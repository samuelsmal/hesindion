import Foundation

/// Optional DSA 5 Fokus-Regeln. Each is independently switchable per hero, because
/// a group may want hit zones without, say, zone armour.
///
/// These are the table's house rules, not a per-fight choice: they are stored in
/// `Hero.fokusRules` and edited on the hero settings screen.
///
/// Adding a rule: one case here, two `L()` keys, and whatever the rule itself needs.
enum FokusRule: String, CaseIterable, Identifiable {
    case trefferzonen
    /// Kritische Erfolge beim Angriff — the 2W6 table that replaces double damage
    /// on a confirmed critical AT or FK.
    case kritischeErfolgeAngriff
    /// Kritische Erfolge bei Verteidigung im Nahkampf — replaces the Passierschlag.
    case kritischeErfolgeNahkampf
    /// Kritischer Erfolg bei Verteidigung im Fernkampf — replaces "the next
    /// defence does not drop by 3".
    case kritischeErfolgeFernkampf
    /// The Fokusregel nested inside all three: a further 1W20 refines the 2W6
    /// category. On its own it does nothing, which its subtitle says.
    case kritischeErfolgeDetail

    var id: String { rawValue }
    var nameKey: String { "fokus.\(rawValue).name" }
    var subtitleKey: String { "fokus.\(rawValue).subtitle" }
}
