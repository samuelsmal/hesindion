import Foundation
@testable import RulesEngine

// `CompiledSituation` lives in the test target (Task 24), so the draft's compiled form is read
// into it here: `SituationDraft.compiledJSON` (in the engine) is the object rulec writes for the
// draft's YAML, and this decodes it as the harness decodes `build/rules/situations.json`.

extension SituationDraft {
    /// The `CompiledSituation` of the draft `yaml(from: entry, id:, name:)` writes.
    static func compiled(from entry: LogEntry, id: String = "draft", name: String = "draft") throws -> CompiledSituation {
        let json = compiledJSON(from: entry, id: id, name: name)
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONEncoder().encode(json))
    }
}
