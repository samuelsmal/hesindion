import Foundation

// Phase 7 (legality, spec §5.2), and the player-facing parts of a breakdown (§5.3): the offers
// with their legality, the `tell`s, `ask`s and unencoded clauses. Also the choices a situation
// takes that are not legal, which no line reads (MIGRATION probe-magie 20.4).

/// A legality effect on a choice or a manoeuvre whose rule applies and whose `when` is yes,
/// evaluated once per call: a forbid, an unmet require, or a limit with its max.
struct ChoiceRule {
    enum Kind {
        case forbid(RuleSelector)
        /// A require that is not met: for the choices its selector names, or (nil) for the offers
        /// of its own rule (SA_48.F3: Finte only with these techniques).
        case require(RuleSelector?)
        case limit(RuleSelector, max: Int)
    }

    var effect: Effect
    var kind: Kind
    var facts: [FactUse]
    var via: [ClauseRef]

    var rule: String { effect.origin.rule }

    func entry(_ reason: ReasonCode) -> NotApplied {
        NotApplied(origin: effect.origin.clauseRef, reason: reason, because: effect.because, rulings: effect.ruling,
                   facts: facts, via: via)
    }
}

extension Evaluation {
    // MARK: - Phase 7

    /// Phase 7. The query's action is not allowed when, among the legality effects that reach it
    /// and whose rules apply:
    /// - a `forbid` (not `together`: a combination is the action layer's) whose selector names
    ///   the query or the action the situation declares fires → `forbidden`;
    /// - a `require` `for` such a selector has a `that` that is no → `requirementNotMet` (unknown:
    ///   `unknownFact` and its questions);
    /// - a `limit` on such a selector has its count fact at `max` or above → `forbidden`. The
    ///   count is `round.parries` (parries), `round.dodges` (dodges) or `round.defencesMade`.
    ///
    /// Every entry is kept in `legal.reasons`. Each `when` reads `query.result`, the value after
    /// phase 6: a defence at 0 or below is forbidden by the rule that says so
    /// (mehrfache-verteidigung.MV3), never by the engine.
    func legalityPhase(_ state: inout PipelineState) {
        if state.base != nil {
            state.local["query.result"] = Fact(name: "query.result", value: .int(state.running), owner: .derived)
        }
        for e in state.candidates where e.phase == .legality {
            let selector: RuleSelector
            switch e.payload {
            case .forbid(let f) where f.together != true: selector = f.what
            case .require(let r) where r.enables != true && r.for != nil: selector = r.for!
            case .limit(let l) where l.what.kind != .choice && l.what.kind != .manoeuvre: selector = l.what   // choiceRules
            default: continue
            }
            guard names(selector, state.query), applies(e, &state), !isSuppressed(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            var via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            // Task 31 fix round 2: a provided fact its `when` read joins `via` with its providing
            // clause (GK4 over svellttaler-kaltblut.SK7's `mount.size`), as a value's does.
            via = (via + providedVia(used, depth: state.depth)).uniqued()
            let origin = e.origin.clauseRef
            switch e.payload {
            case .require(let r):
                let c = condition(r.that, level: level, rule: rule, depth: state.depth, local: state.local)
                let facts = (used + c.used).uniqued()
                switch c.truth {
                case .yes: continue
                case .no:
                    forbid(NotApplied(origin: origin, reason: .requirementNotMet, because: e.because, rulings: e.ruling,
                                      facts: facts, via: via), &state)
                case .unknown:
                    state.record(NotApplied(origin: origin, reason: .unknownFact, because: e.because, rulings: e.ruling,
                                            facts: facts, via: via))
                    state.ask(c.unknown, for: origin)
                }
            case .limit(let l):
                guard let count = countFact(of: l.what) else {
                    fail(e, "keine Zählung für \(l.what.kind.rawValue)", &state)
                    continue
                }
                let max = value(l.max, level: level, rule: rule, depth: state.depth)
                guard computed([max], of: e, used: used, via: via, &state, [l.max]), let bound = max.value else { continue }
                let f = fact(count, level: level, rule: rule, depth: state.depth)
                guard let use = f.use else {
                    state.record(NotApplied(origin: origin, reason: .unknownFact, because: e.because, rulings: e.ruling,
                                            facts: used, via: via))
                    state.ask(f.unknown, for: origin)
                    continue
                }
                guard let n = use.value.double else {
                    fail(e, "\(count) ist keine Zahl", &state)
                    continue
                }
                if n >= Double(bound) {
                    forbid(NotApplied(origin: origin, reason: .forbidden, because: e.because, rulings: e.ruling,
                                      facts: (used + [use] + max.used).uniqued(), via: via), &state)
                }
            default:
                forbid(NotApplied(origin: origin, reason: .forbidden, because: e.because, rulings: e.ruling,
                                  facts: used, via: via), &state)
            }
        }
    }

    /// `Engine.legality(ofLoadout:)`: the loadout forbids and requires naming `ids`.
    func loadoutLegality(_ ids: Set<String>) -> Legality {
        let effects = book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        var state = PipelineState(query: Query("loadout"), depth: 0, candidates: effects.filter { $0.phase == .lines })
        control(effects.filter { $0.phase == .legality }, &state)
        for e in effects {
            let selector: RuleSelector
            switch e.payload {
            case .forbid(let f) where f.together != true: selector = f.what
            case .require(let r) where r.enables != true && r.for != nil: selector = r.for!
            default: continue
            }
            guard selector.kind == .loadout, !ids.isDisjoint(with: selector.ids.compactMap(\.id)),
                  applies(e, &state), !isSuppressed(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: [:], depth: 0)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state, asking: false) else { continue }
            if case .require(let r) = e.payload {
                let c = condition(r.that, level: level, rule: rule, depth: 0)
                guard c.truth == .no else { continue }
                forbid(NotApplied(origin: e.origin.clauseRef, reason: .requirementNotMet, because: e.because, rulings: e.ruling,
                                  facts: (used + c.used).uniqued(), via: via), &state)
            } else {
                forbid(NotApplied(origin: e.origin.clauseRef, reason: .forbidden, because: e.because, rulings: e.ruling,
                                  facts: used, via: via), &state)
            }
        }
        return state.legal
    }

