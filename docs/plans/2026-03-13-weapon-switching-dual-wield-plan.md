# Weapon Switching & Dual-Wield Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Allow weapon switching mid-combat, support dual-wielding for heroes with Beidhändig (ADV_5), add Vorteilhafte Position per-roll toggle, and two-handed grip option.

**Architecture:** Extends existing CombatView step-based navigation. Merges weapon+shield loadout into one view with checkboxes. Adds pre-attack choice screen and per-roll modifier options. All changes in CombatView.swift, Hero.swift, and Strings.swift.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

**Design doc:** `docs/plans/2026-03-13-weapon-switching-dual-wield-design.md`

---

### Task 1: Add `selectedOffHandName` to Hero model

**Files:**
- Modify: `Hesindion/Models/Hero.swift:33-36` (loadout persistence section)
- Modify: `Hesindion/Models/Hero.swift:146-161` (loadout computed helpers)

**Step 1: Add the persisted property**

In `Hero.swift`, after line 36 (`var selectedShieldName: String?`), add:

```swift
var selectedOffHandName: String?
```

**Step 2: Add computed helpers**

After the existing `passiveShieldPABonus` computed property (line 159-161), add:

```swift
/// Off-hand item: either a MeleeWeapon or a Shield.
var selectedOffHandWeapon: MeleeWeapon? {
    guard let name = selectedOffHandName else { return nil }
    return meleeWeapons.first { $0.name == name }
}

/// True if hero has the Beidhändig advantage (ADV_5), removing the -4 off-hand penalty.
var hasBeidhaendig: Bool {
    advantages.contains { $0.ruleId == "ADV_5" }
}

/// Level of Beidhändiger Kampf SA. Each level reduces the -2 dual-attack penalty by 1.
/// Returns 0 if the hero doesn't have the SA.
/// TODO: Confirm correct SA ruleId for "Beidhändiger Kampf" once identified in Optolith data.
var beidhaendigerKampfLevel: Int {
    // SA ruleId unknown — scan by name as fallback
    let sa = combatSpecialAbilities.first { $0.name.contains("Beidhändiger Kampf") }
    return sa?.tier ?? 0
}

/// Dual-attack penalty: base -2, reduced by Beidhändiger Kampf level.
var dualAttackPenalty: Int {
    max(0, 2 - beidhaendigerKampfLevel) * -1
}

/// Off-hand penalty: -4 unless hero has Beidhändig (ADV_5).
var offHandPenalty: Int {
    hasBeidhaendig ? 0 : -4
}

/// True if the current loadout is dual-wielding (two weapons, no shield in off-hand).
var isDualWielding: Bool {
    selectedWeaponName != nil && selectedOffHandWeapon != nil
}

/// The selected shield — derived from selectedOffHandName if it matches a shield, otherwise from selectedShieldName for backwards compat.
var selectedShieldFromOffHand: Shield? {
    guard let name = selectedOffHandName else { return nil }
    return shields.first { $0.name == name }
}
```

**Step 3: Update `selectedShield` computed property**

Replace the existing `selectedShield` (lines 153-156):

```swift
var selectedShield: Shield? {
    // Check off-hand first (new unified loadout), then legacy selectedShieldName
    if let name = selectedOffHandName, let shield = shields.first(where: { $0.name == name }) {
        return shield
    }
    guard let name = selectedShieldName else { return nil }
    return shields.first { $0.name == name }
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Hesindion/Models/Hero.swift
git commit -m "feat: add off-hand weapon support and dual-wield computed properties to Hero"
```

---

### Task 2: Add new localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add English strings**

In the English `strings` dictionary, in the combat section (around line 109), add these entries:

```swift
"selectEquipment":      "Select Equipment",
"offHandWeapon":        "OFF-HAND",
"dualAttack":           "Both Weapons",
"singleAttack":         "One Weapon",
"oneHanded":            "One-Handed",
"twoHanded":            "Two-Handed (+1 TP, −1 PA)",
"dualAttackPenalty":    "Dual-attack penalty",
"offHandPenalty":       "Off-hand penalty",
"advantageousPosition": "Advantageous Position (+2)",
"fumbleSecondLost":     "Fumble! Second attack lost.",
"selectParryWeapon":    "Parry With",
```

**Step 2: Add German strings**

In the German `strings` dictionary (around line 301), add:

