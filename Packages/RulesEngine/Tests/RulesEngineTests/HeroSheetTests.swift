import XCTest
@testable import RulesEngine

final class HeroSheetTests: XCTestCase {
    func testTheCheckTableDecodesTheBuiltFile() throws {
        let data = try Data(contentsOf: Repo.url("build/rules/checks.json"))
        let table = try CheckTable.decode(data)
        XCTAssertEqual(table.hinderedByBelastung["TAL_5"], .bool(true))
        XCTAssertEqual(table.attributes["TAL_5"], ["KO", "KK", "KK"])
    }
}
