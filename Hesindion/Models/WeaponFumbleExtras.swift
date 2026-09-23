import Foundation

/// A weapon's Waffennachteil that fires on a confirmed Patzer — Swift because
/// the catalog vocabulary has no "add a state" effect (ITEMTPL_19's note).
/// Keyed by the weapon's name, as the loadout is (issue #14).
enum WeaponFumbleExtras {
    static func extraStates(weaponName: String, action: CombatAction) -> [(stateId: String, levels: Int)] {
        switch (weaponName, action) {
        case ("Rabenschnabel", .angriff): [("betaeubung", 1)]
        default: []
        }
    }
}
