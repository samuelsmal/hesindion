import Foundation
import SwiftData

// MARK: - Reversible Protocol

protocol Reversible {
    func reverse(on hero: Hero)
}

// MARK: - CombatActionType

enum CombatActionType: String, Codable {
    case attack
    case parry
    case dodge
    case damageDealt
    case damageTaken
}

// MARK: - Payload Types

struct TalentCheckPayload: Codable, Reversible {
    var talentName: String
    var qualityLevel: Int
    var succeeded: Bool

    func reverse(on hero: Hero) {
        // no-op: talent checks don't mutate hero state
    }
}

struct CombatActionPayload: Codable, Reversible {
    var combatId: UUID
    var round: Int
    var action: CombatActionType
    var weaponName: String?
    var rollValue: Int?
    var damageDealt: Int?
    var damageTaken: Int?
    var lpChange: Int

    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        let reversed = dv.lebensenergie.current - lpChange
        dv.lebensenergie.current = min(max(reversed, 0), dv.lebensenergie.max)
    }
}

struct HealingPayload: Codable, Reversible {
    var source: String
    var lpRestored: Int

    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        let reversed = dv.lebensenergie.current - lpRestored
        dv.lebensenergie.current = min(max(reversed, 0), dv.lebensenergie.max)
    }
}

struct RestPayload: Codable, Reversible {
    var lpRestored: Int
    var duration: String?

    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        let reversed = dv.lebensenergie.current - lpRestored
        dv.lebensenergie.current = min(max(reversed, 0), dv.lebensenergie.max)
    }
}

struct MountLPChangePayload: Codable, Reversible {
    var petName: String
    var lpChange: Int

    func reverse(on hero: Hero) {
        guard let pet = hero.pets.first(where: { $0.name == petName }) else { return }
        let reversed = pet.currentLifeEnergy - lpChange
        pet.currentLifeEnergy = min(max(reversed, 0), pet.lifeEnergy)
    }
}

// MARK: - LogEntry Model

@Model
final class LogEntry {
    var id: UUID
    var timestamp: Date
    var kind: String
    var payload: Data

    @Relationship var hero: Hero?

    init(id: UUID = UUID(), timestamp: Date = .now, kind: String, payload: Data, hero: Hero? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.payload = payload
        self.hero = hero
    }

    // MARK: - Factory

    static func create<P: Codable>(kind: String, payload: P, hero: Hero) -> LogEntry {
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        return LogEntry(kind: kind, payload: data, hero: hero)
    }

    // MARK: - Decoding

    func decodePayload<P: Codable>(_ type: P.Type) -> P? {
        try? JSONDecoder().decode(type, from: payload)
    }

    // MARK: - Reversible Resolution

    func reversible() -> Reversible? {
        switch kind {
        case "talentCheck":
            return decodePayload(TalentCheckPayload.self)
        case "combatAction":
            return decodePayload(CombatActionPayload.self)
        case "healing":
            return decodePayload(HealingPayload.self)
        case "rest":
            return decodePayload(RestPayload.self)
        case "mountLPChange":
            return decodePayload(MountLPChangePayload.self)
        default:
            return nil
        }
    }
}
