import Foundation

/// Where a landed attack hit the opponent, under the Trefferzonen Fokusregel
/// (trefferzonen.TZ2).
///
/// Every landed hit has a zone. An aimed attack named it before the roll and paid
/// the Zonenaufschlag for it; an attack that named none has its zone rolled with
/// 1W20 on the *target's* table after the defence failed — never before the
/// attack, where a rolled zone would be charged as an aimed one.
enum LandedHitZone: Equatable {
    /// The Fokusregel is off, or the target has no zones (`BodyPlan.keineZonen`).
    case notApplicable
    case aimed(HitZone)
    /// No zone was named and the 1W20 is not rolled yet.
    case awaitingRoll
    /// The raw roll is kept so the screen can show where the zone came from.
    case rolled(HitZoneHit, roll: Int)

    static func resolve(rulesActive: Bool, plan: BodyPlan, aimed: HitZone?, roll: Int?) -> LandedHitZone {
        guard rulesActive, plan != .keineZonen else { return .notApplicable }
        if let aimed { return .aimed(aimed) }
        guard let roll else { return .awaitingRoll }
        return .rolled(HitZoneTable.lookup(roll, plan: plan), roll: roll)
    }

    var zone: HitZone? {
        switch self {
        case .aimed(let zone): zone
        case .rolled(let hit, _): hit.zone
        case .notApplicable, .awaitingRoll: nil
        }
    }

    var isAwaitingRoll: Bool { self == .awaitingRoll }
}
