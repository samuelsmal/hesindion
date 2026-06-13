import SwiftUI
import SwiftData

/// The "Zustände & Status" content for the hero detail: active states render as a vertical
/// list of `SwipeActionRow`s (matching advantages/talents/spells), with swipe-left to remove
/// and tap to open the `StateDetailSheet`. Derived (Schmerz/Belastung) and implied-only states
/// expose no swipe action — they can't be removed by hand. A trailing "+ Zustand hinzufügen"
/// button opens `StatePickerSheet`.
///
/// The compact chip strip (`StatesStrip`) is used by `CombatRootView`'s STATUS section instead.
struct StatesSectionView: View {
    @Bindable var hero: Hero

    @State private var showPicker = false
    @State private var detailState: StateSelection?

    /// Identifiable wrapper so `.sheet(item:)` can present the detail for a tapped state.
    private struct StateSelection: Identifiable {
        let def: StateDefinition
        var id: String { def.id }
    }

    /// Implied states (e.g. bewusstlos ⇒ liegend) not already explicitly active —
    /// shown for context but not manually removable.
    private var impliedOnlyDefs: [StateDefinition] {
        let active = Set(hero.activeStates.map { $0.def.id })
        return hero.impliedStateIDs
            .subtracting(active)
            .compactMap { StateCatalog.definition(for: $0) }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(hero.activeStates, id: \.def.id) { entry in
                let derived = StateCatalog.derivedIDs.contains(entry.def.id)
                stateRow(def: entry.def, level: entry.level, removable: !derived)
                Divider()
            }

            ForEach(impliedOnlyDefs) { def in
                // Implied-only: shown muted, no swipe-remove.
                stateRow(def: def, level: 1, removable: false, muted: true)
                Divider()
            }

            addRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func stateRow(def: StateDefinition, level: Int, removable: Bool, muted: Bool = false) -> some View {
        let actions: [SwipeAction] = removable
            ? [SwipeAction(icon: "trash", color: .groupCombat) { hero.setStateLevel(def.id, level: 0) }]
            : []
        return SwipeActionRow(actions: actions) {
            StateRowContent(def: def, level: level, muted: muted)
                .contentShape(Rectangle())
                .onTapGesture { detailState = StateSelection(def: def) }
        }
    }

    private var addRow: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .bold))
                Text(L("states.add"))
                    .font(.body)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One state row: leading SF Symbol, localized name, trailing roman level / per-level penalty
/// (matching the chip's value via `StateCatalog.levelValueText`). Implied-only rows render muted.
private struct StateRowContent: View {
    let def: StateDefinition
    let level: Int
    var muted: Bool = false

    var body: some View {
        let value = StateCatalog.levelValueText(for: def, level: level)
        HStack(spacing: 8) {
            Image(systemName: def.iconSystemName)
                .font(.system(.body, weight: .bold))
                .frame(width: 22)
            Text(L(def.nameKey)).font(.body)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(.body, design: .monospaced))
            }
        }
        .foregroundStyle(muted ? Color.secondary : Color.primary)
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
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
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
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
