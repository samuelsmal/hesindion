# Action Log & Split Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add an event-sourcing action log and replace the notes-only right sidebar with a flexible split-screen layout supporting Notes, Logs, and Rules panels.

**Architecture:** SwiftData `LogEntry` model with JSON-encoded payloads per event kind. `SplitContentLayout` replaces `ContentWithNotesLayout` with orientation-aware 50/50 split. New commands for healing and mount healing.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

---

### Task 1: Create LogEntry Model and Payload Types

**Files:**
- Create: `Hesindion/Models/LogEntry.swift`

**Step 1: Create the LogEntry model and all payload types**

```swift
import Foundation
import SwiftData

// MARK: - LogEntry

@Model
final class LogEntry {
    var id: UUID
    var timestamp: Date
    var kind: String
    var payload: Data

    @Relationship var hero: Hero?

    init(id: UUID = UUID(), timestamp: Date = Date(), kind: String, payload: Data, hero: Hero? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.payload = payload
        self.hero = hero
    }
}

// MARK: - Payload Types

struct TalentCheckPayload: Codable {
    let talentName: String
    let qualityLevel: Int
    let succeeded: Bool
}

enum CombatActionType: String, Codable {
    case attack
    case parry
    case dodge
    case damageDealt
    case damageTaken
}

struct CombatActionPayload: Codable {
    let combatId: UUID
    let round: Int
    let action: CombatActionType
    let weaponName: String?
    let rollValue: Int?
    let damageDealt: Int?
    let damageTaken: Int?
    let lpChange: Int
}

struct HealingPayload: Codable {
    let source: String
    let lpRestored: Int
}

struct RestPayload: Codable {
    let lpRestored: Int
    let duration: String?
}

struct MountLPChangePayload: Codable {
    let petName: String
    let lpChange: Int
}

// MARK: - Reversible Protocol

protocol Reversible {
    func reverse(on hero: Hero)
}

extension TalentCheckPayload: Reversible {
    func reverse(on hero: Hero) {
        // No-op: talent checks are informational
    }
}

extension CombatActionPayload: Reversible {
    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        dv.lebensenergie.current = min(dv.lebensenergie.max, max(0, dv.lebensenergie.current - lpChange))
    }
}

extension HealingPayload: Reversible {
    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        dv.lebensenergie.current = min(dv.lebensenergie.max, max(0, dv.lebensenergie.current - lpRestored))
    }
}

extension RestPayload: Reversible {
    func reverse(on hero: Hero) {
        guard let dv = hero.derivedValues else { return }
        dv.lebensenergie.current = min(dv.lebensenergie.max, max(0, dv.lebensenergie.current - lpRestored))
    }
}

extension MountLPChangePayload: Reversible {
    func reverse(on hero: Hero) {
        guard let pet = hero.pets.first else { return }
        pet.currentLifeEnergy = min(pet.lifeEnergy, max(0, pet.currentLifeEnergy - lpChange))
    }
}

// MARK: - LogEntry Helpers

extension LogEntry {
    static func create<P: Codable>(kind: String, payload: P, hero: Hero) -> LogEntry {
        let data = try! JSONEncoder().encode(payload)
        return LogEntry(kind: kind, payload: data, hero: hero)
    }

    func decodePayload<P: Codable>(_ type: P.Type) -> P? {
        try? JSONDecoder().decode(type, from: payload)
    }

    func reversible() -> Reversible? {
        switch kind {
        case "talentCheck": return decodePayload(TalentCheckPayload.self)
        case "combatAction": return decodePayload(CombatActionPayload.self)
        case "healing": return decodePayload(HealingPayload.self)
        case "rest": return decodePayload(RestPayload.self)
        case "mountLPChange": return decodePayload(MountLPChangePayload.self)
        default: return nil
        }
    }
}
```

**Step 2: Verify file compiles**

