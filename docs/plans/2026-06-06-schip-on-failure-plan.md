# Schip-on-Failure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** On a failed talent or spell check, let the player spend one Schicksalspunkt (Schip) to reroll dice they choose (all selected by default), mirroring the existing combat reroll affordance.

**Architecture:** The feature lives entirely in `Hesindion/Views/SkillCheckModal.swift` — the single view behind `TalentProbeModal` and `SpellProbeModal`. We add two `@State` fields, make the locked dice boxes selectable on a qualifying failure, render a golden reroll button below the summary bar, and add a `reroll()` that rerolls only selected dice. Snapshot tests use a small `previewFinalRolls` init seam to render the failure state deterministically.

**Tech Stack:** SwiftUI, SwiftData, swift-snapshot-testing, XCTest. Build/test via Makefile (`make build`, `make test-ui`, `make test-ui-record`).

**Design doc:** `docs/plans/2026-06-06-schip-on-failure-design.md`

**Conventions:** See `AGENTS.md`. Update `CHANGELOG.md` (already done for this feature). All UI strings go through `L(_:)` in `Hesindion/Theme/Strings.swift` (EN + DE tables). Commit frequently.

---

## Reference: current relevant code

`SkillCheckModal.swift` today:
- State: `modifiers`, `displayRolls`, `finalRolls: [Int]?`, `animationTask`.
- Dice row (`probeContent()`, ~L162-169) is one `HStack` of `diceBox(value:isAnimating:)` with `.onTapGesture { roll() }`.
- Summary bar rendered at ~L180-183.
- `CheckResult` enum: `.kritischerPatzer`, `.kritischerErfolg`, `.qs(Int)`. Failure = `.qs(0)`.
- `roll()` (~L352) rerolls all three dice, computes result, fires `onResult`, inserts a `TalentCheckPayload` `LogEntry`.
- `hero.derivedValues?.schicksalspunkte.current` is the Schip count (mutable).

Existing combat precedent: `CombatExecutionView.swift` L121-145 (golden button) and L696-713 (`logSchipUsed`).

---

## Task 0: Add localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` (EN table near L334 `"schip.label"`, DE table near L774)

**Step 1: Add the EN string**

In the English table, after the `"schip.label"` line (~L334), add:

```swift
        "schip.remaining":              "Fate Points left",
```

**Step 2: Add the DE string**

In the German table, after the `"schip.label"` line (~L774), add:

```swift
        "schip.remaining":              "Schips übrig",
```

(`L(_:)` takes no format args, so the count is interpolated separately: `"\(n) \(L("schip.remaining"))"`.)

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add schip.remaining localization string"
```

---

## Task 1: Add reroll state, eligibility helpers, and the preview seam

**Files:**
- Modify: `Hesindion/Views/SkillCheckModal.swift`

**Step 1: Add state fields**

After `@State private var animationTask` (~L41) add:

```swift
    @State private var schipUsed = false
    @State private var rerollSelection: Set<Int> = [0, 1, 2]  // all dice selected by default
```

**Step 2: Add the preview/test seam to the initializer**

Add a defaulted parameter so tests and SwiftUI previews can render a locked result deterministically. Update the `init` signature to add (before `initialModifier`):

```swift
        previewFinalRolls: [Int]? = nil,
```

and inside `init`, after `_modifiers = State(...)`:

```swift
        _finalRolls = State(initialValue: previewFinalRolls)
```

**Step 3: Add eligibility helpers**

Below the `CheckResult` enum (~after L296) add:

```swift
    private var schipsRemaining: Int {
        hero.derivedValues?.schicksalspunkte.current ?? 0
    }

    /// Schip reroll is offered only on a regular failure (QS 0) — not on a
    /// critical botch and not on any success. Mirrors the combat decision.
    private func isRerollEligible(_ result: CheckResult) -> Bool {
        guard case .qs(0) = result else { return false }
        return !schipUsed && schipsRemaining > 0
    }
```

**Step 4: Build to verify it compiles**

Run: `make build`
Expected: build succeeds (no behavior change yet).

**Step 5: Commit**

```bash
git add Hesindion/Views/SkillCheckModal.swift
git commit -m "feat: add schip reroll state and eligibility to SkillCheckModal"
```

---

## Task 2: Make the dice boxes reroll-selectable on a qualifying failure

**Files:**
- Modify: `Hesindion/Views/SkillCheckModal.swift`

**Step 1: Teach `diceBox` to show a selection highlight**

Replace `diceBox(value:isAnimating:)` (~L239) with a version that takes a `selectable`/`selected` state and draws a golden border when selected:

```swift
    private func diceBox(value: Int, isAnimating: Bool, selected: Bool) -> some View {
        Text("\(value)")
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isAnimating ? config.accentColor.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
            .overlay(
                Rectangle().stroke(
                    selected ? Color(red: 0.6, green: 0.5, blue: 0.0) : Color.clear,
                    lineWidth: 3
                )
            )
    }
