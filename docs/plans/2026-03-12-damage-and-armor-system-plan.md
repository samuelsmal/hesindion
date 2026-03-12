# Damage & Armor System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Implement armor equip/unequip, Belastung penalties on combat stats, and a "Schaden nehmen" damage flow in combat mode.

**Architecture:** Extend the existing `Armor` model with `isEquipped`, `iniModifier`, `gsModifier`. Add computed properties on `Hero` for RS/BE/Belastung. Modify CombatView to add armor selection at start, armor management mid-combat, and a "Schaden nehmen" flow with TP input → RS calculation → LP reduction.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

---

### Task 1: Extend Armor Model

**Files:**
- Modify: `Hesindion/Models/Armor.swift`

**Step 1: Add new properties to Armor**

```swift
@Model
final class Armor {
    var name: String
    var protectionValue: Int
    var encumbrance: Int
    var weight: Double
    var isEquipped: Bool
    var iniModifier: Int
    var gsModifier: Int

    init(name: String, protectionValue: Int, encumbrance: Int, weight: Double, isEquipped: Bool = false, iniModifier: Int = 0, gsModifier: Int = 0) {
        self.name = name
        self.protectionValue = protectionValue
        self.encumbrance = encumbrance
        self.weight = weight
        self.isEquipped = isEquipped
        self.iniModifier = iniModifier
        self.gsModifier = gsModifier
    }
}
```

**Step 2: Build and verify no compile errors**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Models/Armor.swift
git commit -m "feat: add isEquipped, iniModifier, gsModifier to Armor model"
```

---

### Task 2: Add Belastung Computed Properties to Hero

**Files:**
- Modify: `Hesindion/Models/Hero.swift`

**Step 1: Add computed properties**

Add these computed properties to the `Hero` class after `verbessertRegenerationLEBonus`:

```swift
/// Sum of RS from all equipped armor pieces.
var totalRS: Int {
    armors.filter(\.isEquipped).reduce(0) { $0 + $1.protectionValue }
}

/// Sum of BE from all equipped armor pieces.
var totalEquippedBE: Int {
    armors.filter(\.isEquipped).reduce(0) { $0 + $1.encumbrance }
}

/// Level of Belastungsgewöhnung combat SA (SA_41). Each level reduces effective BE by 2.
var belastungsgewoehnungLevel: Int {
    combatSpecialAbilities.first(where: { $0.ruleId == "SA_41" })?.tier ?? 0
}

/// Effective BE after Belastungsgewöhnung reduction.
var effectiveBE: Int {
    max(0, totalEquippedBE - 2 * belastungsgewoehnungLevel)
}

/// Belastung penalty applied to AT, PA, AW, INI, GS. Equals negative effectiveBE.
var belastungPenalty: Int {
    -effectiveBE
}

/// Sum of direct INI modifiers from equipped armor (independent of BE).
var armorIniModifier: Int {
    armors.filter(\.isEquipped).reduce(0) { $0 + $1.iniModifier }
}

/// Sum of direct GS modifiers from equipped armor (independent of BE).
var armorGsModifier: Int {
    armors.filter(\.isEquipped).reduce(0) { $0 + $1.gsModifier }
}

/// Total INI penalty: Belastung + direct armor modifiers.
var totalIniPenalty: Int {
    belastungPenalty + armorIniModifier
}