Run: `make build`
Expected: Build succeeds (LogEntry is not yet registered in schema, so it won't be included yet)

**Step 3: Commit**

```bash
git add Hesindion/Models/LogEntry.swift
git commit -m "feat: add LogEntry model with payload types and Reversible protocol"
```

---

### Task 2: Add LogEntry Relationship to Hero

**Files:**
- Modify: `Hesindion/Models/Hero.swift:28` (add relationship after `pets`)

**Step 1: Add the logEntries relationship to Hero**

In `Hesindion/Models/Hero.swift`, after line 31 (`@Relationship(deleteRule: .cascade) var liturgies: [HeroSpell]`), add:

```swift
@Relationship(deleteRule: .cascade, inverse: \LogEntry.hero) var logEntries: [LogEntry] = []
```

No changes needed to `init` — SwiftData default `= []` handles it.

**Step 2: Commit**

```bash
git add Hesindion/Models/Hero.swift
git commit -m "feat: add logEntries cascade relationship to Hero"
```

---

### Task 3: Schema Migration to V3

**Files:**
- Create: `Hesindion/Migration/SchemaV3.swift`
- Modify: `Hesindion/Migration/MigrationPlan.swift`

**Step 1: Create SchemaV3**

```swift
import SwiftData

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Hero.self,
            PersonalData.self,
            Experience.self,
            Attributes.self,
            DerivedValues.self,
            Talent.self,
            CombatTechnique.self,
            MeleeWeapon.self,
            RangedWeapon.self,
            Armor.self,
            Shield.self,
            EquipmentItem.self,
            Money.self,
            Pet.self,
            Language.self,
            HeroSpell.self,
            LogEntry.self,
        ]
    }
}
```

**Step 2: Update MigrationPlan**

Replace contents of `Hesindion/Migration/MigrationPlan.swift`:

```swift
import SwiftData

enum HesindionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
```

**Step 3: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Hesindion/Migration/SchemaV3.swift Hesindion/Migration/MigrationPlan.swift
git commit -m "feat: add SchemaV3 with LogEntry migration"
```

---

### Task 4: Add Logging to TalentProbeModal

**Files:**
- Modify: `Hesindion/Views/TalentProbeModal.swift`

**Step 1: Add modelContext and emit log entry on roll**

In `TalentProbeModal`, add `@Environment(\.modelContext) private var modelContext` (it already imports SwiftData).

In the `roll()` function (line 324), after `finalRolls = rolls` and the `onRolled` callback block, add log entry creation:

```swift
// After the onRolled callback block, add:
if let data = probeData {
    let result = computeResult(rolls: rolls, attrValues: data.values, mods: modifiers)
    let qs: Int
    let succeeded: Bool
    switch result {
    case .kritischerPatzer: qs = 0; succeeded = false
    case .kritischerErfolg: qs = 6; succeeded = true
    case .qs(let n): qs = n; succeeded = n > 0
    }
    let entry = LogEntry.create(
        kind: "talentCheck",
        payload: TalentCheckPayload(talentName: talent.name, qualityLevel: qs, succeeded: succeeded),
        hero: hero
    )
    modelContext.insert(entry)
}
```

**Step 2: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Hesindion/Views/TalentProbeModal.swift
git commit -m "feat: log talent check results to action log"
```

---

### Task 5: Add Logging to RegenerierenSheet

**Files:**
- Modify: `Hesindion/Views/CommandPaletteOverlay.swift:152-156` (RegenerierenSheet confirm button)

**Step 1: Add modelContext to RegenerierenSheet**

Add `@Environment(\.modelContext) private var modelContext` to `RegenerierenSheet`.

**Step 2: Emit log entry on confirm**

In the confirm button action (line 153-155), before `dismiss()`:

```swift
let actualHealing = newLE - currentLE
if actualHealing > 0 {
    let entry = LogEntry.create(
        kind: "rest",
        payload: RestPayload(lpRestored: actualHealing, duration: nil),
        hero: hero
    )
    modelContext.insert(entry)
}
hero.derivedValues?.lebensenergie.current = newLE
dismiss()
```

**Step 3: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Hesindion/Views/CommandPaletteOverlay.swift
git commit -m "feat: log regeneration to action log"
```

---

### Task 6: Add Logging to MountDamageSheet

**Files:**
- Modify: `Hesindion/Views/CommandPaletteOverlay.swift:385-616` (MountDamageSheet)

**Step 1: Add modelContext to MountDamageSheet**

Add `@Environment(\.modelContext) private var modelContext` to `MountDamageSheet`.

**Step 2: Emit log entry when damage is applied**

In the damage application button (line 487), after `mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)`:

```swift
let entry = LogEntry.create(
    kind: "mountLPChange",
    payload: MountLPChangePayload(petName: mount.name, lpChange: -spAmount),
    hero: hero
)
modelContext.insert(entry)
```

**Step 3: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Hesindion/Views/CommandPaletteOverlay.swift
git commit -m "feat: log mount damage to action log"
```

