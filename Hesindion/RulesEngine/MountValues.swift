import Foundation
import RulesEngine

/// The mount's values from its own engine evaluation (issue #48), as `SheetValues` is the
/// hero's: one instance per distinct `CreatureSheet`, so a hit or a heal is a new evaluation.
@MainActor
final class MountValues {
    let sheet: CreatureSheet
    let hasBreedRule: Bool
    private let engine: Engine
    private let situation: RulesEngine.Situation
    private var memo: [String: SheetValue] = [:]

    private init(sheet: CreatureSheet, hasBreedRule: Bool, engine: Engine) {
        self.sheet = sheet
        self.hasBreedRule = hasBreedRule
        self.engine = engine
        self.situation = RulesEngine.Situation(creature: sheet)
    }

    private static var cache: [ObjectIdentifier: MountValues] = [:]

    /// nil when the rules are not loaded (`RulesEngineStore.shared` is nil).
    static func of(_ pet: Pet) -> MountValues? {
        guard let store = RulesEngineStore.shared else { return nil }
        let mapped = PetSheetMapping.sheet(for: pet, book: store.engine.book)
        let key = ObjectIdentifier(pet)
        if let hit = cache[key], hit.sheet == mapped.sheet { return hit }
        let values = MountValues(sheet: mapped.sheet, hasBreedRule: mapped.breed != nil, engine: store.engine)
        cache[key] = values
        return values
    }

    private(set) lazy var facts: MountFacts = engine.mountFacts(in: situation)

    var gs: SheetValue { SheetValue(breakdown: facts.gs) }
    var schmerz: Int { facts.schmerz }
    var handlungsunfaehig: Bool { facts.handlungsunfaehig }
    var vw: SheetValue? { sheet.vw == nil ? nil : value("vw") }

    func at(with attack: String) -> SheetValue? {
        sheet.attacks[attack] == nil ? nil : value("at(with: \(attack))")
    }

    private func value(_ query: String) -> SheetValue {
        if let hit = memo[query] { return hit }
        let v = SheetValue(breakdown: engine.evaluate(Query(query), in: situation))
        memo[query] = v
        return v
    }
}
