import Foundation

public enum Verb: String, Codable, CaseIterable, Sendable {
    case add, set, multiply, cap, floor, useLevel, replace, suppress
    case forbid, require, limit, offer, ask, tell, provide, derive
    case check, gain, cost, process, item, reroll, restore

    /// The pipeline phase a value verb runs in (spec §5.2); nil for data, player and action verbs.
    public var phase: Phase? {
        switch self {
        case .derive: .base
        case .useLevel: .level
        case .add, .set: .add
        case .replace, .suppress: .lines
        case .multiply: .multiply
        case .cap, .floor: .cap
        case .forbid, .require, .limit: .legality
        default: nil
        }
    }

    /// The JSON's `phase` field: a phase name, or data / player / action.
    public var layerName: String {
        if let phase { return phase.rawValue }
        switch self {
        case .provide: return "data"
        case .offer, .ask, .tell: return "player"
        default: return "action"
        }
    }
}

public enum Phase: String, Codable, CaseIterable, Comparable, Sendable {
    case base, level, add, lines, multiply, cap, legality
    public static func < (a: Phase, b: Phase) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

public enum Owner: String, Codable, CaseIterable, Sendable { case sheet, loadout, player, gm, round, roll, derived }
public enum ReasonCode: String, Codable, CaseIterable, Sendable {
    case conditionFalse, unknownFact, openRuling, requirementNotMet, forbidden
    case suppressed, replaced, overridden, rulesetOff, outOfContext
}
public enum RuleKind: String, Codable, CaseIterable, Sendable {
    case specialAbility, advantage, disadvantage, condition, state, core, equipment, creature, talent
}
public enum Span: String, Codable, CaseIterable, Sendable { case action, round, fight, whileFormed, untilCleared }
public enum Pool: String, Codable, CaseIterable, Sendable { case le, asp, kap, schips, ammunition, actions, freeActions }
public enum EventKind: String, Codable, CaseIterable, Sendable {
    case paid, damaged, progressed, completed, brokenOff, itemChanged, gained, cleared, logged, clockAdvanced, stated, restored
}
public enum Audience: String, Codable, CaseIterable, Sendable { case player, gm, opponent }
public enum LineKind: String, Codable, CaseIterable, Sendable {
    case base, add, set, levelAs, replaced, multiplied, capped, floored, rerolled, free
}
/// What a selector picks (`{ defence: [pa] }`, `{ line: RULE.CLAUSE }`, …).
public enum SelectorKind: String, Codable, CaseIterable, Sendable {
    case action, attack, defence, manoeuvre, choice, check, talent, spell, loadout
    case line, rule, lineKind, dice, target, ruleKind
}
public enum Rounding: String, Codable, CaseIterable, Sendable { case up, down }
/// Who reads a `provide`d value that no rule computes with (`readBy`).
public enum Reader: String, Codable, CaseIterable, Sendable { case display, loadout, roll }

public enum Vocabulary {
    public static let version = 1
    public static let targets: Set<String> = [
        "armourScore", "aspCurrent", "aspMax", "at", "aw",
        "carryingCapacity", "check.attribute", "check.dice", "check.fp", "check.fw",
        "check.modifier", "check.qs", "fk", "gs", "gsNatural",
        "ini", "iniBase", "item.ladezeit", "item.structurePoints", "kapMax",
        "leCurrent", "leMax", "level", "pa", "regeneration.asp",
        "regeneration.kap", "regeneration.le", "rs", "schips", "sp",
        "spell.castingTime", "spell.cost", "spell.costPerInterval", "spell.duration", "spell.range",
        "tp", "wundschwelle",
    ]
    public static let targetPrefixes = ["opponent.", "mount.", "ally."]
    public static let facts: [String: Owner] = [
        "action.attack": .player,
        "action.defence": .player,
        "action.gait": .player,
        "action.gaitChange": .player,
        "action.manoeuvre": .player,
        "action.runUp": .player,
        "action.with": .player,
        "ally.has": .player,
        "belastung.source": .derived,
        "check.application": .player,
        "check.applicationOnOption": .derived,
        "check.hinderedByBelastung": .derived,
        "check.kind": .player,
        "check.onOption": .derived,
        "check.ones": .roll,
        "check.result": .roll,
        "check.spell": .player,
        "check.spent": .derived,
        "check.talent": .player,
        "check.twenties": .roll,
        "clock.minutes": .round,
        "fw.current": .derived,
        "hero.aspCurrent": .derived,
        "hero.conditionLevels": .derived,
        "hero.gs": .derived,
        "hero.has": .sheet,
        "hero.inMelee": .player,
        "hero.lastMovement": .player,
        "hero.leCurrent": .derived,
        "hero.mounted": .loadout,
        "hero.purchased.le": .sheet,
        "hit.heldInHand": .derived,
        "hit.mountSp": .roll,
        "hit.overWundschwelle": .derived,
        "hit.side": .roll,
        "hit.sp": .derived,
        "hit.tp": .roll,
        "hit.zone": .roll,
        "hit.zoneRs": .derived,
        "ktw.current": .loadout,
        "ladezeit.current": .derived,
        "level": .sheet,
        "loadout.armour": .loadout,
        "loadout.armour.belastung": .loadout,
        "loadout.armour.extraPenalty": .loadout,
        "loadout.mount": .loadout,
        "loadout.mount.instance": .loadout,
        "loadout.other": .loadout,
        "loadout.other.paMod": .loadout,
        "loadout.other.technique": .loadout,
        "loadout.quiver": .loadout,
        "loadout.reach": .loadout,
        "loadout.shield": .loadout,
        "loadout.shield.size": .loadout,
        "loadout.shield.structurePoints": .loadout,
        "loadout.twoHanded": .loadout,
        "loadout.weapon": .loadout,
        "loadout.weapon.closeRange": .loadout,
        "loadout.weapon.farRange": .loadout,
        "loadout.weapon.instance": .loadout,
        "loadout.weapon.kind": .loadout,
        "loadout.weapon.ladezeit": .loadout,
        "loadout.weapon.leit": .loadout,
        "loadout.weapon.loaded": .loadout,
        "loadout.weapon.mediumRange": .loadout,
        "loadout.weapon.ownLeit": .loadout,
        "loadout.weapon.schadensschwelle": .loadout,
        "loadout.weapon.strung": .loadout,
        "loadout.weapon.technique": .loadout,
        "loadout.weaponHand": .loadout,
        "opponent.has": .gm,
        "option": .sheet,
        "query.result": .derived,
        "query.target": .derived,
        "reach.gap": .derived,
        "round.defencesMade": .round,
        "round.defendedThisAttack": .round,
        "round.dodges": .round,
        "round.doubleAttack": .round,
        "round.number": .round,
        "round.parries": .round,
        "round.phase": .round,
        "round.previousDefenceCrit": .round,
        "rulesets": .gm,
        "species.le": .sheet,
        "technique.leit": .loadout,
    ]
    public static let factFamilies: [String: Owner] = [
        "attr.": .sheet,
        "choice.": .player,
        "creature.": .sheet,
        "fw.": .sheet,
        "gmFact.": .gm,
        "hero.levelOf.": .derived,
        "item.": .loadout,
        "ktw.": .sheet,
        "loadout.armourPiece.": .loadout,
        "mount.": .sheet,
        "opponent.": .gm,
        "process.": .derived,
        "roll.": .roll,
        "spell.": .player,
        "stage.": .roll,
        "target.": .gm,
        "upkeep.": .derived,
    ]

    public static func owner(ofFact name: String) -> Owner? {
        if let o = facts[name] { return o }
        return factFamilies.first { name.hasPrefix($0.key) && name.count > $0.key.count }?.value
    }
}
