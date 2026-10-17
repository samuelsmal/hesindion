import SwiftUI
import SwiftData

/// The "Zustand hinzufügen" panel: a `DSAModal` with a search field and two sections
/// (Zustände, Status) drawn from `StateCatalog.manuallyAddable`. Tapping a Status toggles
/// it on; tapping a Zustand's I–IV sets that level. All writes go through
/// `hero.setStateLevel`.
///
/// A modal, not a system sheet (#33): the caller hangs it on its whole screen, like
/// `WeaponInfoSheet`, so the scrim covers the screen.
struct StatePickerSheet: View {
    @Bindable var hero: Hero
    var accent: Color = .groupCombat
    var onDismiss: () -> Void

    @State private var query: String = ""

    private var zustaende: [StateDefinition] {
        StateCatalog.manuallyAddable.filter { $0.kind == .zustand && matches($0) }
    }

    private var statuses: [StateDefinition] {
        StateCatalog.manuallyAddable.filter { $0.kind == .status && matches($0) }
    }

    private func matches(_ def: StateDefinition) -> Bool {
        guard !query.isEmpty else { return true }
        return L(def.nameKey).localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        DSAModal(
            title: L("states.add"),
            accent: accent,
            onScrimTap: onDismiss,
            onClose: onDismiss,
            scrolls: true
        ) {
            searchField
            if !zustaende.isEmpty {
                section(L("states.zustaende.section")) {
                    ForEach(zustaende) { def in
                        zustandRow(def)
                            .dsaRowDivider()
                    }
                }
            }
            if !statuses.isEmpty {
                section(L("states.status.section")) {
                    ForEach(statuses) { def in
                        statusRow(def)
                            .dsaRowDivider()
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("states.search.prompt"), text: $query)
                .font(.dsaBody(.body))
                .autocorrectionDisabled()
                .accessibilityIdentifier("states.picker.search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.dsaMotion)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .dsaBox(.flush)
    }

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.dsaHeading(.caption))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsaRowDivider()
            rows()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsaBox(.flush)
    }

    // MARK: - Rows

    @ViewBuilder private func zustandRow(_ def: StateDefinition) -> some View {
        let level = hero.level(of: def.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: def.iconSystemName)
                    .font(.dsaBody(.body))
                    .foregroundStyle(level > 0 ? accent : .secondary)
                    .frame(width: 24)
                Text(L(def.nameKey))
                    .font(.dsaBody(.body))
                Spacer()
                if level > 0 {
                    Text(StateCatalog.roman(level))
                        .font(.dsaMono(.body, emphasis: true))
                        .foregroundStyle(accent)
                }
            }
            // Inline I–IV stepper: tap a number to set that level; tap the active one to clear.
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { lvl in
                    Button {
                        hero.setStateLevel(def.id, level: level == lvl ? 0 : lvl)
                    } label: {
                        Text(StateCatalog.roman(lvl))
                            .font(.dsaMono(.caption, emphasis: true))
                            .foregroundStyle(level == lvl ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(level == lvl ? accent : Color(UIColor.secondarySystemBackground))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                    .accessibilityIdentifier("states.picker.\(def.id).\(lvl)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder private func statusRow(_ def: StateDefinition) -> some View {
        let isOn = hero.hasState(def.id)
        Button {
            hero.setStateLevel(def.id, level: isOn ? 0 : 1)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: def.iconSystemName)
                    .font(.dsaBody(.body))
                    .foregroundStyle(isOn ? accent : .secondary)
                    .frame(width: 24)
                Text(L(def.nameKey))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.dsaBody(.body))
                    .foregroundStyle(isOn ? accent : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("states.picker.\(def.id)")
    }
}
