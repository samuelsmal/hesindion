import Foundation

/// The optional "Kritische Erfolge" tables (Aventurisches Kompendium 2, p. 100ff).
///
/// The basic rules settle a confirmed critical success with a single outcome:
/// double damage on an attack, a Passierschlag on a melee defence, and a defence
/// that does not drop by 3 on a ranged defence. These tables replace that outcome
/// with a 2W6 lookup, and the nested Fokusregel refines the result with a further
/// 1W20 (see `CriticalSuccessRefinements`).
///
/// `FumbleTable` is the pattern: pure value types, no SwiftUI and no SwiftData,
/// with the rules text quoted in German as published so a GM checking the book
/// finds the same words.
enum CriticalSuccessTableType: String, CaseIterable, Identifiable {
    /// Kritische Erfolge beim Angriff — AT *and* FK, per the rule's own wording.
    case angriff
    case verteidigungNahkampf
    case verteidigungFernkampf

    var id: String { rawValue }

    /// The Fokus-Regel that switches this table on. Each is independent: a table
    /// may want criticals on the attack without the defensive ones.
    var fokusRule: FokusRule {
        switch self {
        case .angriff:               .kritischeErfolgeAngriff
        case .verteidigungNahkampf:  .kritischeErfolgeNahkampf
        case .verteidigungFernkampf: .kritischeErfolgeFernkampf
        }
    }

    var titleKey: String { "critical.table.\(rawValue)" }

    /// What the basic rule this table replaces would have done, stated once the
    /// table has settled so the player can see what they traded away.
    var replacesKey: String { "critical.replaces.\(rawValue)" }

    /// Short name for the basic rule, used on the button that takes it.
    var basicRuleKey: String { "critical.basic.\(rawValue)" }

    /// The basic rule spelled out, for the box shown when it is taken.
    var basicEffectKey: String { "critical.basicEffect.\(rawValue)" }

    /// What the basic rule does to the damage. The optional table replaces this
    /// with whatever it rolls; taking the basic rule keeps it.
    var basicDamage: CriticalDamage {
        self == .angriff ? .double : .unchanged
    }

    /// Whether the basic rule grants an immediate Passierschlag. Only the melee
    /// defence one does — that *is* the basic rule there.
    var basicGrantsPassierschlag: Bool {
        self == .verteidigungNahkampf
    }
}

// MARK: - Damage

/// What a table result does to the damage of the hit that triggered it.
///
/// Only the Angriff table carries these — a defensive critical never changes the
/// damage of the attack it turned aside. This is the one part of a table result
/// the app applies itself; everything else lands on an opponent the app does not
/// model (ADR-0005) and is stated for the GM instead.
enum CriticalDamage: Equatable {
    case unchanged
    case bonus(Int)
    /// "veranderthalbfacht (aufgerundet)"
    case oneAndAHalf
    case double
    case triple

    /// Integer arithmetic rather than `ceil(Double)`: the table says round up and
    /// `(base * 3 + 1) / 2` says exactly that, without a float in the middle.
    func apply(to base: Int) -> Int {
        switch self {
        case .unchanged:    base
        case .bonus(let n): base + n
        case .oneAndAHalf:  (base * 3 + 1) / 2
        case .double:       base * 2
        case .triple:       base * 3
        }
    }

    /// Short label for the damage line, e.g. "×2". `nil` when the result leaves
    /// the damage alone — most of the table's lower half does.
    var label: String? {
        switch self {
        case .unchanged:    nil
        case .bonus(let n): "+\(n)"
        case .oneAndAHalf:  "×1½"
        case .double:       "×2"
        case .triple:       "×3"
        }
    }
}

// MARK: - Entries

/// One band of the Fokusregel's 1W20 refinement.
struct CriticalSuccessRefinement: Equatable {
    let range: ClosedRange<Int>
    /// `nil` is the table's own "nochmal würfeln".
    let effect: String?
    var damage: CriticalDamage = .unchanged
    var grantsPassierschlag: Bool = false

    var isReroll: Bool { effect == nil }
}

