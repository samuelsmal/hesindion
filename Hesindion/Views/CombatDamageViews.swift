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
    /// `nil` until the Selbstbeherrschung probe is rolled — the wound effect has
    /// not been resolved yet, so nothing is applied.
    @State private var probeSucceeded: Bool? = nil
    @State private var showingProbeModal = false
    /// Resolved once when the probe is opened rather than per body pass, because the
    /// FW-0 fallback (see `Hero.selbstbeherrschung`) builds a fresh stand-in `Talent`.
    @State private var probeTalent: Talent? = nil
    /// Rolled once, on confirm, and folded into the single LP write.
    @State private var extraDamage: Int? = nil
    /// Everything `applyDamage` changed, kept so a wrong press can be taken back.
    /// The previous LP is stored rather than recomputed: the write clamps at 0, so
    /// adding the total back would overshoot on a hero who was dropped to zero.
    @State private var applied: AppliedDamage? = nil
    @State private var showingOverwriteAlert = false
    @State private var showingZoneRoll = false

    /// The undo record for a confirmed entry.
    private struct AppliedDamage {
        let previousLP: Int?
        let droppedWeapon: String?
        let logEntries: [LogEntry]
    }
    /// Staged intent, not an immediate action: only cleared on confirm, alongside
    /// the LP write and the log entry, so an abandoned flow cannot disarm the hero.
    @State private var dropWeapon: Bool = false

    private var rs: Int { hero.totalRS }
    private var effectiveDamage: Int { WoundEffectResolver.effectiveDamage(tp: tpInput, rs: rs) }

    /// The Wundeffekt's own damage, but only where it is actually going to be
    /// written: a probe that has not been rolled, or one that was passed, adds
    /// nothing.
    private var appliedExtraDamage: Int {
        guard woundEffectApplies else { return 0 }
        return extraDamage ?? 0
    }

    /// What LP will actually lose. The display used to stop at `TP - RS`, so on
    /// a failed probe the panel showed 12 while the confirm wrote 16 — the one
    /// number the screen exists to produce was the one it did not show.
    private var totalDamage: Int { effectiveDamage + appliedExtraDamage }

    /// "12 TP - 0 RS + 4 WE = 16". The Wundeffekt term appears only when it
    /// contributes, so an ordinary hit still reads as two terms.
    private var damageFormula: String {
        var formula = "\(tpInput) \(L("tp")) \u{2212} \(rs) \(L("rs"))"
        if appliedExtraDamage > 0 {
            formula += " + \(appliedExtraDamage) \(L("we"))"
        }
        return formula + " = \(totalDamage)"
    }

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
    /// basic ability, so an unrolled probe simply means it has not been rolled —
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
            .dsaBox(.raised)

            VStack(spacing: 16) {
                VStack(spacing: 16) {
                // TP input stepper
                combatSectionLabel(L("tp"))

                DSAStepper(
                    tint: combatAccent,
                    decrementDisabled: confirmed || tpInput <= 0,
                    incrementDisabled: confirmed,
                    isSettled: confirmed,
                    incrementIdentifier: "combat.takeDamage.increaseTP",
                    onDecrement: { if tpInput > 0 { tpInput -= 1 } },
                    onIncrement: { tpInput += 1 }
                ) {
                    Text("\(tpInput)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        .padding(.vertical, 14)
                }

                // Calculation display
                VStack(spacing: 4) {
                    Text(damageFormula)
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("combat.takeDamage.formula")
                    if totalDamage == 0 {
                        Text(L("absorbed"))
                            .font(.dsaBody(.caption))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(totalDamage) \(L("lpLost"))")
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
                        isDisabled: confirmed,
                        onRollZone: { showingZoneRoll = true }
                    )

                    if let hit = zoneHit, multiple >= 1 {
                        CombatWoundEffectPanel(
                            hero: hero,
                            hit: hit,
                            effectiveDamage: effectiveDamage,
                            wundschwelle: wundschwelle,
                            probeSucceeded: $probeSucceeded,
                            effectApplies: woundEffectApplies,
                            extraDamage: $extraDamage,
                            confirmed: confirmed,
                            dropWeapon: $dropWeapon,
                            onRollProbe: {
                                probeTalent = hero.selbstbeherrschung
                                showingProbeModal = true
                            }
                        )
                    }
                }

                }
                // Confirmed inputs render disabled but stay reachable: a wrong
                // press should be correctable here rather than forcing "Neue
                // Aktion", which returns to the combat root and leaves the
                // mistaken damage on the sheet. The catcher covers the inputs
                // only, so the action button below stays live.
                .overlay {
                    if confirmed {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { showingOverwriteAlert = true }
                            .accessibilityIdentifier("combat.takeDamage.overwriteCatcher")
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
                            .dsaBox(.raised)
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
                        .dsaBox(.raised)
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
            if showingZoneRoll {
                DSADiceRevealModal(
                    title: L("trefferzone.section"),
                    sides: 20,
                    accent: combatAccent,
                    caption: { $0.first.map { CombatHitZoneRow.rollSummary($0) } },
                    onConfirm: { rolls in
                        if let roll = rolls.first {
                            lastRoll = roll
                            zoneHit = HitZoneTable.lookup(roll, plan: .humanoid(.mittel))
                        }
                        showingZoneRoll = false
                    },
                    onCancel: { showingZoneRoll = false }
                )
            }
        }
        // Not `.alert`: a system alert arrives with rounded corners, a blurred
        // material and tinted text, on top of a screen built without any of the
        // three.
        .overlay {
            if showingOverwriteAlert {
                DSAModal(
                    title: L("takeDamage.overwrite.title"),
                    accent: combatAccent,
                    onScrimTap: { showingOverwriteAlert = false }
                ) {
                    Text(L("takeDamage.overwrite.message"))
                        .font(.dsaBody(.body))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DSAModalButton(
                        title: L("takeDamage.overwrite.action"),
                        accent: combatAccent,
                        identifier: "combat.takeDamage.overwriteConfirm"
                    ) {
                        showingOverwriteAlert = false
                        undoDamage()
                    }

                    DSAModalButton(
                        title: L("cancel"),
                        accent: combatAccent,
                        filled: false,
                        identifier: "combat.takeDamage.overwriteCancel"
                    ) {
                        showingOverwriteAlert = false
                    }
                }
            }
        }
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
        // The Wundeffekt's damage is rolled beforehand (see the panel's roll
        // button), so `confirmDamage` is told the result rather than rolling
        // one of its own — otherwise the figure on screen and the figure written
        // to LP could differ.
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: zoneHit, effectApplies: woundEffectApplies,
            effectiveDamage: effectiveDamage, hero: hero,
            preRolledExtraDamage: extraDamage)
        extraDamage = extra

        var droppedWeapon: String? = nil
        if dropWeapon, woundEffectApplies, let weaponName = hero.selectedWeaponName {
            droppedWeapon = weaponName
            hero.selectedWeaponName = nil
        }

        let previousLP = hero.derivedValues?.lebensenergie.current
        if let dv = hero.derivedValues {
            dv.lebensenergie.current = max(0, dv.lebensenergie.current - total)
        }

        // Held so `undoDamage` can remove exactly the entries this confirm wrote.
        var written: [LogEntry] = []

        let actionEntry = LogEntry.create(
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
        )
        modelContext.insert(actionEntry)
        written.append(actionEntry)

        if let hit = zoneHit, woundEffectThreatens {
            let effectEntry = LogEntry.create(
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
            )
            modelContext.insert(effectEntry)
            written.append(effectEntry)
        }

        applied = AppliedDamage(
            previousLP: previousLP,
            droppedWeapon: droppedWeapon,
            logEntries: written
        )
        confirmed = true
    }

    /// Takes back a confirmed entry so a wrong press can be corrected in place.
    ///
    /// Without this the only way out was "Neue Aktion", which returns to the
    /// combat root and leaves the mistaken damage on the sheet. Everything the
    /// confirm wrote is reversed: the LP value, the dropped weapon, and both log
    /// entries.
    private func undoDamage() {
        guard let record = applied else { return }

        if let dv = hero.derivedValues, let previous = record.previousLP {
            dv.lebensenergie.current = previous
        }
        if let weaponName = record.droppedWeapon {
            hero.selectedWeaponName = weaponName
        }
        for entry in record.logEntries {
            modelContext.delete(entry)
        }

        applied = nil
        extraDamage = nil
        confirmed = false
    }
}

