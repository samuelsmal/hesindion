# Dice Roll Command Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add a general-purpose "Würfeln" command to the command palette that rolls any dice combination and logs results.

**Architecture:** New `DiceRollSheet` view presented from `HeroDetailView` when the "Würfeln" command fires. Uses existing tumble animation pattern from `RegenerierenSheet`. Logs via `LogEntry.create` with a new `DiceRollPayload`.

**Tech Stack:** SwiftUI, SwiftData

---

### Task 1: Add DiceRollPayload to LogEntry

**Files:**
- Modify: `Hesindion/Models/LogEntry.swift`

**Step 1: Add the payload struct**

After `MountLPChangePayload` (line ~90), add:

```swift
struct DiceRollPayload: Codable {
    var count: Int
    var sides: Int
    var results: [Int]
    var total: Int
}
```

No `Reversible` conformance needed — dice rolls don't mutate hero state.

**Step 2: Add "diceRoll" to the `reversible()` switch**

Not strictly needed (default returns nil), but for clarity add a case before `default`:

```swift
case "diceRoll":
    return nil
```

**Step 3: Commit**

```bash
git add Hesindion/Models/LogEntry.swift
git commit -m "feat: add DiceRollPayload to LogEntry"
```

---

### Task 2: Add log rendering for diceRoll entries

**Files:**
- Modify: `Hesindion/Views/LogPanelView.swift`

**Step 1: Add icon mapping**

In `iconName(for:)` (line ~143), add before `default`:

```swift
case "diceRoll":       "dice.fill"
```

In `iconColor(for:)` (line ~154), add before `default`:

```swift
case "diceRoll":       .secondary
```

**Step 2: Add entry description**

In `entryDescription(_:)` (line ~167), add a new case before `default`:

```swift
case "diceRoll":
    guard let p = entry.decodePayload(DiceRollPayload.self) else { return "—" }
    let dice = "\(p.count)W\(p.sides)"
    if p.count == 1 {
        return "\(dice) = \(p.total)"
    }
    let parts = p.results.map(String.init).joined(separator: " + ")
    return "\(dice): \(parts) = \(p.total)"
```

**Step 3: Commit**

```bash
git add Hesindion/Views/LogPanelView.swift
git commit -m "feat: render diceRoll entries in log panel"
```

---

### Task 3: Add localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add English fallback strings**

In the `englishFallback` dictionary, in the "Misc UI" section (around line 291), add:

```swift
"diceRoll":             "Roll Dice",
"diceCount":            "Count",
"diceSides":            "Sides",
```

**Step 2: Add German translations**

In the `translations` dictionary, in the "Misc UI" section (around line 726), add:

```swift
"diceRoll":             "Würfeln",
"diceCount":            "Anzahl",
"diceSides":            "Seiten",
```

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add dice roll localization strings"
```

---

### Task 4: Create DiceRollSheet view

**Files:**
- Create: `Hesindion/Views/DiceRollSheet.swift`

**Step 1: Create the file**

```swift
import SwiftUI
import SwiftData

