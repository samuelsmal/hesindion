import Foundation

/// Every Sonderfertigkeit this app does something with, in one list.
///
/// The ids were written inline at each of a dozen call sites, which is how three
/// of them ended up pointing at the wrong ability with the right name in a
/// comment beside it. They live here now, and `CombatAbilityCoverageTests`
/// checks each one against `rules.db` — a typo fails a test instead of silently
/// switching a rule off.
///
/// **How an ability reaches the roll.** `RuleEffectModifiers` builds modifier
/// definitions straight from the `effects` table, so an ability that is a flat
/// number against a named value needs no code at all. The rest — a choice
/// between two bonuses, a penalty that is *halved* rather than shifted, a style
/// that pays out only in one loadout — cannot be written as a row in that table,
/// so they are wired by hand. `wiring` records which is which, and the coverage
/// test fails if an ability the sample hero carries is neither.
enum CombatAbility: String, CaseIterable {
    case aufmerksamkeit       = "SA_40"
    case belastungsgewoehnung = "SA_41"
    case berittenerKampf      = "SA_43"
    case finte                = "SA_48"
    case schildspalter        = "SA_59"
    case vorstoss             = "SA_66"
    case wuchtschlag          = "SA_67"
    case gezielterAngriff     = "SA_160"
    case gezielterSchuss      = "SA_161"
    case golgaritenStil       = "SA_661"
    case plaenklerFormation   = "SA_884"

    enum Wiring {
        /// Driven by the `effects` table — nothing in the app names it.
        case fromEffects
        /// Wired by hand, because the rule is not a flat modifier. The reason is
        /// spelled out so "why is this not in the table?" has an answer.
        case byHand(String)
    }

    var wiring: Wiring {
        switch self {
        case .aufmerksamkeit:
            .byHand("Eases one named Talentprobe (Sinnesschärfe), not a combat value")
        case .belastungsgewoehnung:
            .byHand("Reduces BE by 2 per tier before every other value derives from it")
        case .berittenerKampf, .finte, .schildspalter, .vorstoss, .wuchtschlag:
            .fromEffects
        case .gezielterAngriff, .gezielterSchuss:
            .byHand("Halves the Zonenaufschlag; a multiplier, not an addend")
        case .golgaritenStil:
            .byHand("Pays out only mounted, with a Rabenschnabel and a Großschild")
        case .plaenklerFormation:
            .byHand("+1 AT *or* +1 VW — a choice the player makes each fight")
        }
    }
}
