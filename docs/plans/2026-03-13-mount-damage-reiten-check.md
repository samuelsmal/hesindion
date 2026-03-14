# Mount Damage with Reiten Check Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** When a mount takes SP damage, automatically trigger a Reiten (Kampfmanöver) check with difficulty scaled by SP received (+1 per 5 full SP). Fail = Sturz warning.

**Architecture:** Two entry points — a dedicated button in CombatView's mount LP section and a command in the command palette for normal mode. Both share the same flow: SP input → LP deduction → Reiten check with pre-set modifier → result display. TalentProbeModal gains an `initialModifier` parameter to support pre-applied penalties.

**Tech Stack:** SwiftUI, SwiftData, existing TalentProbeModal, existing AppCommand system

---

### Task 1: Add `initialModifier` parameter to TalentProbeModal

**Files:**
- Modify: `Hesindion/Views/TalentProbeModal.swift:6-12`

**Step 1: Add the parameter**

Add an optional `initialModifier` parameter (default `0`) to `TalentProbeModal`. When set, all three modifier slots start at this value instead of `0`.

```swift
struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil
    var initialModifier: Int = 0

    @State private var modifiers = [0, 0, 0]
    // ... existing code ...
```

Then add `.onAppear` logic (or change the default) so `modifiers` initializes from `initialModifier`:

```swift
    // Change the @State init:
    @State private var modifiers: [Int]

    // Add a custom init that sets the default:
    init(talent: Talent, hero: Hero, onDismiss: @escaping () -> Void, onRolled: ((Bool) -> Void)? = nil, initialModifier: Int = 0) {
        self.talent = talent
        self.hero = hero
        self.onDismiss = onDismiss
        self.onRolled = onRolled
        self.initialModifier = initialModifier
        _modifiers = State(initialValue: [initialModifier, initialModifier, initialModifier])
    }
```

**Step 2: Verify existing callers still compile**

Existing callers pass no `initialModifier`, so the default `0` keeps behavior identical.

Run: `make build`
Expected: Build succeeds with no changes to existing behavior.

**Step 3: Commit**

```bash
git add Hesindion/Views/TalentProbeModal.swift
git commit -m "feat: add initialModifier parameter to TalentProbeModal"
```

---

### Task 2: Add localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add new strings to both English and German dictionaries**

English (add after `"rollReitenCheck"` line ~253):

```swift
"mountTakesDamage":         "Mount Takes Damage",
"mountDamage.sp":           "SP received",
"mountDamage.penalty":      "Check penalty: %d",
"mountDamage.apply":        "Apply & Check",
"mountDamage.sturz":        "Fall! The rider is dismounted.",
"mountDamage.noPenalty":    "No additional penalty",
```

German (add after `"rollReitenCheck"` line ~524):

```swift
"mountTakesDamage":         "Reittier erleidet Schaden",
"mountDamage.sp":           "Erlittene SP",
"mountDamage.penalty":      "Erschwernis: %d",
"mountDamage.apply":        "Anwenden & Probe",
"mountDamage.sturz":        "Sturz! Der Reiter wird abgeworfen.",
"mountDamage.noPenalty":    "Keine zusätzliche Erschwernis",
```

**Step 2: Build**

Run: `make build`
Expected: PASS

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add mount damage Reiten check localization strings"
```

---

### Task 3: Build CombatMountDamageView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (add new view at bottom, before closing `}`)

**Step 1: Add the `mountDamage` case to CombatStep**

```swift
// In the CombatStep enum, add before `case takeDamage`:
case mountDamage
```

Also add the stepID case:

```swift
case .mountDamage: "mountDamage"
```

And the swipe-back handler:

```swift
case .mountDamage:
    step = .root
```

**Step 2: Add CombatMountDamageView**

This view has 3 phases:
1. **SP input** — stepper to enter SP amount (1+)
2. **Reiten check** — uses TalentProbeModal with `initialModifier: -(sp / 5)`
3. **Result** — shows pass/fail, with Sturz warning on fail

```swift
// MARK: - CombatMountDamageView

private struct CombatMountDamageView: View {
    let hero: Hero
    let mount: Pet
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var spAmount: Int = 1
    @State private var damageApplied = false
    @State private var showingProbeModal = false
    @State private var probeSucceeded: Bool? = nil

    private var penalty: Int { spAmount / 5 }

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
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
                Text(L("mountTakesDamage"))
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

            Spacer()

