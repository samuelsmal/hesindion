# UI Snapshot Testing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add visual regression testing using swift-snapshot-testing to catch UI regressions across dark/light mode, iPad sizes, and dynamic type scales.

**Architecture:** SwiftUI views rendered with mock SwiftData in the existing `HesindionTests` target. Each view is snapshotted in 12 variants (2 color schemes × 2 iPad sizes × 3 dynamic type sizes). Uses XCTestCase (not Swift Testing) because swift-snapshot-testing's `assertSnapshot` API requires XCTest.

**Tech Stack:** swift-snapshot-testing (SPM, test-only), XCTest, SwiftUI, SwiftData

**Design doc:** `docs/plans/2026-03-30-ui-snapshot-testing-design.md`

---

### Task 0: Add swift-snapshot-testing SPM dependency

**Files:**
- Modify: `Hesindion.xcodeproj/project.pbxproj`

**Step 1: Add the package via Xcode CLI**

Since editing `project.pbxproj` by hand is fragile, use `xcodebuild` to resolve after adding through the Xcode project file. The safest approach: add the package reference and product dependency following the existing MarkdownUI pattern.

In `project.pbxproj`, add:

1. A new `XCRemoteSwiftPackageReference` entry (in the `XCRemoteSwiftPackageReference` section, ~line 480):
```
/* XCRemoteSwiftPackageReference "swift-snapshot-testing" */ = {
    isa = XCRemoteSwiftPackageReference;
    repositoryURL = "https://github.com/pointfreeco/swift-snapshot-testing";
    requirement = {
        kind = upToNextMajorVersion;
        minimumVersion = 1.17.0;
    };
};
```

2. A new `XCSwiftPackageProductDependency` for `SnapshotTesting` linked to the **HesindionTests** target (not the main app target):
```
/* SnapshotTesting */ = {
    isa = XCSwiftPackageProductDependency;
    package = /* reference to swift-snapshot-testing */;
    productName = SnapshotTesting;
};
```

3. Add the product dependency to `HesindionTests` target's `packageProductDependencies` array (currently empty at ~line 133).

4. Add a `SnapshotTesting in Frameworks` entry to the HesindionTests target's `PBXFrameworksBuildPhase` (lines 63-68).

5. Add the package reference to the project's `packageReferences` array.

**Step 2: Resolve packages**

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -resolvePackageDependencies -derivedDataPath .build
```
Expected: SUCCESS, packages resolved including swift-snapshot-testing

**Step 3: Verify build**

Run:
```bash
make build
```
Expected: Build succeeds (main app unaffected)

**Step 4: Commit**

```bash
git add Hesindion.xcodeproj/project.pbxproj
git commit -m "chore: add swift-snapshot-testing as test-only SPM dependency"
```

---

### Task 1: Create snapshot test helpers

**Files:**
- Create: `HesindionTests/Snapshots/SnapshotTestHelpers.swift`

**Step 1: Write the helper file**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// Standard iPad configurations for snapshot testing.
enum iPadConfig {
    /// iPad Pro 11-inch (M5) — primary test device
    static let pro11 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
        size: CGSize(width: 1024, height: 1366),
        traits: UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceIdiom: .pad),
            UITraitCollection(displayScale: 2),
            UITraitCollection(horizontalSizeClass: .regular),
            UITraitCollection(verticalSizeClass: .regular),
        ])
    )

    /// iPad Pro 13-inch
    static let pro13 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
        size: CGSize(width: 1032, height: 1376),
        traits: UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceIdiom: .pad),
            UITraitCollection(displayScale: 2),
            UITraitCollection(horizontalSizeClass: .regular),
            UITraitCollection(verticalSizeClass: .regular),
        ])
    )
}

/// All variant axes for snapshot testing.
struct SnapshotVariant: CustomStringConvertible {
    let name: String
    let config: ViewImageConfig
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize

    var description: String { name }

    static let all: [SnapshotVariant] = {
        let configs: [(String, ViewImageConfig)] = [
            ("iPad11", iPadConfig.pro11),
            ("iPad13", iPadConfig.pro13),
        ]
        let schemes: [(String, ColorScheme)] = [
            ("light", .light),
            ("dark", .dark),
        ]
        let typeSizes: [(String, DynamicTypeSize)] = [
            ("default", .large),
            ("accLarge", .accessibilityLarge),
            ("accXXXL", .accessibility3),
        ]

        var variants: [SnapshotVariant] = []
        for (configName, config) in configs {
            for (schemeName, scheme) in schemes {
                for (sizeName, size) in typeSizes {
                    variants.append(SnapshotVariant(
                        name: "\(configName)_\(schemeName)_\(sizeName)",
                        config: config,
                        colorScheme: scheme,
                        dynamicTypeSize: size
                    ))
                }
            }
        }
        return variants
    }()
}

extension XCTestCase {
    /// Snapshot a SwiftUI view across all 12 iPad variants.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to snapshot.
    ///   - name: Base name for the snapshot (used in file name).
    ///   - record: Whether to record new reference images.
    ///   - file: Source file (auto-filled).
    ///   - testName: Test function name (auto-filled).
    ///   - line: Source line (auto-filled).
    @MainActor
    func assertAllVariants<V: View>(
        of view: V,
        named name: String,
        record: Bool = false,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for variant in SnapshotVariant.all {
            let styledView = view
                .environment(\.colorScheme, variant.colorScheme)
                .dynamicTypeSize(variant.dynamicTypeSize)

            assertSnapshot(
                of: styledView,
                as: .image(layout: .device(config: variant.config)),
                named: "\(name)_\(variant.name)",
                record: record,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}
```

**Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator -configuration Debug -derivedDataPath .build -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build-for-testing
```
Expected: Build succeeds

**Step 3: Commit**

```bash
git add HesindionTests/Snapshots/SnapshotTestHelpers.swift
git commit -m "feat: add snapshot test helpers with iPad variant matrix"
```

---

### Task 2: Create TestData factory

**Files:**
- Create: `HesindionTests/Snapshots/TestData.swift`

**Step 1: Write the test data factory**

Reuse `OptolithImportService` to import a real hero from sample data for realistic rendering. Create additional models (adventures, weather, etc.) programmatically.

```swift
import Foundation
import SwiftData
@testable import Hesindion

@MainActor
enum TestData {

    /// Full schema for ModelContainer.
    static let schema = Schema([
        Hero.self, PersonalData.self, Experience.self, Attributes.self,
        DerivedValues.self, Talent.self, CombatTechnique.self,
        MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
        EquipmentItem.self, Money.self, Pet.self, Language.self,
        HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
    ])

    /// Create an in-memory ModelContainer with the full schema.
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// URL to the Boronmir sample hero JSON.
    static var boronmirURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Snapshots/
            .deletingLastPathComponent()    // HesindionTests/
            .appendingPathComponent("docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json")
    }

    /// Import the Boronmir sample hero and return the Hero and context.
    static func importBoronmir(into container: ModelContainer) throws -> Hero {
        let context = ModelContext(container)
        try OptolithImportService().importHero(from: boronmirURL, context: context)
        let heroes = try context.fetch(FetchDescriptor<Hero>())
        return heroes.first!
    }

    /// Create a sample Adventure with weather days and log entries.
    static func makeSampleAdventure(for hero: Hero, in context: ModelContext) -> Adventure {
        let adventure = Adventure(name: "Die Schwarze Katze", createdAt: Date())

        // Add a few weather days
        let calendar = Calendar.current
        for dayOffset in 0..<3 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let weather = WeatherDay(
                date: date,
                temperature: Double.random(in: 5...25),
                windSpeed: Int.random(in: 0...5),
                precipitation: Int.random(in: 0...3)
            )
            adventure.weatherDays.append(weather)
        }

        // Add log entries
        let textEntry = LogEntry(type: .text, text: "Die Gruppe erreicht das Dorf.", timestamp: Date())
        adventure.logEntries.append(textEntry)

        let diceEntry = LogEntry(type: .diceRoll, text: "Würfeln: 3W6 → 4, 2, 6 = 12", timestamp: Date())
        adventure.logEntries.append(diceEntry)

        context.insert(adventure)
        return adventure
    }
}
```

> **Note:** The exact `Adventure`, `WeatherDay`, and `LogEntry` initializers may differ from what's shown — check the actual model files at implementation time and adjust accordingly. The key pattern is: create realistic data that exercises all visual elements of each view.

**Step 2: Write a smoke test to verify TestData works**

Create a minimal test in the same file or a separate test:

```swift
import XCTest
import SwiftData
@testable import Hesindion

final class TestDataTests: XCTestCase {
    @MainActor
    func testBoronmirImport() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        XCTAssertEqual(hero.name, "Boronmir Siebenfeld von Greifenfurt")
        XCTAssertNotNil(hero.attributes)
        XCTAssertFalse(hero.meleeWeapons.isEmpty)
    }
}
```

**Step 3: Run the test**

Run:
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator -configuration Debug -derivedDataPath .build -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test -only-testing:HesindionTests/TestDataTests
```
Expected: PASS

**Step 4: Commit**

```bash
git add HesindionTests/Snapshots/TestData.swift
git commit -m "feat: add TestData factory for snapshot tests"
```

---

### Task 3: Snapshot tests — HeroListView

