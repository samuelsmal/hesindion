# SwiftData Migration Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add VersionedSchema + SchemaMigrationPlan so model changes no longer crash the app.

**Architecture:** Create a `Hesindion/Migration/` directory with a frozen V1 schema snapshot of all 16 models and a migration plan. Update `HesindionApp.swift` to use the migration plan for container creation.

**Tech Stack:** SwiftData (VersionedSchema, SchemaMigrationPlan), Swift 6

---

### Task 1: Create SchemaV1 snapshot

**Files:**
- Create: `Hesindion/Migration/SchemaV1.swift`

**Step 1: Create the SchemaV1 enum with all 16 model snapshots**

Create `Hesindion/Migration/SchemaV1.swift` with the following content. This is a frozen snapshot of the current schema — it must never be modified after creation.

```swift
import SwiftData
import Foundation

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Hero.self,
            PersonalData.self,
            Experience.self,
            Attributes.self,
            DerivedValues.self,
            Talent.self,
            CombatTechnique.self,
            MeleeWeapon.self,
            RangedWeapon.self,
            Armor.self,
            Shield.self,
            EquipmentItem.self,
            Money.self,
            Pet.self,
            Language.self,
            HeroSpell.self,
        ]
    }

    // MARK: - Value Types (Codable structs embedded in models)

    struct LifeEnergyValue: Codable {
        var base: Int
        var bonus: Int
        var purchased: Int
        var max: Int
        var current: Int
    }

    struct ResourceValue: Codable {
        var base: Int
        var bonus: Int
        var max: Int
    }

    struct ComputedValue: Codable {
        var value: Int
        var bonus: Int
        var max: Int
    }

    struct MutableResourceValue: Codable {
        var current: Int
        var bonus: Int
        var max: Int
    }

    struct PetAttributes: Codable, Hashable {
        var mu: Int
        var kl: Int
        var inValue: Int
        var ch: Int
        var ff: Int
        var ge: Int
        var ko: Int
        var kk: Int
    }

    struct PetAttack: Codable, Hashable {
        var name: String
        var at: Int
        var damage: String
        var reach: String
    }

    struct HeroTrait: Codable, Hashable {
        var ruleId: String
        var name: String
        var tier: Int?
        var sid: String?
    }

    // MARK: - @Model classes

    @Model final class Hero {
        var name: String
        var avatar: Data?
        var advantages: [HeroTrait]
        var disadvantages: [HeroTrait]
        var generalSpecialAbilities: [HeroTrait]
        var combatSpecialAbilities: [HeroTrait]
        var cantrips: [HeroTrait]
        var blessings: [HeroTrait]
        var scripts: [String]
        var selectedWeaponName: String?
        var selectedShieldName: String?
        var selectedOffHandName: String?

        @Relationship(deleteRule: .cascade) var personalData: PersonalData?
        @Relationship(deleteRule: .cascade) var experience: Experience?
        @Relationship(deleteRule: .cascade) var attributes: Attributes?
        @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
        @Relationship(deleteRule: .cascade) var talents: [Talent]
        @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
        @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
        @Relationship(deleteRule: .cascade) var rangedWeapons: [RangedWeapon]
        @Relationship(deleteRule: .cascade) var armors: [Armor]
        @Relationship(deleteRule: .cascade) var shields: [Shield]
        @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem]
        @Relationship(deleteRule: .cascade) var money: Money?
        @Relationship(deleteRule: .cascade) var pets: [Pet]
        @Relationship(deleteRule: .cascade) var languages: [Language]
        @Relationship(deleteRule: .cascade) var spells: [HeroSpell]
        @Relationship(deleteRule: .cascade) var liturgies: [HeroSpell]

        init(name: String) {
            self.name = name
            self.advantages = []
            self.disadvantages = []
            self.generalSpecialAbilities = []
            self.combatSpecialAbilities = []
            self.cantrips = []
            self.blessings = []
            self.scripts = []
            self.talents = []
            self.combatTechniques = []
            self.meleeWeapons = []
            self.rangedWeapons = []
            self.armors = []
            self.shields = []
            self.equipment = []
            self.pets = []
            self.languages = []
            self.spells = []
            self.liturgies = []
        }
    }

    @Model final class PersonalData {
        var name: String
        var family: String
        var birthplace: String
        var birthdate: String
        var age: Int
        var gender: String
        var species: String
        var height: Int
        var weight: Int
        var hairColor: String
        var eyeColor: String
        var culture: String
        var socialStatus: String
        var profession: String
        var title: String
        var characteristics: String

        init(name: String, family: String, birthplace: String, birthdate: String,
             age: Int, gender: String, species: String, height: Int, weight: Int,
             hairColor: String, eyeColor: String, culture: String, socialStatus: String,
             profession: String, title: String, characteristics: String) {
            self.name = name
            self.family = family
            self.birthplace = birthplace
            self.birthdate = birthdate
            self.age = age
            self.gender = gender
            self.species = species
            self.height = height
            self.weight = weight
            self.hairColor = hairColor
            self.eyeColor = eyeColor
            self.culture = culture
            self.socialStatus = socialStatus
            self.profession = profession
            self.title = title
            self.characteristics = characteristics
        }
    }

    @Model final class Experience {
        var level: String
        var totalAP: Int
        var availableAP: Int
        var spentAP: Int

        init(level: String, totalAP: Int, availableAP: Int, spentAP: Int) {
            self.level = level
            self.totalAP = totalAP
            self.availableAP = availableAP
            self.spentAP = spentAP
        }
    }

    @Model final class Attributes {
        var mu: Int
        var kl: Int
        var inValue: Int
        var ch: Int
        var ff: Int
        var ge: Int
        var ko: Int
        var kk: Int

        init(mu: Int, kl: Int, inValue: Int, ch: Int, ff: Int, ge: Int, ko: Int, kk: Int) {
            self.mu = mu
            self.kl = kl
            self.inValue = inValue
            self.ch = ch
            self.ff = ff
            self.ge = ge
            self.ko = ko
            self.kk = kk
        }
    }

    @Model final class DerivedValues {
        var lebensenergie: LifeEnergyValue
        var astralenergie: MutableResourceValue?
        var karmaenergie: MutableResourceValue?
        var seelenkraft: ResourceValue
        var zaehigkeit: ResourceValue
        var ausweichen: ComputedValue
        var initiative: ComputedValue
        var geschwindigkeit: ResourceValue
        var wundschwelle: ComputedValue
        var schicksalspunkte: MutableResourceValue

        init(lebensenergie: LifeEnergyValue, astralenergie: MutableResourceValue?,
             karmaenergie: MutableResourceValue?, seelenkraft: ResourceValue,
             zaehigkeit: ResourceValue, ausweichen: ComputedValue,
             initiative: ComputedValue, geschwindigkeit: ResourceValue,
             wundschwelle: ComputedValue, schicksalspunkte: MutableResourceValue) {
            self.lebensenergie = lebensenergie
            self.astralenergie = astralenergie
            self.karmaenergie = karmaenergie
            self.seelenkraft = seelenkraft
            self.zaehigkeit = zaehigkeit
            self.ausweichen = ausweichen
            self.initiative = initiative
            self.geschwindigkeit = geschwindigkeit
            self.wundschwelle = wundschwelle
            self.schicksalspunkte = schicksalspunkte
        }
    }

    @Model final class Talent {
        var ruleId: String
        var name: String
        var value: Int
        var category: String

        init(ruleId: String, name: String, value: Int, category: String) {
            self.ruleId = ruleId
            self.name = name
            self.value = value
            self.category = category
        }
    }

    @Model final class CombatTechnique {
        var ruleId: String
        var name: String
        var value: Int
        var at: Int
        var pa: Int

        init(ruleId: String, name: String, value: Int, at: Int, pa: Int) {
            self.ruleId = ruleId
            self.name = name
            self.value = value
            self.at = at
            self.pa = pa
        }
    }

    @Model final class MeleeWeapon {
        var name: String
        var combatTechniqueId: String
        var damage: String
        var at: Int
        var pa: Int
        var reach: String
        var weight: Double

        init(name: String, combatTechniqueId: String, damage: String,
             at: Int, pa: Int, reach: String, weight: Double) {
            self.name = name
            self.combatTechniqueId = combatTechniqueId
            self.damage = damage
            self.at = at
            self.pa = pa
            self.reach = reach
            self.weight = weight
        }
    }

    @Model final class RangedWeapon {
        var name: String
        var combatTechniqueId: String
        var damage: String
        var at: Int
        var range: String
        var weight: Double

        init(name: String, combatTechniqueId: String, damage: String,
             at: Int, range: String, weight: Double) {
            self.name = name
            self.combatTechniqueId = combatTechniqueId
            self.damage = damage
            self.at = at
            self.range = range
            self.weight = weight
        }
    }

    @Model final class Armor {
        var name: String
        var protectionValue: Int
        var encumbrance: Int
        var weight: Double
        var isEquipped: Bool = false
        var iniModifier: Int = 0
        var gsModifier: Int = 0

        init(name: String, protectionValue: Int, encumbrance: Int, weight: Double,
             isEquipped: Bool = false, iniModifier: Int = 0, gsModifier: Int = 0) {
            self.name = name
            self.protectionValue = protectionValue
            self.encumbrance = encumbrance
            self.weight = weight
            self.isEquipped = isEquipped
            self.iniModifier = iniModifier
            self.gsModifier = gsModifier
        }
    }

    @Model final class Shield {
        var name: String
        var damage: String
        var at: Int
        var pa: Int
        var paModifier: Int
        var note: String
        var reach: String
        var structurePoints: Int
        var weight: Double

        init(name: String, damage: String, at: Int, pa: Int, paModifier: Int,
             note: String, reach: String, structurePoints: Int, weight: Double) {
            self.name = name
            self.damage = damage
            self.at = at
            self.pa = pa
            self.paModifier = paModifier
            self.note = note
            self.reach = reach
            self.structurePoints = structurePoints
            self.weight = weight
        }
    }

    @Model final class EquipmentItem {
        var name: String
        var value: Int
        var weight: Double

        init(name: String, value: Int, weight: Double) {
            self.name = name
            self.value = value
            self.weight = weight
        }
    }

    @Model final class Money {
        var dukaten: Int
        var silbertaler: Int
        var heller: Int
        var kreuzer: Int

        init(dukaten: Int, silbertaler: Int, heller: Int, kreuzer: Int) {
            self.dukaten = dukaten
            self.silbertaler = silbertaler
            self.heller = heller
            self.kreuzer = kreuzer
        }
    }

    @Model final class Pet {
        var petId: String
        var name: String
        var avatar: Data?
        var size: Double
        var type: String
        var attributes: PetAttributes
        var lifeEnergy: Int
        var spirit: Int
        var toughness: Int
        var initiative: String
        var speed: Int
        var attack: String
        var damage: String
        var reach: String
        var actions: Int
        var talents: String
        var skills: String
        var notes: String
        var attacks: [PetAttack]
        var specialSkills: String

        init(petId: String, name: String, avatar: Data? = nil, size: Double, type: String,
             attributes: PetAttributes, lifeEnergy: Int, spirit: Int, toughness: Int,
             initiative: String, speed: Int, attack: String, damage: String,
             reach: String, actions: Int, talents: String, skills: String, notes: String,
             attacks: [PetAttack], specialSkills: String) {
            self.petId = petId
            self.name = name
            self.avatar = avatar
            self.size = size
            self.type = type
            self.attributes = attributes
            self.lifeEnergy = lifeEnergy
            self.spirit = spirit
            self.toughness = toughness
            self.initiative = initiative
            self.speed = speed
            self.attack = attack
            self.damage = damage
            self.reach = reach
            self.actions = actions
            self.talents = talents
            self.skills = skills
            self.notes = notes
            self.attacks = attacks
            self.specialSkills = specialSkills
        }
    }

    @Model final class Language {
        var name: String
        var level: String

        init(name: String, level: String) {
            self.name = name
            self.level = level
        }
    }

    @Model final class HeroSpell {
        var ruleId: String
        var name: String
        var value: Int

        init(ruleId: String, name: String, value: Int) {
            self.ruleId = ruleId
            self.name = name
            self.value = value
        }
    }
}
```

