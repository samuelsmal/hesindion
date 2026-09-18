import SwiftUI

/// What a Patzertabelle result means for *this* hero, and the one control it
/// still needs.
///
/// The fumble screen used to end at the table's prose: "Probe auf
/// Körperbeherrschung (Balance) –2, sonst Status Liegend." The player then had to
/// leave the fight, open the hero sheet, find Körperbeherrschung, remember the
/// −2, roll it, and — on a failure — go to the states section and add Liegend by
/// hand. Every one of those steps is something the app already does elsewhere.
///
/// Same grammar as `CombatWoundEffectPanel`, and the same division of labour: the
/// panel decides nothing and writes nothing. `FumbleEffectResolver` owns what an
/// effect means, `CombatFumbleChoiceView` owns the writes, the log and the modal.
struct CombatFumbleEffectPanel: View {
    let entry: FumbleTableEntry
    /// Everything the fumble has written to the hero so far, in the order it was
    /// written. A screen that writes something says what it wrote.
    let writes: [BreakdownRow]
    /// `nil` until the result's check is rolled. A result with no check leaves it
    /// `nil` forever, which is why `FumbleEffectResolver.holdsTheWayOut` asks the
    /// effect and not this.
    let probeSucceeded: Bool?
    /// The hero's own weapon damage, once rolled (results 11 and 12).
    let selfDamage: FumbleSelfDamage?
    var onRollProbe: () -> Void
    /// "Kein solches Ziel: Selbst verletzt" — the fallback the Fernkampf table
    /// prints under *Kamerad getroffen*. Whether there is a friend in the line
    /// of fire is the GM's to say, so this is a quiet second button rather than
    /// something the table roll does on its own.
    var onSelfDamageFallback: (() -> Void)? = nil

    private var effect: FumbleEffect { entry.effect }
    private var probe: FumbleProbe? { FumbleEffectResolver.probe(for: effect) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            combatSectionLabel(L("fumble.effect.label"))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.dsaHeading(.body))
                Text(entry.description)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !writes.isEmpty {
                VStack(spacing: 0) {
                    ForEach(writes) { row in
                        CombatBreakdownBox.row(value: row.value, source: row.source, tint: row.tint)
                    }
                }
                .dsaBox(.raised, fill: Color(UIColor.systemBackground))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("combat.fumble.writes")
            }

            // The one control the result still needs, if any. Everything else on
            // this panel is a report.
            if let probe {
                probeSection(probe)
            }

            if let selfDamage {
                selfDamageSection(selfDamage)
            }

            // The Fernkampf table's "Kein solches Ziel" branch. Secondary, and
            // only until it has been taken — once the dice are on screen the
            // panel is reporting, not asking.
            if effect == .friendHit, selfDamage == nil, let onSelfDamageFallback {
                Button(action: onSelfDamageFallback) {
                    Text(L("fumble.friendHit.selfDamage"))
                        .font(.dsaHeading(.caption))
                        .foregroundStyle(combatAccent)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush, stroke: combatAccent)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityIdentifier("combat.fumble.selfDamageFallback")
            }

            // The seam. `friendHit` and `wildShot` are events on the *other*
            // side of the table — a bystander, a shop sign — and opponents and
            // scenery are not modelled (ADR-0005), so the app says so rather
            // than pretending the text is the whole answer.
            if !effect.isAutomated {
                Text(L("fumble.gmOnly"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.groupCombat.opacity(0.1))
        .dsaBox(.flush, stroke: Color.groupCombat)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.fumbleEffectPanel")
    }

    // MARK: - The check

    @ViewBuilder
    private func probeSection(_ probe: FumbleProbe) -> some View {
        if let succeeded = probeSucceeded {
            HStack(spacing: 6) {
                Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(succeeded ? Color.groupEquipment : Color.groupCombat)
                Text(succeeded ? L("success") : L("failure"))
                    .font(.dsaHeading(.caption))
            }
            .accessibilityIdentifier("combat.fumble.probeResult")

            if let note = probeNote(succeeded: succeeded) {
                Text(note)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Button(action: onRollProbe) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: L("fumble.rollProbe"), probe.talentName, probe.modifier))
                        .font(.dsaHeading(.caption))
                    if let costKey = probe.costKey {
                        Text(L(costKey))
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("combat.fumble.rollProbe")
        }
    }

    /// What passing or failing meant, where the bare "Erfolg"/"Misserfolg" does
    /// not already say it. A failed Sturz has its consequence in `writes`
    /// ("Liegend"), so it needs no second sentence.
    private func probeNote(succeeded: Bool) -> String? {
        switch effect {
        case .fall:      succeeded ? L("fumble.fall.avoided") : nil
        case .itemStuck: succeeded ? nil : L("fumble.stuck.failed")
        default:         nil
        }
    }

    // MARK: - Selbst verletzt

    /// The dice and the sum, before the button that carries the figure to the
    /// take-damage screen — where the armour, the Wundschwelle and the single LP
    /// write all live. A total shown in a dark bar would read as the damage
    /// *dealt*, so it is stated as the TP it is, in the same breakdown grammar.
    private func selfDamageSection(_ damage: FumbleSelfDamage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(damage.rolls.enumerated()), id: \.offset) { _, roll in
                    Text("\(roll)")
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                }
                if damage.bonus != 0 {
                    Text(damage.bonus > 0 ? "+\(damage.bonus)" : "\(damage.bonus)")
                        .font(.dsaBody(.body))
                }
                if damage.doubled {
                    Text("\u{00D7}2")
                        .font(.dsaBody(.body))
                }
                Text("=")
                    .font(.dsaBody(.body))
                Text("\(damage.total) TP")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.dsaDark)
                    .foregroundStyle(.white)
                    .dsaBox(.flush)
            }

            HStack(spacing: 6) {
                Text(L("fumble.selfDamage.label"))
                Text(damage.formula)
                    .fontDesign(.monospaced)
                if damage.doubled {
                    Text(L("fumble.selfDamage.doubled"))
                }
            }
            .font(.dsaBody(.caption2))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.fumble.selfDamage")
    }
}