**Files:**
- Create: `HesindionTests/Snapshots/HeroListViewSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class HeroListViewSnapshotTests: XCTestCase {

    @MainActor
    func testEmptyState() throws {
        let container = try TestData.makeContainer()
        let view = HeroListView()
            .modelContainer(container)

        assertAllVariants(of: view, named: "empty")
    }

    @MainActor
    func testPopulated() throws {
        let container = try TestData.makeContainer()
        _ = try TestData.importBoronmir(into: container)
        // Import additional heroes if more sample JSONs are available

        let view = HeroListView()
            .modelContainer(container)

        assertAllVariants(of: view, named: "populated")
    }
}
```

**Step 2: Record initial reference images**

Run with `record: true` (set via environment variable or temporarily in code):
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator -configuration Debug -derivedDataPath .build -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test -only-testing:HesindionTests/HeroListViewSnapshotTests
```

First run will fail and record reference images. Run again to verify they pass.

**Step 3: Commit**

```bash
git add HesindionTests/Snapshots/HeroListViewSnapshotTests.swift
git add HesindionTests/__Snapshots__/
git commit -m "feat: add HeroListView snapshot tests"
```

---

### Task 4: Snapshot tests — HeroDetailView

**Files:**
- Create: `HesindionTests/Snapshots/HeroDetailViewSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class HeroDetailViewSnapshotTests: XCTestCase {

    @MainActor
    func testFullHero() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = HeroDetailView(
            hero: hero,
            sidebarSelection: .constant(.hero(hero.persistentModelID))
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "boronmir")
    }
}
```

**Step 2: Record and verify**

Run tests (first run records, second verifies):
```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator -configuration Debug -derivedDataPath .build -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test -only-testing:HesindionTests/HeroDetailViewSnapshotTests
```

**Step 3: Commit**

```bash
git add HesindionTests/Snapshots/HeroDetailViewSnapshotTests.swift
git add HesindionTests/__Snapshots__/
git commit -m "feat: add HeroDetailView snapshot tests"
```

---

### Task 5: Snapshot tests — CombatView

**Files:**
- Create: `HesindionTests/Snapshots/CombatViewSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class CombatViewSnapshotTests: XCTestCase {

    @MainActor
    func testArmorSelection() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CombatView(hero: hero, onDismiss: {})
            .modelContainer(container)

        assertAllVariants(of: view, named: "armorSelection")
    }
}
```

**Step 2: Record and verify**

```bash
xcodebuild ... test -only-testing:HesindionTests/CombatViewSnapshotTests
```

**Step 3: Commit**

```bash
git add HesindionTests/Snapshots/CombatViewSnapshotTests.swift
git add HesindionTests/__Snapshots__/
git commit -m "feat: add CombatView snapshot tests"
```

---

### Task 6: Snapshot tests — CombatRootView

**Files:**
- Create: `HesindionTests/Snapshots/CombatRootViewSnapshotTests.swift`

**Step 1: Write the test**

CombatRootView requires several bindings to simulate mid-combat state:

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class CombatRootViewSnapshotTests: XCTestCase {

    @MainActor
    func testMidCombat() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CombatRootView(
            hero: hero,
            step: .constant(.root),
            rolledInitiative: .constant(12),
            roundNumber: .constant(2),
            dualAttackPenaltyActive: .constant(false)
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "midCombat")
    }
}
```

> **Note:** Check the full init signature of `CombatRootView` at implementation time — it may have additional binding parameters. Supply sensible mid-combat defaults for all of them.

**Step 2: Record and verify, Step 3: Commit** (same pattern as previous tasks)

```bash
git commit -m "feat: add CombatRootView snapshot tests"
```

---

### Task 7: Snapshot tests — CommandPaletteOverlay

**Files:**
- Create: `HesindionTests/Snapshots/CommandPaletteSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class CommandPaletteSnapshotTests: XCTestCase {

    @MainActor
    func testOpenWithQuery() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CommandPaletteOverlay(
            showCommandSearch: .constant(true),
            commandQuery: .constant("Kampf"),
            activeCommand: .constant(nil),
            hero: hero
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "openWithQuery")
    }
}
```

> **Note:** `CommandPaletteOverlay` has a `@FocusState` parameter — this cannot be passed from outside. The view will render without keyboard focus, which is fine for snapshot testing.

**Step 2: Record and verify, Step 3: Commit**

```bash
git commit -m "feat: add CommandPaletteOverlay snapshot tests"
```

---

### Task 8: Snapshot tests — AdventureDetailView

**Files:**
- Create: `HesindionTests/Snapshots/AdventureDetailViewSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class AdventureDetailViewSnapshotTests: XCTestCase {

    @MainActor
    func testWithEntries() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let context = ModelContext(container)
        let adventure = TestData.makeSampleAdventure(for: hero, in: context)

        let view = AdventureDetailView(adventure: adventure)
            .modelContainer(container)

        assertAllVariants(of: view, named: "withEntries")
    }
}
```

