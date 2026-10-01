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

    /// The root's line under the mount's name: its Stufe and current GS, or that its thresholds
    /// are unknown (ADR-0018: a rule that cannot apply says why). nil when nothing is wrong.
    func statusText(name: String) -> String? {
        guard hasBreedRule else { return String(format: L("mount.schmerz.noThresholds"), name) }
        guard schmerz > 0, let gs = gs.result else { return nil }
        let actsAt = facts.schmerzBreakdown.result
        if let actsAt, actsAt != schmerz {
            // Zähes Tier: the mount acts at a lower Stufe than it has (ADR-0018: say so).
            let as_ = actsAt > 0 ? StateCatalog.roman(actsAt) : L("mount.schmerz.asNone")
            return String(format: L("mount.schmerz.statusShift"), StateCatalog.roman(schmerz), as_, gs)
        }
        return String(format: L("mount.schmerz.status"), StateCatalog.roman(schmerz), gs)
    }

    /// The engine's Schmerz line on a mount attack's AT, for the execution screen's note
    /// (ADR-0018: the AT handed on already includes it, so the screen names it).
    static func schmerzNote(_ at: SheetValue?) -> String? {
        at?.breakdown.lines.first { $0.origin?.rule == "COND_6" }
            .map { String(format: L("mount.at.schmerzNote"), $0.value) }
    }

    private func value(_ query: String) -> SheetValue {
        if let hit = memo[query] { return hit }
        let v = SheetValue(breakdown: engine.evaluate(Query(query), in: situation))
        memo[query] = v
        return v
    }
}
