import SwiftUI

/// "Vor der Probe" (sheet cut-over design §6): before the roll, what the current loadout does to
/// this talent check, and the choices that hold for this check only — nothing here changes the
/// stored loadout. Reads `TalentBelastung.lines` — the same call that feeds the modal's own
/// modifier list — so the summary and the roll cannot drift apart.
struct VorDerProbeRow: View {
    let hero: Hero
    let talentId: String
    @Binding var choices: TalentBelastung.Choices
    var accent: Color = .groupPersonalData
    var onOpenLoadout: () -> Void

    private var result: TalentBelastung.Result {
        TalentBelastung.lines(hero: hero, talentId: talentId, choices: choices)
    }

    /// Worn armour, then the selected shield — the pieces the toggles below name, in the order
    /// the summary lists them. Independent of `choices.putDown`: a piece already put down for
    /// this check still needs its own toggle to put it back on.
    private var pieces: [String] {
        var names = hero.armorsInOrder.filter(\.isEquipped).map(\.name)
        if let shield = hero.selectedShieldName { names.append(shield) }
        return names
    }

    var body: some View {
        let total = result.lines.reduce(0) { $0 + $1.value }
        VStack(alignment: .leading, spacing: 8) {
            Text(L("vorDerProbe.label"))
                .font(.dsaHeading(.caption))
                .foregroundStyle(accent)

            Text(String(format: L("vorDerProbe.summary"), StateCatalog.roman(result.level), total,
                       pieces.joined(separator: ", ")))
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(pieces, id: \.self) { name in
                    DSAToggleRow(
                        title: name,
                        isOn: putDownBinding(for: name),
                        accent: accent,
                        subtitle: L("vorDerProbe.putDown"),
                        identifier: "vorDerProbe.putDown.\(name)"
                    )
                }

                DSAToggleRow(
                    title: L("vorDerProbe.ignore"),
                    isOn: $choices.ignoreBelastung,
                    accent: accent,
                    identifier: "vorDerProbe.ignore"
                )

                if TalentBelastung.isMaybe(talentId: talentId) {
                    DSAToggleRow(
                        title: L("vorDerProbe.zaehlt"),
                        isOn: $choices.belastungZaehlt,
                        accent: accent,
                        identifier: "vorDerProbe.zaehlt"
                    )
                }
            }

            Button(action: onOpenLoadout) {
                Text(L("vorDerProbe.loadout"))
                    .font(.dsaHeading(.caption))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("vorDerProbe.loadout")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accent.opacity(0.1))
        .dsaBox(.flush)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vorDerProbe.row")
    }

    private func putDownBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { choices.putDown.contains(name) },
            set: { isDown in
                if isDown { choices.putDown.insert(name) } else { choices.putDown.remove(name) }
            }
        )
    }
}
