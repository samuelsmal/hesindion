import Foundation

/// The Fokusregel 1W20 breakdowns nested inside each "Kritische Erfolge" table
/// (Aventurisches Kompendium 2, p. 100ff).
///
/// Split out of `CriticalSuccessTable` because it is three times the data and one
/// tenth the logic: the coarse 2W6 rule is the optional rule, this is the
/// Fokusregel that refines it, and a hero can play one without the other.
///
/// Every table covers 1...20 with no gap and no overlap — `CriticalSuccessTableTests`
/// asserts it for all 33, which is the only practical way to proofread data this
/// shape.
enum CriticalSuccessRefinements {

    private static func e(
        _ range: ClosedRange<Int>,
        _ effect: String,
        _ damage: CriticalDamage = .unchanged,
        ps: Bool = false
    ) -> CriticalSuccessRefinement {
        CriticalSuccessRefinement(range: range, effect: effect, damage: damage, grantsPassierschlag: ps)
    }

    /// The table's own "nochmal würfeln".
    private static func reroll(_ range: ClosedRange<Int>) -> CriticalSuccessRefinement {
        CriticalSuccessRefinement(range: range, effect: nil)
    }

    // MARK: - Kritische Treffer für AT und FK (AK2 p100)

    static let leichterTreffer: [CriticalSuccessRefinement] = [
        e(1...10, "Der Treffer richtet +1 TP an.", .bonus(1)),
        e(11...20, "Der Treffer richtet +3 TP an.", .bonus(3)),
    ]

    static let leichtBetaeubenderTreffer: [CriticalSuccessRefinement] = [
        e(1...6, "Der Treffer richtet +1 TP an und der Gegner erhält 1 Stufe Betäubung für 1 KR.", .bonus(1)),
        e(7...12, "Der Treffer richtet +2 TP an und der Gegner erhält 1 Stufe Betäubung für 2 KR.", .bonus(2)),
        e(13...18, "Der Treffer richtet +3 TP an und der Gegner erhält 1 Stufe Betäubung für 3 KR.", .bonus(3)),
        reroll(19...20),
    ]