```swift
"selectEquipment":      "Ausrüstung wählen",
"offHandWeapon":        "NEBENHAND",
"dualAttack":           "Beide Waffen",
"singleAttack":         "Eine Waffe",
"oneHanded":            "Einhändig",
"twoHanded":            "Zweihändig (+1 TP, −1 PA)",
"dualAttackPenalty":    "Beidhändig-Abzug",
"offHandPenalty":       "Nebenhand-Abzug",
"advantageousPosition": "Vorteilhafte Position (+2)",
"fumbleSecondLost":     "Patzer! Zweiter Angriff entfällt.",
"selectParryWeapon":    "Parieren mit",
```

**Step 3: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add localization strings for dual-wield and weapon switching"
```

---

### Task 3: Update CombatStep enum and CombatView orchestrator

**Files:**
- Modify: `Hesindion/Views/CombatView.swift:1-122`

**Step 1: Update `CombatStep` enum**

Replace the existing enum (lines 9-18):

```swift
private enum CombatStep {
    case armorSelection
    case initiativeRoll
    case loadoutEquipment           // was: loadoutWeapon + loadoutShield (merged)
    case root
    case attackChoice               // new: "one or both weapons?" / "one-handed or two-handed?"
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?)
    case dualAttackSecond(name: String, attributeValue: Int, damageFormula: String?) // new: second dual-wield attack
    case takeDamage
}
```

**Step 2: Update `stepID` computed property**

Replace the `stepID` switch (lines 48-58):

```swift
private var stepID: String {
    switch step {
    case .armorSelection: "armorSelection"
    case .initiativeRoll: "initiativeRoll"
    case .loadoutEquipment: "loadoutEquipment"
    case .root: "root"
    case .attackChoice: "attackChoice"
    case .weaponSelection: "weaponSelection"
    case .execution: "execution"
    case .dualAttackSecond: "dualAttackSecond"
    case .takeDamage: "takeDamage"
    }
}
```

**Step 3: Add combat round state**

Add state variables to CombatView struct, after `rolledInitiative`:

```swift
@State private var dualAttackPenaltyActive: Bool = false
@State private var twoHandedGripActive: Bool = false
@State private var roundNumber: Int = 1
```

Note: `roundNumber` is being moved from CombatRootView to CombatView so it can be observed for penalty resets. CombatRootView will receive it as a binding.

**Step 4: Update the body switch statement**

Replace the body's switch (lines 63-96):

```swift
var body: some View {
    VStack(spacing: 0) {
        switch step {
        case .armorSelection:
            CombatArmorSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .leading))
        case .initiativeRoll:
            CombatInitiativeRollView(hero: hero, step: $step, rolledInitiative: $rolledInitiative, onDismiss: onDismiss)
                .transition(.move(edge: .trailing))
        case .loadoutEquipment:
            CombatLoadoutEquipmentView(hero: hero, step: $step, onDismiss: onDismiss)
                .transition(.move(edge: .trailing))
        case .root:
            CombatRootView(
                hero: hero,
                step: $step,
                rolledInitiative: $rolledInitiative,
                roundNumber: $roundNumber,
                dualAttackPenaltyActive: $dualAttackPenaltyActive,
                twoHandedGripActive: $twoHandedGripActive,
                onDismiss: onDismiss
            )
            .transition(.move(edge: .leading))
        case .attackChoice:
            CombatAttackChoiceView(
                hero: hero,
                step: $step,
                dualAttackPenaltyActive: $dualAttackPenaltyActive,
                twoHandedGripActive: $twoHandedGripActive,
                onDismiss: onDismiss
            )
            .transition(.move(edge: .trailing))
        case .weaponSelection(let action):
            CombatWeaponSelectionView(
                action: action,
                hero: hero,
                step: $step,
                dualAttackPenaltyActive: dualAttackPenaltyActive,
                twoHandedGripActive: twoHandedGripActive,
                onDismiss: onDismiss
            )
            .transition(.move(edge: .trailing))
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
            .transition(.move(edge: .trailing))
        case .dualAttackSecond(let name, let attrValue, let dmgFormula):
            CombatExecutionView(
                action: .angriff,
                weaponName: name,
                attributeValue: attrValue,
                damageFormula: dmgFormula,
                note: L("dualAttackPenalty"),
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
            switch step {
            case .armorSelection:
                onDismiss()
            case .initiativeRoll:
                step = .armorSelection
            case .loadoutEquipment:
                step = .initiativeRoll
            case .root:
                onDismiss()
            case .attackChoice:
                step = .root
            case .takeDamage:
                step = .root
            default:
                step = .root
            }
        }
    })
    .onChange(of: roundNumber) { _, _ in
        dualAttackPenaltyActive = false
        twoHandedGripActive = false
    }
}
```

**Step 5: Build (will fail — expected, new views don't exist yet)**

This step cannot build yet because `CombatLoadoutEquipmentView`, `CombatAttackChoiceView` don't exist and `CombatRootView` signature changed. That's fine — we'll add them in subsequent tasks.

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: update CombatStep enum and orchestrator for dual-wield and equipment merging"
```