/// Total GS penalty: Belastung + direct armor modifiers.
var totalGsPenalty: Int {
    belastungPenalty + armorGsModifier
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Models/Hero.swift
git commit -m "feat: add RS, BE, and Belastung computed properties to Hero"
```

---

### Task 3: Add Localization Strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add new string keys**

Add to both `englishFallback` and `translations` dictionaries:

English:
```swift
// Damage & Armor
"takeDamage":           "Take Damage",
"takeDamage.label":     "TAKE DAMAGE",
"tp":                   "TP",
"rs":                   "RS",
"equip":                "Equip",
"unequip":              "Unequip",
"armorSelection":       "Armor Selection",
"armorSelection.label": "ARMOR",
"continue":             "Continue",
"confirm":              "Confirm",
"noArmor":              "No armor available",
"equipped":             "Equipped",
"protectionValue":      "RS",
"encumbrance":          "BE",
"lpLost":               "LP lost",
"absorbed":             "Armor absorbs all damage",
```

German:
```swift
// Damage & Armor
"takeDamage":           "Schaden nehmen",
"takeDamage.label":     "SCHADEN NEHMEN",
"tp":                   "TP",
"rs":                   "RS",
"equip":                "Anlegen",
"unequip":              "Ablegen",
"armorSelection":       "Rüstungsauswahl",
"armorSelection.label": "RÜSTUNG",
"continue":             "Weiter",
"confirm":              "Bestätigen",
"noArmor":              "Keine Rüstung vorhanden",
"equipped":             "Angelegt",
"protectionValue":      "RS",
"encumbrance":          "BE",
"lpLost":               "LP verloren",
"absorbed":             "Rüstung absorbiert allen Schaden",
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add damage and armor localization strings"
```

---

### Task 4: Update OptolithImportService for Armor Fields

**Files:**
- Modify: `Hesindion/Services/OptolithImportService.swift`

**Step 1: Update armor parsing in parseItems**

In the `case 4:` branch of `parseItems` (~line 672-676), add `iniMod` and `movMod` parsing:

```swift
case 4:
    // Armor
    let pro = intFromAny(item["pro"]) ?? 0
    let enc = intFromAny(item["enc"]) ?? 0
    let iniMod = intFromAny(item["iniMod"]) ?? 0
    let movMod = intFromAny(item["movMod"]) ?? 0
    armors.append(Armor(name: name, protectionValue: pro, encumbrance: enc, weight: weight, iniModifier: iniMod, gsModifier: movMod))
```

Note: Optolith uses `iniMod` for INI modifier and `movMod` for GS modifier on armor items. Most items don't have these fields, so they default to 0.

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Services/OptolithImportService.swift
git commit -m "feat: parse iniMod and movMod for armor in Optolith import"
```

---

### Task 5: Add Armor Equip/Unequip in HeroDetailView

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Update armorSection**

Replace the current `armorSection` (~lines 706-720) with swipe-to-toggle equip/unequip:

```swift
// MARK: - Section 15: Armors

@ViewBuilder private var armorSection: some View {
    if !hero.armors.isEmpty {
        CollapsibleSection(L("armor")) {
            ForEach(hero.armors, id: \.persistentModelID) { a in
                SwipeActionRow(
                    actions: [
                        SwipeAction(
                            icon: a.isEquipped ? "xmark.circle.fill" : "checkmark.circle.fill",
                            color: a.isEquipped ? .red : .green
                        ) {
                            a.isEquipped.toggle()
                        }
                    ]
                ) {
                    HStack {
                        SubfieldBlock(label: a.name, subfields: [
                            ("protectionValue", "RS \(a.protectionValue)"),
                            ("encumbrance", "BE \(a.encumbrance)"),
                            ("weight", String(format: "%.2f st", a.weight))
                        ])
                        if a.isEquipped {
                            Text(L("equipped"))
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.groupCombat)
                        }
                    }
                }
            }
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: add swipe-to-equip armor toggle in hero detail view"
```

---

### Task 6: Show Belastung Penalties on Stats in HeroDetailView

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Update combat technique display**

In `combatTechniquesSection`, find the AT/PA display lines and append the penalty when non-zero. Currently combat techniques are shown via `SwipeActionRow` with the CT value. The AT/PA sub-labels are shown below the name. Find the section (~line 528-550) that shows AT and PA values and modify:

Where AT and PA are displayed for each combat technique (inside the VStack after SwipeActionRow), change the display to include the Belastung penalty. Currently there are lines like:

```swift
Text("AT \(ct.at)  PA \(ct.pa)")
```

Update to:

```swift
let penalty = hero.belastungPenalty
let atStr = penalty != 0 ? "AT \(ct.at) (\(penalty))" : "AT \(ct.at)"
let paStr = ct.pa > 0 ? (penalty != 0 ? "PA \(ct.pa) (\(penalty))" : "PA \(ct.pa)") : "PA —"
Text("\(atStr)  \(paStr)")
```

**Step 2: Update derived values display**

Find where INI, AW, and GS are displayed in the derived values section. Add penalty display:

For INI: if `hero.totalIniPenalty != 0`, show `"INI \(value) (\(hero.totalIniPenalty))"`
For AW: if `hero.belastungPenalty != 0`, show `"AW \(value) (\(hero.belastungPenalty))"`
For GS: if `hero.totalGsPenalty != 0`, show `"GS \(value) (\(hero.totalGsPenalty))"`

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: display Belastung penalties on AT/PA/AW/INI/GS"
```

---

### Task 7: Add Combat Armor Selection Step

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Add armorSelection to CombatStep enum**

Update the `CombatStep` enum (~line 9-13):

```swift
private enum CombatStep {
    case armorSelection
    case initiativeRoll
    case root
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?)
    case takeDamage
}
```

**Step 2: Update stepID**

```swift
private var stepID: String {
    switch step {
    case .armorSelection: "armorSelection"
    case .initiativeRoll: "initiativeRoll"
    case .root: "root"
    case .weaponSelection: "weaponSelection"
    case .execution: "execution"
    case .takeDamage: "takeDamage"
    }
}
```

**Step 3: Update CombatView body**

In the CombatView body (~line 50-79), add cases for `.armorSelection`, `.initiativeRoll`, and `.takeDamage`:

```swift
var body: some View {
    VStack(spacing: 0) {
        switch step {
        case .armorSelection:
            CombatArmorSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .leading))
        case .initiativeRoll:
            CombatInitiativeRollView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .trailing))
        case .root:
            CombatRootView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .leading))
        case .weaponSelection(let action):
            CombatWeaponSelectionView(action: action, hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .trailing))
        case .execution(let action, let name, let attrValue, let dmgFormula):
            CombatExecutionView(
                action: action,
                weaponName: name,
                attributeValue: attrValue,
                damageFormula: dmgFormula,
                step: $step,
                onDismiss: onDismiss
            )
            .transition(.move(edge: .trailing))
        case .takeDamage:
            CombatTakeDamageView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .trailing))
        }
    }
    .animation(DSAAnimation.standard, value: stepID)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(UIColor.systemBackground))
    .gesture(DragGesture().onEnded { v in
        if v.translation.height > 80 {
            if case .root = step { onDismiss() } else { step = .root }
        }
    })
}
```

**Step 4: Change initial step to .armorSelection**

Change the `@State` initial value:

```swift
@State private var step: CombatStep = .armorSelection
```

But only if the hero has armor. If no armor, start at `.initiativeRoll`:

Actually, keep it simple — always start at `.armorSelection`. The armor selection view handles the "no armor" case with a "skip" path.

**Step 5: Build** (will fail — new views not yet defined, that's expected)

Continue to next task.

**Step 6: Commit (partial — enum changes only)**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add armorSelection, initiativeRoll, takeDamage to CombatStep"
```

