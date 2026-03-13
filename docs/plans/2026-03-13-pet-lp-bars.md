# Pet LP Bars Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add LP (Lebenspunkte) bars to all pets in HeroDetailView, and show the mount's LP bar in CombatView when mounted.

**Architecture:** Add `currentLifeEnergy` to the `Pet` model. Reuse `LPBarView` with a new optional `label` parameter. Wire into pets section and combat view.

**Tech Stack:** SwiftUI, SwiftData

---

### Task 1: Add `currentLifeEnergy` to Pet model

**Files:**
- Modify: `Hesindion/Models/Pet.swift:30` (add property after `lifeEnergy`)

**Step 1: Add the stored property**

In `Pet.swift`, add after line 30 (`var lifeEnergy: Int`):

```swift
var currentLifeEnergy: Int
```

**Step 2: Update the initializer**

Add `currentLifeEnergy` parameter with default `lifeEnergy`:

```swift
init(
    petId: String,
    name: String,
    avatar: Data? = nil,
    size: Double,
    type: String,
    attributes: PetAttributes,
    lifeEnergy: Int,
    currentLifeEnergy: Int? = nil,  // <-- new, defaults to lifeEnergy
    spirit: Int,
    // ... rest unchanged
) {
    // ... existing assignments ...
    self.currentLifeEnergy = currentLifeEnergy ?? lifeEnergy
    // ... rest unchanged
}
```

**Step 3: Update import service**

In `Hesindion/Services/OptolithImportService.swift`, find where `Pet` is constructed. No changes needed — the new parameter has a default.

**Step 4: Build to verify**

Run: `make build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Hesindion/Models/Pet.swift
git commit -m "feat: add currentLifeEnergy to Pet model"
```

---

### Task 2: Add `label` parameter to `LPBarView`

**Files:**
- Modify: `Hesindion/Views/HeroDetailComponents.swift:246-305`

**Step 1: Add optional label parameter**

Add a `label` property to `LPBarView` with a default:

```swift
struct LPBarView: View {
    let current: Int
    let max: Int
    var accent: Color = Color.groupCombat
    var label: String = "lifePoints.short"  // <-- new
    let onDecrement: () -> Void
    let onIncrement: () -> Void
```

**Step 2: Use label in the bar text**

Replace the hardcoded `L("lifePoints.short")` on line 272:

```swift
// Before:
Text("\(L("lifePoints.short"))   \(current) / \(max)")

// After:
Text("\(L(label))   \(current) / \(max)")
```

**Step 3: Build to verify**

Run: `make build`
Expected: Build succeeds — all existing callsites use the default.

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroDetailComponents.swift
git commit -m "feat: add configurable label to LPBarView"
```

---

### Task 3: Add LP bars to pets section in HeroDetailView

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:841-891` (petsSection)

**Step 1: Add LPBarView after pet name/type header**

In the `petsSection`, after the pet name/type `HStack` (line 853) and before the attributes `SubfieldBlock` (line 855), insert:

```swift
LPBarView(
    current: pet.currentLifeEnergy,
    max: pet.lifeEnergy,
    accent: .groupEquipment,
    label: "lifePoints.short"
) {
    guard pet.currentLifeEnergy > 0 else { return }
    pet.currentLifeEnergy -= 1
} onIncrement: {
    guard pet.currentLifeEnergy < pet.lifeEnergy else { return }
    pet.currentLifeEnergy += 1
}
.padding(.horizontal, 12)
```

**Step 2: Update the LE field in the combat SubfieldBlock**

In the combat `SubfieldBlock` (line 866), change the `"LE"` subfield from showing max to showing current/max:

```swift
("LE", "\(pet.currentLifeEnergy)/\(pet.lifeEnergy)"),
```

**Step 3: Build and test visually**

Run: `make build && make run`
Expected: Each pet in the equipment group shows an LP bar below its name.

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: add LP bars to pets section"
```

---

### Task 4: Add mount LP bar to CombatView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (near line 1626, after hero lpBar)

**Step 1: Add mount LP bar after hero LP bar**

After `lpBar` on line 1626, add:

```swift
if mountedActive, let mount = hero.pets.first {
    LPBarView(
        current: mount.currentLifeEnergy,
        max: mount.lifeEnergy,
        accent: Color(red: 0x0d / 255, green: 0x96 / 255, blue: 0x88 / 255),
        label: "lifePoints.short"
    ) {
        guard mount.currentLifeEnergy > 0 else { return }
        mount.currentLifeEnergy -= 1
    } onIncrement: {
        guard mount.currentLifeEnergy < mount.lifeEnergy else { return }
        mount.currentLifeEnergy += 1
    }
    .padding(.horizontal, 16)

    Text(mount.name)
        .font(.system(.caption, design: .monospaced, weight: .bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

The teal color matches the existing mount-related UI in the combat view.

**Step 2: Build and test visually**

Run: `make build && make run`
Expected: When "Berittener Kampf" is toggled on in combat, a second LP bar appears for the mount below the hero's LP bar.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: show mount LP bar in combat view"
```

---

### Task 5: Update docs

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add changelog entry**

Under `[Unreleased]` → `### Added`:

```markdown
- LP (Lebenspunkte) bar for all pets in hero detail view
- Mount LP bar in combat view when mounted combat is active
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for pet LP bars"
```
