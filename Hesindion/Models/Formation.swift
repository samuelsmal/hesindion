import Foundation

/// A formation the hero stands in: Formation (SA_862) or Plänkler-Formation
/// (SA_884). The two stack (ruling SA_862.formation-and-plaenkler), so the
/// round holds one entry per kind that stands, with the bonus the fighters
/// agreed on (SA_862.F3, SA_884.P3).
///
/// Whose formation it is, is not stored: a hero with the SF stands in their own,
/// a hero without it in an ally's (SA_862.F4, SA_884.P4) — the evaluator names
/// that line "(Verbündeter)".
///
/// Declared in the order the screens list them.
enum FormationKind: String, CaseIterable {
    case formation
    case plaenkler

    var ability: CombatAbility {
        switch self {
        case .formation: .formation
        case .plaenkler: .plaenklerFormation
        }
    }

    var ruleId: String { ability.rawValue }

    /// +2 for Formation (F2), +1 for Plänkler-Formation (P2), on AT or on VW.
    var bonusValue: Int {
        switch self {
        case .formation: 2
        case .plaenkler: 1
        }
    }

    var name: String { L(rawValue) }

    /// "Formation +2 AT"
    func label(_ bonus: FormationBonus) -> String {
        "\(name) +\(bonusValue) \(bonus.shortName)"
    }

    /// What the combat root's chip shows, nil when no formation stands.
    static func summary(_ formations: [FormationKind: FormationBonus]) -> String? {
        let parts = allCases.compactMap { kind in formations[kind].map(kind.label) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Rulings SA_862.formation-mounted and SA_884.plaenkler-mounted: mounting
    /// mid-fight ends every formation. The app removes them by itself, so it
    /// says which, and why.
    static func dissolvedByMounting(_ formations: [FormationKind: FormationBonus]) -> DSAToastContent? {
        guard !formations.isEmpty else { return nil }
        let ended = allCases.compactMap { kind in formations[kind].map(kind.label) }
        return DSAToastContent(title: L("formation.dissolved"), lines: ended + [L("formation.onFootOnly")])
    }
}

/// The bonus a formation agrees on: +AT, or +VW (every defence, parry and dodge).
enum FormationBonus: String, CaseIterable {
    case at
    case aw

    var shortName: String {
        switch self {
        case .at: "AT"
        case .aw: "VW"
        }
    }

    /// The catalog's option index: 0 AT, 1 VW.
    var optionIndex: Int { self == .at ? 0 : 1 }
}
