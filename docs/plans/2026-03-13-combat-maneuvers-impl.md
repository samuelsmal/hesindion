# Combat Maneuvers Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add combat maneuvers (Finte, Wuchtschlag, Vorstoß, Schildspalter, Sturmangriff), Schmerz auto-tracking, mounted combat, Plänkler-Formation, mount attacks, and Aufmerksamkeit reminder to the iDSACompanion app.

**Architecture:** Extend the Hero model with computed Schmerz and maneuver-awareness properties. Add two new combat steps (combatSetup, announcement) to the CombatStep state machine. Enhance the execution view with a modifier breakdown. Parse pet attacks at import time.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

**Design Doc:** `docs/plans/2026-03-13-combat-maneuvers-design.md`

---

### Task 1: Add Schmerz computed properties to Hero

**Files:**
- Modify: `Hesindion/Models/Hero.swift:96-199` (after existing computed properties)

**Step 1: Add Schmerz properties after the `offHandPenalty` property (line 193)**

```swift
// MARK: - Schmerz (Pain)

/// Raw Schmerz level from LP thresholds (0–4+).
var schmerzLevel: Int {
    guard let dv = derivedValues else { return 0 }
    let current = dv.lebensenergie.current
    let maxLP = dv.lebensenergie.max
    guard maxLP > 0 else { return 0 }
    var level = 0
    if current <= (maxLP * 3) / 4 { level = 1 }
    if current <= maxLP / 2 { level = 2 }
    if current <= maxLP / 4 { level = 3 }
    if current <= 5 { level += 1 }
    return level
}

/// True if hero has Zäher Hund (ADV_49).
var hasZaeherHund: Bool {
    advantages.contains { $0.ruleId == "ADV_49" }
}

/// Effective Schmerz after Zäher Hund reduction.
var effectiveSchmerzLevel: Int {
    let raw = schmerzLevel
    if raw >= 4 { return 4 }
    return hasZaeherHund ? max(0, raw - 1) : raw
}

/// Penalty from Schmerz, applied to all checks.
var schmerzPenalty: Int { -effectiveSchmerzLevel }
```

**Step 2: Add combat ability detection helpers**

```swift
// MARK: - Combat Ability Detection

var hasAufmerksamkeit: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_40" }
}

var hasGolgaritenStil: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_661" }
}

var hasBerittenerKampf: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_43" }
}

/// Finte tier (0 if not owned). SA_48.
var finteTier: Int {
    combatSpecialAbilities.first { $0.ruleId == "SA_48" }?.tier ?? 0
}

/// Wuchtschlag tier (0 if not owned). SA_67.
var wuchtschlagTier: Int {
    combatSpecialAbilities.first { $0.ruleId == "SA_67" }?.tier ?? 0
}

/// True if hero has Vorstoß (SA_66).
var hasVorstoss: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_66" }
}

/// True if hero has Schildspalter (SA_59).
var hasSchildspalter: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_59" }
}

/// True if hero has Plänkler-Formation (SA_884).
var hasPlaenklerFormation: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_884" }
}

/// Whether Golgariten-Stil conditions are met (mounted + Rabenschnabel + Großschild).
func golgaritenActive(mounted: Bool) -> Bool {
    guard mounted, hasGolgaritenStil else { return false }
    let hasRabenschnabel = selectedWeapon?.name == "Rabenschnabel"
    let hasGrossschild = selectedShield?.name == "Großschild"
    return hasRabenschnabel && hasGrossschild
}

/// Horse GS for Sturmangriff damage.
var mountGS: Int {
    pets.first?.speed ?? 0
}

/// Sturmangriff bonus damage: +2 + (horse GS / 2).
var sturmangriffDamageBonus: Int {
    2 + (mountGS / 2)
}

/// True if hero has a mount (pet with initiative).
var hasMount: Bool {
    pets.first.map { !$0.initiative.isEmpty } ?? false
}

/// Whether combat setup screen is needed.
var needsCombatSetup: Bool {
    hasPlaenklerFormation || hasMount
}
```