---

### Task 7: Add Heilung (Healing) Command and Sheet

**Files:**
- Create: `Hesindion/Views/HeilungSheet.swift`
- Modify: `Hesindion/Models/Hero.swift` (command registry)
- Modify: `Hesindion/Views/HeroDetailView.swift` (wire up command)

**Step 1: Create HeilungSheet**

```swift
import SwiftUI
import SwiftData

struct HeilungSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var source: String = ""
    @State private var amount: Int = 1

    private var currentLE: Int { hero.derivedValues?.lebensenergie.current ?? 0 }
    private var maxLE: Int { hero.derivedValues?.lebensenergie.max ?? 0 }
    private var newLE: Int { min(currentLE + amount, maxLE) }
    private var actualHealing: Int { newLE - currentLE }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("healing"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 16) {
                TextField(L("healingSource"), text: $source)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                HStack(spacing: 0) {
                    Button { if amount > 1 { amount -= 1 } } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupPersonalData.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Text("\(amount)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button { amount += 1 } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupPersonalData.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                Text("LP")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("\(currentLE) + \(actualHealing) → \(newLE) / \(maxLE) LP")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    hero.derivedValues?.lebensenergie.current = newLE
                    let entry = LogEntry.create(
                        kind: "healing",
                        payload: HealingPayload(source: source.isEmpty ? "Heilung" : source, lpRestored: actualHealing),
                        hero: hero
                    )
                    modelContext.insert(entry)
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
            .padding(16)

            Spacer()
        }
    }
}
```

**Step 2: Add Heilung command to Hero.commandRegistry**

In `Hesindion/Models/Hero.swift`, in the `commandRegistry` computed property, after the "Regenerieren" command block (line 355), add:

```swift
commands.append(AppCommand(
    id: UUID(),
    name: "Heilung",
    subparameter: nil,
    input: nil,
    execute: { _ in }
))
```

**Step 3: Wire up in HeroDetailView**

In `Hesindion/Views/HeroDetailView.swift`:

1. Add state: `@State private var showHeilungSheet = false` (after line 21)

2. Add sheet modifier (after the `.sheet(isPresented: $showMountDamageSheet)` block, around line 126):
```swift
.sheet(isPresented: $showHeilungSheet) {
    HeilungSheet(hero: hero)
        .presentationCornerRadius(0)
        .presentationDetents([.medium])
}
```

3. Add command handler in `.onChange(of: activeCommand?.id)` (after the "Reittier: Schaden" handler, line 156):
```swift
if cmd.name == "Heilung" {
    showHeilungSheet = true
    activeCommand = nil
    return
}
```

**Step 4: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Hesindion/Views/HeilungSheet.swift Hesindion/Models/Hero.swift Hesindion/Views/HeroDetailView.swift
git commit -m "feat: add Heilung command with logging"
```

---

### Task 8: Add Mount Healing Command

**Files:**
- Modify: `Hesindion/Models/Hero.swift` (command registry)
- Modify: `Hesindion/Views/HeroDetailView.swift`
- Create: `Hesindion/Views/MountHealingSheet.swift`

**Step 1: Create MountHealingSheet**

```swift
import SwiftUI
import SwiftData

struct MountHealingSheet: View {
    let hero: Hero
    let mount: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var amount: Int = 1

