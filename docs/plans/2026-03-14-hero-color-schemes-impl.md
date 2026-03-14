# Hero Color Schemes & UI Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Fix sidebar styling, attribute border, panel buttons, and add per-profession color schemes to hero detail views.

**Architecture:** New `HeroColorScheme` value type maps professions to color gradients. A `colorSchemeId` property on Hero persists the user's selection. A new `HeroSettingsView` (full-screen) allows picking a scheme. All section colors in HeroDetailView derive from the active scheme instead of hardcoded group colors. Combat mode is never affected.

**Tech Stack:** SwiftUI, SwiftData (iOS 26+), no external dependencies.

---

### Task 1: Fix Sidebar Styling

**Files:**
- Modify: `Hesindion/Views/HeroListView.swift`

**Step 1: Center the title**

Replace the `.navigationTitle` and `.toolbarTitleDisplayMode` with a custom header. In `sidebarContent`, remove `.navigationTitle("Hesindion")` and `.toolbarTitleDisplayMode(.inlineLarge)` from the NavigationSplitView sidebar. Instead, add a header above the List.

In the `NavigationSplitView` sidebar closure, wrap `sidebarContent` in a VStack with a title header:

```swift
// In body, replace the sidebar closure:
NavigationSplitView {
    VStack(spacing: 0) {
        Text("Hesindion")
            .font(.system(.largeTitle, design: .default, weight: .black))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))

        sidebarContent
    }
    .safeAreaInset(edge: .bottom) {
        importButton
    }
    .navigationTitle("")
    .navigationBarHidden(true)
} detail: {
    detailContent
}
```

**Step 2: Fix sidebar background — no rounded corners, full height**

The List already uses `.listStyle(.plain)` and `.scrollContentBackground(.hidden)` with a flat background. The rounded appearance comes from the system NavigationSplitView sidebar. By hiding the nav bar and using our own header, the sidebar should be flat edge-to-edge. No additional changes needed.

**Step 3: Fix "Held Importieren" readability**

In `importButton`, change `.foregroundStyle(.primary)` to `.foregroundStyle(.black)`:

```swift
// In importButton:
.foregroundStyle(.black)
```

This ensures the text is always black on the golden yellow background regardless of dark/light mode.

**Step 4: Fix selected hero readability**

Increase the selection highlight opacity. In `sidebarContent`, change both `.listRowBackground` selection highlights:

For rulebook:
```swift
.listRowBackground(
    selection == .rulebook
        ? Color.groupRulebook.opacity(0.35)
        : Color(UIColor.systemBackground)
)
```

For heroes:
```swift
.listRowBackground(
    selection == .hero(hero.persistentModelID)
        ? Color.groupPersonalData.opacity(0.35)
        : Color(UIColor.systemBackground)
)
```

**Step 5: Build and verify**

Run: `make run-ipad`

**Step 6: Commit**

```bash
git add Hesindion/Views/HeroListView.swift
git commit -m "fix: center sidebar title, improve selection and button readability"
```

---

### Task 2: Remove Attributes Column Border

**Files:**
- Modify: `Hesindion/Views/HeroDetailComponents.swift:52-56`

**Step 1: Remove the trailing border overlay**

In `AttributesColumn`, delete the `.overlay(alignment: .trailing)` block:

```swift
// DELETE these lines from AttributesColumn body:
.overlay(alignment: .trailing) {
    Rectangle()
        .frame(width: 3)
        .foregroundStyle(Color.dsaBorder)
}
```

The `VStack` should end at `.frame(width: 80)` with no overlay.

**Step 2: Build and verify**

