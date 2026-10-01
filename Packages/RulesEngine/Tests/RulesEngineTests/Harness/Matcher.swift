import Foundation
@testable import RulesEngine

// Matching a compiled situation against the engine (spec §10.2), with the bridge rules of the
// Task 24 extra scope where the engine's output shape and the situations' expectation shape
// differ. What a situation does not mention is never checked. What it states in a shape the
// engine does not model, or states malformed, is reported as `unsupportedShape` (with a short
// `shape` tag), never passed silently.

/// One way the engine's answer differs from what a situation expects.
struct Mismatch: Codable, Hashable, CustomStringConvertible {
    enum Kind: String, Codable, CaseIterable {
        // lines
        case missingLine, wrongValue, wrongVia, wrongRuling, wrongWas, wrongKind, wrongSource, wrongTerm
        // a query's numbers and verdict
        case total, result, base, legal
        // notApplied
        case missingNotApplied, wrongReason, wrongBecause, wrongNotApplied
        // the player-facing parts
        case missingOffer, unexpectedOffer, wrongOffer, missingQuestion, unexpectedQuestion, missingText, unexpectedText
        // a check's stages and result (Task 26)
        case values, fp, qs, spent, success, checkResult, dice
        // an action's events and the checks it asks for (Task 27)
        case missingEvent, unexpectedEvent
        /// A process's state after a step (Task 28): its progress, ended, capped.
        case process
        /// An expectation the engine's output has no field for (`legal.span`, `term`, a
        /// situation-level `legal`, an offer that is no choice, …), or a malformed one.
        case unsupportedShape
    }

    /// What a mismatch is about, for R41: which open rulings could explain it.
    enum Area: String, Codable { case value, notApplied, legal, offers, questions, texts, shape }

    var kind: Kind
    /// The expected query, nil for a situation-level expectation.
    var query: String?
    var detail: String
    /// What the expectation names: clause refs (`RULE.CLAUSE`), rule ids and ruling ids (R41).
    var names: [String]
    /// For `unsupportedShape`: the shape's short tag (R42 lists them).
    var shape: String?

    init(kind: Kind, query: String? = nil, detail: String, names: [String] = [], shape: String? = nil) {
        self.kind = kind; self.query = query; self.detail = detail; self.names = names; self.shape = shape
    }

    static func shape(_ tag: String, _ detail: String, query: String? = nil) -> Mismatch {
        Mismatch(kind: .unsupportedShape, query: query, detail: detail, shape: tag)
    }

    var area: Area {
        switch kind {
        case .missingLine, .wrongValue, .wrongVia, .wrongRuling, .wrongWas, .wrongKind, .wrongSource, .wrongTerm,
             .total, .result, .base, .values, .fp, .qs, .spent, .success, .checkResult, .dice,
             .missingEvent, .unexpectedEvent, .process: .value
        case .missingNotApplied, .wrongReason, .wrongBecause, .wrongNotApplied: .notApplied
        case .legal: .legal
        case .missingOffer, .unexpectedOffer, .wrongOffer: .offers
        case .missingQuestion, .unexpectedQuestion: .questions
        case .missingText, .unexpectedText: .texts
        case .unsupportedShape: .shape
        }
    }

    var description: String { "[\(kind.rawValue)] \(query.map { "\($0): " } ?? "")\(detail)" }
}

/// An open ruling a run met, and the clause whose effect rests on it (R32/R41).
struct OpenHit: Hashable {
    var ruling: String
    var origin: ClauseRef?
}

/// What a situation-level `legal` is compared with (Task 30): the action queries' breakdowns
/// (`at`, `fk`), the defences' (`pa`, `aw`), and each expected loadout entry's legality, read on
/// the situation the run leaves.
struct LegalView {
    var actions: [Breakdown] = []
    var defences: [Breakdown] = []
    /// A `loadout` entry (its keys but `allowed`, `because`, `ruling`) → the pieces' legality.
    var loadout: [[String: JSONValue]: Legality] = [:]
    /// Task 31: a `combinations` entry's `choices` → whether they may be taken together
    /// (`Engine.legality(ofCombination:)`).
    var combinations: [[String]: Legality] = [:]
    /// Task 31: `actions: { attack, spell, freeAction }`: the breakdowns of each kind's queries
    /// (`at` and `fk`; a spell check's `check.modifier(spell: any)`); a free action has none (R37:
    /// an action selector names `at`, `fk` and `check.*`).
    var actionKinds: [String: [Breakdown]] = [:]
    /// The firing entries of the action kinds' breakdowns that come from a `forbid` whose action
    /// selector names every action (`any`) or a free action, which would take free actions too.
    var freeActionForbids: [NotApplied] = []
    /// The combinations' breakdowns: the open rulings their forbids met (R32).
    var recorded: [Breakdown] = []
    /// Task 32: choice → the rulings of its offers (`Engine.offers(in:)`), which a refused
    /// combination of it rests on as a `notOffered` choice does.
    var offerRulings: [String: [String]] = [:]

    /// The queries an `actions` kind stands for.
    static let actionQueries: [String: [String]] = ["attack": ["at", "fk"], "spell": ["check.modifier(spell: any)"], "freeAction": []]

    static let entryFields: Set<String> = ["allowed", "because", "ruling"]

    /// The pieces an entry names: its flags (`secondArmour: true`) and its slots
    /// (`armour: Lederrüstung`); the situation it is read on states the slots unless a flag says
    /// the piece is an additional one.
    static func ids(_ entry: [String: JSONValue]) -> (ids: [String], slots: [String: JSONValue]) {
        let piece = entry.filter { !entryFields.contains($0.key) }
        let flags = piece.filter { $0.value == .bool(true) }.map(\.key)
        let slots = piece.filter { $0.value.string != nil && Vocabulary.facts["loadout.\($0.key)"] == .loadout }
        return ((flags + slots.keys).sorted(), flags.isEmpty ? Dictionary(uniqueKeysWithValues: slots.map { ("loadout.\($0.key)", $0.value) }) : [:])
    }

    /// The kinds `loadout.other` holds; an entry naming an item there names the piece (Task 31 fix round 1).
    static let otherKinds: Set<String> = ["weapon", "shield", "parryingWeapon"]

    /// Task 31 fix round 1: an entry's slots as the app states them. `other` holds the second
    /// piece's kind; an entry naming an item there (`other: Holzschild`) states the kind from data:
    /// the item's technique (stated `item.<item>.technique`, else its equipment row) against the
    /// shield slot's (schilde.SCH3's `loadout.shield.technique`): a shield is `other: shield` in
    /// `loadout.shield`, anything else `other: weapon` with that technique. Without a technique the
    /// name is kept, as before.
    static func slotFacts(_ slots: [String: JSONValue], in situation: Situation, book: RuleBook) -> [String: JSONValue] {
        var out = slots
        guard let item = slots["loadout.other"]?.string, !otherKinds.contains(item) else { return out }
        let evaluation = Engine(book: book).evaluation(situation)
        let stated = situation.facts["item.\(item).technique"]?.value.string
        let row = book.template(ofItem: item, in: situation).flatMap { book.rules[$0]?.provides["technique"]?.string }
        guard let t = (stated ?? row).map(evaluation.techniqueId) else { return out }
        let shield = book.providers(of: "loadout.shield.technique").filter { book.rules[$0.rule]?.kind != .equipment }
            .compactMap { $0.value.string }.map(evaluation.techniqueId)
        if shield.contains(t) {
            out["loadout.other"] = "shield"
            out["loadout.shield"] = .string(item)
        } else {
            out["loadout.other"] = "weapon"
            out["loadout.other.technique"] = .string(t)
        }
        return out
    }

    static func read(_ legal: JSONValue?, in situation: Situation, engine: Engine) -> LegalView? {
        guard let o = legal?.objectValue else { return nil }
        var v = LegalView()
        if o["actions"] != nil { v.actions = ["at", "fk"].map { engine.evaluate(Query($0), in: situation) } }
        if let kinds = o["actions"]?.objectValue {
            for kind in kinds.keys { v.actionKinds[kind] = (actionQueries[kind] ?? []).map { engine.evaluate(Query($0), in: situation) } }
            let firing = v.actionKinds.values.flatMap { $0 }.flatMap(\.legal.reasons)
            v.freeActionForbids = firing.filter { n in
                engine.book.rules[n.origin.rule]?.clauses.first { $0.id == n.origin.clause }?.effects.contains { e in
                    guard case .forbid(let f) = e.payload, f.what.kind == .action else { return false }
                    return f.what.ids.contains { ["any", "freeAction"].contains($0.id ?? "") }
                } ?? false
            }
        }
        let combos = (o["combinations"]?.arrayValue ?? []) + (o["exclusive"]?.arrayValue ?? [])
        if !combos.isEmpty {
            for offer in engine.offers(in: situation) { v.offerRulings[offer.choice, default: []] += offer.rulings }
        }
        for raw in combos {
            guard let choices = raw.objectValue?["choices"]?.arrayValue?.compactMap(\.string) else { continue }
            let b = engine.evaluation(situation).combinationBreakdown(choices)
            v.combinations[choices] = b.legal
            v.recorded.append(b)
        }
        if o["defences"] != nil { v.defences = ["pa", "aw"].map { engine.evaluate(Query($0), in: situation) } }
        for raw in o["loadout"]?.arrayValue ?? [] {
            guard let entry = raw.objectValue else { continue }
            let key = entry.filter { !entryFields.contains($0.key) }
            let (ids, slots) = Self.ids(entry)
            var s = situation
            for (name, value) in slotFacts(slots, in: situation, book: engine.book) { s.facts[name] = Fact(name: name, value: value, owner: .loadout) }
            v.loadout[key] = engine.legality(ofLoadout: ids, in: s)
        }
        return v
    }
}

/// What a comparison found: the mismatches, and notes that are no mismatch (a prose reason).
struct MatchResult {
    var mismatches: [Mismatch] = []
    var notes: [String] = []
}

enum Matcher {
    /// The mismatches of the situation's query and situation-level expectations (§10.2).
    static func match(_ expected: CompiledSituation, engine: Engine) -> [Mismatch] {
        run(expected, engine: engine).mismatches
    }

    struct Run {
        var mismatches: [Mismatch]
        var notes: [String]
        /// Every open ruling the run met, with its clause: a `notApplied(openRuling)` or an
        /// open-ruling text in any breakdown, an `openRuling` reason of an offer, and, without a
        /// query, the offers `Engine.offers(in:)` leaves out for resting on an open ruling.
        var hits: [OpenHit]
    }

