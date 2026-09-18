import Foundation
import SwiftData

@Model
final class RangedWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int
    var range: String
    var weight: Double

    init(name: String, combatTechniqueId: String, damage: String, at: Int, range: String, weight: Double) {
        self.name = name
        self.combatTechniqueId = combatTechniqueId
        self.damage = damage
        self.at = at
        self.range = range
        self.weight = weight
    }
}

extension RangedWeapon {
    /// Schusswaffen — Bögen, Armbrüste and Blasrohre. Everything else that flies
    /// is a Wurfwaffe.
    ///
    /// This read `["CT_11", "CT_12"]` with the comment "Armbrüste (CT_11), Bögen
    /// (CT_12)". Those ids are *Schleudern* and *Schwerter*: every bow and
    /// crossbow in the game counted as a thrown weapon here, and a sword —
    /// should one ever reach this code — counted as a bow.
    var isSchusswaffe: Bool {
        guard let technique = CombatTechniqueID(rawValue: combatTechniqueId) else { return false }
        return [.boegen, .armbrueste, .blasrohre].contains(technique)
    }
}
