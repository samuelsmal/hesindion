import SwiftUI
import SwiftData

// MARK: - CombatTakeDamageView

struct CombatTakeDamageView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int
    /// What the TP are, where the screen did not have to be told by hand — a
    /// Patzer's "Selbst verletzt", say. Named in the calculation's first row so
    /// the figure in the stepper is accountable; `nil` falls back to plain "TP".
    let damageSource: String?
    /// Whether one more blow is still owed after this entry — a defence Patzer
    /// that hurt the hero with their own weapon has not yet accounted for the
    /// opponent's hit, which landed all the same. The last action then leads to a
    /// second, empty entry rather than back to the combat root.
    let thenIncomingHit: Bool

    init(
        hero: Hero,
        step: Binding<CombatStep>,
        onDismiss: @escaping () -> Void,
        combatId: UUID,
        roundNumber: Int,
        prefilledTP: Int? = nil,
        damageSource: String? = nil,
        thenIncomingHit: Bool = false
    ) {
        self.hero = hero
        self._step = step
        self.onDismiss = onDismiss
        self.combatId = combatId
        self.roundNumber = roundNumber
        self.damageSource = damageSource
        self.thenIncomingHit = thenIncomingHit
        self._tpInput = State(initialValue: max(0, prefilledTP ?? 0))
    }

    @Environment(\.modelContext) private var modelContext
    @State private var tpInput: Int
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

    /// The undo record for a confirmed entry, and what the screen reports back.
    private struct AppliedDamage {
        let previousLP: Int?
        let droppedWeapon: String?
        let logEntries: [LogEntry]
        /// Every state's level as it stood before the write, so the outcome can
        /// name the ones that changed. Schmerz is derived from LP, so it moves on
        /// its own without anything setting it — which is precisely the change a
        /// player would otherwise have to notice for themselves.
        let statesBefore: [String: Int]
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

    /// The hit as parts: what was dealt, what the armour stopped, what a Wundeffekt
    /// added. Zero-valued parts are left out, as in every other calculation —
    /// except the armour, which is worth stating even at 0 on the one screen whose
    /// whole subject is how much of the hit got through.
    private var damageRows: [BreakdownRow] {
        var rows: [BreakdownRow] = [
            BreakdownRow(value: "\(tpInput)", source: damageSource ?? L("tp"))
        ]
        rows.append(.signed(-rs, L("rs")))
        if appliedExtraDamage > 0 {
            rows.append(.signed(appliedExtraDamage, L("trefferzone.woundEffect")))
        }
        return rows
    }

    // MARK: - Trefferzonen

    private var zonesActive: Bool { hero.isFokusRuleActive(.trefferzonen) }

    private var wundschwelle: Int { hero.derivedValues?.wundschwelle.max ?? 0 }

    private var multiple: Int {
        WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    /// Whether the full Wundeffekt panel is on screen — it prints the Wundschwelle
    /// comparison itself, so `CombatWundschwelleRow` stands down when it does.
    private var woundEffectPanelShown: Bool {
        zonesActive && zoneHit != nil && multiple >= 1
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

            ScrollView {
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

                if zonesActive {
                    CombatHitZoneRow(
                        zoneHit: $zoneHit,
                        lastRoll: $lastRoll,
                        isDisabled: confirmed,
                        onRollZone: { showingZoneRoll = true }
                    )
                }

                // One slot for what the damage means, always in the same place:
                // below the zone, because the zone is what is being asked for
                // first. The plain comparison stands here until the Wundeffekt
                // panel can say more, and the panel then takes the same slot —
                // rather than the threshold moving above the zone picker when no
                // zone is chosen and below it when one is.
                if wundschwelle > 0, !woundEffectPanelShown {
                    CombatWundschwelleRow(
                        effectiveDamage: effectiveDamage,
                        wundschwelle: wundschwelle,
                        zonesActive: zonesActive,
                        hasZone: zoneHit != nil
                    )
                }

                if zonesActive, let hit = zoneHit, multiple >= 1 {
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

                // One calculation, last, with every part in it — the same box and
                // the same grammar as the damage the hero deals. It used to be a
                // formula string in a dark bar directly under the stepper, which
                // read as a different kind of thing from the row-based
                // calculations everywhere else, and stood above the two inputs
                // (zone, Wundeffekt) that feed it.
                CombatBreakdownBox(
                    rows: damageRows,
                    totalValue: "\(totalDamage) LP",
                    totalSource: totalDamage == 0 ? L("absorbed") : L("lpLost"),
                    sectionLabel: L("calculation.label")
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("combat.takeDamage.formula")

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

                // What the confirm actually did. The screen used to end at
                // "16 LP verloren" and leave the two questions that matter at the
                // table unanswered: how much is left, and what applies now that
                // did not before — the Betäubung a Wundeffekt raised, or the
                // Schmerz step the new LP total crossed on its own.
                //
                // Outside the catcher above: this is a report, and tapping a
                // report should not offer to overwrite the entry.
                if confirmed, let record = applied {
                    CombatDamageOutcomeBox(hero: hero, statesBefore: record.statesBefore)
                }

                if !confirmed {
                    CombatActionButton(
                        title: L("confirm"),
                        identifier: "combat.takeDamage.confirm"
                    ) { applyDamage() }
                } else if thenIncomingHit {
                    // The blow the fumbled parry failed to stop still landed, and
                    // it is a hit of its own: its own TP, its own armour, its own
                    // LP write. Leading there is the only thing that keeps it from
                    // being dropped between the two screens.
                    CombatActionButton(
                        title: L("fumble.incomingHit"),
                        icon: "arrow.right",
                        identifier: "combat.takeDamage.incomingHit"
                    ) { step = .takeDamage(source: L("fumble.incomingHit")) }
                } else {
                    CombatActionButton(
                        title: L("newAction"),
                        icon: "arrow.counterclockwise",
                        identifier: "combat.takeDamage.newAction"
                    ) { step = .root }
                }
            }
            .adaptiveContentWidth()
            .padding(.bottom, 16)
            }
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
                    // The table itself, with the row the die hit lit — rather than
                    // "7: Torso", which stated the answer and hid the rule.
                    result: { rolls in
                        AnyView(
                            HitZoneTableView(
                                plan: hero.bodyPlan,
                                roll: rolls.first,
                                accent: combatAccent
                            )
                        )
                    },
                    onConfirm: { rolls in
                        if let roll = rolls.first {
                            lastRoll = roll
                            zoneHit = HitZoneTable.lookup(roll, plan: hero.bodyPlan)
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
                        damage: effectiveDamage, wundschwelle: wundschwelle),
                    isWoundEffectProbe: true,
                    accent: combatAccent
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
        let statesBefore = Dictionary(
            uniqueKeysWithValues: hero.activeStates.map { ($0.def.id, $0.level) }
        )
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
                    combatId: combatId,
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
            logEntries: written,
            statesBefore: statesBefore
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

/// What a landed targeted attack does to the opponent, and the one thing the
/// player has to be told before it does: whether the opponent's Selbstbeherrschung
/// check succeeded.
///
/// Nothing is *applied*: the opponent has no LP, no KO and no states, so the app
/// states the rule and leaves the call to the player. What it can do is ask the
/// question in the right order. The card used to state the effect and offer its
/// damage immediately, as though the Wundeffekt were automatic — it is not, and
/// the same screen on the receiving side has always made the player roll the
/// check first. The opponent's roll happens at the table, so the app asks for the
/// outcome rather than rolling anything.
struct WoundEffectReminderCard: View {
    let zone: HitZone
    /// Owned by the screen, so the damage total can include it.
    @Binding var extraDamage: Int?
    /// `nil` until the player says how the opponent's check went. Owned by the
    /// screen too: an unanswered question is a reason not to offer the way out
    /// yet, and the screen is what draws that button.
    @Binding var probePassed: Bool?

    var body: some View {
        let effect = WoundEffectCatalog.effect(for: zone)
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(String(format: L("trefferzone.reminderTitle"), L(zone.nameKey)))

            Text(L("trefferzone.onFailure"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
            Text(L(effect.effectKey))
                .font(.dsaBody(.caption))

            switch probePassed {
            case .none:
                probeAsk(effect: effect)
            case .some(true):
                outcomeRow(passed: true)
            case .some(false):
                outcomeRow(passed: false)
                if case .extraDamage = effect.kind {
                    WoundEffectDamageControl(zone: zone, value: $extraDamage)
                }
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

    /// The question, and the two answers. Not a roll: the die is the opponent's,
    /// thrown at the table, and this app never speaks for the other side.
    private func probeAsk(effect: WoundEffect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: L("trefferzone.opponentProbe"), L(effect.resistanceKey)))
                .font(.dsaBody(.caption))

            HStack(spacing: 8) {
                answerButton(
                    title: L("trefferzone.probePassed"),
                    icon: "checkmark.circle.fill",
                    fill: Color.dsaPositive,
                    identifier: "combat.opponentProbe.passed"
                ) {
                    extraDamage = nil
                    probePassed = true
                }

                answerButton(
                    title: L("trefferzone.probeFailed"),
                    icon: "xmark.circle.fill",
                    fill: Color.groupCombat,
                    identifier: "combat.opponentProbe.failed"
                ) {
                    probePassed = false
                }
            }
        }
    }

    private func answerButton(
        title: String,
        icon: String,
        fill: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.dsaHeading(.caption))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(fill)
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier)
    }

    /// The answer, and the way back if it was the wrong button.
    private func outcomeRow(passed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(passed ? Color.dsaPositive : Color.groupCombat)
            Text(passed ? L("trefferzone.noWoundEffect") : L("failure"))
                .font(.dsaHeading(.caption))
            Spacer()
            Button {
                extraDamage = nil
                probePassed = nil
            } label: {
                Text(L("trefferzone.changeProbe"))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(Color.groupCombat)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("combat.opponentProbe.change")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.opponentProbe.outcome")
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

            // A GeometryReader'd ScrollView rather than a bare Spacer sandwich:
            // the content centres exactly as before when it fits the screen, and
            // scrolls instead of running off the bottom edge when it does not
            // (landscape, mostly — see LandscapeScrollFlowTests).
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        if !damageApplied {
                            spInputPhase
                        } else {
                            reitenCheckPhase
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty,
                    accent: combatAccent
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

            // Same fit-then-scroll shape as `CombatMountDamageView`: centred
            // when the three nodes fit, scrollable rather than clipped when
            // they do not.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: 0) {
                            galoppNode
                            connectorArrow
                            reitenNode
                        }
                        .adaptiveContentWidth()

                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    accent: combatAccent
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