    /// Evaluates every expected query on the situation with its pools (`engineSituation`), and
    /// `Engine.offers(in:)` when offers are expected without a query, then compares.
    ///
    /// With a check's `view` (Task 26), a stage query is the procedure's breakdown, `values` its
    /// effective attributes, a `reroll` offer entry its rerolls, and the situation-level entries
    /// are looked up in its breakdowns too. With a hit's `hit` (Task 27), each query is the one the
    /// before/after rule chose and the situation-level entries are looked up in the chain's
    /// breakdowns too. An `offered` / `notOffered` entry naming an attack or a defence is matched
    /// against `CombatRoll.options`. `onlyQueries` compares the query expectations alone: a
    /// situation whose action part cannot run (extra 8).
    static func run(_ s: CompiledSituation, engine: Engine, view: ProcedureView? = nil, hit: HitView? = nil,
                    onlyQueries: Bool = false) -> Run {
        let situation = s.engineSituation
        let breakdowns = s.expect.map {
            view?.breakdown(for: $0.query) ?? hit?.breakdown(for: $0.query) ?? engine.evaluate(Query($0.query), in: situation)
        }
        let wantsOffers = !onlyQueries && (s.expectSituation["offered"] != nil || s.expectSituation["notOffered"] != nil)
        var offers: [OfferedChoice] = []
        let options = wantsOffers && expectsCombatOptions(s) ? CombatRoll.options(in: situation, engine: engine) : nil
        let seen = (breakdowns + (view?.breakdowns ?? []) + (hit?.breakdowns ?? []) + (options ?? []).map(\.target)).distinct()
        var hits = openRulings(in: seen) + openRulings(in: seen.flatMap(\.offers))
        var offerEntries: [NotApplied] = []
        if s.expect.isEmpty && wantsOffers && view == nil {
            offers = engine.offers(in: situation)
            hits += openRulings(in: offers)
            // `offers(in:)` skips an offer resting on an open ruling without a trace; a breakdown
            // of no target (it sees every `*` offer) records it. Only its offers' entries count.
            let offering = Set(offeringClauses(engine.book).values.flatMap { $0 })
            let recorded = engine.evaluate(Query("offers"), in: situation)
            hits += openRulings(in: [recorded]).filter { $0.origin.map(offering.contains) ?? false }
            // Task 31: its entries on the offering clauses say why an offer is not there (its own
            // `when` is no: SA_66.V3).
            offerEntries = recorded.notApplied.filter { offering.contains($0.origin) }
        }
        if let view { hits += openRulings(in: view.offers.flatMap(\.reasons)) }
        // Task 30 (R52, R62): the situation-level entries of a situation without a query are the
        // hero sheet's.
        let sheet = !onlyQueries && s.expect.isEmpty && view == nil && !Set(s.expectSituation.keys).isDisjoint(with: sheetKeys)
            ? engine.sheet(in: situation) : nil
        if let sheet { hits += openRulings(in: [sheet]) }
        let legal = onlyQueries ? nil : LegalView.read(s.expectSituation["legal"], in: hit?.situation ?? situation, engine: engine)
        if let legal {
            hits += openRulings(in: legal.actions + legal.defences + legal.recorded + legal.actionKinds.values.flatMap { $0 })
                + openRulings(in: legal.loadout.values.flatMap(\.reasons))
        }
        // Task 30: the technique each query expecting `base.technique` is made with.
        let evaluation = engine.evaluation(situation)
        let techniques = Dictionary(uniqueKeysWithValues: s.expect.filter { $0.base?.objectValue?["technique"] != nil }
            .map { ($0.query, evaluation.techniqueForms(of: Query($0.query))) })
        // Task 31: a situation-level `notApplied` entry for a rule the breakdowns compared do not
        // touch is looked up where its clause acts: the hero sheet (a `*` effect) and the targets
        // its effects reach, on the situation the run leaves.
        let after = hit?.situation ?? situation
        let fallback: (ExpectedNotApplied) -> [NotApplied] = { e in
            let targets = engine.book.reach.filter { $0.key != "*" }
                .filter { $0.value.contains { $0.rule == e.rule && (e.clause == nil || $0.clause == e.clause) } }.keys.sorted()
            return ([engine.sheet(in: after)] + targets.map { engine.evaluate(Query($0), in: after) }).flatMap(\.notApplied)
        }
        let c = compare(s, breakdowns: breakdowns, offers: offers, offering: offeringClauses(engine.book), view: view,
                        hit: hit, options: options, onlyQueries: onlyQueries, sheet: sheet, legal: legal, techniques: techniques,
                        book: engine.book, offerEntries: offerEntries, fallback: fallback,
                        rulesets: { engine.legality(ofRuleset: $0, in: situation) })
        return Run(mismatches: c.mismatches, notes: c.notes, hits: hits.distinct())
    }

    static func openRulings(in entries: [NotApplied]) -> [OpenHit] {
        entries.filter { $0.reason == .openRuling }.flatMap { n in n.rulings.map { OpenHit(ruling: $0, origin: n.origin) } }
    }

