import XCTest
import RulesEngine
@testable import Hesindion

/// The app's `Hero` → `HeroSheet` mapping states the same facts `scripts/rulec/hero.py` does for
/// the same Optolith file (sheet cut-over design §7). The fixtures are `make hero-sheet-fixtures`.
@MainActor
final class HeroSheetMappingTests: XCTestCase {
    struct PyHero: Decodable {
        struct PyOwned: Decodable { var level: Int }
        struct PyFact: Decodable { var name: String; var value: JSONValue }
        var owned: [String: PyOwned]
        var facts: [PyFact]
    }

    static let heroes = ["Boronmir Siebenfeld von Greifenfurt", "Robak Arkanjeff",
                         "Ingra Tochter der Ilpetta", "Lyssandra Silberhaar"]

    func testTheMappingStatesWhatHeroPyStates() throws {
        for name in Self.heroes {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"),
                                    "run make hero-sheet-fixtures")
            let py = try JSONDecoder().decode(PyHero.self, from: Data(contentsOf: url))
            let hero = try SampleHeroes.importHero(named: name)
            let s = RulesEngine.Situation(sheet: HeroSheetMapping.sheet(for: hero))

            // SA_27 and SA_29 (scripts and languages) the app keeps as `scripts` and `languages`,
            // not as traits; hero.py's level for them is the tier of Optolith's first entry, which
            // the app's unordered languages cannot say. No rule of the sheet reads them.
            let ownedByPy = py.owned.filter { !["SA_27", "SA_29"].contains($0.key) }
            XCTAssertEqual(s.owned.mapValues(\.level), ownedByPy.mapValues(\.level), name)

            let prefixes = ["attr.", "ktw.", "fw.", "hero.purchased.le"]
            let ours = Dictionary(uniqueKeysWithValues: s.facts.values
                .filter { f in prefixes.contains { f.name.hasPrefix($0) } }.map { ($0.name, $0.value) })
            let theirs = Dictionary(uniqueKeysWithValues: py.facts.map { ($0.name, $0.value) })
            // Optolith lists only the raised techniques and talents; the app states every one, the
            // others at their starting value (KtW 6, FW 0), which the engine needs for a technique
            // the hero never raised.
            let unraised = ours.filter { k, v in
                theirs[k] == nil && ((k.hasPrefix("ktw.") && v == .int(6)) || (k.hasPrefix("fw.") && v == .int(0)))
            }
            XCTAssertEqual(ours.filter { unraised[$0.key] == nil }, theirs, name)
        }
    }
}
