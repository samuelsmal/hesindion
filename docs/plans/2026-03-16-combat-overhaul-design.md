# Combat System Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Overhaul the combat system to fully implement DSA 5 Kodex des Schwertes Chapter 3 rules, including opponent defense, Schicksalspunkte, Patzertabellen, weapon reach, Fernkampf, Flucht/Passierschlag, combat session persistence, and comprehensive logging.

**Architecture:** CombatView remains the full-screen orchestrator driven by the `CombatStep` enum. New steps are added for opponent defense, fumble choice, Fernkampf setup/execution, Passierschlag, and Flucht. Combat state is persisted on `Hero` so exiting/re-entering mid-combat resumes rather than restarting. All combat actions are logged to `LogEntry` with `CombatActionPayload`.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+, no external dependencies.

**Rules Reference:** Kodex des Schwertes, Chapter 3 (pp. 61-85). All DSA 5 rules at https://dsa.ulisses-regelwiki.de/

---

## Task 0.5: Split CombatView.swift into Focused Files

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (keep orchestrator only)
- Create: `Hesindion/Views/CombatSetupViews.swift`
- Create: `Hesindion/Views/CombatRootView.swift`
- Create: `Hesindion/Views/CombatAttackViews.swift`
- Create: `Hesindion/Views/CombatExecutionView.swift`
- Create: `Hesindion/Views/CombatDamageViews.swift`

**Pure move refactor — no logic changes.**

Split the ~39K token monolith:

| File | Contents |
|---|---|
| `CombatView.swift` | CombatStep enum, CombatAction enum, combatAccent, combatSectionLabel(), CombatView struct |
| `CombatSetupViews.swift` | CombatArmorSelectionView, CombatSetupView, CombatInitiativeRollView, CombatLoadoutEquipmentView |
| `CombatRootView.swift` | CombatRootView, CombatArmorManagementSheet, CombatInitiativeSheet, LPBarView |
| `CombatAttackViews.swift` | CombatAttackChoiceView, CombatAnnouncementView, CombatWeaponSelectionView |
| `CombatExecutionView.swift` | CombatExecutionView |
| `CombatDamageViews.swift` | CombatTakeDamageView, CombatMountDamageView, CombatMountPreCheckView |

New overhaul views go into:
| `CombatDefenseViews.swift` | CombatOpponentDefenseView, CombatFumbleChoiceView, CombatPassierschlagView, CombatFluchtView |
| `CombatFernkampfViews.swift` | CombatFernkampfSetupView, CombatFernkampfExecutionView |

Key: Remove `private` from all extracted structs/functions. Keep shared types (CombatStep, CombatAction, combatAccent, combatSectionLabel) in CombatView.swift.

---

## Task 0: Data Model — New Types & Enums

**Files:**
- Modify: `Hesindion/Models/CombatManeuver.swift`
- Modify: `Hesindion/Models/LogEntry.swift`
- Create: `Hesindion/Models/FumbleTable.swift`

**Step 1: Add weapon reach enum and opponent reach support**

In `Hesindion/Models/CombatManeuver.swift`, add:

```swift
// MARK: - Weapon Reach

enum WeaponReach: String, CaseIterable {
    case kurz = "Kurz"
    case mittel = "Mittel"
    case lang = "Lang"

    /// AT penalty when attacking an opponent with the given reach.
    func atPenaltyAgainst(_ opponent: WeaponReach) -> Int {
        switch (self, opponent) {
        case (.kurz, .mittel): return -2
        case (.kurz, .lang):   return -4
        case (.mittel, .lang): return -2
        default:               return 0
        }
    }

    /// AT/PA penalty for beengte Umgebung.
    var beengteUmgebungPenalty: Int {
        switch self {
        case .kurz:  return 0
        case .mittel: return -4
        case .lang:  return -8
        }
    }
}
```

**Step 2: Add fumble table model**

Create `Hesindion/Models/FumbleTable.swift`:

