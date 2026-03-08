# Combat Technique AT/PA Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Fix AT/PA calculation to use DSA 5 formulas, list all combat techniques, add ranged weapons, and resolve CT IDs to names in the UI.

**Architecture:** Add a combat technique detail lookup to RulesDatabase, add an attribute-by-ID resolver to Attributes, fix the import formulas in OptolithImportService, add RangedWeapon model, and resolve CT IDs in HeroDetailView.

**Tech Stack:** SwiftUI, SwiftData, SQLite (rules.db)

---

### Task 1: Add combat technique detail lookup to RulesDatabase

**Files:**
- Modify: `iDSACompanion/Services/RulesDatabase.swift`

**Step 1: Add `CombatTechniqueDetail` struct and lookup method**

Add after the `SpellDetail` struct (line 46):

```swift
struct CombatTechniqueDetail {
    let primaryAttr1: String?
    let primaryAttr2: String?
    let hasNoParry: Bool
}
```

Add to `RulesDatabase` class, after `lookupSelectOption` (after line 207):

```swift
func lookupCombatTechniqueDetail(ruleId: String) -> CombatTechniqueDetail? {
    let sql = """
        SELECT d.primary_attr_1, d.primary_attr_2, r.has_no_parry
        FROM combat_technique_details d
        JOIN rules r ON r.id = d.rule_id
        WHERE d.rule_id = ?
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)

    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return CombatTechniqueDetail(
        primaryAttr1: col_text_opt(stmt, 0),
        primaryAttr2: col_text_opt(stmt, 1),
        hasNoParry: (sqlite3_column_int(stmt, 2) != 0)
    )
}
```

**Step 2: Add `allCombatTechniqueIds()` method**

Add after the method above:

```swift
func allCombatTechniqueIds() -> [String] {
    let sql = "SELECT id FROM rules WHERE category = 'combat_technique' ORDER BY id"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }

    var ids: [String] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        ids.append(col_text(stmt, 0))
    }
    return ids
}
```

**Step 3: Build and verify compilation**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add iDSACompanion/Services/RulesDatabase.swift
git commit -m "feat: add combat technique detail lookup to RulesDatabase"
```

---

### Task 2: Add attribute-by-ID resolver to Attributes

**Files:**
- Modify: `iDSACompanion/Models/Attributes.swift`

**Step 1: Add `value(for:)` method**

Add to `Attributes` class, after the `init` (after line 24):

```swift
func value(for attrId: String) -> Int {
    switch attrId {
    case "ATTR_1": return mu
    case "ATTR_2": return kl
    case "ATTR_3": return inValue
    case "ATTR_4": return ch
    case "ATTR_5": return ff
    case "ATTR_6": return ge
    case "ATTR_7": return ko
    case "ATTR_8": return kk
    default: return 8
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add iDSACompanion/Models/Attributes.swift
git commit -m "feat: add attribute-by-ID resolver to Attributes model"
```

---

### Task 3: Fix parseCombatTechniques to use DSA 5 formulas and list all CTs

**Files:**
- Modify: `iDSACompanion/Services/OptolithImportService.swift:482-491` (parseCombatTechniques)
- Modify: `iDSACompanion/Services/OptolithImportService.swift:91-92` (call site)

**Step 1: Add eigenschaftsbonus helper**

Add a private static helper near the top of the struct (after line 27):

```swift
private static func eigenschaftsbonus(_ attributeValue: Int) -> Int {
    max(0, Int(floor(Double(attributeValue - 8) / 3.0)))
}
```

**Step 2: Update parseCombatTechniques signature and body**

Replace the `parseCombatTechniques` method (lines 482-491) with:

```swift
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
            paValue = ktw / 2 + Self.eigenschaftsbonus(primaryAttrValue)
        }

        return CombatTechnique(ruleId: ctId, name: name, value: ktw, at: atValue, pa: paValue)
    }
    .sorted { $0.name < $1.name }
}
```

**Step 3: Update the call site**

At line 92, change:
```swift
let combatTechniques = parseCombatTechniques(ctJSON)
```
to:
```swift
let combatTechniques = parseCombatTechniques(ctJSON, attributes: attributes)
```

**Step 4: Build and verify**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add iDSACompanion/Services/OptolithImportService.swift
git commit -m "feat: fix AT/PA calculation and list all combat techniques"
```

