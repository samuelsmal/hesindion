import SwiftUI

// MARK: - CombatHitZoneRow

/// Zone selection for an incoming hit: tap a chip, or roll 1W20 against the hero's
/// Trefferzonentabelle. The raw roll stays on screen so the table stays auditable.
struct CombatHitZoneRow: View {
    @Binding var zoneHit: HitZoneHit?
    @Binding var lastRoll: Int?
    /// The hero is a humanoid of normal size — the only plan a player character uses.
    var plan: BodyPlan = .humanoid(.mittel)
    var isDisabled: Bool = false
    /// The reveal modal is presented by the screen, not here: an `.overlay` is
    /// sized by the view it decorates, so a scrim hung on this row would cover
    /// this row and nothing else.
    var onRollZone: () -> Void = {}

    /// Naming the zone and rolling for it are the two equally valid ways to
    /// answer the same question, so they share one group and one visual weight.
    private var isDetermined: Bool { zoneHit != nil }

    var body: some View {
        CombatZonePicker(
            selection: Binding(
                get: { zoneHit?.zone },
                set: { newZone in
                    lastRoll = nil
                    zoneHit = newZone.map { HitZoneHit(zone: $0, side: nil) }
                }),
            targetIsSurprised: .constant(false),
            zones: [.kopf, .torso, .arme, .beine],
            allowsNoZone: false,
            isSettled: isDisabled,
            accessory: AnyView(rollButton)
        )
        .disabled(isDisabled)
    }

    /// The roll is shown in the reveal modal, where the player is already
    /// looking, rather than resolved silently and reported as a line of text
    /// under the chips. That line said "7: Torso" — the zone half of which the
    /// highlighted chip was already saying, louder.
    private var rollButton: some View {
        Button(action: onRollZone) {
            HStack(spacing: 6) {
                Image(systemName: "dice.fill")
                Text(L("trefferzone.roll"))
            }
            .font(.dsaHeading(.caption))
            // Red is the call to act. Once the zone is settled the question is
            // answered, so the button stops shouting and becomes the re-roll it
            // actually is.
            .foregroundStyle(
                isDisabled || isDetermined ? Color.dsaDisabledLabel : Color.white
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isDisabled
                    ? Color.dsaDisabled
                    : (isDetermined ? Color(UIColor.secondarySystemBackground) : combatAccent)
            )
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .disabled(isDisabled)
        .accessibilityIdentifier("combat.zone.roll")
    }

    /// "14: Beine (rechts)" — the rolled value and the side it landed on. Shown
    /// inside the reveal modal, where the die is the point.
    static func rollSummary(_ roll: Int, plan: BodyPlan = .humanoid(.mittel)) -> String {
        let hit = HitZoneTable.lookup(roll, plan: plan)
        let name = L(hit.zone.nameKey)
        let sided = hit.side.map { "\(name) (\(L($0.nameKey)))" } ?? name
        return "\(roll): \(sided)"
    }
}

// MARK: - WoundEffectDamageControl

/// Settles a Wundeffekt's own damage: roll it, or enter the number you were
/// given. Both are first-class — at the table the value may just as easily be
/// spoken to you as rolled here, and the app has no way to tell which.
///
/// Used by both sides of a fight. When the hero takes the hit the figure is
/// folded into the LP write; when the hero *deals* one it is informational,
/// because the opponent is not modelled (ADR-0005).
struct WoundEffectDamageControl: View {
    let zone: HitZone
    @Binding var value: Int?
    var isDisabled: Bool = false

    private var rolled: Int { value ?? 0 }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                value = WoundEffectResolver.rollExtraDamage(for: zone)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dice.fill")
                    Text(L("trefferzone.rollExtraDamage"))
                }
                .font(.dsaHeading(.caption))
                // A settled control keeps its label at full strength (ADR-0010).
                // On `tertiarySystemFill` a white label was grey on grey, and
                // the whole Wundeffekt panel became unreadable the moment the
                // entry was confirmed — exactly when you most want to read it.
                .foregroundStyle(isDisabled ? Color.dsaDisabledLabel : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isDisabled ? Color.dsaDisabled : Color.groupCombat)
                .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
            .disabled(isDisabled)
            .accessibilityIdentifier("combat.takeDamage.rollExtraDamage")

