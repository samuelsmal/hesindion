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
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
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
    /// count has reached its max (another one may not be taken).
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
                return names(s, offer: o, of: rule, option: option) && chosen(s).count >= max ? r.entry(.forbidden) : nil
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
                                     span: o.span, costs: o.costs, rulings: decided(e), via: via,
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