---

### Task 4: Fix weapon AT/PA in parseItems

**Files:**
- Modify: `iDSACompanion/Services/OptolithImportService.swift:532-606` (parseItems)
- Modify: `iDSACompanion/Services/OptolithImportService.swift:120` (call site)

**Step 1: Update parseItems signature**

Change line 532 from:
```swift
private func parseItems(_ json: [String: Any], ctValues: [String: Int]) -> ItemsResult {
```
to:
```swift
private func parseItems(_ json: [String: Any], ctValues: [String: Int], attributes: Attributes) -> ItemsResult {
```

**Step 2: Fix melee weapon AT/PA calculation**

Replace lines 574-576 (the `else` branch for non-shield weapons):
```swift
let ctVal = ctValues[ctId] ?? 6
let baseAT = Int(ceil(Double(ctVal) / 2.0))
let basePA = ctVal / 2
```
with:
```swift
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
let basePA = ctVal / 2 + Self.eigenschaftsbonus(primaryAttrValue)
```

**Step 3: Fix shield AT/PA calculation similarly**

Replace lines 557-559 (inside the shield `if ctId == "CT_10"` branch):
```swift
let ctVal = ctValues[ctId] ?? 6
let baseAT = Int(ceil(Double(ctVal) / 2.0))
let basePA = ctVal / 2
```
with the same pattern as step 2 (using CT_10's primary attributes).

**Step 4: Update the call site**

At line 120, change:
```swift
let items = parseItems(itemsJSON, ctValues: ctValues)
```
to:
```swift
let items = parseItems(itemsJSON, ctValues: ctValues, attributes: attributes)
```

**Step 5: Build and verify**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add iDSACompanion/Services/OptolithImportService.swift
git commit -m "feat: fix weapon AT/PA to use DSA 5 formulas"
```

---

### Task 5: Add RangedWeapon model and import

**Files:**
- Create: `iDSACompanion/Models/RangedWeapon.swift`
- Modify: `iDSACompanion/Models/Hero.swift:22` (add relationship)
- Modify: `iDSACompanion/Services/OptolithImportService.swift` (ItemsResult, parseItems case 2, replaceHeroData)
- Modify: `iDSACompanion/iDSACompanionApp.swift` (add to ModelContainer schema if needed)

**Step 1: Create RangedWeapon model**

```swift
import Foundation
import SwiftData

@Model
final class RangedWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int
    var range: String
    var weight: Double

    init(name: String, combatTechniqueId: String, damage: String, at: Int, range: String, weight: Double) {
        self.name = name
        self.combatTechniqueId = combatTechniqueId
        self.damage = damage
        self.at = at
        self.range = range
        self.weight = weight
    }
}
```

**Step 2: Add relationship to Hero**

After line 22 (`meleeWeapons`), add:
```swift
@Relationship(deleteRule: .cascade) var rangedWeapons: [RangedWeapon]
```

And in the `init`, after `self.meleeWeapons = []`:
```swift
self.rangedWeapons = []
```

**Step 3: Update ItemsResult**

Add to the `ItemsResult` struct (after line 527):
```swift
var rangedWeapons: [RangedWeapon]
```

**Step 4: Handle gr=2 in parseItems**

In the switch statement, add before the `default` case:
```swift
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
```

Also add a `var rangedWeapons: [RangedWeapon] = []` at the top of `parseItems`, and include it in the return:
```swift
return ItemsResult(weapons: weapons, armors: armors, shields: shields, rangedWeapons: rangedWeapons, equipment: equipment)
```

**Step 5: Add range formatting helper**

Add a private helper near `formatDamage`:
```swift
private func formatRange(_ item: [String: Any]) -> String {
    let close = intFromAny(item["range1"]) ?? 0
    let medium = intFromAny(item["range2"]) ?? 0
    let far = intFromAny(item["range3"]) ?? 0
    if close == 0 && medium == 0 && far == 0 { return "—" }
    return "\(close)/\(medium)/\(far)"
}
```

Note: Check the actual Optolith JSON field names for range values — they may be `range` (a single array or object) rather than `range1/2/3`. Verify against an actual export. If the format differs, adapt accordingly.

**Step 6: Wire into replaceHeroData and new hero creation**

In `replaceHeroData` (around line 251), add:
```swift
hero.rangedWeapons.forEach { context.delete($0) }
hero.rangedWeapons = items.rangedWeapons
```

In the new hero path (around line 184), add:
```swift
hero.rangedWeapons = items.rangedWeapons
```

**Step 7: Add rangedWeapons weight to totalEquipmentWeight**

In `Hero.totalEquipmentWeight`, add:
```swift
let rangedWeight = rangedWeapons.reduce(0.0) { $0 + $1.weight }
```
And include it in the return sum.

**Step 8: Add to equipmentSection in HeroDetailView**

In the equipment section (after line 583 where shields are listed), add:
```swift
ForEach(hero.rangedWeapons, id: \.persistentModelID) { w in
    weightRow(name: w.name, weight: w.weight)
}
```

**Step 9: Build and verify**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 10: Commit**

```bash
git add iDSACompanion/Models/RangedWeapon.swift iDSACompanion/Models/Hero.swift iDSACompanion/Services/OptolithImportService.swift iDSACompanion/Views/HeroDetailView.swift
git commit -m "feat: add RangedWeapon model and import ranged weapons"
```

---

### Task 6: Resolve combatTechniqueId to name in UI

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift:644` (melee weapons section)
- Modify: `iDSACompanion/Views/HeroDetailView.swift` (add ranged weapons section)

