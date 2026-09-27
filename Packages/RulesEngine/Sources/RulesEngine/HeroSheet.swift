import Foundation

/// What the app knows about a hero that the sheet's values rest on (domain 1, the cut-over design
/// docs/plans/2026-09-27-sheet-cutover-design.md §2): plain values, no SwiftData. `Situation(sheet:)`
/// turns it into the facts scripts/rulec/hero.py writes for a hero file, plus the loadout.
/// No Zustände and no current LE until domain 4 (design §3).
public struct HeroSheet: Codable, Hashable, Sendable {
    /// A piece the hero owns. `name` is the name the rules know it by: the rule's own name when
    /// `template` names an equipment rule in the book (ITEMTPL_29.GR1 compares names), else the
    /// app's. Without a template, `technique`, `atMod` and `paMod` describe it.
    public struct Item: Codable, Hashable, Sendable {
        public var name: String
        public var template: String?
        public var technique: String?
        public var atMod: Int?
        public var paMod: Int?

        public init(name: String, template: String? = nil, technique: String? = nil,
                    atMod: Int? = nil, paMod: Int? = nil) {
            self.name = name; self.template = template; self.technique = technique
            self.atMod = atMod; self.paMod = paMod
        }
    }

    /// The slots, by item name. `shield` fills `loadout.other: shield` as well.
    public struct Loadout: Codable, Hashable, Sendable {
        public var weapon: String?
        public var shield: String?
        public var armour: String?
        public var armourBelastung: Int
        public var armourExtraPenalty: Int

        public init(weapon: String? = nil, shield: String? = nil, armour: String? = nil,
                    armourBelastung: Int = 0, armourExtraPenalty: Int = 0) {
            self.weapon = weapon; self.shield = shield; self.armour = armour
            self.armourBelastung = armourBelastung; self.armourExtraPenalty = armourExtraPenalty
        }
    }

    public var owned: [String: OwnedRule]
    /// `MU` … `KK` → value.
    public var attributes: [String: Int]
    /// `CT_n` → KtW.
    public var techniques: [String: Int]
    /// `TAL_n` → FW.
    public var talents: [String: Int]
    /// The LE bought with AP (lebensenergie.LE2).
    public var purchasedLE: Int
    /// The species' LE-Grundwert; nil when the app cannot say (the engine then asks).
    public var speciesLE: Int?
    /// The species' GS, the base of `gs`; nil when the app cannot say.
    public var speciesGS: Int?
    public var items: [Item]
    public var loadout: Loadout

    public init(owned: [String: OwnedRule], attributes: [String: Int], techniques: [String: Int],
                talents: [String: Int], purchasedLE: Int, speciesLE: Int?, speciesGS: Int?,
                items: [Item], loadout: Loadout) {
        self.owned = owned; self.attributes = attributes; self.techniques = techniques
        self.talents = talents; self.purchasedLE = purchasedLE; self.speciesLE = speciesLE
        self.speciesGS = speciesGS; self.items = items; self.loadout = loadout
    }

    /// This sheet with `slot` holding `item` (nil empties it): a weapon's own values on the sheet
    /// are the values with that weapon in hand.
    public func with(weapon: String?) -> HeroSheet { var s = self; s.loadout.weapon = weapon; return s }
    public func with(shield: String?) -> HeroSheet { var s = self; s.loadout.shield = shield; return s }
    public func with(armour: String?, belastung: Int, extraPenalty: Int) -> HeroSheet {
        var s = self
        s.loadout.armour = armour
        s.loadout.armourBelastung = belastung
        s.loadout.armourExtraPenalty = extraPenalty
        return s
    }
}

extension Situation {
    /// The situation the sheet states: the hero's facts (owner `sheet`), the loadout and the
    /// items' facts (owner `loadout`), and the species GS as the base of `gs`.
    public init(sheet: HeroSheet) {
        var facts: [Fact] = []
        func state(_ name: String, _ value: JSONValue, _ owner: Owner) {
            facts.append(Fact(name: name, value: value, owner: owner))
        }
        for (a, v) in sheet.attributes { state("attr.\(a)", .int(v), .sheet) }
        for (t, v) in sheet.techniques { state("ktw.\(t)", .int(v), .sheet) }
        for (t, v) in sheet.talents { state("fw.\(t)", .int(v), .sheet) }
        state("hero.purchased.le", .int(sheet.purchasedLE), .sheet)
        if let le = sheet.speciesLE { state("species.le", .int(le), .sheet) }

        let l = sheet.loadout
        if let w = l.weapon { state("loadout.weapon", .string(w), .loadout) }
        if let s = l.shield {
            state("loadout.shield", .string(s), .loadout)
            state("loadout.other", .string("shield"), .loadout)
        }
        if let a = l.armour {
            state("loadout.armour", .string(a), .loadout)
            state("loadout.armour.belastung", .int(l.armourBelastung), .loadout)
            state("loadout.armour.extraPenalty", .int(l.armourExtraPenalty), .loadout)
        }
        for item in sheet.items {
            if let t = item.template {
                state("item.\(item.name).template", .string(t), .loadout)
            } else {
                if let t = item.technique { state("item.\(item.name).technique", .string(t), .loadout) }
                if let v = item.atMod { state("item.\(item.name).atMod", .int(v), .loadout) }
                if let v = item.paMod { state("item.\(item.name).paMod", .int(v), .loadout) }
            }
        }
        var base: [String: Int] = [:]
        if let gs = sheet.speciesGS { base["gs"] = gs }
        self.init(owned: sheet.owned, facts: facts, base: base)
    }
}
