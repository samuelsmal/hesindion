import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class StateDetailSheetSnapshotTests: XCTestCase {

    /// A leveled Zustand (Furcht III): stepper, effect table with level III highlighted,
    /// prominent removal callout and the destructive "Entfernen" button.
    @MainActor
    func testFurchtLevelThree() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setStateLevel("furcht", level: 3)

        let def = StateCatalog.definition(for: "furcht")!
        let view = StateDetailSheet(hero: hero, def: def)
            .modelContainer(container)

        assertAllVariants(of: view, named: "state_detail_furcht_III")
    }

    /// A derived state (Schmerz): READ-ONLY variant — no stepper, no remove button,
    /// shows the auto-changes note plus effect table + cause + removal text.
    @MainActor
    func testSchmerzDerivedReadOnly() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        // Drive Schmerz via HP loss so the derived level is non-zero.
        hero.derivedValues?.lebensenergie.current = 1

        let def = StateCatalog.definition(for: "schmerz")!
        let view = StateDetailSheet(hero: hero, def: def)
            .modelContainer(container)

        assertAllVariants(of: view, named: "state_detail_schmerz_derived")
    }

    /// A binary Status (Liegend): on/off `levelControl` indicator, single effect row,
    /// cause + removal callout and the destructive "Entfernen" button.
    @MainActor
    func testLiegendStatus() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setStateLevel("liegend", level: 1)

        let def = StateCatalog.definition(for: "liegend")!
        let view = StateDetailSheet(hero: hero, def: def)
            .modelContainer(container)

        assertAllVariants(of: view, named: "state_detail_liegend")
    }
}