            if !damageApplied {
                spInputPhase
            } else {
                reitenCheckPhase
            }

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty
                )
            }
        }
    }

    // MARK: - SP Input Phase

    private var spInputPhase: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(mount.name)
                .font(.system(.title3, weight: .bold))

            // SP stepper
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Button {
                        if spAmount > 1 { spAmount -= 1 }
                    } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Text("\(spAmount)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button {
                        spAmount += 1
                    } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                Text(L("mountDamage.sp"))
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            // Penalty display
            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(combatAccent)
            } else {
                Text(L("mountDamage.noPenalty"))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Apply button
            Button {
                // Deduct LP from mount
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)
                withAnimation(DSAAnimation.standard) {
                    damageApplied = true
                }
            } label: {
                Text(L("mountDamage.apply"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Reiten Check Phase

    private var reitenCheckPhase: some View {
        VStack(spacing: 16) {
            if let talent = reitenTalent {
                if let succeeded = probeSucceeded {
                    // Result
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

                    Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !succeeded {
                        Text(L("mountDamage.sturz"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(Color.groupCombat)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.groupCombat.opacity(0.1))
                            .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
                    }

                    Button {
                        step = .root
                    } label: {
                        Text(L("continue"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(succeeded ? combatAccent : Color.dsaDark)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Prompt to roll
                    Image(systemName: "dice.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(combatAccent)

                    Text(L("reitenCheck"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    if penalty > 0 {
                        Text(String(format: L("mountDamage.penalty"), penalty))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(combatAccent)
                    }

                    Button {
                        showingProbeModal = true
                    } label: {
                        Text(L("rollReitenCheck"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No Reiten talent — manual confirmation
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(combatAccent)

                Text(L("reitenCheckPrompt"))
                    .font(.system(.title3, weight: .bold))
                    .multilineTextAlignment(.center)

                if penalty > 0 {
                    Text(String(format: L("mountDamage.penalty"), penalty))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(combatAccent)
                }

                HStack(spacing: 12) {
                    Button {
                        probeSucceeded = false
                    } label: {
                        Text(L("no"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Button {
                        probeSucceeded = true
                    } label: {
                        Text(L("yes"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
```

**Step 3: Wire into CombatView's body switch**

In the main `switch step` body, add before `case .takeDamage`:

```swift
case .mountDamage:
    if let mount = hero.pets.first {
        CombatMountDamageView(
            hero: hero,
            mount: mount,
            step: $step,
            onDismiss: onDismiss
        )
        .transition(.move(edge: .trailing))
    }
```

**Step 4: Add "Mount takes damage" button in CombatRootView**

In the mount LP section (after the mount name label, around line 1646), add a button:

```swift
Button {
    step = .mountDamage
} label: {
    HStack(spacing: 6) {
        Image(systemName: "bolt.heart.fill")
            .font(.system(.caption, weight: .bold))
        Text(L("mountTakesDamage"))
            .font(.system(.caption, design: .monospaced, weight: .black))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(combatAccent)
    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
}
.buttonStyle(.plain)
.padding(.horizontal, 16)
.padding(.top, 4)
.frame(maxWidth: .infinity, alignment: .leading)
```

**Step 5: Build and test**

Run: `make build`
Expected: PASS

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add mount damage flow with Reiten check in combat view"
```

---

### Task 4: Add command palette command for normal mode

**Files:**
- Modify: `Hesindion/Models/Hero.swift` (commandRegistry)
- Modify: `Hesindion/Views/HeroDetailView.swift` (handle the command)

**Step 1: Add the command to Hero.commandRegistry**

In `Hero.swift`, inside `commandRegistry`, after the pets `for` loop or at the end before `commands.append(AppCommand(... "Kampf" ...))`, add:

```swift
for pet in pets where type == "mount" || hasMount {
    // Only add for actual mounts
}
```

Actually, since `hasMount` is already a computed property, simply add before the "Kampf" command:

```swift
if hasMount, let mount = pets.first {
    commands.append(AppCommand(
        id: UUID(),
        name: "mountDamage",
        subparameter: mount.name,
        input: .integerAmount(
            label: L("mountDamage.sp"),
            min: 1,
            max: nil,
            initial: 1
        ),
        execute: { result in
            if case .integerAmount(let sp) = result {
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - sp)
            }
        }
    ))
}
```

Also update `AppCommand.displayName` or ensure "mountDamage" maps to the right display. Check if `displayName` just uses `L(name)` — if so, the existing `"mountTakesDamage"` string won't match since the command name is `"mountDamage"`. Either:
- Use name `"mountTakesDamage"` for the command, or
- Add a `"mountDamage"` localization key that maps to the same text.

**Step 2: Handle the command in HeroDetailView**

In `HeroDetailView.swift`, in the `.onChange(of: activeCommand?.id)` handler, add a case for the mount damage command. This needs to:
1. Apply the SP (already done by `execute`)
2. Open a Reiten check with the penalty

Add state variables:

```swift
@State private var mountDamageSP: Int = 0
@State private var showMountDamageReitenCheck = false
```

In the onChange handler, add before `guard cmd.name == "Probe"`:

```swift
if cmd.name == "mountDamage" {
    if case .integerAmount(let label, _, _, _) = cmd.input {
        // The execute callback already applied the damage.
        // We need the SP amount to compute penalty — store it from activeCommand.
    }
    // Actually, the command modal calls execute with the amount, then we handle here.
    // We need to capture the SP. Simplest: store it and show the check.
    activeCommand = nil
    return
}
```

Hmm, the issue is that `onChange` fires when activeCommand changes, but the execute callback runs when the user confirms in CommandModal. The flow is:
1. User selects command → `activeCommand` set → CommandModal appears
2. User enters SP, taps confirm → `command.execute(.integerAmount(sp))` runs → `activeCommand = nil`
3. `onChange` fires with `nil`

So we need a different approach. The simplest: make the `execute` closure also set the state for showing the Reiten check:

Since `execute` is a closure, we can capture `self` state updates — but these are value types in SwiftUI. Instead, use a dedicated sheet/overlay triggered by a flag that the command sets.

Better approach: Add a `@State private var mountDamagePenalty: Int? = nil` and show a TalentProbeModal overlay when it's non-nil. The command's execute closure sets this via a callback.

Actually, the cleanest pattern matching existing code (like Regenerieren): handle the command name in `onChange`, show a sheet. The SP input + Reiten check can be a single sheet similar to RegenerierenSheet.

Create a `MountDamageSheet` in `CommandPaletteOverlay.swift` that combines SP input + Reiten check. This avoids fighting the command palette flow.

```swift
// In HeroDetailView:
@State private var showMountDamageSheet = false

// In onChange:
if cmd.name == "mountDamage" {
    showMountDamageSheet = true
    activeCommand = nil
    return
}

// Add sheet:
.sheet(isPresented: $showMountDamageSheet) {
    if let mount = hero.pets.first {
        MountDamageSheet(hero: hero, mount: mount)
            .presentationCornerRadius(0)
            .presentationDetents([.large])
    }
}
```

**Step 3: Create MountDamageSheet**

Add to `CommandPaletteOverlay.swift` (where RegenerierenSheet lives):

```swift
struct MountDamageSheet: View {
    let hero: Hero
    let mount: Pet
    @Environment(\.dismiss) private var dismiss

    @State private var spAmount: Int = 1
    @State private var damageApplied = false
    @State private var showingProbeModal = false
    @State private var probeSucceeded: Bool? = nil

    private var penalty: Int { spAmount / 5 }

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("mountTakesDamage"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupCombat)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 16) {
                if !damageApplied {
                    spInput
                } else {
                    reitenCheckContent
                }
            }
            .padding(16)

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty
                )
            }
        }
    }

    private var spInput: some View {
        VStack(spacing: 12) {
            Text(mount.name)
                .font(.system(.title3, weight: .bold))

            HStack(spacing: 0) {
                Button { if spAmount > 1 { spAmount -= 1 } } label: {
                    Text("−")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat.opacity(0.3))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Text("\(spAmount)")
                    .font(.system(.largeTitle, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Button { spAmount += 1 } label: {
                    Text("+")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat.opacity(0.3))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }

            Text(L("mountDamage.sp"))
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.secondary)

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Color.groupCombat)
            } else {
                Text(L("mountDamage.noPenalty"))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button {
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)
                withAnimation { damageApplied = true }
            } label: {
                Text(L("mountDamage.apply"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.groupCombat)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var reitenCheckContent: some View {
        if let talent = reitenTalent {
            if let succeeded = probeSucceeded {
                resultView(succeeded: succeeded)
            } else {
                rollPromptView
            }
        } else {
            manualCheckView
        }
    }

    private func resultView(succeeded: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

            Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                .font(.system(.title3, weight: .bold))

            if !succeeded {
                Text(L("mountDamage.sturz"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Color.groupCombat)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.groupCombat.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
            }

            Button { dismiss() } label: {
                Image(systemName: "checkmark")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.groupCombat)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
    }

    private var rollPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dice.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.groupCombat)

            Text(L("reitenCheck"))
                .font(.system(.title3, weight: .bold))

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Color.groupCombat)
            }

            Button { showingProbeModal = true } label: {
                Text(L("rollReitenCheck"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.groupCombat)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
    }

    private var manualCheckView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.groupCombat)

            Text(L("reitenCheckPrompt"))
                .font(.system(.title3, weight: .bold))

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Color.groupCombat)
            }

            HStack(spacing: 12) {
                Button { probeSucceeded = false } label: {
                    Text(L("no"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button { probeSucceeded = true } label: {
                    Text(L("yes"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

**Step 4: Remove the mountDamage AppCommand from commandRegistry**

Since we're using a sheet (like Regenerieren) instead of the standard CommandModal, the command in the registry doesn't need an `input` or `execute` — it just needs to exist so the user can find it:

```swift
if hasMount {
    commands.append(AppCommand(
        id: UUID(),
        name: "mountTakesDamage",
        subparameter: nil,
        input: nil,
        execute: { _ in }
    ))
}
```

**Step 5: Build and test**

Run: `make build`
Expected: PASS

**Step 6: Commit**

```bash
git add Hesindion/Views/CommandPaletteOverlay.swift Hesindion/Models/Hero.swift Hesindion/Views/HeroDetailView.swift
git commit -m "feat: add mount damage command with Reiten check in normal mode"
```

---

### Task 5: Build, smoke test, update docs

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Full build**

Run: `make build`
Expected: PASS

**Step 2: Update CHANGELOG.md**

Add under `[Unreleased]` → `### Added`:

```markdown
- Mount damage with automatic Reiten (Kampfmanöver) check — penalty scales +1 per 5 SP; Sturz warning on failure
- "Reittier erleidet Schaden" command in command palette for normal mode
- TalentProbeModal now accepts an initial modifier for pre-applied penalties
```

**Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for mount damage Reiten check feature"
```
