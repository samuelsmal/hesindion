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
                        onTap: {},
                        onLongPress: {}
                    )
                }

                ForEach(impliedOnlyDefs) { def in
                    StateChip(def: def, level: 1, isDerived: true)
                }

                addChip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showPicker) {
            StatePickerSheet(hero: hero)
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
