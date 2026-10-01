import Foundation
import RulesEngine

/// `Pet` → `CreatureSheet` (issue #48): the only code that knows both. The breed is the creature
/// rule whose name is the export's type (`Pet` has no breed field; #49 covers the import); the
/// animal advantages are the creature rules named in `Pet.advantages`.
enum PetSheetMapping {
    /// nil `breed` when no creature rule has `Pet.type` as its name.
    static func sheet(for pet: Pet, book: RuleBook? = RulesEngineStore.shared?.engine.book)
        -> (sheet: CreatureSheet, breed: String?) {
        let creatures = book?.rules.values.filter { $0.kind == .creature } ?? []
        let breed = creatures.first { $0.name == pet.type && $0.group == nil }?.id
        var owned: [String: OwnedRule] = [:]
        if let breed { owned[breed] = OwnedRule() }
        for name in pet.advantages {
            if let rule = creatures.first(where: { $0.name == name && $0.group == "Vorteile (Tiere)" }) {
                owned[rule.id] = OwnedRule()
            }
        }
        let attacks = Dictionary(pet.attacks.map { ($0.name, $0.at) }, uniquingKeysWith: { a, _ in a })
        let sheet = CreatureSheet(owned: owned, gs: pet.speed, leMax: pet.lifeEnergy,
                                  leCurrent: pet.currentLifeEnergy, vw: pet.defense, attacks: attacks)
        return (sheet, breed)
    }
}
