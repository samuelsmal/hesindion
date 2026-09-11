import SwiftUI
import SwiftData

// MARK: - CombatTakeDamageView

struct CombatTakeDamageView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var tpInput: Int = 0
    @State private var confirmed: Bool = false

    // Trefferzonen (Fokus-Regel)
    @State private var zoneHit: HitZoneHit? = nil
    @State private var lastRoll: Int? = nil
    /// `nil` until the Selbstbeherrschung probe is rolled — which means the GM has
    /// not adjudicated the wound effect, so nothing is applied.
    @State private var probeSucceeded: Bool? = nil
    @State private var showingProbeModal = false
    /// Resolved once when the probe is opened rather than per body pass, because the
    /// FW-0 fallback (see `Hero.selbstbeherrschung`) builds a fresh stand-in `Talent`.
    @State private var probeTalent: Talent? = nil
    /// Rolled once, on confirm, and folded into the single LP write.
    @State private var extraDamage: Int? = nil
    /// Staged intent, not an immediate action: only cleared on confirm, alongside
    /// the LP write and the log entry, so an abandoned flow cannot disarm the hero.
    @State private var dropWeapon: Bool = false

    private var rs: Int { hero.totalRS }
    private var effectiveDamage: Int { WoundEffectResolver.effectiveDamage(tp: tpInput, rs: rs) }

    // MARK: - Trefferzonen

    private var zonesActive: Bool { hero.isFokusRuleActive(.trefferzonen) }

    private var wundschwelle: Int { hero.derivedValues?.wundschwelle.max ?? 0 }

    private var multiple: Int {
        WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    /// The wound effect is threatened once the damage reaches the Wundschwelle.
    private var woundEffectThreatens: Bool {
        WoundEffectResolver.effectThreatens(
            zonesActive: zonesActive, hasZone: zoneHit != nil,
            damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    /// It applies only on a *failed* Selbstbeherrschung probe. Every hero has that
    /// basic ability, so an unrolled probe simply means the GM has not adjudicated —
    /// never a silent auto-apply.
    private var woundEffectApplies: Bool {
        WoundEffectResolver.effectApplies(
            threatens: woundEffectThreatens, probeSucceeded: probeSucceeded)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)

                Spacer()

                Text(L("takeDamage"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .dsaBox(.flush)

            VStack(spacing: 16) {
                // TP input stepper
                combatSectionLabel(L("tp"))

                HStack(spacing: 0) {
                    Button {
                        if tpInput > 0 { tpInput -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.dsaDisabled : combatAccent)
                    }
                    .buttonStyle(.dsaMotion)
                    .disabled(confirmed || tpInput <= 0)
                    .dsaBox(.flush)

                    Text("\(tpInput)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        // Equal thirds: the two steppers already fill, so the value
                        // must too, or it collapses to its intrinsic width.
                        .frame(minWidth: 80, maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)

                    Button {
                        tpInput += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.dsaDisabled : combatAccent)
                    }
                    .buttonStyle(.dsaMotion)
                    .disabled(confirmed)
                    .dsaBox(.flush)
                    .accessibilityIdentifier("combat.takeDamage.increaseTP")
                }
                .fixedSize(horizontal: false, vertical: true)

                // Calculation display
                VStack(spacing: 4) {
                    Text("\(tpInput) \(L("tp")) \u{2212} \(rs) \(L("rs")) = \(effectiveDamage)")
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                    if effectiveDamage == 0 {
                        Text(L("absorbed"))
                            .font(.dsaBody(.caption))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(effectiveDamage) \(L("lpLost"))")
                            .font(.dsaBody(.caption))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .dsaBox(.flush)

                if zonesActive {
                    CombatHitZoneRow(
                        zoneHit: $zoneHit,
                        lastRoll: $lastRoll,
                        isDisabled: confirmed
                    )

                    if let hit = zoneHit, multiple >= 1 {
                        CombatWoundEffectPanel(
                            hero: hero,
                            hit: hit,
                            effectiveDamage: effectiveDamage,
                            wundschwelle: wundschwelle,
                            probeSucceeded: $probeSucceeded,
                            effectApplies: woundEffectApplies,
                            extraDamage: extraDamage,
                            confirmed: confirmed,
                            dropWeapon: $dropWeapon,
                            onRollProbe: {
                                probeTalent = hero.selbstbeherrschung
                                showingProbeModal = true
                            }
                        )
                    }
                }

                if !confirmed {
                    // Confirm button
                    Button {
                        applyDamage()
                    } label: {
                        Text(L("confirm"))
                            .font(.dsaHeading(.title3))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(combatAccent)
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                } else {
                    // Neue Aktion button
                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.dsaHeading(.body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
            .adaptiveContentWidth()

            Spacer()
        }
        // A different zone resists with a different Anwendungsgebiet, and a different
        // damage total changes the modifier — either way the old probe is void.
        .onChange(of: zoneHit) { if !confirmed { probeSucceeded = nil; dropWeapon = false } }
        .onChange(of: effectiveDamage) { if !confirmed { probeSucceeded = nil; dropWeapon = false } }
        .overlay {
            if showingProbeModal, let talent = probeTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: WoundEffectResolver.probeModifier(
                        damage: effectiveDamage, wundschwelle: wundschwelle)
                )
            }
        }
    }

    // MARK: - Confirm

    /// The single point where LP changes: the hit and any Torso extra damage are
    /// summed first and written once. The Arme drop-weapon action is staged (see
    /// `CombatWoundEffectPanel`) rather than immediate, so it too only lands here —
    /// in the same transaction as the LP write and the log entry — and never on a
    /// flow the user abandons before confirming.
    private func applyDamage() {
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: zoneHit, effectApplies: woundEffectApplies,
            effectiveDamage: effectiveDamage, hero: hero)
        extraDamage = extra

        var droppedWeapon: String? = nil
        if dropWeapon, woundEffectApplies, let weaponName = hero.selectedWeaponName {
            droppedWeapon = weaponName
            hero.selectedWeaponName = nil
        }

        if let dv = hero.derivedValues {
            dv.lebensenergie.current = max(0, dv.lebensenergie.current - total)
        }

        modelContext.insert(LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .damageTaken,
                weaponName: nil,
                rollValue: nil,
                damageDealt: nil,
                damageTaken: total,
                lpChange: -total
            ),
            hero: hero
        ))

        if let hit = zoneHit, woundEffectThreatens {
            modelContext.insert(LogEntry.create(
                kind: "woundEffect",
                payload: WoundEffectPayload(
                    zone: hit.zone.rawValue,
                    side: hit.side?.rawValue,
                    roll: lastRoll,
                    damage: effectiveDamage,
                    wundschwelle: wundschwelle,
                    multiple: multiple,
                    probeSucceeded: probeSucceeded,
                    applied: woundEffectApplies,
                    extraDamage: extra,
                    weaponDropped: droppedWeapon
                ),
                hero: hero
            ))
        }

        confirmed = true
    }
}

// MARK: - WoundEffectReminderCard

/// Read-only GM prompt shown after a landed targeted attack.
///
/// Nothing is applied: the opponent has no LP, no KO and no states, so the app can
/// only state the rule and let the GM adjudicate.
struct WoundEffectReminderCard: View {
    let zone: HitZone

    var body: some View {
        let effect = WoundEffectCatalog.effect(for: zone)
        VStack(alignment: .leading, spacing: 6) {
            combatSectionLabel(String(format: L("trefferzone.reminderTitle"), L(zone.nameKey)))
            Text(L(effect.effectKey))
                .font(.dsaBody(.caption))
            Text(L(effect.resistanceKey))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.groupCombat.opacity(0.1))
        .dsaBox(.flush)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.woundEffectReminder")
    }
}

// MARK: - CombatMountDamageView

struct CombatMountDamageView: View {
    let hero: Hero
    let mount: Pet
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var spAmount: Int = 1
    @State private var damageApplied = false
    @State private var showingProbeModal = false
    @State private var probeSucceeded: Bool? = nil

    private var penalty: Int { spAmount / 5 }

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                Spacer()
                Text(L("mountTakesDamage"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .dsaBox(.flush)

            Spacer()

            if !damageApplied {
                spInputPhase
            } else {
                reitenCheckPhase
            }

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty
                )
            }
        }
    }

    // MARK: - SP Input Phase

    private var spInputPhase: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(mount.name)
                .font(.dsaHeading(.title3))

            // SP stepper
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Button {
                        if spAmount > 1 { spAmount -= 1 }
                    } label: {
                        Text("−")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)

                    Text("\(spAmount)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)

                    Button {
                        spAmount += 1
                    } label: {
                        Text("+")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                }

                Text(L("mountDamage.sp"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
            }

            // Penalty display
            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.dsaBody(.body))
                    .foregroundStyle(combatAccent)
            } else {
                Text(L("mountDamage.noPenalty"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
            }

            // Apply button
            Button {
                // Deduct LP from mount
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)
                let entry = LogEntry.create(
                    kind: "combatAction",
                    payload: CombatActionPayload(
                        combatId: combatId,
                        round: roundNumber,
                        action: .damageTaken,
                        weaponName: nil,
                        rollValue: nil,
                        damageDealt: nil,
                        damageTaken: spAmount,
                        lpChange: 0
                    ),
                    hero: hero
                )
                modelContext.insert(entry)
                let mountEntry = LogEntry.create(
                    kind: "mountLPChange",
                    payload: MountLPChangePayload(petName: mount.name, lpChange: -spAmount),
                    hero: hero
                )
                modelContext.insert(mountEntry)
                withAnimation(DSAAnimation.standard) {
                    damageApplied = true
                }
            } label: {
                Text(L("mountDamage.apply"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(combatAccent)
                    .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Reiten Check Phase

    private var reitenCheckPhase: some View {
        VStack(spacing: 16) {
            if let talent = reitenTalent {
                if let succeeded = probeSucceeded {
                    // Result
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(succeeded ? Color.groupEquipment : Color.groupCombat)

                    Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                        .font(.dsaHeading(.title3))
                        .multilineTextAlignment(.center)

                    if !succeeded {
                        Text(L("mountDamage.sturz"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(Color.groupCombat)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.groupCombat.opacity(0.1))
                            .dsaBox(.flush, stroke: Color.groupCombat)
                    }

                    Button {
                        step = .root
                    } label: {
                        Text(L("continue"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(succeeded ? combatAccent : Color.dsaDark)
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                } else {
                    // Prompt to roll
                    Image(systemName: "dice.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(combatAccent)

                    Text(L("reitenCheck"))
                        .font(.dsaHeading(.title3))
                        .multilineTextAlignment(.center)

                    if penalty > 0 {
                        Text(String(format: L("mountDamage.penalty"), penalty))
                            .font(.dsaBody(.body))
                            .foregroundStyle(combatAccent)
                    }

                    Button {
                        showingProbeModal = true
                    } label: {
                        Text(L("rollReitenCheck"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                }
            } else {
                // No Reiten talent — manual confirmation
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(combatAccent)

                Text(L("reitenCheckPrompt"))
                    .font(.dsaHeading(.title3))
                    .multilineTextAlignment(.center)

                if penalty > 0 {
                    Text(String(format: L("mountDamage.penalty"), penalty))
                        .font(.dsaBody(.body))
                        .foregroundStyle(combatAccent)
                }

                HStack(spacing: 12) {
                    Button {
                        probeSucceeded = false
                    } label: {
                        Text(L("no"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)

                    Button {
                        probeSucceeded = true
                    } label: {
                        Text(L("yes"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - CombatMountPreCheckView

struct CombatMountPreCheckView: View {
    let hero: Hero
    let onSuccess: CombatStep
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var galoppConfirmed = false
    @State private var probeSucceeded: Bool? = nil
    @State private var showingProbeModal = false

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { step = .attackChoice } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                Spacer()
                Text(L("reitenCheck"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .dsaBox(.flush)

            Spacer()

            VStack(spacing: 0) {
                galoppNode
                connectorArrow
                reitenNode
            }
            .adaptiveContentWidth()

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded }
                )
            }
        }
    }

    // MARK: - Step 1: Galopp

    private var galoppNode: some View {
        VStack(spacing: 12) {
            if galoppConfirmed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.groupEquipment)
                    Text(L("galoppConfirm"))
                        .font(.dsaBody(.body))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            } else {
                Image(systemName: "figure.equestrian.sports")
                    .font(.system(size: 36))
                    .foregroundStyle(combatAccent)

                Text(L("galoppConfirm"))
                    .font(.dsaBody(.body))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        step = .attackChoice
                    } label: {
                        Text(L("no"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)

                    Button {
                        withAnimation(DSAAnimation.standard) {
                            galoppConfirmed = true
                        }
                    } label: {
                        Text(L("yes"))
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(combatAccent)
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
        }
        .padding(galoppConfirmed ? 0 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
    }

    // MARK: - Connector

    private var connectorArrow: some View {
        Image(systemName: "chevron.down.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(galoppConfirmed ? combatAccent : Color.dsaBorder)
            .padding(.vertical, 8)
    }

    // MARK: - Step 2: Reiten

    private var reitenNode: some View {
        VStack(spacing: 12) {
            if let talent = reitenTalent {
                reitenWithTalent(talent)
            } else {
                reitenManual
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
        .opacity(galoppConfirmed ? 1 : 0.4)
        .allowsHitTesting(galoppConfirmed)
    }

    @ViewBuilder
    private func reitenWithTalent(_ talent: Talent) -> some View {
        if let succeeded = probeSucceeded {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(succeeded ? Color.groupEquipment : Color.groupCombat)

            Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                .font(.dsaBody(.body))
                .multilineTextAlignment(.center)

            Button {
                if succeeded {
                    step = onSuccess
                } else {
                    step = .attackChoice
                }
            } label: {
                Text(succeeded ? L("continue") : L("back"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(succeeded ? combatAccent : Color.dsaDark)
                    .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
        } else {
            Image(systemName: "dice.fill")
                .font(.system(size: 36))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheck"))
                .font(.dsaBody(.body))
                .multilineTextAlignment(.center)

            Button {
                showingProbeModal = true
            } label: {
                Text(L("rollReitenCheck"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(combatAccent)
                    .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    private var reitenManual: some View {
        Group {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheckPrompt"))
                .font(.dsaBody(.body))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
                } label: {
                    Text(L("no"))
                        .font(.dsaBody(.body))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)

                Button {
                    step = onSuccess
                } label: {
                    Text(L("yes"))
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(combatAccent)
                        .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
            }
        }
    }
}
