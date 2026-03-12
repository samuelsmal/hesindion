# Combat Loadout System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add weapon + shield loadout selection to combat, applying passive/active shield PA bonuses per DSA 5 rules.

**Architecture:** Extend `Shield` model with `paModifier` and `note` fields. Add `selectedWeaponID`/`selectedShieldID` to `Hero` for persistence. Insert a loadout selection step into the combat flow before the action root. Modify parry/attack choices to reflect loadout.

**Tech Stack:** SwiftUI, SwiftData

**Design doc:** `docs/plans/2026-03-12-combat-loadout-design.md`

---

### Task 1: Add `paModifier` and `note` fields to Shield model

**Files:**
- Modify: `iDSACompanion/Models/Shield.swift`

**Step 1: Add fields to Shield model**

```swift
@Model
final class Shield {
    var name: String
    var damage: String
    var at: Int
    var pa: Int
    var paModifier: Int
    var note: String
    var reach: String
    var structurePoints: Int
    var weight: Double

    init(name: String, damage: String, at: Int, pa: Int, paModifier: Int, note: String = "", reach: String, structurePoints: Int, weight: Double) {
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
```

**Step 2: Commit**

```bash
git add iDSACompanion/Models/Shield.swift
git commit -m "feat: add paModifier and note fields to Shield model"
```

---

### Task 2: Update shield import to populate new fields

**Files:**
- Modify: `iDSACompanion/Services/OptolithImportService.swift` (lines 584–612)

**Step 1: Store paModifier and map template to note**

In the shield parsing block (where `ctId == "CT_10"`), pass `paMod` and a note derived from the item template:

```swift
let paMod = intFromAny(item["pa"]) ?? 0
let template = item["template"] as? String ?? ""
let note = Self.shieldNote(for: template)
// ...
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
```

Add the template-to-note mapping as a static method:

```swift
private static func shieldNote(for template: String) -> String {
    switch template {
    case "ITEMTPL_29": return "+1 PA vs. Fernkampf"
    default: return ""
    }
}
```

**Step 2: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 3: Commit**

```bash
git add iDSACompanion/Services/OptolithImportService.swift
git commit -m "feat: populate shield paModifier and note during import"
```

---

### Task 3: Add loadout persistence fields to Hero model

**Files:**
- Modify: `iDSACompanion/Models/Hero.swift`

**Step 1: Add selectedWeaponName and selectedShieldName**

Use weapon/shield names for persistence (simpler than PersistentIdentifier which is not Codable). Add after the existing relationship declarations:

```swift
var selectedWeaponName: String?
var selectedShieldName: String?
```

Add computed properties to resolve to actual objects:

```swift
var selectedWeapon: MeleeWeapon? {
    guard let name = selectedWeaponName else { return nil }
    return meleeWeapons.first { $0.name == name }
}

var selectedShield: Shield? {
    guard let name = selectedShieldName else { return nil }
    return shields.first { $0.name == name }
}

/// Passive shield PA bonus applied to main weapon parade.
/// Uses the highest paModifier if multiple shields (only selected counts here).
var passiveShieldPABonus: Int {
    selectedShield?.paModifier ?? 0
}
```

**Step 2: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 3: Commit**

```bash
git add iDSACompanion/Models/Hero.swift
git commit -m "feat: add loadout persistence fields to Hero model"
```

---

### Task 4: Add loadout selection step to CombatView

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift`

**Step 1: Add new CombatStep cases**

Update `CombatStep` enum:

```swift
private enum CombatStep {
    case armorSelection
    case initiativeRoll
    case loadoutWeapon          // NEW
    case loadoutShield          // NEW
    case root
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?)
    case takeDamage
}
```

Note: added `note: String?` to `.execution` for shield note display.

**Step 2: Update stepID computed property**

Add cases:

```swift
case .loadoutWeapon: "loadoutWeapon"
case .loadoutShield: "loadoutShield"
```

**Step 3: Update CombatView body switch**

After `.initiativeRoll`, add:

```swift
case .loadoutWeapon:
    CombatLoadoutWeaponView(hero: hero, step: $step, onDismiss: onDismiss)
        .transition(.move(edge: .trailing))
case .loadoutShield:
    CombatLoadoutShieldView(hero: hero, step: $step, onDismiss: onDismiss)
        .transition(.move(edge: .trailing))
```

**Step 4: Update drag gesture**

Add cases for the new steps in the swipe-down handler:

```swift
case .loadoutWeapon:
    step = .initiativeRoll
case .loadoutShield:
    step = .loadoutWeapon
```

**Step 5: Update initial step logic**

Change `CombatInitiativeRollView` to transition to `.loadoutWeapon` instead of `.root` after rolling initiative (unless loadout is already set — then skip to `.root`).

In the initiative roll view's "Weiter" button action, change:

```swift
// Old:
step = .root
// New:
if hero.selectedWeaponName != nil {
    step = .root
} else {
    step = .loadoutWeapon
}
```

**Step 6: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 7: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift
git commit -m "feat: add loadout step cases to CombatView flow"
```

---