---

### Task 4: Replace loadout views with combined CombatLoadoutEquipmentView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — delete `CombatLoadoutWeaponView` (lines 248-350) and `CombatLoadoutShieldView` (lines 352-445), replace with new combined view

**Step 1: Delete both old views and add new combined view**

Delete `CombatLoadoutWeaponView` and `CombatLoadoutShieldView` entirely (lines 248-445). Replace with:

```swift
// MARK: - CombatLoadoutEquipmentView

private struct CombatLoadoutEquipmentView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    /// Tracks selected item names (max 2).
    @State private var selected: Set<String> = []

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
    }

    /// All selectable items: weapons, shields, and Raufen.
    private var allItems: [(name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)] {
        var items: [(String, String, String?, Bool, Bool, Bool)] = []
        for w in hero.meleeWeapons {
            // Check if weapon requires two hands (Zweihandwaffen, Stangenwaffen)
            let twoHandedTechniques = ["CT_7", "CT_14"] // Zweihandschwerter, Stangenwaffen
            let isTwoHanded = twoHandedTechniques.contains(w.combatTechniqueId)
            items.append((w.name, "AT \(w.at) / PA \(w.pa)", nil, false, false, isTwoHanded))
        }
        for s in hero.shields {
            items.append((s.name, "AT \(s.at) / PA \(s.pa)", s.note.isEmpty ? nil : s.note, true, false, false))
        }
        items.append(("Raufen", "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)", nil, false, true, false))
        return items
    }

    private func canSelect(_ item: (name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)) -> Bool {
        if selected.contains(item.name) { return true } // can always deselect
        if item.isRaufen { return selected.isEmpty } // Raufen = both hands free
        if item.isTwoHandedOnly { return selected.isEmpty } // two-handed weapon needs both hands
        if selected.count >= 2 { return false }
        if selected.count == 1 {
            // Check what's already selected
            let currentItem = allItems.first { selected.contains($0.name) }
            if currentItem?.isRaufen == true { return false } // can't add to Raufen
            if currentItem?.isTwoHandedOnly == true { return false } // can't add to two-handed
            // Can't pick two weapons without Beidhändig
            if !item.isShield && currentItem?.isShield == false && !hero.hasBeidhaendig { return false }
            // Can't pick two shields
            if item.isShield && currentItem?.isShield == true { return false }
        }
        return true
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

                Text(L("selectEquipment"))
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
                        combatSectionLabel(L("meleeWeapons.label"))
                        ForEach(allItems.filter({ !$0.isShield && !$0.isRaufen }), id: \.name) { item in
                            equipmentRow(item)
                        }
                    }

                    if !hero.shields.isEmpty {
                        combatSectionLabel(L("shields.label"))
                        ForEach(allItems.filter(\.isShield), id: \.name) { item in
                            equipmentRow(item)
                        }
                    }

                    combatSectionLabel(L("unarmed.label"))
                    ForEach(allItems.filter(\.isRaufen), id: \.name) { item in
                        equipmentRow(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            // Continue button
            Button {
                applySelection()
                step = .root
            } label: {
                Text(L("continue"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selected.isEmpty ? Color.gray : combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
        }
        .onAppear { loadCurrentSelection() }
    }

    private func equipmentRow(_ item: (name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)) -> some View {
        let isSelected = selected.contains(item.name)
        let enabled = canSelect(item)
        return Button {
            if isSelected {
                selected.remove(item.name)
            } else {
                // Raufen and two-handed weapons clear everything else
                if item.isRaufen || item.isTwoHandedOnly {
                    selected.removeAll()
                }
                selected.insert(item.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(isSelected ? combatAccent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(.body, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(enabled ? .primary : .tertiary)
                    Text(item.detail)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(enabled ? .secondary : .tertiary)
                    if let note = item.note {
                        Text(note)
                            .font(.system(.caption2))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(isSelected ? combatAccent : Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.bottom, 4)
    }

    private func loadCurrentSelection() {
        selected.removeAll()
        if let name = hero.selectedWeaponName { selected.insert(name) }
        if let name = hero.selectedOffHandName { selected.insert(name) }
        // Legacy: also check selectedShieldName
        if let name = hero.selectedShieldName, !selected.contains(name) { selected.insert(name) }
    }

    private func applySelection() {
        let items = allItems
        let selectedItems = items.filter { selected.contains($0.name) }

        // Determine main weapon and off-hand
        let mainWeapon = selectedItems.first { !$0.isShield && !$0.isRaufen } ?? selectedItems.first { $0.isRaufen }
        let offHand = selectedItems.first { $0.name != mainWeapon?.name }

        hero.selectedWeaponName = mainWeapon?.name
        hero.selectedOffHandName = offHand?.name
        // Keep selectedShieldName in sync for backwards compat
        hero.selectedShieldName = offHand?.isShield == true ? offHand?.name : nil
    }
}
```

