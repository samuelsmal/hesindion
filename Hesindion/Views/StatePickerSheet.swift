import SwiftUI
import SwiftData

/// Sheet for adding player states to a hero. Two searchable sections (Zustände, Status)
/// drawn from `StateCatalog.manuallyAddable`. Tapping a Status toggles it on; tapping a
/// Zustand reveals an inline I–IV stepper. All writes go through `hero.setStateLevel`.
struct StatePickerSheet: View {
    @Bindable var hero: Hero
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            List {
                if !zustaende.isEmpty {
                    Section(L("states.zustaende.section")) {
                        ForEach(zustaende) { def in
                            zustandRow(def)
                        }
                    }
                }
                if !statuses.isEmpty {
                    Section(L("states.status.section")) {
                        ForEach(statuses) { def in
                            statusRow(def)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: L("states.search.prompt"))
            .navigationTitle(L("states.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder private func zustandRow(_ def: StateDefinition) -> some View {
        let level = hero.level(of: def.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: def.iconSystemName)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(level > 0 ? Color.groupCombat : .secondary)
                    .frame(width: 24)
                Text(L(def.nameKey))
                    .font(.system(.body, weight: .semibold))
                Spacer()
                if level > 0 {
                    Text(StateCatalog.romanSuffix(level).trimmingCharacters(in: .whitespaces))
                        .font(.system(.body, design: .monospaced, weight: .black))
                        .foregroundStyle(Color.groupCombat)
                }
            }
            // Inline I–IV stepper: tap a number to set that level; tap the active one to clear.
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { lvl in
                    Button {
                        hero.setStateLevel(def.id, level: level == lvl ? 0 : lvl)
                    } label: {
                        Text(StateCatalog.romanSuffix(lvl).trimmingCharacters(in: .whitespaces))
                            .font(.system(.caption, design: .monospaced, weight: .black))
                            .foregroundStyle(level == lvl ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(level == lvl ? Color.groupCombat : Color(UIColor.secondarySystemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.tertiaryBorder))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func statusRow(_ def: StateDefinition) -> some View {
        let isOn = hero.hasState(def.id)
        Button {
            hero.setStateLevel(def.id, level: isOn ? 0 : 1)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: def.iconSystemName)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(isOn ? Color.groupCombat : .secondary)
                    .frame(width: 24)
                Text(L(def.nameKey))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(isOn ? Color.groupCombat : .secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}
