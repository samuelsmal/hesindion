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
    /// Offer the "keine Zone" chip. True on offence, where not aiming is a real
    /// choice; false when the hero takes a hit, where the zone is either chosen
    /// outright or rolled.
    var allowsNoZone: Bool = true
    /// Hero owns SA_160 / SA_161 for the current domain.
    var hasSonderfertigkeit: Bool = false
    /// Which Sonderfertigkeit halves the Zonenaufschlag here — SA_160 *Gezielter Angriff*
    /// in melee, SA_161 *Gezielter Schuss* at range. The picker is shared by both screens,
    /// so the caller names its own SF; nil (the defence screen) shows no hint at all.
    var sfHalvesKey: String? = nil
    /// Placed inside the chip group, not below it. On the take-damage screen the
    /// 1W20 roll is not a lesser action than naming a zone — it is the other way
    /// of answering the same question, so it carries the same weight.
    /// The choice is made and locked, so the group gives up its shadow with the
    /// rest of the screen (ADR-0010).
    var isSettled: Bool = false
    var accessory: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(L("trefferzone.section"))

            // Centred when the chips fit on one line (the iPad case, and any phone
            // with the four humanoid zones); falls back to a wrapping grid when they
            // do not — a non-humanoid plan can offer up to ten zones, and five chips
            // at their minimum width already exceed an iPhone in portrait.
            VStack(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { chips }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) { chips }
                }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

                if let accessory {
                    accessory
                }
            }
            .dsaOptionGroup(isSettled: isSettled)

            if showsSurprisedToggle {
                // Filled when on, like the zone chip directly above it. It was
                // the tickbox one row under a red-filled "Torso" — the same
                // screen saying "selected" two different ways.
                DSAToggleRow(
                    title: L("trefferzone.targetSurprised"),
                    isOn: $targetIsSurprised,
                    accent: combatAccent,
                    identifier: "combat.zone.surprised"
                )
            }

            if showsPenalty, hasSonderfertigkeit, let sfHalvesKey {
                Text(L(sfHalvesKey))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One chip, styled like the other single-select segmented pickers in combat
    /// (e.g. opponent weapon reach): accent fill + heavier border when selected.
    /// The zone chips plus the "Keine Zone" reset, shared by both layout branches.
    @ViewBuilder
    private var chips: some View {
        ForEach(zones) { zone in
            chip(isSelected: selection == zone, identifier: "combat.zone.\(zone.rawValue)") {
                selection = (selection == zone) ? nil : zone
            } label: {
                VStack(spacing: 2) {
                    Text(L(zone.nameKey))
                        .font(.dsaHeading(.caption))
                    if showsPenalty {
                        Text("\(HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: hasSonderfertigkeit, targetIsSurprised: targetIsSurprised))")
                            .font(.dsaMono(.caption2, emphasis: true))
                    }
                }
            }
        }

        // Only where declining to aim is a real choice — the attack announcement.
        // When the hero *takes* a hit under the Fokus-Regel the zone is either
        // chosen outright or rolled, so "keine Zone" is not an available answer.
        if allowsNoZone {
            chip(isSelected: selection == nil, identifier: "combat.zone.none") {
                selection = nil
            } label: {
                Text(L("trefferzone.none"))
                    .font(.dsaHeading(.caption))
            }
        }
    }

    private func chip(
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(minWidth: 78)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                // Fill the grid row so a one-line chip ("Keine Zone") matches the
                // two-line zone chips, which carry a penalty beneath the name.
                .frame(maxHeight: .infinity)
                .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier)
    }
}