**Step 2: Record and verify, Step 3: Commit**

```bash
git commit -m "feat: add AdventureDetailView snapshot tests"
```

---

### Task 9: Snapshot tests — DiceRollSheet

**Files:**
- Create: `HesindionTests/Snapshots/DiceRollSheetSnapshotTests.swift`

**Step 1: Write the test**

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class DiceRollSheetSnapshotTests: XCTestCase {

    @MainActor
    func testInitialState() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = DiceRollSheet(hero: hero)
            .modelContainer(container)

        assertAllVariants(of: view, named: "initial")
    }
}
```

> **Note:** DiceRollSheet has animation state — the snapshot captures the initial (pre-roll) state. Testing the post-roll state would require driving @State changes, which is not possible from outside. If needed later, extract the result display into a separate view.

**Step 2: Record and verify, Step 3: Commit**

```bash
git commit -m "feat: add DiceRollSheet snapshot tests"
```

---

### Task 10: Snapshot tests — WeatherDayRow

**Files:**
- Create: `HesindionTests/Snapshots/WeatherDayRowSnapshotTests.swift`

**Step 1: Write the test**

There is no `WeatherDetailView` — use `WeatherDayRow` instead (takes a `WeatherDay`):

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class WeatherDayRowSnapshotTests: XCTestCase {

    @MainActor
    func testWeatherDay() throws {
        let container = try TestData.makeContainer()
        let context = ModelContext(container)

        let weather = WeatherDay(
            date: Date(),
            temperature: 18.5,
            windSpeed: 3,
            precipitation: 1
        )
        context.insert(weather)

        let view = WeatherDayRow(weatherDay: weather)
            .frame(width: 700) // Approximate content width
            .modelContainer(container)

        assertAllVariants(of: view, named: "sunny")
    }
}
```

> **Note:** WeatherDayRow is a row component, not a full-screen view. Constrain its width to approximate how it appears inside AdventureDetailView. Adjust `WeatherDay` initializer to match actual model.

**Step 2: Record and verify, Step 3: Commit**

```bash
git commit -m "feat: add WeatherDayRow snapshot tests"
```

---

### Task 11: Add Makefile targets and update .gitignore

**Files:**
- Modify: `Makefile`
- Modify: `.gitignore`

**Step 1: Add test targets to Makefile**

Add after the existing `clean` target:

```makefile
# ── Testing ──────────────────────────────────────────────────────────────────

test: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		test

test-ui: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		test -only-testing:HesindionTests

test-ui-record: boot
	SNAPSHOT_TESTING_RECORD=1 xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		test -only-testing:HesindionTests
```

> **Note:** `SNAPSHOT_TESTING_RECORD=1` is the environment variable that swift-snapshot-testing 1.17+ uses to enable recording mode globally. Verify this works at implementation time — the alternative is `withSnapshotTesting(record: .all)` in code.

**Step 2: Update .gitignore**

Add to `.gitignore`:
```
# Snapshot test failure artifacts
HesindionTests/__Snapshots__/failures/
```

**Step 3: Update .PHONY line**

Add `test test-ui test-ui-record` to the `.PHONY` line in Makefile.

**Step 4: Verify**

Run:
```bash
make test-ui
```
Expected: All snapshot tests pass

**Step 5: Commit**

```bash
git add Makefile .gitignore
git commit -m "chore: add test-ui and test-ui-record Makefile targets"
```

---

### Task 12: Record all reference images and finalize

**Step 1: Record all snapshots**

```bash
make test-ui-record
```

Expected: All tests run, reference images created in `HesindionTests/__Snapshots__/`

**Step 2: Verify all tests pass**

```bash
make test-ui
```

Expected: All tests PASS (no diffs from just-recorded images)

**Step 3: Review reference images**

Open `HesindionTests/__Snapshots__/` in Finder and visually inspect a sampling of images across dark/light and dynamic type variants. Verify:
- Text is readable in both color schemes
- No clipping or overlap at largest dynamic type
- Layout fills iPad screen appropriately

**Step 4: Commit all reference images**

```bash
git add HesindionTests/__Snapshots__/
git commit -m "feat: record initial snapshot reference images"
```

---

### Task 13: Update CHANGELOG and documentation

**Files:**
- Modify: `CHANGELOG.md`
- The design doc is already committed.

**Step 1: Update CHANGELOG**

Add under `[Unreleased]`:
```markdown
### Added
- UI snapshot testing infrastructure using swift-snapshot-testing
- Snapshot tests for 8 views across 12 iPad/color/dynamic-type variants
- `make test-ui` and `make test-ui-record` Makefile targets
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add UI snapshot testing to changelog"
```
