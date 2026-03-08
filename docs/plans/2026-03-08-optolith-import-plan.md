# Optolith Import Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom hero JSON import with direct Optolith export file import, adapting all data models to match.

**Architecture:** Parse Optolith's ID-based JSON format directly into SwiftData models. Resolve IDs to display names via rules.db lookups and static maps at import time. Compute derived values using DSA 5e formulas.

**Tech Stack:** Swift, SwiftUI, SwiftData, SQLite3 (rules.db), Swift Testing

---

### Task 1: Create HeroTrait Codable struct

**Files:**
- Create: `iDSACompanion/Models/HeroTrait.swift`

**Step 1: Create the file**

```swift
import Foundation

struct HeroTrait: Codable, Hashable {
    var ruleId: String
    var name: String
    var tier: Int?
    var sid: String?
}
```

**Step 2: Commit**

```bash
git add iDSACompanion/Models/HeroTrait.swift
git commit -m "feat: add HeroTrait Codable struct for structured advantages/disadvantages/abilities"
```

---

### Task 2: Create HeroSpell model

**Files:**
- Create: `iDSACompanion/Models/HeroSpell.swift`

**Step 1: Create the file**

```swift
import Foundation
import SwiftData

@Model
final class HeroSpell {
    var ruleId: String
    var name: String
    var value: Int

    init(ruleId: String, name: String, value: Int) {
        self.ruleId = ruleId
        self.name = name
        self.value = value
    }
}
```

**Step 2: Commit**

```bash
git add iDSACompanion/Models/HeroSpell.swift
git commit -m "feat: add HeroSpell model for spells and liturgies"
```

---

### Task 3: Create Pet model (replaces Mount)

**Files:**
- Create: `iDSACompanion/Models/Pet.swift`
- Delete: `iDSACompanion/Models/Mount.swift`

**Step 1: Create Pet.swift**

```swift
import Foundation
import SwiftData

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

@Model
final class Pet {
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

    var carryingCapacity: Int { attributes.kk * 2 }

    init(
        petId: String,
        name: String,
        avatar: Data? = nil,
        size: Double,
        type: String,
        attributes: PetAttributes,
        lifeEnergy: Int,
        spirit: Int,
        toughness: Int,
        initiative: String,
        speed: Int,
        attack: String,
        damage: String,
        reach: String,
        actions: Int,
        talents: String,
        skills: String,
        notes: String
    ) {
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
    }
}
```

**Step 2: Delete Mount.swift**

```bash
git rm iDSACompanion/Models/Mount.swift
```

**Step 3: Commit**

```bash
git add iDSACompanion/Models/Pet.swift
git commit -m "feat: replace Mount with Pet model supporting free-text fields and avatar"
```

---

### Task 4: Update existing models

**Files:**
- Modify: `iDSACompanion/Models/Hero.swift`
- Modify: `iDSACompanion/Models/Talent.swift`
- Modify: `iDSACompanion/Models/CombatTechnique.swift`
- Modify: `iDSACompanion/Models/MeleeWeapon.swift`
- Modify: `iDSACompanion/Models/Shield.swift`
- Modify: `iDSACompanion/Models/Armor.swift`

**Step 1: Update Talent — add ruleId**

In `Talent.swift`, add `var ruleId: String` property and update init:

```swift
@Model
final class Talent {
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
```

**Step 2: Update CombatTechnique — add ruleId**

In `CombatTechnique.swift`, add `var ruleId: String` property and update init:

```swift
@Model
final class CombatTechnique {
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
```

**Step 3: Update MeleeWeapon — technique → combatTechniqueId**

In `MeleeWeapon.swift`:

```swift
@Model
final class MeleeWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int
    var pa: Int
    var reach: String
    var weight: Double

    init(name: String, combatTechniqueId: String, damage: String, at: Int, pa: Int, reach: String, weight: Double) {
        self.name = name
        self.combatTechniqueId = combatTechniqueId
        self.damage = damage
        self.at = at
        self.pa = pa
        self.reach = reach
        self.weight = weight
    }
}
```

