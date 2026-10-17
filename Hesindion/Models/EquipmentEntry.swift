import Foundation

/// One weapon or shield of Optolith's own inventory (`equipment` in rules.db):
/// the template a hero's weapon was bought from, with the rules' text about it.
///
/// `at`/`pa` are the template's *modifiers*, not a hero's values; `reach` is
/// Optolith's number (1 kurz, 2 mittel, 3 lang). Texts keep Optolith's line
/// breaks as "\n".
struct EquipmentEntry: Equatable {
    let id: String
    let name: String
    let combatTechniqueId: String?
    let damage: String?
    let at: Int?
    let pa: Int?
    let reach: Int?
    let note: String?
    let advantage: String?
    let disadvantage: String?

    /// The deity this template's own note names ("geweiht (Boron); …" →
    /// "Boron"). Only this row's note — whether a *weapon* is consecrated is
    /// `RulesDatabase.consecratedDeity(forWeaponNamed:)`, which reads every
    /// template of that name.
    var consecratedTo: String? { Self.consecratedDeity(inNote: note) }

    /// "geweiht (X)…" → "X"; nil for any other note.
    static func consecratedDeity(inNote note: String?) -> String? {
        guard let note, note.hasPrefix("geweiht ("),
              let close = note.firstIndex(of: ")") else { return nil }
        let deity = note[note.index(note.startIndex, offsetBy: "geweiht (".count)..<close]
            .trimmingCharacters(in: .whitespaces)
        return deity.isEmpty ? nil : deity
    }

    /// Optolith's reach number as the app's `WeaponReach`.
    var weaponReach: WeaponReach? {
        switch reach {
        case 1: .kurz
        case 2: .mittel
        case 3: .lang
        default: nil
        }
    }
}