    /// Compares `s` with the breakdowns of its expected queries (in `s.expect`'s order) and, for
    /// a situation without a query, `Engine.offers(in:)`. `offering`: choice id → the clauses
    /// that offer it (for a `notOffered` whose offer was suppressed).
    static func compare(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice],
                        offering: [String: [ClauseRef]] = [:], view: ProcedureView? = nil, hit: HitView? = nil,
                        options: [CombatOption]? = nil, onlyQueries: Bool = false, sheet: Breakdown? = nil,
                        legal: LegalView? = nil, techniques: [String: [String]] = [:], book: RuleBook? = nil,
                        offerEntries: [NotApplied] = [], fallback: ((ExpectedNotApplied) -> [NotApplied])? = nil,
                        rulesets: ((String) -> Legality)? = nil) -> MatchResult {
        var c = MatchResult()
        for (q, b) in zip(s.expect, breakdowns) {
            query(q, b, values: view?.values(for: q.query), techniques: techniques[q.query], &c)
        }
        if onlyQueries { return c }
        situationLevel(s, breakdowns: breakdowns, offers: offers, offering: offering, view: view, hit: hit, options: options,
                       sheet: sheet, legal: legal, book: book, offerEntries: offerEntries, fallback: fallback, rulesets: rulesets, &c)
        let run = hit.map { _ in s.expectSituation.keys.filter(CombatRunner.handled.contains).count + s.sequence.count } ?? 0
        if checkedExpectations(s, check: view != nil) + run == 0 {
            c.mismatches.append(.shape("nothing to compare", "the situation states no expectation the harness checks"))
        }
        return c
    }

    /// How many expectations `s` states that the matcher checks (the action layer's excluded,
    /// except a check's result and its steps when the check procedure runs: `check`).
    static func checkedExpectations(_ s: CompiledSituation, check: Bool = false) -> Int {
        let perQuery = s.expect.reduce(0) { n, q in
            n + [q.total != nil, q.result != nil, q.lines != nil, q.notApplied != nil, q.legal != nil, q.base != nil,
                 q.values != nil].filter { $0 }.count
        }
        // Task 31 fix round 1: a check run as its stated outcome compares its events.
        let run: Set<String> = check ? Set(ActionRunner.supported.map(\.rawValue) + (ActionRunner.outcome(s) != nil ? ["events"] : [])) : []
        return perQuery + s.expectSituation.keys.filter { !actionKeys.contains($0) || run.contains($0) }.count
            + (check ? s.sequence.count : 0)
    }

    static func openRulings(in breakdowns: [Breakdown]) -> [OpenHit] {
        var out: [OpenHit] = []
        for b in breakdowns {
            for n in b.notApplied where n.reason == .openRuling { out += n.rulings.map { OpenHit(ruling: $0, origin: n.origin) } }
            for t in b.texts where t.kind == .openRuling { if let r = t.ruling { out.append(OpenHit(ruling: r, origin: t.origin)) } }
        }
        return out
    }

    /// The `openRuling` entries among offers' reasons and their refused options' reasons.
    static func openRulings(in offers: [OfferedChoice]) -> [OpenHit] {
        offers.flatMap { $0.reasons + $0.refused.flatMap(\.reasons) }
            .filter { $0.reason == .openRuling }
            .flatMap { n in n.rulings.map { OpenHit(ruling: $0, origin: n.origin) } }
    }

    /// Choice id → the clauses whose `offer` offers it.
    static func offeringClauses(_ book: RuleBook) -> [String: [ClauseRef]] {
        var out: [String: [ClauseRef]] = [:]
        for rule in book.rules.values {
            for clause in rule.clauses {
                for e in clause.effects {
                    if case .offer(let o) = e.payload { out[o.choice, default: []].append(e.origin.clauseRef) }
                }
            }
        }
        return out
    }

    // MARK: - One query

    static func query(_ q: QueryExpectation, _ b: Breakdown, values: [Int?]? = nil, techniques: [String]? = nil,
                      _ c: inout MatchResult) {
        func add(_ kind: Mismatch.Kind, _ detail: String, names: [String] = []) {
            c.mismatches.append(Mismatch(kind: kind, query: q.query, detail: detail, names: names))
        }

        if let expected = q.lines { c.mismatches += lines(expected, b, query: q.query) }
        if let t = q.total {
            // Bridge 2: a derived base counts in the situation's `total` (leMax 37); a sheet base
            // does not (at −5), nor a base the GM states (Task 32: the opponent's RS); without a
            // base the total is the lines' sum.
            let derived = b.base.map { $0.owner != .sheet && $0.owner != .gm } ?? false
            let actual: Int? = derived ? b.result : b.total
            if actual != t {
                let got = actual.map(String.init) ?? "none"
                let what = derived ? "the result: the base is derived" : "the lines after the base"
                add(.total, "expected total \(t), got \(got) (\(what)) — shown: \(show(b.shownLines))")
            }
        }
        if let r = q.result, b.result != r {
            add(.result, "expected result \(r), got \(b.result.map(String.init) ?? "none (no base)")")
        }
        for e in q.notApplied ?? [] { notApplied(e, in: b.notApplied, query: q.query, &c) }
        if let legal = q.legal { c.mismatches += self.legal(legal, b.legal, query: q.query, offers: b.offers) }
        if let base = q.base { c.mismatches += self.base(base, b, query: q.query, techniques: techniques) }
        if let raw = q.values {
            // Task 26: a check's attribute stage, one effective value per Teilprobe.
            let want = raw.arrayValue?.map(\.int)
            if let values, let want, !want.contains(nil) {
                if want != values {
                    add(.values, "expected values \(want.map { $0! }), got \(values.map { $0.map(String.init) ?? "none" })")
                }
            } else if values == nil {
                c.mismatches.append(.shape("values", "values are a 3W20 check's attribute stage; no check runs here", query: q.query))
            } else {
                c.mismatches.append(.shape("malformed values", "values \(raw) is not a list of numbers", query: q.query))
            }
        }
    }

    // MARK: Lines

    /// The value a situation states for a line (bridge 3): the value after the step for `set`,
    /// `levelAs`, a scale step (an `add` with `now`) and `replaced`; the step for any other kind.
    static func stated(_ l: Line) -> Int {
        switch l.kind {
        case .set, .levelAs, .replaced: l.now ?? l.value
        case .add where l.now != nil: l.now ?? l.value
        default: l.value
        }
    }

    /// Bridge 5: for each `.multiplied` line that scaled the lines of exactly one clause, that
    /// clause's line as the situation names it: value the lines' sum plus the delta, `was` the
    /// sum before any of them was replaced (Task 32: a replaced line counts its own `was`, TZ.4's
    /// aiming −4 eased to −2, then halved to −1, is "−1, was −4"), the multiplier in `via`. It
    /// matches only an expected line whose `via` names the multiplier.
    static func scaledLines(_ shown: [Line]) -> [(line: Line, multiplier: ClauseRef)] {
        shown.compactMap { d in
            guard d.kind == .multiplied, let m = d.origin else { return nil }
            let scaled = d.via.filter { v in shown.contains { $0.origin == v && $0.kind != .multiplied } }
            guard scaled.count == 1, let x = scaled.first else { return nil }
            let own = shown.filter { $0.origin == x && $0.kind != .multiplied }
            let sum = own.reduce(0) { $0 + $1.value }
            let line = Line(value: sum + d.value, kind: own[0].kind, origin: x,
                            via: (own.flatMap(\.via) + [m] + d.via.filter { $0 != x }).distinct(),
                            rulings: (own.flatMap(\.rulings) + d.rulings).distinct(),
                            facts: own.flatMap(\.facts) + d.facts, owner: own[0].owner,
                            was: own.reduce(0) { $0 + ($1.kind == .replaced ? $1.was ?? $1.value : $1.value) })
            return (line, m)
        }
    }

    /// What an expected line names (R41): its clause and rule, its `via`, its rulings.
    static func names(_ e: ExpectedLine) -> [String] {
        var out: [String] = []
        if let f = e.from { out.append(f); if let r = ClauseRef(f) { out.append(r.rule) } }
        out += e.via ?? []
        out += e.ruling ?? []
        return out
    }

    /// Each expected line must match a distinct shown line (§10.2: any order; actual lines the
    /// situation does not mention are not checked).
    static func lines(_ expected: [ExpectedLine], _ b: Breakdown, query: String) -> [Mismatch] {
        let scaled = scaledLines(b.shownLines)
        let shown = b.shownLines + scaled.map(\.line)
        // A scaled line stands for its origin line only where the situation names the multiplier.
        let multiplier = Array(repeating: nil, count: b.shownLines.count) + scaled.map { Optional($0.multiplier) }
        func failures(_ e: ExpectedLine, _ j: Int) -> [Mismatch.Kind] {
            var out = Self.failures(e, shown[j])
            if let m = multiplier[j], !(e.via ?? []).contains(m.description), !out.contains(.wrongVia) { out.append(.wrongVia) }
            return out
        }
        let fits = expected.map { e in shown.indices.filter { failures(e, $0).isEmpty } }
        let assigned = maximumMatching(fits, right: shown.count)
        var out: [Mismatch] = []
        for (i, e) in expected.enumerated() {
            guard let j = assigned[i] else {
                out.append(diagnose(e, shown, failures: { failures(e, $0) }, used: Set(assigned.compactMap { $0 }), query: query))
                continue
            }
            // A term the matched line carries matched in `failures` (Task 35); one it lacks is a shape.
            if let term = e.term, shown[j].term == nil {
                out.append(.shape("term", "term \"\(term)\" on \(e.from ?? "a line"): the engine does not name a line's term",
                                  query: query))
            }
        }
        return out
    }

    /// The fields of `e` that `a` does not meet, in reporting order.
    static func failures(_ e: ExpectedLine, _ a: Line) -> [Mismatch.Kind] {
        var out: [Mismatch.Kind] = []
        if let from = e.from, a.origin?.description != from { out.append(.missingLine) }
        if let v = e.value, stated(a) != v { out.append(.wrongValue) }
        if let via = e.via, !Set(via).isSubset(of: a.via.map(\.description)) { out.append(.wrongVia) }
        // Task 31: a ruling as written (a `sequence` step's `round-up`) or qualified (`shared.round-up`).
        if let r = e.ruling, !r.allSatisfy({ rulingMatches($0, a.rulings) }) { out.append(.wrongRuling) }
        if let was = e.was, a.was != was { out.append(.wrongWas) }
        if let k = e.kind, a.kind.rawValue != k { out.append(.wrongKind) }
        if let s = e.source, a.owner?.rawValue != s { out.append(.wrongSource) }
        // Task 35: two lines of one clause and value (ZM11's per modification) pair by their terms.
        if let t = e.term, let actual = a.term, actual != t { out.append(.wrongTerm) }
        return out
    }

    /// Why `e` matched no line: the closest line from its clause (R21: carrying its ruling), the
    /// unused ones first, and its first failing field; `missingLine` when there is none.
    static func diagnose(_ e: ExpectedLine, _ shown: [Line], failures: (Int) -> [Mismatch.Kind], used: Set<Int>,
                         query: String) -> Mismatch {
        let same = shown.indices.filter { j in
            if let from = e.from { return shown[j].origin?.description == from }
            if let r = e.ruling { return Set(r).isSubset(of: shown[j].rulings) }
            return true
        }
        let pool = same.filter { !used.contains($0) }.isEmpty ? same : same.filter { !used.contains($0) }
        let best = pool.min { failures($0).count < failures($1).count }
        let want = describe(e)
        guard let j = best, let kind = failures(j).first else {
            let what = e.from.map { "no line from \($0)" } ?? "no line carrying \(e.ruling ?? [])"
            let extra = same.isEmpty ? "" : " (its \(same.count) line(s) match other expected lines)"
            return Mismatch(kind: .missingLine, query: query, detail: "expected \(want): \(what)\(extra) — shown: \(show(shown))",
                            names: names(e))
        }
        return Mismatch(kind: kind, query: query, detail: "expected \(want), got \(show([shown[j]]))", names: names(e))
    }

    /// Bipartite matching by augmenting paths: `fits[i]` are the right-hand indices left `i` may
    /// take. Returns the right index each left one got, or nil.
    static func maximumMatching(_ fits: [[Int]], right: Int) -> [Int?] {
        var owner = [Int?](repeating: nil, count: right)
        func augment(_ i: Int, _ seen: inout Set<Int>) -> Bool {
            for j in fits[i] where !seen.contains(j) {
                seen.insert(j)
                if owner[j] == nil || augment(owner[j]!, &seen) { owner[j] = i; return true }
            }
            return false
        }
        for i in fits.indices { var seen: Set<Int> = []; _ = augment(i, &seen) }
        var out = [Int?](repeating: nil, count: fits.count)
        for (j, i) in owner.enumerated() { if let i { out[i] = j } }
        return out
    }

    // MARK: notApplied

    enum ReasonForm: Equatable { case code(ReasonCode), ref(String), prose(String) }

    /// A `reason` is a reason code, a `RULE.CLAUSE` ref (read as `because`, bridge 6), or prose.
    static func reasonForm(_ reason: String) -> ReasonForm {
        if let code = ReasonCode(rawValue: reason) { return .code(code) }
        return isRef(reason) ? .ref(reason) : .prose(reason)
    }

    /// `RULE.CLAUSE`: no whitespace, a dot inside.
    static func isRef(_ text: String) -> Bool {
        !text.contains(where: \.isWhitespace) && ClauseRef(text) != nil
    }

    /// Bridge 6: a text `because` is the entry's own `because`. A clause ref names what
    /// suppressed, overrode or forbade the entry: only for those reasons, and only as the
    /// entry's first `via` (the suppressor), its `because` (the winning clause) or, for a forbid,
    /// its origin; for a `when` that read `level` and is false, a clause in its `via` (the
    /// useLevel that gave that level, Task 30).
    static func because(_ b: String, _ n: NotApplied) -> Bool {
        guard isRef(b) else { return n.because == b }
        switch n.reason {
        case .suppressed, .overridden: return n.via.first?.description == b || n.because == b
        case .forbidden: return n.via.first?.description == b || n.because == b || n.origin.description == b
        // Task 30: a `when` made false through the level it read names the useLevel in its `via`
        // (lebensenergie 15.4: Schmerz I treated as none by ADV_49.ZH4). Only a `when` that read
        // `level`: an enabling require in `via` is no reason for a false condition.
        case .conditionFalse: return n.facts.contains { $0.name == "level" } && n.via.contains { $0.description == b }
        default: return false
        }
    }

    static func failures(_ e: ExpectedNotApplied, _ n: NotApplied) -> [Mismatch.Kind] {
        var out: [Mismatch.Kind] = []
        switch e.reason.map(reasonForm) {
        case .code(let c)?: if n.reason != c { out.append(.wrongReason) }
        case .ref(let r)?: if !because(r, n) { out.append(.wrongBecause) }
        case .prose?, nil: break
        }
        if let b = e.because, !because(b, n) { out.append(.wrongBecause) }
        if let r = e.ruling, !Set(r).isSubset(of: n.rulings) { out.append(.wrongNotApplied) }
        if let v = e.value, n.value != v { out.append(.wrongNotApplied) }
        return out
    }

    static func names(_ e: ExpectedNotApplied) -> [String] {
        [e.rule] + (e.clause.map { ["\(e.rule).\($0)"] } ?? []) + (e.because.map { [$0] } ?? [])
            + (e.reason.flatMap { isRef($0) ? [$0] : nil } ?? []) + (e.ruling ?? []) + (e.reason.map(proseRulings) ?? [])
    }

    /// Task 31: the rulings a prose reason cites as "ruling <id>" ("in Formation instead (ruling
    /// formation-and-plaenkler)"), for R41: they name what the entry rests on.
    static func proseRulings(_ reason: String) -> [String] {
        guard !isRef(reason) else { return [] }
        let words = reason.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return zip(words, words.dropFirst()).filter { $0.0.hasSuffix("ruling") }
            .map { $0.1.trimmingCharacters(in: CharacterSet(charactersIn: "(),;:.")) }.filter { !$0.isEmpty }
    }

    /// `notApplied` matches by rule (and clause, when given) and reason code (§10.2), plus
    /// `because`, `ruling` and `value` when given. A prose `reason` (R42) is matched by rule and
    /// clause only, and kept as a note.
    static func notApplied(_ e: ExpectedNotApplied, in entries: [NotApplied], query: String?, _ c: inout MatchResult) {
        let name = e.clause.map { "\(e.rule).\($0)" } ?? e.rule
        if case .prose(let p)? = e.reason.map(reasonForm) {
            c.notes.append("\(query.map { "\($0): " } ?? "")notApplied \(name): reason \"\(p)\" is prose; matched by rule and clause only")
        }
        let same = entries.filter { $0.rule == e.rule && (e.clause == nil || $0.clause == e.clause) }
        guard !same.isEmpty else {
            let got = entries.filter { $0.rule == e.rule }.map { "\($0.origin) \($0.reason.rawValue)" }
            c.mismatches.append(Mismatch(kind: .missingNotApplied, query: query,
                                         detail: "no notApplied entry for \(name)" + (got.isEmpty ? "" : " (the rule's: \(got))"),
                                         names: names(e)))
            return
        }
        if same.contains(where: { failures(e, $0).isEmpty }) { return }
        let best = same.min { failures(e, $0).count < failures(e, $1).count }!
        c.mismatches.append(Mismatch(kind: failures(e, best)[0], query: query,
                                     detail: "expected notApplied \(name) \(describe(e)), got \(best.origin) \(best.reason.rawValue)"
                                         + " because \(best.because ?? "–") via \(best.via.map(\.description)) rulings \(best.rulings)"
                                         + " value \(best.value.map(String.init) ?? "–")",
                                     names: names(e)))
    }

    // MARK: legal, base

    /// Bridge 7: `allowed` compares when given (a bare bool is `allowed`); `because` matches when
    /// any firing forbid or require is it; `ruling` when any of them rests on it; `span` (Task 31)
    /// when a firing entry read a choice (`choice.vorstoss`) that an offer among `offers` offers for
    /// that span (SA_66.V3's `round`: the defences are gone until the round ends); `via` and any
    /// other key are not modelled; a malformed value is reported.
    static func legal(_ expected: JSONValue, _ actual: Legality, query: String?, offers: [OfferedChoice] = []) -> [Mismatch] {
        let firing = actual.reasons.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") }
        switch expected {
        case .bool(let allowed):
            return actual.allowed == allowed ? []
                : [Mismatch(kind: .legal, query: query, detail: "expected legal \(allowed), got \(actual.allowed) \(firing)")]
        case .object(let o):
            var out: [Mismatch] = []
            let names = [o["because"]?.string].compactMap { $0 } + (o["ruling"].map(strings) ?? [])
            func mismatch(_ d: String) -> Mismatch { Mismatch(kind: .legal, query: query, detail: d, names: names) }
            if let allowed = o["allowed"] {
                guard case .bool(let a) = allowed else {
                    return [.shape("legal.malformed", "legal.allowed \(allowed) is not a bool", query: query)]
                }
                if actual.allowed != a { return [mismatch("expected allowed \(a), got \(actual.allowed) \(firing)")] }
            }
            if let raw = o["because"] {
                if let b = raw.string {
                    if !actual.reasons.contains(where: { $0.origin.description == b || $0.because == b }) {
                        out.append(mismatch("expected a firing \(b), firing: \(firing)"))
                    }
                } else {
                    out.append(.shape("legal.malformed", "legal.because \(raw) is not a string", query: query))
                }
            }
            if let r = o["ruling"].map(strings), !r.allSatisfy({ ruling in actual.reasons.contains { rulingMatches(ruling, $0.rulings) } }) {
                out.append(mismatch("expected a firing entry resting on \(r), firing: \(firing)"))
            }
            if let raw = o["span"] {
                let choices = Set(actual.reasons.flatMap(\.facts).map(\.name).filter { $0.hasPrefix("choice.") }
                    .map { String($0.dropFirst("choice.".count)) })
                let spans = offers.filter { choices.contains($0.choice) }.compactMap(\.span?.rawValue)
                if raw.string == nil {
                    out.append(.shape("legal.malformed", "legal.span \(raw) is not a string", query: query))
                } else if !spans.contains(raw.string!) {
                    out.append(mismatch("expected a firing entry lasting the \(raw.string!), the choices it read are offered for \(spans)"))
                }
            }
            if let raw = o["via"], raw.string == nil, raw.arrayValue?.allSatisfy({ $0.string != nil }) != true {
                out.append(.shape("legal.malformed", "legal.via \(raw) is not a clause or a list of clauses", query: query))
            } else if let via = o["via"].map(strings), !Set(via).isSubset(of: actual.reasons.flatMap(\.via).map(\.description)) {
                // Task 31 fix round 1: the firing entries' `via`.
                out.append(mismatch("expected a firing entry via \(via), firing: \(actual.reasons.map { "\($0.origin) via \($0.via)" })"))
            }
            for key in o.keys.sorted() where !["allowed", "because", "ruling", "span", "via"].contains(key) {
                out.append(.shape("legal.\(key)", "legal.\(key) is not modelled", query: query))
            }
            return out
        default:
            return [.shape("legal.malformed", "legal \(expected) is not a bool or an object", query: query)]
        }
    }

    /// The query key `base`: `from` is the base's clause or one of its parts', `value` the
    /// base's value, `ruling` and `via` are carried by the base or its parts, `technique` the
    /// technique it is for (Task 30).
    static func base(_ expected: JSONValue, _ b: Breakdown, query: String, techniques: [String]? = nil) -> [Mismatch] {
        guard case .object(let o) = expected else { return [.shape("base.malformed", "base \(expected)", query: query)] }
        var out: [Mismatch] = []
        let lines = b.base.map { [$0] + $0.parts } ?? []
        var wrong: [String] = []
        let from = o["from"]?.string
        if let from, !lines.contains(where: { $0.origin?.description == from }) { wrong.append("from \(from)") }
        if let v = o["value"]?.int, b.base?.value != v { wrong.append("value \(v)") }
        if let r = o["ruling"].map(strings), !Set(r).allSatisfy({ x in lines.contains { rulingMatches(x, $0.rulings) } }) {
            wrong.append("ruling \(r)")
        }
        if let via = o["via"].map(strings), !Set(via).isSubset(of: lines.flatMap(\.via).map(\.description)) {
            wrong.append("via \(via)")
        }
        // Task 30: `technique` is the technique the value is for: a KtW the base read
        // (`ktw.Schilde`), else the technique the query is made with (`techniques`, both forms).
        if let t = o["technique"]?.string {
            let read = lines.flatMap(\.facts).contains { $0.name == "ktw.\(t)" }
            if !read && !(techniques ?? []).contains(t) { wrong.append("technique \(t)") }
        }
        if !wrong.isEmpty {
            let names = (from.map { [$0] + [ClauseRef($0)?.rule].compactMap { $0 } } ?? []) + (o["via"].map(strings) ?? [])
                + (o["ruling"].map(strings) ?? [])
            out.append(Mismatch(kind: .base, query: query, detail: "expected base \(wrong.joined(separator: ", ")), got "
                                + (b.base.map { show([$0] + $0.parts) } ?? "no base"), names: names))
        }
        for key in o.keys.sorted() where !["from", "value", "ruling", "via", "technique"].contains(key) {
            out.append(.shape("base.\(key)", "base.\(key) is not modelled", query: query))
        }
        return out
    }

    /// A ruling as a situation writes it outside lines (unqualified or qualified) against
    /// qualified ids.
    static func rulingMatches(_ ruling: String, _ actual: [String]) -> Bool {
        actual.contains { $0 == ruling || $0.hasSuffix("." + ruling) }
    }

    // MARK: - Situation level

    /// The situation-level keys the action layer matches (`ActionRunner.Need`).
    static var actionKeys: Set<String> { Set(ActionRunner.Need.allCases.map(\.rawValue)) }
    /// The situation-level keys this matcher handles.
    static let situationKeys: Set<String> = ["offered", "notOffered", "notApplied", "questions", "texts", "legal"]
    /// The situation-level keys the hero sheet answers when no query does (Task 30).
    static let sheetKeys: Set<String> = ["notApplied", "questions", "texts"]

    /// `sheet`: the hero sheet's breakdown (`Engine.sheet(in:)`), for a situation without a
    /// query: its `texts`, `notApplied` and `questions` are the sheet's, and so is a hit run's
    /// entry for a rule no stage of the hit evaluates (R52).
    static func situationLevel(_ s: CompiledSituation, breakdowns queried: [Breakdown], offers: [OfferedChoice],
                               offering: [String: [ClauseRef]], view: ProcedureView? = nil, hit: HitView? = nil,
                               options: [CombatOption]? = nil, sheet: Breakdown? = nil, legal legalView: LegalView? = nil,
                               book: RuleBook? = nil, offerEntries: [NotApplied] = [],
                               fallback: ((ExpectedNotApplied) -> [NotApplied])? = nil,
                               rulesets: ((String) -> Legality)? = nil, _ c: inout MatchResult) {
        let es = s.expectSituation
        // A check's stage breakdowns, and a hit's, count as the situation's too; without them, the
        // sheet's.
        let staged = (queried + (view?.breakdowns ?? []) + (hit?.breakdowns ?? [])).distinct()
        let breakdowns = staged.isEmpty ? (sheet.map { [$0] } ?? []) : staged
        let noQuery = breakdowns.isEmpty
        func shape(_ tag: String, _ d: String) { c.mismatches.append(.shape(tag, d)) }
        func needsQuery(_ key: String) -> Bool {
            guard noQuery else { return false }
            shape("situation \(key) without a query", "situation-level \(key) without a query: the engine has no situation-wide breakdown")
            return true
        }
        func list(_ key: String) -> [JSONValue]? {
            guard let raw = es[key] else { return nil }
            guard let a = raw.arrayValue else { shape("malformed \(key)", "\(key) \(raw) is not a list"); return nil }
            return a
        }

        // Bridge 8: with a query, the breakdowns' offers (a phase-4 suppress acts there);
        // otherwise `Engine.offers(in:)`.
        let pool = queried.isEmpty && view == nil && hit == nil ? offers : breakdowns.flatMap(\.offers)
        let entries = breakdowns.flatMap(\.notApplied)
        for (key, wanted) in [("offered", true), ("notOffered", false)] {
            for entry in list(key) ?? [] {
                if let options, let o = entry.objectValue, o["defence"] != nil || o["attack"] != nil {
                    combatOffer(o, wanted: wanted, options: options, &c)
                    continue
                }
                if let rulesets, let o = entry.objectValue, let slug = o["ruleset"]?.string {
                    c.mismatches += rulesetOffer(o, slug: slug, wanted: wanted, rulesets(slug))
                    continue
                }
                c.mismatches += offer(entry, wanted: wanted, in: pool, notApplied: entries + offerEntries, offering: offering,
                                      rerolls: view?.offers, book: book, screen: hit != nil ? "takeDamage" : nil)
            }
        }
        if es["notApplied"] != nil, !needsQuery("notApplied") {
            // R52: a hit run without a query evaluates the hit's stages only; an entry for a rule
            // none of them touches is about the hero sheet, which the engine has no breakdown of.
            let touched = Set(breakdowns.flatMap { $0.shownLines.compactMap(\.origin?.rule) + $0.notApplied.map(\.origin.rule) })
            for raw in list("notApplied") ?? [] {
                guard let e = ExpectedNotApplied(raw) else { shape("malformed notApplied", "notApplied entry \(raw) has no rule or a key outside notAppliedKeys"); continue }
                if hit != nil, queried.isEmpty, !touched.contains(e.rule) {
                    guard let sheet else {
                        shape("sheet-wide notApplied", "notApplied \(e.rule): no stage of the hit evaluates the rule, and no sheet was read")
                        continue
                    }
                    notApplied(e, in: sheet.notApplied, query: nil, &c)
                    continue
                }
                let own = entries.contains { $0.rule == e.rule && (e.clause == nil || $0.clause == e.clause) }
                notApplied(e, in: own ? entries : entries + (fallback?(e) ?? []), query: nil, &c)
            }
        }
        if es["questions"] != nil, !needsQuery("questions"), let expected = list("questions") {
            let asked = breakdowns.flatMap(\.questions)
            if expected.isEmpty, !asked.isEmpty {
                c.mismatches.append(Mismatch(kind: .unexpectedQuestion, detail: "expected no question, asked: \(asked.map(\.fact).distinct())"))
            }
            for e in expected {
                guard case .object(let o) = e, let fact = o["fact"]?.string else { shape("malformed question", "question \(e)"); continue }
                if !asked.contains(where: { $0.fact == fact }) {
                    let names = [o["from"]?.string, o["ruling"]?.string].compactMap { $0 }
                    c.mismatches.append(Mismatch(kind: .missingQuestion, detail: "no question for \(fact)", names: names))
                }
            }
        }
        if es["texts"] != nil, !needsQuery("texts"), let expected = list("texts") {
            c.mismatches += texts(expected, in: breakdowns.flatMap(\.texts))
        }
        if let legal = es["legal"] {
            c.mismatches += situationLegal(legal, legalView)
        }
        for key in es.keys.sorted() where !situationKeys.contains(key) && !actionKeys.contains(key) {
            shape("situation \(key)", "situation-level \(key) is not modelled")
        }
    }

    /// A situation-level `legal` (Task 30): `actions: none`, `defences: none` and `loadout`
    /// entries against `view` (`LegalView`); any other key or form is an unsupported shape.
    static func situationLegal(_ legal: JSONValue, _ view: LegalView?) -> [Mismatch] {
        guard let o = legal.objectValue, let view else {
            return [.shape("situation legal", "situation-level legal \(legal) is not modelled")]
        }
        var out: [Mismatch] = []
        for key in o.keys.sorted() {
            let raw = o[key]!
            switch key {
            case "actions" where raw.objectValue != nil:
                out += actionKinds(raw.objectValue!, view)
            case "combinations":
                out += combinations(raw, view)
            case "exclusive":
                out += exclusive(raw, view)
            case "actions", "defences":
                guard raw.string == "none" else { out.append(.shape("situation legal \(key)", "legal \(key): \(raw) is not `none`")); continue }
                let breakdowns = key == "actions" ? view.actions : view.defences
                let allowed = breakdowns.filter(\.legal.allowed).map(\.query.description)
                if !allowed.isEmpty {
                    out.append(Mismatch(kind: .legal, detail: "expected no \(key), but \(allowed) allowed"))
                }
            case "loadout":
                for entry in raw.arrayValue ?? [] {
                    guard let e = entry.objectValue, let legality = view.loadout[e.filter { !LegalView.entryFields.contains($0.key) }] else {
                        out.append(.shape("situation legal loadout", "legal loadout entry \(entry) is not modelled"))
                        continue
                    }
                    var wrong: [String] = []
                    if let want = e["allowed"], want != .bool(legality.allowed) { wrong.append("allowed \(want)") }
                    if let b = e["because"]?.string, !legality.reasons.contains(where: { because(b, $0) || $0.because == b }) {
                        wrong.append("because \(b)")
                    }
                    if let r = e["ruling"].map(strings), !r.allSatisfy({ x in legality.reasons.contains { rulingMatches(x, $0.rulings) } }) {
                        wrong.append("ruling \(r)")
                    }
                    if !wrong.isEmpty {
                        let got = "allowed \(legality.allowed) " + legality.reasons.map { "\($0.origin) \($0.reason.rawValue) rulings \($0.rulings)" }.joined(separator: "; ")
                        out.append(Mismatch(kind: .legal, detail: "loadout \(LegalView.ids(e).ids): expected \(wrong.joined(separator: ", ")), got \(got)",
                                            names: [e["because"]?.string].compactMap { $0 } + (e["ruling"].map(strings) ?? [])))
                    }
                }
            default:
                out.append(.shape("situation legal \(key)", "situation-level legal \(key) is not modelled"))
            }
        }
        return out
    }

    /// Task 31: `actions: { attack: forbidden, spell: forbidden, freeAction: { allowed, ruling } }`.
    /// A kind with queries is forbidden when none of them is allowed, allowed when all are; a free
    /// action has no query (R37), so it is allowed unless a firing forbid names every action or a
    /// free action. `because` / `ruling` are the firing entries' of the action kinds.
    static func actionKinds(_ o: [String: JSONValue], _ view: LegalView) -> [Mismatch] {
        var out: [Mismatch] = []
        let firing = view.actionKinds.values.flatMap { $0 }.flatMap(\.legal.reasons)
        for kind in o.keys.sorted() {
            let raw = o[kind]!
            let spec = raw.objectValue ?? [:]
            let want: Bool? = raw.string.map { $0 == "allowed" } ?? spec["allowed"].flatMap { if case .bool(let b) = $0 { b } else { nil } }
            guard let want, LegalView.actionQueries[kind] != nil, raw.string == nil || ["allowed", "forbidden"].contains(raw.string!),
                  Set(spec.keys).isSubset(of: ["allowed", "because", "ruling"]) else {
                out.append(.shape("situation legal actions \(kind)", "legal actions \(kind): \(raw) is not modelled"))
                continue
            }
            let breakdowns = view.actionKinds[kind] ?? []
            let got = breakdowns.isEmpty ? view.freeActionForbids.isEmpty : breakdowns.allSatisfy(\.legal.allowed)
            let names = [spec["because"]?.string].compactMap { $0 } + (spec["ruling"].map(strings) ?? [])
            if breakdowns.isEmpty ? got != want : (want ? !got : breakdowns.contains(where: \.legal.allowed)) {
                out.append(Mismatch(kind: .legal, detail: "expected \(kind) \(want ? "allowed" : "forbidden"), got "
                                    + breakdowns.map { "\($0.query) \($0.legal.allowed)" }.joined(separator: ", ")
                                    + (breakdowns.isEmpty ? "free actions \(got ? "allowed" : "forbidden by \(view.freeActionForbids.map(\.origin))")" : ""),
                                    names: names))
            }
            let pool = breakdowns.isEmpty ? firing : breakdowns.flatMap(\.legal.reasons)
            if let b = spec["because"]?.string, !pool.contains(where: { $0.origin.description == b || $0.because == b }) {
                out.append(Mismatch(kind: .legal, detail: "\(kind): expected a firing \(b), firing: \(pool.map(\.origin))", names: names))
            }
            if let r = spec["ruling"].map(strings), !r.allSatisfy({ x in pool.contains { rulingMatches(x, $0.rulings) } }) {
                out.append(Mismatch(kind: .legal, detail: "\(kind): expected a firing entry resting on \(r), firing: \(pool.map { "\($0.origin) \($0.rulings)" })",
                                    names: names))
            }
        }
        return out
    }

    /// Task 31: `combinations: [{ choices, allowed, because, from, ruling }]` against
    /// `Engine.legality(ofCombination:)`. `because` and `from` name a refusing entry (by clause or
    /// text), `ruling` one it rests on; an allowed combination has no refusing entry, so a `from`
    /// on it is never met.
    static func combinations(_ raw: JSONValue, _ view: LegalView) -> [Mismatch] {
        guard let list = raw.arrayValue else { return [.shape("situation legal combinations", "legal combinations \(raw) is not a list")] }
        var out: [Mismatch] = []
        for entry in list {
            guard let e = entry.objectValue, let choices = e["choices"]?.arrayValue?.compactMap(\.string),
                  Set(e.keys).isSubset(of: ["choices", "allowed", "because", "from", "ruling"]), let legality = view.combinations[choices] else {
                out.append(.shape("situation legal combinations", "legal combinations entry \(entry) is not modelled"))
                continue
            }
            let names = [e["because"]?.string, e["from"]?.string].compactMap { $0 } + (e["ruling"].map(strings) ?? [])
            var wrong: [String] = []
            if let want = e["allowed"], want != .bool(legality.allowed) { wrong.append("allowed \(want)") }
            for key in ["because", "from"] {
                if let b = e[key]?.string, !legality.reasons.contains(where: { $0.origin.description == b || $0.because == b }) {
                    wrong.append("\(key) \(b)")
                }
            }
            // Task 32: a refused combination rests on its refusing entries' rulings and, as a
            // `notOffered` choice does, on those of its choices' offers (TZ.17).
            let rulings = legality.reasons.flatMap(\.rulings) + (legality.allowed ? [] : choices.flatMap { view.offerRulings[$0] ?? [] })
            if let r = e["ruling"].map(strings), !r.allSatisfy({ rulingMatches($0, rulings) }) {
                wrong.append("ruling \(r)")
            }
            if !wrong.isEmpty {
                out.append(Mismatch(kind: .legal, detail: "combination \(choices): expected \(wrong.joined(separator: ", ")), got allowed \(legality.allowed) "
                                    + legality.reasons.map { "\($0.origin) \($0.because ?? "")" }.joined(separator: "; "), names: names))
            }
        }
        return out
    }

    /// Task 31: `exclusive: [{ choices, ruling, because }]`: the choices may not be taken together
    /// (`Engine.legality(ofCombination:)` refuses them), resting on the `ruling`.
    static func exclusive(_ raw: JSONValue, _ view: LegalView) -> [Mismatch] {
        guard let list = raw.arrayValue else { return [.shape("situation legal exclusive", "legal exclusive \(raw) is not a list")] }
        var out: [Mismatch] = []
        for entry in list {
            guard let e = entry.objectValue, let choices = e["choices"]?.arrayValue?.compactMap(\.string),
                  Set(e.keys).isSubset(of: ["choices", "because", "ruling"]), let legality = view.combinations[choices] else {
                out.append(.shape("situation legal exclusive", "legal exclusive entry \(entry) is not modelled"))
                continue
            }
            let names = [e["because"]?.string].compactMap { $0 } + (e["ruling"].map(strings) ?? [])
            var wrong: [String] = []
            if legality.allowed { wrong.append("refused") }
            if let b = e["because"]?.string, !legality.reasons.contains(where: { $0.origin.description == b || $0.because == b }) {
                wrong.append("because \(b)")
            }
            if let r = e["ruling"].map(strings), !r.allSatisfy({ x in legality.reasons.contains { rulingMatches(x, $0.rulings) } }) {
                wrong.append("ruling \(r)")
            }
            if !wrong.isEmpty {
                out.append(Mismatch(kind: .legal, detail: "exclusive \(choices): expected \(wrong.joined(separator: ", ")), got allowed \(legality.allowed)",
                                    names: names))
            }
        }
        return out
    }

    /// `offered` / `notOffered`: by choice and origin clause (bridge 8). A choice is offered when
    /// an offer of it is legal; `choice.option` is that option of the offer, offered when the
    /// offer lists it and does not refuse it.
    ///
    /// A `notOffered` with `because` / `ruling` needs a reason that says so: an illegal offer
    /// whose refusals hold the `because` (by origin or text) and rest on the `ruling`; or, for an
    /// offer that is not there, a `suppressed` entry on its offering clause whose suppressor is
    /// the `because`. When neither can be found the case cannot be decided: an unsupported shape.
    /// The `offered` fields `OfferedChoice` models (R47); every other field is an unsupported shape.
    static let offeredFields: Set<String> = ["choice", "from", "ruling", "options", "max", "costs", "via", "default", "kind", "on"]
    static let notOfferedFields: Set<String> = ["choice", "from", "because", "ruling"]

    static func offer(_ entry: JSONValue, wanted: Bool, in pool: [OfferedChoice], notApplied: [NotApplied],
                      offering: [String: [ClauseRef]], rerolls: [RerollOffer]? = nil, book: RuleBook? = nil,
                      screen: String? = nil) -> [Mismatch] {
        let key = wanted ? "offered" : "notOffered"
        if let rerolls, let o = entry.objectValue, o["reroll"] != nil { return reroll(o, wanted: wanted, in: rerolls) }
        guard case .object(let o) = entry, let choice = o["choice"]?.string else {
            // Task 31 fix round 1 (R62): an offered check is compared: the rules ask checks, they
            // offer choices only, so no offer can be it.
            if wanted, let o = entry.objectValue, o["check"] != nil {
                let cause = o["cause"]?.objectValue?["rule"]?.string
                let names = [cause, o["from"]?.string].compactMap { $0 } + (o["ruling"].map(strings) ?? [])
                return [Mismatch(kind: .missingOffer, detail: "expected the check \(o["check"]!) offered: an offer offers a choice, a check is asked",
                                 names: names)]
            }
            return [.shape("offer without a choice", "\(key) entry without a choice \(entry.objectValue.map { $0.keys.sorted() } ?? []) is the action layer's")]
        }
        if let f = o["from"], f.string == nil { return [.shape("malformed offer", "\(key) \(choice): from \(f) is not a string")] }
        if let b = o["because"], b.string == nil { return [.shape("malformed offer", "\(key) \(choice): because \(b) is not a string")] }
        // R47: never ignore a field.
        // Task 31: `kind` (the manoeuvre kind of the offering rule) needs the book.
        let shapes = o.keys.sorted().filter { !(wanted ? offeredFields : notOfferedFields).contains($0) || ($0 == "kind" && book == nil) }
            .map { Mismatch.shape("\(key) field \($0)", "\(key) \(choice): field \($0) \(o[$0]!) is not modelled") }
        return shapes + (offerFindings(o, choice: choice, wanted: wanted, in: pool, notApplied: notApplied, offering: offering, book: book,
                                       screen: screen).map { [$0] } ?? [])
    }

    /// The expected `costs` as (pool, amount): `action`, `{action: 1}`, `{freeAction: 1}`, or a
    /// pool name (`{asp: 2}`). nil when malformed.
    static func costs(_ json: JSONValue) -> [(Pool, Int)]? {
        func pool(_ k: String) -> Pool? {
            switch k {
            case "action": .actions
            case "freeAction": .freeActions
            default: Pool(rawValue: k)
            }
        }
        switch json {
        case .string(let k): return pool(k).map { [($0, 1)] }
        case .object(let o):
            let out = o.keys.sorted().compactMap { k -> (Pool, Int)? in
                guard let p = pool(k), let n = o[k]?.int else { return nil }
                return (p, n)
            }
            return out.count == o.count ? out : nil
        default: return nil
        }
    }

    /// The modelled `offered` fields an offer does not meet (R47): `ruling` (in its rulings),
    /// `options` (each listed and not refused), `max`, `default` (Task 30), `via` (each in its via) and `costs`
    /// (each a `cost` of that pool and constant amount). nil entries are malformed fields.
    static func offerFailures(_ o: [String: JSONValue], _ c: OfferedChoice, book: RuleBook? = nil, screen: String? = nil) -> [String] {
        var out: [String] = []
        // Task 31 fix round 1: `on` is the screen the offer is made on; a hit's is `takeDamage`.
        if let on = o["on"], on.string != screen { out.append("on \(on) (offered on \(screen ?? "no screen of the harness"))") }
        if let k = o["kind"], let book {
            // Task 31: the manoeuvre kind of the offering rule (SA_48's `basismanoever`).
            let have = book.rules[c.origin.rule]?.manoeuvre?["kind"]
            if have != k { out.append("kind \(k) (the offering rule's \(have.map { "\($0)" } ?? "none"))") }
        }
        if let r = o["ruling"].map(strings), !r.allSatisfy({ rulingMatches($0, c.rulings) }) {
            out.append("ruling \(r) (offer rulings \(c.rulings))")
        }
        if let raw = o["options"] {
            let want = (raw.arrayValue ?? [raw]).compactMap(text)
            let have = (c.options ?? []).compactMap(text), refused = c.refused.compactMap { text($0.option) }
            if !want.allSatisfy({ have.contains($0) && !refused.contains($0) }) {
                out.append("options \(want) (offer options \(have), refused \(refused))")
            }
        }
        if let d = o["default"], d != c.default { out.append("default \(d) (offer default \(c.default.map { "\($0)" } ?? "none"))") }
        if let m = o["max"], m.int != c.max { out.append("max \(m) (offer max \(c.max.map(String.init) ?? "none"))") }
        if let via = o["via"].map(strings), !Set(via).isSubset(of: c.via.map(\.description)) {
            out.append("via \(via) (offer via \(c.via.map(\.description)))")
        }
        if let raw = o["costs"] {
            let have: [(Pool, Int?)] = c.costs.compactMap {
                guard case .cost(let k) = $0.payload else { return nil }
                if case .number(let n) = k.amount { return (k.pool, Int(exactly: n)) }
                return (k.pool, nil)
            }
            // R47: a malformed `costs` never passes (offerFindings reports it as the shape
            // "malformed offer" before it gets here).
            guard let want = costs(raw) else {
                out.append("costs \(raw) is no pool and amount (malformed)")
                return out
            }
            if !want.allSatisfy({ w in have.contains { $0.0 == w.0 && $0.1 == w.1 } }) {
                out.append("costs \(raw) (offer costs \(have.map { "\($0.0.rawValue) \($0.1.map(String.init) ?? "?")" }))")
            }
        }
        return out
    }

    static func offerFindings(_ o: [String: JSONValue], choice: String, wanted: Bool, in pool: [OfferedChoice],
                              notApplied: [NotApplied], offering: [String: [ClauseRef]], book: RuleBook? = nil,
                              screen: String? = nil) -> Mismatch? {
        if let raw = o["costs"], costs(raw) == nil {
            return .shape("malformed offer", "offered \(choice): costs \(raw) is no pool and amount")
        }
        if let m = o["max"], m.int == nil { return .shape("malformed offer", "offered \(choice): max \(m) is not a number") }
        if let on = o["on"], on.string == nil { return .shape("malformed offer", "offered \(choice): on \(on) is not a screen") }
        let from = o["from"]?.string, because = o["because"]?.string, ruling = o["ruling"].map(strings)
        let names = [from, because].compactMap { $0 } + (ruling ?? [])
        // Task 31: `from` is the offering clause, or the require that enables its rule for a hero
        // who does not own it (SA_884.P4: the companion's formation), the first of the offer's `via`.
        func enabler(_ ref: ClauseRef) -> Bool {
            book?.rules[ref.rule]?.clauses.first { $0.id == ref.clause }?.effects.contains {
                if case .require(let r) = $0.payload { r.enables == true } else { false }
            } ?? false
        }
        func origin(_ c: OfferedChoice) -> Bool {
            from == nil || c.origin.description == from || (c.via.first.map { $0.description == from && enabler($0) } ?? false)
        }

        var offered = pool.contains { $0.choice == choice && origin($0) && $0.legal }
        var seen = pool.filter { $0.choice == choice && origin($0) }
        var parent = choice, option: String?
        var refusals = seen.filter { !$0.legal }.flatMap(\.reasons)
        if !offered, seen.isEmpty, let dot = choice.firstIndex(of: ".") {
            parent = String(choice[..<dot]); option = String(choice[choice.index(after: dot)...])
            seen = pool.filter { $0.choice == parent && origin($0) }
            offered = seen.contains { c in
                c.legal && (c.options ?? []).contains { text($0) == option } && !c.refused.contains { text($0.option) == option }
            }
            refusals = seen.flatMap { c in (c.legal ? [] : c.reasons) + c.refused.filter { text($0.option) == option }.flatMap(\.reasons) }
        }
        let got = seen.isEmpty ? "not offered"
            : seen.map { "\($0.origin) legal \($0.legal)" + ($0.because.map { " because \($0)" } ?? "") }.joined(separator: "; ")
        if offered != wanted {
            return Mismatch(kind: wanted ? .missingOffer : .unexpectedOffer,
                            detail: "expected \(choice)\(from.map { " from \($0)" } ?? "") \(wanted ? "offered" : "not offered"), got \(got)",
                            names: names)
        }
        if wanted {
            // R47: some legal offer (for `C.O`, one allowing O) meets every modelled field.
            let legal = seen.filter { c in
                c.legal && (option.map { opt in (c.options ?? []).contains { text($0) == opt } && !c.refused.contains { text($0.option) == opt } } ?? true)
            }
            let failures = legal.map { offerFailures(o, $0, book: book, screen: screen) }
            if failures.contains(where: \.isEmpty) { return nil }
            let best = failures.min { $0.count < $1.count } ?? []
            return Mismatch(kind: .wrongOffer, detail: "expected \(choice) offered with \(best.joined(separator: "; "))", names: names)
        }
        guard because != nil || ruling != nil else { return nil }

        func wrong(_ d: String) -> Mismatch { Mismatch(kind: .wrongOffer, detail: "expected \(choice) not offered \(d)", names: names) }
        let expectation = [because.map { "because \($0)" }, ruling.map { "on \($0)" }].compactMap { $0 }.joined(separator: " ")
        if !refusals.isEmpty {
            let rulings = seen.flatMap(\.rulings) + refusals.flatMap(\.rulings)
            let becauseOK = because.map { b in refusals.contains { $0.origin.description == b || $0.because == b } } ?? true
            let rulingOK = ruling.map { $0.allSatisfy { rulingMatches($0, rulings) } } ?? true
            if becauseOK && rulingOK { return nil }
            let why = refusals.map { "\($0.origin) \($0.reason.rawValue)" + ($0.because.map { " (\($0))" } ?? "") + " rulings \($0.rulings)" }
            return wrong("\(expectation), refused by \(why)")
        }
        // Not there at all: suppressed on its offering clause?
        let clauses = from.flatMap(ClauseRef.init).map { [$0] } ?? offering[choice] ?? offering[parent] ?? []
        let suppressed = notApplied.filter { $0.reason == .suppressed && clauses.contains($0.origin) }
        // Task 31: not offered because its own `when` is no (SA_66.V3's "am Anfang der Runde"): a
        // `conditionFalse` entry on its offering clause, when that clause is the `because`.
        let ownWhen = notApplied.filter { $0.reason == .conditionFalse && clauses.contains($0.origin) }
        if suppressed.isEmpty, !ownWhen.isEmpty, let because, ownWhen.contains(where: { $0.origin.description == because || $0.because == because }) {
            let rulingOK = ruling.map { $0.allSatisfy { r in ownWhen.contains { rulingMatches(r, $0.rulings) } } } ?? true
            return rulingOK ? nil : wrong("\(expectation), its own condition is false, resting on \(ownWhen.flatMap(\.rulings))")
        }
        // Task 32: not offered because the offering rule's set is off (TZ.1: `because:
        // trefferzonen.ruleset`, the rule's `ruleset`): a `rulesetOff` entry on its offering clause.
        let off = notApplied.filter { $0.reason == .rulesetOff && clauses.contains($0.origin) }
        if suppressed.isEmpty, !off.isEmpty, let because, because.hasSuffix(".ruleset") {
            let named = off.contains { "\($0.origin.rule).ruleset" == because }
            let rulingOK = ruling.map { $0.allSatisfy { r in off.contains { rulingMatches(r, $0.rulings) } } } ?? true
            return named && rulingOK ? nil : wrong("\(expectation), its rule set is off: \(off.map { "\($0.origin) \($0.because ?? "")" })")
        }
        if !suppressed.isEmpty {
            let becauseOK = because.map { b in suppressed.contains { $0.via.first?.description == b || $0.because == b } } ?? true
            let rulingOK = ruling.map { $0.allSatisfy { r in suppressed.contains { rulingMatches(r, $0.rulings) } } } ?? true
            if becauseOK && rulingOK { return nil }
            return wrong("\(expectation), suppressed by \(suppressed.map { $0.via.first?.description ?? $0.because ?? "?" })")
        }
        return .shape("notOffered reason undecidable",
                      "notOffered \(choice) \(expectation): it is not offered at all, so its reason cannot be checked")
    }

    /// Task 32: an `offered` / `notOffered` entry naming a rule set (`{ ruleset, because, ruling }`,
    /// TZ.25): offered when `Engine.legality(ofRuleset:)` allows it; not offered when it refuses
    /// it, by `because` (clause or text) resting on `ruling`. Any other field is a shape (R47).
    static func rulesetOffer(_ o: [String: JSONValue], slug: String, wanted: Bool, _ legality: Legality) -> [Mismatch] {
        let key = wanted ? "offered" : "notOffered"
        let fields: Set<String> = wanted ? ["ruleset"] : ["ruleset", "because", "ruling"]
        let shapes = o.keys.sorted().filter { !fields.contains($0) }
            .map { Mismatch.shape("\(key) field \($0)", "\(key) ruleset \(slug): field \($0) \(o[$0]!) is not modelled") }
        let because = o["because"]?.string, ruling = o["ruling"].map(strings)
        let names = [because].compactMap { $0 } + (ruling ?? [])
        if legality.allowed == !wanted {
            return shapes + [Mismatch(kind: wanted ? .missingOffer : .unexpectedOffer,
                                      detail: "expected the rule set \(slug) \(wanted ? "offered" : "not offered"), got \(legality.allowed ? "allowed" : "refused by \(legality.reasons.map(\.origin))")",
                                      names: names)]
        }
        guard !wanted else { return shapes }
        let becauseOK = because.map { b in legality.reasons.contains { $0.origin.description == b || $0.because == b } } ?? true
        let rulingOK = ruling.map { $0.allSatisfy { r in legality.reasons.contains { rulingMatches(r, $0.rulings) } } } ?? true
        if becauseOK && rulingOK { return shapes }
        return shapes + [Mismatch(kind: .wrongOffer, detail: "expected the rule set \(slug) not offered because \(because ?? "–") on \(ruling ?? []), refused by "
                                  + legality.reasons.map { "\($0.origin) \($0.rulings)" }.joined(separator: "; "), names: names)]
    }

    /// The `reroll` entry fields a `RerollOffer` models; any other is an unsupported shape (R47).
    static let rerollFields: Set<String> = ["reroll", "from", "ruling", "because"]

    /// A `reroll` offer entry of a check (Task 26): `reroll` names the offering clause (or its
    /// rule), `from` the clause too. Offered: a legal reroll offer resting on each `ruling`. Not
    /// offered: none legal; a `because` needs an illegal one refused by it (by clause or text).
    /// A reroll that is not offered at all cannot show why: an unsupported shape.
    static func reroll(_ o: [String: JSONValue], wanted: Bool, in offers: [RerollOffer]) -> [Mismatch] {
        let key = wanted ? "offered" : "notOffered"
        guard let name = o["reroll"]?.string else { return [.shape("malformed offer", "\(key) reroll \(o["reroll"]!) is not a string")] }
        var out = o.keys.sorted().filter { !rerollFields.contains($0) || ($0 == "because" && wanted) }
            .map { Mismatch.shape("\(key) field \($0)", "\(key) reroll \(name): field \($0) \(o[$0]!) is not modelled") }
        let from = o["from"]?.string, because = o["because"]?.string, ruling = o["ruling"].map(strings)
        let names = [name, from, because].compactMap { $0 } + (ruling ?? [])
        func named(_ r: RerollOffer) -> Bool {
            (r.origin.description == name || (ClauseRef(name) == nil && r.origin.rule == name))
                && (from == nil || r.origin.description == from)
        }
        let seen = offers.filter(named)
        let legal = seen.filter(\.legal)
        let got = seen.isEmpty ? "not offered" : seen.map { "\($0.origin) legal \($0.legal)" + ($0.because.map { " because \($0)" } ?? "") }
            .joined(separator: "; ")
        if legal.isEmpty == wanted {
            out.append(Mismatch(kind: wanted ? .missingOffer : .unexpectedOffer, query: "check.dice",
                                detail: "expected reroll \(name)\(from.map { " from \($0)" } ?? "") \(wanted ? "offered" : "not offered"), got \(got)",
                                names: names))
            return out
        }
        if wanted, let ruling, !legal.contains(where: { r in ruling.allSatisfy { rulingMatches($0, r.rulings) } }) {
            out.append(Mismatch(kind: .wrongOffer, query: "check.dice", detail: "expected reroll \(name) on \(ruling), got \(got)", names: names))
        }
        if !wanted, because != nil || ruling != nil {
            let refusals = seen.flatMap(\.reasons)
            if refusals.isEmpty {
                out.append(.shape("notOffered reason undecidable", "notOffered reroll \(name): it is not offered at all, so its reason cannot be checked"))
            } else {
                let becauseOK = because.map { b in refusals.contains { $0.origin.description == b || $0.because == b } } ?? true
                let rulingOK = ruling.map { $0.allSatisfy { r in refusals.contains { rulingMatches(r, $0.rulings) } } } ?? true
                if !(becauseOK && rulingOK) {
                    out.append(Mismatch(kind: .wrongOffer, query: "check.dice",
                                        detail: "expected reroll \(name) not offered because \(because ?? "–") on \(ruling ?? []), refused by "
                                            + "\(refusals.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") })", names: names))
                }
            }
        }
        return out
    }

    /// `texts`: an entry matches a text by origin (`from`), open ruling (`ruling`) and, for an
    /// audience key (`player`, `gm`, `opponent`) with a string, that audience and exact text.
    /// `[]` asserts no `tell`. Other keys, a structured text or a malformed field are unsupported
    /// shapes.
    static func texts(_ entries: [JSONValue], in actual: [TextLine]) -> [Mismatch] {
        var out: [Mismatch] = []
        let tells = actual.filter { $0.kind == .tell }
        if entries.isEmpty, !tells.isEmpty {
            out.append(Mismatch(kind: .unexpectedText, detail: "expected no tell, got \(tells.map { "\($0.origin.map(\.description) ?? "–"): \($0.text)" })"))
        }
        for e in entries {
            guard case .object(let o) = e else { out.append(.shape("text shape", "text \(e)")); continue }
            let other = o.keys.filter { !["from", "ruling"].contains($0) && Audience(rawValue: $0) == nil }
            let audience = o.keys.compactMap(Audience.init(rawValue:)).first
            let malformed = ["from", "ruling"].contains { o[$0] != nil && o[$0]?.string == nil }
            if !other.isEmpty || malformed || audience.map({ o[$0.rawValue]?.string == nil }) == true {
                // Task 31 fix round 1 (R62): a structured text from a clause is compared with that
                // clause's texts, which are plain: it never matches.
                if !malformed, let from = o["from"]?.string {
                    let near = actual.filter { $0.origin?.description == from }.map { "\($0.kind.rawValue) \($0.audience.rawValue): \($0.text)" }
                    out.append(Mismatch(kind: .missingText, detail: "expected the structured text \(e); the rules' texts from \(from) are plain: "
                                        + (near.isEmpty ? "none" : "\(near)"), names: [from] + [o["ruling"]?.string].compactMap { $0 }))
                    continue
                }
                out.append(.shape("text shape", "text \(o.keys.sorted()) \(e): only from, ruling and a plain audience text are matched"))
                continue
            }
            let from = o["from"]?.string, ruling = o["ruling"]?.string
            let hit = actual.contains { t in
                (from == nil || t.origin?.description == from)
                    && (ruling == nil || t.ruling.map { rulingMatches(ruling!, [$0]) } == true)
                    && (audience == nil || (t.audience == audience && t.text == o[audience!.rawValue]?.string))
            }
            if !hit {
                let near = actual.filter { from == nil || $0.origin?.description == from }
                    .map { "\($0.kind.rawValue) \($0.audience.rawValue): \($0.text)" }
                out.append(Mismatch(kind: .missingText, detail: "expected text \(e), got \(near.isEmpty ? "none from there" : "\(near)")",
                                    names: [from, ruling].compactMap { $0 }))
            }
        }
        return out
    }

    // MARK: - Showing

    static func show(_ lines: [Line]) -> String {
        "[" + lines.map { l in
            var s = "\(l.origin.map(\.description) ?? (l.owner?.rawValue ?? "?")) \(l.kind.rawValue) \(l.value)"
            if let was = l.was, let now = l.now { s += " (\(was)→\(now))" }
            if !l.via.isEmpty { s += " via \(l.via.map(\.description))" }
            if !l.rulings.isEmpty { s += " rulings \(l.rulings)" }
            if let t = l.term { s += " term \(t)" }
            return s
        }.joined(separator: ", ") + "]"
    }

    static func describe(_ e: ExpectedLine) -> String {
        var parts: [String] = []
        if let f = e.from { parts.append("from \(f)") }
        if let v = e.value { parts.append("value \(v)") }
        if let k = e.kind { parts.append("kind \(k)") }
        if let w = e.was { parts.append("was \(w)") }
        if let v = e.via { parts.append("via \(v)") }
        if let r = e.ruling { parts.append("ruling \(r)") }
        if let s = e.source { parts.append("source \(s)") }
        if let t = e.term { parts.append("term \(t)") }
        return "{" + parts.joined(separator: ", ") + "}"
    }

    static func describe(_ e: ExpectedNotApplied) -> String {
        var parts: [String] = []
        if let r = e.reason { parts.append("reason \(r)") }
        if let b = e.because { parts.append("because \(b)") }
        if let r = e.ruling { parts.append("ruling \(r)") }
        if let v = e.value { parts.append("value \(v)") }
        return "{" + parts.joined(separator: ", ") + "}"
    }

    static func text(_ v: JSONValue) -> String? {
        switch v {
        case .string(let s): s
        case .int(let i): String(i)
        case .bool(let b): String(b)
        default: nil
        }
    }
}

