import Foundation

/// The Optolith special-ability groups that make an ability a *combat* one.
///
/// The raw values are `groups.id` in `rules.db`, which is Optolith's `gr`.
/// `SpecialAbilityGroupTests` checks each one against the group's name, so a
/// wrong number fails a test instead of silently filing an ability out of reach.
enum SpecialAbilityGroup: Int, CaseIterable {
    case kampf = 3
    case kampfstileBewaffnet = 9
    case kampfstileUnbewaffnet = 10
    case kampfErweitert = 11

    /// Whether an ability in this group belongs in `Hero.combatSpecialAbilities`.
    static func isCombat(groupId: Int?) -> Bool {
        guard let groupId else { return false }
        return SpecialAbilityGroup(rawValue: groupId) != nil
    }
}