---

### Task 8: Implement CombatArmorSelectionView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Add CombatArmorSelectionView**

Add this view after the `CombatView` struct but before `CombatRootView`:

```swift
// MARK: - CombatArmorSelectionView

private struct CombatArmorSelectionView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("armorSelection"))
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

            if hero.armors.isEmpty {
                VStack(spacing: 12) {
                    Text(L("noArmor"))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            } else {
                combatSectionLabel(L("armorSelection.label"))

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(hero.armors, id: \.persistentModelID) { armor in
                            Button {
                                armor.isEquipped.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(armor.name)
                                            .font(.system(.body, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text("RS \(armor.protectionValue)  BE \(armor.encumbrance)")
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: armor.isEquipped ? "checkmark.circle.fill" : "circle")
                                        .font(.system(.title3, weight: .bold))
                                        .foregroundStyle(armor.isEquipped ? combatAccent : .secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                                .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Summary
                if hero.totalRS > 0 {
                    HStack {
                        Text("RS \(hero.totalRS)")
                            .font(.system(.body, design: .monospaced, weight: .black))
                        Spacer()
                        Text("BE \(hero.effectiveBE)")
                            .font(.system(.body, design: .monospaced, weight: .black))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.dsaDark)
                    .foregroundStyle(.white)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    .padding(.horizontal, 16)
                }
            }

            Spacer()

            // Continue button
            Button {
                step = .initiativeRoll
            } label: {
                Text(L("continue"))
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: May still fail if CombatInitiativeRollView and CombatTakeDamageView don't exist yet. Continue.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add CombatArmorSelectionView"
```

---

### Task 9: Extract Initiative Roll as a Combat Step

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Create CombatInitiativeRollView**

This wraps the existing `CombatInitiativeSheet` logic but as a full step instead of a sheet. Add after `CombatArmorSelectionView`:

