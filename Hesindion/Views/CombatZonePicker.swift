import SwiftUI

/// Single-select Trefferzone chips. Shared by the melee announcement, the ranged
/// setup and the take-damage screen.
struct CombatZonePicker: View {
    @Binding var selection: HitZone?
    @Binding var targetIsSurprised: Bool

    /// Zones offered. Defaults to the humanoid set; pass the full set for other plans.
    var zones: [HitZone] = [.kopf, .torso, .arme, .beine]
    /// Show the live Zonenaufschlag on each chip (offence only).
    var showsPenalty: Bool = false
    /// Show the Überrascht toggle (offence only).
    var showsSurprisedToggle: Bool = false
    /// Hero owns SA_160 / SA_161 for the current domain.
    var hasSonderfertigkeit: Bool = false
    /// Which Sonderfertigkeit halves the Zonenaufschlag here — SA_160 *Gezielter Angriff*
    /// in melee, SA_161 *Gezielter Schuss* at range. The picker is shared by both screens,
    /// so the caller names its own SF; nil (the defence screen) shows no hint at all.
    var sfHalvesKey: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(L("trefferzone.section"))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(zones) { zone in
                    chip(isSelected: selection == zone) {
                        selection = (selection == zone) ? nil : zone
                    } label: {
                        VStack(spacing: 2) {
                            Text(L(zone.nameKey))
                                .font(.system(.caption, weight: .black))
                            if showsPenalty {
                                Text("\(HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: hasSonderfertigkeit, targetIsSurprised: targetIsSurprised))")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                            }
                        }
                    }
                }

                chip(isSelected: selection == nil) {
                    selection = nil
                } label: {
                    Text(L("trefferzone.none"))
                        .font(.system(.caption, weight: .black))
                }
            }

            if showsSurprisedToggle {
                Button { targetIsSurprised.toggle() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: targetIsSurprised ? "checkmark.square.fill" : "square")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(targetIsSurprised ? combatAccent : .secondary)
                        Text(L("trefferzone.targetSurprised"))
                            .font(.system(.body, weight: targetIsSurprised ? .bold : .regular))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(targetIsSurprised ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(targetIsSurprised ? combatAccent : Color.dsaBorder, lineWidth: targetIsSurprised ? 3 : 2))
                }
                .buttonStyle(.plain)
            }

            if showsPenalty, hasSonderfertigkeit, let sfHalvesKey {
                Text(L(sfHalvesKey))
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One chip, styled like the other single-select segmented pickers in combat
    /// (e.g. opponent weapon reach): accent fill + heavier border when selected.
    private func chip(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }
}
