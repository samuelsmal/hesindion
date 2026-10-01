import Foundation

// The sheet's loadout facts (Task 30, R61: a fact the sheet derives is derived). A situation
// names the items the hero carries (`loadout.weapon: Rabenschnabel`); the rules read what the
// items are: the piece a roll is made with (`item.atMod`), a slot's field
// (`loadout.weapon.technique`), the KtW of the technique in hand (`ktw.current`) and the value
// of its Leiteigenschaft (`technique.leit`). Each is derived here when the situation does not
// state it, from the facts it states and the equipment rows (`provides`) of the items'
// templates.

/// A derived fact's value, the facts and clauses it rests on, and what it lacks when unknown.
struct Derived {
    var value: JSONValue?
    var used: [FactUse] = []
    var via: [ClauseRef] = []
    var unknown: [UnknownFact] = []

    static func lacking(_ unknown: [UnknownFact]) -> Derived { Derived(value: nil, unknown: unknown) }
}

/// The piece a roll is made with: the slot it is in (when it is in one), the item, or a
/// technique without an item (Raufen with bare hands). All nil: unknown.
struct Piece {
    var slot: String?
    var item: String?
    var technique: String?
    /// The facts that named it.
    var used: [FactUse] = []
    /// Why it is not known.
    var unknown: [UnknownFact] = []
    /// A slot stated empty (`loadout.weapon: null`).
    var empty = false
}

extension RuleBook {
    /// The equipment rule an item is: `item.<name>.template` when the situation states it, else
    /// the one equipment rule whose `name` is the item's (Task 30). nil when neither says.
    func template(ofItem name: String, in situation: Situation) -> String? {
        if let stated = situation.facts["item.\(name).template"]?.value.string { return stated }
        let named = rules.values.filter { $0.kind == .equipment && $0.name == name }
        return named.count == 1 ? named[0].id : nil
    }
}

extension Evaluation {
    /// The loadout facts `Loadout.swift` derives, by name.
    static func isLoadoutFact(_ name: String) -> Bool {
        if ["ktw.current", "technique.leit"].contains(name) { return true }
        let parts = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 2, parts[0] == "item" { return true }
        if parts.count == 3 { return parts[0] == "loadout" && parts[2] != "instance" && Vocabulary.facts["loadout.\(parts[1])"] == .loadout }
        // Task 32: a field of a slot in a loadout family (`loadout.armourPiece.kopf.rs`: the RS of
        // the piece worn on the head, trefferzonen-ruestungsschutz.RS2).
        return parts.count == 4 && parts[0] == "loadout" && parts[3] != "instance" && !parts.contains("")
            && Vocabulary.facts["loadout.\(parts[1]).\(parts[2])"] == nil
            && Vocabulary.owner(ofFact: "loadout.\(parts[1]).\(parts[2])") == .loadout
    }

    /// The tables the loadout reads a fact from (`readBy: loadout`): `technique.leit` is the value
    /// of the technique's Leiteigenschaft, the higher of two (kampfwerte.KW21, KW7).
    static let loadoutTables: [String: String] = ["technique.leit": "kampfwerte.leiteigenschaft",
                                                  "technique.leit.higher": "kampfwerte.hoehereLeiteigenschaft",
                                                  "technique.name": "kampfwerte.kampftechnik"]

    /// A technique's forms, its id and its name (`CT_5`, `Hiebwaffen`), as the loadout table
    /// `kampfwerte.kampftechnik` pairs them: an equipment row names the technique by id, a
    /// situation and the Leiteigenschaft table by name. The table's clause, when it paired them.
    func techniqueForms(_ t: String) -> (forms: [String], via: [ClauseRef]) {
        let providers = book.providers(of: Self.loadoutTables["technique.name"]!)
        guard providers.count == 1, case .object(let table) = providers[0].value else { return ([t], []) }
        if let name = table[t]?.string { return ([t, name], [providers[0].origin.clauseRef]) }
        if let id = table.first(where: { $0.value == .string(t) })?.key { return ([t, id], [providers[0].origin.clauseRef]) }
        return ([t], [])
    }

    /// A technique in its id form (`Peitschen` → `CT_8`), as the rules compare it; a technique
    /// the table does not pair is kept as it is.
    func techniqueId(_ t: String) -> String {
        let providers = book.providers(of: Self.loadoutTables["technique.name"]!)
        guard providers.count == 1, case .object(let table) = providers[0].value else { return t }
        if table[t] != nil { return t }
        return table.first(where: { $0.value == .string(t) })?.key ?? t
    }

