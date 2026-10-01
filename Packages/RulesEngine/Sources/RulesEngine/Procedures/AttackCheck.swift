import Foundation

// Ruling R72: an encoded attack check (`check: { of: { attack: X, with: mount } }`: a mount's
// attack on an order) is asked as a 3W20 check is: the action gives it, with the attack's values
// from the profile row the rules provide, and the caller rolls it.

/// An attack a rule asks for: the attack's name (`Tritt`, read from a choice when the rule names
/// one: `choice.mountAttack`), who makes it (`mount`), its AT and TP from the row of
/// `<by>.attacks` an applying rule provides (svellttaler-kaltblut.SK3), and the clauses behind it.
public struct PendingAttack: Hashable, Sendable {
    public var origin: ClauseRef
    /// nil while the choice naming it is not made.
    public var attack: String?
    public var by: String?
    public var at: Int?
    public var tp: String?
    public var rulings: [String]
    /// The clauses its rule rests on, and the clause providing the attack's row.
    public var via: [ClauseRef]
    public var facts: [FactUse]

    public init(origin: ClauseRef, attack: String?, by: String?, at: Int?, tp: String?, rulings: [String] = [],
                via: [ClauseRef] = [], facts: [FactUse] = []) {
        self.origin = origin; self.attack = attack; self.by = by; self.at = at; self.tp = tp
        self.rulings = rulings; self.via = via; self.facts = facts
    }
}

extension Evaluation {
    /// The top-level attack checks among the book's effects that `asking` selects, read as the
    /// pipeline reads an effect (the rule applies, no suppress, the `when` is yes), in rule-id and
    /// clause order. What did not act is recorded in `records`.
    func attacksCalledFor(_ records: inout PipelineState, asking: (Effect) -> Bool) -> [PendingAttack] {
        let all = book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        var out: [PendingAttack] = []
        for e in all {
            guard case .check(let c) = e.payload, c.of.kind == .attack, asking(e), applies(e, &records),
                  !isSuppressed(e, &records) else { continue }
            let rule = e.origin.rule
            var via = ruleVia(rule, records)
            guard let used = gate(e, level: ruleLevel(rule, levels: [:], depth: 0), via: via, &records) else { continue }
            var facts = used
            var name = c.of.ids.compactMap(\.id).first
            if let id = name, id.hasPrefix("choice.") {
                let f = situation.fact(id)
                if let f { facts.append(f) }
                name = f?.value.string
            }
            let by = c.of.with?.first
            var at: Int?, tp: String?
            if let by, let name {
                let rows = book.providers(of: "\(by).attacks").filter {
                    book.rules[$0.rule]?.kind != .equipment && applicability(of: $0.rule, depth: 0).applies
                }
                for p in rows {
                    guard case .array(let list) = p.value,
                          let row = list.compactMap({ v -> [String: JSONValue]? in if case .object(let o) = v { o } else { nil } })
                            .first(where: { $0["name"]?.string == name }) else { continue }
                    at = row["at"]?.int
                    tp = row["tp"]?.string
                    via.append(p.origin.clauseRef)
                    break
                }
            }
            out.append(PendingAttack(origin: e.origin.clauseRef, attack: name, by: by, at: at, tp: tp, rulings: decided(e),
                                     via: via.uniqued(), facts: facts.uniqued()))
        }
        return out
    }
}
