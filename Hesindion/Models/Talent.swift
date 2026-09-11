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
        talents.first { $0.name == Talent.selbstbeherrschungName }
            ?? Talent(
                ruleId: Talent.selbstbeherrschungRuleId,
                name: Talent.selbstbeherrschungName,
                value: 0,
                category: "Körpertalente")
    }
}

extension Talent {
    static let selbstbeherrschungName = "Selbstbeherrschung"
    static let selbstbeherrschungRuleId = "TAL_8"
}
