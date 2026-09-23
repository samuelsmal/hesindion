import Foundation

/// Zonenaufschlag for targeted attacks (DSA 5 Fokus-Trefferzonenregeln).
///
/// The evaluator carries the rule (`GRW_zonenaufschlag`); `penalty` is the same table for the
/// zone picker's chips until step 3 reads them off the evaluation.
enum HitZoneModifiers {

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
}
