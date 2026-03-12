# Rulebook View & Swipe-to-Lookup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add a browsable Regelbuch as a sidebar section and swipe-to-reveal lookup buttons on hero detail rows.

**Architecture:** Two-section NavigationSplitView sidebar (Regelbuch + Helden) with shared detail pane. SidebarSelection enum drives detail content. SwipeActionRow provides generic swipe-to-reveal with configurable action buttons.

**Tech Stack:** SwiftUI, SwiftData, SQLite (RulesDatabase)

**Design doc:** `docs/plans/2026-03-07-rulebook-view-design.md`

---

### Task 1: Add category listing and name lookup to RulesDatabase

**Files:**
- Modify: `Hesindion/Services/RulesDatabase.swift`

**Step 1: Add categories() method**

After line 80 (end of `search` method), add:

```swift
func categories() -> [String] {
    let sql = "SELECT DISTINCT category FROM rules ORDER BY category"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }

    var results: [String] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        results.append(col_text(stmt, 0))
    }
    return results
}
```

**Step 2: Add rulesByCategory() method**

```swift
func rulesByCategory(_ category: String, locale: String = "de-DE") -> [RuleSearchResult] {
    let sql = """
        SELECT r.id, r.category, i.name, i.description
        FROM rules r
        JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
        WHERE r.category = ?
        ORDER BY i.name
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, locale, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, category, -1, SQLITE_TRANSIENT)

    var results: [RuleSearchResult] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        results.append(RuleSearchResult(
            id: col_text(stmt, 0),
            category: col_text(stmt, 1),
            name: col_text(stmt, 2),
            description: col_text_opt(stmt, 3) ?? ""
        ))
    }
    return results
}
```

**Step 3: Add lookupByName() method**

For swipe-to-lookup matching (find rule by display name):

```swift
func lookupByName(_ name: String, locale: String = "de-DE") -> RuleDetail? {
    let sql = """
        SELECT r.id
        FROM rules r
        JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
        WHERE i.name = ?
        LIMIT 1
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, locale, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)

    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    let ruleId = col_text(stmt, 0)
    return lookup(id: ruleId, locale: locale)
}
```

**Step 4: Commit**

```bash
git add Hesindion/Services/RulesDatabase.swift
git commit -m "feat: add category listing and name lookup to RulesDatabase"
```

---

### Task 2: Create SidebarSelection enum and refactor HeroListView

**Files:**
- Modify: `Hesindion/Views/HeroListView.swift`
- Modify: `Hesindion/ContentView.swift` (no changes needed — it just wraps HeroListView)

**Step 1: Add SidebarSelection enum**

At the top of `HeroListView.swift`, before the struct:

```swift
import SwiftData

enum SidebarSelection: Hashable {
    case rulebook
    case hero(PersistentIdentifier)
    case rule(String)
}
```

**Step 2: Refactor HeroListView state**

Replace `@State private var selectedHero: Hero?` with:

```swift
@State private var selection: SidebarSelection? = nil
@State private var previousSelection: SidebarSelection? = nil
```

**Step 3: Refactor sidebarContent**

Replace the sidebar content with a two-section List:

```swift
@ViewBuilder
private var sidebarContent: some View {
    List(selection: $selection) {
        Section("Regelbuch") {
            Label("Regelbuch", systemImage: "book.closed")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .tag(SidebarSelection.rulebook)
        }

        Section("Helden") {
            ForEach(heroes, id: \.persistentModelID) { hero in
                Text(hero.name)
                    .font(.system(.title3, design: .default, weight: .bold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .tag(SidebarSelection.hero(hero.persistentModelID))
            }
        }
    }
    .listStyle(.sidebar)
}
```

Remove the `heroes.isEmpty` check from sidebarContent (always show Regelbuch even with no heroes).

**Step 4: Refactor detailContent**

```swift
@ViewBuilder
private var detailContent: some View {
    switch selection {
    case .rulebook:
        RulebookView(sidebarSelection: $selection)
    case .hero(let id):
        if let hero = heroes.first(where: { $0.persistentModelID == id }) {
            HeroDetailView(hero: hero, sidebarSelection: $selection)
        }
    case .rule(let ruleId):
        RuleDetailView(
            ruleId: ruleId,
            sidebarSelection: $selection,
            previousSelection: previousSelection
        )
    case nil:
        ContentUnavailableView(
            heroes.isEmpty ? "Keine Helden" : "Auswahl treffen",
            systemImage: "shield",
            description: Text(
                heroes.isEmpty
                    ? "Importiere eine JSON- oder YAML-Datei, um deinen ersten Helden hinzuzufuegen."
                    : "Waehle einen Helden oder das Regelbuch aus der Liste."
            )
        )
    }
}
```

