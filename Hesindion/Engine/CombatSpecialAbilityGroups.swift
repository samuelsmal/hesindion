import Foundation

/// Single source of truth for which Optolith special-ability groups count as "combat":
/// Kampf (3), Kampfstile bewaffnet (9) / unbewaffnet (10), Kampf (erweitert) (11) and
/// Befehle (12). See ADR-0008.
///
/// `OptolithImportService` (at import) and `SpecialAbilityClassificationRepair` (at launch,
/// for a hero imported under an older classification) both call `isCombat(groupId:)` rather
/// than each holding its own copy of the group list. This file is a neutral home for a rule
/// two independent paths must share and cannot drift apart on — the same role
/// `DerivedValueFormulas` plays for the import and repair of derived values (ADR-0006),
/// rather than living inside `OptolithImportService`, which would make the repair depend on
/// the import service for a predicate that is not otherwise its concern, and would leave the
/// group list reachable for a future caller to copy back out — precisely the duplication
/// ADR-0007 exists to remove. The group set itself is `private`, so `isCombat(groupId:)` is
/// the only way to ask the question.
enum CombatSpecialAbilityGroups {
    static func isCombat(groupId: Int?) -> Bool {
        guard let groupId else { return false }
        return groups.contains(groupId)
    }

    private static let groups: Set<Int> = [3, 9, 10, 11, 12]
}
