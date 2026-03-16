import Foundation

// MARK: - Combat Maneuver

enum CombatManeuver: Equatable, Hashable {
    case normal
    case finte(tier: Int)
    case wuchtschlag(tier: Int)
    case vorstoss
    case schildspalter
    case sturmangriff
}

extension CombatManeuver {
    /// AT modifier from this maneuver.
    var atModifier: Int {
        switch self {
        case .normal: return 0
        case .finte(let tier): return -tier
        case .wuchtschlag(let tier): return -(tier * 2)
        case .vorstoss: return 2
        case .schildspalter: return 0
        case .sturmangriff: return 0
        }
    }

    /// Extra damage from this maneuver.
    var damageBonus: Int {
        switch self {
        case .wuchtschlag(let tier): return tier * 2
        default: return 0
        }
    }

    /// Whether this maneuver prevents defense actions this round.
    var preventsDefense: Bool {
        switch self {
        case .vorstoss: return true
        default: return false
        }
    }

    /// Localized display name.
    var displayName: String {
        switch self {
        case .normal: return L("maneuver.normal")
        case .finte: return L("maneuver.finte")
        case .wuchtschlag: return L("maneuver.wuchtschlag")
        case .vorstoss: return L("maneuver.vorstoss")
        case .schildspalter: return L("maneuver.schildspalter")
        case .sturmangriff: return L("maneuver.sturmangriff")
        }
    }

    /// Localized source label for modifier breakdown.
    var sourceLabel: String {
        switch self {
        case .normal: return ""
        case .finte: return L("source.finte")
        case .wuchtschlag: return L("source.wuchtschlag")
        case .vorstoss: return L("source.vorstoss")
        case .schildspalter: return ""
        case .sturmangriff: return L("source.sturmangriff")
        }
    }

    /// Info text shown to player (e.g. "Opponent PA -2").
    func infoText() -> String? {
        switch self {
        case .finte(let t):
            return "\(L("opponentPA")) -\(t * 2)"
        case .wuchtschlag(let t):
            return "\(L("damageBonus")) +\(t * 2)"
        case .vorstoss:
            return "⚠ \(L("noDefenseWarning"))"
        case .schildspalter:
            return L("targetShield")
        default:
            return nil
        }
    }
}

// MARK: - Plänkler Bonus

enum PlaenklerBonus: String, CaseIterable {
    case at
    case aw
}

// MARK: - Weapon Reach

enum WeaponReach: String, CaseIterable {
    case kurz = "Kurz"
    case mittel = "Mittel"
    case lang = "Lang"

    /// AT penalty when attacking an opponent with the given reach.
    func atPenaltyAgainst(_ opponent: WeaponReach) -> Int {
        switch (self, opponent) {
        case (.kurz, .mittel): return -2
        case (.kurz, .lang):   return -4
        case (.mittel, .lang): return -2
        default:               return 0
        }
    }

    /// AT/PA penalty for beengte Umgebung.
    var beengteUmgebungPenalty: Int {
        switch self {
        case .kurz:  return 0
        case .mittel: return -4
        case .lang:  return -8
        }
    }
}

// MARK: - Modifier Line

struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
}
