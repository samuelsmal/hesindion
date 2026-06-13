import SwiftUI
import SwiftData

/// The "Zustände & Status" content for the hero detail: thin wrapper around the shared
/// `StatesStrip` (a wrapping strip of `StateChip`s from `hero.activeStates` plus implied
/// states and a trailing "+" picker chip). The same `StatesStrip` is reused in
/// `CombatRootView`'s STATUS section so both surfaces behave identically.
struct StatesSectionView: View {
    @Bindable var hero: Hero

    var body: some View {
        StatesStrip(hero: hero)
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