/// One 2W6 result: the category, and the Fokusregel breakdown beneath it.
struct CriticalSuccessCategory: Equatable {
    let roll: Int
    let title: String
    let effect: String
    var damage: CriticalDamage = .unchanged
    /// Whether this result hands the hero an immediate Passierschlag.
    ///
    /// Only the flag is modelled. The modifiers and damage bonuses the table
    /// names ("um 2 erschwert", "+3 TP bei Gelingen") stay in `effect` and are
    /// dialled into the Passierschlag screen's own Mod stepper, which is where
    /// every other modifier in this app is entered.
    var grantsPassierschlag: Bool = false
    /// Covers 1...20 with no gap for every category — `CriticalSuccessTableTests`
    /// asserts it.
    var refinements: [CriticalSuccessRefinement] = []
}

// MARK: - Lookup

enum CriticalSuccessTable {

    /// 2W6 → category. Out-of-range rolls clamp, as `FumbleTable.lookup` does.
    static func category(_ roll: Int, table: CriticalSuccessTableType) -> CriticalSuccessCategory {
        let clamped = min(max(roll, 2), 12)
        return categories(for: table).first { $0.roll == clamped }
            ?? CriticalSuccessCategory(roll: clamped, title: "—", effect: "—")
    }

    /// 1W20 → refinement inside a category. `nil` only if a category has no
    /// Fokusregel breakdown at all.
    static func refinement(_ roll: Int, in category: CriticalSuccessCategory) -> CriticalSuccessRefinement? {
        let clamped = min(max(roll, 1), 20)
        return category.refinements.first { $0.range.contains(clamped) }
    }

    static func categories(for table: CriticalSuccessTableType) -> [CriticalSuccessCategory] {
        switch table {
        case .angriff:               angriffCategories
        case .verteidigungNahkampf:  nahkampfCategories
        case .verteidigungFernkampf: fernkampfCategories
        }
    }

    // MARK: - Kritische Erfolge beim Angriff (AK2 p100)
    //
    // "Der Verteidigungswert des Gegners ist bei allen Ergebnissen halbiert" —
    // unconditional, so it stays where it already is on the execution screen
    // rather than being repeated in every row here.
    //
    // The published sub-tables say "der Held" in several places where the effect
    // plainly lands on the target ("…erleidet der Held 1 Stufe Betäubung" inside
    // a hit the hero deals). Quoted as printed — do not "fix" it; a GM checking
    // the book has to find the same words.