**Step 5: Track previousSelection**

Add an `.onChange` on `selection`:

```swift
.onChange(of: selection) { oldValue, newValue in
    if case .rule = newValue, oldValue != nil {
        previousSelection = oldValue
    }
}
```

**Step 6: Remove NavigationLink/navigationDestination pattern**

The old code used `NavigationLink(value: hero)` with `.navigationDestination`. Replace with the tag-based selection approach above. Remove the `.navigationDestination(for: Hero.self)` modifier.

**Step 7: Commit**

```bash
git add Hesindion/Views/HeroListView.swift
git commit -m "feat: refactor HeroListView into two-section sidebar with SidebarSelection"
```

---

### Task 3: Create RulebookView with category browsing and search

**Files:**
- Create: `Hesindion/Views/RulebookView.swift`
- Modify: `Hesindion/Theme/AttributeColors.swift` (add groupRulebook color)

**Step 1: Add groupRulebook color**

In `AttributeColors.swift`, add:

```swift
static let groupRulebook = Color(red: 0x7c / 255, green: 0x3a / 255, blue: 0xed / 255) // purple
```

**Step 2: Create RulebookView**

```swift
import SwiftUI

struct RulebookView: View {
    @Binding var sidebarSelection: SidebarSelection?
    @State private var searchText = ""

    private let categoryOrder = [
        "advantage", "disadvantage", "special_ability",
        "combat_technique", "skill", "condition", "state"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(pinnedViews: [.sectionHeaders]) {
                // Header
                Text("Regelbuch")
                    .font(.system(.largeTitle, design: .default, weight: .black))
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.groupRulebook)
                    .foregroundStyle(.white)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                let results = searchResults
                ForEach(categoryOrder, id: \.self) { category in
                    let rules = results[category] ?? []
                    if !rules.isEmpty {
                        CollapsibleSection(categoryLabel(category)) {
                            ForEach(rules) { rule in
                                Button {
                                    sidebarSelection = .rule(rule.id)
                                } label: {
                                    ruleRow(rule)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .searchable(text: $searchText, prompt: "Regel suchen...")
        .environment(\.groupColor, .groupRulebook)
        .environment(\.groupTextColor, .white)
    }

    private var searchResults: [String: [RuleSearchResult]] {
        if searchText.count >= 2 {
            let results = RulesDatabase.shared.search(query: searchText, limit: 50)
            return Dictionary(grouping: results, by: \.category)
        } else {
            var grouped: [String: [RuleSearchResult]] = [:]
            for cat in categoryOrder {
                grouped[cat] = RulesDatabase.shared.rulesByCategory(cat)
            }
            return grouped
        }
    }

    private func ruleRow(_ rule: RuleSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule.name)
                .font(.body)
                .foregroundStyle(Color.primary)
            if !rule.description.isEmpty {
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "advantage": "Vorteile"
        case "disadvantage": "Nachteile"
        case "special_ability": "Sonderfertigkeiten"
        case "combat_technique": "Kampftechniken"
        case "skill": "Talente"
        case "condition": "Zustaende"
        case "state": "Status"
        default: category
        }
    }
}
```

**Step 3: Commit**

```bash
git add Hesindion/Views/RulebookView.swift Hesindion/Theme/AttributeColors.swift
git commit -m "feat: add RulebookView with category browsing and search"
```

---

### Task 4: Create RuleDetailView as full detail pane

**Files:**
- Create: `Hesindion/Views/RuleDetailView.swift`

**Step 1: Create RuleDetailView**

Adapt content from `RuleDetailSheet` (lines 332-441 of `CommandPaletteOverlay.swift`):