```swift
import Foundation

enum FumbleTableType: String {
    case nahkampfAttacke
    case verteidigungWaffe
    case verteidigungSchild
    case fernkampf
}

struct FumbleTableEntry {
    let roll: Int
    let title: String
    let description: String
    /// SP to apply automatically (nil = GM decides)
    let autoDamage: Int?
}

enum FumbleTable {
    static func entries(for type: FumbleTableType) -> [FumbleTableEntry] {
        // Return entries for 2W6 results 2-12 per table type.
        // See Kodex des Schwertes pp. 68, 70, 83, 84 for tables.
        switch type {
        case .nahkampfAttacke:     return nahkampfAttackeEntries
        case .verteidigungWaffe:   return verteidigungWaffeEntries
        case .verteidigungSchild:  return verteidigungSchildEntries
        case .fernkampf:           return fernkampfEntries
        }
    }

    static func lookup(_ roll: Int, table: FumbleTableType, isUnarmed: Bool) -> FumbleTableEntry {
        let adjustedRoll = (isUnarmed && roll < 7) ? roll + 5 : roll
        let clamped = min(max(adjustedRoll, 2), 12)
        return entries(for: table).first { $0.roll == clamped }
            ?? FumbleTableEntry(roll: clamped, title: "—", description: "—", autoDamage: nil)
    }

    // MARK: - Table data (localized strings via L())
    // Each table has entries for 2W6 rolls 2-12.
    // Implementation: populate from Kodex des Schwertes tables.
    // Nahkampf-Patzertabelle (p68), Verteidigung-Patzertabelle Waffe (p70),
    // Verteidigung-Patzertabelle Schild (p84), Fernkampf-Patzertabelle (p83)

    private static let nahkampfAttackeEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: L("fumble.weaponDestroyed"),      description: L("fumble.weaponDestroyed.desc"),      autoDamage: nil),
        FumbleTableEntry(roll: 3,  title: L("fumble.weaponHeavyDamage"),    description: L("fumble.weaponHeavyDamage.desc"),    autoDamage: nil),
        FumbleTableEntry(roll: 4,  title: L("fumble.weaponDamaged"),        description: L("fumble.weaponDamaged.desc"),        autoDamage: nil),
        FumbleTableEntry(roll: 5,  title: L("fumble.weaponLost"),           description: L("fumble.weaponLost.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 6,  title: L("fumble.weaponStuck"),          description: L("fumble.weaponStuck.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 7,  title: L("fumble.fall"),                 description: L("fumble.fall.desc"),                 autoDamage: nil),
        FumbleTableEntry(roll: 8,  title: L("fumble.stumble"),              description: L("fumble.stumble.desc"),              autoDamage: nil),
        FumbleTableEntry(roll: 9,  title: L("fumble.footTwisted"),          description: L("fumble.footTwisted.desc"),          autoDamage: nil),
        FumbleTableEntry(roll: 10, title: L("fumble.bump"),                 description: L("fumble.bump.desc"),                 autoDamage: nil),
        FumbleTableEntry(roll: 11, title: L("fumble.selfHit"),              description: L("fumble.selfHit.desc"),              autoDamage: nil),
        FumbleTableEntry(roll: 12, title: L("fumble.selfHitHeavy"),         description: L("fumble.selfHitHeavy.desc"),         autoDamage: nil),
    ]

    // verteidigungWaffe uses identical structure/entries to nahkampfAttacke (same table, p70)
    private static let verteidigungWaffeEntries = nahkampfAttackeEntries

    private static let verteidigungSchildEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: L("fumble.shieldDestroyed"),      description: L("fumble.shieldDestroyed.desc"),      autoDamage: nil),
        FumbleTableEntry(roll: 3,  title: L("fumble.shieldHeavyDamage"),    description: L("fumble.shieldHeavyDamage.desc"),    autoDamage: nil),
        FumbleTableEntry(roll: 4,  title: L("fumble.shieldDamaged"),        description: L("fumble.shieldDamaged.desc"),        autoDamage: nil),
        FumbleTableEntry(roll: 5,  title: L("fumble.shieldLost"),           description: L("fumble.shieldLost.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 6,  title: L("fumble.shieldStuck"),          description: L("fumble.shieldStuck.desc"),          autoDamage: nil),
        FumbleTableEntry(roll: 7,  title: L("fumble.fall"),                 description: L("fumble.fall.desc"),                 autoDamage: nil),
        FumbleTableEntry(roll: 8,  title: L("fumble.stumble"),              description: L("fumble.stumble.desc"),              autoDamage: nil),
        FumbleTableEntry(roll: 9,  title: L("fumble.footTwisted"),          description: L("fumble.footTwisted.desc"),          autoDamage: nil),
        FumbleTableEntry(roll: 10, title: L("fumble.bump"),                 description: L("fumble.bump.desc"),                 autoDamage: nil),
        FumbleTableEntry(roll: 11, title: L("fumble.selfHit"),              description: L("fumble.selfHit.desc"),              autoDamage: nil),
        FumbleTableEntry(roll: 12, title: L("fumble.selfHitHeavy"),         description: L("fumble.selfHitHeavy.desc"),         autoDamage: nil),
    ]

    private static let fernkampfEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: L("fumble.weaponDestroyed"),      description: L("fumble.weaponDestroyed.desc"),      autoDamage: nil),
        FumbleTableEntry(roll: 3,  title: L("fumble.weaponHeavyDamage"),    description: L("fumble.weaponHeavyDamage.desc"),    autoDamage: nil),
        FumbleTableEntry(roll: 4,  title: L("fumble.fkWeaponDamaged"),      description: L("fumble.fkWeaponDamaged.desc"),      autoDamage: nil),
        FumbleTableEntry(roll: 5,  title: L("fumble.weaponLost"),           description: L("fumble.weaponLost.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 6,  title: L("fumble.comradeHit"),           description: L("fumble.comradeHit.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 7,  title: L("fumble.spectacularMiss"),      description: L("fumble.spectacularMiss.desc"),      autoDamage: nil),
        FumbleTableEntry(roll: 8,  title: L("fumble.strain"),               description: L("fumble.strain.desc"),               autoDamage: nil),
        FumbleTableEntry(roll: 9,  title: L("fumble.jam"),                  description: L("fumble.jam.desc"),                  autoDamage: nil),
        FumbleTableEntry(roll: 10, title: L("fumble.tooFocused"),           description: L("fumble.tooFocused.desc"),           autoDamage: nil),
        FumbleTableEntry(roll: 11, title: L("fumble.selfHit"),              description: L("fumble.selfHit.desc"),              autoDamage: nil),
        FumbleTableEntry(roll: 12, title: L("fumble.selfHitHeavy"),         description: L("fumble.selfHitHeavy.desc"),         autoDamage: nil),
    ]
}
```