    /// `Engine.legality(ofRuleset:)`.
    func rulesetLegality(_ slug: String) -> Legality {
        var state = PipelineState(query: Query("ruleset"), depth: 0, candidates: [])
        state.local = [:]
        for id in book.rules.keys.sorted(by: Self.idOrder) where book.rules[id]!.ruleset == slug {
            for e in book.rules[id]!.clauses.flatMap(\.effects) {
                guard case .require(let r) = e.payload, r.for == nil, r.enables != true else { continue }
                let level = ruleLevel(id, levels: [:], depth: 0)
                guard let used = gate(e, level: level, via: [], &state, asking: false) else { continue }
                let c = condition(r.that, level: level, rule: id, depth: 0)
                guard c.truth == .no else { continue }
                forbid(NotApplied(origin: e.origin.clauseRef, reason: .requirementNotMet, because: e.because, rulings: e.ruling,
                                  facts: (used + c.used).uniqued()), &state)
            }
        }
        return state.legal
    }

    /// `Engine.legality(ofCombination:)`.
    func combinationLegality(_ ids: [String]) -> Legality { combinationBreakdown(ids).legal }

    /// The combination as a breakdown of no target: its `legal`, and the entries of the forbids
    /// it read that did not refuse it (one resting on an open ruling: `openRuling`, and its text).
    func combinationBreakdown(_ ids: [String]) -> Breakdown {
        var state = combinationState()
        let choices = ids.uniqued()
        for r in togetherRefusals(choices, &state) { forbid(r.entry, &state) }
        for r in choiceRules() {
            guard case .limit(let s, let max) = r.kind, named(s, among: choices).count > max else { continue }
            forbid(r.entry(.forbidden), &state)
        }
        return state.breakdown
    }

    /// A breakdown of no target with phase 4's control decided on the legality effects: where a
    /// combination of choices is judged.
    private func combinationState() -> PipelineState {
        let effects = book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        var state = PipelineState(query: Query("combination"), depth: 0, candidates: effects.filter { $0.phase == .lines })
        state.local = [:]
        control(effects.filter { $0.phase == .legality }, &state)
        return state
    }

    /// The choices among `choices` whose offers `selector` names.
    private func named(_ selector: RuleSelector, among choices: [String]) -> [String] {
        choices.filter { c in offers.contains { $0.offer.choice == c && names(selector, offer: $0.offer, of: $0.rule, option: nil) } }
    }