// MARK: - WoundEffectReminderCard

/// Rules prompt shown after a landed targeted attack.
///
/// Nothing is *applied*: the opponent has no LP, no KO and no states, so the app
/// states the rule and leaves the call to the player. Where the effect is extra
/// damage the number can still be settled here — rolled, or entered after being
/// told — because the player needs the figure to report, even though there is
/// nothing on this device to subtract it from.
struct WoundEffectReminderCard: View {
    let zone: HitZone
    /// Owned by the screen, so the damage total can include it.
    @Binding var extraDamage: Int?

    var body: some View {
        let effect = WoundEffectCatalog.effect(for: zone)
        VStack(alignment: .leading, spacing: 6) {
            combatSectionLabel(String(format: L("trefferzone.reminderTitle"), L(zone.nameKey)))
            Text(L(effect.effectKey))
                .font(.dsaBody(.caption))
            Text(L(effect.resistanceKey))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)

            if case .extraDamage = effect.kind {
                WoundEffectDamageControl(zone: zone, value: $extraDamage)
                    .padding(.top, 4)
            }
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
            .dsaBox(.raised)

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
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)

                    Text("\(spAmount)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.raised)

                    Button {
                        spAmount += 1
                    } label: {
                        Text("+")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .dsaBox(.raised)
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
                    .dsaBox(.raised)
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
                            .dsaBox(.raised, stroke: Color.groupCombat)
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
                            .dsaBox(.raised)
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
                            .dsaBox(.raised)
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
                            .dsaBox(.raised)
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
                            .dsaBox(.raised)
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
            .dsaBox(.raised)

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
                            .dsaBox(.raised)
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
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
        }
        .padding(galoppConfirmed ? 0 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.raised)
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
                    .dsaBox(.raised)
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
                    .dsaBox(.raised)
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
                        .dsaBox(.raised)
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
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
            }
        }
    }
}
