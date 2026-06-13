import SwiftUI
import SwiftData

/// The "Zustände & Status" content for the hero detail: a wrapping strip of `StateChip`s
/// drawn from `hero.activeStates`, plus implied states and a trailing "+" chip that opens
/// `StatePickerSheet`.
///
/// Derived states (Schmerz/Belastung — `StateCatalog.derivedIDs`) and implied states
/// (`hero.impliedStateIDs`) render visually distinct (dashed secondary border) and are
/// NOT removable. Tapping a live chip is wired via `onSelect` (Task 5 detail sheet);
/// long-press is reserved for quick decrement/remove (Task 5).
struct StatesSectionView: View {
    @Bindable var hero: Hero
    @Environment(\.modelContext) private var modelContext
    @State private var showPicker = false
    @State private var detailState: StateSelection?
    /// Bumped on every long-press quick action to drive haptic feedback.
    @State private var quickActionTick = 0
    /// Whether the most recent quick action removed the state (resulting level 0).
    @State private var quickActionRemoved = false

    /// Identifiable wrapper so `.sheet(item:)` can present the detail for a tapped state.
    private struct StateSelection: Identifiable {
        let def: StateDefinition
        var id: String { def.id }
    }

    /// Long-press quick action: Zustand ⇒ decrement one level; Status ⇒ remove.
    /// Derived/implied chips pass no long-press handler.
    private func quickAction(for def: StateDefinition) {
        let newLevel: Int
        if def.kind == .zustand {
            newLevel = hero.level(of: def.id) - 1
        } else {
            newLevel = 0
        }
        hero.setStateLevel(def.id, level: newLevel)
        // Trigger haptic feedback: a warning when the action removed the state,
        // a lighter impact for a decrement.
        quickActionRemoved = newLevel <= 0
        quickActionTick += 1
    }

    /// Implied states (e.g. bewusstlos ⇒ liegend) that aren't already explicitly active,
    /// rendered as non-removable derived-style chips.
    private var impliedOnlyDefs: [StateDefinition] {
        let active = Set(hero.activeStates.map { $0.def.id })
        return hero.impliedStateIDs
            .subtracting(active)
            .compactMap { StateCatalog.definition(for: $0) }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(hero.activeStates, id: \.def.id) { entry in
                    let derived = StateCatalog.derivedIDs.contains(entry.def.id)
                    StateChip(
                        def: entry.def,
                        level: entry.level,
                        isDerived: derived,
                        onTap: { detailState = StateSelection(def: entry.def) },
                        onLongPress: { quickAction(for: entry.def) }
                    )
                }

                ForEach(impliedOnlyDefs) { def in
                    StateChip(
                        def: def,
                        level: 1,
                        isDerived: true,
                        onTap: { detailState = StateSelection(def: def) }
                    )
                }

                addChip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(trigger: quickActionTick) { _, _ in
            quickActionRemoved ? .warning : .impact
        }
        .sheet(isPresented: $showPicker) {
            StatePickerSheet(hero: hero)
                .presentationCornerRadius(0)
                .presentationDetents([.large])
        }
        .sheet(item: $detailState) { selection in
            StateDetailSheet(hero: hero, def: selection.def)
                .presentationCornerRadius(0)
                .presentationDetents([.large])
        }
    }

    private var addChip: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(.caption, weight: .bold))
                Text(L("states.add"))
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .fixedSize()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

/// A simple line-wrapping layout: places subviews left-to-right, wrapping to a new line
/// when the available width is exceeded. Used for the wrapping state-chip strip.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + row.height + (acc > 0 ? lineSpacing : 0)
        }
        let width = rows.map { $0.width }.max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = layoutRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = subviews[item].sizeThatFits(.unspecified)
                subviews[item].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.width + (current.items.isEmpty ? 0 : spacing) + size.width
            if !current.items.isEmpty, proposedWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            if !current.items.isEmpty { current.width += spacing }
            current.items.append(index)
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
