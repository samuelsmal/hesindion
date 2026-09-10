import Foundation

/// Zonenaufschlag for targeted attacks (DSA 5 Fokus-Trefferzonenregeln).
enum HitZoneModifiers {

    static let all: [ModifierDefinition] = [zonenaufschlag]

    /// Base Zonenaufschlag per zone.
    ///
    /// The rules table names Kopf, Torso, Arme and Beine only; the extra limb zones on
    /// non-humanoid plans reuse the limb value of −8 by analogy. `.koerper` (an undifferentiated
    /// body, used when a creature offers no distinct zones) is the torso analogue, not a limb,
    /// so it shares Torso's −4. `.fangarme` and `.koerper` are both unreachable from the
    /// offence-side picker today, which only offers the humanoid zones Kopf/Torso/Arme/Beine —
    /// these values exist for completeness rather than current use.
    private static func basePenalty(for zone: HitZone) -> Int {
        switch zone {
        case .kopf:            -10
        case .torso, .koerper: -4
        default:                -8
        }
    }

    /// - Parameters:
    ///   - hasSonderfertigkeit: hero owns SA_160 (melee) or SA_161 (ranged)
    ///   - targetIsSurprised: GM-driven; the opponent is not modelled
    static func penalty(for zone: HitZone, hasSonderfertigkeit: Bool, targetIsSurprised: Bool) -> Int {
        var value = basePenalty(for: zone)
        if hasSonderfertigkeit { value /= 2 }        // every base is even; asserted in tests
        if targetIsSurprised { value += 2 }          // 2 toward zero
        return min(value, 0)                         // never a bonus
    }

    static let zonenaufschlag = ModifierDefinition(
        id: "zonenaufschlag",
        domains: [.meleeAttack, .rangedAttack]
    ) { ctx in
        guard let zone = ctx.targetHitZone else { return nil }
        let ruleId = ctx.domain == .rangedAttack ? "SA_161" : "SA_160"
        let hasSF = ctx.hero.combatSpecialAbilities.contains { $0.ruleId == ruleId }
        let value = penalty(for: zone, hasSonderfertigkeit: hasSF, targetIsSurprised: ctx.targetIsSurprised)
        guard value != 0 else { return nil }
        return ModifierLine(value: value, source: "\(L("modifier.trefferzone")): \(L(zone.nameKey))")
    }
}
