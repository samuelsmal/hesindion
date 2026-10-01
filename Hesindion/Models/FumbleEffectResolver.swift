// Hesindion/Models/FumbleEffectResolver.swift
import Foundation

/// The check a Patzer result asks the hero to make.
///
/// A value rather than two loose numbers on the view, because the same three
/// facts are needed in three places: the button's label, the modal's
/// `initialModifier`, and the decision whether the way out is held until it has
/// been rolled.
struct FumbleProbe: Equatable {
    /// The talent by name — `TalentProbeAttributes` keys its attribute triples by
    /// name, and `Hero.talents` rows are matched the same way.
    let talentName: String
    /// …and by id, for the fallback row and for anything that reads the catalog.
    let talentRuleId: String
    let modifier: Int
    /// Whether the screen must hold the way out until the check is rolled.
    ///
    /// Sturz is not optional: the result *is* the check, and leaving without it
    /// is leaving an announced consequence unresolved (AGENTS.md, "An open
    /// question holds the way out"). Freeing a stuck weapon is: the player may
    /// simply decide not to spend the action, and re-equip later through
    /// "Ausrüstung wechseln".
    let isRequired: Bool
    /// L() key for what rolling it costs, where the rule names a cost.
    let costKey: String?
}

/// What a fumble's own damage rolled — the dice as well as the sum, because the
/// screen shows both before it hands the figure to the take-damage screen.
struct FumbleSelfDamage: Equatable {
    let formula: String
    let rolls: [Int]
    let bonus: Int
    let doubled: Bool

    /// The TP the hero takes. Doubling is applied to the whole thing, the way
    /// every other doubling in the app is (`CriticalDamage`).
    var total: Int {
        max(0, (rolls.reduce(0, +) + bonus) * (doubled ? 2 : 1))
    }
}

/// Pure decision logic for Patzertabelle effects, kept out of the view so it is
/// testable — the same split `WoundEffectResolver` makes for the Wundeffekte.
///
/// Nothing here draws anything and nothing here decides *when* to write: the
/// screen owns the order in which questions are asked, this owns what each
/// answer means.
enum FumbleEffectResolver {

    // MARK: - Probes

    /// The check the result asks for, or `nil` where it asks for none.
    static func probe(for effect: FumbleEffect) -> FumbleProbe? {
        switch effect {
        case .fall:
            FumbleProbe(
                talentName: Talent.koerperbeherrschungName,
                talentRuleId: Talent.koerperbeherrschungRuleId,
                modifier: -2,
                isRequired: true,
                costKey: nil)
        case .itemStuck:
            FumbleProbe(
                talentName: Talent.kraftaktName,
                talentRuleId: Talent.kraftaktRuleId,
                modifier: -1,
                isRequired: false,
                costKey: "fumble.cost.oneAction")
        default:
            nil
        }
    }

    /// Whether the screen still owes an answer: a required check that has not
    /// been rolled. `probeSucceeded` is `nil` until it is.
    static func holdsTheWayOut(_ effect: FumbleEffect, probeSucceeded: Bool?) -> Bool {
        guard let probe = probe(for: effect), probe.isRequired else { return false }
        return probeSucceeded == nil
    }

    // MARK: - What is written the moment the table is rolled

    /// Whether the result takes the thing out of the hand at once.
    ///
    /// Destroyed, lost and stuck all do — a stuck weapon is as unavailable as a
    /// dropped one until it is freed, and the Kraftakt check below puts it back.
    static func unequipsItem(_ effect: FumbleEffect) -> Bool {
        switch effect {
        case .itemLost, .itemStuck: true
        default: false
        }
    }

    /// The Betäubung level a Beule raises the hero to. `setStateLevel` clamps.
    static func stuporLevel(for hero: Hero) -> Int {
        hero.level(of: FumbleEffectResolver.stuporStateID) + 1
    }

    static let stuporStateID = "betaeubung"
    static let fallStateID = "liegend"

    /// Applies the Beule at once — the way the 1W6+2 SP branch writes its LP as
    /// soon as it is chosen. The text still says "für 1 Stunde"; removal is
    /// manual, as it is for every state in the app.
    static func applyStupor(to hero: Hero) {
        hero.setStateLevel(stuporStateID, level: stuporLevel(for: hero))
    }

    /// Applies the Sturz. Only a *failed* Körperbeherrschung check does this —
    /// the same rule the Wundeffekt probe follows, and the reason an unrolled
    /// check writes nothing at all.
    static func applyFall(to hero: Hero, probeSucceeded: Bool) {
        guard !probeSucceeded else { return }
        hero.setStateLevel(fallStateID, level: 1)
    }

    // MARK: - Selbst verletzt

    /// The formula the hero's own weapon rolls against them.
    ///
    /// The loadout carries the weapon's **own** damage (`MeleeWeapon.damage`,
    /// straight from the Optolith export) and the attack flow keeps the app's
    /// computed TP bonuses apart from it as `damageLines` — a two-handed grip, a
    /// Wuchtschlag, a Sturmangriff. None of those belong here: they are bonuses
    /// on a swing that connected, and this swing did not. The hero's
    /// Leiteigenschaft Schadensbonus (TP/KK) is not modelled at all — no export
    /// carries the threshold (issue #14) — so it is the one part of "mit
    /// Schadensbonus" the player still adds by hand, on the take-damage screen's
    /// own stepper.
    static func selfDamageFormula(weaponFormula: String?, isUnarmed: Bool) -> String {
        if isUnarmed { return raufenFormula }
        guard let weaponFormula, DamageFormula.parse(weaponFormula) != nil else {
            return raufenFormula
        }
        return weaponFormula
    }

    /// Unarmed damage, the same string the attack flow gives Raufen.
    static let raufenFormula = "1W6"

    /// Rolls it. Through `DiceRoller`, so `ScriptedDice` can drive the branch
    /// from a UI test; `DamageFormula` parses the string, because nothing else
    /// should carry a copy of that regex.
    static func rollSelfDamage(formula: String, doubled: Bool) -> FumbleSelfDamage {
        let parsed = DamageFormula.parse(formula) ?? DamageFormula(count: 1, sides: 6, bonus: 0)
        let rolls = DiceRoller.roll(count: parsed.count, sides: parsed.sides)
        return FumbleSelfDamage(
            formula: parsed.text, rolls: rolls, bonus: parsed.bonus, doubled: doubled)
    }
}
