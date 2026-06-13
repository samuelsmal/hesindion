import SwiftUI
import SwiftData

/// A wrapping strip of `StateChip`s drawn from `hero.activeStates`, plus implied states
/// and a trailing "+" chip that opens `StatePickerSheet`. The COMBAT STATUS strip:
/// compact and glanceable, tap a chip → `StateDetailSheet` (removal happens there via
/// "Entfernen"); derived/implied chips rendered distinct and non-removable. No long-press.
///
/// The hero detail uses swipe-to-remove rows (`StatesSectionView`) instead of this strip.
/// The combat surface passes `accent: .groupCombat` to keep its red status aesthetic.
struct StatesStrip: View {
    @Bindable var hero: Hero
    /// Background accent for "live" (manually-tracked) chips.
    var accent: Color = .groupCombat

    @State private var showPicker = false
    @State private var detailState: StateSelection?

    /// Identifiable wrapper so `.sheet(item:)` can present the detail for a tapped state.
    private struct StateSelection: Identifiable {
        let def: StateDefinition
        var id: String { def.id }
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
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(hero.activeStates, id: \.def.id) { entry in
                let derived = StateCatalog.derivedIDs.contains(entry.def.id)
                StateChip(
                    def: entry.def,
                    level: entry.level,
                    isDerived: derived,
                    accent: accent,
                    onTap: { detailState = StateSelection(def: entry.def) }
                )
            }

            ForEach(impliedOnlyDefs) { def in
                StateChip(
                    def: def,
                    level: 1,
                    isDerived: true,
                    accent: accent,
                    onTap: { detailState = StateSelection(def: def) }
                )
            }

            addChip
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