**Step 3: Extend CombatActionType with new cases**

In `Hesindion/Models/LogEntry.swift`, extend `CombatActionType`:

```swift
enum CombatActionType: String, Codable {
    case attack
    case rangedAttack
    case parry
    case dodge
    case damageDealt
    case damageTaken
    case fumble
    case schipUsed
    case passierschlag
    case flucht
    case opponentDefense
}
```

**Step 4: Extend CombatActionPayload**

In `Hesindion/Models/LogEntry.swift`, add optional fields to `CombatActionPayload`:

```swift
struct CombatActionPayload: Codable, Reversible {
    var combatId: UUID
    var round: Int
    var action: CombatActionType
    var weaponName: String?
    var rollValue: Int?
    var effectiveValue: Int?         // NEW: the target number
    var outcome: String?             // NEW: "success", "failure", "critical", "fumble"
    var damageDealt: Int?
    var damageTaken: Int?
    var lpChange: Int
    var schipAction: String?         // NEW: "reroll", "damageReroll", "defenseBoost", "ignoreZustand"
    var fumbleTableResult: String?   // NEW: table entry title

    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        let reversed = dv.lebensenergie.current - lpChange
        dv.lebensenergie.current = min(max(reversed, 0), dv.lebensenergie.max)
    }
}
```

**Step 5: Commit**

```
feat: add combat data models — WeaponReach, FumbleTable, extended CombatActionPayload
```

---

## Task 1: Combat Session Persistence

**Files:**
- Modify: `Hesindion/Models/Hero.swift`
- Modify: `Hesindion/Views/CombatView.swift`
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Add combat state properties to Hero**

In `Hesindion/Models/Hero.swift`, add persisted combat state:

```swift
// MARK: - Combat session state
var activeCombatId: UUID?
var activeCombatRound: Int = 0
var activeCombatInitiative: Int?
var activeCombatPlaenkler: Bool = false
var activeCombatPlaenklerBonus: String?   // "at" or "aw"
var activeCombatMounted: Bool = false
var activeCombatBeengt: Bool = false
```

**Step 2: Modify CombatView to persist/restore state**

- On `CombatView.onAppear`: if `hero.activeCombatId != nil`, restore `combatId`, `roundNumber`, `rolledInitiative`, etc. from Hero and start at `.root` step.
- On every state change (round increment, initiative roll): write back to Hero.
- Add a **"Kampf beenden"** button in `CombatRootView` that clears `hero.activeCombatId` and calls `onDismiss()`.
- The existing X button just calls `onDismiss()` without clearing combat state (allowing re-entry).

**Step 3: Modify HeroDetailView**

- When `showCombatMode = true` and `hero.activeCombatId != nil`, CombatView should skip to root.
- No changes to the `.fullScreenCover` API — CombatView handles it internally.

