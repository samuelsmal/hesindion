import Foundation

/// Optional DSA 5 Fokus-Regeln. Each is independently switchable per combat, because
/// a group may want hit zones without, say, zone armour.
///
/// Adding a rule: one case here, two `L()` keys, and whatever the rule itself needs.
enum FokusRule: String, CaseIterable, Identifiable {
    case trefferzonen

    var id: String { rawValue }
    var nameKey: String { "fokus.\(rawValue).name" }
    var subtitleKey: String { "fokus.\(rawValue).subtitle" }
}
