# Overview of spec 006_combat-mode

- This command is called `Combat`, or `Kampf` in German
- Entry points:
    - Long-press on any Weapon or Shield element in HeroDetailView
    - Command palette (add a `Kampf` command to the `commandRegistry`)
- It opens a `ZStack` overlay covering HeroDetailView, using the same blurred-background pattern as TalentProbeModal.
- Add `@State private var showCombatMode = false` to `HeroDetailView`.

# Wireframe

┌──────────────────────┐
│                      │
│                      │
│  ┌───────────────┐   │
│ ▲│LP      13 / 30│▼  │ ◄───────  LifeEnergy Progress Bar
│  └───────────────┘   │
│  ─────────────────   │
│  ┌───────────────┐   │
│  │ Actions       │   │
│  └───────────────┘   │
│   ┌─────────────┐    │
│   │   Angriff   │    │ ◄───────  Trigger attack
│   └─────────────┘    │
│   ┌─────────────┐    │
│   │   Parieren  │    │ ◄───────  Trigger Parieren
│   └─────────────┘    │
│   ┌─────────────┐    │
│   │  Ausweichen │    │ ◄───────  Trigger Ausweichen
│   └─────────────┘    │
│                      │
│                      │
└──────────────────────┘

- A user can exit combat mode by swiping up on the modal's background.
- The ▲/▼ buttons on either side of the progress bar adjust `hero.derivedValues!.lebensenergie.current`
  by +1 or −1 per tap. Value is clamped to `[0, lebensenergie.max]`. Changes persist immediately via SwiftData.


## Navigation / Flow Architecture

The three action flows (Angriff, Parieren, Ausweichen) share the same two-step pattern:
1. Weapon/source selection
2. Roll execution

Use a `NavigationStack` embedded inside the `ZStack` overlay. Each action step is a separate
view pushed onto the stack. This gives proper push/pop semantics and a back button for free.

Define a local `CombatSelection` value type to carry the chosen weapon/source between steps:

```swift
enum CombatSelection {
    case weapon(MeleeWeapon)
    case shield(Shield)
    case raufen
}
```

After a roll is completed (result shown), the user may swipe up or tap a dismiss button to return
directly to the combat root. The selection step is NOT re-shown automatically.


## Trigger: Angriff (Attack)

- Is a flow of two views pushed via `NavigationStack`:
    1. Weapon selection
    2. Roll execution
- After execution, swipe-up (or a dismiss button) returns directly to the combat root.


### Step 1 — Weapon selection (Angriff)

 ┌────────────────┐
 │                │
 │   Angriff      │
 │                │
 │ ────────────── │
 │                │
 │ Rabenschnabel  │  <- MeleeWeapons, then Shields, then Raufen
 │                │
 │ Langschwert    │
 │                │
 │ Großschild     │
 │                │
 │ Raufen         │  <- Always present as last item
 │                │
 └────────────────┘

- Lists all `meleeWeapons`, then all `shields`, then `Raufen` as a fixed last entry.
- If the hero has no `meleeWeapons` and no `shields`, only `Raufen` is shown (no empty state message needed).
- Tapping an item pushes the execution view with that selection.
- The AT value used per selection:
    - `MeleeWeapon` → `weapon.at`
    - `Shield` → `shield.at`  *(see Data Model Fixes below)*
    - `Raufen` → look up `hero.combatTechniques.first(where: { $0.name == "Raufen" })?.at ?? 0`


### Step 2 — Execution (Angriff)

   ┌────────────────┐
   │                │
   │  Angriff       │
   │  Rabenschnabel │
   │ ────────────── │
   │      ┌──┐      │
   │      │AT│      │
   │      │  │      │◄───────    Weapon AT value (read-only)
   │      │14│      │
   │      └──┘      │
   │      ┌──┐      │
   │    ▲ │ 3│ ▼    │◄───────    Modifier (inline stepper, simple press)
   │      └──┘      │
   │      ┌──┐      │
   │      │11│      │◄───────    Dice result (tap to roll)
   │      └──┘      │
   │      ┌──┐      │
   │      │11│      │◄───────    Effective result (AT + modifier − roll, for display)
   │      └──┘      │
   │                │
   └────────────────┘

- Roll is a single d20. Use the same dice animation as TalentProbeModal.
- The user triggers the roll by tapping the dice result box.
- The modifier is adjusted with the inline ▲/▼ stepper (simple tap, no extra modal). It can be
  positive or negative. Resets to 0 each time the execution view is opened.
- **Success condition**: roll ≤ AT + modifier.

### Critical Success / Failure (single d20)

Evaluated in this order (first match wins):

| Roll | Label | Action |
|------|-------|--------|
| 1 | Potential critical success | Trigger confirmation roll |
| 20 | Potential critical failure | Trigger confirmation roll |
| ≤ AT + modifier | Success | — |
| > AT + modifier | Failure | — |

**Confirmation roll**: after a 1 or 20, the die animates and rolls again automatically.
- If the initial roll was 1:
    - Confirmation roll ≤ AT + modifier → **Confirmed critical success**
    - Otherwise → **Normal success**
- If the initial roll was 20:
    - Confirmation roll > AT + modifier → **Confirmed critical failure**
    - Otherwise → **Normal failure**

Show the outcome label (critical success / success / failure / critical failure) prominently below the result box.


## Trigger: Parieren

- Reuses the exact same layout and two-step flow as Angriff.
- Title changes to `Parieren`.
- Replace the `AT` label with `PA`.
- Use PA values instead:
    - `MeleeWeapon` → `weapon.pa`
    - `Shield` → `shield.pa`  *(see Data Model Fixes below)*
    - `Raufen` → `hero.combatTechniques.first(where: { $0.name == "Raufen" })?.pa ?? 0`


## Trigger: Ausweichen

- Same two-step layout and flow as Angriff.
- Title changes to `Ausweichen`.
- Step 1 (selection) is **skipped** — there is no weapon to select. Go directly to the execution view.
- The attribute value shown (where AT/PA would be) is `hero.derivedValues!.ausweichen.value`.
  Label it `AW` instead of `AT`.
- Roll is a single d20 against `ausweichen.value + modifier`.
- Same critical success/failure rules apply.


## LifeEnergie Progress Bar

- `LP` stands for `Lebenspunkte` (the German display label).
- Displayed as a layered progress bar:
    - Back layer: white background spanning full width.
    - Front layer: coloured fill proportional to `current / max`, colour from the table below.
- Text displays `current / max` centred over the bar.

### Progress Bar Colours

Predicates evaluated top-to-bottom; first match wins.

| predicate | fill colour | text colour |
|-----------|-------------|-------------|
| current == 0 | #000000 (black) | #FFFFFF (white) |
| current <= 5 | #8B0000 (dark red) | #FFFFFF (white) |
| current < 1/4 × max | #CC2200 (light red) | #FFFFFF (white) |
| current < 1/2 × max | #E07000 (orange) | #FFFFFF (white) |
| current < 3/4 × max | #D4C000 (yellow) | #FFFFFF (white) |
| current >= 3/4 × max | #2E7D32 (green) | #FFFFFF (white) |


## Data Model Fixes Required

Before implementing this spec, fix the following model bugs:

### Shield — missing `at` and `pa` fields

`Shield.swift` currently only has `atMod` and `paMod`. Add direct base values:

```swift
var at: Int   // base AT value
var pa: Int   // base PA value
```

Update the JSON seed/import accordingly.

### CombatTechnique.pa — should be non-optional

`CombatTechnique.pa` is currently `Int?`. Every combat technique has a PA value (per DSA rules).
Change to `Int` and update the JSON seed/import accordingly.