**Step 4: Commit**

```
feat: persist combat session state for exit/re-enter without restart
```

---

## Task 2: Combat Setup — Beengte Umgebung

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatSetupView)
- Modify: `Hesindion/Views/CombatView.swift` (CombatRootView — settings sheet)
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add Beengte Umgebung toggle to CombatSetupView**

Below the mounted toggle in `CombatSetupView`, add a new section:

```swift
// Beengte Umgebung toggle
combatSectionLabel(L("beengteUmgebung.label"))

Button { beengteUmgebungActive.toggle() } label: {
    HStack(spacing: 12) {
        Image(systemName: beengteUmgebungActive ? "checkmark.square.fill" : "square")
            .font(.system(.title3, weight: .semibold))
            .foregroundStyle(beengteUmgebungActive ? combatAccent : .secondary)
        Text(L("beengteUmgebung"))
            .font(.system(.body, weight: beengteUmgebungActive ? .bold : .regular))
            .foregroundStyle(.primary)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(beengteUmgebungActive ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
    .overlay(Rectangle().stroke(beengteUmgebungActive ? combatAccent : Color.dsaBorder, lineWidth: beengteUmgebungActive ? 3 : 2))
}
.buttonStyle(.plain)
```

**Step 2: Pass `beengteUmgebungActive` through CombatView state**

Add `@State private var beengteUmgebungActive: Bool = false` to `CombatView`. Thread through to `CombatSetupView` and make available as a settings sheet in `CombatRootView` for mid-combat changes.

**Step 3: Apply Beengte Umgebung penalty in modifier builders**

In `CombatAnnouncementView.buildModifierLines()` and `CombatRootView.buildDefenseModifiers()`, when `beengteUmgebungActive`, look up `hero.selectedWeapon?.reach` and apply the penalty from `WeaponReach.beengteUmgebungPenalty`.

**Step 4: Commit**

```
feat: add Beengte Umgebung toggle to combat setup with AT/PA penalties
```

---

## Task 3: Weapon Reach Modifiers

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatAnnouncementView)
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add opponent reach selector to CombatAnnouncementView**

After the Vorteilhafte Position toggle, add:

```swift
combatSectionLabel(L("opponentReach.label"))

HStack(spacing: 8) {
    ForEach(WeaponReach.allCases, id: \.self) { reach in
        let isSelected = selectedOpponentReach == reach
        Button { selectedOpponentReach = reach } label: {
            Text(reach.rawValue)
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
```

Add `@State private var selectedOpponentReach: WeaponReach = .mittel`.

**Step 2: Include reach modifier in buildModifierLines()**

```swift
let heroReach = WeaponReach(rawValue: hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
let reachPenalty = heroReach.atPenaltyAgainst(selectedOpponentReach)
if reachPenalty != 0 {
    lines.append(ModifierLine(value: reachPenalty, source: L("source.reach")))
}
```

**Step 3: Commit**

```
feat: add opponent weapon reach selector with AT penalties
```

---

## Task 4: Rework CombatExecutionView — Info Box, Schips, Opponent Defense

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatExecutionView, CombatStep enum)
- Modify: `Hesindion/Theme/Strings.swift`

This is the largest task. Split into sub-steps.

**Step 1: Add new CombatStep cases**

```swift
case opponentDefense(weaponName: String, damageFormula: String?, isCriticalHit: Bool, isDoubleDamage: Bool, modifierLines: [ModifierLine]?)
case fumbleChoice(action: CombatAction, weaponName: String)
```

**Step 2: Move info box to after AT roll**

In `CombatExecutionView`, move the maneuver `note` display from above the dice box to below the outcome bar. Only show it when `finalRoll != nil`.

**Step 3: Add Schicksalspunkt "Neuer Wurf" button**

After the outcome bar, if the roll failed and is NOT a confirmed Patzer, and `hero.derivedValues.schicksalspunkte.current > 0`, show:

```swift
Button {
    hero.derivedValues?.schicksalspunkte.current -= 1
    schipUsed = true
    // Re-roll: reset finalRoll, restart animation, then roll again
    finalRoll = nil
    confirmRoll = nil
    startAnimation()
} label: {
    HStack(spacing: 6) {
        Image(systemName: "sparkles")
        Text(L("schip.reroll"))
    }
    // styled as combatAccent button
}
```

Add `@State private var schipUsed: Bool = false` to prevent double-use.

**Step 4: Add Schicksalspunkt "W6 wiederholen" for damage**