            DSAStepper(
                tint: isDisabled ? Color.dsaDisabled : Color.groupCombat,
                decrementDisabled: isDisabled || rolled <= 0,
                incrementDisabled: isDisabled,
                isSettled: isDisabled,
                incrementIdentifier: "combat.takeDamage.increaseExtraDamage",
                onDecrement: { if rolled > 0 { value = rolled - 1 } },
                onIncrement: { value = rolled + 1 }
            ) {
                Text("+\(rolled)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("combat.takeDamage.extraDamage")
            }
        }
        .dsaOptionGroup(isSettled: isDisabled)
    }
}

// MARK: - CombatWoundEffectPanel

/// Wundschwelle panel for the hero taking damage: the multiple, the Wundeffekt, and
/// the Selbstbeherrschung probe that can avert it.
///
/// The panel decides nothing itself — `WoundEffectResolver` owns the arithmetic and
/// the parent owns the single LP write.
struct CombatWoundEffectPanel: View {
    let hero: Hero
    let hit: HitZoneHit
    let effectiveDamage: Int
    let wundschwelle: Int
    /// `nil` until the probe is rolled, so no effect is applied yet. Every hero
    /// can roll it: Selbstbeherrschung is a basic ability.
    @Binding var probeSucceeded: Bool?
    let effectApplies: Bool
    @Binding var extraDamage: Int?
    let confirmed: Bool
    /// Staged intent for the Arme drop-weapon action: the weapon is only actually
    /// cleared on confirm, alongside the LP write and the log entry (see
    /// `CombatTakeDamageView.applyDamage()`), so an abandoned flow cannot disarm
    /// the hero.
    @Binding var dropWeapon: Bool
    var onRollProbe: () -> Void

    private var effect: WoundEffect { WoundEffectCatalog.effect(for: hit.zone) }

    private var multiple: Int {
        WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    private var probeModifier: Int {
        WoundEffectResolver.probeModifier(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(L("trefferzone.woundEffect"))

            Text(String(format: L("trefferzone.threshold"), effectiveDamage, wundschwelle, multiple))
                .font(.dsaMono(.caption, emphasis: true))

            Text(L(effect.effectKey))
                .font(.dsaBody(.caption))
                .foregroundStyle(effectApplies ? Color.groupCombat : .primary)

            if let succeeded = probeSucceeded {
                HStack(spacing: 6) {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(succeeded ? Color.groupEquipment : Color.groupCombat)
                    Text(succeeded ? L("success") : L("failure"))
                        .font(.dsaHeading(.caption))
                }
            } else {
                Button(action: onRollProbe) {
                    Text(String(format: L("trefferzone.probe"), L(effect.resistanceKey), probeModifier))
                        .font(.dsaHeading(.caption))
                        .foregroundStyle(confirmed ? Color.dsaDisabledLabel : Color.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(confirmed ? Color.dsaDisabled : combatAccent)
                        .dsaBox(confirmed ? .flush : .raised)
                }
                .buttonStyle(.dsaMotion)
                .disabled(confirmed)
            }

            if effectApplies, case .reminder = effect.kind, hero.selectedWeaponName != nil {
                DSAToggleRow(
                    title: L("trefferzone.dropWeapon"),
                    isOn: $dropWeapon,
                    accent: Color.groupCombat,
                    identifier: "combat.takeDamage.dropWeapon"
                )
                .disabled(confirmed)
            }

            // The Wundeffekt's own damage. It used to be rolled silently inside
            // `confirmDamage`, so the number was never shown — unlike every other
            // roll on this screen.
            if effectApplies, case .extraDamage = effect.kind {
                WoundEffectDamageControl(
                    zone: hit.zone,
                    value: $extraDamage,
                    isDisabled: confirmed
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.groupCombat.opacity(0.1))
        .dsaBox(.flush, stroke: Color.groupCombat)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.woundEffectPanel")
    }
}