    /// Every top-level `forbid { together: true }` of a rule that applies, not suppressed, whose
    /// `when` is yes, that refuses `choices` taken together: they hold a choice its selector names
    /// and another (one of the holder's own offers, or a second named one). Each with the choices
    /// it refuses (Task 32): the named ones that are not the holder's own offers (SA_172.U3 refuses
    /// the Spezialmanöver beside Unterlaufen, not Unterlaufen); with none of the holder's own among
    /// them, every named one after the first.
    private func togetherRefusals(_ choices: [String], _ state: inout PipelineState) -> [(entry: NotApplied, refused: [String])] {
        var out: [(entry: NotApplied, refused: [String])] = []
        for e in book.rules.keys.sorted(by: Self.idOrder).flatMap({ book.rules[$0]!.clauses.flatMap(\.effects) }) {
            guard case .forbid(let f) = e.payload, f.together == true, applies(e, &state), !isSuppressed(e, &state) else { continue }
            let rule = e.origin.rule
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: ruleLevel(rule, levels: [:], depth: 0), via: via, &state, asking: false) else { continue }
            let them = named(f.what, among: choices)
            let own = choices.filter { c in offers.contains { $0.offer.choice == c && $0.rule == rule } }
            guard !them.isEmpty, Set(them + own).count >= 2 else { continue }
            let refused = own.isEmpty ? Array(them.dropFirst()) : them.filter { !own.contains($0) }
            out.append((NotApplied(origin: e.origin.clauseRef, reason: .forbidden, because: e.because, rulings: e.ruling,
                                   facts: used, via: via), refused))
        }
        return out
    }

    private func forbid(_ entry: NotApplied, _ state: inout PipelineState) {
        state.legal.allowed = false
        if !state.legal.reasons.contains(entry) { state.legal.reasons.append(entry) }
    }

    /// Whether a legality selector names the query's action: the query itself (a `defence`,
    /// `attack` or `check` target, on the same side: `opponent.weaponParry` names
    /// `opponent.pa(with: weapon)`; an `action`, the hero's action queries, R37), or what the
    /// situation declares (`action.defence`, `action.manoeuvre`). `action.attack` states an
    /// attack's outcome (hit, miss), never what is declared.
    func names(_ selector: RuleSelector, _ query: Query) -> Bool {
        switch selector.kind {
        case .action: return selector.ids.contains { action($0, names: query) }
        case .defence where selector.ids.contains(where: { defence($0, names: query) }): return true
        case .attack where selector.ids.contains(where: { attack($0, names: query) }): return true
        case .check where check(selector, names: query): return true
        default: return declared(selector)
        }
    }

    /// `opponent.x` → ("opponent.", "x").
    private func side(_ name: String) -> (side: String, name: String) {
        let prefix = "opponent."
        return name.hasPrefix(prefix) ? (prefix, String(name.dropFirst(prefix.count))) : ("", name)
    }

    /// What a defence id stands for, as rulec indexes it (`compile._defence_targets`): `aw`, `pa`,
    /// or both.
    static func defenceTarget(_ id: String) -> String? {
        let n = id.lowercased()
        if n == "aw" || n.contains("ausweich") || n.contains("dodge") { return "aw" }
        if n == "pa" || n.hasSuffix("parry") || n.hasSuffix("parade") { return "pa" }
        return nil
    }

    /// A defence id names `pa`/`aw` on its side; a parry id with a piece names the parry with it
    /// (`shieldParry`: `with: shield`; `weaponParry`: any other), or the parry with none given.
    private func defence(_ id: SelectorID, names query: Query) -> Bool {
        guard let raw = id.id else { return false }
        let (qSide, qName) = side(query.name), (idSide, idName) = side(raw)
        guard qSide == idSide, qName == "pa" || qName == "aw" else { return false }
        guard let target = Self.defenceTarget(idName) else { return true }
        guard target == qName else { return false }
        let piece = idName.lowercased(), with = query.target.context["with"]
        if piece.hasPrefix("shield") || piece.hasPrefix("schild") { return with == nil || with == "shield" }
        if piece.hasPrefix("weapon") || piece.hasPrefix("waffe") { return with != "shield" }
        return true
    }

    /// An attack id names `at`/`fk` on its side: `any` both, `ranged` fk, `melee` at, else the
    /// query's name or its `with` (`offHand`).
    private func attack(_ id: SelectorID, names query: Query) -> Bool {
        guard let raw = id.id else { return false }
        let (qSide, qName) = side(query.name), (idSide, idName) = side(raw)
        guard qSide == idSide, qName == "at" || qName == "fk" else { return false }
        switch idName {
        case "any": return true
        case "ranged": return qName == "fk"
        case "melee": return qName == "at"
        default: return idName == qName || idName == query.target.context["with"]
        }
    }

    /// R37: an action id names the action queries on its side: `at`, `fk` and `check.*`, never a
    /// defence (a reaction) or a value such as `tp`. Every id (`any`, `aktion`) names all of them.
    private func action(_ id: SelectorID, names query: Query) -> Bool {
        guard let raw = id.id else { return false }
        let (qSide, qName) = side(query.name)
        guard side(raw).side == qSide else { return false }
        return qName == "at" || qName == "fk" || qName.hasPrefix("check.")
    }

    /// A check selector names a `check.*` query whose context (`talent:`, `spell:`) or whose
    /// `check.kind` it lists (fertigkeitsproben.FP2: `talent`, `spell`, `liturgy`).
    private func check(_ selector: RuleSelector, names query: Query) -> Bool {
        guard query.name.hasPrefix("check.") else { return false }
        let ids = Set(selector.ids.compactMap(\.id))
        if !ids.isDisjoint(with: query.target.context.keys) { return true }
        return situation.facts["check.kind"]?.value.string.map(ids.contains) ?? false
    }

    /// A selector names what the situation declares: the value (or any entry) of `action.defence`
    /// or `action.manoeuvre` is one of its ids (or it lists `any`); a manoeuvre match
    /// (`{ kind: spezialmanoever }`) names a declared manoeuvre whose rule has those properties.
    private func declared(_ selector: RuleSelector) -> Bool {
        let facts: [String]
        switch selector.kind {
        case .defence: facts = ["action.defence"]
        case .manoeuvre: facts = ["action.manoeuvre"]
        default: return false
        }
        let values = facts.compactMap { situation.facts[$0]?.value }
            .flatMap { v -> [JSONValue] in if case .array(let a) = v { a } else { [v] } }
            .filter { $0 != .null }
        guard !values.isEmpty else { return false }
        return selector.ids.contains { id in
            switch id {
            case .id(let s): return s == "any" || values.contains(.string(s))
            case .match(let properties):
                return values.contains { v in v.string.map { manoeuvre(named: $0, has: properties) } ?? false }
            }
        }
    }

    /// Whether the manoeuvre `name` (a rule id, or a choice a rule offers) belongs to a rule whose
    /// `manoeuvre` properties include `properties`.
    private func manoeuvre(named name: String, has properties: [String: JSONValue]) -> Bool {
        let rules = book.rules[name].map { [$0] } ?? offers.filter { $0.offer.choice == name }.compactMap { book.rules[$0.rule] }
        return rules.contains { rule in ruleHas(rule.id, properties) }
    }

    private func ruleHas(_ rule: String, _ properties: [String: JSONValue]) -> Bool {
        guard let m = book.rules[rule]?.manoeuvre else { return false }
        return properties.allSatisfy { m[$0.key] == $0.value }
    }

    /// The round fact a defence `limit` counts; nil for any other selector.
    private func countFact(of selector: RuleSelector) -> String? {
        guard selector.kind == .defence else { return nil }
        let ids = selector.ids.compactMap(\.id).map(side)
        guard !ids.isEmpty, ids.allSatisfy({ $0.side.isEmpty }) else { return nil }
        let targets = Set(ids.map { Self.defenceTarget($0.name) ?? "both" })
        if targets == ["pa"] { return "round.parries" }
        if targets == ["aw"] { return "round.dodges" }
        return "round.defencesMade"
    }

    // MARK: - Choices

    /// Every top-level offer in the book, with its rule, in the compiler's order.
    private var offers: [(offer: Offer, effect: Effect, rule: String)] {
        if let memo = offersMemo { return memo }
        let all = book.effects(reaching: "*").compactMap { e -> (offer: Offer, effect: Effect, rule: String)? in
            if case .offer(let o) = e.payload { return (o, e, e.origin.rule) }
            return nil
        }
        offersMemo = all
        return all
    }

    /// The legality effects on choices and manoeuvres (a forbid not `together`, a require `for`
    /// choices or for its own rule's offers, a limit), from the rules that apply, whose `when` is
    /// yes and that rest on no open ruling: the forbids, the requires whose `that` is no, the
    /// limits whose max is computed. Evaluated once per call, with no query.
    func choiceRules() -> [ChoiceRule] {
        if let memo = choiceRulesMemo { return memo }
        var scratch = PipelineState(query: Query("choice"), depth: 0, candidates: [])
        scratch.local = [:]
        var rules: [ChoiceRule] = []
        for e in book.effects(reaching: "*") where e.phase == .legality {
            switch e.payload {
            case .forbid(let f) where f.together != true && [.choice, .manoeuvre, .rule].contains(f.what.kind): break
            case .require(let r) where r.enables != true && (r.for == nil || r.for?.kind == .choice): break
            case .limit(let l) where [.choice, .manoeuvre].contains(l.what.kind): break
            default: continue
            }
            let rule = e.origin.rule
            guard applicability(of: rule, depth: 0).applies else { continue }
            let level = ruleLevel(rule, levels: [:], depth: 0)
            let via = ruleVia(rule, scratch)
            guard let used = gate(e, level: level, via: via, &scratch) else { continue }
            switch e.payload {
            case .forbid(let f):
                rules.append(ChoiceRule(effect: e, kind: .forbid(f.what), facts: used, via: via))
            case .require(let r):
                let c = condition(r.that, level: level, rule: rule, depth: 0)
                guard c.truth == .no else { continue }
                rules.append(ChoiceRule(effect: e, kind: .require(r.for), facts: (used + c.used).uniqued(), via: via))
            case .limit(let l):
                let max = value(l.max, level: level, rule: rule, depth: 0)
                guard let bound = max.value else { continue }
                rules.append(ChoiceRule(effect: e, kind: .limit(l.what, max: bound), facts: (used + max.used).uniqued(), via: via))
            default: continue
            }
        }
        choiceRulesMemo = rules
        return rules
    }

    /// Whether the situation takes the choice `id`: `choice.<id>` is true, a number other than 0,
    /// or a text; for an option (`mod.a`), also `choice.mod` equal to it.
    func isChosen(_ id: String) -> Bool {
        if let v = situation.facts["choice." + id]?.value { return truthy(v) }
        guard let dot = id.lastIndex(of: ".") else { return false }
        let option = String(id[id.index(after: dot)...])
        guard let v = situation.facts["choice." + id[..<dot]]?.value else { return false }
        return text(v) == option
    }

    private func truthy(_ v: JSONValue) -> Bool {
        switch v {
        case .bool(let b): return b
        case .int, .double: return v.double != 0
        case .string(let s): return !s.isEmpty
        case .array(let a): return !a.isEmpty
        case .null, .object: return false
        }
    }

    private func text(_ v: JSONValue) -> String? {
        switch v {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double: return v.int.map(String.init)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    /// Whether `selector` names the offer `o` of `rule`: a choice id equal to it (`doppel`) or
    /// above it (`spellModification` names `spellModification.x`), a manoeuvre id or match its
    /// rule fits, or its rule. With `option`, whether it names that option: the choice id
    /// `<choice>.<option>` (`spellModification.erzwingen`). The manoeuvre id `any` names the offers
    /// of manoeuvre rules only (passierschlag.PS3 forbids every manoeuvre beside the
    /// Passierschlag, not the Passierschlag's own offer: ruling passierschlag-sf).
    private func names(_ selector: RuleSelector, offer o: Offer, of rule: String, option: String?) -> Bool {
        switch selector.kind {
        case .choice:
            let ids = selector.ids.compactMap(\.id)
            if let option { return ids.contains("\(o.choice).\(option)") }
            return ids.contains { o.choice == $0 || o.choice.hasPrefix($0 + ".") }
        case .manoeuvre where option == nil:
            return selector.ids.contains { id in
                switch id {
                case .id(let s): return (s == "any" && book.rules[rule]?.manoeuvre != nil) || s == o.choice || s == rule
                case .match(let properties): return ruleHas(rule, properties)
                }
            }
        case .rule where option == nil:
            return selector.ids.contains { $0.id == rule }
        default:
            return false
        }
    }

    /// The clauses providing the facts among `used` that nobody stated (`Evaluation.providedFact`).
    func providedVia(_ used: [FactUse], depth: Int) -> [ClauseRef] {
        used.filter { $0.owner == .derived && situation.facts[$0.name] == nil }
            .compactMap { providedFact($0.name, depth: depth)?.via.first }.uniqued()
    }

    /// Ruling R67: a line rests on the decided rulings of the live offers of the choices its
    /// effect's `when` reads (trefferzonen.TZ5's zone line reads `choice.targetZone`, which
    /// passierschlag.PS3 offers on the ruling passierschlag-zone during a Passierschlag). An offer
    /// is live when its rule applies, its `when` holds and it rests on no open ruling.
    func offerRulings(reading e: Effect, _ state: PipelineState) -> [String] {
        let choices = (e.when?.factNames ?? []).filter { $0.hasPrefix("choice.") }.map { String($0.dropFirst("choice.".count)) }
        guard !choices.isEmpty else { return [] }
        var out: [String] = []
        // Fix round 2: of an offer with options, only one offering an option the `when` compares
        // the choice with (RK13's `niederreiten`, not RK15's `flucht`).
        let compared = e.when.map { Self.comparedValues($0) } ?? [:]
        for o in offers where choices.contains(o.offer.choice) && !o.effect.ruling.isEmpty {
            if let options = o.offer.options, let values = compared["choice.\(o.offer.choice)"], !values.isEmpty,
               !options.contains(where: { opt in values.contains { Conditions.same($0, opt) } }) { continue }
            guard applicability(of: o.rule, depth: state.depth).applies,
                  !o.effect.ruling.contains(where: { book.rulings[$0]?.status == .open }) else { continue }
            let level = ruleLevel(o.rule, levels: state.levels, depth: state.depth)
            if let when = o.effect.when,
               condition(when, level: level, rule: o.rule, depth: state.depth, local: state.local).truth != .yes { continue }
            out += decided(o.effect)
        }
        return out.uniqued()
    }

    /// The values a condition compares each fact with by `is` / `in`, outside a `not`.
    static func comparedValues(_ c: Condition) -> [String: [JSONValue]] {
        switch c {
        case .all(let cs), .any(let cs):
            return cs.map(comparedValues).reduce(into: [:]) { acc, m in m.forEach { acc[$0.key, default: []] += $0.value } }
        case .not: return [:]
        case .fact(let name, let comparison):
            switch comparison {
            case .is(let v): return [name: [v]]
            case .in(let vs): return [name: vs]
            default: return [:]
            }
        }
    }

    /// Ruling R67: an offer of a manoeuvre rests on the decided rulings of the manoeuvre
    /// legality effects it passed, that fire and do not refuse it (reiterkampf.RK3's forbid of
    /// Spezialmanöver on a mounted Basismanöver: ruling mounted-manoeuvres).
    private func passedRulings(of o: Offer, _ rule: String, _ rules: [ChoiceRule]) -> [String] {
        guard book.rules[rule]?.manoeuvre != nil else { return [] }
        let refusing = Set(refusals(of: o, rule, rules).map(\.origin))
        return rules.filter { r in
            let selector: RuleSelector
            switch r.kind {
            case .forbid(let s), .limit(let s, _): selector = s
            case .require(let s?): selector = s
            case .require(nil): return false
            }
            return selector.kind == .manoeuvre && !refusing.contains(r.effect.origin.clauseRef)
        }.flatMap { decided($0.effect) }.uniqued()
    }

    /// The choices `selector` names that the situation takes, in the selector's order (a
    /// manoeuvre selector: in the offers' order).
    private func chosen(_ selector: RuleSelector) -> [String] {
        switch selector.kind {
        case .choice: return selector.ids.compactMap(\.id).filter(isChosen)
        case .manoeuvre:
            return offers.filter { names(selector, offer: $0.offer, of: $0.rule, option: nil) }.map(\.offer.choice)
                .uniqued().filter(isChosen)
        default: return []
        }
    }

    /// The entries that refuse the offer `o` of `rule` (or, with `option`, that option): a
    /// forbid naming it, a require for it (or its rule's own) not met, a limit naming it whose
    /// count of the other choices taken has reached its max (another one may not be taken).
    private func refusals(of o: Offer, _ rule: String, option: String? = nil, _ rules: [ChoiceRule]) -> [NotApplied] {
        rules.compactMap { r in
            switch r.kind {
            case .forbid(let s):
                return names(s, offer: o, of: rule, option: option) ? r.entry(.forbidden) : nil
            case .require(let s?):
                return names(s, offer: o, of: rule, option: option) ? r.entry(.requirementNotMet) : nil
            case .require(nil):
                return option == nil && r.rule == rule ? r.entry(.requirementNotMet) : nil
            case .limit(let s, let max):
                // Task 31: the other choices taken count, not the offer's own (a chosen Finte is
                // still offered under "one Basismanöver per action"; a second one is not). An
                // option's count is unchanged (Task 23: the options chosen, its own included).
                let others = chosen(s).filter { $0 != o.choice }
                return names(s, offer: o, of: rule, option: option) && others.count >= max ? r.entry(.forbidden) : nil
            }
        }
    }

    /// The offer's bound: the max of the limit naming the most of its options (ties: the first).
    private func bound(of o: Offer, _ rules: [ChoiceRule]) -> Int? {
        let options = Set((o.options ?? []).compactMap(text).map { "\(o.choice).\($0)" })
        guard !options.isEmpty else { return nil }
        var best: (covered: Int, max: Int)?
        for r in rules {
            guard case .limit(let s, let max) = r.kind, s.kind == .choice else { continue }
            let ids = Set(s.ids.compactMap(\.id))
            guard ids.isSubset(of: options) else { continue }
            if ids.count > (best?.covered ?? 0) { best = (ids.count, max) }
        }
        return best?.max
    }

    /// The offers among `effects` whose rules apply and whose `when` is not no (unknown still
    /// offers: an offer asks nothing), each with its legality, bound and refused options. With
    /// `recording`, an offer whose `when` is no, or that rests on an open ruling, is recorded
    /// (and the ruling's text shown) as any effect is.
    func offered(_ effects: [Effect], _ state: inout PipelineState, recording: Bool) -> [OfferedChoice] {
        let rules = choiceRules()
        var out: [OfferedChoice] = []
        for e in effects {
            guard case .offer(let o) = e.payload else { continue }
            let rule = e.origin.rule
            guard recording ? applies(e, &state) && !isSuppressed(e, &state)
                            : applicability(of: rule, depth: state.depth).applies else { continue }
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            let truth = e.when.map { condition($0, level: level, rule: rule, depth: state.depth, local: state.local).truth } ?? .yes
            let open = e.ruling.contains { book.rulings[$0]?.status == .open }
            if recording {
                // No, or an open ruling: recorded (and its text shown) as `gate` records any effect.
                if truth != .unknown || open {
                    guard gate(e, level: level, via: via, &state, asking: false) != nil else { continue }
                }
            } else if truth == .no || open {
                continue
            }
            let refused = (o.options ?? []).compactMap { option -> RefusedOption? in
                guard let t = text(option) else { return nil }
                let reasons = refusals(of: o, rule, option: t, rules)
                return reasons.isEmpty ? nil : RefusedOption(option: option, reasons: reasons)
            }
            out.append(OfferedChoice(choice: o.choice, origin: e.origin.clauseRef, options: o.options, default: o.default,
                                     span: o.span, costs: o.costs, rulings: (decided(e) + passedRulings(of: o, rule, rules)).uniqued(), via: via,
                                     reasons: refusals(of: o, rule, rules),
                                     max: bound(of: o, rules) ?? splitBound(of: o, rule: rule, level: level, depth: state.depth),
                                     refused: refused))
        }
        return out
    }

    /// `Engine.offers(in:)`: every offer in the book, as `offered` gives it, read with no query.
    func allOffers() -> [OfferedChoice] {
        var scratch = PipelineState(query: Query("offers"), depth: 0, candidates: [])
        scratch.local = [:]
        return offered(offers.map(\.effect), &scratch, recording: false)
    }

    /// `situation` less the choices it takes that are not legal, which no line may read
    /// (MIGRATION probe-magie 20.4): a chosen choice (or option) that a forbid or an unmet
    /// require refuses, and the chosen ids of a limit beyond its max, in the limit's order. Each
    /// is stated `false` (0 for a number) by `derived`. nil when it takes none such.
    func withoutRefusedChoices() -> Situation? {
        let rules = choiceRules()
        var refused: [String] = []
        for r in rules {
            switch r.kind {
            case .forbid(let s), .require(let s?):
                if s.kind == .choice {
                    for id in s.ids.compactMap(\.id) {
                        refused += situation.facts.keys.filter { $0 == "choice." + id || $0.hasPrefix("choice.\(id).") }
                            .map { String($0.dropFirst("choice.".count)) }.filter(isChosen)
                    }
                } else {
                    refused += offers.filter { names(s, offer: $0.offer, of: $0.rule, option: nil) }.map(\.offer.choice)
                        .filter(isChosen)
                }
            case .require(nil):
                refused += offers.filter { $0.rule == r.rule }.map(\.offer.choice).filter(isChosen)
            case .limit(let s, let max):
                refused += chosen(s).dropFirst(Swift.max(max, 0))
            }
        }
        // Task 32: a choice a `together` forbid refuses beside the others taken (SA_172.U3: the
        // Gezielter Angriff beside Unterlaufen is not taken, so its halving does not apply).
        let taken = offers.map(\.offer.choice).uniqued().filter(isChosen)
        if taken.count >= 2 {
            var state = combinationState()
            refused += togetherRefusals(taken, &state).flatMap(\.refused)
        }
        guard !refused.isEmpty else { return nil }
        var s = situation
        for id in refused.uniqued() {
            let name = "choice." + id
            guard let f = s.facts[name] else { continue }
            let off: JSONValue = if case .bool = f.value { .bool(false) } else if f.value.double != nil { .int(0) } else { .null }
            s.facts[name] = Fact(name: name, value: off, owner: .derived)
        }
        return s
    }

    // MARK: - Texts and questions

    /// Task 31: on the hero sheet, each action-layer effect every query sees (a `gain`, `cost`,
    /// `item`, `restore` or `check`) of a rule that applies whose `when` is no: an entry
    /// `conditionFalse` (ITEMTPL_19.RS4's Betäubung with the Fokusregel off). One that may act is
    /// the action layer's, and is not listed.
    private func actionEffectsNotApplying(_ state: inout PipelineState) {
        for e in state.candidates {
            switch e.payload {
            case .gain, .cost, .item, .restore, .check: break
            default: continue
            }
            guard let when = e.when, applicability(of: e.origin.rule, depth: state.depth).applies else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let c = condition(when, level: level, rule: rule, depth: state.depth, local: state.local)
            guard c.truth == .no else { continue }
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .conditionFalse, because: e.because, rulings: e.ruling,
                                    facts: c.used, via: ruleVia(rule, state)))
        }
    }

    /// The player-facing parts of a breakdown (depth 0, after phase 7):
    /// - the offers that reach the query (`offered`);
    /// - each applicable `tell` whose `when` is yes → a `.tell` text to its audience (a suppressed
    ///   one is `suppressed`; an unknown `when` asks nothing: a text changes no number);
    /// - each applicable `ask` whose `when` is not no, of a fact nobody stated → a question to
    ///   its `who`, with its options;
    /// - each unencoded clause of an applicable rule with an effect indexed under the query's
    ///   name → an `.unencoded` text of the clause.
    func playerParts(_ state: inout PipelineState) {
        state.offers = offered(state.candidates.filter { if case .offer = $0.payload { true } else { false } }, &state,
                               recording: true)
        for e in state.candidates {
            let origin = e.origin.clauseRef
            switch e.payload {
            case .tell(let t):
                guard applies(e, &state), !isSuppressed(e, &state) else { continue }
                let rule = e.origin.rule
                let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
                guard gate(e, level: level, via: ruleVia(rule, state), &state, asking: false) != nil else { continue }
                state.show(TextLine(kind: .tell, audience: t.to, text: t.text, origin: origin))
            case .ask(let a):
                guard applies(e, &state), !isSuppressed(e, &state) else { continue }
                let rule = e.origin.rule
                let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
                if let when = e.when,
                   condition(when, level: level, rule: rule, depth: state.depth, local: state.local).truth == .no { continue }
                guard fact(a.fact, level: level, rule: rule, depth: state.depth).use == nil else { continue }
                if let i = state.questions.firstIndex(where: { $0.fact == a.fact }) {
                    state.questions[i].owner = a.who
                    state.questions[i].options = a.options ?? state.questions[i].options
                    if !state.questions[i].origins.contains(origin) { state.questions[i].origins.append(origin) }
                } else {
                    state.questions.append(Question(fact: a.fact, owner: a.who, origins: [origin], options: a.options))
                }
            default:
                continue
            }
        }
        if state.query.name == Engine.sheetQuery { actionEffectsNotApplying(&state) }
        let reaching = (book.reach[state.query.name] ?? []).map(\.rule).uniqued()
        for id in reaching where applicability(of: id, depth: state.depth).applies {
            for clause in book.rules[id]?.clauses ?? [] {
                guard case .unencoded = clause.body else { continue }
                let ref = ClauseRef(rule: id, clause: clause.id)
                state.show(TextLine(kind: .unencoded, text: clauseText(ref) ?? clause.text, origin: ref))
            }
        }
    }
}
