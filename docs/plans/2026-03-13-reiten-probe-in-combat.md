# Reiten Probe in Combat — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Yes/No "Did the Reiten check succeed?" dialog in the mount pre-check combat flow with the actual TalentProbeModal dice-rolling UI.

**Architecture:** Add an optional `onRolled` callback to `TalentProbeModal` that fires with success/failure after the user rolls. `CombatMountPreCheckView` presents the modal after galopp confirmation, tracks the result, and routes the combat flow on dismiss.

**Tech Stack:** SwiftUI, SwiftData

---

### Task 1: Add `onRolled` callback to TalentProbeModal

**Files:**
- Modify: `Hesindion/Views/TalentProbeModal.swift:6-9` (struct properties)
- Modify: `Hesindion/Views/TalentProbeModal.swift:313-317` (roll function)

**Step 1: Add optional callback property**

In `TalentProbeModal`, add a new property after `onDismiss`:

```swift
struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil   // ← ADD THIS
```

**Step 2: Fire callback in `roll()`**

Replace the `roll()` function to compute the result and fire the callback:

```swift
private func roll() {
    guard finalRolls == nil else { return }
    animationTask?.cancel()
    let rolls = (0..<3).map { _ in Int.random(in: 1...20) }
    finalRolls = rolls
    if let onRolled, let data = probeData {
        let result = computeResult(rolls: rolls, attrValues: data.values, mods: modifiers)
        let succeeded: Bool
        switch result {
        case .kritischerPatzer: succeeded = false
        case .kritischerErfolg: succeeded = true
        case .qs(let n): succeeded = n > 0
        }
        onRolled(succeeded)
    }
}
```

**Step 3: Build & verify**

Run: `make build`
Expected: Compiles with no errors. Existing TalentProbeModal usage in HeroDetailView is unaffected (default `nil` for `onRolled`).

**Step 4: Commit**

```
feat: add onRolled callback to TalentProbeModal
```

---

### Task 2: Replace Yes/No Reiten check with TalentProbeModal in combat flow

**Files:**
- Modify: `Hesindion/Views/CombatView.swift:3025-3155` (CombatMountPreCheckView)

**Step 1: Add state for probe result tracking**

In `CombatMountPreCheckView`, add state:

```swift
private struct CombatMountPreCheckView: View {
    let hero: Hero
    let onSuccess: CombatStep
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var galoppConfirmed = false
    @State private var probeSucceeded: Bool? = nil     // ← ADD
    @State private var showingProbeModal = false        // ← ADD
```

**Step 2: Add computed property to find Reiten talent**

```swift
private var reitenTalent: Talent? {
    hero.talents.first { $0.name == "Reiten" }
}
```

**Step 3: Replace `reitenCheck` view**

Replace the entire `reitenCheck` computed property. If the hero has the Reiten talent, show a button that opens the TalentProbeModal. If not, fall back to the existing Yes/No.

```swift
private var reitenCheck: some View {
    VStack(spacing: 16) {
        if let talent = reitenTalent {
            // Hero has Reiten talent — show probe trigger or result
            if let succeeded = probeSucceeded {
                // Roll completed — show result and action button
                Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

                Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                    .font(.system(.title3, weight: .bold))
                    .multilineTextAlignment(.center)

                Button {
                    if succeeded {
                        step = onSuccess
                    } else {
                        step = .attackChoice
                    }
                } label: {
                    Text(succeeded ? L("continue") : L("back"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(succeeded ? combatAccent : Color.dsaDark)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            } else {
                // No roll yet — prompt to open probe modal
                Image(systemName: "dice.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(combatAccent)

                Text(L("reitenCheck"))
                    .font(.system(.title3, weight: .bold))
                    .multilineTextAlignment(.center)

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
            // Fallback: hero has no Reiten talent — use original Yes/No
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheckPrompt"))
                .font(.system(.title3, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
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
                    step = onSuccess
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
```

**Step 4: Add TalentProbeModal overlay to body**

In the `body` of `CombatMountPreCheckView`, wrap existing content and add the modal overlay:

```swift
var body: some View {
    VStack(spacing: 0) {
        // ... existing header and content ...
    }
    .overlay {
        if showingProbeModal, let talent = reitenTalent {
            TalentProbeModal(
                talent: talent,
                hero: hero,
                onDismiss: { showingProbeModal = false },
                onRolled: { succeeded in probeSucceeded = succeeded }
            )
        }
    }
}
```

**Step 5: Build & verify**

Run: `make build`
Expected: Compiles. Mount pre-check now shows the TalentProbeModal after galopp confirmation.

**Step 6: Commit**

```
feat: use TalentProbeModal for Reiten check in combat
```

---

### Task 3: Add localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add new string keys**

Add to the English dictionary (near existing Reiten strings):

```swift
"reitenCheckPassed":    "Reiten check passed!",
"reitenCheckFailed":    "Reiten check failed!",
"rollReitenCheck":      "Roll Reiten Check",
```

Add to the German dictionary:

```swift
"reitenCheckPassed":    "Reiten-Probe bestanden!",
"reitenCheckFailed":    "Reiten-Probe nicht bestanden!",
"rollReitenCheck":      "Reiten-Probe würfeln",
```

**Step 2: Verify `continue` and `back` strings exist**

Check that `L("continue")` and `L("back")` already exist. If not, add them.

**Step 3: Build & verify**

Run: `make build`

**Step 4: Commit**

```
feat: add localization strings for Reiten probe in combat
```

---

### Task 4: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add entry under `[Unreleased]`**

```markdown
### Changed
- Mount combat: Reiten check now uses the full talent probe modal with dice rolls instead of a simple Yes/No dialog
```

**Step 2: Commit**

```
docs: update CHANGELOG for Reiten probe in combat
```
