import Foundation
import SwiftData

/// Persists a user-tracked state (Zustand or Status) on a Hero.
/// Schmerz & Belastung are NOT stored here — they are derived on `Hero`.
@Model
final class HeroStateEntry {
    var stateID: String
    var level: Int

    init(stateID: String, level: Int) {
        self.stateID = stateID
        self.level = level
    }
}
