import SwiftUI

/// What a confirmed hit left behind: the life points that remain, and every
/// state that is now in force and was not — or was, at a lower Stufe — a moment
/// ago.
///
/// The take-damage screen used to stop at the arithmetic. It said "16 LP
/// verloren" and returned to the combat root, and the two things a player
/// actually has to know next went unsaid: what the hero is down to, and what
/// now applies. Some of it is written by the Wundeffekt (a head hit raises
/// Betäubung), and some of it nothing writes at all — Schmerz is derived from
/// the LP total, so crossing a quarter changes the hero without any step of the
/// flow mentioning it.
///
/// Comparison, not recomputation: the levels are read back off the hero and set
/// against the snapshot taken before the write, so a state that arrives by a
/// route this view knows nothing about still shows up.
struct CombatDamageOutcomeBox: View {
    let hero: Hero
    /// State id → Stufe, as it stood before the damage was written.
    let statesBefore: [String: Int]

    /// Everything that went up. A state that fell — nothing here lowers one, but
    /// an undo followed by a smaller entry can — is left out rather than reported
    /// as a consequence of taking damage.
    private var raised: [(def: StateDefinition, from: Int, to: Int)] {
        hero.activeStates.compactMap { entry in
            let before = statesBefore[entry.def.id] ?? 0
            guard entry.level > before else { return nil }
            return (entry.def, before, entry.level)
        }
    }

    private var lifePoints: (current: Int, max: Int)? {
        guard let dv = hero.derivedValues else { return nil }
        return (dv.lebensenergie.current, dv.lebensenergie.max)
    }

    var body: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("takeDamage.outcome.label"))

            VStack(spacing: 0) {
                ForEach(raised, id: \.def.id) { change in
                    CombatBreakdownBox.row(
                        value: change.def.kind == .status
                            ? L("takeDamage.outcome.now")
                            : "\(L("level")) \(change.from) → \(change.to)",
                        source: L(change.def.nameKey),
                        tint: Color.groupCombat
                    )
                }

                if hero.isHandlungsunfaehig {
                    CombatBreakdownBox.row(
                        value: "!",
                        source: L("states.handlungsunfaehig.banner"),
                        tint: Color.groupCombat
                    )
                }

                if let lp = lifePoints {
                    HStack {
                        Text("\(lp.current) / \(lp.max)")
                            .font(.dsaMono(.body, emphasis: true))
                        Spacer()
                        Text(L("lifePoints.label"))
                            .font(.dsaBody(.caption2))
                            .opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.dsaDark)
                }
            }
            .dsaBox(.raised, fill: Color(UIColor.systemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.takeDamage.outcome")
    }
}
