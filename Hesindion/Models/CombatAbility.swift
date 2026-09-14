import Foundation

/// Every Sonderfertigkeit this app does something with, in one list.
///
/// The ids were written inline at each of a dozen call sites, which is how three
/// of them ended up pointing at the wrong ability with the right name in a
/// comment beside it. They live here now, and `CombatAbilityCoverageTests`
/// checks each one against `rules.db` — a typo fails a test instead of silently
/// switching a rule off.
///
/// **How an ability reaches the roll.** By hand, all eleven of them.
/// `RuleEffectModifiers` can build modifier definitions straight from the
/// `effects` table, but it is not wired into `ModifierEngine.shared` and nothing
/// calls it — and the table it would read covers 26 of the 2675 rules in
/// `rules.db`, ten of the 1557 Sonderfertigkeiten. `wiring` records how each
/// ability is actually reached, and `CombatAbilityCoverageTests` holds it to
/// that: a `.fromEffects` claim has to survive a round trip through the live
/// engine, so the field cannot drift into wishful thinking. See issue #27.
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

    enum Wiring: Equatable {
        /// Reached through `ModifierEngine.shared` off the `effects` table, with
        /// no code naming the ability. Nothing is, yet.
        case fromEffects
        /// Named in the app's own code. The note says what reaches it, so
        /// "where does this ability actually happen?" has an answer that is not
        /// a search.
        case byHand(String)
    }

    var wiring: Wiring {
        switch self {
        case .aufmerksamkeit:
            .byHand("TalentProbeModal — eases one named Talentprobe (Sinnesschärfe), not a combat value")
        case .belastungsgewoehnung:
            .byHand("Hero.effectiveBE — reduces BE before every value that derives from it")
        case .berittenerKampf:
            .byHand("CombatAttackViews — offers Sturmangriff zu Pferd")
        case .finte, .schildspalter, .vorstoss, .wuchtschlag:
            .byHand("CombatManeuver — offered as a manoeuvre on the announcement screen")
        case .gezielterAngriff, .gezielterSchuss:
            .byHand("HitZoneModifiers — halves the Zonenaufschlag; a multiplier, not an addend")
        case .golgaritenStil:
            .byHand("Hero.golgaritenActive — pays out only mounted, with a Rabenschnabel and a Großschild")
        case .plaenklerFormation:
            .byHand("CombatSetupView — +1 AT *or* +1 VW, a choice the player makes each fight")
        }
    }
}
