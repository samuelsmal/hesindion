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

    /// Which route the player took to the number. `nil` until they say.
    ///
    /// The two used to sit side by side — a roll button above a stepper — which
    /// left "what wins if I roll and then type?" unanswered, and the screen
    /// showing two controls for one number. Deciding first means only one of them
    /// is ever on screen, and the answer is whatever the chosen route produced.
    private enum Route { case rolled, byHand }
    @State private var route: Route? = nil

    private var rolled: Int { value ?? 0 }

    private var formula: String { WoundEffectResolver.extraDamageFormula(for: zone) }

    var body: some View {
        VStack(spacing: 8) {
            switch route {
            case .none:
                routeChoice
            case .rolled:
                resultRow(canReroll: true)
            case .byHand:
                stepper
            }
        }
        .dsaOptionGroup(isSettled: isDisabled)
        .onAppear {
            // A value restored from an earlier visit is already settled; the
            // stepper is the honest home for it, since we cannot know it was rolled.
            if route == nil, value != nil { route = .byHand }
        }
    }

    // MARK: - The fork

    private var routeChoice: some View {
        VStack(spacing: 8) {
            Text(String(format: L("trefferzone.extraDamageAsk"), formula))
                .font(.dsaBody(.caption))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                routeButton(
                    icon: "dice.fill",
                    title: L("roll"),
                    identifier: "combat.takeDamage.rollExtraDamage"
                ) {
                    value = WoundEffectResolver.rollExtraDamage(for: zone)
                    route = .rolled
                }

                routeButton(
                    icon: "square.and.pencil",
                    title: L("enterValue"),
                    identifier: "combat.takeDamage.enterExtraDamage"
                ) {
                    value = value ?? 0
                    route = .byHand
                }
            }
        }
    }

    private func routeButton(
        icon: String,
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.dsaHeading(.caption))
            .foregroundStyle(isDisabled ? Color.dsaDisabledLabel : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isDisabled ? Color.dsaDisabled : Color.groupCombat)
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - What the chosen route produced

    private func resultRow(canReroll: Bool) -> some View {
        HStack(spacing: 8) {
            Text("+\(rolled)")
                .font(.dsaHeading(.title3))
                .fontDesign(.monospaced)
                .accessibilityIdentifier("combat.takeDamage.extraDamage")
            Text(formula)
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)

            Spacer()

            if canReroll, !isDisabled {
                Button {
                    value = WoundEffectResolver.rollExtraDamage(for: zone)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L("rollAgain"))
                    }
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(Color.groupCombat)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityIdentifier("combat.takeDamage.rerollExtraDamage")
            }

            if !isDisabled {
                changeRouteButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var stepper: some View {
        VStack(spacing: 6) {
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

            if !isDisabled {
                HStack {
                    Text(formula)
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(.secondary)
                    Spacer()
                    changeRouteButton
                }
            }
        }
    }

    /// Changing route clears the number: a value rolled here and then edited by
    /// hand would be neither, and the screen could not say which it was.
    private var changeRouteButton: some View {
        Button {
            value = nil
            route = nil
        } label: {
            Text(L("change"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(Color.groupCombat)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.takeDamage.changeExtraDamageRoute")
    }
}

// MARK: - CombatWundschwelleRow

/// Where the hit stands against the hero's Wundschwelle — shown whether or not the
/// Trefferzonen focus rule is on.
///
/// The comparison used to live inside `CombatWoundEffectPanel`, which only appears
/// with that focus rule *and* a rolled zone, so with the rule off the take-damage
/// screen never mentioned the Wundschwelle at all: the player had to remember the
/// number and do the comparison in their head (issue #23). The threshold is a
/// property of the hero, not of the focus rule, so it is stated either way.
///
/// What *follows* from reaching it stays where it belongs — the zone Wundeffekt is
/// still the focus rule's business, and this row says so rather than implying an
/// effect it cannot name.
struct CombatWundschwelleRow: View {
    let effectiveDamage: Int
    let wundschwelle: Int
    /// Whether the Trefferzonen focus rule is on, and whether a zone has been
    /// rolled — only to explain what is still missing before a Wundeffekt.
    let zonesActive: Bool
    let hasZone: Bool

    private var multiple: Int {
        WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    private var reached: Bool { multiple >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            combatSectionLabel(L("wundschwelle.label"))

            if reached {
                Text(L("wundschwelle.reached"))
                    .font(.dsaHeading(.caption))
                    .foregroundStyle(Color.groupCombat)

                Text(String(format: L("trefferzone.threshold"),
                            effectiveDamage, wundschwelle, multiple))
                    .font(.dsaMono(.caption, emphasis: true))

                if !zonesActive {
                    Text(L("wundschwelle.zonesOff"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                } else if !hasZone {
                    Text(L("wundschwelle.rollZone"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(format: L("wundschwelle.below"), effectiveDamage, wundschwelle))
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(reached ? Color.groupCombat.opacity(0.1) : Color.clear)
        .dsaBox(.flush, stroke: reached ? Color.groupCombat : Color.dsaBorder)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.takeDamage.wundschwelle")
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

    /// The Wundschwelle-based penalty plus whatever the engine adds to the same
    /// check (Verweichlicht/DISADV_57, a Zustand) — the modal this panel opens
    /// rolls at this same total, via the shared `Situation.woundEffectProbe`.
    /// The talent id comes from the hero's own Selbstbeherrschung row, the same
    /// source `CombatTakeDamageView` uses to build the modal it rolls, so the
    /// two cannot disagree (falls back to `Talent.selbstbeherrschungRuleId` when
    /// the hero has no such row, same as `Hero.selbstbeherrschung` — but read
    /// straight off `hero.talents` here rather than through that computed
    /// property, which builds a fresh, never-inserted `Talent` on every access
    /// for a hero without the row, and this is a render-time computed property)
    private var probeModifier: Int {
        let selbstbeherrschungId = hero.talents.first { $0.name == Talent.selbstbeherrschungName }?.ruleId
            ?? Talent.selbstbeherrschungRuleId
        let engineModifier = ModifierEngine.shared.evaluate(
            context: Situation.woundEffectProbe(hero: hero, talentId: selbstbeherrschungId)
        ).reduce(0) { $0 + $1.value }
        return WoundEffectResolver.probeModifier(damage: effectiveDamage, wundschwelle: wundschwelle) + engineModifier
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