```swift
// MARK: - CombatInitiativeRollView

private struct CombatInitiativeRollView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var selectedBase: Int? = nil
    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var animTask: Task<Void, Never>? = nil

    private var heroBaseINI: Int {
        (hero.derivedValues?.initiative.value ?? 0) + hero.totalIniPenalty
    }

    private var mountBaseINI: Int? {
        hero.pets.first.flatMap { pet in
            Int(pet.initiative.split(separator: "+").first ?? "")
        }
    }

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return base + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .armorSelection } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("newInitiative"))
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

            VStack(spacing: 0) {
                combatSectionLabel("BASIS")

                HStack(spacing: 8) {
                    baseButton(label: "Held", value: heroBaseINI)
                    if let mountINI = mountBaseINI {
                        baseButton(label: hero.pets.first?.name ?? "Reittier", value: mountINI)
                    }
                }
                .padding(.horizontal, 16)

                if selectedBase != nil {
                    VStack(spacing: 8) {
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.system(.largeTitle, weight: .black))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text(L("tapToRoll"))
                                        .font(.system(.caption2, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            .contentShape(Rectangle())
                            .onTapGesture { rollD6() }
                            Text("W6")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        if let base = selectedBase {
                            Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                                .font(.system(.title3, weight: .black))
                                .fontDesign(.monospaced)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.systemBackground))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                                .opacity(d6Result == nil ? 0.4 : 1)
                        }

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                step = .root
                            } label: {
                                Text("Bestätigen  →  INI \(t)")
                                    .font(.system(.body, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(label: String, value: Int) -> some View {
        let isSelected = selectedBase == value
        return Button {
            selectedBase = value
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, weight: .bold))
                Text("\(value)")
                    .font(.system(.title3, weight: .black))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private func startD6Animation() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            var count = 0
            while !Task.isCancelled && count < 12 {
                d6Display = Int.random(in: 1...6)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            d6Result = Int.random(in: 1...6)
        }
    }

    private func rollD6() {
        guard d6Result == nil else { return }
        animTask?.cancel()
        d6Result = Int.random(in: 1...6)
    }
}
```

**Step 2: Update CombatRootView to store rolled initiative**

The `CombatRootView` currently manages its own initiative state. Since we now roll initiative in a separate step, we need to pass the rolled value. For simplicity, keep the existing initiative sheet in CombatRootView as well (for "Neu" button re-rolls during combat). The initial roll happens in the new step.

Actually, the cleanest approach: store initiative as a `@State` in the parent `CombatView` and pass it through. Update `CombatView`:

```swift
struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @State private var step: CombatStep = .armorSelection
    @State private var rolledInitiative: Int? = nil
    // ...
}
```

Pass `rolledInitiative` binding to both `CombatInitiativeRollView` and `CombatRootView`. The initiative roll view sets it; the root view reads and can re-roll via the existing "Neu" sheet.

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: May still fail until CombatTakeDamageView exists. Continue.

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add CombatInitiativeRollView with Belastung-adjusted INI"
```

---

### Task 10: Implement CombatTakeDamageView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Add CombatTakeDamageView**

Add after `CombatExecutionView`:

```swift
// MARK: - CombatTakeDamageView

