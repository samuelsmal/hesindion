import Foundation

/// A Passierschlag's numbers: the piece it is struck with, every modifier line
/// the hero has for it (the catalog's `GRW_passierschlag` −4 among them), the
/// total the die is rolled against, and the TP.
///
/// Pure, no SwiftUI: `CombatPassierschlagView` owns the dice, this owns the
/// arithmetic.
struct PassierschlagRoll {
    let hero: Hero
    /// The fight's round flags. A Passierschlag is not a dual attack, so the
    /// round's `dualAttackActive` is ignored.
    let round: CombatSituation
    let opponent: OpponentProfile
    /// The weapon, shield or "Raufen" the announcement named; `nil` for the
    /// main weapon (the critical-parry route).
    let announcedWeaponName: String?
    let isOffHand: Bool

    init(hero: Hero, round: CombatSituation, opponent: OpponentProfile, weaponName: String? = nil, isOffHand: Bool = false) {
        self.hero = hero
        self.round = round
        self.opponent = opponent
        self.announcedWeaponName = weaponName
        self.isOffHand = isOffHand
    }

    private static let raufen = "Raufen"

    var weaponName: String { announcedWeaponName ?? hero.selectedWeapon?.name ?? Self.raufen }

    private var weapon: MeleeWeapon? { hero.meleeWeapons.first { $0.name == weaponName } }
    private var shield: Shield? { weapon == nil ? hero.shields.first { $0.name == weaponName } : nil }

    var rawAT: Int {
        weapon?.at ?? shield?.at ?? (hero.combatTechniques.first { $0.name == Self.raufen }?.at ?? 0)
    }

    var damageFormula: String { weapon?.damage ?? shield?.damage ?? "1W6" }

    func situation(_ domain: RuleDomain) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round = round
        s.round.dualAttackActive = false
        s.opponents = OpponentRoster([opponent])
        s.loadoutName = weaponName
        s.isOffHand = isOffHand
        s.maneuver = .passierschlag
        return s
    }

    var lines: [ModifierLine] { ModifierEngine.shared.evaluate(context: situation(.meleeAttack)) }
    var effectiveAT: Int { rawAT + lines.reduce(0) { $0 + $1.value } }
    var effectiveDamage: String {
        DamageModifiers.applied(to: damageFormula, lines: DamageModifiers.lines(situation: situation(.damage))) ?? damageFormula
    }
}
