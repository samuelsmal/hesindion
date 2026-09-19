import SwiftUI

/// Which of the hero's weapons the info sheet is about. Names are what the
/// loadout and the rows identify a weapon by.
struct WeaponInfoTarget: Identifiable, Equatable {
    let name: String
    var id: String { name }
}

/// What the rules say about one of the hero's weapons or shields: the hero's own
/// values, and — when Optolith's inventory has the weapon — the template's
/// TP, AT/PA-Mod, RW, whether it is geweiht (by name, like the consecration
/// default — the Regelwiki's reading, not one template's note), Vorteil, Nachteil and Hinweis,
/// whatever of that is present. A weapon with no entry shows only the hero's own
/// values.
struct WeaponInfoSheet: View {
    let hero: Hero
    let name: String
    @Environment(\.dismiss) private var dismiss

    private var entry: EquipmentEntry? { hero.equipmentEntry(forLoadoutNamed: name) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    section(L("weapon.info.hero"), rows: heroRows)
                    if let entry {
                        section(L("weapon.info.template"), rows: templateRows(entry))
                        if let deity = hero.consecratedDeity(ofLoadoutNamed: name) {
                            Text(String(format: L("weapon.consecratedTo"), deity))
                                .font(.dsaHeading(.body))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.dsaDark)
                                .dsaBox(.flush)
                                .accessibilityIdentifier("weapon.info.consecrated")
                        }
                        text(L("weapon.advantage"), entry.advantage, id: "advantage")
                        text(L("weapon.disadvantage"), entry.disadvantage, id: "disadvantage")
                        text(L("weapon.note"), entry.note, id: "note")
                    }
                }
                .padding(16)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("weapon.info.title"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.white.opacity(0.8))
                Text(name)
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityLabel(L("close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(combatAccent)
        .dsaBox(.raised)
    }

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.dsaHeading(.caption))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            ForEach(rows, id: \.0) { label, value in
                Divider()
                HStack {
                    Text(label).font(.dsaBody(.body)).foregroundStyle(.secondary)
                    Spacer()
                    Text(value).font(.dsaMono(.body, emphasis: true))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsaBox(.flush)
    }

    @ViewBuilder
    private func text(_ title: String, _ body: String?, id: String) -> some View {
        if let body {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.dsaHeading(.caption))
                Text(body).font(.dsaBody(.body))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsaBox(.flush)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weapon.info.\(id)")
        }
    }

    // MARK: - Rows

    /// The hero's own numbers — what the rows elsewhere show, repeated so the
    /// sheet can be read on its own.
    private var heroRows: [(String, String)] {
        if let w = hero.meleeWeapons.first(where: { $0.name == name }) {
            return [(L("tp"), w.damage), ("AT", "\(w.at)"), ("PA", "\(w.pa)"), (L("reach"), w.reach)]
        }
        if let s = hero.shields.first(where: { $0.name == name }) {
            return [(L("tp"), s.damage), ("AT", "\(s.at)"), ("PA", "\(s.pa)"), (L("reach"), s.reach)]
        }
        if let r = hero.rangedWeapons.first(where: { $0.name == name }) {
            return [(L("tp"), r.damage), ("FK", "\(r.at)"), (L("range"), r.range)]
        }
        return []
    }

    private func templateRows(_ entry: EquipmentEntry) -> [(String, String)] {
        var rows: [(String, String)] = []
        if let damage = entry.damage { rows.append((L("tp"), damage)) }
        if entry.at != nil || entry.pa != nil {
            rows.append((L("weapon.atPaMod"), "\(Self.signed(entry.at)) / \(Self.signed(entry.pa))"))
        }
        if let reach = entry.weaponReach { rows.append((L("reach"), reach.rawValue)) }
        return rows
    }

    /// "+1", "0", "−6" (the typographic minus the app uses for modifiers), "—"
    /// where the template has no value (a weapon that cannot parry).
    static func signed(_ value: Int?) -> String {
        guard let value else { return "—" }
        if value > 0 { return "+\(value)" }
        if value < 0 { return "−\(-value)" }
        return "0"
    }
}

/// The ⓘ that opens `WeaponInfoSheet`, for the weapon rows on the hero sheet
/// and in the loadout picker.
struct WeaponInfoButton: View {
    let name: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.dsaBody(.body))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.dsaMotion)
        .accessibilityLabel(L("weapon.info.title"))
        .accessibilityIdentifier("weapon.info.\(name)")
    }
}