```swift
import SwiftUI

struct RuleDetailView: View {
    let ruleId: String
    @Binding var sidebarSelection: SidebarSelection?
    let previousSelection: SidebarSelection?

    private var rule: RuleDetail? {
        RulesDatabase.shared.lookup(id: ruleId)
    }

    var body: some View {
        if let rule {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    if let prev = previousSelection {
                        Button {
                            sidebarSelection = prev
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(backLabel(prev))
                            }
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(Color.groupRulebook)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Header
                    Text(rule.name)
                        .font(.system(.largeTitle, design: .default, weight: .black))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.groupRulebook)
                        .foregroundStyle(.white)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        // Meta badges
                        HStack(spacing: 8) {
                            metaBadge(categoryLabel(rule.category))
                            if let cost = rule.cost {
                                metaBadge("AP: \(cost)")
                            }
                            if let levels = rule.levels {
                                metaBadge("Stufen: \(levels)")
                            }
                        }

                        // Description
                        if !rule.description.isEmpty {
                            Text(rule.description)
                                .font(.body)
                        }

                        // Effects
                        if !rule.effects.isEmpty {
                            Text("Effekte")
                                .font(.system(.subheadline, weight: .black))
                                .padding(.top, 4)

                            ForEach(Array(rule.effects.enumerated()), id: \.offset) { _, effect in
                                effectRow(effect)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        } else {
            ContentUnavailableView(
                "Regel nicht gefunden",
                systemImage: "book.closed",
                description: Text("Die Regel konnte nicht geladen werden.")
            )
        }
    }

    private func backLabel(_ sel: SidebarSelection) -> String {
        switch sel {
        case .hero: "Zurueck zum Helden"
        case .rulebook: "Zurueck zum Regelbuch"
        default: "Zurueck"
        }
    }

    // Copy metaBadge, effectRow, categoryLabel from RuleDetailSheet
    private func metaBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.groupRulebook.opacity(0.2))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private func effectRow(_ effect: RuleEffect) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let level = effect.level {
                Text("Stufe \(level)")
                    .font(.system(.caption, weight: .bold))
                    .frame(width: 56, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(effect.type)
                        .font(.system(.caption, weight: .bold))
                    if let attr = effect.attribute {
                        Text(attr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let val = effect.value {
                        Text(val >= 0 ? "+\(Int(val))" : "\(Int(val))")
                            .font(.system(.caption, weight: .bold))
                            .fontDesign(.monospaced)
                    }
                }
                if let desc = effect.description {
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "advantage": "Vorteil"
        case "disadvantage": "Nachteil"
        case "special_ability": "Sonderfertigkeit"
        case "combat_technique": "Kampftechnik"
        case "skill": "Talent"
        case "condition": "Zustand"
        case "state": "Status"
        default: category
        }
    }
}
```

**Step 2: Commit**

```bash
git add Hesindion/Views/RuleDetailView.swift
git commit -m "feat: add RuleDetailView as full detail pane with back navigation"
```

---

### Task 5: Refactor TalentSwipeRow into generic SwipeActionRow

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift` (lines 758-840)

**Step 1: Create SwipeActionRow**

Replace `TalentSwipeRow` with a generic `SwipeActionRow`. Keep it in HeroDetailView.swift (private):

```swift
struct SwipeAction {
    let icon: String
    let color: Color
    let action: () -> Void
}

private struct SwipeActionRow: View {
    let label: String
    let value: String
    let actions: [SwipeAction]

    @State private var offset: CGFloat = 0
    @State private var settled: Bool = false
    @State private var dragDirection: DragDirection = .undecided

    private var revealWidth: CGFloat { CGFloat(actions.count) * 56 }
    private let triggerThreshold: CGFloat = 120

    private enum DragDirection { case undecided, horizontal, vertical }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background action buttons
            HStack(spacing: 0) {
                Spacer()
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    Button {
                        withAnimation(DSAAnimation.standard) { offset = 0 }
                        settled = false
                        action.action()
                    } label: {
                        Image(systemName: action.icon)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(action.color)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(actions.last?.color ?? .gray)

            // Foreground content
            HStack {
                Text(label).font(.body)
                Spacer()
                if !value.isEmpty {
                    Text(value).font(.system(.body, design: .monospaced))
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        guard !settled else { return }
                        if dragDirection == .undecided {
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            if dx > dy * 1.5 && value.translation.width < 0 {
                                dragDirection = .horizontal
                            } else if dy > dx {
                                dragDirection = .vertical
                            }
                        }
                        if dragDirection == .horizontal {
                            offset = min(0, value.translation.width)
                        }
                    }
                    .onEnded { value in
                        defer { dragDirection = .undecided }
                        guard !settled, dragDirection == .horizontal else { return }
                        if -offset > triggerThreshold, let last = actions.last {
                            // Full swipe triggers default (last) action
                            withAnimation(DSAAnimation.standard) { offset = 0 }
                            last.action()
                        } else if -offset > revealWidth / 2 {
                            // Partial swipe reveals buttons
                            withAnimation(DSAAnimation.standard) { offset = -revealWidth }
                            settled = true
                        } else {
                            withAnimation(DSAAnimation.standard) { offset = 0 }
                        }
                    }
            )
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if settled {
                withAnimation(DSAAnimation.standard) { offset = 0 }
                settled = false
            }
        }
    }
}
```

**Step 2: Update talentsSections**

Replace the TalentSwipeRow usage with SwipeActionRow:

```swift
@ViewBuilder private var talentsSections: some View {
    let grouped = Dictionary(grouping: hero.talents, by: \.category)
    ForEach(talentCategoryOrder, id: \.self) { category in
        if let items = grouped[category], !items.isEmpty {
            CollapsibleSection(category) {
                ForEach(items, id: \.persistentModelID) { talent in
                    SwipeActionRow(
                        label: talent.name,
                        value: "\(talent.value)",
                        actions: talentActions(for: talent)
                    )
                    Divider()
                }
            }
        }
    }
}

