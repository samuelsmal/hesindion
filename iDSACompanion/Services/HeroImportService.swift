import Foundation
import SwiftData

enum HeroImportError: LocalizedError {
    case fileReadFailed
    case decodingFailed(String)
    case saveFailed(String)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "The file could not be read. Please check that the file is accessible and try again."
        case .decodingFailed(let detail):
            return "The file is not a valid hero. \(detail)"
        case .saveFailed(let detail):
            return "The hero could not be saved. \(detail)"
        case .unsupportedFormat(let ext):
            return "'\(ext)' is not a supported format. Please import a .json or .yaml file."
        }
    }
}

struct HeroImportService {

    /// Import a hero from a file URL, detecting the format by file extension.
    /// Security-scoped resource access is handled internally.
    func importHero(from url: URL, context: ModelContext) throws {
        let ext = url.pathExtension.lowercased()

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw HeroImportError.fileReadFailed
        }

        switch ext {
        case "json":
            try importHero(from: data, context: context)
        case "yaml", "yml":
            throw HeroImportError.unsupportedFormat("YAML import requires the Yams package (not yet available)")
        default:
            throw HeroImportError.unsupportedFormat(ext.isEmpty ? "(no extension)" : ext)
        }
    }

    func importHero(from data: Data, context: ModelContext) throws {
        // 1. Decode
        let dto: HeroDTO
        do {
            dto = try JSONDecoder().decode(HeroDTO.self, from: data)
        } catch let error as DecodingError {
            throw HeroImportError.decodingFailed(error.localizedDescription)
        } catch {
            throw HeroImportError.decodingFailed(error.localizedDescription)
        }

        let heroName = dto.personalData.name

        // 2. Check for existing hero
        let descriptor = FetchDescriptor<Hero>(predicate: #Predicate { $0.name == heroName })
        let existing = try context.fetch(descriptor)

        if let hero = existing.first {
            // 3. Upsert: replace all non-preserved relationships
            replaceChildren(of: hero, with: dto, context: context)
        } else {
            // 4. New hero: create everything including equipment and money
            let hero = Hero(
                name: heroName,
                advantages: dto.advantages,
                disadvantages: dto.disadvantages,
                generalSpecialAbilities: dto.specialAbilities.general,
                combatSpecialAbilities: dto.specialAbilities.combat,
                scripts: dto.scripts,
                carryingCapacity: dto.carryingCapacity
            )
            hero.personalData = makePersonalData(dto.personalData)
            hero.experience = makeExperience(dto.experience)
            hero.attributes = makeAttributes(dto.attributes)
            hero.derivedValues = makeDerivedValues(dto.derivedValues)
            hero.talents = makeTalents(dto.talents)
            hero.combatTechniques = makeCombatTechniques(dto.combatTechniques)
            hero.meleeWeapons = makeMeleeWeapons(dto.meleeWeapons)
            hero.armor = makeArmor(dto.armor)
            hero.shield = dto.shield.map(makeShield)
            hero.equipment = makeEquipment(dto.equipment)
            hero.money = makeMoney(dto.money)
            hero.mount = dto.mount.map(makeMount)
            hero.languages = makeLanguages(dto.languages)
            context.insert(hero)
        }

        // 5. Save
        do {
            try context.save()
        } catch {
            throw HeroImportError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Upsert helpers

    private func replaceChildren(of hero: Hero, with dto: HeroDTO, context: ModelContext) {
        // Update scalar properties
        hero.advantages = dto.advantages
        hero.disadvantages = dto.disadvantages
        hero.generalSpecialAbilities = dto.specialAbilities.general
        hero.combatSpecialAbilities = dto.specialAbilities.combat
        hero.scripts = dto.scripts
        hero.carryingCapacity = dto.carryingCapacity

        // Replace personal data
        if let old = hero.personalData { context.delete(old) }
        hero.personalData = makePersonalData(dto.personalData)

        // Replace experience
        if let old = hero.experience { context.delete(old) }
        hero.experience = makeExperience(dto.experience)

        // Replace attributes
        if let old = hero.attributes { context.delete(old) }
        hero.attributes = makeAttributes(dto.attributes)

        // Replace derived values
        if let old = hero.derivedValues { context.delete(old) }
        hero.derivedValues = makeDerivedValues(dto.derivedValues)

        // Replace talents
        hero.talents.forEach { context.delete($0) }
        hero.talents = makeTalents(dto.talents)

        // Replace combat techniques
        hero.combatTechniques.forEach { context.delete($0) }
        hero.combatTechniques = makeCombatTechniques(dto.combatTechniques)

        // Replace melee weapons
        hero.meleeWeapons.forEach { context.delete($0) }
        hero.meleeWeapons = makeMeleeWeapons(dto.meleeWeapons)

        // Replace armor
        if let old = hero.armor { context.delete(old) }
        hero.armor = makeArmor(dto.armor)

        // Replace shield
        if let old = hero.shield { context.delete(old) }
        hero.shield = dto.shield.map(makeShield)

        // Replace mount
        if let old = hero.mount { context.delete(old) }
        hero.mount = dto.mount.map(makeMount)

        // Replace languages
        hero.languages.forEach { context.delete($0) }
        hero.languages = makeLanguages(dto.languages)

        // equipment and money are intentionally preserved — do not touch them
    }

    // MARK: - Factory methods

    private func makePersonalData(_ dto: PersonalDataDTO) -> PersonalData {
        PersonalData(
            name: dto.name,
            family: dto.family,
            birthplace: dto.birthplace,
            birthdate: dto.birthdate,
            age: dto.age,
            gender: dto.gender,
            species: dto.species,
            height: dto.height,
            weight: dto.weight,
            hairColor: dto.hairColor,
            eyeColor: dto.eyeColor,
            culture: dto.culture,
            socialStatus: dto.socialStatus,
            profession: dto.profession,
            title: dto.title,
            characteristics: dto.characteristics
        )
    }

    private func makeExperience(_ dto: ExperienceDTO) -> Experience {
        Experience(level: dto.level, totalAP: dto.totalAP, availableAP: dto.availableAP, spentAP: dto.spentAP)
    }

    private func makeAttributes(_ dto: AttributesDTO) -> Attributes {
        Attributes(mu: dto.MU, kl: dto.KL, inValue: dto.IN, ch: dto.CH, ff: dto.FF, ge: dto.GE, ko: dto.KO, kk: dto.KK)
    }

    private func makeDerivedValues(_ dto: DerivedValuesDTO) -> DerivedValues {
        DerivedValues(
            lebensenergie: dto.lebensenergie,
            astralenergie: dto.astralenergie,
            karmaenergie: dto.karmaenergie,
            seelenkraft: dto.seelenkraft,
            zaehigkeit: dto.zähigkeit,
            ausweichen: dto.ausweichen,
            initiative: dto.initiative,
            geschwindigkeit: dto.geschwindigkeit,
            wundschwelle: dto.wundschwelle,
            schicksalspunkte: dto.schicksalspunkte
        )
    }

    private func makeTalents(_ dto: TalentsContainerDTO) -> [Talent] {
        var result: [Talent] = []
        result += dto.körpertalente.map { Talent(name: $0.name, value: $0.value, category: "körpertalente") }
        result += dto.gesellschaftstalente.map { Talent(name: $0.name, value: $0.value, category: "gesellschaftstalente") }
        result += dto.naturtalente.map { Talent(name: $0.name, value: $0.value, category: "naturtalente") }
        result += dto.wissenstalente.map { Talent(name: $0.name, value: $0.value, category: "wissenstalente") }
        result += dto.handwerkstalente.map { Talent(name: $0.name, value: $0.value, category: "handwerkstalente") }
        return result
    }

    private func makeCombatTechniques(_ dtos: [CombatTechniqueDTO]) -> [CombatTechnique] {
        dtos.map { CombatTechnique(name: $0.name, value: $0.value, at: $0.at, pa: $0.pa) }
    }

    private func makeMeleeWeapons(_ dtos: [MeleeWeaponDTO]) -> [MeleeWeapon] {
        dtos.map { MeleeWeapon(name: $0.name, technique: $0.technique, damage: $0.damage, at: $0.at, pa: $0.pa, reach: $0.reach, weight: $0.weight) }
    }

    private func makeArmor(_ dto: ArmorDTO) -> Armor {
        Armor(name: dto.name, protectionValue: dto.protectionValue, armorRating: dto.armorRating, encumbrance: dto.encumbrance, weight: dto.weight)
    }

    private func makeShield(_ dto: ShieldDTO) -> Shield {
        Shield(name: dto.name, structure: dto.structure, breakingFactor: dto.breakingFactor, atMod: dto.atMod, paMod: dto.paMod, weight: dto.weight)
    }

    private func makeEquipment(_ dtos: [EquipmentItemDTO]) -> [EquipmentItem] {
        dtos.map { EquipmentItem(name: $0.name, value: $0.value, weight: $0.weight) }
    }

    private func makeMoney(_ dto: MoneyDTO) -> Money {
        Money(dukaten: dto.dukaten, silbertaler: dto.silbertaler, heller: dto.heller, kreuzer: dto.kreuzer)
    }

    private func makeMount(_ dto: MountDTO) -> Mount {
        Mount(
            name: dto.name,
            size: dto.size,
            mountType: dto.mountType,
            attributes: dto.attributes,
            lifeEnergy: dto.lifeEnergy,
            initiative: dto.initiative,
            speed: dto.speed,
            attacks: dto.attacks,
            talents: dto.talents,
            specialAbilities: dto.specialAbilities
        )
    }

    private func makeLanguages(_ dict: [String: String]) -> [Language] {
        dict.map { Language(name: $0.key, level: $0.value) }
    }
}