**Step 4: Update Shield — drop structure/breakingFactor, add damage/reach/structurePoints**

```swift
@Model
final class Shield {
    var name: String
    var damage: String
    var at: Int
    var pa: Int
    var reach: String
    var structurePoints: Int
    var weight: Double

    init(name: String, damage: String, at: Int, pa: Int, reach: String, structurePoints: Int, weight: Double) {
        self.name = name
        self.damage = damage
        self.at = at
        self.pa = pa
        self.reach = reach
        self.structurePoints = structurePoints
        self.weight = weight
    }
}
```

**Step 5: Update Armor — drop armorRating**

```swift
@Model
final class Armor {
    var name: String
    var protectionValue: Int
    var encumbrance: Int
    var weight: Double

    init(name: String, protectionValue: Int, encumbrance: Int, weight: Double) {
        self.name = name
        self.protectionValue = protectionValue
        self.encumbrance = encumbrance
        self.weight = weight
    }
}
```

**Step 6: Update Hero.swift**

Replace string arrays with HeroTrait arrays, add new relationships, replace mount with pets:

```swift
@Model
final class Hero {
    var name: String
    var avatar: Data?
    var advantages: [HeroTrait]
    var disadvantages: [HeroTrait]
    var generalSpecialAbilities: [HeroTrait]
    var combatSpecialAbilities: [HeroTrait]
    var cantrips: [HeroTrait]
    var blessings: [HeroTrait]
    var scripts: [String]

    @Relationship(deleteRule: .cascade) var personalData: PersonalData?
    @Relationship(deleteRule: .cascade) var experience: Experience?
    @Relationship(deleteRule: .cascade) var attributes: Attributes?
    @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
    @Relationship(deleteRule: .cascade) var talents: [Talent]
    @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
    @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
    @Relationship(deleteRule: .cascade) var armors: [Armor]
    @Relationship(deleteRule: .cascade) var shields: [Shield]
    @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem]
    @Relationship(deleteRule: .cascade) var money: Money?
    @Relationship(deleteRule: .cascade) var pets: [Pet]
    @Relationship(deleteRule: .cascade) var languages: [Language]
    @Relationship(deleteRule: .cascade) var spells: [HeroSpell]
    @Relationship(deleteRule: .cascade) var liturgies: [HeroSpell]

    init(
        name: String,
        avatar: Data? = nil,
        advantages: [HeroTrait] = [],
        disadvantages: [HeroTrait] = [],
        generalSpecialAbilities: [HeroTrait] = [],
        combatSpecialAbilities: [HeroTrait] = [],
        cantrips: [HeroTrait] = [],
        blessings: [HeroTrait] = [],
        scripts: [String] = []
    ) {
        self.name = name
        self.avatar = avatar
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.generalSpecialAbilities = generalSpecialAbilities
        self.combatSpecialAbilities = combatSpecialAbilities
        self.cantrips = cantrips
        self.blessings = blessings
        self.scripts = scripts
        self.talents = []
        self.combatTechniques = []
        self.meleeWeapons = []
        self.armors = []
        self.shields = []
        self.equipment = []
        self.languages = []
        self.pets = []
        self.spells = []
        self.liturgies = []
    }
    // ... keep existing computed properties but update:
}
```

Update `verbessertRegenerationLEBonus` computed property to use HeroTrait:

```swift
var verbessertRegenerationLEBonus: Int {
    guard let adv = advantages.first(where: { $0.ruleId == "ADV_44" }) else { return 0 }
    return (adv.tier ?? 1) >= 2 ? 2 : 1
}
```

Update `totalCarryingCapacity` to use pets:

```swift
var totalCarryingCapacity: Int {
    carryingCapacity + pets.reduce(0) { $0 + $1.carryingCapacity }
}
```

**Step 7: Commit**

