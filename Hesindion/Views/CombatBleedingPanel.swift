import SwiftUI

// MARK: - BleedingProbe

/// The two probes the Blutend panel opens (https://dsa.ulisses-regelwiki.de/Status_Blutend.html).
enum BleedingProbe {
    /// Selbstbeherrschung sets the duration: 7 − QS rounds.
    case selbstbeherrschung
    /// Heilkunde Wunden +2 (1 Aktion) shortens the clock by QS/2.
    case heilkunde

    /// What a final result does to the hero.
    func apply(_ result: SkillCheckResult, to hero: Hero) {
        switch self {
        case .selbstbeherrschung:
            hero.startBleeding(rounds: BleedingRules.duration(
                qualityLevel: result.qualityLevel,
                succeeded: result.succeeded,
                critical: result.isCriticalSuccess,
                fumble: result.isCriticalFailure
            ))
        case .heilkunde:
            guard result.succeeded else { return }
            hero.treatBleeding(qs: result.qualityLevel)
        }
    }
}

/// One open probe modal. `SkillCheckModal` fires `onResult` again after a
/// Schip reroll, so the result is only *recorded* while the modal is up and
/// applied once, with the final result, when it closes — the same "log on
/// close" rule `CombatFluchtView` follows. A value type so the guard is
/// unit-testable without a SwiftUI harness.
struct BleedingProbeSession {
    let probe: BleedingProbe
    private(set) var latest: SkillCheckResult? = nil
    private(set) var applied = false

    init(probe: BleedingProbe) { self.probe = probe }

    mutating func record(_ result: SkillCheckResult) {
        latest = result
    }

    mutating func finish(on hero: Hero) {
        guard !applied, let latest else { return }
        probe.apply(latest, to: hero)
        applied = true
    }
}

// MARK: - CombatBleedingPanel

/// Blutend on the combat root: the clock (or the probe that sets it) and the
/// Heilkunde Wunden treatment that shortens it. Replaces the plain per-round
/// reminder line Blutend used to get.
struct CombatBleedingPanel: View {
    let hero: Hero
    let accent: Color
    var onRollSelbstbeherrschung: () -> Void
    var onRollHeilkunde: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: StateCatalog.definition(for: BleedingRules.stateId)?.iconSystemName ?? "drop.fill")
                    .font(.dsaBody(.caption2))
                Text("\(L("state.blutend.name")): \(statusLine)")
                    .font(.dsaMono(.caption2, emphasis: true))
            }
            .foregroundStyle(accent)

            if hero.bleedingRoundsLeft == nil {
                outlineButton(icon: "dice", title: L("bleeding.rollDuration"),
                              action: onRollSelbstbeherrschung)
                    .accessibilityIdentifier("combat.bleeding.selbstbeherrschung")
            } else {
                outlineButton(icon: "cross.case", title: L("bleeding.heilkunde"),
                              action: onRollHeilkunde)
                    .accessibilityIdentifier("combat.bleeding.heilkunde")
                Text(L("bleeding.heilkunde.effect"))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.bleeding")
    }

    private var statusLine: String {
        if let left = hero.bleedingRoundsLeft {
            return String(format: L("bleeding.roundsLeft"), left)
        }
        return L("bleeding.unknownDuration")
    }

    /// Outline button in the style of the root's Fernkampf entry, one size down.
    private func outlineButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.dsaHeading(.body))
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.flush, stroke: accent)
        }
        .buttonStyle(.dsaMotion)
    }
}