In `damageSection`, after damage rolls are finalized, if `hero.derivedValues.schicksalspunkte.current > 0` and `!damageSchipUsed`, show a button that rerolls one die (the lowest).

**Step 5: Rework outcome flow for attacks**

When `action == .angriff` and outcome is `.erfolg` or `.kritischerErfolg`:
- Instead of showing damage section immediately, show a **"Weiter zur Verteidigung"** button
- This transitions to `.opponentDefense(...)` step

When outcome is fumble (20 + confirmed):
- Transition to `.fumbleChoice(action, weaponName)`

**Step 6: Add logging at each step**

After each roll is finalized, insert a `LogEntry`:

```swift
let entry = LogEntry.create(
    kind: "combatAction",
    payload: CombatActionPayload(
        combatId: combatId,
        round: roundNumber,
        action: .attack,
        weaponName: weaponName,
        rollValue: finalRoll,
        effectiveValue: effectiveValue,
        outcome: outcomeString,
        damageDealt: nil,
        damageTaken: nil,
        lpChange: 0
    ),
    hero: hero
)
modelContext.insert(entry)
```

This requires passing `hero`, `modelContext`, `combatId`, `roundNumber` into `CombatExecutionView`.

**Step 7: Commit**

```
feat: rework attack execution — info box after roll, Schips, opponent defense transition
```

---

## Task 5: Opponent Defense Step View

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add CombatOpponentDefenseView)

**Step 1: Create CombatOpponentDefenseView**

Handles the `.opponentDefense` step. Shows:
- Header: weapon name
- If critical hit: info box "Gegner Verteidigung halbiert" (+ "TP verdoppelt" if confirmed)
- Three buttons:
  - **"Pariert"** — logs opponent parry, returns to `.root`
  - **"Ausgewichen"** — logs opponent dodge, returns to `.root`
  - **"Treffer geht durch"** — proceeds to damage section (inline or new step)

When "Treffer geht durch" is tapped, show the damage dice section (same as current `damageSection` but with doubled TP if `isDoubleDamage`).

After damage is rolled, show:
- Damage result (TP)
- "Neue Aktion" button → `.root`

**Step 2: Wire into CombatView body switch**

```swift
case .opponentDefense(let name, let dmg, let isCrit, let isDouble, let mods):
    CombatOpponentDefenseView(
        hero: hero, weaponName: name, damageFormula: dmg,
        isCriticalHit: isCrit, isDoubleDamage: isDouble,
        modifierLines: mods,
        step: $step, onDismiss: onDismiss,
        combatId: combatId, roundNumber: roundNumber
    )
    .transition(.move(edge: .trailing))
```

**Step 3: Commit**

```
feat: add opponent defense step — Pariert / Ausgewichen / Treffer buttons
```

---

## Task 6: Fumble Choice View

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add CombatFumbleChoiceView)

**Step 1: Create CombatFumbleChoiceView**

Handles `.fumbleChoice` step. Shows:
- Header: "Patzer!"
- Two options:
  1. **"1W6+2 SP nehmen"** — rolls 1W6, adds 2, applies as SP (ignoring RS), logs, returns to `.root`
  2. **"Patzertabelle würfeln"** — rolls 2W6, looks up the entry in `FumbleTable`, displays the result text, lets GM interpret

Automatically selects the correct table based on `action`:
- `.angriff` → `.nahkampfAttacke`
- `.parieren` → `.verteidigungWaffe` (or `.verteidigungSchild` if parrying with shield)
- `.ausweichen` → `.verteidigungSchild` (with +5 adjustment for dodging)
- `.fernkampf` → `.fernkampf`

**Step 2: Wire into CombatView body switch and stepID**

**Step 3: Commit**

```
feat: add fumble choice — 1W6+2 SP or Patzertabelle with all 4 table types
```

---

## Task 7: Defense Flow Improvements

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatView state, CombatRootView, CombatExecutionView)

**Step 1: Track multiple defenses per round**

Add `@State private var defenseCountThisRound: Int = 0` to `CombatView`. Reset in `onChange(of: roundNumber)`.

**Step 2: Apply cumulative -3 penalty**

In `CombatRootView.buildDefenseModifiers()`:

```swift
if defenseCountThisRound > 0 {
    lines.append(ModifierLine(value: -(defenseCountThisRound * 3), source: L("source.multipleDefense")))
}
```

**Step 3: Increment defense count after each defense action**

When transitioning to `.execution(.parieren, ...)` or `.execution(.ausweichen, ...)`, increment `defenseCountThisRound`. This needs a binding or callback.