```bash
git add -A iDSACompanion/Models/
git commit -m "feat: update all models for Optolith import format"
```

---

### Task 5: Create OptolithImportService with static maps

**Files:**
- Create: `iDSACompanion/Services/OptolithImportService.swift`
- Delete: `iDSACompanion/DTOs/HeroDTO.swift`
- Delete: `iDSACompanion/Services/HeroImportService.swift`

**Step 1: Create OptolithImportService.swift**

This is the largest file. It contains:
- Static maps for ATTR, EL, reach, haircolor, eyecolor, socialstatus
- Optolith JSON parsing (using JSONSerialization for flexibility with the untyped format)
- ID resolution via `RulesDatabase.shared.lookup(id:)`
- DSA 5e derived value computation
- Weapon AT/PA computation from CTR + attribute + modifier

Key static maps:

```swift
private let attrMap: [String: String] = [
    "ATTR_1": "mu", "ATTR_2": "kl", "ATTR_3": "inValue", "ATTR_4": "ch",
    "ATTR_5": "ff", "ATTR_6": "ge", "ATTR_7": "ko", "ATTR_8": "kk"
]

private let elMap: [String: String] = [
    "EL_1": "Unerfahren", "EL_2": "Durchschnittlich", "EL_3": "Erfahren",
    "EL_4": "Kompetent", "EL_5": "Meisterlich", "EL_6": "Brilliant", "EL_7": "Legendär"
]

private let reachMap: [Int: String] = [1: "Kurz", 2: "Mittel", 3: "Lang"]

private let hairColorMap: [Int: String] = [
    1: "schwarz", 2: "blond", 3: "braun", 4: "rot", 5: "weiß",
    6: "dunkelblond", 7: "hellbraun", 8: "dunkelbraun", 9: "rotblond",
    10: "grau", 11: "silber"
]

private let eyeColorMap: [Int: String] = [
    1: "grün", 2: "braun", 3: "schwarz", 4: "blau", 5: "grau",
    6: "bernstein", 7: "dunkelbraun", 8: "hellbraun", 9: "dunkelgrün",
    10: "hellgrün", 11: "dunkelblau", 12: "hellblau", 13: "dunkelgrau",
    14: "hellgrau", 15: "schwarz"
]

private let socialStatusMap: [Int: String] = [
    1: "Unfrei", 2: "Frei", 3: "Niederadel", 4: "Hochadel"
]
```

Activatable classification: SA_ IDs that are combat abilities can be determined by checking if rules.db returns a category containing "combat" in the group, or by maintaining a known list. As a simpler approach, check if the SA_ has effects scoped to "combat" in rules.db. If not determinable, default to general.

For derived values, the DSA 5e formulas:

```swift
// LE
let koValue = attributes.ko
let kkValue = attributes.kk
let leBase = koValue * 2  // for Mensch (R_1)
let leMax = leBase + kkValue + purchasedLP
// + advantage bonuses (ADV_25 "Hohe Lebenskraft" tier * 1)

// AE (only if attr.ae > 0 or has magic tradition SA)
let aeBase = 20  // base for most traditions
let aeMax = aeBase + purchasedAE  // + (KL or CH or IN depending on tradition)

// SK = round_up((MU + KL + IN) / 6)
// ZK = round_up((KO + KO + KK) / 6)
// INI = round_down((MU + GE) / 2)
// AW = round_down(GE / 2)
// GS = 8 (for Mensch)
// WS = round_down(KO / 2)
```

Weapon AT/PA computation:
- Look up the combat technique value from `ct` dict
- Primary attribute for the technique determines AT/PA split
- AT = CTR_value/2 (rounded up) + item.at modifier (for most techniques)
- PA = CTR_value/2 (rounded down) + item.pa modifier

**Step 2: Delete old import files**

```bash
git rm iDSACompanion/DTOs/HeroDTO.swift
git rm iDSACompanion/Services/HeroImportService.swift
```

**Step 3: Commit**