**Step 3: Build and verify no compiler errors**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add Hesindion/Models/Hero.swift
git commit -m "feat: add Schmerz and combat ability detection to Hero model"
```

---

### Task 2: Add PetAttack struct and parsing to Pet model

**Files:**
- Modify: `Hesindion/Models/Pet.swift:1-77`
- Modify: `Hesindion/Services/OptolithImportService.swift:734-774` (parsePets)

**Step 1: Add PetAttack struct and attacks property to Pet.swift**

After the `PetAttributes` struct (line 13), add:

```swift
struct PetAttack: Codable, Hashable {
    var name: String
    var at: Int
    var damage: String
    var reach: String
}
```

Add new fields to Pet class after `notes` (line 34):

```swift
var attacks: [PetAttack]
var specialSkills: String
```

Update the `init` to include the new fields (add parameters and assignments):

```swift
attacks: [PetAttack] = [],
specialSkills: String = ""
```

**Step 2: Add pet attack parsing method to OptolithImportService**

Add after the `parsePets` method:

```swift
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
```

Update `parsePets` to use it — in the Pet init call, add:

```swift
attacks: parsePetAttacks(notes: pet["notes"] as? String ?? ""),
specialSkills: pet["skills"] as? String ?? ""
```

Remove the old `skills` parameter assignment and keep the `skills` field for backward compat, or remove it entirely if `specialSkills` replaces it. Since `skills` is already used, rename is simpler: keep `skills` stored property but also populate `attacks` and `specialSkills`.

Actually, simplest: keep `skills` as-is (stored property), add `attacks` and `specialSkills` as new fields. `specialSkills` is just a copy of `skills` for display clarity.

**Step 3: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add Hesindion/Models/Pet.swift Hesindion/Services/OptolithImportService.swift
git commit -m "feat: add PetAttack struct and parse mount attacks from notes"
```

---

### Task 3: Add localization strings for combat maneuvers

**Files:**
- Modify: `Hesindion/Theme/Strings.swift:17-431`

**Step 1: Add new keys to both `englishFallback` and `translations` dictionaries**

Add to `englishFallback` (after the combat section ~line 130):

```swift
// Combat Maneuvers
"combatSetup":          "Combat Setup",
"combatSetup.label":    "COMBAT SETUP",
"formation.label":      "FORMATION",
"mount.label":          "MOUNT",
"mounted":              "Mounted",
"announcement":         "Announcement",
"announcement.label":   "MANEUVER",
"maneuver.normal":      "Normal",
"maneuver.finte":       "Feint",
"maneuver.wuchtschlag": "Powerful Blow",
"maneuver.vorstoss":    "Thrust",
"maneuver.schildspalter":"Shield Splitter",
"maneuver.sturmangriff":"Mounted Charge",
"plaenkler":            "Skirmisher Formation",
"plaenklerAT":          "+1 AT",
"plaenklerAW":          "+1 Dodge",
"noDefenseWarning":     "No defense this round!",
"opponentPA":           "Opponent PA",
"damageBonus":          "Damage",
"targetShield":         "Damage targets shield SP",
"calculation.label":    "CALCULATION",
"additional.label":     "ADDITIONAL",
"source.basis":         "Base",
"source.belastung":     "Encumbrance",
"source.schmerz":       "Pain",
"source.vorteilhaft":   "Adv. Position",
"source.golgariten":    "Golgariten",
"source.plaenkler":     "Skirmisher",
"source.finte":         "Feint",
"source.wuchtschlag":   "Powerful Blow",
"source.vorstoss":      "Thrust",
"source.sturmangriff":  "Mounted Charge",
"source.dualAttack":    "Dual-attack",
"source.offHand":       "Off-hand",
"source.additional":    "Additional",
"source.mounted":       "Mounted",
"source.shield":        "Shield",
"mountAttacks.label":   "MOUNT ATTACKS",
"aufmerksamkeitHint":   "Aufmerksamkeit: +2 to avoid surprise",
"schmerz.label":        "Pain",
"schmerz.none":         "No pain",
"schmerz.I":            "Pain I",
"schmerz.II":           "Pain II",
"schmerz.III":          "Pain III",
"schmerz.IV":           "Incapacitated",
"chargeBonus":          "Charge bonus",
```

Add to `translations` (matching position):