**Step 4: Handle critical PA success → Passierschlag opportunity**

In `CombatExecutionView`, when `action == .parieren` and outcome is `.kritischerErfolg`, show a **"Passierschlag ausführen"** button that transitions to `.passierschlag`.

**Step 5: Handle defense fumble → fumble choice**

When defense outcome is confirmed Patzer, transition to `.fumbleChoice(action, weaponName)`.

**Step 6: Commit**

```
feat: track multiple defenses per round with -3 penalty, critical PA → Passierschlag
```

---

## Task 8: Schicksalspunkte — Defense Boost & Zustand Ignore

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatRootView)

**Step 1: Add Schip buttons to CombatRootView**

Below the action buttons, in a new "Schicksalspunkte" section:

- **"Verteidigung stärken"** — costs 1 Schip, sets `schipDefenseBoostActive = true` for this round, adds +4 to all defense modifiers
- **"Zustand ignorieren"** — costs 1 Schip, sets `schipIgnoreZustandThisRound = true`, zeroes out Schmerz penalty in modifier builders

Both reset on `roundNumber` change.

**Step 2: Wire into modifier builders**

In `buildDefenseModifiers()`:
```swift
if schipDefenseBoostActive {
    lines.append(ModifierLine(value: 4, source: L("source.schipDefense")))
}
```

When `schipIgnoreZustandThisRound`, skip the Schmerz modifier line.

**Step 3: Log Schip usage**

```swift
let entry = LogEntry.create(kind: "combatAction", payload: CombatActionPayload(
    combatId: combatId, round: roundNumber, action: .schipUsed,
    schipAction: "defenseBoost", lpChange: 0
), hero: hero)
modelContext.insert(entry)
```

**Step 4: Commit**

```
feat: add Schicksalspunkte defense boost (+4) and Zustand ignorieren in combat
```

---

## Task 9: Passierschlag

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add CombatPassierschlagView, CombatStep)

**Step 1: Add `.passierschlag` CombatStep**

**Step 2: Create CombatPassierschlagView**

A simplified attack view:
- Uses hero's AT value with -4 penalty
- No maneuvers allowed
- No criticals or fumbles possible (a 1 is just a success, a 20 is just a miss)
- On hit: roll normal weapon damage, show TP, log it
- Cannot be defended against (no opponent defense step)
- "Neue Aktion" → `.root`

**Step 3: Commit**

```
feat: add Passierschlag — AT-4 attack, no maneuvers, no criticals
```

---

## Task 10: Flucht

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add CombatFluchtView, CombatStep, CombatRootView)

**Step 1: Add `.flucht` CombatStep and button in CombatRootView**

Add a "Flucht" button in the action section of `CombatRootView`.

**Step 2: Create CombatFluchtView**

Shows:
- Info: "Probe auf Körperbeherrschung (Kampfmanöver)"
- Stepper: "Anzahl Gegner in Angriffsdistanz" (the probe is erschwert by this count)
- "Probe gelungen" / "Probe misslungen" buttons (user resolves the talent check themselves, possibly exiting combat mode to do so)
- On success: info "GS Schritt Bewegung, Achtung: Passierschläge möglich"
- On failure: info "GS/2 Bewegung, Passierschlag erlitten"
- Log the attempt

**Step 3: Commit**

```
feat: add Flucht — escape attempt with opponent count and outcome
```

---

## Task 11: Fernkampf — Equipment & Weapon Selection

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatLoadoutEquipmentView, CombatRootView, CombatStep)
- Modify: `Hesindion/Models/RangedWeapon.swift`

**Step 1: Add `isSchusswaffe` computed property to RangedWeapon**

```swift
extension RangedWeapon {
    /// Schusswaffen: Armbrüste (CT_11), Bögen (CT_12). Others are Wurfwaffen.
    var isSchusswaffe: Bool {
        ["CT_11", "CT_12"].contains(combatTechniqueId)
    }
}
```

**Step 2: Track selected ranged weapon on Hero**

Add `var selectedRangedWeaponName: String?` to `Hero`.

**Step 3: Show ranged weapons in CombatLoadoutEquipmentView**

Add a "Fernkampfwaffen" section showing `hero.rangedWeapons`. Ranged weapon selection is independent of melee selection (a hero can have both ready).

**Step 4: Add "Fernkampf" button to CombatRootView**

Below the Angriff button, add a Fernkampf button (only visible when `hero.selectedRangedWeaponName != nil`):

