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
             .total, .result, .base: .value
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
    static func run(_ s: CompiledSituation, engine: Engine) -> Run {
        let situation = s.engineSituation
        let breakdowns = s.expect.map { engine.evaluate(Query($0.query), in: situation) }
        let wantsOffers = s.expectSituation["offered"] != nil || s.expectSituation["notOffered"] != nil
        var offers: [OfferedChoice] = []
        var hits = openRulings(in: breakdowns) + openRulings(in: breakdowns.flatMap(\.offers))
        if s.expect.isEmpty && wantsOffers {
            offers = engine.offers(in: situation)
            hits += openRulings(in: offers)
            // `offers(in:)` skips an offer resting on an open ruling without a trace; a breakdown
            // of no target (it sees every `*` offer) records it. Only its offers' entries count.
            let offering = Set(offeringClauses(engine.book).values.flatMap { $0 })
            hits += openRulings(in: [engine.evaluate(Query("offers"), in: situation)])
                .filter { $0.origin.map(offering.contains) ?? false }
        }
        let c = compare(s, breakdowns: breakdowns, offers: offers, offering: offeringClauses(engine.book))
        return Run(mismatches: c.mismatches, notes: c.notes, hits: hits.distinct())
    }

    /// Compares `s` with the breakdowns of its expected queries (in `s.expect`'s order) and, for
    /// a situation without a query, `Engine.offers(in:)`. `offering`: choice id → the clauses
    /// that offer it (for a `notOffered` whose offer was suppressed).
    static func compare(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice],
                        offering: [String: [ClauseRef]] = [:]) -> MatchResult {
        var c = MatchResult()
        for (q, b) in zip(s.expect, breakdowns) { query(q, b, &c) }
        situationLevel(s, breakdowns: breakdowns, offers: offers, offering: offering, &c)
        if checkedExpectations(s) == 0 {
            c.mismatches.append(.shape("nothing to compare", "the situation states no expectation the harness checks"))
        }
        return c
    }

    /// How many expectations `s` states that the matcher checks (the action layer's excluded).
    static func checkedExpectations(_ s: CompiledSituation) -> Int {
        let perQuery = s.expect.reduce(0) { n, q in
            n + [q.total != nil, q.result != nil, q.lines != nil, q.notApplied != nil, q.legal != nil, q.base != nil,
                 q.values != nil].filter { $0 }.count
        }
        return perQuery + s.expectSituation.keys.filter { !actionKeys.contains($0) }.count
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

    static func query(_ q: QueryExpectation, _ b: Breakdown, _ c: inout MatchResult) {
        func add(_ kind: Mismatch.Kind, _ detail: String, names: [String] = []) {
            c.mismatches.append(Mismatch(kind: kind, query: q.query, detail: detail, names: names))
        }

        if let expected = q.lines { c.mismatches += lines(expected, b, query: q.query) }
        if let t = q.total {
            // Bridge 2: a derived base counts in the situation's `total` (leMax 37); a sheet base
            // does not (at −5); without a base the total is the lines' sum.
            let derived = b.base.map { $0.owner != .sheet } ?? false
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
        if let legal = q.legal { c.mismatches += self.legal(legal, b.legal, query: q.query) }
        if let base = q.base { c.mismatches += self.base(base, b, query: q.query) }
        if q.values != nil {
            c.mismatches.append(.shape("values", "values (a check's stage values) are not in a breakdown before Task 26", query: q.query))
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
    /// sum, the multiplier in `via`. It matches only an expected line whose `via` names the
    /// multiplier.
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
                            facts: own.flatMap(\.facts) + d.facts, owner: own[0].owner, was: sum)
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
            guard let term = e.term else { continue }
            if let actual = shown[j].term {
                if actual != term {
                    out.append(Mismatch(kind: .wrongTerm, query: query, detail: "expected term \"\(term)\", got \"\(actual)\"",
                                        names: names(e)))
                }
            } else {
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
        if let r = e.ruling, !Set(r).isSubset(of: a.rulings) { out.append(.wrongRuling) }
        if let was = e.was, a.was != was { out.append(.wrongWas) }
        if let k = e.kind, a.kind.rawValue != k { out.append(.wrongKind) }
        if let s = e.source, a.owner?.rawValue != s { out.append(.wrongSource) }
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
    /// its origin.
    static func because(_ b: String, _ n: NotApplied) -> Bool {
        guard isRef(b) else { return n.because == b }
        switch n.reason {
        case .suppressed, .overridden: return n.via.first?.description == b || n.because == b
        case .forbidden: return n.via.first?.description == b || n.because == b || n.origin.description == b
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
            + (e.reason.flatMap { isRef($0) ? [$0] : nil } ?? []) + (e.ruling ?? [])
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
    /// any firing forbid or require is it; `ruling` when any of them rests on it; `span`, `via`
    /// and any other key are not modelled; a malformed value is reported.
    static func legal(_ expected: JSONValue, _ actual: Legality, query: String?) -> [Mismatch] {
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
            for key in o.keys.sorted() where !["allowed", "because", "ruling"].contains(key) {
                out.append(.shape("legal.\(key)", "legal.\(key) is not modelled", query: query))
            }
            return out
        default:
            return [.shape("legal.malformed", "legal \(expected) is not a bool or an object", query: query)]
        }
    }

    /// The query key `base`: `from` is the base's clause or one of its parts', `value` the
    /// base's value, `ruling` and `via` are carried by the base or its parts.
    static func base(_ expected: JSONValue, _ b: Breakdown, query: String) -> [Mismatch] {
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
        if !wrong.isEmpty {
            let names = (from.map { [$0] + [ClauseRef($0)?.rule].compactMap { $0 } } ?? []) + (o["via"].map(strings) ?? [])
                + (o["ruling"].map(strings) ?? [])
            out.append(Mismatch(kind: .base, query: query, detail: "expected base \(wrong.joined(separator: ", ")), got "
                                + (b.base.map { show([$0] + $0.parts) } ?? "no base"), names: names))
        }
        for key in o.keys.sorted() where !["from", "value", "ruling", "via"].contains(key) {
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

    static func situationLevel(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice],
                               offering: [String: [ClauseRef]], _ c: inout MatchResult) {
        let es = s.expectSituation
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
        let pool = noQuery ? offers : breakdowns.flatMap(\.offers)
        let entries = breakdowns.flatMap(\.notApplied)
        for (key, wanted) in [("offered", true), ("notOffered", false)] {
            for entry in list(key) ?? [] {
                c.mismatches += offer(entry, wanted: wanted, in: pool, notApplied: entries, offering: offering)
            }
        }
        if es["notApplied"] != nil, !needsQuery("notApplied") {
            for raw in list("notApplied") ?? [] {
                guard let e = ExpectedNotApplied(raw) else { shape("malformed notApplied", "notApplied entry \(raw) has no rule"); continue }
                notApplied(e, in: entries, query: nil, &c)
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
            let keys = legal.objectValue.map { $0.keys.sorted() } ?? []
            shape("situation legal", "situation-level legal \(keys.isEmpty ? "\(legal)" : "\(keys)") is not modelled")
        }
        for key in es.keys.sorted() where !situationKeys.contains(key) && !actionKeys.contains(key) {
            shape("situation \(key)", "situation-level \(key) is not modelled")
        }
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
    static let offeredFields: Set<String> = ["choice", "from", "ruling", "options", "max", "costs", "via"]
    static let notOfferedFields: Set<String> = ["choice", "from", "because", "ruling"]

    static func offer(_ entry: JSONValue, wanted: Bool, in pool: [OfferedChoice], notApplied: [NotApplied],
                      offering: [String: [ClauseRef]]) -> [Mismatch] {
        let key = wanted ? "offered" : "notOffered"
        guard case .object(let o) = entry, let choice = o["choice"]?.string else {
            return [.shape("offer without a choice", "\(key) entry without a choice \(entry.objectValue.map { $0.keys.sorted() } ?? []) is the action layer's")]
        }
        if let f = o["from"], f.string == nil { return [.shape("malformed offer", "\(key) \(choice): from \(f) is not a string")] }
        if let b = o["because"], b.string == nil { return [.shape("malformed offer", "\(key) \(choice): because \(b) is not a string")] }
        // R47: never ignore a field.
        let shapes = o.keys.sorted().filter { !(wanted ? offeredFields : notOfferedFields).contains($0) }
            .map { Mismatch.shape("\(key) field \($0)", "\(key) \(choice): field \($0) \(o[$0]!) is not modelled") }
        return shapes + (offerFindings(o, choice: choice, wanted: wanted, in: pool, notApplied: notApplied, offering: offering)
            .map { [$0] } ?? [])
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
    /// `options` (each listed and not refused), `max`, `via` (each in its via) and `costs`
    /// (each a `cost` of that pool and constant amount). nil entries are malformed fields.
    static func offerFailures(_ o: [String: JSONValue], _ c: OfferedChoice) -> [String] {
        var out: [String] = []
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
            let want = costs(raw) ?? []
            if !want.allSatisfy({ w in have.contains { $0.0 == w.0 && $0.1 == w.1 } }) {
                out.append("costs \(raw) (offer costs \(have.map { "\($0.0.rawValue) \($0.1.map(String.init) ?? "?")" }))")
            }
        }
        return out
    }

    static func offerFindings(_ o: [String: JSONValue], choice: String, wanted: Bool, in pool: [OfferedChoice],
                              notApplied: [NotApplied], offering: [String: [ClauseRef]]) -> Mismatch? {
        if let raw = o["costs"], costs(raw) == nil {
            return .shape("malformed offer", "offered \(choice): costs \(raw) is no pool and amount")
        }
        if let m = o["max"], m.int == nil { return .shape("malformed offer", "offered \(choice): max \(m) is not a number") }
        let from = o["from"]?.string, because = o["because"]?.string, ruling = o["ruling"].map(strings)
        let names = [from, because].compactMap { $0 } + (ruling ?? [])
        func origin(_ c: OfferedChoice) -> Bool { from == nil || c.origin.description == from }

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
            let failures = legal.map { offerFailures(o, $0) }
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
        if !suppressed.isEmpty {
            let becauseOK = because.map { b in suppressed.contains { $0.via.first?.description == b || $0.because == b } } ?? true
            let rulingOK = ruling.map { $0.allSatisfy { r in suppressed.contains { rulingMatches(r, $0.rulings) } } } ?? true
            if becauseOK && rulingOK { return nil }
            return wrong("\(expectation), suppressed by \(suppressed.map { $0.via.first?.description ?? $0.because ?? "?" })")
        }
        return .shape("notOffered reason undecidable",
                      "notOffered \(choice) \(expectation): it is not offered at all, so its reason cannot be checked")
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
    ///   target by a non-`*` reach entry;
    /// - `m` is about offers / questions / texts and the effect is a `*` offer / ask / tell.
    ///
    /// With a book, the explaining effect must be live (R46): its `when` (and, for a ruling on a
    /// nested effect, the nested effect's) is not `no` in `situation`, read with `Conditions`.
    /// `*`-indexed open-ruling texts alone never explain a value mismatch. An unsupported shape
    /// is explained by nothing.
    static func explains(_ hit: OpenHit, _ m: Mismatch, book: RuleBook?, situation: Situation) -> Bool {
        guard m.area != .shape else { return false }
        guard let o = hit.origin else { return m.names.contains(hit.ruling) }
        let named = m.names.contains(hit.ruling) || m.names.contains(o.description) || m.names.contains(o.rule)
        guard let book else { return named }
        // The top-level effects of the clause that rest on the ruling and are live.
        let live = { (e: EffectOrigin) in
            e.rule == o.rule && e.clause == o.clause
                && (book.effect(at: e).map { self.live($0, on: hit.ruling, in: situation) } ?? false)
        }
        let clauseEffects = book.rules[o.rule]?.clauses.flatMap(\.effects).filter { $0.origin.clause == o.clause } ?? []
        if named { return clauseEffects.contains { live($0.origin) } }
        if let q = m.query, (book.reach[TargetRef(q).name] ?? []).contains(where: live) { return true }
        let verb: Verb? = switch m.area {
        case .offers: .offer
        case .questions: .ask
        case .texts: .tell
        default: nil
        }
        guard let verb else { return false }
        return (book.reach["*"] ?? []).contains { live($0) && book.effect(at: $0)?.payload.verb == verb }
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