    /// Whether a fact names a technique (`loadout.<slot>.technique`), which reads in its id form.
    static func isTechniqueFact(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        return parts.count == 3 && parts[0] == "loadout" && parts[2] == "technique"
    }

    /// The KtW of a technique in either form, as the sheet states it.
    func ktw(_ t: String, in s: Situation) -> Fact? {
        techniqueForms(t).forms.lazy.compactMap { s.facts["ktw.\($0)"] }.first
    }

    /// A loadout fact of `s` (the situation with the query's own facts): see the file's head.
    /// - `loadout.<slot>.<field>`: of the item in the slot (`loadout.other`: the piece besides
    ///   the Hauptwaffe that `loadout.other` names, a shield or the Parierwaffe);
    /// - `item.<field>`: of the piece the roll is made with (`piece`);
    /// - `ktw.current`: `ktw.<technique>` of that piece's technique;
    /// - `technique.leit`: the higher value of the attributes the loadout table names for it.
    /// An item's field is `item.<item>.<field>` when stated, else its template's row (the
    /// `provide` of the rule's `provides`, which joins `via`), else a `provide` of the template
    /// named `loadout.<slot>.<field>` (the Großschild's `loadout.shield.size`), else what the rules
    /// give every piece in the slot (`slotDatum`: SCH3's shield technique).
    func loadoutFact(_ name: String, in s: Situation) -> Derived {
        switch name {
        case "ktw.current":
            let p = piece(in: s)
            let t = technique(of: p, in: s)
            guard let technique = t.value?.string else { return .lacking(p.unknown + t.unknown) }
            guard let ktw = ktw(technique, in: s) else { return .lacking([UnknownFact("ktw.\(technique)")]) }
            return Derived(value: ktw.value, used: (p.used + t.used + [use(ktw)]).uniqued(), via: t.via)
        case "technique.leit":
            let p = piece(in: s)
            let t = technique(of: p, in: s)
            guard let technique = t.value?.string else { return .lacking(p.unknown + t.unknown) }
            return leiteigenschaft(of: technique, in: s, base: Derived(value: nil, used: p.used + t.used, via: t.via))
        default:
            break
        }
        let parts = name.split(separator: ".").map(String.init)
        let p = parts.count == 2 ? piece(in: s) : slotPiece(parts.dropFirst().dropLast().joined(separator: "."), in: s)
        var d = field(parts.last!, of: p, in: s)
        d.used = (p.used + d.used).uniqued()
        if d.value == nil {
            // An item no rule describes: the fact itself is asked, as without the loadout.
            d.unknown = d.unknown.map { $0.name.hasPrefix("item.") && $0.name.hasSuffix(".\(parts.last!)") ? UnknownFact(name) : $0 }
        }
        return d
    }

    /// The piece a roll is made with: `action.with` (stated, or the query's `with:`), else the
    /// Hauptwaffe. `mainHand` / `weapon` is the weapon slot, `shield` the shield slot, `offHand` /
    /// `parryingWeapon` the piece besides the Hauptwaffe; an item a slot holds is that item; a
    /// technique the hero has a KtW in (`Raufen`) is that technique without an item.
    func piece(in s: Situation) -> Piece {
        guard let with = s.facts["action.with"] else { return slotPiece("weapon", in: s) }
        guard let name = with.value.string else { return Piece(unknown: []) }
        var p: Piece
        switch name {
        case "mainHand", "weapon": p = slotPiece("weapon", in: s)
        case "shield": p = slotPiece("shield", in: s)
        case "offHand", "parryingWeapon": p = slotPiece("other", in: s)
        default:
            if let slot = s.facts.values.first(where: { $0.name.split(separator: ".").count == 2 && $0.name.hasPrefix("loadout.")
                && $0.value == .string(name) }) {
                p = Piece(slot: String(slot.name.dropFirst("loadout.".count)), item: name, used: [use(slot)])
            } else if ktw(name, in: s) != nil {
                p = Piece(technique: name)
            } else {
                p = Piece(item: name)
            }
        }
        p.used.insert(use(with), at: 0)
        return p
    }