    private var newLE: Int { min(mount.currentLifeEnergy + amount, mount.lifeEnergy) }
    private var actualHealing: Int { newLE - mount.currentLifeEnergy }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("mountHealing"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupEquipment)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 16) {
                Text(mount.name)
                    .font(.system(.title3, weight: .bold))

                HStack(spacing: 0) {
                    Button { if amount > 1 { amount -= 1 } } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupEquipment.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Text("\(amount)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button { amount += 1 } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupEquipment.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                Text("LP")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("\(mount.currentLifeEnergy) + \(actualHealing) → \(newLE) / \(mount.lifeEnergy) LP")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    mount.currentLifeEnergy = newLE
                    let entry = LogEntry.create(
                        kind: "mountLPChange",
                        payload: MountLPChangePayload(petName: mount.name, lpChange: actualHealing),
                        hero: hero
                    )
                    modelContext.insert(entry)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupEquipment)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Spacer()
        }
    }
}
```

**Step 2: Add command to Hero.commandRegistry**

In `Hesindion/Models/Hero.swift`, after the "Reittier: Schaden" command (inside the `if hasMount` block, line 453):

```swift
commands.append(AppCommand(
    id: UUID(),
    name: "Reittier: Heilung",
    subparameter: nil,
    input: nil,
    execute: { _ in }
))
```

**Step 3: Wire up in HeroDetailView**

1. Add state: `@State private var showMountHealingSheet = false`

2. Add sheet:
```swift
.sheet(isPresented: $showMountHealingSheet) {
    if let mount = hero.pets.first {
        MountHealingSheet(hero: hero, mount: mount)
            .presentationCornerRadius(0)
            .presentationDetents([.medium])
    }
}
```

3. Add command handler in `.onChange(of: activeCommand?.id)`:
```swift
if cmd.name == "Reittier: Heilung" {
    showMountHealingSheet = true
    activeCommand = nil
    return
}
```

**Step 4: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Hesindion/Views/MountHealingSheet.swift Hesindion/Models/Hero.swift Hesindion/Views/HeroDetailView.swift
git commit -m "feat: add mount healing command with logging"
```

---

### Task 9: Add Logging to CombatView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

This is the most complex integration. CombatView is a state machine. We need to:

1. Add `@Environment(\.modelContext) private var modelContext` to CombatView
2. Add `@State private var combatId = UUID()` and `@State private var currentRound: Int = 1` (for grouping log entries)
3. Log damage taken when `takeDamage` step confirms (search for where `dv.lebensenergie.current` is modified)
4. Log attack results when execution step shows results

**Step 1: Add state properties**

Add to CombatView's state properties:
```swift
@Environment(\.modelContext) private var modelContext
@State private var combatId = UUID()
```

**Step 2: Find and instrument damage application points**

Search CombatView for all places where `lebensenergie.current` is modified. Add log entries at each point:

```swift
// When hero takes damage (in takeDamage confirmation):
let entry = LogEntry.create(
    kind: "combatAction",
    payload: CombatActionPayload(
        combatId: combatId,
        round: currentRound,
        action: .damageTaken,
        weaponName: nil,
        rollValue: nil,
        damageDealt: nil,
        damageTaken: actualDamage,
        lpChange: -actualDamage
    ),
    hero: hero
)
modelContext.insert(entry)
```

**Step 3: Find and instrument attack result points**

When the hero deals damage (execution step):
```swift
let entry = LogEntry.create(
    kind: "combatAction",
    payload: CombatActionPayload(
        combatId: combatId,
        round: currentRound,
        action: .attack,
        weaponName: weaponName,
        rollValue: rollResult,
        damageDealt: nil,
        damageTaken: nil,
        lpChange: 0
    ),
    hero: hero
)
modelContext.insert(entry)
```

Note: The implementer should trace through CombatView's state machine to find exact insertion points. Key search terms: `lebensenergie.current`, `currentLifeEnergy`, the `takeDamage` step handler, and the `execution` step. CombatView uses `currentRound` state — verify if it exists or add it.

**Step 4: Instrument mount damage within combat**

If mount damage happens during combat, log with the same `combatId`.

