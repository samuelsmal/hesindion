import Foundation

/// The Probe table rulec compiles from `specs/rules/checks.yaml` into `build/rules/checks.json`:
/// each talent's and spell's three attributes, and each talent's Belastung flag. The engine reads
/// no such table; its caller (the app, the harness) states `check.hinderedByBelastung` from it.
public struct CheckTable: Equatable, Sendable {
    /// Talent or spell id → its three attributes, by the sheet's names (`attr.<name>`).
    public var attributes: [String: [String]]
    /// Talent id → `true`, `false` or `"maybe"` (COND_1.belastung-reach).
    public var hinderedByBelastung: [String: JSONValue]

    public init(attributes: [String: [String]] = [:], hinderedByBelastung: [String: JSONValue] = [:]) {
        self.attributes = attributes
        self.hinderedByBelastung = hinderedByBelastung
    }

    /// Reads a file whose top level has `checks` (`checks.json`, and `situations.json` too).
    public static func decode(_ data: Data) throws -> CheckTable {
        struct Row: Decodable { var attributes: [String]; var hinderedByBelastung: JSONValue? }
        struct File: Decodable { var checks: [String: Row] }
        let rows = try JSONDecoder().decode(File.self, from: data).checks
        return CheckTable(attributes: rows.mapValues(\.attributes),
                          hinderedByBelastung: rows.compactMapValues(\.hinderedByBelastung))
    }
}