Run: `make run-ipad`

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailComponents.swift
git commit -m "fix: remove trailing border from attributes column"
```

---

### Task 3: Fill Panel Toggle Buttons

**Files:**
- Modify: `Hesindion/Views/ContentWithNotesLayout.swift:127-149`

**Step 1: Update panelButton styling**

Replace the `panelButton` function:

```swift
private func panelButton(_ panel: SidePanel, icon: String, activeIcon: String) -> some View {
    let isActive = activePanel == panel
    return Button {
        withAnimation(DSAAnimation.standard) {
            if activePanel == panel {
                activePanel = nil
            } else {
                activePanel = panel
            }
        }
    } label: {
        Image(systemName: isActive ? activeIcon : icon)
            .font(.system(.body, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(panelColor(for: panel))
    }
    .buttonStyle(.plain)
}
```

Changes: icon is always `.white`, background is always `panelColor(for: panel)`, no `.overlay` border.

**Step 2: Remove left border from panelToggleButtons**

In `panelToggleButtons`, remove the `.overlay(alignment: .leading)` block that draws the 2pt left border:

```swift
private var panelToggleButtons: some View {
    VStack(spacing: 0) {
        panelButton(.notes, icon: "note.text", activeIcon: "note.text.badge.plus")
        panelButton(.logs, icon: "list.bullet.rectangle", activeIcon: "list.bullet.rectangle.fill")
        panelButton(.rules, icon: "book.closed", activeIcon: "book.closed.fill")
    }
}
```

**Step 3: Build and verify**

Run: `make run-ipad`

**Step 4: Commit**

```bash
git add Hesindion/Views/ContentWithNotesLayout.swift
git commit -m "style: fill panel toggle buttons with color, remove borders"
```

---

### Task 4: Create HeroColorScheme Type

**Files:**
- Create: `Hesindion/Theme/HeroColorScheme.swift`

**Step 1: Create the scheme struct and all palettes**

```swift
import SwiftUI

struct HeroColorScheme: Identifiable, Equatable {
    let id: String
    let name: String
    let sectionColors: [Color]  // 4 colors: personal data (darkest) → equipment (lightest)
    let textColor: Color
    let accentColor: Color

    func groupColor(at index: Int) -> Color {
        sectionColors[min(index, sectionColors.count - 1)]
    }
}

// MARK: - Predefined Schemes

extension HeroColorScheme {
    static let allSchemes: [HeroColorScheme] = [
        .defaultGolden, .boron, .praios, .rondra, .peraine,
        .hesinde, .phex, .efferd, .firun, .ingerimm,
        .rahja, .travia, .tsa, .swafnir, .namenlos,
        .krieger, .magier, .hexe, .mundane,
    ]

    static let defaultGolden = HeroColorScheme(
        id: "default",
        name: "Standard (Gold)",
        sectionColors: [
            Color(red: 0xf5/255, green: 0xc4/255, blue: 0x00/255),  // groupPersonalData
            Color(red: 0x1d/255, green: 0x4e/255, blue: 0xd8/255),  // groupTalents
            Color(red: 0xdc/255, green: 0x26/255, blue: 0x26/255),  // groupCombat
            Color(red: 0x16/255, green: 0xa3/255, blue: 0x4a/255),  // groupEquipment
        ],
        textColor: .primary,
        accentColor: Color(red: 0xf5/255, green: 0xc4/255, blue: 0x00/255)
    )

    static let boron = HeroColorScheme(
        id: "boron",
        name: "Boron / Golgarit",
        sectionColors: [
            Color(red: 0x1a/255, green: 0x0a/255, blue: 0x2e/255),
            Color(red: 0x2d/255, green: 0x16/255, blue: 0x50/255),
            Color(red: 0x4a/255, green: 0x25/255, blue: 0x78/255),
            Color(red: 0x6b/255, green: 0x3f/255, blue: 0xa0/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x4a/255, green: 0x25/255, blue: 0x78/255)
    )

    static let praios = HeroColorScheme(
        id: "praios",
        name: "Praios",
        sectionColors: [
            Color(red: 0x5c/255, green: 0x3d/255, blue: 0x00/255),
            Color(red: 0x8b/255, green: 0x69/255, blue: 0x14/255),
            Color(red: 0xb8/255, green: 0x94/255, blue: 0x2a/255),
            Color(red: 0xd4/255, green: 0xb4/255, blue: 0x4a/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0xb8/255, green: 0x94/255, blue: 0x2a/255)
    )

    static let rondra = HeroColorScheme(
        id: "rondra",
        name: "Rondra / Kor",
        sectionColors: [
            Color(red: 0x4a/255, green: 0x0e/255, blue: 0x0e/255),
            Color(red: 0x6b/255, green: 0x1a/255, blue: 0x1a/255),
            Color(red: 0x8c/255, green: 0x2f/255, blue: 0x2f/255),
            Color(red: 0xa8/255, green: 0x45/255, blue: 0x45/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x8c/255, green: 0x2f/255, blue: 0x2f/255)
    )

    static let peraine = HeroColorScheme(
        id: "peraine",
        name: "Peraine",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x2e/255, blue: 0x14/255),
            Color(red: 0x16/255, green: 0x50/255, blue: 0x28/255),
            Color(red: 0x22/255, green: 0x78/255, blue: 0x40/255),
            Color(red: 0x2e/255, green: 0xa0/255, blue: 0x58/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x22/255, green: 0x78/255, blue: 0x40/255)
    )

    static let hesinde = HeroColorScheme(
        id: "hesinde",
        name: "Hesinde",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x1a/255, blue: 0x3e/255),
            Color(red: 0x14/255, green: 0x2e/255, blue: 0x5c/255),
            Color(red: 0x1e/255, green: 0x42/255, blue: 0x80/255),
            Color(red: 0x28/255, green: 0x56/255, blue: 0xa4/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x1e/255, green: 0x42/255, blue: 0x80/255)
    )

    static let phex = HeroColorScheme(
        id: "phex",
        name: "Phex",
        sectionColors: [
            Color(red: 0x1a/255, green: 0x1a/255, blue: 0x22/255),
            Color(red: 0x2e/255, green: 0x2e/255, blue: 0x3a/255),
            Color(red: 0x44/255, green: 0x44/255, blue: 0x56/255),
            Color(red: 0x5a/255, green: 0x5a/255, blue: 0x70/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x44/255, green: 0x44/255, blue: 0x56/255)
    )

    static let efferd = HeroColorScheme(
        id: "efferd",
        name: "Efferd",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x1e/255, blue: 0x2e/255),
            Color(red: 0x14/255, green: 0x34/255, blue: 0x50/255),
            Color(red: 0x1e/255, green: 0x4a/255, blue: 0x78/255),
            Color(red: 0x28/255, green: 0x60/255, blue: 0xa0/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x1e/255, green: 0x4a/255, blue: 0x78/255)
    )

    static let firun = HeroColorScheme(
        id: "firun",
        name: "Firun / Ifirn",
        sectionColors: [
            Color(red: 0x1a/255, green: 0x22/255, blue: 0x30/255),
            Color(red: 0x2e/255, green: 0x3a/255, blue: 0x4a/255),
            Color(red: 0x44/255, green: 0x52/255, blue: 0x64/255),
            Color(red: 0x5a/255, green: 0x6a/255, blue: 0x80/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x44/255, green: 0x52/255, blue: 0x64/255)
    )

    static let ingerimm = HeroColorScheme(
        id: "ingerimm",
        name: "Ingerimm",
        sectionColors: [
            Color(red: 0x2e/255, green: 0x1a/255, blue: 0x0a/255),
            Color(red: 0x50/255, green: 0x30/255, blue: 0x14/255),
            Color(red: 0x78/255, green: 0x46/255, blue: 0x1e/255),
            Color(red: 0xa0/255, green: 0x5c/255, blue: 0x28/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x78/255, green: 0x46/255, blue: 0x1e/255)
    )

    static let rahja = HeroColorScheme(
        id: "rahja",
        name: "Rahja",
        sectionColors: [
            Color(red: 0x2e/255, green: 0x0a/255, blue: 0x1a/255),
            Color(red: 0x50/255, green: 0x14/255, blue: 0x30/255),
            Color(red: 0x78/255, green: 0x1e/255, blue: 0x46/255),
            Color(red: 0xa0/255, green: 0x28/255, blue: 0x5c/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x78/255, green: 0x1e/255, blue: 0x46/255)
    )

    static let travia = HeroColorScheme(
        id: "travia",
        name: "Travia",
        sectionColors: [
            Color(red: 0x2e/255, green: 0x1e/255, blue: 0x0a/255),
            Color(red: 0x50/255, green: 0x34/255, blue: 0x14/255),
            Color(red: 0x78/255, green: 0x4a/255, blue: 0x1e/255),
            Color(red: 0xa0/255, green: 0x60/255, blue: 0x28/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x78/255, green: 0x4a/255, blue: 0x1e/255)
    )

    static let tsa = HeroColorScheme(
        id: "tsa",
        name: "Tsa",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x2e/255, blue: 0x1e/255),
            Color(red: 0x14/255, green: 0x50/255, blue: 0x34/255),
            Color(red: 0x1e/255, green: 0x78/255, blue: 0x4a/255),
            Color(red: 0x28/255, green: 0xa0/255, blue: 0x60/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x1e/255, green: 0x78/255, blue: 0x4a/255)
    )

    static let swafnir = HeroColorScheme(
        id: "swafnir",
        name: "Swafnir",
        sectionColors: [
            Color(red: 0x18/255, green: 0x1e/255, blue: 0x24/255),
            Color(red: 0x28/255, green: 0x32/255, blue: 0x3c/255),
            Color(red: 0x3c/255, green: 0x48/255, blue: 0x56/255),
            Color(red: 0x50/255, green: 0x5e/255, blue: 0x70/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x3c/255, green: 0x48/255, blue: 0x56/255)
    )

    static let namenlos = HeroColorScheme(
        id: "namenlos",
        name: "Namenloser",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x0a/255, blue: 0x0e/255),
            Color(red: 0x16/255, green: 0x16/255, blue: 0x1e/255),
            Color(red: 0x22/255, green: 0x22/255, blue: 0x30/255),
            Color(red: 0x2e/255, green: 0x2e/255, blue: 0x42/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x22/255, green: 0x22/255, blue: 0x30/255)
    )

    static let krieger = HeroColorScheme(
        id: "krieger",
        name: "Krieger / Ritter",
        sectionColors: [
            Color(red: 0x14/255, green: 0x18/255, blue: 0x1e/255),
            Color(red: 0x24/255, green: 0x2c/255, blue: 0x36/255),
            Color(red: 0x38/255, green: 0x40/255, blue: 0x50/255),
            Color(red: 0x4c/255, green: 0x58/255, blue: 0x6a/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x38/255, green: 0x40/255, blue: 0x50/255)
    )

    static let magier = HeroColorScheme(
        id: "magier",
        name: "Magier",
        sectionColors: [
            Color(red: 0x0e/255, green: 0x0a/255, blue: 0x2e/255),
            Color(red: 0x1a/255, green: 0x16/255, blue: 0x50/255),
            Color(red: 0x28/255, green: 0x22/255, blue: 0x78/255),
            Color(red: 0x36/255, green: 0x30/255, blue: 0xa0/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x28/255, green: 0x22/255, blue: 0x78/255)
    )

    static let hexe = HeroColorScheme(
        id: "hexe",
        name: "Hexe",
        sectionColors: [
            Color(red: 0x0a/255, green: 0x1e/255, blue: 0x0a/255),
            Color(red: 0x16/255, green: 0x34/255, blue: 0x16/255),
            Color(red: 0x22/255, green: 0x4a/255, blue: 0x22/255),
            Color(red: 0x2e/255, green: 0x60/255, blue: 0x2e/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x22/255, green: 0x4a/255, blue: 0x22/255)
    )

    static let mundane = HeroColorScheme(
        id: "mundane",
        name: "Mundan",
        sectionColors: [
            Color(red: 0x2e/255, green: 0x1a/255, blue: 0x0a/255),
            Color(red: 0x4a/255, green: 0x2e/255, blue: 0x14/255),
            Color(red: 0x66/255, green: 0x42/255, blue: 0x1e/255),
            Color(red: 0x82/255, green: 0x56/255, blue: 0x28/255),
        ],
        textColor: .white,
        accentColor: Color(red: 0x66/255, green: 0x42/255, blue: 0x1e/255)
    )

    // MARK: - Profession Mapping

    static func schemeForProfession(_ profession: String) -> HeroColorScheme {
        let lower = profession.lowercased()
        if lower.contains("golgarit") || lower.contains("borongeweih") { return .boron }
        if lower.contains("praiosgeweih") { return .praios }
        if lower.contains("rondrageweih") || lower.contains("kor-geweih") { return .rondra }
        if lower.contains("perainegeweih") { return .peraine }
        if lower.contains("hesindegeweih") { return .hesinde }
        if lower.contains("phexgeweih") { return .phex }
        if lower.contains("efferdgeweih") { return .efferd }
        if lower.contains("firungeweih") || lower.contains("ifirn-geweih") { return .firun }
        if lower.contains("ingerimmgeweih") { return .ingerimm }
        if lower.contains("rahjageweih") { return .rahja }
        if lower.contains("travia-geweih") { return .travia }
        if lower.contains("tsakgeweih") { return .tsa }
        if lower.contains("swafnir-geweih") { return .swafnir }
        if lower.contains("namenloser geweih") || lower.contains("gravesh") { return .namenlos }
        if lower.contains("magier") || lower.contains("bannstrahler") || lower.contains("borbaradianer") || lower.contains("qabalyamagier") { return .magier }
        if lower.contains("hexe") { return .hexe }
        if lower.contains("zauberbarde") || lower.contains("zaubertänzer") { return .magier }
        if lower.contains("schelm") { return .magier }
        if lower.contains("durro-dûn") { return .magier }
        if lower.contains("fakir") || lower.contains("zibilja") || lower.contains("sangara") { return .magier }
        if lower.contains("krieger") || lower.contains("ritter") || lower.contains("söldner") || lower.contains("gardist") || lower.contains("ordenskrieger") || lower.contains("amazone") || lower.contains("lanisto") || lower.contains("ferkina") { return .krieger }
        if lower.contains("stammeskrieger") || lower.contains("tierkrieger") { return .krieger }
        if lower.contains("scharfschütze") || lower.contains("kopfgeldjäger") { return .krieger }
        return .mundane
    }

    static func scheme(for hero: Hero) -> HeroColorScheme {
        // User override first
        if let id = hero.colorSchemeId,
           let scheme = allSchemes.first(where: { $0.id == id }) {
            return scheme
        }
        // Auto-detect from profession
        let profession = hero.personalData?.profession ?? ""
        if profession.isEmpty { return .defaultGolden }
        return schemeForProfession(profession)
    }
}
```

**Step 2: Add `colorSchemeId` to Hero model**

In `Hesindion/Models/Hero.swift`, add a new property after `notes`:

```swift
// After: var notes: String = ""
var colorSchemeId: String?
```

**Step 3: Build and verify**

Run: `make build-ipad`

**Step 4: Commit**

```bash
git add Hesindion/Theme/HeroColorScheme.swift Hesindion/Models/Hero.swift
git commit -m "feat: add HeroColorScheme type with profession-based color palettes"
```

Note: You must also add `HeroColorScheme.swift` to the Xcode project. Since this project doesn't use SPM and uses an `.xcodeproj`, add the file via the existing folder reference or manually to the project targets.

---

### Task 5: Wire Color Schemes into HeroDetailView

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift`

**Step 1: Compute the scheme and replace group colors**

At the top of `HeroDetailView`, add a computed property:

```swift
private var colorScheme: HeroColorScheme {
    HeroColorScheme.scheme(for: hero)
}
```

**Step 2: Replace hardcoded colors in `nameHeading`**

Change `.background(Color.groupPersonalData)` to:

```swift
.background(colorScheme.groupColor(at: 0))
```

**Step 3: Replace hardcoded colors in `groupsContent`**

Replace the four `CollapsibleGroup` calls:

```swift
// Personal Data (index 0)
CollapsibleGroup(L("groupPersonalData"), color: colorScheme.groupColor(at: 0), textColor: colorScheme.textColor) {
    // ... unchanged content
}

// Talents (index 1)
CollapsibleGroup(L("groupTalents"), color: colorScheme.groupColor(at: 1), textColor: colorScheme.textColor) {
    // ... unchanged content
}

// Combat — ALWAYS uses .groupCombat (never affected by scheme)
CollapsibleGroup(L("groupCombat"), color: .groupCombat) {
    // ... unchanged content
}

// Equipment (index 3)
CollapsibleGroup(L("groupEquipment"), color: colorScheme.groupColor(at: 3), textColor: colorScheme.textColor) {
    // ... unchanged content
}
```

**Step 4: Build and verify**

Run: `make run-ipad`
Expected: Boronmir (Golgarit) should show dark violet gradient sections. Combat group stays red.

**Step 5: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: wire profession color schemes into hero detail sections"
```

---

### Task 6: Create HeroSettingsView

**Files:**
- Create: `Hesindion/Views/HeroSettingsView.swift`
- Modify: `Hesindion/Views/HeroDetailView.swift`
- Modify: `Hesindion/Models/Hero.swift` (command registry)
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add localization strings**

In `Strings.swift`, add to both `englishFallback` and `translations`:

English:
```swift
"heroSettings":         "Hero Settings",
"colorScheme":          "Color Scheme",
"colorSchemeAutomatic": "Automatic (from profession)",
"close":                "Close",
```

German:
```swift
"heroSettings":         "Heldeneinstellungen",
"colorScheme":          "Farbschema",
"colorSchemeAutomatic": "Automatisch (aus Profession)",
"close":                "Schließen",
```

**Step 2: Create HeroSettingsView**

```swift
import SwiftUI

struct HeroSettingsView: View {
    let hero: Hero
    let dismiss: () -> Void

    private var currentScheme: HeroColorScheme {
        HeroColorScheme.scheme(for: hero)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: dismiss) {
                    Text(L("close"))
                        .font(.system(.body, weight: .bold))
                }
                Spacer()
                Text(L("heroSettings"))
                    .font(.system(.headline, weight: .black))
                Spacer()
                // Balance spacer
                Text(L("close"))
                    .font(.system(.body, weight: .bold))
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: DSALayout.secondaryBorder)
                    .foregroundStyle(Color.dsaBorder)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("colorScheme"))
                        .font(.system(.title3, weight: .black))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Automatic option
                    schemeRow(
                        scheme: nil,
                        label: L("colorSchemeAutomatic"),
                        isSelected: hero.colorSchemeId == nil
                    )

                    // All schemes
                    ForEach(HeroColorScheme.allSchemes) { scheme in
                        schemeRow(
                            scheme: scheme,
                            label: scheme.name,
                            isSelected: hero.colorSchemeId == scheme.id
                        )
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private func schemeRow(scheme: HeroColorScheme?, label: String, isSelected: Bool) -> some View {
        Button {
            hero.colorSchemeId = scheme?.id
        } label: {
            HStack(spacing: 12) {
                // Color swatch preview
                HStack(spacing: 0) {
                    if let scheme {
                        ForEach(0..<4, id: \.self) { i in
                            Rectangle()
                                .fill(scheme.sectionColors[i])
                                .frame(width: 20, height: 32)
                        }
                    } else {
                        // Auto: show profession-derived preview
                        let auto = HeroColorScheme.schemeForProfession(hero.personalData?.profession ?? "")
                        ForEach(0..<4, id: \.self) { i in
                            Rectangle()
                                .fill(auto.sectionColors[i])
                                .frame(width: 20, height: 32)
                        }
                    }
                }
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(label)
                    .font(.system(.body, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
```

**Step 3: Add settings command to Hero command registry**

In `Hesindion/Models/Hero.swift`, the `commandRegistry` cannot directly trigger a settings view (it would need a callback). Instead, we add the command in `HeroDetailView`. At the end of `commandRegistry` (before the final `return commands`), this won't work because the registry returns closures.

Better approach: Add the settings command in `HeroDetailView`'s `filteredCommands`. Actually, the cleanest way is to handle it like "Kampf" — add a command entry and intercept it in `onChange(of: activeCommand)`.

In `HeroDetailView`, add a new `@State`:

```swift
@State private var showHeroSettings = false
```

In the `filteredCommands` computed property (or in the command registry usage), we need to add a settings command. The simplest approach: add it to the `commandRegistry` in `Hero.swift`:

```swift
// At the end of commandRegistry, before `return commands`:
commands.append(AppCommand(
    id: UUID(),
    name: "Einstellungen für \(name)",
    subparameter: nil,
    input: nil,
    execute: { _ in }
))
```

Then in `HeroDetailView`, in the `.onChange(of: activeCommand?.id)` handler, add:

```swift
if cmd.name.hasPrefix("Einstellungen für") {
    showHeroSettings = true
    activeCommand = nil
    return
}
```

And add the `.fullScreenCover`:

```swift
.fullScreenCover(isPresented: $showHeroSettings) {
    HeroSettingsView(hero: hero) { showHeroSettings = false }
}
```

**Step 4: Build and verify**

Run: `make run-ipad`
Test: Open command palette (Ctrl+K), type "Einstellungen", select the settings command, verify the settings view opens.

**Step 5: Commit**

```bash
git add Hesindion/Views/HeroSettingsView.swift Hesindion/Views/HeroDetailView.swift Hesindion/Models/Hero.swift Hesindion/Theme/Strings.swift
git commit -m "feat: add hero settings view with color scheme picker"
```

---

### Task 7: Update Sidebar to Use Scheme Accent Color

**Files:**
- Modify: `Hesindion/Views/HeroListView.swift`

**Step 1: Use scheme accent color for selected hero row**

In the hero `ForEach`, replace the `.listRowBackground` with scheme-derived color:

```swift
.listRowBackground(
    selection == .hero(hero.persistentModelID)
        ? HeroColorScheme.scheme(for: hero).accentColor.opacity(0.35)
        : Color(UIColor.systemBackground)
)
```

**Step 2: Build and verify**

Run: `make run-ipad`

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroListView.swift
git commit -m "feat: use hero color scheme accent for sidebar selection highlight"
```

---

### Task 8: Final Build, Verify, and Update Docs

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Full build and visual verification**

Run: `make run-ipad`
Verify all changes:
- [ ] Sidebar title is centered
- [ ] No rounded corners on sidebar
- [ ] "Held importieren" text is readable (black on gold)
- [ ] Selected hero is clearly visible
- [ ] Attributes column has no right border
- [ ] Panel toggle buttons are filled, no borders
- [ ] Boronmir shows violet gradient sections
- [ ] Combat group stays red regardless of scheme
- [ ] Command palette shows "Einstellungen für ..."
- [ ] Settings view opens and allows scheme selection
- [ ] Changing scheme updates detail view immediately

**Step 2: Update CHANGELOG.md**

Add to `[Unreleased]` section:

```markdown
### Added
- Per-profession color schemes for hero detail views (19 palettes: priests, warriors, mages, mundane)
- Hero settings view accessible via command palette ("Einstellungen für <Hero>")
- Color scheme picker with visual swatch previews

### Changed
- Sidebar title is now centered
- Panel toggle buttons now have filled backgrounds (no borders)

### Fixed
- "Held importieren" button text readability
- Selected hero row visibility in sidebar
- Removed unnecessary border from attributes column
```

**Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update changelog with color scheme feature and UI fixes"
```