    /// The item in `slot`: `loadout.<slot>`; for `other`, the piece `loadout.other` names besides
    /// the Hauptwaffe: the shield (`loadout.shield`) or the Parierwaffe (the item stated
    /// `item.<item>.parryingWeapon: true`).
    func slotPiece(_ slot: String, in s: Situation) -> Piece {
        if slot == "other" {
            guard let other = s.facts["loadout.other"] else { return Piece(unknown: [UnknownFact("loadout.other")]) }
            switch other.value.string {
            case "shield":
                var p = slotPiece("shield", in: s)
                p.used.insert(use(other), at: 0)
                return p
            case "parryingWeapon":
                let marked = s.facts.values.filter { f in
                    f.value == .bool(true) && f.name.hasPrefix("item.") && f.name.hasSuffix(".parryingWeapon")
                }.sorted { $0.name < $1.name }
                guard let first = marked.first else { return Piece(used: [use(other)], unknown: []) }
                let item = String(first.name.dropFirst("item.".count).dropLast(".parryingWeapon".count))
                return Piece(item: item, used: [use(other), use(first)])
            default:
                return Piece(used: [use(other)], unknown: [])
            }
        }
        guard let f = s.facts["loadout.\(slot)"] else { return Piece(slot: slot, unknown: [UnknownFact("loadout.\(slot)")]) }
        guard let item = f.value.string else { return Piece(slot: slot, used: [use(f)], empty: true) }
        return Piece(slot: slot, item: item, used: [use(f)])
    }

    /// A field of a piece: its slot's fact as stated, the item's, then its template's row.
    func field(_ name: String, of p: Piece, in s: Situation) -> Derived {
        if let slot = p.slot, let f = s.fact("loadout.\(slot).\(name)") { return Derived(value: f.value, used: [f]) }
        guard let item = p.item else { return .lacking(p.empty ? [] : p.unknown) }
        if let f = s.fact("item.\(item).\(name)") { return Derived(value: f.value, used: [f]) }
        guard let template = book.template(ofItem: item, in: s), let rule = book.rules[template] else {
            return slotDatum(name, of: p) ?? itemRow(name, of: item) ?? .lacking([UnknownFact("item.\(item).\(name)")])
        }
        if let v = rule.provides[name] {
            let row = rule.clauses.flatMap(\.effects).first { e in
                if case .provide(let pr) = e.payload { return pr.value == .string("provides") } else { return false }
            }
            return Derived(value: v, via: row.map { [$0.origin.clauseRef] } ?? [])
        }
        for e in rule.clauses.flatMap(\.effects) {
            guard case .provide(let pr) = e.payload, pr.name.hasPrefix("loadout."), pr.name.hasSuffix(".\(name)"),
                  pr.name.split(separator: ".").count == 3 else { continue }
            return Derived(value: pr.value, via: [e.origin.clauseRef])
        }
        return slotDatum(name, of: p) ?? .lacking([UnknownFact("item.\(item).\(name)")])
    }

    /// Task 32 (R61: a default the rules state): an item no equipment rule describes, read from a
    /// table of items the loadout reads (`readBy: loadout`), keyed by the item's name, whose row
    /// holds the field (ruestung-und-belastung.A2: the page's armours, `Plattenrüstung` RS 6). One
    /// such table only; its clause joins `via`.
    func itemRow(_ name: String, of item: String) -> Derived? {
        let rows = book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
            .compactMap { e -> Derived? in
                guard case .provide(let pr) = e.payload, pr.readBy == .loadout, case .object(let table) = pr.value,
                      case .object(let row)? = table[item], let v = row[name] else { return nil }
                return Derived(value: v, via: [e.origin.clauseRef])
            }
        return rows.count == 1 ? rows[0] : nil
    }

    /// What the rules give every piece in a slot (schilde.SCH3: an active shield parry is made
    /// with the technique Schilde): a `provide` of a rule that is no equipment, named
    /// `loadout.<slot>.<field>`, when exactly one rule gives it. Its clause joins `via`.
    func slotDatum(_ name: String, of p: Piece) -> Derived? {
        guard let slot = p.slot else { return nil }
        let providers = book.providers(of: "loadout.\(slot).\(name)").filter { book.rules[$0.rule]?.kind != .equipment }
        guard providers.count == 1 else { return nil }
        return Derived(value: providers[0].value, via: [providers[0].origin.clauseRef])
    }

