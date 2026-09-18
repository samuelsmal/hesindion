import Foundation
import SwiftData

@Model
final class Talent {
    var ruleId: String
    var name: String
    var value: Int
    var category: String

    init(ruleId: String, name: String, value: Int, category: String) {
        self.ruleId = ruleId
        self.name = name
        self.value = value
        self.category = category
    }
}

// MARK: - Basic abilities

extension Hero {
    /// The hero's Selbstbeherrschung row, or a transient Fertigkeitswert-0 stand-in.
    ///
    /// Selbstbeherrschung is a DSA 5 *basic ability* (Talent) that every hero
    /// possesses, and a Talentprobe may always be attempted — at FW 0 if need be. A
    /// hero without the row is therefore a data anomaly, not a rules case: the
    /// Optolith importer seeds all 59 standard talents at 0, so this only happens for
    /// hand-built data. The stand-in is never inserted into a model context; it exists
    /// only to let the probe be rolled instead of refused.
    var selbstbeherrschung: Talent {
        basicTalent(name: Talent.selbstbeherrschungName, ruleId: Talent.selbstbeherrschungRuleId)
    }

    /// The hero's Körperbeherrschung row, or a Fertigkeitswert-0 stand-in.
    /// Rolled by the Patzertabelle's Sturz (`FumbleEffect.fall`).
    var koerperbeherrschung: Talent {
        basicTalent(name: Talent.koerperbeherrschungName, ruleId: Talent.koerperbeherrschungRuleId)
    }

    /// The hero's Kraftakt row, or a Fertigkeitswert-0 stand-in.
    /// Rolled to free a weapon the Patzertabelle stuck fast (`FumbleEffect.itemStuck`).
    var kraftakt: Talent {
        basicTalent(name: Talent.kraftaktName, ruleId: Talent.kraftaktRuleId)
    }

    /// Shared fallback for the basic abilities the app rolls on the player's
    /// behalf. See `selbstbeherrschung` above for why a missing row is answered
    /// with a stand-in rather than a refusal.
    private func basicTalent(name: String, ruleId: String) -> Talent {
        talents.first { $0.name == name }
            ?? Talent(ruleId: ruleId, name: name, value: 0, category: "Körpertalente")
    }
}

extension Talent {
    static let selbstbeherrschungName = "Selbstbeherrschung"
    static let selbstbeherrschungRuleId = "TAL_8"
    /// Sinnesschärfe — the check Aufmerksamkeit (SA_40) eases. Named here because
    /// it sits one digit away from Selbstbeherrschung's id, and the hint was
    /// wired to the wrong one.
    static let sinnesschaerfeRuleId = "TAL_10"
    /// Körperbeherrschung — the Balance check a Sturz on the Patzertabelle asks for.
    static let koerperbeherrschungName = "Körperbeherrschung"
    static let koerperbeherrschungRuleId = "TAL_4"
    /// Kraftakt — "Ziehen & Zerren", the check that frees a stuck weapon.
    static let kraftaktName = "Kraftakt"
    static let kraftaktRuleId = "TAL_5"
}
