import Foundation

/// The Optolith special-ability groups that make an ability a *combat* one.
///
/// The raw values are `groups.id` in `rules.db`, which is Optolith's `gr`.
/// `CombatSpecialAbilityGroupTests` checks each one against the group's name,
/// so a wrong number fails a test instead of silently filing an ability out of
/// reach. `groups.id` is only meaningful for `special_ability` rules;
/// advantages reuse the same numbers for other groups (ADV_24 has group 3,
/// which is Karmal there).
enum CombatSpecialAbilityGroup: Int, CaseIterable {
    case kampf = 3
    case kampfstileBewaffnet = 9
    case kampfstileUnbewaffnet = 10
    case kampfErweitert = 11

    /// Whether an ability in this group belongs in `Hero.combatSpecialAbilities`.
    static func contains(groupId: Int?) -> Bool {
        guard let groupId else { return false }
        return CombatSpecialAbilityGroup(rawValue: groupId) != nil
    }
}
