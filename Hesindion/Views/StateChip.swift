import SwiftUI

/// A reusable Neo-Brutalist chip representing one active player state (Zustand or Status).
///
/// Styling mirrors the combat STATUS badges in `CombatRootView`: a flat, high-contrast
/// background, a 2px `Color.dsaBorder` rectangle overlay, monospaced bold text and an
/// SF Symbol icon. Penalty-mechanic Zustände (and Entrückung) show their roman level and
/// the numeric penalty (e.g. "Furcht II −2").
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

    /// Numeric penalty shown on the chip for penalty/entrückung Zustände (e.g. "−2"); nil otherwise.
    private var penaltyText: String? {
        guard isZustand else { return nil }
        switch def.mechanic {
        case .penalty(_, let value):
            switch value {
            case .perLevel:
                return "−\(level)"
            case .fixed:
                return nil
            }
        case .entrueckung:
            // Default (non-gottgefällig) reading: −level.
            return "−\(level)"
        default:
            return nil
        }
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
        .onTapGesture { onTap() }
        .onLongPressGesture {
            guard !isDerived else { return }
            onLongPress()
        }
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
