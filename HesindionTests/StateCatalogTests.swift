import XCTest
@testable import Hesindion

final class StateCatalogTests: XCTestCase {
    func testCoreZustaendePresent() {
        let ids = Set(StateCatalog.all.map(\.id))
        for id in ["schmerz", "belastung", "betaeubung", "furcht", "paralyse",
                   "verwirrung", "berauscht", "entrueckung"] {
            XCTAssertTrue(ids.contains(id), "missing zustand \(id)")
        }
    }

    func testCoreStatusPresent() {
        let ids = Set(StateCatalog.all.map(\.id))
        for id in ["liegend", "blutend", "brennend", "blind", "taub", "stumm",
                   "fixiert", "eingeengt", "ueberrascht", "vergiftet", "krank",
                   "bewegungsunfaehig", "handlungsunfaehig", "bewusstlos",
                   "unsichtbar", "versteinert", "uebler_geruch"] {
            XCTAssertTrue(ids.contains(id), "missing status \(id)")
        }
    }

    func testIdsUnique() {
        let ids = StateCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testZustaendeHaveFourEffectLevels() {
        for def in StateCatalog.all where def.kind == .zustand {
            XCTAssertEqual(def.levelEffectKeys.count, 4, "\(def.id) must define I–IV")
        }
    }

    func testLookupById() {
        XCTAssertEqual(StateCatalog.definition(for: "furcht")?.id, "furcht")
        XCTAssertNil(StateCatalog.definition(for: "nonsense"))
    }

    func testAutoDerivedStatesAreNotManuallyAddable() {
        // Schmerz & Belastung are derived; must not appear in the add-picker list.
        XCTAssertFalse(StateCatalog.manuallyAddable.contains { $0.id == "belastung" })
        XCTAssertFalse(StateCatalog.manuallyAddable.contains { $0.id == "schmerz" })
        XCTAssertTrue(StateCatalog.manuallyAddable.contains { $0.id == "furcht" })
    }
}