// MARK: - R41: which open rulings could explain a mismatch

enum Explainer {
    /// Whether the open ruling `hit` met could explain `m` (R41, tightened by R46):
    /// - the expectation names the ruling, or the clause or rule its effect sits on;
    /// - its effect (the clause's effect resting on the ruling) reaches the mismatched query's
    ///   target, or a target that target reads through the operand chain (R48), by a non-`*`
    ///   reach entry;
    /// - `m` is about offers / questions / texts and the effect is a `*` offer / ask / tell.
    ///
    /// With a book, the explaining effect must be live (R46): its `when` (and, for a ruling on a
    /// nested effect, the nested effect's) is not `no` in `situation`, read with `Conditions`.
    /// `*`-indexed open-ruling texts alone never explain a value mismatch. An unsupported shape
    /// is explained by nothing.
    /// Whether an expectation's `name` names the open ruling `ruling` met on a clause of `rule`:
    /// the qualified id, or a short id (no dot) that is the shared ruling's or `rule`'s own.
    static func names(_ name: String, ruling: String, rule: String) -> Bool {
        name == ruling || (!name.contains(".") && (ruling == "shared.\(name)" || ruling == "\(rule).\(name)"))
    }

    static func explains(_ hit: OpenHit, _ m: Mismatch, book: RuleBook?, situation: Situation) -> Bool {
        guard m.area != .shape else { return false }
        guard let o = hit.origin else { return m.names.contains(hit.ruling) }
        // A ruling as a situation writes it: qualified, or by its short id (Task 31) — a shared
        // ruling (`round-up` is `shared.round-up`) or one of the rule the hit's clause sits on,
        // never another rule's ruling of the same short id.
        let named = m.names.contains { names($0, ruling: hit.ruling, rule: o.rule) } || m.names.contains(o.description)
            || m.names.contains(o.rule)
        guard let book else { return named }
        // The top-level effects of the clause that rest on the ruling and are live.
        let live = { (e: EffectOrigin) in
            e.rule == o.rule && e.clause == o.clause
                && (book.effect(at: e).map { self.live($0, on: hit.ruling, in: situation) } ?? false)
        }
        let clauseEffects = book.rules[o.rule]?.clauses.flatMap(\.effects).filter { $0.origin.clause == o.clause } ?? []
        if named { return clauseEffects.contains { live($0.origin) } }
        if let q = m.query, operandChain(TargetRef(q).name, book).contains(where: { (book.reach[$0] ?? []).contains(where: live) }) {
            return true
        }
        // Task 31 (R48 through a named clause): the targets the effects of a clause the mismatch
        // names read, and their operand chains (trefferzonen.TZ8's Wundeffekt check reads the
        // Wundschwelle, on which ADV_54.E1 rests on eisern-scope: boronmir-neu 19.7).
        let namedEffects = m.names.compactMap(ClauseRef.init).flatMap { c in
            book.rules[c.rule]?.clauses.first { $0.id == c.clause }?.effects ?? []
        }
        let read = namedEffects.flatMap { operandTargets($0.payload) }.distinct()
        if read.flatMap({ operandChain($0, book) }).contains(where: { (book.reach[$0] ?? []).contains(where: live) }) {
            return true
        }
        let verb: Verb? = switch m.area {
        case .offers: .offer
        case .questions: .ask
        case .texts: .tell
        default: nil
        }
        guard let verb else { return false }
        return (book.reach["*"] ?? []).contains { live($0) && book.effect(at: $0)?.payload.verb == verb }
    }