```bash
git add iDSACompanion/Services/OptolithImportService.swift
git commit -m "feat: add OptolithImportService for direct Optolith JSON import"
```

---

### Task 6: Update ModelContainer registrations

**Files:**
- Modify: `iDSACompanion/iDSACompanionApp.swift`
- Modify: `iDSACompanion/ContentView.swift`

**Step 1: Update schema in iDSACompanionApp.swift**

Replace `Mount.self` with `Pet.self`, add `HeroSpell.self`:

```swift
let schema = Schema([
    Hero.self,
    PersonalData.self,
    Experience.self,
    Attributes.self,
    DerivedValues.self,
    Talent.self,
    CombatTechnique.self,
    MeleeWeapon.self,
    Armor.self,
    Shield.self,
    EquipmentItem.self,
    Money.self,
    Pet.self,
    Language.self,
    HeroSpell.self,
])
```

**Step 2: Update preview containers in ContentView.swift and HeroListView.swift**

Same changes — replace `Mount.self` with `Pet.self`, add `HeroSpell.self`.

**Step 3: Commit**

```bash
git add iDSACompanion/iDSACompanionApp.swift iDSACompanion/ContentView.swift iDSACompanion/Views/HeroListView.swift
git commit -m "fix: update ModelContainer registrations for new model types"
```

---

### Task 7: Update HeroListView to use OptolithImportService

**Files:**
- Modify: `iDSACompanion/Views/HeroListView.swift`

**Step 1: Replace HeroImportService with OptolithImportService**

In `handleURL` method (line 179-185):

```swift
private func handleURL(_ url: URL) {
    do {
        try OptolithImportService().importHero(from: url, context: modelContext)
    } catch {
        showError(error.localizedDescription)
    }
}
```

Update the error reference at line 47 from `HeroImportError` to `OptolithImportError` (or whatever the new error type is named).

**Step 2: Commit**

```bash
git add iDSACompanion/Views/HeroListView.swift
git commit -m "fix: wire HeroListView to OptolithImportService"
```

---

### Task 8: Update HeroDetailView for model changes

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift`

**Step 1: Update advantages/disadvantages/specialAbilities sections**

These currently iterate `[String]` and display with `Text($0)`. Update to iterate `[HeroTrait]` and display structured info:

```swift
// Before (line ~404):
ForEach(hero.advantages, id: \.self) { Text($0) }