```swift
// Combat Maneuvers
"combatSetup":          "Kampfvorbereitung",
"combatSetup.label":    "KAMPFVORBEREITUNG",
"formation.label":      "FORMATION",
"mount.label":          "REITTIER",
"mounted":              "Beritten",
"announcement":         "Ansage",
"announcement.label":   "MANÖVER",
"maneuver.normal":      "Normal",
"maneuver.finte":       "Finte",
"maneuver.wuchtschlag": "Wuchtschlag",
"maneuver.vorstoss":    "Vorstoß",
"maneuver.schildspalter":"Schildspalter",
"maneuver.sturmangriff":"Sturmangriff",
"plaenkler":            "Plänkler-Formation",
"plaenklerAT":          "+1 AT",
"plaenklerAW":          "+1 AW",
"noDefenseWarning":     "Keine Verteidigung diese Runde!",
"opponentPA":           "Gegner PA",
"damageBonus":          "Schaden",
"targetShield":         "Schaden gegen Schild-SP",
"calculation.label":    "BERECHNUNG",
"additional.label":     "ZUSÄTZLICH",
"source.basis":         "Basis",
"source.belastung":     "Belastung",
"source.schmerz":       "Schmerz",
"source.vorteilhaft":   "Vorteilh. Pos.",
"source.golgariten":    "Golgariten",
"source.plaenkler":     "Plänkler",
"source.finte":         "Finte",
"source.wuchtschlag":   "Wuchtschlag",
"source.vorstoss":      "Vorstoß",
"source.sturmangriff":  "Sturmangriff",
"source.dualAttack":    "Beidhändig",
"source.offHand":       "Nebenhand",
"source.additional":    "Zusätzlich",
"source.mounted":       "Beritten",
"source.shield":        "Schild",
"mountAttacks.label":   "REITTIER-ANGRIFFE",
"aufmerksamkeitHint":   "Aufmerksamkeit: +2 auf Überraschung vermeiden",
"schmerz.label":        "Schmerz",
"schmerz.none":         "Kein Schmerz",
"schmerz.I":            "Schmerz I",
"schmerz.II":           "Schmerz II",
"schmerz.III":          "Schmerz III",
"schmerz.IV":           "Handlungsunfähig",
"chargeBonus":          "Sturmangriffsbonus",
```

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add localization strings for combat maneuvers and Schmerz"
```

---

### Task 4: Add CombatManeuver enum and ModifierLine struct

**Files:**
- Create: `Hesindion/Models/CombatManeuver.swift`

**Step 1: Create the file**

```swift
import Foundation

// MARK: - Combat Maneuver

enum CombatManeuver: Equatable, Hashable {
    case normal
    case finte(tier: Int)
    case wuchtschlag(tier: Int)
    case vorstoss
    case schildspalter
    case sturmangriff
}

extension CombatManeuver {
    /// AT modifier from this maneuver.
    var atModifier: Int {
        switch self {
        case .normal: return 0
        case .finte(let tier): return -tier
        case .wuchtschlag(let tier): return -(tier * 2)
        case .vorstoss: return 2
        case .schildspalter: return 0
        case .sturmangriff: return 0
        }
    }

    /// Extra damage from this maneuver.
    var damageBonus: Int {
        switch self {
        case .wuchtschlag(let tier): return tier * 2
        default: return 0
        }
    }

    /// Whether this maneuver prevents defense actions this round.
    var preventsDefense: Bool {
        switch self {
        case .vorstoss: return true
        default: return false
        }
    }

    /// Localized display name.
    var displayName: String {
        switch self {
        case .normal: return L("maneuver.normal")
        case .finte: return L("maneuver.finte")
        case .wuchtschlag: return L("maneuver.wuchtschlag")
        case .vorstoss: return L("maneuver.vorstoss")
        case .schildspalter: return L("maneuver.schildspalter")
        case .sturmangriff: return L("maneuver.sturmangriff")
        }
    }

    /// Localized source label for modifier breakdown.
    var sourceLabel: String {
        switch self {
        case .normal: return ""
        case .finte: return L("source.finte")
        case .wuchtschlag: return L("source.wuchtschlag")
        case .vorstoss: return L("source.vorstoss")
        case .schildspalter: return ""
        case .sturmangriff: return L("source.sturmangriff")
        }
    }

    /// Info text shown to player (e.g. "Opponent PA -2").
    func infoText(tier: Int = 1) -> String? {
        switch self {
        case .finte(let t):
            return "\(L("opponentPA")) -\(t * 2)"
        case .wuchtschlag(let t):
            return "\(L("damageBonus")) +\(t * 2)"
        case .vorstoss:
            return "⚠ \(L("noDefenseWarning"))"
        case .schildspalter:
            return L("targetShield")
        default:
            return nil
        }
    }
}

// MARK: - Plänkler Bonus

enum PlaenklerBonus: String, CaseIterable {
    case at
    case aw
}