    static let mittelschwererTreffer: [CriticalSuccessRefinement] = [
        e(1...5, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält den Status Blutend.", .oneAndAHalf),
        e(6...10, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet).", .oneAndAHalf),
        e(11...15, "Der Gegner erhält den Status Blutend."),
        e(16...20, "Der Gegner muss eine Probe auf Körperbeherrschung (Kampfmanöver) bestehen, bei Misslingen erleidet er den Status Liegend."),
    ]

    static let mittelschwererSchmerzhafterTreffer: [CriticalSuccessRefinement] = [
        e(1...3, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 2 KR 1 Stufe Schmerz sowie 1 Stufe Betäubung.", .oneAndAHalf),
        e(4...6, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 2 KR 1 Stufe Schmerz sowie den Status Blutend.", .oneAndAHalf),
        e(7...9, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 2 KR 1 Stufe Schmerz.", .oneAndAHalf),
        e(10...12, "Der Gegner erhält für 2 KR 1 Stufe Schmerz sowie den Status Blutend."),
        e(13...15, "Der Gegner erhält für 2 KR 1 Stufe Schmerz."),
        e(16...18, "Der Gegner erhält für 1 KR 1 Stufe Schmerz."),
        reroll(19...20),
    ]

    static let mittelschwererBetaeubenderTreffer: [CriticalSuccessRefinement] = [
        e(1...2, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) gelingen, um nicht für 3 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 1 Stufe Betäubung für 8 KR.", .oneAndAHalf),
        e(3...4, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 5 KR 2 Stufen Betäubung.", .oneAndAHalf),
        e(5...6, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 8 KR 1 Stufe Betäubung.", .oneAndAHalf),
        e(7...8, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erhält für 5 KR 1 Stufe Betäubung.", .oneAndAHalf),
        e(9...10, "Der Treffer richtet +1 TP an und der Gegner erhält für 5 KR 1 Stufe Betäubung.", .bonus(1)),
        e(11...12, "Der Treffer richtet +1 TP an und der Gegner erhält für 3 KR 2 Stufen Betäubung.", .bonus(1)),
        e(13...14, "Der Treffer richtet +1 TP an und der Gegner erhält für 1 KR 2 Stufen Betäubung.", .bonus(1)),
        reroll(15...20),
    ]

    static let schwererTreffer: [CriticalSuccessRefinement] = [
        e(1...2, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält für 5 KR 1 Stufe Betäubung sowie den Status Blutend.", .double),
        e(3...4, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält für 5 KR 1 Stufe Betäubung.", .double),
        e(5...6, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält den Status Blutend.", .double),
        e(7...8, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält 1 Stufe Schmerz für 2 KR.", .double),
        e(9...10, "Die Trefferpunkte samt Modifikatoren werden verdoppelt.", .double),
        e(11...12, "Der Treffer richtet +5 TP an und der Gegner muss eine Probe auf Körperbeherrschung (Kampfmanöver) –1 bestehen, bei Misslingen erleidet er den Status Liegend.", .bonus(5)),
        e(13...14, "Der Treffer richtet +3 TP an und der Gegner muss eine Probe auf Körperbeherrschung (Kampfmanöver) –1 bestehen, bei Misslingen erleidet er den Status Liegend.", .bonus(3)),
        e(15...16, "Der Treffer richtet +1 TP an und der Gegner muss eine Probe auf Körperbeherrschung (Kampfmanöver) –1 bestehen, bei Misslingen erleidet er den Status Liegend.", .bonus(1)),
        reroll(17...20),
    ]

    /// The published table jumps from 13-14 straight to 19-20, leaving 15-18
    /// unassigned. An unlisted band cannot be resolved, so it rerolls — the same
    /// thing its neighbour 19-20 does, and the only reading that leaves no hole.
    static let schwererBetaeubenderTreffer: [CriticalSuccessRefinement] = [
        e(1...2, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) –1 gelingen, um nicht für 5 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 1 Stufe Betäubung für 10 KR.", .double),
        e(3...4, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und Gegner erhält für 5 KR 2 Stufen Betäubung.", .double),
        e(5...6, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und Gegner erhält für 8 KR 1 Stufe Betäubung.", .double),
        e(7...8, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und Gegner erhält für 5 KR 1 Stufe Betäubung.", .double),
        e(9...10, "Der Treffer richtet +3 TP an und der Gegner erhält für 5 KR 1 Stufe Betäubung.", .bonus(3)),
        e(11...12, "Der Treffer richtet +3 TP an und der Gegner erhält für 3 KR 2 Stufen Betäubung.", .bonus(3)),
        e(13...14, "Der Treffer richtet +3 TP an und der Gegner erhält für 1 KR 2 Stufen Betäubung.", .bonus(3)),
        reroll(15...20),
    ]

    static let schwererSchmerzhafterTreffer: [CriticalSuccessRefinement] = [
        e(1...3, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält für 5 KR 1 Stufe Schmerz sowie 1 Stufe Betäubung.", .double),
        e(4...6, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält für 5 KR 1 Stufe Schmerz sowie den Status Blutend.", .double),
        e(7...9, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erhält für 5 KR 1 Stufe Schmerz.", .double),
        e(10...12, "Der Gegner erhält für 5 KR 1 Stufe Schmerz sowie den Status Blutend."),
        e(13...15, "Der Gegner erhält für 5 KR 1 Stufe Schmerz."),
        e(16...18, "Der Gegner erhält für 5 KR 2 Stufen Schmerz."),
        reroll(19...20),
    ]

    static let ausDemGleichgewicht: [CriticalSuccessRefinement] = [
        e(1...5, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und der Gegner erleidet bis zum Ende der nächsten KR eine Erschwernis von 2 auf Verteidigung. Außerdem muss er eine Probe auf Körperbeherrschung (Kampfmanöver) –2 bestehen, bei Misslingen erleidet er den Status Liegend.", .double),
        e(6...10, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und der Gegner erleidet bis zum Ende der nächsten KR eine Erschwernis von 2 auf Verteidigung. Außerdem muss er eine Probe auf Körperbeherrschung (Kampfmanöver) bestehen, bei Misslingen erleidet er den Status Liegend.", .oneAndAHalf),
        e(11...15, "Der Gegner erleidet bis zum Ende der nächsten KR eine Erschwernis von 4 auf Verteidigung. Außerdem muss er eine Probe auf Körperbeherrschung (Kampfmanöver) –2 bestehen, bei Misslingen erleidet er den Status Liegend."),
        e(16...20, "Der Gegner erleidet bis zum Ende der nächsten KR eine Erschwernis von 2 auf Verteidigung. Außerdem muss er eine Probe auf Körperbeherrschung (Kampfmanöver) bestehen, bei Misslingen erleidet er den Status Liegend."),
    ]

    static let gehirnerschuetterung: [CriticalSuccessRefinement] = [
        e(1...6, "Die Trefferpunkte samt Modifikatoren werden veranderthalbfacht (aufgerundet) und dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) –2 gelingen, um nicht für 5 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 2 Stufen Betäubung für 1 Stunde.", .oneAndAHalf),
        e(7...12, "Dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) –2 gelingen, um nicht für 5 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 2 Stufen Betäubung für 1 Stunde."),
        e(13...18, "Dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) gelingen, um nicht für 5 KR den Status Bewusstlos zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 1 Stufe Betäubung für 1 Stunde."),
        reroll(19...20),
    ]

    static let extremSchwererTreffer: [CriticalSuccessRefinement] = [
        e(1...10, "Die Trefferpunkte samt Modifikatoren werden verdreifacht.", .triple),
        e(11...20, "Die Trefferpunkte samt Modifikatoren werden verdoppelt und dem Gegner muss eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) gelingen, um nicht für 1W3 KR den Status Handlungsunfähig zu erleiden. Gleich ob die Probe ge- oder misslungen ist, erleidet der Held 1 Stufe Schmerz für 3 KR.", .double),
    ]

    // MARK: - Kritische Erfolge bei Verteidigung im Nahkampf (AK2 p101)

    static let geschickterAngriff: [CriticalSuccessRefinement] = [
        e(1...10, "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +2 auf AT gegen seinen Gegner."),
        e(11...20, "Wenn der Held bis zum Ende der nächsten KR ein Manöver im Nahkampf einsetzt, kann er einmalig eine Erschwernis von bis zu 2 Punkten ignorieren."),
    ]

    static let geschickteVerteidigung: [CriticalSuccessRefinement] = [
        e(1...6, "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +1 auf VW gegen seinen Gegner."),
        e(7...12, "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +2 auf VW gegen seinen Gegner."),
        e(13...18, "Der Held verfügt bis zum Ende der nächsten KR über einen Bonus von +3 auf VW gegen seinen Gegner."),
        reroll(19...20),
    ]

    static let geschickteKampfbewegungen: [CriticalSuccessRefinement] = [
        e(1...5, "Bis zum Ende der nächsten KR sind Manöver gegen den Helden für den Gegner um 2 zusätzlich erschwert."),
        e(6...10, "Wenn der Gegner bis zum Ende der nächsten KR Manöver gegen den Helden einsetzt, ist die Verteidigung gegen diese um 4 Punkte erleichtert."),
        e(11...15, "Bis zum Ende der nächsten KR darf der Gegner keine Manöver gegen den Helden einsetzen."),
        e(16...20, "Bis zum Ende der nächsten KR darf der Gegner keine Spezialmanöver gegen den Helden einsetzen."),
    ]

    static let aeusserstGeschickteKampfbewegungen: [CriticalSuccessRefinement] = [
        e(1...3, "Bis zum Ende der nächsten KR sind alle Angriffe (AT, FK) des Gegners gegen den Helden um 2 erschwert."),
        e(4...6, "Bis zum Ende der nächsten KR sind alle Angriffe (AT, FK) des Gegners gegen den Helden um 4 erschwert."),
        e(7...9, "Bis zum Ende der nächsten KR darf der Gegner keine Angriffe (AT, FK) gegen den Helden ausführen."),
        e(10...12, "Bis zum Ende der nächsten KR darf der Gegner keine Angriffe (AT, FK) gegen den Helden ausführen. Außerdem kann der Held in diesem Zeitraum einmalig eine Erschwernis von bis zu 1 Punkt ignorieren, wenn er ein Manöver im Nahkampf einsetzt."),
        e(13...15, "Bis zum Ende der nächsten KR darf der Gegner keine Angriffe (AT, FK) gegen den Helden ausführen. Außerdem kann der Held in diesem Zeitraum einmalig eine Erschwernis von bis zu 2 Punkten ignorieren, wenn er ein Manöver im Nahkampf einsetzt."),
        e(16...18, "Bis zum Ende der nächsten KR darf der Gegner keine Angriffe (AT, FK) gegen den Helden ausführen. Außerdem kann der Held in diesem Zeitraum einmalig eine Erschwernis von bis zu 3 Punkten ignorieren, wenn er ein Manöver im Nahkampf einsetzt."),
        reroll(19...20),
    ]

    static let vorteilhaftePosition: [CriticalSuccessRefinement] = [
        e(1...2, "Der Held muss bis zum Ende der nächsten KR nur 1 freie Aktion aufwenden, um in Vorteilhafte Position zu gelangen. Er muss dazu keine Probe ablegen."),
        e(3...4, "Der Held muss bis zum Ende der nächsten KR nur 1 Aktion aufwenden, um in Vorteilhafte Position zu gelangen. Er muss dazu keine Probe ablegen."),
        e(5...6, "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position."),
        e(7...8, "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position. Außerdem kann der Held in diesem Zeitraum zusätzlich einmalig eine Erschwernis von bis zu 1 Punkt ignorieren, wenn er ein Manöver im Nahkampf einsetzt."),
        e(9...10, "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position. Außerdem kann der Held in diesem Zeitraum zusätzlich einmalig eine Erschwernis von bis zu 2 Punkten ignorieren, wenn er ein Manöver im Nahkampf einsetzt."),
        e(11...12, "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position. Außerdem erhält der Held in diesem Zeitraum zusätzlich noch einen Bonus von +1 auf AT und +1 auf VW."),
        e(13...14, "Der Held befindet sich bis zum Ende der nächsten KR gegen seinen Gegner in einer Vorteilhaften Position. Außerdem erhält der Held in diesem Zeitraum zusätzlich noch einen Bonus von +2 auf AT und +1 auf VW."),
        reroll(15...20),
    ]

    static let passierschlag: [CriticalSuccessRefinement] = [
        e(1...2, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 3 erschwert.", ps: true),
        e(3...4, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert.", ps: true),
        e(5...6, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 1 erschwert.", ps: true),
        e(7...8, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen.", ps: true),
        e(9...10, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 1 erleichtert. Wenn der Held den Passierschlag nutzt, ist seine AT danach bis zum Ende der nächsten KR um 1 erschwert.", ps: true),
        e(11...12, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 1 erleichtert.", ps: true),
        e(13...14, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erleichtert. Wenn der Held den Passierschlag nutzt, ist seine AT danach bis zum Ende der nächsten KR um 1 erschwert.", ps: true),
        e(15...16, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erleichtert.", ps: true),
        reroll(17...20),
    ]

    static let geschickterPassierschlag: [CriticalSuccessRefinement] = [
        e(1...2, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 3 erschwert. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei Basismanöver einsetzen.", ps: true),
        e(3...4, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei Basismanöver einsetzen.", ps: true),
        e(5...6, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 1 erschwert. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei Basismanöver einsetzen.", ps: true),
        e(7...8, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei Basismanöver einsetzen.", ps: true),
        e(9...10, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei sowohl Basis- als auch Spezialmanöver einsetzen.", ps: true),
        e(11...12, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 1 erleichtert. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei sowohl Basis- als auch Spezialmanöver einsetzen.", ps: true),
        e(13...14, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erleichtert. Abweichend von der eigentlichen Regel (siehe Regelwerk Seite 237) kann er dabei sowohl Basis- als auch Spezialmanöver einsetzen.", ps: true),
        reroll(15...20),
    ]

    static let machtvollerPassierschlag: [CriticalSuccessRefinement] = [
        e(1...3, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +2 TP an.", ps: true),
        e(4...6, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +2 TP an und der Gegner erhält bis zum Ende der nächsten KR 1 Stufe Betäubung.", ps: true),
        e(7...9, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +3 TP an.", ps: true),
        e(10...12, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +3 TP an und der Gegner erhält bis zum Ende der nächsten KR 1 Stufe Betäubung.", ps: true),
        e(13...15, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +4 TP an.", ps: true),
        e(16...18, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen, dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erschwert. Bei Gelingen richtet dieser Treffer +4 TP an und der Gegner erhält bis zum Ende der nächsten KR 1 Stufe Betäubung.", ps: true),
        reroll(19...20),
    ]

    static let guenstigeAngriffsposition: [CriticalSuccessRefinement] = [
        e(1...5, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Wenn der Held bis zum Ende der nächsten KR ein Manöver im Nahkampf einsetzt, kann er einmalig eine Erschwernis von 1 Punkt ignorieren.", ps: true),
        e(6...10, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +1 auf AT.", ps: true),
        e(11...15, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Wenn der Held bis zum Ende der nächsten KR ein Manöver im Nahkampf einsetzt, kann er einmalig eine Erschwernis von bis zu 2 Punkten ignorieren.", ps: true),
        e(16...20, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +2 auf AT.", ps: true),
    ]

    static let guenstigeVerteidigungsposition: [CriticalSuccessRefinement] = [
        e(1...6, "Der Kämpfer kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +1 auf VW.", ps: true),
        e(7...12, "Der Kämpfer kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +2 auf VW.", ps: true),
        e(13...18, "Der Kämpfer kann sofort einen Passierschlag gegen seinen Gegner ausführen. Zudem verfügt der Held bis zum Ende der nächsten KR gegen seinen Gegner über einen Bonus von +3 auf VW.", ps: true),
        reroll(19...20),
    ]

    static let zweiPassierschlaege: [CriticalSuccessRefinement] = [
        e(1...10, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Dieser ist zuzüglich zu allen anderen Modifikatoren um 2 erleichtert. Danach kann er einen weiteren durchführen, der nicht zuzüglich modifiziert ist.", ps: true),
        e(11...20, "Der Held kann sofort einen Passierschlag gegen seinen Gegner ausführen. Dieser ist zuzüglich zu allen anderen Modifikatoren um 4 erleichtert. Danach kann er einen weiteren durchführen, der zuzüglich um 2 erschwert ist.", ps: true),
    ]

    // MARK: - Kritischer Erfolg bei Verteidigung im Fernkampf (AK2 p102)

    static let sehrGuteGelegenheit: [CriticalSuccessRefinement] = [
        e(1...10, "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 2 senken (bis zu einem Maximum von +/–0)."),
        e(11...20, "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 3 senken (bis zu einem Maximum von +/–0), wenn er den Vorteil nutzt, sinkt seine Verteidigung im selben Zeitraum um 1."),
    ]

    static let guteGelegenheit: [CriticalSuccessRefinement] = [
        e(1...6, "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 2 senken (bis zu einem Maximum von +/–0), wenn er den Vorteil nutzt, sinkt seine Verteidigung im selben Zeitraum um 1."),
        e(7...12, "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 1 senken (bis zu einem Maximum von +/–0)."),
        e(13...18, "Der Held kann bis zum Ende der nächsten KR Erschwernisse auf AT und FK um 1 senken (bis zu einem Maximum von +/–0), außerdem ist die Verteidigung gegen seine Angriffe im selben Zeitraum zusätzlich um 1 erschwert."),
        reroll(19...20),
    ]

    static let grosseVerteidigungsluecke: [CriticalSuccessRefinement] = [
        e(1...5, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 3 erschwert, allerdings erleidet der Held eine Erschwernis von 1 Punkt, sofern er ein Kampfmanöver einsetzt."),
        e(6...10, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 3 erschwert."),
        e(11...15, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 3 erschwert. Außerdem kann der Held bis zum Ende der nächsten KR einmalig eine Erschwernis von 1 Punkt ignorieren, wenn er ein Manöver einsetzt."),
        e(16...20, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 3 erschwert. Außerdem kann der Held bis zum Ende der nächsten KR einmalig eine Erschwernis von bis zu 2 Punkten ignorieren, wenn er ein Manöver einsetzt."),
    ]

    static let kleineVerteidigungsluecke: [CriticalSuccessRefinement] = [
        e(1...3, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 1 erschwert."),
        e(4...6, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 2 erschwert, allerdings erleidet der Held eine Erschwernis von 1 Punkt, sofern er ein Kampfmanöver einsetzt."),
        e(7...9, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 2 erschwert."),
        e(10...12, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 2 erschwert. Außerdem kann der Held bis zum Ende der nächsten KR einmalig eine Erschwernis von 1 Punkt ignorieren, wenn er ein Manöver einsetzt."),
        e(13...15, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 2 erschwert. Außerdem kann der Held bis zum Ende der nächsten KR einmalig eine Erschwernis von bis zu 2 Punkten ignorieren, wenn er ein Manöver einsetzt."),
        e(16...18, "Die Verteidigung des Gegners, der den Abenteurer angegriffen hat, ist bis zum Ende der nächsten KR gegen den Helden um 2 erschwert. Außerdem kann der Held bis zum Ende der nächsten KR einmalig eine Erschwernis von bis zu 3 Punkten ignorieren, wenn er ein Manöver einsetzt."),
        reroll(19...20),
    ]

    static let angriffssituation: [CriticalSuccessRefinement] = [
        e(1...2, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK, allerdings nur sofern er keine Basis- oder Spezialmanöver einsetzt."),
        e(3...4, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK, allerdings nur sofern er keine Spezialmanöver einsetzt."),
        e(5...6, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK."),
        e(7...8, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK. Darüber hinaus sind Basismanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        e(9...10, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 AT und +1 FK. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        e(11...12, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 2 erleichtert."),
        e(13...14, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 3 erleichtert."),
        reroll(15...20),
    ]

    static let verteidigungsvorteil: [CriticalSuccessRefinement] = [
        e(1...2, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde, sondern nur um 2, allerdings sind alle darauf folgenden Aktionen bis zum Ende der nächsten KR um 1 erschwert, sofern der Held von dem Vorteil profitiert."),
        e(3...4, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde, sondern nur um 2."),
        e(5...6, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde, sondern nur um 1, allerdings sind alle darauf folgenden Aktionen bis zum Ende der nächsten KR um 1 erschwert, sofern der Held von dem Vorteil profitiert."),
        e(7...8, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde, sondern nur um 1."),
        e(9...10, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde."),
        e(11...12, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde. Darüber hinaus sind alle Angriffe gegen den Helden bis zum Ende der nächsten KR um 1 zusätzlich erschwert."),
        e(13...14, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde. Darüber hinaus sind alle Angriffe gegen den Helden bis zum Ende der nächsten KR um 2 zusätzlich erschwert."),
        e(15...16, "Der Verteidigungswert sinkt nicht um 3 wie üblich bei der nächsten Verteidigung in dieser Kampfrunde. Darüber hinaus sind alle Angriffe gegen den Helden bis zum Ende der nächsten KR um 2 zusätzlich erschwert und es können im selbem Zeitraum keine Manöver gegen ihn eingesetzt werden."),
        reroll(17...20),
    ]

    static let verteidigungssituation: [CriticalSuccessRefinement] = [
        e(1...2, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 VW, allerdings sind Kampfmanöver, sofern er welche einsetzt, bis zum Ende der nächsten KR um –2 erschwert."),
        e(3...4, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 VW, allerdings sind Kampfmanöver, sofern er welche einsetzt, bis zum Ende der nächsten KR um –1 erschwert."),
        e(5...6, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 VW."),
        e(7...8, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +1 VW. Setzt er bei seiner Verteidigung ein Manöver ein, erhält er einen zusätzlichen Bonus von +1 VW (also insgesamt +2 VW)."),
        e(9...10, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 VW. Setzt er bei seiner Verteidigung ein Manöver ein, erhält er einen zusätzlichen Bonus von +1 VW (also insgesamt +3 VW)."),
        e(11...12, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 VW. Setzt er bei seiner Verteidigung ein Manöver ein, erhält er einen zusätzlichen Bonus von +2 VW (also insgesamt +4 VW)."),
        e(13...14, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +3 VW. Setzt er bei seiner Verteidigung ein Manöver ein, erhält er einen zusätzlichen Bonus von +2 VW (also insgesamt +5 VW)."),
        reroll(15...20),
    ]

    /// The 2W6 row is titled "Gute Angriffsposition", the Fokusregel heading for
    /// the same category "Gute Angriffssituation". Published inconsistency; the
    /// 2W6 title wins because that is what the player reads first.
    static let guteAngriffsposition: [CriticalSuccessRefinement] = [
        e(1...3, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK, allerdings nur sofern er keine Basis- oder Spezialmanöver einsetzt."),
        e(4...6, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK, allerdings nur sofern er keine Spezialmanöver einsetzt."),
        e(7...9, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK."),
        e(10...12, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK. Darüber hinaus sind Basismanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        e(13...15, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        e(16...18, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT und +2 FK. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 2 erleichtert."),
        reroll(19...20),
    ]

    static let herausragendeKampfsituation: [CriticalSuccessRefinement] = [
        e(1...5, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT, +2 FK und +1 VW, allerdings nur sofern er keine Basis- oder Spezialmanöver einsetzt."),
        e(6...10, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT, +2 FK und +1 VW."),
        e(11...15, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT, +2 FK und +1 VW. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        e(16...20, "Der Held bekommt bis zum Ende der nächsten KR einen Bonus von +2 AT, +2 FK und +1 VW. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 2 erleichtert."),
    ]

    static let bloesse: [CriticalSuccessRefinement] = [
        e(1...6, "Bis zum Ende der nächsten KR sind alle Proben auf AT und FK, die gegen den Gegner gerichtet sind, um 1 erleichtert, gleich ob durch den Helden oder seine Gefährten, allerdings nur sofern keine Basis- oder Spezialmanöver eingesetzt werden."),
        e(7...12, "Bis zum Ende der nächsten KR sind alle Proben auf AT und FK, die gegen den Gegner gerichtet sind, um 1 erleichtert, gleich ob durch den Helden oder seine Gefährten."),
        e(13...18, "Bis zum Ende der nächsten KR sind alle Proben auf AT und FK, die gegen den Gegner gerichtet sind, um 1 erleichtert, gleich ob durch den Helden oder seine Gefährten. Darüber hinaus sind Basis- und Spezialmanöver im selben Zeitraum zusätzlich um 1 erleichtert."),
        reroll(19...20),
    ]

    static let aufDemPraesentierteller: [CriticalSuccessRefinement] = [
        e(1...10, "Bis zum Ende der nächsten KR sind Verteidigungen des Gegners um 1 erschwert, außerdem sind Basis- und Spezialmanöver gegen ihn um 1 erleichtert gleich ob durch den Helden oder seine Gefährten."),
        e(11...20, "Bis zum Ende der nächsten KR sind Verteidigungen des Gegners um 1 erschwert, außerdem sind alle Proben auf AT und FK gegen ihn um 1 erleichtert gleich ob durch den Helden oder seine Gefährten."),
    ]
}
