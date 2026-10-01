import XCTest
import RulesEngine
@testable import Hesindion

final class RulesEngineStoreTests: XCTestCase {
    func testTheBundledBookLoadsWithTheAppsVocabulary() throws {
        let store = try XCTUnwrap(RulesEngineStore.shared)
        XCTAssertEqual(store.engine.book.vocabularyVersion, Vocabulary.version)
    }

    func testTheBundledCheckTableIsTheBuiltOne() throws {
        let store = try XCTUnwrap(RulesEngineStore.shared)
        XCTAssertEqual(store.checks.hinderedByBelastung["TAL_5"], .bool(true))
    }
}
