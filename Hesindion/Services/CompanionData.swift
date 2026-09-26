import Foundation

/// One pet's entry in the `hesindion` block that `scripts/companions/amend_export.py`
/// writes into an Optolith export (docs/plans/2026-09-24-companion-data-design.md §4;
/// schema: specs/data/companion-block.schema.json). Optolith ignores the key, so a
/// fresh Optolith export does not have it.
struct CompanionData: Decodable {
    struct AP: Decodable {
        var total: Int
        var spent: Int
    }

    struct Attack: Decodable {
        var name: String
        var at: Int
        var tp: String
        var rw: String
    }

    struct Values: Decodable {
        var vw: Int?
        var rs: Int?
        var be: Int?
        var attacks: [Attack]
        var advantages: [String]
        var abilities: [String]
        var training: [String]
        var tricks: [String]
    }

    var name: String
    var ap: AP
    var purchases: [PetPurchase]
    var values: Values

    /// Entries by pet key. An entry that does not decode is left out — the pet then
    /// imports as if the export had not been amended.
    static func parse(root: [String: Any]) -> [String: CompanionData] {
        guard let block = root["hesindion"] as? [String: Any],
              let pets = block["pets"] as? [String: Any] else { return [:] }
        var result: [String: CompanionData] = [:]
        for (key, value) in pets {
            do {
                let data = try JSONSerialization.data(withJSONObject: value)
                result[key] = try JSONDecoder().decode(CompanionData.self, from: data)
            } catch {
                print("OptolithImport: companion data for \(key) does not decode, ignored: \(error)")
            }
        }
        return result
    }

    func apply(to pet: Pet) {
        pet.defense = values.vw
        pet.armor = values.rs
        pet.encumbrance = values.be
        pet.advantages = values.advantages
        pet.abilities = values.abilities
        pet.training = values.training
        pet.tricks = values.tricks
        pet.purchases = purchases
        pet.apTotal = ap.total
        pet.apSpent = ap.spent
        pet.attacks = values.attacks.map { PetAttack(name: $0.name, at: $0.at, damage: $0.tp, reach: $0.rw) }
    }
}