```

**Step 2: Update the dice row to drive selection**

Replace the dice row block (~L162-169). Compute eligibility once, render per-die taps:

```swift
            // Dice row — tap to roll; once failed with Schips available, tap to
            // toggle which dice the Schip reroll will replace.
            let rerollEligible = hasResult && isRerollEligible(computeResult(rolls: fr))
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    diceBox(
                        value: rolls[i],
                        isAnimating: !hasResult,
                        selected: rerollEligible && rerollSelection.contains(i)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !hasResult {
                            roll()
                        } else if rerollEligible {
                            if rerollSelection.contains(i) {
                                rerollSelection.remove(i)
                            } else {
                                rerollSelection.insert(i)
                            }
                        }
                    }
                }
            }
```

(Removes the old whole-row `.onTapGesture { roll() }`; tapping any die still rolls when no result is locked yet.)

**Step 3: Build**

Run: `make build`
Expected: build succeeds. Manually: a failed check with Schips shows three gold-outlined dice; tapping a die toggles its outline.

**Step 4: Commit**

```bash
git add Hesindion/Views/SkillCheckModal.swift
git commit -m "feat: make SkillCheckModal dice selectable for schip reroll"
```

---

## Task 3: Add the Schip reroll button + remaining caption

**Files:**
- Modify: `Hesindion/Views/SkillCheckModal.swift`

**Step 1: Render the button below the summary bar**

In `probeContent()`, after the summary-bar block (~L182-183), add (inside the outer `VStack`):

```swift
            // Schip reroll affordance — only on a regular failure with Schips left.
            if hasResult, isRerollEligible(computeResult(rolls: fr)) {
                Button {
                    reroll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(L("schip.reroll"))
                    }
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.6, green: 0.5, blue: 0.0))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .disabled(rerollSelection.isEmpty)
                .opacity(rerollSelection.isEmpty ? 0.5 : 1)

                Text("\(schipsRemaining) \(L("schip.remaining"))")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
```

**Step 2: Add a temporary stub so it compiles**

`reroll()` doesn't exist yet. Add a stub right after `roll()` to keep the build green until Task 4:

```swift
    private func reroll() { /* implemented in next task */ }
```

**Step 3: Build**

Run: `make build`
Expected: succeeds. Button appears below the summary bar on a failed check, disabled when no dice selected.

**Step 4: Commit**

```bash
git add Hesindion/Views/SkillCheckModal.swift
git commit -m "feat: add schip reroll button to SkillCheckModal"
```

---

## Task 4: Implement selective reroll + logging

**Files:**
- Modify: `Hesindion/Views/SkillCheckModal.swift`
- Modify: `Hesindion/Models/LogEntry.swift` (add optional `schipReroll` flag)

**Step 1: Add a backward-compatible log flag**

In `LogEntry.swift`, in `TalentCheckPayload` (L28-36), add an optional field (Optional so old persisted entries without the key still decode):

```swift
struct TalentCheckPayload: Codable, Reversible {
    var talentName: String
    var qualityLevel: Int
    var succeeded: Bool
    var schipReroll: Bool? = nil

    func reverse(on hero: Hero) {
        // no-op: talent checks don't mutate hero state
    }
}
```

**Step 2: Refactor `roll()` to share result/log code, then implement `reroll()`**

Replace the `reroll()` stub from Task 3 with the real implementation. It spends a Schip, rerolls only the selected dice (keeping the rest), recomputes, fires `onResult`, and logs a fresh `TalentCheckPayload` marked `schipReroll: true`:

```swift
    private func reroll() {
        guard let current = finalRolls, !schipUsed, !rerollSelection.isEmpty else { return }
        guard schipsRemaining > 0 else { return }

        // Spend one Schip and lock out further rerolls this check.
        hero.derivedValues?.schicksalspunkte.current -= 1
        schipUsed = true

        // Reroll only the selected dice; keep the others.
        var newRolls = current
        for i in rerollSelection { newRolls[i] = Int.random(in: 1...20) }
        finalRolls = newRolls

        emitResult(rolls: newRolls, schipReroll: true)
    }
