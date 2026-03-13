# iPad-Optimized Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Adapt HeroDetailView for iPad landscape use — fixed attributes column, inline talent probe abbreviations, grid personal data, and Ctrl+K command palette shortcut.

**Architecture:** Environment-based adaptive layout using `@Environment(\.horizontalSizeClass)`. `.regular` triggers landscape optimizations (attributes column, wider grids). `.compact` preserves current behavior. All changes are in existing files — no new files created.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

---

### Task 1: Add `AttributesColumn` View

**Files:**
- Modify: `Hesindion/Views/HeroDetailComponents.swift:1-34`

**Step 1: Add `AttributesColumn` below the existing `AttributesBar`**

Add a new view struct after `AttributesBar` (line 34) in `HeroDetailComponents.swift`:

```swift
// MARK: - AttributesColumn

struct AttributesColumn: View {
    let attrs: Attributes

    var body: some View {
        VStack(spacing: 0) {
            attrCell("MU", attrs.mu)
            attrCell("KL", attrs.kl)
            attrCell("IN", attrs.inValue)
            attrCell("CH", attrs.ch)
            attrCell("FF", attrs.ff)
            attrCell("GE", attrs.ge)
            attrCell("KO", attrs.ko)
            attrCell("KK", attrs.kk)
        }
        .frame(width: 80)
        .overlay(alignment: .trailing) {
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(Color.dsaBorder)
        }
    }

    private func attrCell(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, weight: .bold))
            Text("\(value)")
                .font(.system(.title3, weight: .black))
        }
        .foregroundStyle(Color.attributeForeground(for: label))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.attributeBackground(for: label))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailComponents.swift
git commit -m "feat: add AttributesColumn view for iPad landscape"
```

---

