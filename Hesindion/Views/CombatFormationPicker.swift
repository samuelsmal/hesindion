import SwiftUI

/// The formations the hero stands in (issue #44): Formation (SA_862) and
/// Plänkler-Formation (SA_884), each a toggle with the bonus its fighters
/// agreed on. On the preparation screen, and in a modal from the combat root's
/// Formation chip — a formation forms and breaks at any point in the fight.
///
/// Every hero sees both: only one fighter in a formation needs the SF (SA_862.F4,
/// SA_884.P4), so a hero without it stands in an ally's, and the toggle says so.
/// A rider stands in none (rulings formation-mounted, plaenkler-mounted): the
/// toggles are disabled while mounted, with the reason under them.
struct CombatFormationPicker: View {
    let hero: Hero
    @Binding var formations: [FormationKind: FormationBonus]
    let mounted: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(FormationKind.allCases, id: \.self) { kind in
                formationRow(kind)
            }
            if mounted {
                Text(L("formation.onFootOnly"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .accessibilityIdentifier("combat.formation.mountedReason")
            }
        }
    }

    private func title(_ kind: FormationKind) -> String {
        hero.has(kind.ability) ? kind.name : String(format: L("formation.ally"), kind.name)
    }

    @ViewBuilder
    private func formationRow(_ kind: FormationKind) -> some View {
        DSAToggleRow(
            title: title(kind),
            isOn: Binding(
                get: { formations[kind] != nil },
                set: { formations[kind] = $0 ? .at : nil }
            ),
            accent: combatAccent,
            identifier: "combat.formation.\(kind.rawValue)"
        )
        .disabled(mounted)
        .opacity(mounted ? 0.5 : 1)
        .padding(.bottom, 4)

        if let chosen = formations[kind] {
            HStack(spacing: 8) {
                ForEach(FormationBonus.allCases, id: \.self) { bonus in
                    let isSelected = chosen == bonus
                    Button { formations[kind] = bonus } label: {
                        Text(String(format: L(bonus == .at ? "formation.bonusAT" : "formation.bonusAW"), kind.bonusValue))
                            .font(.dsaBody(.caption))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                    .accessibilityIdentifier("combat.formation.\(kind.rawValue).\(bonus.rawValue)")
                }
            }
            .dsaOptionGroup()
            .padding(.bottom, 8)
        }
    }
}
