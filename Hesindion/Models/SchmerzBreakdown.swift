import Foundation

/// Where a level of Schmerz came from — and therefore what puts it away again.
///
/// The app knows exactly two origins, and they end in completely different
/// ways, which is the whole reason the screen after the fight has to name them:
/// the life points' own thresholds end with healing and there is nothing to
/// switch off, while the Patzertabelle's "1 Stufe Schmerz für 3 Kampfrunden"
/// belongs to the fight and is gone the moment the session is cleared.
///
/// Schmerz from a poison, a spell or a wound the GM rules painful is *not* one
/// of these: the app has no manually tracked Schmerz at all (`setStateLevel`
/// refuses it), so there is no third origin to report.
enum SchmerzOrigin: String, CaseIterable, Equatable {
    /// The LP thresholds: ¾, ½ and ¼ of the maximum, and "5 LP or fewer".
    case lebenspunkte
    /// `Hero.temporarySchmerzLevels`, set by the Patzertabelle's Fuß verdreht
    /// and Zerrung.
    case patzer

    var nameKey: String { "schmerz.origin.\(rawValue)" }
    var removalKey: String { "schmerz.origin.\(rawValue).ends" }

    /// Whether leaving the fight is what ends it. The Patzer levels hang off
    /// the combat session (`Hero.clearCombatSession`), which is exactly what
    /// the aftermath screen's "Fertig" does — so the row can say "endet jetzt"
    /// rather than leave the player waiting for it.
    var endsWithTheFight: Bool { self == .patzer }
}

/// One origin with the levels it contributes.
struct SchmerzOriginPart: Equatable {
    let origin: SchmerzOrigin
    let level: Int
}

/// The hero's Schmerz taken apart by origin, with the two corrections that make
/// the parts *not* add up to the level every other screen shows.
///
/// A value rather than a handful of computed properties on the view, so the one
/// thing that can go wrong — rows whose numbers do not add up to the chip —
/// is a unit test rather than a reading of the screen.
struct SchmerzBreakdown: Equatable {

    /// The origins that carry at least one level, life points first. Empty when
    /// the hero has no Schmerz at all.
    let parts: [SchmerzOriginPart]

    /// The life points the LP part was read off, for the row's own sentence.
    /// `nil` when the hero has no derived values yet (an import in flight).
    let currentLP: Int?
    let maxLP: Int?

    /// Zäher Hund (ADV_49) took one level off the total. Not a fifth part: it is
    /// a correction on the sum, and only the sum.
    let zaeherHundApplied: Bool

    /// The sum ran past IV and was cut back to it.
    let cappedAtFour: Bool

    /// What the origins add up to, before the two corrections — `Hero.schmerzLevel`.
    let raw: Int

    /// What the chip, the modifier lines and the states strip show —
    /// `Hero.effectiveSchmerzLevel`.
    let effective: Int

    /// True when the rows on their own do not add up to the chip, and the screen
    /// therefore owes the reader a sentence saying why.
    var needsCorrectionNote: Bool { effective != raw }

    init(lebenspunkteLevel: Int, patzerLevel: Int, currentLP: Int?, maxLP: Int?, hasZaeherHund: Bool) {
        var parts: [SchmerzOriginPart] = []
        if lebenspunkteLevel > 0 {
            parts.append(SchmerzOriginPart(origin: .lebenspunkte, level: lebenspunkteLevel))
        }
        if patzerLevel > 0 {
            parts.append(SchmerzOriginPart(origin: .patzer, level: patzerLevel))
        }
        self.parts = parts
        self.currentLP = currentLP
        self.maxLP = maxLP

        // The same two steps `Hero.effectiveSchmerzLevel` takes, in the same
        // order: the cap comes first and Zäher Hund does not apply past it.
        let raw = lebenspunkteLevel + patzerLevel
        self.raw = raw
        if raw >= 4 {
            self.effective = 4
            self.cappedAtFour = raw > 4
            self.zaeherHundApplied = false
        } else {
            self.effective = hasZaeherHund ? max(0, raw - 1) : raw
            self.cappedAtFour = false
            self.zaeherHundApplied = hasZaeherHund && raw > 0
        }
    }

    /// The levels this origin is worth once the fight is over — the Patzer's go
    /// with the session, everything else stays.
    func levelAfterTheFight(for origin: SchmerzOrigin) -> Int {
        origin.endsWithTheFight ? 0 : (parts.first { $0.origin == origin }?.level ?? 0)
    }
}
