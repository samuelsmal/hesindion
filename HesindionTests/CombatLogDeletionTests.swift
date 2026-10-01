import XCTest
@testable import Hesindion

/// Which entries a combat owns, for deleting a whole fight from the log (issue #13).
///
/// The log's combat header is the only place a finished combat can be deleted from —
/// its rows collapse, and a collapsed combat has nothing left to swipe — so the
/// selection has to be right without the rows on screen to check it against.
final class CombatLogDeletionTests: XCTestCase {

    private let combat = UUID()
    private let otherCombat = UUID()

    // MARK: - Helpers

    private func action(_ combatId: UUID, round: Int = 1, lpChange: Int = -3) -> LogEntry {
        let payload = CombatActionPayload(
            combatId: combatId, round: round, action: .attack,
            weaponName: nil, rollValue: nil, damageDealt: nil, damageTaken: nil,
            lpChange: lpChange)
        return LogEntry(kind: "combatAction", payload: try! JSONEncoder().encode(payload))
    }

    private func woundEffect(_ combatId: UUID?) -> LogEntry {
        let payload = WoundEffectPayload(
            combatId: combatId, zone: HitZone.torso.rawValue, side: nil, roll: 11,
            damage: 9, wundschwelle: 6, multiple: 1,
            probeSucceeded: false, applied: true, extraDamage: 2, weaponDropped: nil)
        return LogEntry(kind: "woundEffect", payload: try! JSONEncoder().encode(payload))
    }

    private func talentCheck() -> LogEntry {
        let payload = TalentCheckPayload(
            talentName: "Klettern", qualityLevel: 2, succeeded: true)
        return LogEntry(kind: "talentCheck", payload: try! JSONEncoder().encode(payload))
    }

    // MARK: - Selection

    func testEveryActionOfThatCombatIsSelected() {
        let entries = [action(combat, round: 1), action(combat, round: 2), action(combat, round: 3)]
        XCTAssertEqual(LogEntry.entries(ofCombat: combat, in: entries).count, 3)
    }

    func testAnotherCombatIsLeftAlone() {
        let mine = action(combat)
        let theirs = action(otherCombat)
        let selected = LogEntry.entries(ofCombat: combat, in: [mine, theirs])
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.id, mine.id)
    }

    /// The Wundeffekt is a separate entry written by the same confirm, so it has to
    /// go with the combat — otherwise deleting the fight leaves a wound behind that
    /// belongs to nothing.
    func testWoundEffectOfThatCombatGoesWithIt() {
        let selected = LogEntry.entries(ofCombat: combat, in: [action(combat), woundEffect(combat)])
        XCTAssertEqual(selected.count, 2)
    }

    /// Entries written before `WoundEffectPayload` carried a `combatId` cannot be
    /// attributed, and are deliberately not guessed at by timestamp.
    func testWoundEffectWithoutACombatIdStaysPut() {
        let selected = LogEntry.entries(ofCombat: combat, in: [action(combat), woundEffect(nil)])
        XCTAssertEqual(selected.count, 1)
    }

    func testUnrelatedKindsAreNeverSelected() {
        let selected = LogEntry.entries(ofCombat: combat, in: [talentCheck(), action(combat)])
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.kind, "combatAction")
    }

    func testNothingMatchesAnUnknownCombat() {
        XCTAssertTrue(LogEntry.entries(ofCombat: UUID(), in: [action(combat), woundEffect(combat)]).isEmpty)
    }

    // MARK: - Payload compatibility

    /// The field was added to an already-shipped payload, so a stored entry without
    /// it must still decode — a failed decode would drop the row from the log.
    func testWoundEffectPayloadDecodesWithoutACombatId() throws {
        let json = """
        {"zone":"torso","damage":9,"wundschwelle":6,"multiple":1,"applied":true}
        """
        let payload = try JSONDecoder().decode(WoundEffectPayload.self, from: Data(json.utf8))
        XCTAssertNil(payload.combatId)
        XCTAssertEqual(payload.zone, "torso")
    }

    func testWoundEffectPayloadRoundTripsTheCombatId() throws {
        let encoded = try JSONEncoder().encode(
            WoundEffectPayload(
                combatId: combat, zone: HitZone.kopf.rawValue, side: nil, roll: nil,
                damage: 12, wundschwelle: 6, multiple: 2,
                probeSucceeded: nil, applied: false, extraDamage: nil, weaponDropped: nil))
        let decoded = try JSONDecoder().decode(WoundEffectPayload.self, from: encoded)
        XCTAssertEqual(decoded.combatId, combat)
    }

    // MARK: - Reversal

    /// Deleting a combat reverses each entry, and only the `combatAction` entries
    /// carry the LP change: the Wundeffekt's damage rides on the action written by
    /// the same confirm, so reversing both would give the LP back twice.
    func testOnlyTheActionEntriesAreReversible() {
        XCTAssertNotNil(action(combat).reversible())
        XCTAssertNil(woundEffect(combat).reversible())
    }
}