private struct CombatTakeDamageView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var tpInput: Int = 1
    @State private var confirmed: Bool = false

    private var totalRS: Int { hero.totalRS }

    private var damage: Int { max(0, tpInput - totalRS) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("takeDamage"))
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

            VStack(spacing: 8) {
                // TP Input
                combatSectionLabel(L("takeDamage.label"))

                HStack(spacing: 0) {
                    Button { if tpInput > 0 { tpInput -= 1 } } label: {
                        Image(systemName: "minus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Text("\(tpInput)")
                        .font(.system(.title, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(minWidth: 80)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button { tpInput += 1 } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)

                Text(L("tp"))
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)

                // Calculation display (black bg, white text)
                VStack(spacing: 4) {
                    Text("\(tpInput) TP − \(totalRS) RS = \(damage)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)

                    if damage == 0 {
                        Text(L("absorbed"))
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(damage) \(L("lpLost"))")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                .padding(.horizontal, 16)

                // Confirm button
                if !confirmed {
                    Button {
                        if let dv = hero.derivedValues {
                            dv.lebensenergie.current = max(0, dv.lebensenergie.current - damage)
                        }
                        confirmed = true
                    } label: {
                        Text(L("confirm"))
                            .font(.system(.body, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                } else {
                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add CombatTakeDamageView with TP input and RS calculation"
```

---

### Task 11: Add "Schaden nehmen" Button and Armor Management to CombatRootView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Add "Schaden nehmen" button**

In `CombatRootView`, after the Ausweichen button in the AKTION section (~line 235-252), add:

```swift
// Schaden nehmen — distinct danger styling
Button {
    step = .takeDamage
} label: {
    HStack(spacing: 6) {
        Image(systemName: "heart.slash.fill")
        Text(L("takeDamage"))
    }
    .font(.system(.title3, weight: .black))
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color.dsaDark)
    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
}
.buttonStyle(.plain)
```

**Step 2: Add armor management button**

Near the LP bar section, add a gear icon button that opens an armor management sheet:

Add state variable:
```swift
@State private var showArmorSheet = false
```

After the `lpBar` view, add:
```swift
// Armor management button
Button { showArmorSheet = true } label: {
    HStack(spacing: 6) {
        Image(systemName: "shield.fill")
        Text("RS \(hero.totalRS)")
            .font(.system(.caption, design: .monospaced, weight: .black))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.dsaDark)
    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
}
.buttonStyle(.plain)
.padding(.horizontal, 16)
.sheet(isPresented: $showArmorSheet) {
    CombatArmorManagementSheet(hero: hero)
        .presentationCornerRadius(0)
}
```

**Step 3: Create CombatArmorManagementSheet**

```swift
// MARK: - CombatArmorManagementSheet

private struct CombatArmorManagementSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("armorSelection"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
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

            if hero.armors.isEmpty {
                Text(L("noArmor"))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(hero.armors, id: \.persistentModelID) { armor in
                            Button { armor.isEquipped.toggle() } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(armor.name)
                                            .font(.system(.body, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text("RS \(armor.protectionValue)  BE \(armor.encumbrance)")
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: armor.isEquipped ? "checkmark.circle.fill" : "circle")
                                        .font(.system(.title3, weight: .bold))
                                        .foregroundStyle(armor.isEquipped ? combatAccent : .secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                                .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }

            if hero.totalRS > 0 {
                HStack {
                    Text("RS \(hero.totalRS)")
                        .font(.system(.body, design: .monospaced, weight: .black))
                    Spacer()
                    Text("BE \(hero.effectiveBE)")
                        .font(.system(.body, design: .monospaced, weight: .black))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.dsaDark)
                .foregroundStyle(.white)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Spacer()
        }
    }
}
```

**Step 4: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add Schaden nehmen button and armor management to combat root"
```

---

### Task 12: Show Belastung Penalties in Combat View

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Update weapon rows in CombatWeaponSelectionView**

In `CombatWeaponSelectionView`, the `weaponRow` function shows AT/PA values. Update it to also display the Belastung penalty when non-zero.

Update the stat display in `weaponRow`:

```swift
private func weaponRow(name: String, statLabel: String, statValue: Int, damageFormula: String? = nil) -> some View {
    let penalty = hero.belastungPenalty
    Button {
        step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil)
    } label: {
        HStack {
            Text(name)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 4) {
                Text("\(statLabel) \(statValue)")
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.dsaDark)
                if penalty != 0 {
                    Text("(\(penalty))")
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
```

**Step 2: Update Ausweichen button in CombatRootView**

The Ausweichen button uses the AW value. Update its display to show the penalty:

In the Ausweichen button label, show penalty if non-zero.

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: display Belastung penalties on combat weapon and dodge stats"
```

---

### Task 13: Wire Up Initiative State Between Combat Steps

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Pass initiative through CombatView**

The parent `CombatView` holds `@State private var rolledInitiative: Int? = nil`. Pass this as a binding to `CombatInitiativeRollView` (which sets it) and `CombatRootView` (which reads it and can re-roll via the existing "Neu" sheet).

Update `CombatInitiativeRollView` to accept `@Binding var rolledInitiative: Int?` and set it on confirm.

Update `CombatRootView` to accept `@Binding var rolledInitiative: Int?` and use it for the INI display instead of local state. Keep the existing "Neu" sheet for re-rolling.

**Step 2: Remove the old initiative sheet auto-display from CombatRootView**

The `CombatRootView` currently has its own `@State private var rolledInitiative: Int? = nil` and `showInitiativeSheet`. Replace with the binding.

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: wire initiative state between combat armor/initiative/root steps"
```

---

### Task 14: Final Build Verification and Manual Testing

**Step 1: Full build**

Run: `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 2: Manual testing checklist**

1. Import a hero with armor (Boronmir)
2. In hero detail view, swipe left on armor → verify equip/unequip toggle works
3. Verify AT/PA/AW/INI/GS show Belastung penalty when armor equipped
4. Enter combat → verify armor selection screen appears
5. Select armor → tap "Weiter" → verify initiative roll screen with adjusted INI
6. Roll initiative → confirm → verify combat root view
7. Verify RS badge shows correct value
8. Tap gear icon → verify armor management sheet
9. Tap "Schaden nehmen" → enter TP → verify calculation display (black bg, white text)
10. Confirm → verify LP reduced → verify LP bar updated
11. Exit combat and re-enter → verify armor selection remembers equipped state

**Step 3: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: complete damage and armor system implementation"
```