// MARK: - Modifier Line

struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add Hesindion/Models/CombatManeuver.swift
git commit -m "feat: add CombatManeuver enum, PlaenklerBonus, and ModifierLine"
```

---

### Task 5: Add CombatSetup step and view

**Files:**
- Modify: `Hesindion/Views/CombatView.swift:9-19` (CombatStep enum)
- Modify: `Hesindion/Views/CombatView.swift:42-165` (CombatView body + state)

**Step 1: Add combatSetup to CombatStep enum (after armorSelection, line 10)**

```swift
case combatSetup
```

Add to stepID (after armorSelection case):

```swift
case .combatSetup: "combatSetup"
```

**Step 2: Add state variables to CombatView (after line 49)**

```swift
@State private var plaenklerActive: Bool = false
@State private var plaenklerBonus: PlaenklerBonus = .at
@State private var mountedActive: Bool = false
@State private var vorstossActiveThisRound: Bool = false
@State private var activeManeuver: CombatManeuver = .normal
```

**Step 3: Add combatSetup case to the body switch (after armorSelection)**

```swift
case .combatSetup:
    CombatSetupView(
        hero: hero,
        step: $step,
        plaenklerActive: $plaenklerActive,
        plaenklerBonus: $plaenklerBonus,
        mountedActive: $mountedActive,
        onDismiss: onDismiss
    )
    .transition(.move(edge: .trailing))