    private static let angriffCategories: [CriticalSuccessCategory] = [
        CriticalSuccessCategory(
            roll: 2, title: "Leichter Treffer",
            effect: "Die Trefferpunkte werden um 2 erhöht.",
            damage: .bonus(2),
            refinements: CriticalSuccessRefinements.leichterTreffer
        ),
        CriticalSuccessCategory(
            roll: 3, title: "Leicht betäubender Treffer",
            effect: "Die Trefferpunkte werden um 2 erhöht und der Gegner bekommt 1 Stufe Betäubung für 2 KR.",
            damage: .bonus(2),
            refinements: CriticalSuccessRefinements.leichtBetaeubenderTreffer
        ),
        CriticalSuccessCategory(
            roll: 4, title: "Mittelschwerer Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet).",
            damage: .oneAndAHalf,
            refinements: CriticalSuccessRefinements.mittelschwererTreffer
        ),
        CriticalSuccessCategory(
            roll: 5, title: "Mittelschwerer schmerzhafter Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner bekommt 1 Stufe Schmerz für 5 KR.",
            damage: .oneAndAHalf,
            refinements: CriticalSuccessRefinements.mittelschwererSchmerzhafterTreffer
        ),
        CriticalSuccessCategory(
            roll: 6, title: "Mittelschwerer betäubender Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner bekommt 1 Stufe Betäubung für 5 KR.",
            damage: .oneAndAHalf,
            refinements: CriticalSuccessRefinements.mittelschwererBetaeubenderTreffer
        ),
        CriticalSuccessCategory(
            roll: 7, title: "Schwerer Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden verdoppelt.",
            damage: .double,
            refinements: CriticalSuccessRefinements.schwererTreffer
        ),
        CriticalSuccessCategory(
            roll: 8, title: "Schwerer betäubender Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erleidet 1 Stufe Betäubung für 5 KR.",
            damage: .double,
            refinements: CriticalSuccessRefinements.schwererBetaeubenderTreffer
        ),
        CriticalSuccessCategory(
            roll: 9, title: "Schwerer schmerzhafter Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erleidet 1 Stufe Schmerz für 5 KR.",
            damage: .double,
            refinements: CriticalSuccessRefinements.schwererSchmerzhafterTreffer
        ),
        CriticalSuccessCategory(
            roll: 10, title: "Aus dem Gleichgewicht gebracht",
            effect: "Der Gegner erleidet bis zum Ende der nächsten KR eine Erschwernis von 4 auf Verteidigung. Außerdem muss er eine Probe auf Körperbeherrschung (Kampfmanöver) –2 bestehen, bei Misslingen erleidet er den Status Liegend.",
            refinements: CriticalSuccessRefinements.ausDemGleichgewicht
        ),
        CriticalSuccessCategory(
            roll: 11, title: "Gehirnerschütterung",
            effect: "Dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) –2 gelingen, um nicht für 5 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Gegner 2 Stufen Betäubung für 1 Stunde.",
            refinements: CriticalSuccessRefinements.gehirnerschuetterung
        ),
        CriticalSuccessCategory(
            roll: 12, title: "Extrem schwerer Treffer",
            effect: "Die Trefferpunkte samt Modifikatoren werden verdreifacht.",
            damage: .triple,
            refinements: CriticalSuccessRefinements.extremSchwererTreffer
        ),
    ]

    // MARK: - Kritische Erfolge bei Verteidigung im Nahkampf (AK2 p101)
    //
    // "Die Ergebnisse ersetzen den Passierschlag des Helden […], es sei denn, ein
    // Passierschlag wird als Ergebnis aufgeführt" — hence `grantsPassierschlag`
    // on 7 and up only. A hero who rolls 2–6 has traded the free strike for a
    // standing advantage.

    private static let nahkampfCategories: [CriticalSuccessCategory] = [
        CriticalSuccessCategory(
            roll: 2, title: "Geschickter Angriff",
            effect: "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +2 auf AT gegen seinen Gegner.",
            refinements: CriticalSuccessRefinements.geschickterAngriff
        ),
        CriticalSuccessCategory(
            roll: 3, title: "Geschickte Verteidigung",
            effect: "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +2 auf VW gegen seinen Gegner.",
            refinements: CriticalSuccessRefinements.geschickteVerteidigung
        ),
        CriticalSuccessCategory(
            roll: 4, title: "Geschickte Kampfbewegungen",
            effect: "Bis zum Ende der nächsten KR darf der Gegner keine Manöver gegen den Helden einsetzen.",
            refinements: CriticalSuccessRefinements.geschickteKampfbewegungen
        ),
        CriticalSuccessCategory(
            roll: 5, title: "Äußerst geschickte Kampfbewegungen",
            effect: "Bis zum Ende der nächsten KR darf der Gegner keine Angriffe (AT, FK) gegen den Helden ausführen.",
            refinements: CriticalSuccessRefinements.aeusserstGeschickteKampfbewegungen
        ),
        CriticalSuccessCategory(
            roll: 6, title: "Vorteilhafte Position",
            effect: "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position.",
            refinements: CriticalSuccessRefinements.vorteilhaftePosition
        ),
        CriticalSuccessCategory(
            roll: 7, title: "Passierschlag",
            effect: "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.passierschlag
        ),
        CriticalSuccessCategory(
            roll: 8, title: "Geschickter Passierschlag",
            effect: "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei Basismanöver einsetzen.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.geschickterPassierschlag
        ),
        CriticalSuccessCategory(
            roll: 9, title: "Machtvoller Passierschlag",
            effect: "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +3 TP an.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.machtvollerPassierschlag
        ),
        CriticalSuccessCategory(
            roll: 10, title: "Günstige Angriffsposition",
            effect: "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +1 auf AT.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.guenstigeAngriffsposition
        ),
        CriticalSuccessCategory(
            roll: 11, title: "Günstige Verteidigungsposition",
            effect: "Der Kämpfer kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +2 auf VW.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.guenstigeVerteidigungsposition
        ),
        CriticalSuccessCategory(
            roll: 12, title: "Zwei Passierschläge",
            effect: "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Dieser ist um 2 erleichtert. Danach kann er einen weiteren durchführen, der nicht modifiziert ist.",
            grantsPassierschlag: true,
            refinements: CriticalSuccessRefinements.zweiPassierschlaege
        ),
    ]