    /// The technique of a piece: a technique without an item, else the stated
    /// `loadout.weapon.technique` of a piece in the weapon slot, else the item's `technique`.
    func technique(of p: Piece, in s: Situation) -> Derived {
        if let t = p.technique { return Derived(value: .string(t)) }
        return field("technique", of: p, in: s)
    }

    /// `technique.leit`: the value of the attribute the loadout table names for the technique
    /// (kampfwerte.KW6: `Schwerter: [GE, KK]`); of two, the higher, where the datum
    /// `kampfwerte.hoehereLeiteigenschaft` says so (KW7). Each clause read joins `via`.
    func leiteigenschaft(of technique: String, in s: Situation, base: Derived) -> Derived {
        let providers = book.providers(of: Self.loadoutTables["technique.leit"]!)
        let forms = techniqueForms(technique)
        guard providers.count == 1, case .object(let table) = providers[0].value,
              let entry = forms.forms.lazy.compactMap({ table[$0] }).first else {
            return .lacking([])
        }
        let names: [String]
        switch entry {
        case .array(let a): names = a.compactMap(\.string)
        case .string(let one): names = [one]
        default: names = []
        }
        var best: FactUse?
        var lacking: [UnknownFact] = []
        for a in names {
            guard let f = s.facts["attr.\(a)"], let v = f.value.double else { lacking.append(UnknownFact("attr.\(a)")); continue }
            if best == nil || v > best!.value.double! { best = use(f) }
        }
        guard lacking.isEmpty, let best else { return .lacking(lacking) }
        var via = base.via + forms.via + [providers[0].origin.clauseRef]
        if names.count > 1 {
            // Of two, the higher: only where the rules say so (kampfwerte.KW7), which joins `via`.
            let higher = book.providers(of: Self.loadoutTables["technique.leit.higher"]!)
            guard higher.count == 1, higher[0].value == .bool(true) else { return .lacking([]) }
            via.append(higher[0].origin.clauseRef)
        }
        return Derived(value: best.value, used: (base.used + [best]).uniqued(), via: via.uniqued())
    }

    private func use(_ f: Fact) -> FactUse { FactUse(name: f.name, value: f.value, owner: f.owner) }

    /// Task 30: the action a hero's combat value query names, as facts every `when` and value of
    /// it reads where the situation states none (MIGRATION kampfwerte 16.1–16.16):
    /// - `action.with`: the piece its `with:` names (`pa(with: shield)`, `at(with: Hiebwaffen)`),
    ///   else `mainHand` for `at`, `pa`, `fk` and `tp`: the sheet's value is the Hauptwaffe's;
    /// - `action.defence` for `pa`: `shieldParry` with the shield, else `weaponParry`; for `aw`:
    ///   `aw` (Task 31, and no `action.with`); for an attack (`at`, `fk`, `tp`): none;
    /// - `loadout.weapon.technique`: a technique its `with:` names (one the hero has a KtW in), by
    ///   its id.
    func combatFacts(of query: Query) -> [String: JSONValue] {
        // Task 31: a dodge is the defence `aw`, made with no piece.
        if query.name == "aw" { return ["action.defence": .string("aw")] }
        guard ["at", "pa", "fk", "tp"].contains(query.name) else { return [:] }
        let with = query.target.context["with"]
        var out: [String: JSONValue] = ["action.with": .string(with ?? "mainHand")]
        // An attack (and its TP) is no defence: `action.defence` is none (Task 31: ZW3's
        // `not: { action.defence: shieldParry }` holds for the attack).
        out["action.defence"] = query.name == "pa" ? .string(with == "shield" ? "shieldParry" : "weaponParry") : .null
        if let with, ktw(with, in: situation) != nil { out["loadout.weapon.technique"] = .string(techniqueId(with)) }
        return out
    }

    /// The technique a hero's combat value query is made with (its piece's, `technique(of:in:)`),
    /// in both its forms (`CT_10`, `Schilde`); empty when it is not known. What a sheet base
    /// stands for when the sheet states it (kampfwerte 16.14: Arbosch's Schilde PA 8).
    func techniqueForms(of query: Query) -> [String] {
        var s = situation
        for (name, value) in combatFacts(of: query) where s.facts[name] == nil {
            s.facts[name] = Fact(name: name, value: value, owner: .derived)
        }
        guard let t = technique(of: piece(in: s), in: s).value?.string else { return [] }
        return techniqueForms(t).forms
    }
}