**Step 5: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: log combat actions to action log"
```

---

### Task 10: Create LogPanelView

**Files:**
- Create: `Hesindion/Views/LogPanelView.swift`

**Step 1: Create the log panel view**

```swift
import SwiftUI
import SwiftData

struct LogPanelView: View {
    @Bindable var hero: Hero
    @Environment(\.modelContext) private var modelContext

    @State private var expandedCombats: Set<UUID> = []
    @State private var entryToDelete: LogEntry?

    private var sortedEntries: [LogEntry] {
        hero.logEntries.sorted { $0.timestamp > $1.timestamp }
    }

    private var groupedEntries: [(key: UUID?, entries: [LogEntry])] {
        var result: [(key: UUID?, entries: [LogEntry])] = []
        var currentCombatId: UUID?
        var currentGroup: [LogEntry] = []

        for entry in sortedEntries {
            if entry.kind == "combatAction",
               let payload = entry.decodePayload(CombatActionPayload.self) {
                if payload.combatId == currentCombatId {
                    currentGroup.append(entry)
                } else {
                    if !currentGroup.isEmpty {
                        result.append((key: currentCombatId, entries: currentGroup))
                    }
                    currentCombatId = payload.combatId
                    currentGroup = [entry]
                }
            } else {
                if !currentGroup.isEmpty {
                    result.append((key: currentCombatId, entries: currentGroup))
                    currentCombatId = nil
                    currentGroup = []
                }
                result.append((key: nil, entries: [entry]))
            }
        }
        if !currentGroup.isEmpty {
            result.append((key: currentCombatId, entries: currentGroup))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Protokoll")
                .font(.system(.headline, weight: .black))
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.headerVerticalPadding)

            if hero.logEntries.isEmpty {
                Text("Noch keine Einträge...")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DSALayout.contentPadding)
                    .padding(.vertical, DSALayout.headerVerticalPadding)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedEntries, id: \.entries.first?.id) { group in
                            if let combatId = group.key {
                                combatGroupView(combatId: combatId, entries: group.entries)
                            } else if let entry = group.entries.first {
                                logEntryRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.primaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen & Rückgängig", role: .destructive) {
                if let entry = entryToDelete {
                    deleteAndReverse(entry)
                }
            }
        } message: {
            Text("Die Auswirkung wird rückgängig gemacht.")
        }
    }

    // MARK: - Combat Group

    @ViewBuilder
    private func combatGroupView(combatId: UUID, entries: [LogEntry]) -> some View {
        let totalLP = entries.compactMap { $0.decodePayload(CombatActionPayload.self)?.lpChange }.reduce(0, +)
        let rounds = Set(entries.compactMap { $0.decodePayload(CombatActionPayload.self)?.round }).count
        let isExpanded = expandedCombats.contains(combatId)

        VStack(spacing: 0) {
            Button {
                withAnimation(DSAAnimation.standard) {
                    if isExpanded {
                        expandedCombats.remove(combatId)
                    } else {
                        expandedCombats.insert(combatId)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.groupCombat)
                    Text("Kampf — \(rounds) Runden, \(totalLP) LP")
                        .font(.system(.caption, weight: .bold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, 8)
                .background(Color.groupCombat.opacity(0.1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(entries, id: \.id) { entry in
                    logEntryRow(entry)
                        .padding(.leading, 12)
                }
            }

            Divider()
        }
    }

    // MARK: - Entry Row

    private func logEntryRow(_ entry: LogEntry) -> some View {
        HStack(spacing: 8) {
            entryIcon(entry)
            Text(entryDescription(entry))
                .font(.system(.caption))
                .lineLimit(1)
            Spacer()
            Text(entry.timestamp, style: .time)
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DSALayout.contentPadding)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                entryToDelete = entry
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Entry Display Helpers

    private func entryIcon(_ entry: LogEntry) -> some View {
        Group {
            switch entry.kind {
            case "talentCheck":
                Image(systemName: "dice.fill")
                    .foregroundStyle(Color.groupTalents)
            case "combatAction":
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.groupCombat)
            case "healing":
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.groupPersonalData)
            case "rest":
                Image(systemName: "moon.fill")
                    .foregroundStyle(Color.groupPersonalData)
            case "mountLPChange":
                Image(systemName: "hare.fill")
                    .foregroundStyle(Color.groupEquipment)
            default:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.caption, weight: .bold))
    }

    private func entryDescription(_ entry: LogEntry) -> String {
        switch entry.kind {
        case "talentCheck":
            if let p = entry.decodePayload(TalentCheckPayload.self) {
                return p.succeeded ? "\(p.talentName) — QS \(p.qualityLevel) ✓" : "\(p.talentName) — misslungen ✗"
            }
        case "combatAction":
            if let p = entry.decodePayload(CombatActionPayload.self) {
                switch p.action {
                case .attack:
                    let weapon = p.weaponName ?? "Angriff"
                    return "Angriff \(weapon) — \(p.rollValue ?? 0)"
                case .damageTaken:
                    return "Schaden erhalten — \(p.damageTaken ?? 0) SP"
                case .damageDealt:
                    return "Schaden ausgeteilt — \(p.damageDealt ?? 0) TP"
                case .parry:
                    return "Parade — \(p.rollValue ?? 0)"
                case .dodge:
                    return "Ausweichen — \(p.rollValue ?? 0)"
                }
            }
        case "healing":
            if let p = entry.decodePayload(HealingPayload.self) {
                return "\(p.source) — +\(p.lpRestored) LP"
            }
        case "rest":
            if let p = entry.decodePayload(RestPayload.self) {
                return "Rast — +\(p.lpRestored) LP"
            }
        case "mountLPChange":
            if let p = entry.decodePayload(MountLPChangePayload.self) {
                if p.lpChange < 0 {
                    return "\(p.petName) — Schaden \(-p.lpChange)"
                } else {
                    return "\(p.petName) — Heilung +\(p.lpChange) LP"
                }
            }
        default:
            break
        }
        return entry.kind
    }

    // MARK: - Delete & Reverse

    private func deleteAndReverse(_ entry: LogEntry) {
        entry.reversible()?.reverse(on: hero)
        modelContext.delete(entry)
        entryToDelete = nil
    }
}
```

**Step 2: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Hesindion/Views/LogPanelView.swift
git commit -m "feat: add LogPanelView with combat grouping and reversible delete"
```

---

### Task 11: Create SplitContentLayout (Replace ContentWithNotesLayout)

**Files:**
- Modify: `Hesindion/Views/ContentWithNotesLayout.swift` (rewrite to SplitContentLayout)

**Step 1: Define SidePanel enum and rewrite the layout**

Replace the entire contents of `ContentWithNotesLayout.swift`:

```swift
import SwiftUI

enum SidePanel: String, CaseIterable {
    case notes
    case logs
    case rules
}

struct SplitContentLayout<Content: View>: View {
    let hero: Hero
    @Binding var activePanel: SidePanel?
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isLandscape: Bool {
        sizeClass == .regular
    }

    var body: some View {
        if isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    // MARK: - Landscape (50/50 split)

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)

            if let panel = activePanel {
                panelView(for: panel)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .trailing) {
            if activePanel == nil {
                panelToggleButtons
            }
        }
    }

    // MARK: - Portrait (full-screen overlay)

    private var portraitLayout: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity)

            if let panel = activePanel {
                panelView(for: panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .trailing) {
            panelToggleButtons
        }
    }

    // MARK: - Panel Content

    @ViewBuilder
    private func panelView(for panel: SidePanel) -> some View {
        switch panel {
        case .notes:
            NotesPanelView(hero: hero)
        case .logs:
            LogPanelView(hero: hero)
        case .rules:
            RulebookPanelView()
        }
    }

    // MARK: - Toggle Buttons

    private var panelToggleButtons: some View {
        VStack(spacing: 0) {
            panelButton(.notes, icon: "note.text", activeIcon: "note.text.badge.plus")
            panelButton(.logs, icon: "list.bullet.rectangle", activeIcon: "list.bullet.rectangle.fill")
            panelButton(.rules, icon: "book.closed", activeIcon: "book.closed.fill")
        }
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.tertiaryBorder))
        .padding(.trailing, 8)
    }

    private func panelButton(_ panel: SidePanel, icon: String, activeIcon: String) -> some View {
        Button {
            withAnimation(DSAAnimation.standard) {
                if activePanel == panel {
                    activePanel = nil
                } else {
                    activePanel = panel
                }
            }
        } label: {
            Image(systemName: activePanel == panel ? activeIcon : icon)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(activePanel == panel ? Color.groupPersonalData : .primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Create a placeholder RulebookPanelView**

This is a lightweight wrapper around the existing RulebookView for the side panel context. Add at the bottom of the same file or create a new file:

```swift
struct RulebookPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Regelwerk")
                .font(.system(.headline, weight: .black))
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.headerVerticalPadding)

            RulebookView(sidebarSelection: .constant(nil))
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.primaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
    }
}
```

**Step 3: Build — this will fail because HeroDetailView still references ContentWithNotesLayout**

Expected: Build fails (handled in Task 12)

**Step 4: Commit**

```bash
git add Hesindion/Views/ContentWithNotesLayout.swift
git commit -m "feat: replace ContentWithNotesLayout with SplitContentLayout"
```

---

### Task 12: Update HeroDetailView to Use SplitContentLayout

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Replace state and layout references**

1. Replace `@State private var showNotes = false` with `@State private var activePanel: SidePanel?`

2. Replace `ContentWithNotesLayout(hero: hero, showNotes: $showNotes)` (line 25) with:
```swift
SplitContentLayout(hero: hero, activePanel: $activePanel)
```

3. Remove the toolbar notes toggle button (lines 164-174). The toggle buttons are now built into `SplitContentLayout`.

**Step 2: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: wire HeroDetailView to SplitContentLayout"
```

