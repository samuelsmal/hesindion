import Foundation
@testable import RulesEngine

/// The three attributes of every talent's and spell's Probe, and a talent's Belastung flag: the
/// Probe table rulec compiles from `specs/rules/checks.yaml` into
/// `build/rules/situations.json`'s `checks` (Task 34; before, rules.db's `skill_details` /
/// `spell_details`). The engine reads no such table; the harness, like the app, is the check
/// procedure's caller and hands them in (`CheckRequest.attributes`, `check.hinderedByBelastung`).
enum CheckAttributes {
    typealias Table = CheckTable

    static let shared: Table = table(from: Repo.url("build/rules/situations.json"))

    /// Talent or spell id → its three attributes. Empty when situations.json is missing.
    static var all: [String: [String]] { shared.attributes }

    /// Talent id → its Belastung flag. Empty when situations.json is missing.
    static var hinderedByBelastung: [String: JSONValue] { shared.hinderedByBelastung }

    /// The `checks` of a compiled situations file; an empty table when it cannot be read.
    static func table(from url: URL) -> Table {
        guard let data = try? Data(contentsOf: url) else { return Table() }
        return (try? CheckTable.decode(data)) ?? Table()
    }
}
