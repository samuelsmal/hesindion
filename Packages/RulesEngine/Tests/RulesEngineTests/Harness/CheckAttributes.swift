import Foundation
@testable import RulesEngine

/// The three attributes of every talent's and spell's Probe, and a talent's Belastung flag: the
/// Probe table rulec compiles from `docs/rules-rework/examples/checks.yaml` into
/// `build/rules/situations.json`'s `checks` (Task 34; before, rules.db's `skill_details` /
/// `spell_details`). The engine reads no such table; the harness, like the app, is the check
/// procedure's caller and hands them in (`CheckRequest.attributes`, `check.hinderedByBelastung`).
enum CheckAttributes {
    struct Table: Equatable {
        /// Talent or spell id → its three attributes, by the sheet's names (the facts `attr.<name>`).
        var attributes: [String: [String]] = [:]
        /// Talent id → its Belastung flag (`true`, `false` or `"maybe"`), the fact
        /// `check.hinderedByBelastung` of a check on it (COND_1.belastung-reach; Task 30).
        var hinderedByBelastung: [String: JSONValue] = [:]
    }

    static let shared: Table = table(from: Repo.url("build/rules/situations.json"))

    /// Talent or spell id → its three attributes. Empty when situations.json is missing.
    static var all: [String: [String]] { shared.attributes }

    /// Talent id → its Belastung flag. Empty when situations.json is missing.
    static var hinderedByBelastung: [String: JSONValue] { shared.hinderedByBelastung }

    /// The `checks` of a compiled situations file; an empty table when it cannot be read.
    static func table(from url: URL) -> Table {
        struct Row: Decodable { var attributes: [String]; var hinderedByBelastung: JSONValue? }
        struct File: Decodable { var checks: [String: Row]? }
        guard let data = try? Data(contentsOf: url),
              let rows = (try? JSONDecoder().decode(File.self, from: data))?.checks else { return Table() }
        return Table(attributes: rows.mapValues(\.attributes),
                     hinderedByBelastung: rows.compactMapValues(\.hinderedByBelastung))
    }
}