---

### Task 13: Add Localization Strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` (or wherever L() function strings are defined)

**Step 1: Find the L() function and add new strings**

Search for the `L()` function implementation. Add these strings:

```swift
"healing": "Heilung",
"healingSource": "Quelle (z.B. Heiltrank, Balsam...)",
"mountHealing": "Reittier: Heilung",
```

**Step 2: Build and verify**

Run: `make build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add localization strings for healing commands"
```

---

### Task 14: Update CHANGELOG and Architecture Docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/architecture.md` (if it exists)

**Step 1: Add to CHANGELOG.md under [Unreleased]**

```markdown
### Added
- Action log (Protokoll) with event sourcing — all talent checks, combat actions, healing, and resting are recorded
- Reversible log entries — deleting a log entry undoes its effect on hero state
- Split-screen layout — Notes, Protokoll, and Regelwerk panels available in 50/50 split (landscape) or full-screen overlay (portrait)
- Heilung command — heal hero with source tracking and logging
- Reittier: Heilung command — heal mount with logging
- SchemaV3 migration with LogEntry model

### Changed
- Replaced notes-only right sidebar with flexible SplitContentLayout supporting multiple panels
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update changelog with action log and split layout features"
```

---

### Task 15: Final Build and Test

**Step 1: Clean build**

Run: `make clean && make build`
Expected: Build succeeds with no warnings

**Step 2: Run on iPad simulator**

Run: `make run-ipad`
Expected: App launches without crash, existing heroes load (schema migration succeeds)

**Step 3: Verify functionality**

- Open a hero → verify split layout buttons appear on right edge
- Tap Notes → 50/50 split opens
- Tap Protokoll → replaces Notes panel with log view
- Tap Regelwerk → replaces with rules panel
- Tap active button → panel closes
- Open command palette → verify "Heilung" and "Reittier: Heilung" appear
- Roll a talent check → verify it appears in Protokoll
- Use Heilung → verify LP changes and log entry appears
- Delete a log entry → verify LP is reversed

**Step 4: Run on iPhone simulator**

Run: `make run`
Expected: Panels open full-screen in portrait, close on button tap

**Step 5: Final commit if any fixes needed**