```

**Step 3: Extract `emitResult` from `roll()` (DRY)**

`roll()` currently computes the result, fires `onResult`, and inserts the log entry inline (~L356-391). Extract that tail into a helper both `roll()` and `reroll()` call. Replace the body after `finalRolls = rolls` in `roll()` with `emitResult(rolls: rolls, schipReroll: false)`, and add:

```swift
    private func emitResult(rolls: [Int], schipReroll: Bool) {
        let result = computeResult(rolls: rolls)
        let qs: Int
        let succeeded: Bool
        let isCritSuccess: Bool
        let isCritFailure: Bool
        switch result {
        case .kritischerPatzer: qs = 0; succeeded = false; isCritSuccess = false; isCritFailure = true
        case .kritischerErfolg: qs = 6; succeeded = true; isCritSuccess = true; isCritFailure = false
        case .qs(let n): qs = n; succeeded = n > 0; isCritSuccess = false; isCritFailure = false
        }

        let engineMod = config.modifierLines.reduce(0) { $0 + $1.value }
        let excesses = (0..<3).map { i -> Int in
            let excess = rolls[i] - (config.checkAttributes[i].value + modifiers[i] + engineMod)
            return excess > 0 ? excess : 0
        }
        let remaining = config.skillValue - excesses.reduce(0, +)

        onResult?(SkillCheckResult(
            rolls: rolls,
            qualityLevel: qs,
            succeeded: succeeded,
            isCriticalSuccess: isCritSuccess,
            isCriticalFailure: isCritFailure,
            remainingSkillPoints: remaining
        ))

        let entry = LogEntry.create(
            kind: config.logKind,
            payload: TalentCheckPayload(
                talentName: config.name,
                qualityLevel: qs,
                succeeded: succeeded,
                schipReroll: schipReroll ? true : nil
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
```

Resulting `roll()`:

```swift
    private func roll() {
        guard finalRolls == nil else { return }
        animationTask?.cancel()
        let rolls = (0..<3).map { _ in Int.random(in: 1...20) }
        finalRolls = rolls
        emitResult(rolls: rolls, schipReroll: false)
    }
```

**Step 4: Build**

Run: `make build`
Expected: succeeds.

**Step 5: Manual smoke check (simulator)**

Run: `make run`
Open a hero with Schips (e.g. Boronmir, 3 Schips), roll a talent check until it fails, confirm: dice are gold-outlined, deselect one, tap "Schip: Neuer Wurf" → one Schip is spent, only selected dice change, result recomputes, button disappears, LogPanel shows the reroll result.

**Step 6: Commit**

```bash
git add Hesindion/Views/SkillCheckModal.swift Hesindion/Models/LogEntry.swift
git commit -m "feat: implement selective schip reroll on failed skill checks"
```

---

## Task 5: Snapshot tests for the new states

**Files:**
- Create: `HesindionTests/Snapshots/SkillCheckModalSnapshotTests.swift`

**Step 1: Write the test**

Uses the `previewFinalRolls` seam to lock a guaranteed failure. With three `20` rolls against any normal attribute spread, the check fails (`QS 0`). Boronmir has 3 Schips, so the button renders.

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class SkillCheckModalSnapshotTests: XCTestCase {

    private func failingConfig() -> SkillCheckConfig {
        SkillCheckConfig(
            title: "Talent",
            name: "Klettern",
            skillValue: 5,
            checkAttributes: [("MU", 12), ("GE", 12), ("KK", 12)],
            accentColor: .groupCombat,
            modifierLines: [],
            logKind: "talentCheck"
        )
    }

    @MainActor
    func testFailureWithSchipsAvailable() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)  // 3 Schips

        let view = SkillCheckModal(
            config: failingConfig(),
            hero: hero,
            onDismiss: {},
            previewFinalRolls: [20, 20, 20]  // guaranteed failure
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "failure-schips-available")
    }

    @MainActor
    func testFailureWithNoSchips() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.derivedValues?.schicksalspunkte.current = 0  // exhaust Schips

        let view = SkillCheckModal(
            config: failingConfig(),
            hero: hero,
            onDismiss: {},
            previewFinalRolls: [20, 20, 20]
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "failure-no-schips")  // button absent
    }
}
```

**Step 2: Record the baseline snapshots**

Run: `make test-ui-record`
Expected: new reference images written under `HesindionTests/Snapshots/__Snapshots__/SkillCheckModalSnapshotTests/`. Inspect them: the "schips-available" images must show the gold-outlined dice + golden "Schip: Neuer Wurf" button + "3 Schips übrig"; the "no-schips" images must show neither.

**Step 3: Run the tests against the baseline**

Run: `make test-ui`
Expected: PASS.

**Step 4: Commit**

```bash
git add HesindionTests/Snapshots/SkillCheckModalSnapshotTests.swift HesindionTests/Snapshots/__Snapshots__/SkillCheckModalSnapshotTests
git commit -m "test: snapshot tests for schip reroll on failed skill checks"
```

---

## Task 6: Full verification + changelog confirm

**Files:**
- Verify: `CHANGELOG.md` (entry already added under `[Unreleased]` — confirm it reads correctly)

**Step 1: Run the unit test suite**

Run: `make test`
Expected: PASS (no engine changes; confirms nothing regressed).

**Step 2: Run the snapshot suite**

Run: `make test-ui`
Expected: PASS (all existing + new snapshots).

**Step 3: Confirm CHANGELOG**

Verify `CHANGELOG.md` `[Unreleased] → Added` contains the Schip reroll line.

**Step 4: Final commit (if anything outstanding)**

```bash
git status
# commit any stragglers
```

---

## Done criteria

- Failed talent/spell check with Schips left shows gold-outlined selectable dice (all selected) + golden reroll button + "N Schips übrig".
- Reroll spends exactly one Schip, rerolls only selected dice, recomputes, logs a `schipReroll` entry, and is offered only once per check.
- No button on success, on a critical botch, or with zero Schips.
- `make build`, `make test`, `make test-ui` all green.