// After:
ForEach(hero.advantages, id: \.self) { trait in
    HStack {
        Text(trait.name)
        if let tier = trait.tier {
            Text("(\(tier))").foregroundStyle(.secondary)
        }
        if let sid = trait.sid {
            Text("– \(sid)").foregroundStyle(.secondary)
        }
    }
}
```

Apply same pattern to disadvantages (line ~417), generalSpecialAbilities (line ~430), combatSpecialAbilities (line ~542).

**Step 2: Update mount section to pets**

Replace `hero.mount` references (line ~710) with `hero.pets` iteration.

**Step 3: Update preview ModelContainer**

Replace `Mount.self` with `Pet.self`, add `HeroSpell.self`.

**Step 4: Commit**

```bash
git add iDSACompanion/Views/HeroDetailView.swift
git commit -m "fix: update HeroDetailView for HeroTrait and Pet model changes"
```

---

### Task 9: Update CommandPaletteOverlay for verbessertRegenerationLEBonus

**Files:**
- Modify: `iDSACompanion/Views/CommandPaletteOverlay.swift`

**Step 1: Verify the reference**

Line 14 uses `hero.verbessertRegenerationLEBonus` — this is a computed property on Hero that we already updated in Task 4 to use `ruleId == "ADV_44"`. No changes needed in the view itself, but verify it compiles.

**Step 2: Commit (if changes needed)**

---

### Task 10: Update and run tests

**Files:**
- Modify: `iDSACompanionTests/HeroImportTests.swift`

**Step 1: Rewrite tests for Optolith format**

The test currently reads `specs/001_heros-view/hero.json` (old format). Update to read from `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json`:

```swift
@MainActor
struct HeroImportTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Hero.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, Armor.self, Shield.self, EquipmentItem.self,
            Money.self, Pet.self, Language.self, HeroSpell.self,
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private var sampleBoronmirURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json")
    }

    @Test func importBoronmirFromOptolith() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try OptolithImportService().importHero(from: sampleBoronmirURL, context: context)

        let heroes = try context.fetch(FetchDescriptor<Hero>())
        #expect(heroes.count == 1)
        let hero = try #require(heroes.first)

        // Identity
        #expect(hero.name == "Boronmir Siebenfeld von Greifenfurt")
        #expect(hero.avatar != nil)

        // Attributes
        let attr = try #require(hero.attributes)
        #expect(attr.mu == 14)
        #expect(attr.kl == 12)
        #expect(attr.kk == 15)

        // Advantages (ADV_ entries from activatable)
        #expect(hero.advantages.count == 6)
        #expect(hero.advantages.contains { $0.ruleId == "ADV_5" })  // Beidhändig

        // Disadvantages (DISADV_ entries)
        #expect(hero.disadvantages.count >= 5)

        // Special abilities (SA_ entries)
        #expect(!hero.generalSpecialAbilities.isEmpty)
        #expect(!hero.combatSpecialAbilities.isEmpty)

        // Talents (31 entries in Optolith)
        #expect(hero.talents.count == 31)

        // Combat techniques (5 entries)
        #expect(hero.combatTechniques.count == 5)

        // Equipment split
        #expect(hero.meleeWeapons.count == 2)  // Rabenschnabel + Langschwert
        #expect(hero.shields.count == 1)        // Großschild
        #expect(hero.armors.count == 1)         // Plattenrüstung

        // No spells for this hero
        #expect(hero.spells.isEmpty)
        #expect(hero.cantrips.isEmpty)

        // Pet
        #expect(hero.pets.count == 1)
        let pet = try #require(hero.pets.first)
        #expect(pet.name == "Kupperus")
        #expect(pet.type == "Svellttaler Kaltblut")
        #expect(pet.lifeEnergy == 75)

        // Money
        let money = try #require(hero.money)
        #expect(money.dukaten == 9)
        #expect(money.silbertaler == 5)
    }
}
```

**Step 2: Build and run tests**

```bash
xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator test
```

**Step 3: Commit**

```bash
git add iDSACompanionTests/HeroImportTests.swift
git commit -m "test: rewrite import tests for Optolith format"
```

---

### Task 11: Build verification and cleanup

**Step 1: Full build**

```bash
xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build
```

**Step 2: Fix any remaining compilation errors**

Check for stray references to:
- `Mount` (should be `Pet`)
- `HeroImportService` / `HeroImportError` (should be `OptolithImportService` / `OptolithImportError`)
- `hero.mount` (should be `hero.pets`)
- `MountAttributes` / `MountAttack` / `MountTalent` (removed)
- `technique` on MeleeWeapon (now `combatTechniqueId`)
- `armorRating` on Armor (removed)
- `structure` / `breakingFactor` on Shield (removed)

**Step 3: Run tests**

```bash
xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator test
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: cleanup and fix remaining compilation issues from Optolith migration"
```

---

### Task dependency order

```
Task 1 (HeroTrait) ──┐
Task 2 (HeroSpell) ──┤
Task 3 (Pet) ────────┼──→ Task 4 (Update models) ──→ Task 5 (OptolithImportService) ──→ Task 6 (ModelContainer)
                      │                                                                    ↓
                      │                                                              Task 7 (HeroListView)
                      │                                                              Task 8 (HeroDetailView)
                      │                                                              Task 9 (CommandPalette)
                      │                                                                    ↓
                      └──────────────────────────────────────────────────────────── Task 10 (Tests)
                                                                                          ↓
                                                                                   Task 11 (Build & cleanup)
```