**Step 2: Add SchemaV1.swift to the Xcode project**

Add `Hesindion/Migration/SchemaV1.swift` to the Hesindion target in `Hesindion.xcodeproj`. Since this project uses Xcode's file references (not SPM), the file must be added to the project's build sources.

Run:
```bash
# Verify the file exists
ls -la Hesindion/Migration/SchemaV1.swift
```

Then use the `xcodebuild` or manually add via project file. If using folder references, the file will be picked up automatically.

**Step 3: Build to verify SchemaV1 compiles**

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add Hesindion/Migration/SchemaV1.swift
git commit -m "feat: add SchemaV1 versioned schema snapshot"
```

---

### Task 2: Create MigrationPlan

**Files:**
- Create: `Hesindion/Migration/MigrationPlan.swift`

**Step 1: Create the migration plan**

Create `Hesindion/Migration/MigrationPlan.swift`:

```swift
import SwiftData

enum HesindionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
```

**Step 2: Add to Xcode project and build**

Add `Hesindion/Migration/MigrationPlan.swift` to the Hesindion target.

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add Hesindion/Migration/MigrationPlan.swift
git commit -m "feat: add HesindionMigrationPlan"
```

---

### Task 3: Wire up HesindionApp.swift

**Files:**
- Modify: `Hesindion/HesindionApp.swift`

**Step 1: Update ModelContainer initialization**

Replace the current `sharedModelContainer` property in `HesindionApp.swift`:

```swift
// Before:
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Hero.self,
        PersonalData.self,
        // ... all 16 models
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

// After:
var sharedModelContainer: ModelContainer = {
    do {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        return try ModelContainer(
            for: SchemaV1.self,
            migrationPlan: HesindionMigrationPlan.self,
            configurations: [configuration]
        )
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
```

**Step 2: Build**

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 3: Delete old app and launch to verify**

```bash
xcrun simctl uninstall booted org.savoba.Hesindion
xcrun simctl install booted <path-to-built-app>
xcrun simctl launch booted org.savoba.Hesindion
```
Expected: App launches without crash.

**Step 4: Commit**

```bash
git add Hesindion/HesindionApp.swift
git commit -m "feat: use VersionedSchema + MigrationPlan for ModelContainer"
```

---

### Task 4: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add entry under [Unreleased] → Added**

```markdown
- SwiftData VersionedSchema and SchemaMigrationPlan for safe schema migrations
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for SwiftData migration infrastructure"
```