```

**Step 4: Update armorSelection continue to go to combatSetup if needed**

In `CombatArmorSelectionView`, change the continue button action (line 248):

```swift
Button { step = hero.needsCombatSetup ? .combatSetup : .initiativeRoll } label: {
```

**Step 5: Add combatSetup to swipe-back gesture (after armorSelection case in DragGesture)**

```swift
case .combatSetup:
    step = .armorSelection
```

**Step 6: Update initiative view back button to go to combatSetup if applicable**

In `CombatInitiativeRollView`, change the back button (line 690):

```swift
Button { step = hero.needsCombatSetup ? .combatSetup : .armorSelection } label: {
```

**Step 7: Reset Vorstoß and maneuver each round**

In `onChange(of: roundNumber)` (line 160), add:

```swift
vorstossActiveThisRound = false
activeManeuver = .normal
```

**Step 8: Write CombatSetupView (add before CombatArmorSelectionView)**

```swift
// MARK: - CombatSetupView

private struct CombatSetupView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var plaenklerActive: Bool
    @Binding var plaenklerBonus: PlaenklerBonus
    @Binding var mountedActive: Bool
    var onDismiss: () -> Void

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
                Text(L("combatSetup"))
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
                    // Plänkler-Formation
                    if hero.hasPlaenklerFormation {
                        combatSectionLabel(L("formation.label"))

                        Button { plaenklerActive.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: plaenklerActive ? "checkmark.square.fill" : "square")
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(plaenklerActive ? combatAccent : .secondary)
                                Text(L("plaenkler"))
                                    .font(.system(.body, weight: plaenklerActive ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(plaenklerActive ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(plaenklerActive ? combatAccent : Color.dsaBorder, lineWidth: plaenklerActive ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        if plaenklerActive {
                            HStack(spacing: 8) {
                                ForEach(PlaenklerBonus.allCases, id: \.self) { bonus in
                                    let isSelected = plaenklerBonus == bonus
                                    Button { plaenklerBonus = bonus } label: {
                                        Text(bonus == .at ? L("plaenklerAT") : L("plaenklerAW"))
                                            .font(.system(.caption, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }

                    // Mount toggle
                    if hero.hasMount {
                        combatSectionLabel(L("mount.label"))

                        let mountName = hero.pets.first?.name ?? L("mount")
                        Button { mountedActive.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mountedActive ? "checkmark.square.fill" : "square")
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(mountedActive ? combatAccent : .secondary)
                                Text("\(L("mounted")) (\(mountName))")
                                    .font(.system(.body, weight: mountedActive ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(mountedActive ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(mountedActive ? combatAccent : Color.dsaBorder, lineWidth: mountedActive ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }

            // Continue
            Button { step = .initiativeRoll } label: {
                Text(L("continue"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
    }
}
```

**Step 9: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 10: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add combat setup step with Plänkler and mounted toggles"
```

---

### Task 6: Add Announcement step and view

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

**Step 1: Add announcement case to CombatStep**

```swift
case announcement(CombatAction, name: String, baseAT: Int, damageFormula: String?, isOffHand: Bool)
```

Add to stepID:
```swift
case .announcement: "announcement"
```

**Step 2: Add CombatAnnouncementView body case in CombatView**

```swift
case .announcement(let action, let name, let baseAT, let dmgFormula, let isOffHand):
    CombatAnnouncementView(
        hero: hero,
        action: action,
        weaponName: name,
        baseAT: baseAT,
        damageFormula: dmgFormula,
        isOffHand: isOffHand,
        mountedActive: mountedActive,
        step: $step,
        activeManeuver: $activeManeuver,
        vorstossActiveThisRound: $vorstossActiveThisRound,
        dualAttackPenaltyActive: dualAttackPenaltyActive,
        twoHandedGripActive: twoHandedGripActive,
        plaenklerActive: plaenklerActive,
        plaenklerBonus: plaenklerBonus,
        onDismiss: onDismiss
    )
    .transition(.move(edge: .trailing))
```

**Step 3: Update weapon selection and attack choice to route to announcement instead of execution**

In `CombatWeaponSelectionView.weaponRow`, change the button action to navigate to `.announcement` instead of `.execution`. The announcement view will then build the full modifier list and navigate to execution.

In `CombatAttackChoiceView.proceedSingleAttack`, route to `.announcement` instead of `.execution`.

In `CombatRootView`, update the direct-to-execution paths (single weapon, no shield, no dual-wield cases around lines 1026-1035) to route through `.announcement`.

**Step 4: Write CombatAnnouncementView**

This view shows:
1. Vorteilhafte Position toggle (or auto-on label if Golgariten mounted)
2. Maneuver radio group (Normal + available maneuvers from hero)
3. Continue button that builds ModifierLines and navigates to execution

```swift
// MARK: - CombatAnnouncementView

private struct CombatAnnouncementView: View {
    let hero: Hero
    let action: CombatAction
    let weaponName: String
    let baseAT: Int
    let damageFormula: String?
    let isOffHand: Bool
    let mountedActive: Bool
    @Binding var step: CombatStep
    @Binding var activeManeuver: CombatManeuver
    @Binding var vorstossActiveThisRound: Bool
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    var onDismiss: () -> Void

    @State private var vorteilhaftePosition: Bool = false
    @State private var selectedManeuver: CombatManeuver = .normal

    private var golgaritenForced: Bool {
        hero.golgaritenActive(mounted: mountedActive)
    }

    private var availableManeuvers: [CombatManeuver] {
        var maneuvers: [CombatManeuver] = [.normal]
        if hero.finteTier > 0 { maneuvers.append(.finte(tier: hero.finteTier)) }
        if hero.wuchtschlagTier > 0 { maneuvers.append(.wuchtschlag(tier: hero.wuchtschlagTier)) }
        if hero.hasVorstoss { maneuvers.append(.vorstoss) }
        if hero.hasSchildspalter { maneuvers.append(.schildspalter) }
        if mountedActive && hero.hasBerittenerKampf { maneuvers.append(.sturmangriff) }
        return maneuvers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .weaponSelection(action) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 1) {
                    Text(L("announcement"))
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(.white)
                    Text(weaponName)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
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
                    // Vorteilhafte Position
                    if golgaritenForced {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.square.fill")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(combatAccent)
                            Text("\(L("advantageousPosition")) (\(L("mounted")))")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("+2")
                                .font(.system(.caption, design: .monospaced, weight: .black))
                                .foregroundStyle(combatAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(combatAccent.opacity(0.1))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                    } else {
                        Button {
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
                    }

                    // Maneuver selection
                    combatSectionLabel(L("announcement.label"))

                    ForEach(availableManeuvers, id: \.self) { maneuver in
                        let isSelected = selectedManeuver == maneuver
                        Button { selectedManeuver = maneuver } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(isSelected ? combatAccent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(maneuver.displayName)
                                            .font(.system(.body, weight: isSelected ? .bold : .regular))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if maneuver.atModifier != 0 {
                                            Text("AT \(maneuver.atModifier > 0 ? "+" : "")\(maneuver.atModifier)")
                                                .font(.system(.caption, design: .monospaced, weight: .black))
                                                .foregroundStyle(maneuver.atModifier > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : .groupCombat)
                                        }
                                    }
                                    if let info = maneuver.infoText() {
                                        Text(info)
                                            .font(.system(.caption2, weight: .medium))
                                            .foregroundStyle(maneuver.preventsDefense ? .groupCombat : .secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(isSelected ? combatAccent : Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Continue
            Button { proceed() } label: {
                Text(L("continue"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
    }

    private func proceed() {
        activeManeuver = selectedManeuver
        if selectedManeuver.preventsDefense {
            vorstossActiveThisRound = true
        }

        // Build modifier lines and effective value, then navigate to execution
        let modifiers = buildModifierLines()
        let effectiveAT = baseAT + modifiers.reduce(0) { $0 + $1.value }
        let effectiveDamage = adjustedDamage()
        let note = selectedManeuver.infoText()

        step = .execution(
            action,
            name: weaponName,
            attributeValue: effectiveAT,
            damageFormula: effectiveDamage,
            note: note
        )
    }

    private func buildModifierLines() -> [ModifierLine] {
        var lines: [ModifierLine] = []

        // Belastung
        let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
        if be > 0 { lines.append(ModifierLine(value: -be, source: L("source.belastung"))) }

        // Schmerz
        if hero.schmerzPenalty != 0 {
            let level = hero.effectiveSchmerzLevel
            lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
        }

        // Vorteilhafte Position
        if golgaritenForced || vorteilhaftePosition {
            lines.append(ModifierLine(value: 2, source: L("source.vorteilhaft")))
        }

        // Golgariten extra
        if golgaritenForced {
            lines.append(ModifierLine(value: 2, source: L("source.golgariten")))
        }

        // Plänkler
        if plaenklerActive && plaenklerBonus == .at {
            lines.append(ModifierLine(value: 1, source: L("source.plaenkler")))
        }

        // Maneuver AT modifier
        if selectedManeuver.atModifier != 0 {
            lines.append(ModifierLine(value: selectedManeuver.atModifier, source: selectedManeuver.sourceLabel))
        }

        // Dual-attack penalty
        if dualAttackPenaltyActive {
            let penalty = hero.dualAttackPenalty
            if penalty != 0 { lines.append(ModifierLine(value: penalty, source: L("source.dualAttack"))) }
        }

        // Off-hand penalty
        if isOffHand && hero.offHandPenalty != 0 {
            lines.append(ModifierLine(value: hero.offHandPenalty, source: L("source.offHand")))
        }

        return lines
    }

    private func adjustedDamage() -> String? {
        guard var formula = damageFormula else { return nil }
        var bonus = selectedManeuver.damageBonus
        if twoHandedGripActive { bonus += 1 }
        if selectedManeuver == .sturmangriff { bonus += hero.sturmangriffDamageBonus }
        if bonus == 0 { return formula }
        // Adjust formula
        let pattern = /^(\d+W\d+)([+-]\d+)?$/
        guard let match = formula.firstMatch(of: pattern) else { return formula }
        let base = String(match.1)
        let existing = match.2.flatMap { Int($0) } ?? 0
        let total = existing + bonus
        if total == 0 { return base }
        return total > 0 ? "\(base)+\(total)" : "\(base)\(total)"
    }
}
```

**Step 5: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add announcement step with maneuver selection"
```

---

### Task 7: Enhance execution view with modifier breakdown

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatExecutionView)

**Step 1: Pass modifier lines to execution view**

Update `CombatStep.execution` to include modifier lines:

```swift
case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?, modifierLines: [ModifierLine]? = nil, secondAttack: (name: String, at: Int, damage: String?)? = nil)
```

**Step 2: Add modifierLines property to CombatExecutionView**

```swift
let modifierLines: [ModifierLine]?
```

**Step 3: Replace the single `valueBox` + `modifierBox` with modifier breakdown**

Remove the Vorteilhafte Position toggle (moved to announcement).

Replace the existing AT/PA display + modifier section with:

```swift
// Modifier breakdown
if let lines = modifierLines, !lines.isEmpty {
    VStack(spacing: 0) {
        combatSectionLabel(L("calculation.label"))

        // Base value
        HStack {
            Text("\(attrLabel) \(attributeValue - lines.reduce(0) { $0 + $1.value } - modifier)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
            Spacer()
            Text(L("source.basis"))
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))

        // Modifier lines
        ForEach(lines) { line in
            HStack {
                Text(line.value > 0 ? "+\(line.value)" : "\(line.value)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(line.value > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : .groupCombat)
                Spacer()
                Text(line.source)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
        }

        // Manual modifier (if non-zero)
        if modifier != 0 {
            HStack {
                Text(modifier > 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(modifier > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : .groupCombat)
                Spacer()
                Text(L("source.additional"))
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
        }

        // Effective total
        HStack {
            Text("\(attrLabel) \(effectiveValue)")
                .font(.system(.body, design: .monospaced, weight: .black))
            Spacer()
            Text("Effektiv")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.dsaDark)
        .foregroundStyle(.white)
    }
} else {
    // Fallback: simple display (for defense/dodge without full breakdown)
    valueBox("\(attributeValue)", label: attrLabel)
}
```

Keep the manual modifier stepper below the breakdown, labeled "ZUSÄTZLICH".

**Step 4: Update effectiveValue computation**

The `effectiveValue` should now be: `attributeValue + modifier` (the attributeValue already includes announcement modifiers).

Remove the `vorteilhaftePosition` state and its effect on `effectiveValue` since it's handled upstream.

**Step 5: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add modifier breakdown to combat execution view"
```

---

### Task 8: Add Vorstoß defense lock and mount attacks to CombatRootView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatRootView)

**Step 1: Pass vorstossActiveThisRound and mountedActive to CombatRootView**

Add bindings:
```swift
@Binding var vorstossActiveThisRound: Bool
let mountedActive: Bool
```

**Step 2: Disable Parieren and Ausweichen when Vorstoß active**

Wrap the Parieren and Ausweichen buttons with `.disabled(vorstossActiveThisRound)` and change their background to `Color.gray` when disabled. Add a note below: `L("noDefenseWarning")`.

**Step 3: Add mount attacks section**

When `mountedActive`, add below the existing action buttons:

```swift
if mountedActive, let mount = hero.pets.first {
    combatSectionLabel(L("mountAttacks.label"))

    ForEach(mount.attacks, id: \.name) { attack in
        Button {
            step = .execution(.angriff, name: "\(mount.name): \(attack.name)", attributeValue: attack.at, damageFormula: attack.damage, note: nil)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attack.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("TP \(attack.damage) · RW \(attack.reach)")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("AT \(attack.at)")
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.dsaDark)
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

    if !mount.specialSkills.isEmpty {
        Text("ⓘ \(mount.specialSkills)")
            .font(.system(.caption2, weight: .medium))
            .foregroundStyle(combatAccent)
            .padding(.horizontal, 16)
            .padding(.top, 2)
    }
}
```

**Step 4: Add Schmerz indicator next to LP bar**

After the `lpBar` in CombatRootView, add:

```swift
if hero.effectiveSchmerzLevel > 0 {
    let level = hero.effectiveSchmerzLevel
    let label = level >= 4 ? L("schmerz.IV") : L("schmerz.\(String(repeating: "I", count: level))")
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(.caption, weight: .bold))
        Text("\(label) (\(hero.schmerzPenalty))")
            .font(.system(.caption, design: .monospaced, weight: .black))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.groupCombat)
    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    .padding(.horizontal, 16)
    .padding(.top, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

**Step 5: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add Vorstoß defense lock, mount attacks, and Schmerz indicator"
```

---

### Task 9: Add Schmerz penalty and Aufmerksamkeit hint to TalentProbeModal

**Files:**
- Modify: `Hesindion/Views/TalentProbeModal.swift:1-282`

**Step 1: Add Schmerz penalty display after modifier boxes (line 90)**

After the modifier boxes HStack and before the dice row, insert:

```swift
// Schmerz penalty
if hero.schmerzPenalty != 0 {
    let level = hero.effectiveSchmerzLevel
    let label = level >= 4 ? L("schmerz.IV") : L("schmerz.\(String(repeating: "I", count: level))")
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(.groupCombat)
        Text("\(label): \(hero.schmerzPenalty) \(L("source.schmerz"))")
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(.groupCombat)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.groupCombat.opacity(0.1))
    .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
}
```

**Step 2: Apply Schmerz to attribute checks**

In `computeResult` (line 223), add schmerzPenalty to each modifier:

```swift
let schmerzMod = hero.schmerzPenalty
for i in 0..<3 {
    let excess = rolls[i] - (attrValues[i] + mods[i] + schmerzMod)
    if excess > 0 { remaining -= excess }
}
```

Also update `summaryText` (line 189) and `resultBox` (line 102) to use the same adjusted values.

**Step 3: Add Aufmerksamkeit hint for Sinnenschärfe**

After the Schmerz display, add:

```swift
// Aufmerksamkeit hint
if hero.hasAufmerksamkeit && talent.ruleId == "TAL_8" {
    HStack(spacing: 8) {
        Image(systemName: "info.circle.fill")
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(Color.groupPersonalData)
        Text(L("aufmerksamkeitHint"))
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(Color.groupPersonalData)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.groupPersonalData.opacity(0.1))
    .overlay(Rectangle().stroke(Color.groupPersonalData, lineWidth: 2))
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add Hesindion/Views/TalentProbeModal.swift
git commit -m "feat: add Schmerz penalty and Aufmerksamkeit hint to talent probes"
```

---

### Task 10: Wire defense modifier breakdown (PA/AW)

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatRootView defense actions)

**Step 1: Build PA/AW modifier lines when navigating to execution for defense**

When the Parieren or Ausweichen button is tapped, build modifier lines:

```swift
func buildDefenseModifiers(isAusweichen: Bool) -> [ModifierLine] {
    var lines: [ModifierLine] = []

    let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
    if be > 0 { lines.append(ModifierLine(value: -be, source: L("source.belastung"))) }

    if hero.schmerzPenalty != 0 {
        let level = hero.effectiveSchmerzLevel
        lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
    }

    if !isAusweichen && hero.golgaritenActive(mounted: mountedActive) {
        lines.append(ModifierLine(value: 1, source: L("source.golgariten")))
    }

    if isAusweichen && plaenklerActive && plaenklerBonus == .aw {
        lines.append(ModifierLine(value: 1, source: L("source.plaenkler")))
    }

    if isAusweichen && mountedActive {
        lines.append(ModifierLine(value: -2, source: L("source.mounted")))
    }

    if dualAttackPenaltyActive {
        let penalty = hero.dualAttackPenalty
        if penalty != 0 { lines.append(ModifierLine(value: penalty, source: L("source.dualAttack"))) }
    }

    return lines
}
```

Pass these modifier lines to the `.execution` step when navigating for Parieren/Ausweichen.

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add modifier breakdown for defense actions (PA/AW)"
```

---

### Task 11: Disable two-handed weapons in loadout when mounted

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatLoadoutEquipmentView)

**Step 1: Pass mountedActive to CombatLoadoutEquipmentView**

Add `let mountedActive: Bool` property.

**Step 2: Disable two-handed items when mounted**

In `canSelect`, when `mountedActive && item.isTwoHandedOnly`, return `false`.

In `equipmentRow`, show a "(Beritten)" note for disabled two-handed items.

**Step 3: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: disable two-handed weapons in loadout when mounted"
```

---

### Task 12: Update initiative auto-selection for mounted combat

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatInitiativeRollView)

**Step 1: Pass mountedActive to CombatInitiativeRollView**

When `mountedActive` is true, auto-select the mount INI base if available.

In the view's `onAppear`, if `mountedActive` and `mountBaseINI` exists, set `selectedBase = mountBaseINI` and start animation.

**Step 2: Build and verify**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: auto-select mount initiative when mounted"
```

---

### Task 13: Final build and integration test

**Step 1: Full clean build**

Run: `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator clean build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`

**Step 2: Manual verification checklist**

- [ ] Import Boronmir and enter combat
- [ ] Combat setup shows Plänkler-Formation and Beritten toggles
- [ ] Initiative auto-selects mount base when mounted
- [ ] Two-handed weapons disabled in loadout when mounted
- [ ] Attack flow goes through announcement screen
- [ ] Finte, Wuchtschlag, Vorstoß, Schildspalter appear as options
- [ ] Sturmangriff appears only when mounted
- [ ] Modifier breakdown shows in execution view
- [ ] Vorstoß disables Parieren/Ausweichen
- [ ] Mount attacks (Tritt, Biss, Niederreiten) appear when mounted
- [ ] Schmerz indicator shows when LP drops below thresholds
- [ ] Zäher Hund reduces effective Schmerz
- [ ] Talent probe shows Schmerz penalty
- [ ] Sinnenschärfe probe shows Aufmerksamkeit hint
- [ ] Golgariten-Stil forces Vorteilhafte Position when mounted + Rabenschnabel + Großschild

**Step 3: Commit any fixups and update CHANGELOG**

```bash
git add -A
git commit -m "docs: update CHANGELOG for combat maneuvers feature"
```