### Task 2: Wire Adaptive Attributes Layout into HeroDetailView

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:6-88`

**Step 1: Add horizontalSizeClass environment**

At line 9, after the `@Binding var sidebarSelection` line, add:

```swift
@Environment(\.horizontalSizeClass) private var sizeClass
```

**Step 2: Restructure body to use HStack in regular mode**

Currently the `body` has this structure (simplified):
```
ZStack {
    ScrollView {
        LazyVStack(pinnedViews: [.sectionHeaders]) {
            // name heading
            if let attrs = hero.attributes {
                Section {
                    // groups...
                } header: {
                    AttributesBar(attrs: attrs)
                }
            }
        }
    }
    // overlays...
}
```

Wrap the `ScrollView` in a conditional layout. Replace lines 22–88 (the `ScrollView { ... }` block including the `Section header:` for `AttributesBar`) with:

```swift
            if let attrs = hero.attributes, sizeClass == .regular {
                HStack(spacing: 0) {
                    AttributesColumn(attrs: attrs)
                    ScrollView {
                        LazyVStack {
                            nameHeading
                            groupsContent(attrs: attrs)
                        }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y + geo.contentInsets.top
                    } action: { _, y in
                        if y < -120 && !showCommandSearch {
                            showCommandSearch = true
                            commandQuery = ""
                            searchFocused = true
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(pinnedViews: [.sectionHeaders]) {
                        nameHeading
                        if let attrs = hero.attributes {
                            SwiftUI.Section {
                                groupsContent(attrs: attrs)
                            } header: {
                                AttributesBar(attrs: attrs)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, y in
                    if y < -120 && !showCommandSearch {
                        showCommandSearch = true
                        commandQuery = ""
                        searchFocused = true
                    }
                }
            }
```

**Step 3: Extract `nameHeading` and `groupsContent` computed properties**

Add these private computed properties to `HeroDetailView`:

```swift
    @ViewBuilder private var nameHeading: some View {
        Text(hero.name)
            .font(.system(.largeTitle, design: .default, weight: .black))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupPersonalData)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    @ViewBuilder private func groupsContent(attrs: Attributes) -> some View {
        VStack(spacing: 0) {
            CollapsibleGroup(L("groupPersonalData"), color: .groupPersonalData) {
                VStack(spacing: 8) {
                    personalDataSection
                    experienceSection
                    derivedValuesSection
                    advantagesSection
                    disadvantagesSection
                    generalSpecialAbilitiesSection
                    languagesSection
                    scriptsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            CollapsibleGroup(L("groupTalents"), color: .groupTalents, textColor: .white) {
                VStack(spacing: 8) {
                    talentsSections
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            CollapsibleGroup(L("groupCombat"), color: .groupCombat) {
                VStack(spacing: 8) {
                    combatTechniquesSection
                    combatSpecialAbilitiesSection
                    meleeWeaponsSection
                    rangedWeaponsSection
                    armorSection
                    shieldSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            CollapsibleGroup(L("groupEquipment"), color: .groupEquipment, textColor: .white) {
                VStack(spacing: 8) {
                    equipmentSection
                    moneySection
                    petsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 16)
    }
```

**Step 4: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: adaptive attributes column in landscape, bar in portrait"
```

---

### Task 3: Add Probe Abbreviations to Talent Rows

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:499-515` (talentsSections)
- Modify: `Hesindion/Views/HeroDetailView.swift:953-970` (DefaultSwipeContent or new TalentSwipeContent)

**Step 1: Create TalentSwipeContent view**

Add a new view near `DefaultSwipeContent` (after line 970) in `HeroDetailView.swift`:

```swift
/// Talent row content showing name, probe abbreviations, and value.
struct TalentSwipeContent: View {
    let name: String
    let value: Int
    let probeKeys: [String]?

    var body: some View {
        HStack(spacing: 0) {
            Text(L(name)).font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let keys = probeKeys {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.attributeForeground(for: key))
                        .frame(width: 32, height: 24)
                        .background(Color.attributeBackground(for: key).opacity(0.7))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }
            }
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }
}
```

**Step 2: Update `talentsSections` to use `TalentSwipeContent`**

Replace the `SwipeActionRow` call in `talentsSections` (lines 505-509):

```swift
// Before:
SwipeActionRow(
    label: talent.name,
    value: "\(talent.value)",
    actions: talentActions(for: talent)
)

// After:
SwipeActionRow(actions: talentActions(for: talent)) {
    TalentSwipeContent(
        name: talent.name,
        value: talent.value,
        probeKeys: TalentProbeAttributes.checks[talent.name]
    )
}
```

**Step 3: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: show probe attribute abbreviations in talent rows"
```

---

### Task 4: Personal Data Grid Layout

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:237-258` (personalDataSection)

**Step 1: Replace vertical FieldRow stack with LazyVGrid**

Replace the `personalDataSection` computed property (lines 237-258):

```swift
    @ViewBuilder private var personalDataSection: some View {
        if let pd = hero.personalData {
            CollapsibleSection(L("personalData")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], alignment: .leading, spacing: 0) {
                    FieldRow(label: "name", value: pd.name)
                    FieldRow(label: "family", value: pd.family)
                    FieldRow(label: "birthplace", value: pd.birthplace)
                    FieldRow(label: "birthdate", value: pd.birthdate)
                    FieldRow(label: "age", value: "\(pd.age)")
                    FieldRow(label: "gender", value: pd.gender)
                    FieldRow(label: "species", value: pd.species)
                    FieldRow(label: "height", value: "\(pd.height) cm")
                    FieldRow(label: "weight", value: "\(pd.weight) st")
                    FieldRow(label: "hairColor", value: pd.hairColor)
                    FieldRow(label: "eyeColor", value: pd.eyeColor)
                    FieldRow(label: "culture", value: pd.culture)
                    FieldRow(label: "socialStatus", value: pd.socialStatus)
                    FieldRow(label: "profession", value: pd.profession)
                    FieldRow(label: "title", value: pd.title)
                }
                // characteristics spans full width — outside grid
                if !pd.characteristics.isEmpty {
                    FieldRow(label: "characteristics", value: pd.characteristics)
                }
            }
        }
    }
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: personal data fields in adaptive grid layout"
```

---

### Task 5: Ctrl+K Keyboard Shortcut for Command Palette

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:131` (after closing brace of ZStack)

**Step 1: Add `.onKeyPress` modifier**

Add after the ZStack closing brace (line 131), before `.fullScreenCover`:

```swift
        .onKeyPress(.init("k"), modifiers: .control) {
            if !showCommandSearch {
                showCommandSearch = true
                commandQuery = ""
                searchFocused = true
            }
            return .handled
        }
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: Ctrl+K keyboard shortcut opens command palette"
```

---

### Task 6: Integration Verification

**Step 1: Build the full project**

Run: `make build`
Expected: BUILD SUCCEEDED, 0 errors, 0 warnings related to our changes

**Step 2: Deploy to simulator and verify**

Run: `make run`

Manual checks:
- [ ] iPad landscape: attributes show as fixed left column, not scrolling with content
- [ ] iPad portrait: attributes show as horizontal bar at top (pinned header)
- [ ] Talent rows show 3 colored probe abbreviation badges between name and value
- [ ] Personal data section displays in 2-3 column grid (landscape) / 2 columns (portrait)
- [ ] Characteristics field spans full width
- [ ] Ctrl+K opens command palette overlay
- [ ] Pull-down gesture still opens command palette overlay
- [ ] Swipe actions on talent rows still work (dice, book)

**Step 3: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: polish iPad layout integration"
```

**Step 4: Update CHANGELOG.md**

Add under `[Unreleased]`:

```markdown
### Added
- Adaptive attributes column fixed to left side in iPad landscape mode
- Inline probe attribute abbreviations (e.g., KL, CH, GE) in talent rows
- Personal data fields display in responsive grid layout
- Ctrl+K keyboard shortcut to open command palette
```

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for iPad layout improvements"
```