**Step 2: Add "shields.label" localization**

In Strings.swift, add to English section (near meleeWeapons.label):
```swift
"shields.label":        "SHIELDS",
```

In German section:
```swift
"shields.label":        "SCHILDE",
```

**Step 3: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: May still fail due to CombatRootView signature change — that's OK.

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift Hesindion/Theme/Strings.swift
git commit -m "feat: replace separate weapon/shield loadout with combined equipment selection"
```

---

### Task 5: Add CombatAttackChoiceView (pre-attack options)

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — add new view after `CombatLoadoutEquipmentView`

**Step 1: Add the attack choice view**

Insert after `CombatLoadoutEquipmentView`:

```swift
// MARK: - CombatAttackChoiceView

private struct CombatAttackChoiceView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    var onDismiss: () -> Void

    private var isDualWield: Bool { hero.isDualWielding }
    private var hasShield: Bool { hero.selectedShield != nil }

    /// Check if current weapon is eligible for two-handed grip.
    /// Not applicable to Dolche (CT_1) or Fechtwaffen (CT_3).
    private var canUseTwoHanded: Bool {
        guard !isDualWield, !hasShield else { return false }
        guard let w = hero.selectedWeapon else { return false }
        let excluded = ["CT_1", "CT_3"] // Dolche, Fechtwaffen
        return !excluded.contains(w.combatTechniqueId)
    }

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
                Text(L("attack"))
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
                VStack(spacing: 8) {
                    if isDualWield {
                        dualWieldOptions
                    } else if canUseTwoHanded {
                        gripOptions
                    } else {
                        // Weapon + shield or simple weapon: go directly to weapon selection or execution
                        // This view shouldn't be reached in this case — but handle gracefully
                        Color.clear.onAppear { proceedSingleAttack() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            Spacer()
        }
    }

    // MARK: - Dual-wield options

    private var dualWieldOptions: some View {
        VStack(spacing: 8) {
            combatSectionLabel(L("attack"))

            // Single weapon attack (no penalty)
            choiceButton(
                title: L("singleAttack"),
                subtitle: nil,
                icon: "1.circle.fill"
            ) {
                dualAttackPenaltyActive = false
                step = .weaponSelection(.angriff)
            }

            // Both weapons attack (with penalty)
            let penalty = hero.dualAttackPenalty
            let penaltyText = penalty == 0 ? nil : "\(penalty) AT, \(penalty) \(L("parry"))/\(L("dodge"))"
            choiceButton(
                title: L("dualAttack"),
                subtitle: penaltyText,
                icon: "2.circle.fill"
            ) {
                dualAttackPenaltyActive = true
                step = .weaponSelection(.angriff)
            }
        }
    }

    // MARK: - Grip options (single weapon, no shield)

    private var gripOptions: some View {
        VStack(spacing: 8) {
            combatSectionLabel(L("attack"))

            choiceButton(
                title: L("oneHanded"),
                subtitle: nil,
                icon: "hand.raised.fill"
            ) {
                twoHandedGripActive = false
                proceedSingleAttack()
            }

            choiceButton(
                title: L("twoHanded"),
                subtitle: nil,
                icon: "hands.clap.fill"
            ) {
                twoHandedGripActive = true
                proceedSingleAttack()
            }
        }
    }

    private func proceedSingleAttack() {
        if let w = hero.selectedWeapon {
            let pa = twoHandedGripActive ? -1 : 0 // PA penalty stored via twoHandedGripActive binding
            let damage = twoHandedGripActive ? adjustDamage(w.damage, bonus: 1) : w.damage
            step = .execution(.angriff, name: w.name, attributeValue: w.at, damageFormula: damage, note: nil)
        } else if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            step = .execution(.angriff, name: "Raufen", attributeValue: raufen?.at ?? 0, damageFormula: "1W6", note: nil)
        }
    }

    /// Adjusts a damage formula like "1W6+2" by adding a bonus.
    private func adjustDamage(_ formula: String, bonus: Int) -> String {
        let pattern = /^(\d+W\d+)([+-]\d+)?$/
        guard let match = formula.firstMatch(of: pattern) else { return formula }
        let base = String(match.1)
        let existing = match.2.flatMap { Int($0) } ?? 0
        let total = existing + bonus
        if total == 0 { return base }
        return total > 0 ? "\(base)+\(total)" : "\(base)\(total)"
    }

    private func choiceButton(title: String, subtitle: String?, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(combatAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: May still fail due to CombatRootView signature — that's next.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add pre-attack choice view for dual-wield and two-handed grip options"
```

---

### Task 6: Update CombatRootView for new bindings and styled loadout button

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — CombatRootView section (lines ~641-925)

**Step 1: Update CombatRootView signature**

Replace the CombatRootView struct declaration and properties:

```swift
private struct CombatRootView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var rolledInitiative: Int?
    @Binding var roundNumber: Int
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    var onDismiss: () -> Void

    @State private var showInitiativeSheet = false
    @State private var showArmorSheet = false
```

Note: `roundNumber` is now a binding from parent, not local `@State`.

**Step 2: Update Angriff button action**

Replace the Angriff button action (lines ~805-815):

```swift
Button {
    let isDualWield = hero.isDualWielding
    let hasShield = hero.selectedShield != nil
    let canTwoHand: Bool = {
        guard !isDualWield, !hasShield else { return false }
        guard let w = hero.selectedWeapon else { return false }
        let excluded = ["CT_1", "CT_3"]
        return !excluded.contains(w.combatTechniqueId)
    }()

    if isDualWield || canTwoHand {
        // Show attack choice (one/both weapons, or one-handed/two-handed)
        step = .attackChoice
    } else if hasShield {
        step = .weaponSelection(.angriff)
    } else if let w = hero.selectedWeapon {
        step = .execution(.angriff, name: w.name, attributeValue: w.at, damageFormula: w.damage, note: nil)
    } else if hero.selectedWeaponName == "Raufen" {
        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
        step = .execution(.angriff, name: "Raufen", attributeValue: raufen?.at ?? 0, damageFormula: "1W6", note: nil)
    } else {
        step = .attackChoice
    }
} label: {
```

**Step 3: Update Parieren button action**

Replace the Parieren button action (lines ~831-841):

```swift
Button {
    let isDualWield = hero.isDualWielding
    if isDualWield || hero.selectedShield != nil {
        step = .weaponSelection(.parieren)
    } else if let w = hero.selectedWeapon {
        let paValue = w.pa + hero.passiveShieldPABonus + (twoHandedGripActive ? -1 : 0) + (dualAttackPenaltyActive ? hero.dualAttackPenalty : 0)
        step = .execution(.parieren, name: w.name, attributeValue: paValue, damageFormula: nil, note: nil)
    } else if hero.selectedWeaponName == "Raufen" {
        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
        let paValue = (raufen?.pa ?? 0) + (dualAttackPenaltyActive ? hero.dualAttackPenalty : 0)
        step = .execution(.parieren, name: "Raufen", attributeValue: paValue, damageFormula: nil, note: nil)
    } else {
        step = .weaponSelection(.parieren)
    }
} label: {
```

**Step 4: Update Ausweichen to include dual-attack penalty**

```swift
Button {
    let aw = hero.derivedValues?.ausweichen.value ?? 0
    let penalty = dualAttackPenaltyActive ? hero.dualAttackPenalty : 0
    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw + penalty, damageFormula: nil, note: nil)
} label: {
```

**Step 5: Update loadout display to show off-hand**

Replace the loadout display section (lines ~778-798):

```swift
if let weaponName = hero.selectedWeaponName {
    HStack(spacing: 8) {
        Image(systemName: "hammer.fill")
            .font(.system(.caption, weight: .bold))
        Text(weaponName)
            .font(.system(.caption, design: .monospaced, weight: .black))
        if let offHandName = hero.selectedOffHandName {
            Text("+")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.secondary)
            let isShield = hero.selectedShield != nil
            Image(systemName: isShield ? "shield.fill" : "hammer.fill")
                .font(.system(.caption, weight: .bold))
            Text(offHandName)
                .font(.system(.caption, design: .monospaced, weight: .black))
        }
        Spacer()
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```

**Step 6: Restyle "Ausrüstung wechseln" button**

Replace the change loadout button (lines ~889-900):

```swift
// Change loadout — visually distinct (teal)
Button { step = .loadoutEquipment } label: {
    HStack(spacing: 6) {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(.body, weight: .bold))
        Text(L("changeLoadout"))
            .font(.system(.body, weight: .bold))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Color(red: 0x0d / 255, green: 0x96 / 255, blue: 0x88 / 255)) // teal
    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
}
.buttonStyle(.plain)
```

**Step 7: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (all views now exist)

**Step 8: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: update CombatRootView with dual-wield support and styled loadout button"
```

---

### Task 7: Update CombatWeaponSelectionView for dual-wield and parry weapon picking

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — CombatWeaponSelectionView section

**Step 1: Update CombatWeaponSelectionView to handle dual-wield**

Replace the entire `CombatWeaponSelectionView`:

```swift
// MARK: - CombatWeaponSelectionView

private struct CombatWeaponSelectionView: View {
    let action: CombatAction
    let hero: Hero
    @Binding var step: CombatStep
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    var onDismiss: () -> Void

    private var headerLabel: String {
        switch action {
        case .angriff: return L("attack")
        case .parieren: return L("selectParryWeapon")
        case .ausweichen: return L("dodge")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = dualAttackPenaltyActive && action == .angriff ? .attackChoice : .root } label: {
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
                    let dualPenalty = dualAttackPenaltyActive ? hero.dualAttackPenalty : 0

                    // Main weapon option
                    if let w = hero.selectedWeapon {
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? w.at : (w.pa + hero.passiveShieldPABonus)
                        let val = baseVal + dualPenalty + (action == .parieren && twoHandedGripActive ? -1 : 0)
                        weaponRow(
                            name: w.name,
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? w.damage : nil,
                            note: nil,
                            isOffHand: false
                        )
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? (raufen?.at ?? 0) : ((raufen?.pa ?? 0) + hero.passiveShieldPABonus)
                        let val = baseVal + dualPenalty
                        weaponRow(
                            name: "Raufen",
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? "1W6" : nil,
                            note: nil,
                            isOffHand: false
                        )
                    }

                    // Off-hand weapon (dual-wield)
                    if let offW = hero.selectedOffHandWeapon {
                        combatSectionLabel("\(L("offHandWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? offW.at : offW.pa
                        let val = baseVal + dualPenalty + hero.offHandPenalty
                        weaponRow(
                            name: offW.name,
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? offW.damage : nil,
                            note: hero.offHandPenalty != 0 ? "\(L("offHandPenalty")): \(hero.offHandPenalty)" : nil,
                            isOffHand: true
                        )
                    }

                    // Shield option
                    if let s = hero.selectedShield {
                        combatSectionLabel("\(L("shieldOption")) (\(statLabel))")
                        let val = action == .angriff ? s.at : s.pa
                        weaponRow(
                            name: s.name,
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? s.damage : nil,
                            note: action == .parieren && !s.note.isEmpty ? s.note : nil,
                            isOffHand: false
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func weaponRow(name: String, statLabel: String, statValue: Int, damageFormula: String?, note: String?, isOffHand: Bool) -> some View {
        Button {
            if dualAttackPenaltyActive && action == .angriff {
                // Dual-wield: first attack, then queue second
                let otherWeapon = isOffHand ? hero.selectedWeapon : hero.selectedOffHandWeapon
                let otherName = otherWeapon?.name ?? hero.selectedWeapon?.name ?? "?"
                let otherBaseAT = otherWeapon?.at ?? hero.selectedWeapon?.at ?? 0
                let otherPenalty = hero.dualAttackPenalty + (isOffHand ? 0 : hero.offHandPenalty)
                let otherDmg = otherWeapon?.damage ?? hero.selectedWeapon?.damage

                // Navigate to execution for first attack, with callback info for second
                step = .execution(
                    .angriff,
                    name: name,
                    attributeValue: statValue,
                    damageFormula: damageFormula,
                    note: dualAttackPenaltyActive ? L("dualAttackPenalty") : nil
                )
                // Store second attack info — we'll handle this via dualAttackSecond step
                // The execution view's "Neue Aktion" will be replaced with "Zweiter Angriff"
                // For now, we use a simple approach: after first attack, go to dualAttackSecond
                // This requires the execution view to know about dual attack state.
                // Simplified: we'll navigate to execution and handle second attack in the next task.
            } else {
                step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil, note: action == .parieren ? note : nil)
            }
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

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: update weapon selection view for dual-wield and off-hand display"
```

---

### Task 8: Add Vorteilhafte Position toggle to CombatExecutionView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — CombatExecutionView section

**Step 1: Add Vorteilhafte Position state and UI**

In `CombatExecutionView`, add a state variable after `modifier`:

```swift
@State private var vorteilhaftePosition: Bool = false
```

Update `effectiveValue` to include the bonus:

```swift
private var effectiveValue: Int { attributeValue + modifier + (vorteilhaftePosition ? 2 : 0) }
```

Add the Vorteilhafte Position toggle after the modifier box (after `modifierBox` in the VStack), before `diceBox`:

```swift
// Vorteilhafte Position toggle
Button {
    guard finalRoll == nil else { return }
    vorteilhaftePosition.toggle()
} label: {
    HStack(spacing: 8) {
        Image(systemName: vorteilhaftePosition ? "checkmark.square.fill" : "square")
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(vorteilhaftePosition ? combatAccent : .secondary)
        Text(L("advantageousPosition"))
            .font(.system(.caption, weight: .bold))
            .foregroundStyle(vorteilhaftePosition ? .primary : .secondary)
        Spacer()
        if vorteilhaftePosition {
            Text("+2")
                .font(.system(.caption, design: .monospaced, weight: .black))
                .foregroundStyle(combatAccent)
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(vorteilhaftePosition ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
    .overlay(Rectangle().stroke(vorteilhaftePosition ? combatAccent : Color.dsaBorder, lineWidth: vorteilhaftePosition ? 3 : 2))
}
.buttonStyle(.plain)
.disabled(finalRoll != nil)
```

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add Vorteilhafte Position toggle to combat execution pre-roll screen"
```

---

### Task 9: Handle dual-attack second strike flow

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` — CombatExecutionView and CombatWeaponSelectionView

**Step 1: Add dual-attack context to CombatExecutionView**

Add a new optional property to `CombatExecutionView`:

```swift
var secondAttackStep: CombatStep? = nil
```

Update the "Neue Aktion" button: when `secondAttackStep` is set and the first attack didn't fumble, show "Zweiter Angriff" instead:

In `showNeueAktion` and the button below it, replace the existing Neue Aktion button logic:

```swift
if showNeueAktion {
    if let secondStep = secondAttackStep, computedOutcome != .kritischerPatzer {
        // Second dual-wield attack
        Button { step = secondStep } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text(L("dualAttack") + " 2")
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
    } else if secondAttackStep != nil && computedOutcome == .kritischerPatzer {
        // Fumble — second attack lost
        Text(L("fumbleSecondLost"))
            .font(.system(.body, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dsaDark)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            .padding(.horizontal, 16)

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
```

**Step 2: Update CombatWeaponSelectionView to pass second attack info**

When `dualAttackPenaltyActive` and action is `.angriff`, compute the second weapon info and pass it through the execution step. Update the button action in `weaponRow`:

```swift
Button {
    if dualAttackPenaltyActive && action == .angriff {
        // Determine the other weapon for the second attack
        let otherWeapon: MeleeWeapon? = isOffHand ? hero.selectedWeapon : hero.selectedOffHandWeapon
        let otherName = otherWeapon?.name ?? "?"
        let otherBaseAT = otherWeapon?.at ?? 0
        let otherOffHandPenalty = isOffHand ? 0 : hero.offHandPenalty
        let otherAT = otherBaseAT + hero.dualAttackPenalty + otherOffHandPenalty
        let otherDmg = otherWeapon?.damage

        step = .execution(
            .angriff,
            name: name,
            attributeValue: statValue,
            damageFormula: damageFormula,
            note: nil
        )
        // We need to encode the second attack. Since CombatStep is an enum, we'll use dualAttackSecond.
        // But we can't set two steps at once. Instead, we'll need to wire secondAttackStep through.
        // Alternative: encode it directly in execution via the note field or a new enum case.
    } else {
        step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil, note: action == .parieren ? note : nil)
    }
}
```

**Note:** The dual-attack second-strike flow requires passing the second weapon's info from the weapon selection through to the execution view. The cleanest approach is to extend the `CombatStep.execution` case to include an optional `secondAttack` tuple, or use the existing `.dualAttackSecond` case.

**Refined approach:** Update `CombatStep.execution` to carry optional second-attack data:

```swift
case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?, secondAttack: (name: String, at: Int, damage: String?)? = nil)
```

Then in the orchestrator, when execution has secondAttack data, pass it to CombatExecutionView as `secondAttackStep`.

This task is complex — the implementer should wire the second-attack flow end-to-end, ensuring:
1. Weapon selection computes second weapon info
2. Execution view receives it and shows "Zweiter Angriff" button
3. Second execution view has no further second attack
4. Fumble on first attack shows "Patzer! Zweiter Angriff entfällt." and returns to root

**Step 3: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: implement dual-attack second strike flow with fumble handling"
```

---

### Task 10: Update CHANGELOG and architecture docs

**Files:**
- Modify: `CHANGELOG.md` — add entries under `[Unreleased]`
- Modify: `AGENT.md` — update combat system section if needed

**Step 1: Add changelog entries**

Under `[Unreleased]` → `### Added`:
- Combined equipment loadout view (weapons + shields in one screen)
- Dual-wielding support for heroes with Beidhändig (ADV_5) advantage
- Pre-attack choice: "Eine Waffe" vs "Beide Waffen" for dual-wield
- Two-handed grip option (+1 TP, −1 PA) for one-handed weapons
- Vorteilhafte Position per-roll toggle (+2 AT/PA/AW)
- Off-hand penalty display and calculation
- Dual-attack penalty tracking per combat round

Under `[Unreleased]` → `### Changed`:
- "Ausrüstung wechseln" button restyled with teal accent for better visibility
- Weapon and shield selection merged into single loadout step

**Step 2: Commit**

```bash
git add CHANGELOG.md AGENT.md
git commit -m "docs: update changelog and architecture for weapon switching and dual-wield"
```

---

### Task 11: Manual testing checklist

This task is not code — it's a verification checklist for the implementer to run through on the simulator:

1. **Basic loadout:** Open combat → select single weapon → continue → root shows weapon name
2. **Weapon + shield:** Select weapon + shield → root shows both → Angriff goes directly to weapon selection (weapon or shield)
3. **Dual-wield (Boronmir):** Select Rabenschnabel + Langschwert → root shows both weapons → Angriff shows "Eine Waffe" / "Beide Waffen" choice
4. **Single attack:** Choose "Eine Waffe" → pick weapon → normal roll, no penalty
5. **Dual attack:** Choose "Beide Waffen" → pick weapon → roll with penalty → "Zweiter Angriff" button → second weapon auto-rolls → back to root
6. **Fumble on first:** During dual attack, if roll is 20 and confirmed → "Patzer! Zweiter Angriff entfällt."
7. **Parry with dual-wield:** Tap Parieren → weapon picker (main or off-hand) → roll with correct penalties
8. **Ausweichen with dual penalty:** After dual attack in same round, dodge should show reduced AW
9. **Two-handed grip:** Single weapon, no shield → Angriff → "Einhändig" / "Zweihändig" choice → two-handed shows +1 in damage formula, -1 PA
10. **Vorteilhafte Position:** On any pre-roll screen, toggle checkbox → value changes by +2
11. **Change loadout:** Tap teal "Ausrüstung wechseln" → combined loadout view → re-pick → return to root
12. **Validation:** Try to pick 2 weapons without Beidhändig (use a hero without ADV_5) → second weapon should be disabled
13. **Raufen:** Select only Raufen → can't combine with other items
14. **Round reset:** Advance round → dual-attack penalty clears
