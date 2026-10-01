import Foundation

/// Which defences the Größenkategorie of the attacker leaves (Regelwerk,
/// Größenkategorie). Swift because the catalog vocabulary has no "forbid"
/// effect; GRW_groessenkategorie's note points here. The AT −4 against a
/// winzig target is the catalog's.
enum SizeCategoryRules {
    enum Defense: Hashable { case weaponParry, shieldParry, dodge }

    static func allowedDefenses(against size: CreatureSize) -> Set<Defense> {
        switch size {
        case .winzig, .klein, .mittel: [.weaponParry, .shieldParry, .dodge]
        case .gross:                   [.shieldParry, .dodge]
        case .riesig:                  [.dodge]
        }
    }
}