    /// R48: `target` and every target it reads through the R26 operand chain: the targets the
    /// values of the effects reaching it read (a derive's terms, an add's or set's value, a cap's
    /// bounds, a table key that is a target), and theirs in turn (`check.qs` → `check.fp` →
    /// `check.fw`). `*` entries are not followed.
    static func operandChain(_ target: String, _ book: RuleBook) -> [String] {
        var out = [target], i = 0
        while i < out.count {
            for origin in book.reach[out[i]] ?? [] {
                guard let e = book.effect(at: origin) else { continue }
                for t in operandTargets(e.payload) where !out.contains(t) { out.append(t) }
            }
            i += 1
        }
        return out
    }

    static func operandTargets(_ p: Payload) -> [String] {
        let values: [ValueExpr]
        switch p {
        case .add(let a): values = [a.value]
        case .set(let s): values = [s.value]
        case .derive(let d): values = d.sum
        case .cap(let c): values = [c.max, c.min].compactMap { $0 }
        case .floor(let f): values = [f.min]
        case .replace(let r): values = [r.with]
        case .check(let c): values = [c.modifier].compactMap { $0 }
        default: values = []
        }
        return values.flatMap(\.targets).map(\.name)
    }

    /// Whether `e`, or an effect nested in it, rests on `ruling` with every `when` on the way not
    /// `no` (R46).
    static func live(_ e: Effect, on ruling: String, in situation: Situation) -> Bool {
        if let w = e.when, Conditions.evaluate(w, in: situation, rule: e.origin.rule).truth == .no { return false }
        return e.ruling.contains(ruling)
            || e.payload.nested.contains { $0.effects.contains { live($0, on: ruling, in: situation) } }
    }

    /// R46: the rulings explaining the mismatches when every one of them is explained by a hit on
    /// the situation's static pending list (sorted); nil when any mismatch is unexplained.
    static func explaining(_ hits: [OpenHit], _ mismatches: [Mismatch], pending: [String], book: RuleBook?,
                           situation: Situation) -> [String]? {
        let open = hits.filter { Set(pending).contains($0.ruling) }
        var rulings: Set<String> = []
        for m in mismatches {
            let by = open.filter { explains($0, m, book: book, situation: situation) }
            if by.isEmpty { return nil }
            rulings.formUnion(by.map(\.ruling))
        }
        return rulings.isEmpty ? nil : rulings.sorted()
    }
}

extension JSONValue {
    var arrayValue: [JSONValue]? { if case .array(let a) = self { a } else { nil } }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { o } else { nil } }
}

extension Array where Element: Hashable {
    func distinct() -> [Element] { var seen: Set<Element> = []; return filter { seen.insert($0).inserted } }
}