private func talentActions(for talent: Talent) -> [SwipeAction] {
    var actions: [SwipeAction] = []
    // Lookup action (if rule exists)
    if let rule = RulesDatabase.shared.lookupByName(talent.name) {
        actions.append(SwipeAction(icon: "book.closed", color: .groupRulebook) {
            sidebarSelection = .rule(rule.id)
        })
    }
    // Dice action (always for talents)
    actions.append(SwipeAction(icon: "dice.fill", color: .groupCombat) {
        activeTalentProbe = talent
    })
    return actions
}
```

**Step 3: Update advantagesSection**

```swift
@ViewBuilder private var advantagesSection: some View {
    if !hero.advantages.isEmpty {
        CollapsibleSection("Advantages") {
            ForEach(hero.advantages, id: \.self) { item in
                SwipeActionRow(
                    label: item,
                    value: "",
                    actions: lookupActions(for: item)
                )
            }
        }
    }
}
```

**Step 4: Add lookupActions helper**

```swift
private func lookupActions(for name: String) -> [SwipeAction] {
    guard let rule = RulesDatabase.shared.lookupByName(name) else { return [] }
    return [SwipeAction(icon: "book.closed", color: .groupRulebook) {
        sidebarSelection = .rule(rule.id)
    }]
}
```

**Step 5: Update disadvantagesSection, generalSpecialAbilitiesSection, combatSpecialAbilitiesSection**

Same pattern as advantagesSection — use `SwipeActionRow` with `lookupActions(for:)`.

**Step 6: Update combatTechniquesSection**

Use SwipeActionRow with lookup action. Keep the existing AT/PA sub-display by either using a custom view or extending SwipeActionRow.

Since combat techniques have sub-rows (AT/PA), wrap the existing layout in a SwipeActionRow-like pattern, or show the lookup action only on the main row. Simplest: use FieldRow for AT/PA display below SwipeActionRow.

**Step 7: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift
git commit -m "feat: refactor TalentSwipeRow into SwipeActionRow with lookup support"
```

---

### Task 6: Wire deep-linking from hero detail to rule book

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift`
- Modify: `Hesindion/Views/HeroListView.swift`

**Step 1: Add sidebarSelection binding to HeroDetailView**

Add to HeroDetailView:

```swift
@Binding var sidebarSelection: SidebarSelection?
```

Update all call sites in HeroListView to pass the binding.

**Step 2: Verify previousSelection tracking**

The `.onChange(of: selection)` in HeroListView (Task 2, Step 5) already stores previousSelection when navigating to `.rule`. Verify it captures the hero context correctly.

**Step 3: Pass previousSelection to RuleDetailView**

Already handled in Task 2's detailContent switch. Verify the back button works.

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift Hesindion/Views/HeroListView.swift
git commit -m "feat: wire deep-linking from hero swipe-lookup to rule detail"
```

---

### Task 7: Build verification and cleanup

**Step 1: Build**

```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build
```

**Step 2: Fix any build errors**

Common issues to watch for:
- Missing imports
- SidebarSelection not visible across files (may need to move to its own file or make non-private)
- Preview providers referencing old HeroDetailView init (needs sidebarSelection binding)

**Step 3: Consider removing RuleDetailSheet**

If `.sheet(item: $selectedRule)` in HeroDetailView is no longer needed (rules now open in detail pane), remove:
- `@State private var selectedRule: RuleDetail?` from HeroDetailView
- The `.sheet(item: $selectedRule)` modifier
- The `selectedRule` binding from CommandSearchOverlay
- Update CommandSearchOverlay to navigate via sidebarSelection instead

Keep `RuleDetailSheet` if the command palette still uses it.

**Step 4: Update command palette rule search**

Update CommandSearchOverlay to set `sidebarSelection = .rule(id)` instead of `selectedRule = ...`. This unifies rule navigation.

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: cleanup and unify rule navigation"
```

---

## Dependency Graph

```
Task 1 (RulesDatabase methods)
  |
  +---> Task 2 (Sidebar refactor) --+---> Task 3 (RulebookView)
  |                                  |
  |                                  +---> Task 4 (RuleDetailView)
  |                                  |
  +---> Task 5 (SwipeActionRow) -----+---> Task 6 (Deep-linking)
                                                |
                                                +---> Task 7 (Build & cleanup)
```

Tasks 3, 4, and 5 can run in parallel after their dependencies are met.