**Step 1: Fix melee weapon display**

At line 644, change:
```swift
("combatTechnique", w.combatTechniqueId),
```
to:
```swift
("combatTechnique", RulesDatabase.shared.lookup(id: w.combatTechniqueId)?.name ?? w.combatTechniqueId),
```

**Step 2: Add ranged weapons section**

After the `meleeWeaponsSection` (after line 655), add a new section:

```swift
// MARK: - Section 13b: RangedWeapons

@ViewBuilder private var rangedWeaponsSection: some View {
    if !hero.rangedWeapons.isEmpty {
        CollapsibleSection(L("rangedWeapons")) {
            ForEach(hero.rangedWeapons, id: \.persistentModelID) { w in
                SwipeActionRow(
                    actions: [SwipeAction(icon: "bolt.fill", color: .groupCombat) { showCombatMode = true }]
                ) {
                    SubfieldBlock(label: w.name, subfields: [
                        ("combatTechnique", RulesDatabase.shared.lookup(id: w.combatTechniqueId)?.name ?? w.combatTechniqueId),
                        ("damage", w.damage),
                        ("FK", "\(w.at)"),
                        ("range", w.range),
                        ("weight", String(format: "%.2f st", w.weight))
                    ])
                }
            }
        }
    }
}
```

**Step 3: Wire rangedWeaponsSection into the body**

Find where `meleeWeaponsSection` is referenced in the main body and add `rangedWeaponsSection` right after it.

**Step 4: Add localization key**

In `iDSACompanion/Theme/Strings.swift`, add `"rangedWeapons"` key with value `"Fernkampfwaffen"`.

**Step 5: Build and verify**

Run: `xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add iDSACompanion/Views/HeroDetailView.swift iDSACompanion/Theme/Strings.swift
git commit -m "feat: resolve CT IDs to names and add ranged weapons UI"
```

---

### Task 7: Verify and test

**Step 1: Re-import a hero**

Build and run the app in the simulator. Import a hero JSON file with ranged weapons and melee weapons. Verify:
- All combat techniques are listed (not just trained ones)
- Combat technique names display properly (e.g., "Hiebwaffen" not "CT_5")
- AT/PA values match expected DSA 5 calculations
- Ranged weapons appear with FK values
- Weapon sections show resolved CT names

**Step 2: Spot-check Boronmir**

For a hero with MU=13, Hiebwaffen KtW=12:
- AT = 12 + max(0, floor((13-8)/3)) = 12 + 1 = 13
- If primary attrs are GE/KK and both ≥ 14: PA = 6 + max(0, floor((14-8)/3)) = 6 + 2 = 8

**Step 3: Final commit if any fixes needed**
