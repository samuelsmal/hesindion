import Foundation
import SwiftData

// MARK: - Error

enum OptolithImportError: LocalizedError {
    case fileReadFailed
    case invalidFormat(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            "The file could not be read. Please check that the file is accessible and try again."
        case .invalidFormat(let detail):
            "The file is not a valid Optolith export. \(detail)"
        case .saveFailed(let detail):
            "The hero could not be saved. \(detail)"
        }
    }
}

// MARK: - Service

struct OptolithImportService {

    private let rules = RulesDatabase.shared

    private static func eigenschaftsbonus(_ attributeValue: Int) -> Int {
        max(0, Int(floor(Double(attributeValue - 8) / 3.0)))
    }

    // MARK: - Public API

    func importHero(from url: URL, context: ModelContext) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw OptolithImportError.fileReadFailed
        }

        try importHero(from: data, context: context)
    }

    func importHero(from data: Data, context: ModelContext) throws {
        let root: [String: Any]
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw OptolithImportError.invalidFormat("Root is not a JSON object.")
            }
            root = json
        } catch let error as OptolithImportError {
            throw error
        } catch {
            throw OptolithImportError.invalidFormat(error.localizedDescription)
        }

        guard let heroName = root["name"] as? String, !heroName.isEmpty else {
            throw OptolithImportError.invalidFormat("Missing hero name.")
        }

        // Parse avatar
        let avatar = parseAvatar(root["avatar"])

        // Parse attributes first (needed for derived values)
        let attrJSON = root["attr"] as? [String: Any] ?? [:]
        let attributes = parseAttributes(attrJSON)

        // Parse personal data
        let raceId = root["r"] as? String ?? ""
        let cultureId = root["c"] as? String ?? ""
        let professionId = root["p"] as? String ?? ""
        let sex = root["sex"] as? String ?? ""
        let persJSON = root["pers"] as? [String: Any] ?? [:]
        let personalData = parsePersonalData(persJSON, heroName: heroName, sex: sex, raceId: raceId, cultureId: cultureId, professionId: professionId)

        // Parse experience
        let elId = root["el"] as? String ?? ""
        let apJSON = root["ap"] as? [String: Any] ?? [:]
        let experience = parseExperience(elId: elId, apJSON: apJSON)

        // Parse activatables
        let activatableJSON = root["activatable"] as? [String: Any] ?? [:]
        let activatables = parseActivatables(activatableJSON)

        // Parse talents
        let talentsJSON = root["talents"] as? [String: Any] ?? [:]
        let talents = parseTalents(talentsJSON)

        // Parse combat techniques
        let ctJSON = root["ct"] as? [String: Any] ?? [:]
        let combatTechniques = parseCombatTechniques(ctJSON, attributes: attributes)

        // Build CT value lookup for weapon computation
        let ctValues = buildCTValueLookup(ctJSON)

        // Parse spells and liturgies
        let spellsJSON = root["spells"] as? [String: Any] ?? [:]
        let spells = parseSpells(spellsJSON)

        let liturgiesJSON = root["liturgies"] as? [String: Any] ?? [:]
        let liturgies = parseLiturgies(liturgiesJSON)

        // Parse cantrips and blessings
        let cantripIds = root["cantrips"] as? [String] ?? []
        let cantrips = cantripIds.compactMap { id -> HeroTrait? in
            let name = rules.lookup(id: id)?.name ?? id
            return HeroTrait(ruleId: id, name: name)
        }

        let blessingIds = root["blessings"] as? [String] ?? []
        let blessings = blessingIds.compactMap { id -> HeroTrait? in
            let name = rules.lookup(id: id)?.name ?? id
            return HeroTrait(ruleId: id, name: name)
        }

        // Parse items
        let belongingsJSON = root["belongings"] as? [String: Any] ?? [:]
        let itemsJSON = belongingsJSON["items"] as? [String: Any] ?? [:]
        let items = parseItems(itemsJSON, ctValues: ctValues, attributes: attributes)

        // Parse money
        let purseJSON = belongingsJSON["purse"] as? [String: Any] ?? [:]
        let money = parseMoney(purseJSON)

        // Parse pets
        let petsJSON = root["pets"] as? [String: Any] ?? [:]
        let pets = parsePets(petsJSON)

        // Compute derived values
        let purchasedLP = intFromAny(attrJSON["lp"]) ?? 0
        let purchasedAE = intFromAny(attrJSON["ae"]) ?? 0
        let purchasedKP = intFromAny(attrJSON["kp"]) ?? 0
        let derivedValues = computeDerivedValues(
            attributes: attributes,
            raceId: raceId,
            purchasedLP: purchasedLP,
            purchasedAE: purchasedAE,
            purchasedKP: purchasedKP,
            advantages: activatables.advantages
        )

        // Upsert: check for existing hero by name
        let descriptor = FetchDescriptor<Hero>(predicate: #Predicate { $0.name == heroName })
        let existing = try context.fetch(descriptor)

        if let hero = existing.first {
            replaceHeroData(
                hero,
                avatar: avatar,
                activatables: activatables,
                cantrips: cantrips,
                blessings: blessings,
                personalData: personalData,
                experience: experience,
                attributes: attributes,
                derivedValues: derivedValues,
                talents: talents,
                combatTechniques: combatTechniques,
                items: items,
                money: money,
                pets: pets,
                spells: spells,
                liturgies: liturgies,
                context: context
            )
        } else {
            let hero = Hero(
                name: heroName,
                avatar: avatar,
                advantages: activatables.advantages,
                disadvantages: activatables.disadvantages,
                generalSpecialAbilities: activatables.generalSA,
                combatSpecialAbilities: activatables.combatSA,
                cantrips: cantrips,
                blessings: blessings,
                scripts: activatables.scripts
            )
            hero.personalData = personalData
            hero.experience = experience
            hero.attributes = attributes
            hero.derivedValues = derivedValues
            hero.talents = talents
            hero.combatTechniques = combatTechniques
            hero.meleeWeapons = items.weapons
            hero.rangedWeapons = items.rangedWeapons
            hero.armors = items.armors
            hero.shields = items.shields
            hero.equipment = items.equipment
            hero.money = money
            hero.pets = pets
            hero.languages = activatables.languages
            hero.spells = spells
            hero.liturgies = liturgies
            context.insert(hero)
        }

        do {
            try context.save()
        } catch {
            throw OptolithImportError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Upsert

    private func replaceHeroData(
        _ hero: Hero,
        avatar: Data?,
        activatables: ActivatablesResult,
        cantrips: [HeroTrait],
        blessings: [HeroTrait],
        personalData: PersonalData,
        experience: Experience,
        attributes: Attributes,
        derivedValues: DerivedValues,
        talents: [Talent],
        combatTechniques: [CombatTechnique],
        items: ItemsResult,
        money: Money,
        pets: [Pet],
        spells: [HeroSpell],
        liturgies: [HeroSpell],
        context: ModelContext
    ) {
        hero.avatar = avatar
        hero.advantages = activatables.advantages
        hero.disadvantages = activatables.disadvantages
        hero.generalSpecialAbilities = activatables.generalSA
        hero.combatSpecialAbilities = activatables.combatSA
        hero.cantrips = cantrips
        hero.blessings = blessings
        hero.scripts = activatables.scripts

        if let old = hero.personalData { context.delete(old) }
        hero.personalData = personalData

        if let old = hero.experience { context.delete(old) }
        hero.experience = experience

        if let old = hero.attributes { context.delete(old) }
        hero.attributes = attributes

        if let old = hero.derivedValues { context.delete(old) }
        hero.derivedValues = derivedValues

        hero.talents.forEach { context.delete($0) }
        hero.talents = talents

        hero.combatTechniques.forEach { context.delete($0) }
        hero.combatTechniques = combatTechniques

        hero.meleeWeapons.forEach { context.delete($0) }
        hero.meleeWeapons = items.weapons

        hero.armors.forEach { context.delete($0) }
        hero.armors = items.armors

        hero.shields.forEach { context.delete($0) }
        hero.shields = items.shields

        hero.rangedWeapons.forEach { context.delete($0) }
        hero.rangedWeapons = items.rangedWeapons

        hero.equipment.forEach { context.delete($0) }
        hero.equipment = items.equipment

        if let old = hero.money { context.delete(old) }
        hero.money = money

        hero.pets.forEach { context.delete($0) }
        hero.pets = pets

        hero.languages.forEach { context.delete($0) }
        hero.languages = activatables.languages

        hero.spells.forEach { context.delete($0) }
        hero.spells = spells

        hero.liturgies.forEach { context.delete($0) }
        hero.liturgies = liturgies
    }

    // MARK: - Avatar

    private func parseAvatar(_ value: Any?) -> Data? {
        guard let dataURI = value as? String else { return nil }
        // Strip "data:image/...;base64," prefix
        guard let commaIndex = dataURI.firstIndex(of: ",") else {
            return Data(base64Encoded: dataURI)
        }
        let base64 = String(dataURI[dataURI.index(after: commaIndex)...])
        return Data(base64Encoded: base64)
    }

    // MARK: - Attributes

    private func parseAttributes(_ json: [String: Any]) -> Attributes {
        let values = json["values"] as? [[String: Any]] ?? []
        var attrMap: [String: Int] = [:]
        for entry in values {
            if let id = entry["id"] as? String, let val = intFromAny(entry["value"]) {
                attrMap[id] = val
            }
        }
        return Attributes(
            mu: attrMap["ATTR_1"] ?? 8,
            kl: attrMap["ATTR_2"] ?? 8,
            inValue: attrMap["ATTR_3"] ?? 8,
            ch: attrMap["ATTR_4"] ?? 8,
            ff: attrMap["ATTR_5"] ?? 8,
            ge: attrMap["ATTR_6"] ?? 8,
            ko: attrMap["ATTR_7"] ?? 8,
            kk: attrMap["ATTR_8"] ?? 8
        )
    }

    // MARK: - Personal Data

    private func parsePersonalData(
        _ json: [String: Any],
        heroName: String,
        sex: String,
        raceId: String,
        cultureId: String,
        professionId: String
    ) -> PersonalData {
        let hairColorId = intFromAny(json["haircolor"]) ?? 0
        let eyeColorId = intFromAny(json["eyecolor"]) ?? 0
        let socialStatusId = intFromAny(json["socialstatus"]) ?? 0

        let gender: String = switch sex {
        case "m": "männlich"
        case "f": "weiblich"
        default: sex
        }

        let species = rules.lookup(id: raceId)?.name ?? Self.speciesMap[raceId] ?? raceId
        let culture = rules.lookup(id: cultureId)?.name ?? Self.cultureMap[cultureId] ?? cultureId
        let profession = rules.lookup(id: professionId)?.name ?? Self.professionMap[professionId] ?? professionId

        return PersonalData(
            name: heroName,
            family: json["family"] as? String ?? "",
            birthplace: json["placeofbirth"] as? String ?? "",
            birthdate: json["dateofbirth"] as? String ?? "",
            age: intFromAny(json["age"]) ?? 0,
            gender: gender,
            species: species,
            height: intFromAny(json["size"]) ?? 0,
            weight: intFromAny(json["weight"]) ?? 0,
            hairColor: Self.hairColorMap[hairColorId] ?? "\(hairColorId)",
            eyeColor: Self.eyeColorMap[eyeColorId] ?? "\(eyeColorId)",
            culture: culture,
            socialStatus: Self.socialStatusMap[socialStatusId] ?? "\(socialStatusId)",
            profession: profession,
            title: json["title"] as? String ?? "",
            characteristics: json["characteristics"] as? String ?? ""
        )
    }

    // MARK: - Experience

    private func parseExperience(elId: String, apJSON: [String: Any]) -> Experience {
        let level = Self.elMap[elId] ?? elId
        let totalAP = intFromAny(apJSON["total"]) ?? 0
        // Optolith doesn't export spent/available split; derive from total
        return Experience(level: level, totalAP: totalAP, availableAP: 0, spentAP: totalAP)
    }

    // MARK: - Activatables

    private struct ActivatablesResult {
        var advantages: [HeroTrait]
        var disadvantages: [HeroTrait]
        var generalSA: [HeroTrait]
        var combatSA: [HeroTrait]
        var languages: [Language]
        var scripts: [String]
    }

    private func parseActivatables(_ json: [String: Any]) -> ActivatablesResult {
        var advantages: [HeroTrait] = []
        var disadvantages: [HeroTrait] = []
        var generalSA: [HeroTrait] = []
        var combatSA: [HeroTrait] = []
        var languages: [Language] = []
        var scripts: [String] = []

        for (key, value) in json {
            guard let instances = value as? [[String: Any]], !instances.isEmpty else { continue }

            if key == "SA_29" {
                // Languages
                for inst in instances {
                    let sid = stringFromAny(inst["sid"]) ?? "?"
                    let tier = intFromAny(inst["tier"])
                    let langName = rules.lookup(id: "LANG_\(sid)")?.name ?? "Sprache \(sid)"
                    let levelStr = tier.map { $0 >= 4 ? "MS" : "\($0)" } ?? "MS"
                    languages.append(Language(name: langName, level: levelStr))
                }
                continue
            }

            if key == "SA_27" {
                // Scripts
                for inst in instances {
                    let sid = stringFromAny(inst["sid"]) ?? "?"
                    let scriptName = rules.lookup(id: "SCRIPT_\(sid)")?.name ?? "Schrift \(sid)"
                    scripts.append(scriptName)
                }
                continue
            }

            let ruleName = rules.lookup(id: key)?.name ?? key

            for inst in instances {
                let tier = intFromAny(inst["tier"])
                let sid = stringFromAny(inst["sid"])
                let sid2 = stringFromAny(inst["sid2"])
                let resolvedSid: String? = if let rawSid = sid, let numericSid = Int(rawSid) {
                    rules.lookupSelectOption(ruleId: key, sid: numericSid) ?? sid
                } else {
                    sid
                }
                let displaySid = sid2 ?? resolvedSid

                let trait = HeroTrait(ruleId: key, name: ruleName, tier: tier, sid: displaySid)

                if key.hasPrefix("ADV_") {
                    advantages.append(trait)
                } else if key.hasPrefix("DISADV_") {
                    disadvantages.append(trait)
                } else if key.hasPrefix("SA_") {
                    if isCombatSpecialAbility(id: key) {
                        combatSA.append(trait)
                    } else {
                        generalSA.append(trait)
                    }
                }
                // Skip other activatable prefixes (traditions, etc.) that don't map to our model
            }
        }

        return ActivatablesResult(
            advantages: advantages,
            disadvantages: disadvantages,
            generalSA: generalSA,
            combatSA: combatSA,
            languages: languages,
            scripts: scripts
        )
    }

    /// Check if a special ability is combat-related using the rules database.
    /// Falls back to `false` (general SA) if the rule is not found.
    private func isCombatSpecialAbility(id: String) -> Bool {
        guard let rule = rules.lookup(id: id) else { return false }
        // The rules.db effects with scope "combat" indicate combat special abilities
        return rule.effects.contains { $0.scope == "combat" }
    }

    // MARK: - Talents

    private func parseTalents(_ json: [String: Any]) -> [Talent] {
        var talentsByRuleId: [String: Talent] = [:]
        for (key, value) in json {
            guard let val = intFromAny(value) else { continue }
            let name = rules.lookup(id: key)?.name ?? key
            let category = Self.talentCategory(for: key)
            talentsByRuleId[key] = Talent(ruleId: key, name: name, value: val, category: category)
        }
        // Fill in all 59 standard talents with value 0 if not present in import
        for num in 1...59 {
            let ruleId = "TAL_\(num)"
            if talentsByRuleId[ruleId] == nil {
                let name = rules.lookup(id: ruleId)?.name ?? ruleId
                let category = Self.talentCategory(for: ruleId)
                talentsByRuleId[ruleId] = Talent(ruleId: ruleId, name: name, value: 0, category: category)
            }
        }
        return talentsByRuleId.values.sorted { $0.name < $1.name }
    }

    // MARK: - Combat Techniques

    private func parseCombatTechniques(_ json: [String: Any], attributes: Attributes) -> [CombatTechnique] {
        let allCTIds = rules.allCombatTechniqueIds()
        let muBonus = Self.eigenschaftsbonus(attributes.mu)

        return allCTIds.compactMap { ctId -> CombatTechnique? in
            let name = rules.lookup(id: ctId)?.name ?? ctId
            let ktw = (json[ctId]).flatMap { intFromAny($0) } ?? 6
            let detail = rules.lookupCombatTechniqueDetail(ruleId: ctId)

            let atValue = ktw + muBonus

            let paValue: Int
            if detail?.hasNoParry == true {
                paValue = 0
            } else {
                let primaryAttrValue: Int
                if let d = detail {
                    let v1 = d.primaryAttr1.map { attributes.value(for: $0) } ?? 8
                    let v2 = d.primaryAttr2.map { attributes.value(for: $0) } ?? 8
                    primaryAttrValue = max(v1, v2)
                } else {
                    primaryAttrValue = 8
                }
                paValue = (ktw + 1) / 2 + Self.eigenschaftsbonus(primaryAttrValue)
            }

            return CombatTechnique(ruleId: ctId, name: name, value: ktw, at: atValue, pa: paValue)
        }
        .sorted { $0.name < $1.name }
    }

    private func buildCTValueLookup(_ json: [String: Any]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (key, value) in json {
            if let val = intFromAny(value) {
                result[key] = val
            }
        }
        return result
    }

    // MARK: - Spells & Liturgies

    private func parseSpells(_ json: [String: Any]) -> [HeroSpell] {
        json.compactMap { key, value -> HeroSpell? in
            guard let val = intFromAny(value) else { return nil }
            let name = rules.lookup(id: key)?.name ?? key
            return HeroSpell(ruleId: key, name: name, value: val)
        }
        .sorted { $0.name < $1.name }
    }

    private func parseLiturgies(_ json: [String: Any]) -> [HeroSpell] {
        json.compactMap { key, value -> HeroSpell? in
            guard let val = intFromAny(value) else { return nil }
            let name = rules.lookup(id: key)?.name ?? key
            return HeroSpell(ruleId: key, name: name, value: val)
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Items

    private struct ItemsResult {
        var weapons: [MeleeWeapon]
        var armors: [Armor]
        var shields: [Shield]
        var rangedWeapons: [RangedWeapon]
        var equipment: [EquipmentItem]
    }

    private func parseItems(_ json: [String: Any], ctValues: [String: Int], attributes: Attributes) -> ItemsResult {
        var weapons: [MeleeWeapon] = []
        var armors: [Armor] = []
        var shields: [Shield] = []
        var rangedWeapons: [RangedWeapon] = []
        var equipment: [EquipmentItem] = []

        for (_, value) in json {
            guard let item = value as? [String: Any] else { continue }
            let gr = intFromAny(item["gr"]) ?? 5
            let name = item["name"] as? String ?? "?"
            let weight = doubleFromAny(item["weight"]) ?? 0.0

            switch gr {
            case 1:
                // Weapon (could be melee or ranged; we handle melee here)
                guard let ctId = item["combatTechnique"] as? String else {
                    // No combat technique means general equipment
                    let price = intFromAny(item["price"]) ?? 0
                    equipment.append(EquipmentItem(name: name, value: price, weight: weight))
                    continue
                }

                // Check for shield (CT_10 = Schilde)
                if ctId == "CT_10" {
                    let stp = intFromAny(item["stp"]) ?? 0
                    let ctVal = ctValues[ctId] ?? 6
                    let detail = rules.lookupCombatTechniqueDetail(ruleId: ctId)
                    let muBonus = Self.eigenschaftsbonus(attributes.mu)
                    let baseAT = ctVal + muBonus
                    let primaryAttrValue: Int
                    if let d = detail {
                        let v1 = d.primaryAttr1.map { attributes.value(for: $0) } ?? 8
                        let v2 = d.primaryAttr2.map { attributes.value(for: $0) } ?? 8
                        primaryAttrValue = max(v1, v2)
                    } else {
                        primaryAttrValue = 8
                    }
                    let basePA = (ctVal + 1) / 2 + Self.eigenschaftsbonus(primaryAttrValue)
                    let atMod = intFromAny(item["at"]) ?? 0
                    let paMod = intFromAny(item["pa"]) ?? 0
                    let damage = formatDamage(item)
                    let reach = Self.reachMap[intFromAny(item["reach"]) ?? 1] ?? "Kurz"
                    let template = item["template"] as? String ?? ""
                    let note = Self.shieldNote(for: template)
                    shields.append(Shield(
                        name: name,
                        damage: damage,
                        at: baseAT + atMod,
                        pa: basePA + 2 * paMod,
                        paModifier: paMod,
                        note: note,
                        reach: reach,
                        structurePoints: stp,
                        weight: weight
                    ))
                } else {
                    let ctVal = ctValues[ctId] ?? 6
                    let detail = rules.lookupCombatTechniqueDetail(ruleId: ctId)
                    let muBonus = Self.eigenschaftsbonus(attributes.mu)
                    let baseAT = ctVal + muBonus
                    let primaryAttrValue: Int
                    if let d = detail {
                        let v1 = d.primaryAttr1.map { attributes.value(for: $0) } ?? 8
                        let v2 = d.primaryAttr2.map { attributes.value(for: $0) } ?? 8
                        primaryAttrValue = max(v1, v2)
                    } else {
                        primaryAttrValue = 8
                    }
                    let basePA = (ctVal + 1) / 2 + Self.eigenschaftsbonus(primaryAttrValue)
                    let atMod = intFromAny(item["at"]) ?? 0
                    let paMod = intFromAny(item["pa"]) ?? 0
                    let damage = formatDamage(item)
                    let reach = Self.reachMap[intFromAny(item["reach"]) ?? 1] ?? "Kurz"
                    weapons.append(MeleeWeapon(
                        name: name,
                        combatTechniqueId: ctId,
                        damage: damage,
                        at: baseAT + atMod,
                        pa: basePA + paMod,
                        reach: reach,
                        weight: weight
                    ))
                }

            case 2:
                // Ranged weapon
                guard let ctId = item["combatTechnique"] as? String else {
                    let price = intFromAny(item["price"]) ?? 0
                    equipment.append(EquipmentItem(name: name, value: price, weight: weight))
                    continue
                }
                let ctVal = ctValues[ctId] ?? 6
                let detail = rules.lookupCombatTechniqueDetail(ruleId: ctId)
                let primaryAttrValue: Int
                if let d = detail {
                    let v1 = d.primaryAttr1.map { attributes.value(for: $0) } ?? 8
                    let v2 = d.primaryAttr2.map { attributes.value(for: $0) } ?? 8
                    primaryAttrValue = max(v1, v2)
                } else {
                    primaryAttrValue = 8
                }
                let baseFK = ctVal + Self.eigenschaftsbonus(primaryAttrValue)
                let atMod = intFromAny(item["at"]) ?? 0
                let damage = formatDamage(item)
                let range = formatRange(item)
                rangedWeapons.append(RangedWeapon(
                    name: name,
                    combatTechniqueId: ctId,
                    damage: damage,
                    at: baseFK + atMod,
                    range: range,
                    weight: weight
                ))

            case 4:
                // Armor
                let pro = intFromAny(item["pro"]) ?? 0
                let enc = intFromAny(item["enc"]) ?? 0
                let iniMod = intFromAny(item["iniMod"]) ?? 0
                let movMod = intFromAny(item["movMod"]) ?? 0
                armors.append(Armor(name: name, protectionValue: pro, encumbrance: enc, weight: weight, iniModifier: iniMod, gsModifier: movMod))

            default:
                // General equipment (gr=3 ammunition, gr=5 general, etc.)
                let price = intFromAny(item["price"]) ?? 0
                equipment.append(EquipmentItem(name: name, value: price, weight: weight))
            }
        }

        return ItemsResult(weapons: weapons, armors: armors, shields: shields, rangedWeapons: rangedWeapons, equipment: equipment)
    }

    private func formatDamage(_ item: [String: Any]) -> String {
        let diceNum = intFromAny(item["damageDiceNumber"]) ?? 0
        let diceSides = intFromAny(item["damageDiceSides"]) ?? 6
        let flat = intFromAny(item["damageFlat"]) ?? 0

        if diceNum == 0 && flat == 0 { return "0" }

        var parts: [String] = []
        if diceNum > 0 {
            parts.append("\(diceNum)W\(diceSides)")
        }
        if flat > 0 {
            parts.append("+\(flat)")
        } else if flat < 0 {
            parts.append("\(flat)")
        }
        return parts.joined()
    }

    private func formatRange(_ item: [String: Any]) -> String {
        let close = intFromAny(item["range1"]) ?? 0
        let medium = intFromAny(item["range2"]) ?? 0
        let far = intFromAny(item["range3"]) ?? 0
        if close == 0 && medium == 0 && far == 0 { return "—" }
        return "\(close)/\(medium)/\(far)"
    }

    // MARK: - Money

    private func parseMoney(_ json: [String: Any]) -> Money {
        Money(
            dukaten: intFromAny(json["d"]) ?? 0,
            silbertaler: intFromAny(json["s"]) ?? 0,
            heller: intFromAny(json["h"]) ?? 0,
            kreuzer: intFromAny(json["k"]) ?? 0
        )
    }

    // MARK: - Pets

    private func parsePets(_ json: [String: Any]) -> [Pet] {
        json.compactMap { key, value -> Pet? in
            guard let pet = value as? [String: Any] else { return nil }
            let name = pet["name"] as? String ?? "?"
            let type = pet["type"] as? String ?? ""
            let avatar = parseAvatar(pet["avatar"])
            let size = doubleFromAny(pet["size"]) ?? 0.0

            let attributes = PetAttributes(
                mu: intFromAny(pet["cou"]) ?? 0,
                kl: intFromAny(pet["sgc"]) ?? 0,
                inValue: intFromAny(pet["int"]) ?? 0,
                ch: intFromAny(pet["cha"]) ?? 0,
                ff: intFromAny(pet["dex"]) ?? 0,
                ge: intFromAny(pet["agi"]) ?? 0,
                ko: intFromAny(pet["con"]) ?? 0,
                kk: intFromAny(pet["str"]) ?? 0
            )

            return Pet(
                petId: key,
                name: name,
                avatar: avatar,
                size: size,
                type: type,
                attributes: attributes,
                lifeEnergy: intFromAny(pet["lp"]) ?? 0,
                spirit: intFromAny(pet["spi"]) ?? 0,
                toughness: intFromAny(pet["tou"]) ?? 0,
                initiative: pet["ini"] as? String ?? "",
                speed: intFromAny(pet["mov"]) ?? 0,
                attack: pet["attack"] as? String ?? "",
                damage: pet["dp"] as? String ?? "",
                reach: pet["reach"] as? String ?? "",
                actions: intFromAny(pet["actions"]) ?? 1,
                talents: pet["talents"] as? String ?? "",
                skills: pet["skills"] as? String ?? "",
                notes: pet["notes"] as? String ?? "",
                attacks: parsePetAttacks(notes: pet["notes"] as? String ?? ""),
                specialSkills: pet["skills"] as? String ?? ""
            )
        }
    }

    /// Parses attack entries from pet notes. Format: "Name: AT \d+ TP \d+W\d+[+-]\d+ RW (kurz|mittel|lang)"
    private func parsePetAttacks(notes: String) -> [PetAttack] {
        let pattern = /([A-ZÄÖÜa-zäöüß]+):\s*AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)/
        return notes.matches(of: pattern).map { match in
            PetAttack(
                name: String(match.1),
                at: Int(match.2) ?? 0,
                damage: String(match.3),
                reach: String(match.4)
            )
        }
    }

    // MARK: - Derived Values

    private static let speciesBaseLP: [String: Int] = [
        "R_1": 5,  // Menschen
        "R_2": 2,  // Elfen
        "R_3": 5,  // Halbelfen
        "R_4": 8,  // Zwerge
    ]

    private static let speciesBaseSK: [String: Int] = [
        "R_1": -5,  // Menschen
        "R_2": -4,  // Elfen
        "R_3": -5,  // Halbelfen
        "R_4": -4,  // Zwerge
    ]

    private static let speciesBaseZK: [String: Int] = [
        "R_1": -5,  // Menschen
        "R_2": -6,  // Elfen
        "R_3": -5,  // Halbelfen
        "R_4": -4,  // Zwerge
    ]

    private func computeDerivedValues(
        attributes: Attributes,
        raceId: String,
        purchasedLP: Int,
        purchasedAE: Int,
        purchasedKP: Int,
        advantages: [HeroTrait]
    ) -> DerivedValues {
        let mu = attributes.mu
        let kl = attributes.kl
        let inVal = attributes.inValue
        let ge = attributes.ge
        let ko = attributes.ko
        let kk = attributes.kk

        // LE: base = species base LP + KO * 2
        let speciesLP = Self.speciesBaseLP[raceId] ?? 5
        let leBase = speciesLP + ko * 2
        let hoheLebenskraftBonus = advantages
            .filter { $0.ruleId == "ADV_25" }
            .reduce(0) { $0 + ($1.tier ?? 1) }
        let leMax = leBase + purchasedLP + hoheLebenskraftBonus
        let lebensenergie = LifeEnergyValue(
            base: leBase, bonus: hoheLebenskraftBonus, purchased: purchasedLP,
            max: leMax, current: leMax
        )

        // AE: only present if hero has magic (purchasedAE > 0 or relevant tradition)
        var astralenergie: MutableResourceValue? = nil
        if purchasedAE > 0 {
            let aeBase = 20
            let aeMax = aeBase + purchasedAE
            astralenergie = MutableResourceValue(current: aeMax, bonus: 0, max: aeMax)
        }

        // KE: only present if hero has karma (purchasedKP > 0 or relevant tradition)
        var karmaenergie: MutableResourceValue? = nil
        if purchasedKP > 0 {
            let keBase = 20
            let keMax = keBase + purchasedKP
            karmaenergie = MutableResourceValue(current: keMax, bonus: 0, max: keMax)
        }

        // SK = species base + ceil((MU + KL + IN) / 6)
        let speciesSK = Self.speciesBaseSK[raceId] ?? -5
        let skBase = speciesSK + Int(ceil(Double(mu + kl + inVal) / 6.0))
        let hoheSeelenkraftBonus = advantages
            .filter { $0.ruleId == "ADV_26" }
            .reduce(0) { $0 + ($1.tier ?? 1) }
        let skMax = skBase + hoheSeelenkraftBonus
        let seelenkraft = ResourceValue(base: skBase, bonus: hoheSeelenkraftBonus, max: skMax)

        // ZK = species base + ceil((KO + KO + KK) / 6)
        let speciesZK = Self.speciesBaseZK[raceId] ?? -5
        let zkBase = speciesZK + Int(ceil(Double(ko + ko + kk) / 6.0))
        let hoheZaehigkeitBonus = advantages
            .filter { $0.ruleId == "ADV_27" }
            .reduce(0) { $0 + ($1.tier ?? 1) }
        let zkMax = zkBase + hoheZaehigkeitBonus
        let zaehigkeit = ResourceValue(base: zkBase, bonus: hoheZaehigkeitBonus, max: zkMax)

        // INI = (MU + GE) / 2
        let iniValue = (mu + ge) / 2
        let initiative = ComputedValue(value: iniValue, bonus: 0, max: iniValue)

        // AW = GE / 2
        let awValue = ge / 2
        let ausweichen = ComputedValue(value: awValue, bonus: 0, max: awValue)

        // GS = 8 (Mensch base)
        let geschwindigkeit = ResourceValue(base: 8, bonus: 0, max: 8)

        // WS = KO / 2
        let wsValue = ko / 2
        let wundschwelle = ComputedValue(value: wsValue, bonus: 0, max: wsValue)

        // Schicksalspunkte: base 3 for Mensch
        let schipBase = 3
        let schicksalspunkte = MutableResourceValue(current: schipBase, bonus: 0, max: schipBase)

        return DerivedValues(
            lebensenergie: lebensenergie,
            astralenergie: astralenergie,
            karmaenergie: karmaenergie,
            seelenkraft: seelenkraft,
            zaehigkeit: zaehigkeit,
            ausweichen: ausweichen,
            initiative: initiative,
            geschwindigkeit: geschwindigkeit,
            wundschwelle: wundschwelle,
            schicksalspunkte: schicksalspunkte
        )
    }

    // MARK: - Talent Category Mapping

    /// DSA 5e talent ID ranges:
    /// TAL_1..TAL_14  = Koerpertalente
    /// TAL_15..TAL_22 = Gesellschaftstalente
    /// TAL_23..TAL_29 = Naturtalente
    /// TAL_30..TAL_42 = Wissenstalente
    /// TAL_43..TAL_59 = Handwerkstalente
    private static func talentCategory(for id: String) -> String {
        guard let numStr = id.split(separator: "_").last, let num = Int(numStr) else {
            return "Handwerkstalente"
        }
        switch num {
        case 1...14: return "Körpertalente"
        case 15...22: return "Gesellschaftstalente"
        case 23...29: return "Naturtalente"
        case 30...42: return "Wissenstalente"
        default: return "Handwerkstalente"
        }
    }

    // MARK: - JSON Value Helpers

    /// Extracts an Int from a value that may be Int, Double, or String.
    private func intFromAny(_ value: Any?) -> Int? {
        switch value {
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let s as String: return Int(s)
        case let n as NSNumber: return n.intValue
        default: return nil
        }
    }

    /// Extracts a Double from a value that may be Double, Int, or String.
    private func doubleFromAny(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }

    /// Extracts a String from a value that may be String, Int, or Double.
    private func stringFromAny(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let i as Int: return "\(i)"
        case let d as Double: return "\(Int(d))"
        default: return nil
        }
    }

    // MARK: - Static Maps

    private static let elMap: [String: String] = [
        "EL_1": "Unerfahren", "EL_2": "Durchschnittlich", "EL_3": "Erfahren",
        "EL_4": "Kompetent", "EL_5": "Meisterlich", "EL_6": "Brilliant", "EL_7": "Legendär",
    ]

    private static func shieldNote(for template: String) -> String {
        switch template {
        case "ITEMTPL_29": return "+1 PA vs. Fernkampf"
        default: return ""
        }
    }

    private static let reachMap: [Int: String] = [1: "Kurz", 2: "Mittel", 3: "Lang"]

    private static let hairColorMap: [Int: String] = [
        1: "schwarz", 2: "blond", 3: "braun", 4: "rot", 5: "weiß",
        6: "dunkelblond", 7: "hellbraun", 8: "dunkelbraun", 9: "rotblond",
        10: "grau", 11: "silber",
    ]

    private static let eyeColorMap: [Int: String] = [
        1: "grün", 2: "braun", 3: "schwarz", 4: "blau", 5: "grau",
        6: "bernstein", 7: "dunkelbraun", 8: "hellbraun", 9: "dunkelgrün",
        10: "hellgrün", 11: "dunkelblau", 12: "hellblau", 13: "dunkelgrau",
        14: "hellgrau", 15: "schwarz",
    ]

    private static let socialStatusMap: [Int: String] = [
        1: "Unfrei", 2: "Frei", 3: "Niederadel", 4: "Hochadel",
    ]

    private static let speciesMap: [String: String] = [
        "R_1": "Menschen", "R_2": "Elfen", "R_3": "Halbelfen", "R_4": "Zwerge",
    ]

    private static let cultureMap: [String: String] = [
        "C_1": "Andergaster", "C_2": "Aranier", "C_3": "Bornländer",
        "C_4": "Fjarninger", "C_5": "Horasier", "C_6": "Zyklopeninsulaner",
        "C_7": "Maraskaner", "C_8": "Mittelreicher", "C_9": "Moha",
        "C_10": "Norbarden", "C_11": "Nivesen", "C_12": "Nostrier",
        "C_13": "Südaventurier", "C_14": "Svelltaler", "C_15": "Thorwaler",
        "C_16": "Trollzacker", "C_17": "Ambosszwerge", "C_18": "Brillantzwerge",
        "C_19": "Erzzwerge", "C_20": "Hügelzwerge", "C_21": "Auelfen",
        "C_22": "Firnelfen", "C_23": "Waldelfen", "C_24": "Ferkina",
        "C_25": "Gjalskerländer",
    ]

    private static let professionMap: [String: String] = [
        "P_1": "Akademie-Magier", "P_2": "Alchimist",
        "P_3": "Borongeweihter", "P_4": "Efferdgeweihter",
        "P_5": "Firungeweihter", "P_6": "Hesindegeweihter",
        "P_7": "Ingerimmgeweihter", "P_8": "Perainegeweihter",
        "P_9": "Phexgeweihter", "P_10": "Praiosgeweihter",
        "P_11": "Rahjageweihter", "P_12": "Rondrageweihter",
        "P_13": "Travia-Geweihter", "P_14": "Tsakgeweihter",
        "P_15": "Durro-Dûn", "P_16": "Gildenloser Magier",
        "P_17": "Hexe", "P_18": "Schelm",
        "P_19": "Scharfschütze", "P_20": "Krieger",
        "P_21": "Ritter", "P_22": "Söldner",
        "P_23": "Gardist", "P_24": "Stammeskrieger",
        "P_25": "Schwertgeselle", "P_26": "Kundschafter",
        "P_27": "Jäger", "P_28": "Waldläufer",
        "P_29": "Händler", "P_30": "Barde",
        "P_31": "Gauner", "P_32": "Einbrecher",
        "P_33": "Bettler", "P_34": "Gladiator",
        "P_35": "Medicus", "P_36": "Gelehrter",
        "P_37": "Kartograph", "P_38": "Grenzjäger",
        "P_39": "Wildnisführer", "P_40": "Pirat",
        "P_41": "Fischer", "P_42": "Seefahrer",
        "P_43": "Handwerker", "P_44": "Bauer",
        "P_45": "Diener", "P_46": "Wundarzt",
        "P_47": "Magiedilettant (Halbzauberer)",
        "P_48": "Magiedilettant (Viertelzauberer)",
        "P_49": "Animist", "P_50": "Geode",
        "P_51": "Zauberweber", "P_52": "Kristallomant",
        "P_53": "Qabalyamagier", "P_54": "Zauberbarde",
        "P_55": "Zaubertänzer",
        "P_100": "Bannstrahler", "P_101": "Magier",
        "P_102": "Borbaradianer",
        "P_103": "Kor-Geweihter", "P_104": "Gravesh-Priester",
        "P_105": "Namenloser Geweihter",
        "P_106": "Swafnir-Geweihter", "P_107": "Ifirn-Geweihter",
        "P_108": "Golgarit", "P_109": "Ordenskrieger",
        "P_110": "Maraskaner Derwisch", "P_111": "Gjalskerländer Tierkrieger",
        "P_112": "Hazaqi", "P_113": "Sharisad",
        "P_114": "Zibilja", "P_115": "Fakir",
        "P_116": "Sangara",
        "P_120": "Lanisto", "P_121": "Ferkina-Krieger",
        "P_122": "Kopfgeldjäger",
        "P_123": "Abdecker", "P_124": "Henker",
        "P_125": "Adersin", "P_126": "Amazone",
        "P_127": "Basarer", "P_128": "Eremit",
        "P_129": "Fuhrmann", "P_130": "Prospektor",
    ]
}