struct DiceRollSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let allowedSides = [3, 4, 6, 8, 10, 12, 20]

    @State private var diceCount: Int = 1
    @State private var sidesIndex: Int = 2 // default W6
    @State private var rollResults: [Int]? = nil
    @State private var displayValues: [Int] = [1]
    @State private var animTask: Task<Void, Never>? = nil

    private var sides: Int { Self.allowedSides[sidesIndex] }
    private var total: Int { rollResults?.reduce(0, +) ?? 0 }
    private var isRolled: Bool { rollResults != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L("diceRoll"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 8) {
                configSection
                diceDisplay
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                if isRolled {
                    resultSummary
                    confirmButton
                }
            }
            .padding(16)

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear { animTask?.cancel() }
    }

    // MARK: - Config Section

    private var configSection: some View {
        HStack(spacing: 12) {
            stepperRow(
                label: L("diceCount"),
                value: diceCount,
                onDecrement: { if diceCount > 1 { diceCount -= 1; syncDisplayValues() } },
                onIncrement: { if diceCount < 10 { diceCount += 1; syncDisplayValues() } }
            )
            stepperRow(
                label: L("diceSides"),
                displayValue: "W\(sides)",
                onDecrement: { if sidesIndex > 0 { sidesIndex -= 1 } },
                onIncrement: { if sidesIndex < Self.allowedSides.count - 1 { sidesIndex += 1 } }
            )
        }
        .disabled(isRolled)
        .opacity(isRolled ? 0.5 : 1)
    }

    private func stepperRow(
        label: String,
        value: Int? = nil,
        displayValue: String? = nil,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onDecrement) {
                    Image(systemName: "arrow.down")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(isRolled ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isRolled ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(displayValue ?? "\(value ?? 0)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(minWidth: 48)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Button(action: onIncrement) {
                    Image(systemName: "arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(isRolled ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isRolled ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .fixedSize(horizontal: false, vertical: true)

            Text(label)
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Dice Display

    private var diceDisplay: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                ForEach(Array((rollResults ?? displayValues).enumerated()), id: \.offset) { _, value in
                    Text("\(value)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                }
            }
            if !isRolled {
                Text(L("tapToRoll"))
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(!isRolled ? Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }

    // MARK: - Result Summary

    private var resultSummary: some View {
        let results = rollResults ?? []
        let dice = "\(diceCount)W\(sides)"
        let formulaStr: String
        if results.count == 1 {
            formulaStr = "\(dice) = \(total)"
        } else {
            let parts = results.map(String.init).joined(separator: " + ")
            formulaStr = "\(dice) = \(parts) = \(total)"
        }

        return Text(formulaStr)
            .font(.system(.body, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            if let results = rollResults {
                let payload = DiceRollPayload(
                    count: diceCount,
                    sides: sides,
                    results: results,
                    total: total
                )
                let entry = LogEntry.create(kind: "diceRoll", payload: payload, hero: hero)
                modelContext.insert(entry)
            }
            dismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animation & Rolling

    private func syncDisplayValues() {
        displayValues = (0..<diceCount).map { _ in Int.random(in: 1...sides) }
    }

    private func startAnimation() {
        syncDisplayValues()
        animTask = Task { @MainActor in
            while !Task.isCancelled && rollResults == nil {
                syncDisplayValues()
                do { try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval) } catch { break }
            }
        }
    }

    private func rollDice() {
        guard rollResults == nil else { return }
        animTask?.cancel()
        rollResults = (0..<diceCount).map { _ in Int.random(in: 1...sides) }
    }
}
```

**Step 2: Commit**

```bash
git add Hesindion/Views/DiceRollSheet.swift
git commit -m "feat: add DiceRollSheet view"
```

---

### Task 5: Register command and wire up sheet

**Files:**
- Modify: `Hesindion/Models/Hero.swift`
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Add "Würfeln" command to registry**

In `Hero.swift`, in `commandRegistry` (around line 510, just before the "Einstellungen" command), add:

```swift
commands.append(AppCommand(
    id: UUID(),
    name: "Würfeln",
    subparameter: nil,
    input: nil,
    execute: { _ in }
))
```

**Step 2: Add state and sheet to HeroDetailView**

In `HeroDetailView.swift`:

1. Add state variable (around line 27, after `showMountHealingSheet`):

```swift
@State private var showDiceRollSheet = false
```

2. Add sheet modifier (after the `showMountHealingSheet` sheet, around line 162):

```swift
.sheet(isPresented: $showDiceRollSheet) {
    DiceRollSheet(hero: hero)
        .presentationCornerRadius(0)
        .presentationDetents([.medium])
}
```

3. Add command handler (in the `onChange(of: activeCommand?.id)` block, before the "Einstellungen" handler around line 206):

```swift
if cmd.name == "Würfeln" {
    showDiceRollSheet = true
    activeCommand = nil
    return
}
```

**Step 3: Commit**

```bash
git add Hesindion/Models/Hero.swift Hesindion/Views/HeroDetailView.swift
git commit -m "feat: wire Würfeln command to DiceRollSheet"
```

---

### Task 6: Build and verify

**Step 1: Build**

```bash
make run
```

**Step 2: Manual test**

1. Open command palette, search "Würfeln"
2. Verify config steppers (count 1–10, sides cycle through 3/4/6/8/10/12/20)
3. Tap to roll, verify tumble animation stops and results appear
4. Confirm, check log panel shows the roll
5. Test with multiple dice (e.g. 3W20)

**Step 3: Commit any fixes if needed**

---

### Task 7: Update changelog

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add entry under [Unreleased] → Added**

```markdown
- General-purpose dice roller ("Würfeln") command with configurable count and sides, tumble animation, and action log integration
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add dice roll command to changelog"
```