### Task 5: Build CombatLoadoutWeaponView

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift`

**Step 1: Create the weapon selection view**

Add a new private struct. Shows list of melee weapons + Raufen option. Tapping selects and moves to shield step (or root if no shields).

```swift
private struct CombatLoadoutWeaponView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .initiativeRoll } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("selectWeapon"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    if !hero.meleeWeapons.isEmpty {
                        combatSectionLabel("NAHKAMPFWAFFEN")
                        ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                            loadoutRow(name: w.name, detail: "AT \(w.at) / PA \(w.pa)") {
                                hero.selectedWeaponName = w.name
                                advanceToShieldOrRoot()
                            }
                        }
                    }

                    combatSectionLabel(L("unarmed.label"))
                    loadoutRow(name: "Raufen", detail: "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)") {
                        hero.selectedWeaponName = "Raufen"
                        advanceToShieldOrRoot()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func advanceToShieldOrRoot() {
        if hero.shields.isEmpty {
            hero.selectedShieldName = nil
            step = .root
        } else {
            step = .loadoutShield
        }
    }

    private func loadoutRow(name: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if hero.selectedWeaponName == name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(combatAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}
```

**Step 2: Add localization key**

Add `"selectWeapon" = "Waffe wählen";` to `Localizable.strings`.

**Step 3: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 4: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift iDSACompanion/Resources/Localizable.strings
git commit -m "feat: add CombatLoadoutWeaponView"
```

---

### Task 6: Build CombatLoadoutShieldView

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift`

**Step 1: Create the shield selection view**

Similar to weapon view. Shows shields + "Kein Schild" option.

```swift
private struct CombatLoadoutShieldView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .loadoutWeapon } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("selectShield"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    combatSectionLabel("SCHILDE")
                    ForEach(hero.shields, id: \.persistentModelID) { s in
                        loadoutRow(name: s.name, detail: "AT \(s.at) / PA \(s.pa)", note: s.note) {
                            hero.selectedShieldName = s.name
                            step = .root
                        }
                    }

                    combatSectionLabel("")
                    loadoutRow(name: L("noShield"), detail: "") {
                        hero.selectedShieldName = nil
                        step = .root
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func loadoutRow(name: String, detail: String, note: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    if let note, !note.isEmpty {
                        Text(note)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
                if hero.selectedShieldName == name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(combatAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}
```

**Step 2: Add localization keys**

Add to `Localizable.strings`:
```
"selectShield" = "Schild wählen";
"noShield" = "Kein Schild";
```

**Step 3: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 4: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift iDSACompanion/Resources/Localizable.strings
git commit -m "feat: add CombatLoadoutShieldView"
```

---

### Task 7: Modify CombatRootView — show loadout and change equipment button

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift` (CombatRootView, lines ~520–620)

**Step 1: Show current loadout at top of action section**

Before the AKTION section label, add a loadout display:

```swift
// Current loadout display
if let weaponName = hero.selectedWeaponName {
    HStack(spacing: 8) {
        Image(systemName: "hammer.fill")
            .font(.system(.caption, weight: .bold))
        Text(weaponName)
            .font(.system(.caption, design: .monospaced, weight: .black))
        if let shieldName = hero.selectedShieldName {
            Text("+")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.secondary)
            Image(systemName: "shield.fill")
                .font(.system(.caption, weight: .bold))
            Text(shieldName)
                .font(.system(.caption, design: .monospaced, weight: .black))
        }
        Spacer()
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```

**Step 2: Replace Angriff/Parieren buttons with loadout-aware versions**

- **Angriff:** If shield is equipped, go to a quick weapon/shield choice. If no shield, go straight to execution with main weapon.
- **Parieren:** If shield is equipped, go to a quick main-weapon-PA vs shield-PA choice. If no shield, go straight to execution with main weapon PA.

For Angriff button action:

```swift
if hero.selectedShield != nil {
    step = .weaponSelection(.angriff)
} else if let w = hero.selectedWeapon {
    step = .execution(.angriff, name: w.name, attributeValue: w.at, damageFormula: w.damage, note: nil)
} else if hero.selectedWeaponName == "Raufen" {
    let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
    step = .execution(.angriff, name: "Raufen", attributeValue: raufen?.at ?? 0, damageFormula: "1W6", note: nil)
}
```

For Parieren button action:

```swift
if hero.selectedShield != nil {
    step = .weaponSelection(.parieren)
} else if let w = hero.selectedWeapon {
    step = .execution(.parieren, name: w.name, attributeValue: w.pa, damageFormula: nil, note: nil)
} else if hero.selectedWeaponName == "Raufen" {
    let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
    step = .execution(.parieren, name: "Raufen", attributeValue: raufen?.pa ?? 0, damageFormula: nil, note: nil)
}
```

**Step 3: Add "Ausrüstung wechseln" button**

After Schaden nehmen button, add:

```swift
Button { step = .loadoutWeapon } label: {
    HStack(spacing: 6) {
        Image(systemName: "arrow.triangle.2.circlepath")
        Text(L("changeLoadout"))
    }
    .font(.system(.caption, weight: .bold))
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
}
.buttonStyle(.plain)
```

Add localization: `"changeLoadout" = "Ausrüstung wechseln";`

**Step 4: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 5: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift iDSACompanion/Resources/Localizable.strings
git commit -m "feat: show loadout in combat root with change button"
```

---

### Task 8: Rewrite CombatWeaponSelectionView for loadout-aware choices

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift` (CombatWeaponSelectionView, lines ~917–1027)

**Step 1: Rewrite for simplified attack/parry choice**

With a loadout set, this view now shows a **quick choice** between main weapon and shield (if equipped). Replace the full weapon list with:

**For Angriff:**
- Row: main weapon (AT value, damage formula)
- Row: shield (AT value, damage formula)

**For Parieren:**
- Row: main weapon name + "PA \(weapon.pa + passiveShieldPABonus)" (passive bonus applied)
- Row: shield name + "PA \(shield.pa)" (active, doubled bonus already in value)

```swift
private struct CombatWeaponSelectionView: View {
    let action: CombatAction
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var headerLabel: String {
        action == .angriff ? "Angriff" : "Parieren"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (same as before)
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(headerLabel)
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    let statLabel = action == .angriff ? "AT" : "PA"

                    // Main weapon option
                    if let w = hero.selectedWeapon {
                        combatSectionLabel("HAUPTWAFFE (\(statLabel))")
                        let val: Int
                        let note: String? = nil
                        if action == .angriff {
                            val = w.at
                        } else {
                            val = w.pa + hero.passiveShieldPABonus
                        }
                        weaponRow(name: w.name, statLabel: statLabel, statValue: val, damageFormula: action == .angriff ? w.damage : nil, note: note)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        combatSectionLabel("HAUPTWAFFE (\(statLabel))")
                        let val = action == .angriff ? (raufen?.at ?? 0) : ((raufen?.pa ?? 0) + hero.passiveShieldPABonus)
                        weaponRow(name: "Raufen", statLabel: statLabel, statValue: val, damageFormula: action == .angriff ? "1W6" : nil, note: nil)
                    }

                    // Shield option
                    if let s = hero.selectedShield {
                        combatSectionLabel("SCHILD (\(statLabel))")
                        let val = action == .angriff ? s.at : s.pa
                        let shieldNote = action == .parieren ? s.note : nil
                        weaponRow(name: s.name, statLabel: statLabel, statValue: val, damageFormula: action == .angriff ? s.damage : nil, note: shieldNote)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func weaponRow(name: String, statLabel: String, statValue: Int, damageFormula: String? = nil, note: String? = nil) -> some View {
        Button {
            step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil, note: action == .parieren ? note : nil)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let note, !note.isEmpty {
                        Text(note)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(statLabel) \(statValue)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.dsaDark)
                    if hero.belastungPenalty != 0 {
                        Text("(\(hero.belastungPenalty))")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}
```

**Step 2: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 3: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift
git commit -m "feat: rewrite weapon selection for loadout-aware attack/parry choice"
```

---

### Task 9: Update CombatExecutionView to show shield note

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift` (CombatExecutionView, lines ~1029–1160)

**Step 1: Add note parameter**

Add `let note: String?` to CombatExecutionView properties. Update the `.execution` case in CombatView body to pass it:

```swift
case .execution(let action, let name, let attrValue, let dmgFormula, let note):
    CombatExecutionView(
        action: action,
        weaponName: name,
        attributeValue: attrValue,
        damageFormula: dmgFormula,
        note: note,
        step: $step,
        onDismiss: onDismiss
    )
```

**Step 2: Display note in execution view**

After the `valueBox` for AT/PA/AW, add:

```swift
if let note, !note.isEmpty {
    Text(note)
        .font(.system(.caption2, weight: .bold))
        .foregroundStyle(combatAccent)
        .padding(.top, 2)
}
```

**Step 3: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 4: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift
git commit -m "feat: display shield note in combat execution view"
```

---

### Task 10: Update Ausweichen to pass note parameter

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift` (CombatRootView, line ~599)

**Step 1: Add nil note to Ausweichen execution**

Update the Ausweichen button to include the note parameter:

```swift
step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw, damageFormula: nil, note: nil)
```

**Step 2: Build and verify**

```bash
xcodebuild -scheme iDSACompanion -destination 'generic/platform=iOS Simulator' build
```

**Step 3: Commit**

```bash
git add iDSACompanion/Views/CombatView.swift
git commit -m "fix: pass note parameter to Ausweichen execution step"
```

---

### Task 11: Update docs and changelog

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/2026-03-12-combat-loadout-design.md` (mark as implemented)

**Step 1: Add changelog entry**

Under `[Unreleased]` → `Added`:

```markdown
- Combat loadout system: select main weapon + shield before combat
- Passive shield PA bonus applied to main weapon parade
- Active shield parry with doubled PA bonus
- Shield-specific combat notes (e.g., Großschild +1 PA vs. Fernkampf)
- Loadout persists across combat sessions
- PA rounding fix: ceil(KtW/2) per DSA 5 rules
```

**Step 2: Commit**

```bash
git add CHANGELOG.md docs/plans/2026-03-12-combat-loadout-design.md
git commit -m "docs: update changelog for combat loadout system"
```