```swift
Button { step = .fernkampfSetup } label: {
    HStack(spacing: 6) {
        Image(systemName: "scope")
        Text(L("rangedAttack"))
    }
    // styled like the Angriff button but with a different icon
}
```

**Step 5: Commit**

```
feat: add ranged weapon selection and Fernkampf button to combat root
```

---

## Task 12: Fernkampf — Setup View

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add CombatFernkampfSetupView, CombatStep)
- Create: `Hesindion/Models/FernkampfModifiers.swift` (optional, or inline)

**Step 1: Add `.fernkampfSetup` and `.fernkampfExecution` CombatStep cases**

```swift
case fernkampfSetup
case fernkampfExecution(weaponName: String, attributeValue: Int, damageFormula: String, distanzTP: Int, modifierLines: [ModifierLine])
```

**Step 2: Create CombatFernkampfSetupView**

Modifier selectors (all as segmented controls or steppers):

- **Distanz**: nah (+2 FK, +1 TP) / mittel (0) / weit (-2 FK, -1 TP)
- **Größe**: winzig (-8) / klein (-4) / mittel (0) / groß (+4) / riesig (+8)
- **Bewegung Ziel**: still (+2) / leicht (0) / schnell (-2) / Haken (-4)
- **Bewegung Schütze**: steht (0) / geht (-2) / rennt (-4)
- **Sicht**: klar (0) / Stufe 1 (-2) / Stufe 2 (-4) / Stufe 3 (-6)
- **Kampfgetümmel**: toggle (-2)
- **Zielen**: 0 / 1 (+2) / 2 (+4) Aktionen
- **Vom Pferd** (if mounted): steht (0) / Schritt (-4) / Galopp (-8)

Build `ModifierLine` array from all selections. Calculate effective FK value. "Weiter" button → `.fernkampfExecution(...)`.

**Step 3: Commit**

```
feat: add Fernkampf setup view with all FK modifier selectors
```

---

## Task 13: Fernkampf — Execution & Defense

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (wire fernkampfExecution, extend CombatExecutionView or create CombatFernkampfExecutionView)

**Step 1: Reuse or extend CombatExecutionView for FK**

The FK execution follows the same pattern as AT: roll W20, check for critical/fumble, show outcome. The main difference is:
- Action label: "Fernkampf" instead of "Angriff"
- FK fumble uses `.fernkampf` table
- On hit → opponent defense step with special rules:
  - No weapon parade possible, only AW or Schild
  - Schusswaffen: -4 on defense
  - Wurfwaffen: -2 on defense
  - Show this info in the opponent defense step

Option: extend `CombatAction` with `.fernkampf` case, and reuse `CombatExecutionView` with FK-specific behavior.

**Step 2: Handle FK-specific opponent defense**

In `CombatOpponentDefenseView`, when the attack was ranged:
- Show info: "Keine Parade mit Waffe möglich"
- Show: "Schusswaffe: Verteidigung -4" or "Wurfwaffe: Verteidigung -2"
- Buttons: "Pariert (Schild)" / "Ausgewichen" / "Treffer geht durch"

**Step 3: Apply distance TP modifier to damage**

In the damage section, add/subtract the `distanzTP` from the formula.

**Step 4: Commit**

```
feat: add Fernkampf execution with FK-specific defense rules
```

---

## Task 14: Combat Logging — Full Integration

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (all views that produce outcomes)
- Modify: `Hesindion/Views/LogPanelView.swift`

**Step 1: Add logging to all views that don't yet log**

Ensure every combat action creates a `LogEntry`:
- `CombatExecutionView`: AT/PA/AW/FK roll → log roll + outcome
- `CombatOpponentDefenseView`: opponent defense choice → log
- `CombatFumbleChoiceView`: fumble result → log (with table entry if used)
- `CombatPassierschlagView`: attack + damage → log
- `CombatFluchtView`: escape attempt → log
- Schip usage → log

**Step 2: Update LogPanelView descriptions**

In `combatActionDescription`, handle new `CombatActionType` cases:

```swift
case .rangedAttack:
    return "\(weapon) — Fernkampf \(p.rollValue ?? 0)"
case .fumble:
    return "\(weapon) — Patzer: \(p.fumbleTableResult ?? "1W6+2 SP")"
case .schipUsed:
    return "Schip: \(p.schipAction ?? "")"
case .passierschlag:
    return "\(weapon) — Passierschlag \(p.rollValue ?? 0)"
case .flucht:
    return "Flucht — \(p.outcome ?? "")"
case .opponentDefense:
    return "\(weapon) — Gegner: \(p.outcome ?? "")"
```

