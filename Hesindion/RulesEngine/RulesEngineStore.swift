import Foundation
import RulesEngine

/// The rules engine and its book, loaded once from the bundle (`rules.json`, `checks.json`, both
/// copied in by `make rules-json`). nil when either is missing or was built for another
/// vocabulary: the screens then show `L("rulesEngine.unavailable")` instead of a number, and
/// `RulesEngineStoreTests` fails before a release.
final class RulesEngineStore: Sendable {
    let engine: Engine
    let checks: CheckTable

    static let shared: RulesEngineStore? = {
        guard let rules = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let checks = Bundle.main.url(forResource: "checks", withExtension: "json"),
              let book = try? RuleBook.load(from: rules),
              let data = try? Data(contentsOf: checks),
              let table = try? CheckTable.decode(data) else { return nil }
        return RulesEngineStore(engine: Engine(book: book), checks: table)
    }()

    init(engine: Engine, checks: CheckTable) {
        self.engine = engine
        self.checks = checks
    }
}
