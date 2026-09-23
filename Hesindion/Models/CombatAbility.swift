import Foundation

/// Every Sonderfertigkeit this app does something with, in one list.
///
/// The ids were written inline at each of a dozen call sites, which is how three
/// of them ended up pointing at the wrong ability with the right name in a
/// comment beside it. They live here now, and `CombatAbilityCoverageTests`
/// checks each one against `rules.db` — a typo fails a test instead of silently
/// switching a rule off.
///
/// Where each one is reached in code is recorded in the rules catalog
/// (`specs/data/rules-catalog.yaml`, status `byHand`), and `RulesCatalogTests`
/// checks that every pointer names a symbol that exists. See issue #27.
enum CombatAbility: String, CaseIterable {
    case aufmerksamkeit       = "SA_40"
    case belastungsgewoehnung = "SA_41"
    case beidhaendigerKampf   = "SA_42"
    case berittenerKampf      = "SA_43"
    case finte                = "SA_48"
    case schildspalter        = "SA_59"
    case vorstoss             = "SA_66"
    case wuchtschlag          = "SA_67"
    case gezielterAngriff     = "SA_160"
    case gezielterSchuss      = "SA_161"
    case golgaritenStil       = "SA_661"
    case plaenklerFormation   = "SA_884"
}