**Step 3: Commit**

```
feat: comprehensive combat logging for all action types
```

---

## Task 15: Localization Strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add all new L() keys**

Add to the `strings` dictionary all keys used in Tasks 0-14. Group by feature:

```swift
// Beengte Umgebung
"beengteUmgebung":              "Beengte Umgebung",
"beengteUmgebung.label":        "UMGEBUNG",

// Weapon Reach
"opponentReach.label":          "GEGNER-REICHWEITE",
"source.reach":                 "Reichweite",

// Opponent Defense
"opponentDefense":              "Verteidigung des Gegners",
"opponentDefense.parried":      "Pariert",
"opponentDefense.dodged":       "Ausgewichen",
"opponentDefense.hitThrough":   "Treffer geht durch",
"opponentDefense.halved":       "Gegner Verteidigung halbiert",
"opponentDefense.doubleDamage": "TP verdoppelt",
"opponentDefense.noWeaponParry":"Keine Parade mit Waffe möglich",
"opponentDefense.schusswaffe":  "Schusswaffe: Verteidigung -4",
"opponentDefense.wurfwaffe":    "Wurfwaffe: Verteidigung -2",
"opponentDefense.shieldParry":  "Pariert (Schild)",

// Schicksalspunkte
"schip.reroll":                 "Schip: Neuer Wurf",
"schip.damageReroll":           "Schip: W6 wiederholen",
"schip.defenseBoost":           "Verteidigung stärken (+4)",
"schip.ignoreZustand":          "Zustand ignorieren",
"source.schipDefense":          "Schicksalspunkt",

// Fumble
"fumble.title":                 "Patzer!",
"fumble.takeDamage":            "1W6+2 SP nehmen",
"fumble.rollTable":             "Patzertabelle würfeln",
// ... all fumble table entry keys (see Task 0)

// Multiple defenses
"source.multipleDefense":       "Mehrfache Verteidigung",

// Passierschlag
"passierschlag":                "Passierschlag",
"passierschlag.info":           "AT -4, keine Manöver, keine Kritischen Erfolge/Patzer",

// Flucht
"flucht":                       "Flucht",
"flucht.info":                  "Probe auf Körperbeherrschung (Kampfmanöver)",
"flucht.opponents":             "Gegner in Angriffsdistanz",
"flucht.success":               "Gelungen — GS Schritt Bewegung",
"flucht.failure":               "Misslungen — GS/2 Bewegung, Passierschlag",

// Fernkampf
"rangedAttack":                 "Fernkampf",
"fernkampf.setup":              "Fernkampf vorbereiten",
"fernkampf.distanz":            "DISTANZ",
"fernkampf.groesse":            "GRÖSSE",
"fernkampf.bewegungZiel":       "BEWEGUNG ZIEL",
"fernkampf.bewegungSchuetze":   "BEWEGUNG SCHÜTZE",
"fernkampf.sicht":              "SICHT",
"fernkampf.kampfgetuemmel":     "Kampfgetümmel",
"fernkampf.zielen":             "ZIELEN",
"fernkampf.vomPferd":           "VOM PFERD",
// ... distance/size/movement/sight option labels

// Combat session
"endCombat":                    "Kampf beenden",
```

**Step 2: Commit**

```
feat: add all localization strings for combat overhaul
```

---

## Task 16: Update CHANGELOG & Documentation

**Files:**
- Modify: `Hesindion/Resources/CHANGELOG.md`
- Modify: `AGENTS.md` (combat system section)

**Step 1: Update CHANGELOG**

Add under `[Unreleased]` → `Added`:
- Opponent defense step after successful attack (Pariert / Ausgewichen / Treffer)
- Schicksalspunkte integration (Neuer Wurf, Schadenswurf wiederholen, Verteidigung stärken, Zustand ignorieren)
- Weapon reach modifiers (Kurz/Mittel/Lang)
- Beengte Umgebung toggle in combat setup
- Patzertabellen (all 4 tables) as alternative to 1W6+2 SP
- Passierschlag and Flucht actions
- Fernkampf attack flow with full modifier support
- Combat session persistence (exit and re-enter without restarting)
- Comprehensive combat logging for all action types
- Multiple defense tracking with cumulative -3 penalty

**Step 2: Update AGENTS.md combat system section**

Update the architecture description to reflect new steps and flows.

**Step 3: Commit**

```
docs: update changelog and architecture for combat system overhaul
```
