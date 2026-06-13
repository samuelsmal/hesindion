import SwiftUI

/// A reusable Neo-Brutalist chip representing one active player state (Zustand or Status).
///
/// Styling mirrors the combat STATUS badges in `CombatRootView`: a flat, high-contrast
/// background, a 2px `Color.dsaBorder` rectangle overlay, monospaced bold text and an
/// SF Symbol icon. Zustände show their roman level (e.g. "Furcht II"); a numeric penalty
/// is appended ONLY for per-level Zustände, where it is unambiguously `−level` in every
/// domain and guaranteed to match the engine (e.g. "Furcht II −2").
///
/// Per-domain `.fixed` statuses (Liegend −4/−2) and Entrückung (whose sign flips for
/// gottgefällige Proben) cannot be reduced to one chip number — their penalties are shown
/// contextually on the actual roll, not on the chip.
///
/// Derived (Schmerz/Belastung) and implied states render visually distinct: a dashed,
/// secondary-colored border and a muted background. They are not removable, so callers
/// pass `isDerived: true` to disable the long-press affordance.
struct StateChip: View {
    let def: StateDefinition
    let level: Int
    /// True for auto-derived (Schmerz/Belastung) or implied states — rendered distinct, non-removable.
    var isDerived: Bool = false
    /// Background accent for "live" (manually-tracked) chips.
    var accent: Color = .groupCombat
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}

    private var isZustand: Bool { def.kind == .zustand }

    /// Numeric penalty shown on the chip — ONLY for per-level Zustände, where `−level` is
    /// unambiguous across every domain and matches the engine (e.g. "−2"); nil otherwise.
    /// Per-domain `.fixed`, `.entrueckung`, `.eingeengt` and `.reminderOnly` show no number.
    private var penaltyText: String? {
        guard isZustand, def.showsPerLevelPenalty else { return nil }
        return "−\(level)"
    }

    private var label: String {
        var text = L(def.nameKey)
        if isZustand {
            text += StateCatalog.romanSuffix(level)
        }
        if let penalty = penaltyText {
            text += " \(penalty)"
        }
        return text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: def.iconSystemName)
                .font(.system(.caption, weight: .bold))
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .black))
                .fixedSize()
        }
        .foregroundStyle(isDerived ? Color.primary : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isDerived ? Color(UIColor.secondarySystemBackground) : accent)
        .overlay(borderOverlay)
        .contentShape(Rectangle())
        // Long-press takes high priority so it wins the gesture arena cleanly; the tap
        // still fires reliably for a quick press. Derived chips attach no long-press.
        .highPriorityGesture(
            isDerived
                ? nil
                : LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLongPress() }
        )
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var borderOverlay: some View {
        if isDerived {
            Rectangle()
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(lineWidth: DSALayout.secondaryBorder, dash: [4, 3])
                )
        } else {
            Rectangle()
                .stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder)
        }
    }
}