    // MARK: - Kritischer Erfolg bei Verteidigung im Fernkampf (AK2 p102)
    //
    // Replaces "die nächste Verteidigung in dieser KR sinkt nicht um 3", which
    // result 7 is the only one to hand back. Nothing here grants a Passierschlag.

    private static let fernkampfCategories: [CriticalSuccessCategory] = [
        CriticalSuccessCategory(
            roll: 2, title: "Sehr gute Gelegenheit zum Angriff",
            effect: "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 2 senken (bis zu einem Maximum von +/–0).",
            refinements: CriticalSuccessRefinements.sehrGuteGelegenheit
        ),
        CriticalSuccessCategory(
            roll: 3, title: "Gute Gelegenheit zum Angriff",
            effect: "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 1 senken (bis zu einem Maximum von +/–0).",
            refinements: CriticalSuccessRefinements.guteGelegenheit
        ),
        CriticalSuccessCategory(
            roll: 4, title: "Große Verteidigungslücke",
            effect: "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 3 erschwert.",
            refinements: CriticalSuccessRefinements.grosseVerteidigungsluecke
        ),
        CriticalSuccessCategory(
            roll: 5, title: "Kleine Verteidigungslücke",
            effect: "Für den Gegner ist bis zum Ende der nächsten KR die Verteidigung um 1 erschwert.",
            refinements: CriticalSuccessRefinements.kleineVerteidigungsluecke
        ),
        CriticalSuccessCategory(
            roll: 6, title: "Angriffssituation",
            effect: "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK.",
            refinements: CriticalSuccessRefinements.angriffssituation
        ),
        CriticalSuccessCategory(
            roll: 7, title: "Verteidigungsvorteil",
            effect: "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde.",
            refinements: CriticalSuccessRefinements.verteidigungsvorteil
        ),
        CriticalSuccessCategory(
            roll: 8, title: "Verteidigungssituation",
            effect: "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 VW.",
            refinements: CriticalSuccessRefinements.verteidigungssituation
        ),
        CriticalSuccessCategory(
            roll: 9, title: "Gute Angriffsposition",
            effect: "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK.",
            refinements: CriticalSuccessRefinements.guteAngriffsposition
        ),
        CriticalSuccessCategory(
            roll: 10, title: "Herausragende Kampfsituation",
            effect: "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT, +2 FK und +1 VW.",
            refinements: CriticalSuccessRefinements.herausragendeKampfsituation
        ),
        CriticalSuccessCategory(
            roll: 11, title: "Blöße",
            effect: "Bis zum Ende der nächsten KR sind alle Proben auf AT und FK, die gegen den Gegner gerichtet sind, um 1 erleichtert, gleich ob durch den Helden oder seine Gefährten.",
            refinements: CriticalSuccessRefinements.bloesse
        ),
        CriticalSuccessCategory(
            roll: 12, title: "Auf dem Präsentierteller",
            effect: "Bis zum Ende der nächsten KR sind Verteidigungen des Gegners um 1 erschwert, außerdem sind alle Proben auf AT und FK gegen ihn um 1 erleichtert gleich ob durch den Helden oder seine Gefährten.",
            refinements: CriticalSuccessRefinements.aufDemPraesentierteller
        ),
    ]
}
