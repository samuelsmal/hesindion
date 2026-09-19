import SwiftUI
import SwiftData

// MARK: - CombatAttackChoiceView

struct CombatAttackChoiceView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    let mountedActive: Bool
    var onDismiss: () -> Void

    private var isDualWield: Bool { hero.isDualWielding }
    private var hasShield: Bool { hero.selectedShield != nil }

    /// Check if current weapon is eligible for two-handed grip.
    /// Not applicable to Dolche (CT_1) or Fechtwaffen (CT_3).
    private var canUseTwoHanded: Bool {
        guard !isDualWield, !hasShield else { return false }
        guard let w = hero.selectedWeapon else { return false }
        return CombatTechniqueID(rawValue: w.combatTechniqueId)?.allowsTwoHandedGrip ?? true
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
                Text(L("attack"))
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
                VStack(spacing: 8) {
                    if isDualWield {
                        dualWieldOptions
                    } else if canUseTwoHanded {
                        gripOptions
                    } else if mountedActive {
                        heroSingleAttackOption
                    } else {
                        // Shouldn't reach here, but handle gracefully
                        Color.clear.onAppear { proceedSingleAttack() }
                    }

                    if mountedActive, let mount = hero.pets.first {
                        mountAttackSection(mount: mount)
                    }
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            Spacer()
        }
    }

    // MARK: - Dual-wield options

    private var dualWieldOptions: some View {
        VStack(spacing: 8) {
            combatSectionLabel(mountedActive ? L("heroAttacksGroup") : L("attack"))

            // Single weapon attack (no penalty)
            choiceButton(
                title: L("singleAttack"),
                subtitle: nil,
                icon: "1.circle.fill"
            ) {
                dualAttackPenaltyActive = false
                step = .weaponSelection(.angriff)
            }

            // Both weapons attack (with penalty)
            let penalty = hero.dualAttackPenalty
            let penaltyText = penalty == 0 ? nil : "\(penalty) AT, \(penalty) \(L("parry"))/\(L("dodge"))"
            choiceButton(
                title: L("dualAttack"),
                subtitle: penaltyText,
                icon: "2.circle.fill"
            ) {
                dualAttackPenaltyActive = true
                step = .weaponSelection(.angriff)
            }
        }
    }

    // MARK: - Grip options (single weapon, no shield)

    private var gripOptions: some View {
        VStack(spacing: 8) {
            combatSectionLabel(mountedActive ? L("heroAttacksGroup") : L("attack"))

            choiceButton(
                title: L("oneHanded"),
                subtitle: nil,
                icon: "hand.raised.fill"
            ) {
                twoHandedGripActive = false
                proceedSingleAttack()
            }

            choiceButton(
                title: L("twoHanded"),
                subtitle: nil,
                icon: "hands.clap.fill"
            ) {
                twoHandedGripActive = true
                proceedSingleAttack()
            }
        }
    }

    private func proceedSingleAttack() {
        if let w = hero.selectedWeapon {
            // The weapon's own damage, unadjusted: the announcement screen owns
            // every bonus, the grip's +1 included. Adding it here too gave a
            // two-handed attack +2 TP for a button that promises +1.
            step = .announcement(.angriff, name: w.name, baseAT: w.at, damageFormula: w.damage, isOffHand: false, secondAttack: nil, isMountCharge: false)
        } else if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            step = .announcement(.angriff, name: "Raufen", baseAT: raufen?.at ?? 0, damageFormula: "1W6", isOffHand: false, secondAttack: nil, isMountCharge: false)
        }
    }

    // MARK: - Hero single attack (mounted, no dual-wield / two-hand)

    private var heroSingleAttackOption: some View {
        VStack(spacing: 8) {
            combatSectionLabel(L("heroAttacksGroup"))

            if let w = hero.selectedWeapon {
                choiceButton(
                    title: w.name,
                    subtitle: "AT \(w.at) · TP \(w.damage)",
                    icon: "hand.raised.fill"
                ) {
                    proceedSingleAttack()
                }
            } else if hero.selectedWeaponName == "Raufen" {
                let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                choiceButton(
                    title: "Raufen",
                    subtitle: "AT \(raufen?.at ?? 0) · TP 1W6",
                    icon: "hand.raised.fill"
                ) {
                    proceedSingleAttack()
                }
            }
        }
    }

    // MARK: - Mount attack section

    private func mountAttackSection(mount: Pet) -> some View {
        VStack(spacing: 8) {
            combatSectionLabel(L("mountAttacksGroup"))

            // Regular mount attacks (Hufschlag, Tritt, etc.) — exclude Niederreiten (has dedicated button below)
            ForEach(mount.attacks.filter { $0.name != "Niederreiten" }, id: \.name) { attack in
                let mightyBlowNote: String? = {
                    guard mount.specialSkills.contains("Mächtiger Schlag") else { return nil }
                    let kk = mount.attributes.kk
                    let penalty = (kk - 20) / 2
                    if penalty > 0 {
                        return String(format: L("mightyBlow"), penalty)
                    } else {
                        return L("mightyBlowNoPenalty")
                    }
                }()

                choiceButton(
                    title: "\(mount.name): \(attack.name)",
                    subtitle: "AT \(attack.at) · TP \(attack.damage)",
                    icon: "pawprint.fill"
                ) {
                    step = .execution(
                        .angriff,
                        name: "\(mount.name): \(attack.name)",
                        attributeValue: attack.at,
                        damageFormula: attack.damage,
                        note: mightyBlowNote,
                        modifierLines: nil
                    )
                }
            }

            // Niederreiten
            niederreitenButton(mount: mount)

            // Sturmangriff zu Pferd (requires Berittener Kampf)
            sturmangriffZuPferdButton(mount: mount)

            // Mount special skills note
            if !mount.specialSkills.isEmpty {
                Text("\u{24D8} \(mount.specialSkills)")
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(combatAccent)
                    .padding(.top, 2)
            }
        }
    }

    private func niederreitenButton(mount: Pet) -> some View {
        let niederreitenAT = mount.attacks.first?.at ?? 0
        let niederreitenAttack = mount.attacks.first { $0.name == "Niederreiten" }
        let niederreitenDamage = niederreitenAttack?.damage ?? mount.damage

        let mightyBlowNote: String? = {
            guard mount.specialSkills.contains("Mächtiger Schlag") else { return nil }
            let kk = mount.attributes.kk
            let penalty = (kk - 20) / 2
            if penalty > 0 {
                return String(format: L("mightyBlow"), penalty)
            } else {
                return L("mightyBlowNoPenalty")
            }
        }()
        let niederreitenNote = [L("niederreiten.info"), mightyBlowNote]
            .compactMap { $0 }
            .joined(separator: "\n")

        return choiceButton(
            title: L("niederreiten"),
            subtitle: "AT \(niederreitenAT) · TP \(niederreitenDamage)",
            icon: "figure.equestrian.sports"
        ) {
            let successStep = CombatStep.execution(
                .angriff,
                name: "\(mount.name): \(L("niederreiten"))",
                attributeValue: niederreitenAT,
                damageFormula: niederreitenDamage,
                note: niederreitenNote,
                modifierLines: nil
            )
            step = .mountPreCheck(onSuccess: successStep)
        }
    }

    @ViewBuilder
    private func sturmangriffZuPferdButton(mount: Pet) -> some View {
        if hero.hasBerittenerKampf, let w = hero.selectedWeapon {
            let damageBonus = hero.sturmangriffDamageBonus
            let bonusLabel = damageBonus >= 0 ? "+\(damageBonus)" : "\(damageBonus)"
            choiceButton(
                title: L("sturmangriffPferd"),
                subtitle: "\(w.name) · AT \(w.at) · TP \(w.damage) \(bonusLabel)",
                icon: "bolt.fill"
            ) {
                let successStep = CombatStep.announcement(
                    .angriff,
                    name: w.name,
                    baseAT: w.at,
                    damageFormula: w.damage,
                    isOffHand: false,
                    secondAttack: nil,
                    isMountCharge: true
                )
                step = .mountPreCheck(onSuccess: successStep)
            }
        }
    }

    private func choiceButton(title: String, subtitle: String?, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(combatAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dsaBody(.body))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.dsaBody(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
    }
}

// MARK: - CombatAnnouncementView

struct CombatAnnouncementView: View {
    let hero: Hero
    let action: CombatAction
    let weaponName: String
    let baseAT: Int
    let damageFormula: String?
    let isOffHand: Bool
    let mountedActive: Bool
    let waterDepth: WaterDepth
    let isMountCharge: Bool
    let beengteUmgebungActive: Bool
    let schipIgnoreZustandThisRound: Bool
    let secondAttack: (name: String, at: Int, damage: String?)?
    @Binding var step: CombatStep
    @Binding var activeManeuver: CombatManeuver
    @Binding var vorstossActiveThisRound: Bool
    @Binding var announcedZone: HitZone?
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    /// The other side of the fight, as far as the app has been told. Owned by
    /// `CombatView` so that the screens resolving *this* swing — the roll, the
    /// opponent's defence, the damage — all read the same answers. Cleared here
    /// as the announcement opens: a new announcement may be at a new opponent.
    /// `CombatView` clears it again on the way back to the root, so a defence
    /// rolled from there does not inherit this announcement's answers either.
    @Binding var opponent: OpponentProfile
    var onDismiss: () -> Void

    /// The reach of the weapon being announced — the one named in the header, not
    /// whatever the hero has in the main hand. It is handed to the modifier
    /// engine as the announced `loadoutName`, so the chips cannot promise a
    /// penalty the roll does not apply.
    private var heroWeaponReach: WeaponReach {
        hero.reach(ofLoadoutNamed: weaponName)
    }
    @State private var selectedManeuver: CombatManeuver = .normal
    @State private var targetZone: HitZone? = nil
    @State private var showingZoneRoll = false

    /// Whether this weapon has anything to say about demons at all.
    private var weaponIsConsecrated: Bool {
        hero.isFokusRuleActive(.karmaleObjekte) && hero.isConsecrated(weaponName)
    }

    /// The multiplier the Fokusregel adds, if any.
    private var karmalDamage: CriticalDamage {
        DamageModifiers.multiplier(situation: situation(.damage))
    }

    private var zonesActive: Bool { hero.isFokusRuleActive(.trefferzonen) }

    private var availableManeuvers: [CombatManeuver] {
        var maneuvers: [CombatManeuver] = [.normal]
        if hero.finteTier > 0 { maneuvers.append(.finte(tier: hero.finteTier)) }
        // One entry per tier the hero has, not only the highest: Wuchtschlag II
        // may be swung as a I, and the trade (-2 AT per +2 TP) is the whole
        // decision. Offering the top tier alone made that choice for the player.
        if hero.wuchtschlagTier > 0 {
            for tier in 1...hero.wuchtschlagTier {
                maneuvers.append(.wuchtschlag(tier: tier))
            }
        }
        if hero.hasVorstoss { maneuvers.append(.vorstoss) }
        if hero.hasSchildspalter { maneuvers.append(.schildspalter) }
        if mountedActive && hero.hasBerittenerKampf { maneuvers.append(.sturmangriff) }
        return maneuvers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .weaponSelection(action) } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityIdentifier("combat.back")
                Spacer()
                VStack(spacing: 1) {
                    Text(L("announcement"))
                        .font(.dsaHeading(.headline))
                        .foregroundStyle(.white)
                    Text(weaponName)
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white.opacity(0.85))
                }
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
                VStack(spacing: 8) {
                    opponentSection

                    // Maneuver selection (hidden for mount charge — auto-selected)
                    if !isMountCharge {
                    combatSectionLabel(L("announcement.label"))

                    VStack(spacing: 8) {
                    ForEach(availableManeuvers, id: \.self) { maneuver in
                        let isSelected = selectedManeuver == maneuver
                        Button { selectedManeuver = maneuver } label: {
                            // Selection is the accent fill, the same signal the zone
                            // and reach chips use. The radio circle that used to sit
                            // here was a second, different way of saying the same
                            // thing on the same screen.
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(maneuver.displayName)
                                            .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                        Spacer()
                                        if maneuver.atModifier != 0 {
                                            Text("AT \(maneuver.atModifier > 0 ? "+" : "")\(maneuver.atModifier)")
                                                .font(.dsaMono(.caption, emphasis: true))
                                                .foregroundStyle(
                                                    isSelected
                                                        ? .white
                                                        : (maneuver.atModifier > 0 ? Color.dsaPositive : Color.groupCombat)
                                                )
                                        }
                                    }
                                    if let info = maneuver.infoText() {
                                        Text(info)
                                            .font(.dsaBody(.caption2))
                                            .foregroundStyle(
                                                isSelected
                                                    ? Color.white.opacity(0.85)
                                                    : (maneuver.preventsDefense ? Color.groupCombat : Color.secondary)
                                            )
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? combatAccent : Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)
                    }
                    }
                    .dsaOptionGroup()
                    } // end if !isMountCharge

                    // Trefferzone (Fokus-Regel). The zones on offer are the
                    // opponent's, not the hero's: a four-legged opponent has no
                    // Arme, and a 1W20 against them lands on their own table.
                    if zonesActive, opponent.bodyPlanKind != .keineZonen {
                        CombatZonePicker(
                            selection: $targetZone,
                            targetIsSurprised: $opponent.isSurprised,
                            zones: HitZoneTable.zones(for: opponent.bodyPlan),
                            showsPenalty: true,
                            showsSurprisedToggle: true,
                            hasSonderfertigkeit: hero.hasGezielterAngriff,
                            sfHalvesKey: "trefferzone.sfHalves.melee",
                            accessory: AnyView(rollZoneButton)
                        )
                    }

                    // Mount charge info
                    if isMountCharge {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(combatAccent)
                            Text(L("sturmangriffPferd.info"))
                                .font(.dsaBody(.caption))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(combatAccent.opacity(0.1))
                        .dsaBox(.flush, stroke: combatAccent)
                    }

                    // The announcement, added up: what the attack is rolled
                    // against, what it does to the opponent's defence, and what
                    // it will hit for. Every part of it was on this screen
                    // already, one modifier per row, but the numbers they add up
                    // to only appeared on the next screen — so the decision this
                    // screen exists for was made without its result in view.
                    attackBreakdown
                    opponentDefenseBreakdown

                    // What the manoeuvre just did to the damage, if anything.
                    damageBreakdown

                    CombatActionButton(
                        title: L("continue"),
                        identifier: "combat.announcement.continue"
                    ) { proceed() }
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            if isMountCharge {
                selectedManeuver = .sturmangriff
            }
            // A new announcement is a new opponent. Not only the posture: the
            // reach, the body plan, the size and the Dämon go as well, because
            // the hero may well be swinging at somebody else this time and the
            // app has no way of knowing that they are not.
            //
            // Coming *back* here from the execution screen re-fires this and so
            // asks again. That is the same rule read the same way — the player
            // is standing in front of the announcement, about to announce — and
            // the alternative (remembering which announcement this used to be)
            // would keep a stale opponent alive for exactly the case the reset
            // exists for. The section is shut by default, so an attack that
            // answers nothing notices nothing.
            opponent.reset()
        }
        .overlay {
            if showingZoneRoll {
                DSADiceRevealModal(
                    title: L("trefferzone.section"),
                    sides: 20,
                    accent: combatAccent,
                    result: { rolls in
                        AnyView(
                            HitZoneTableView(
                                plan: opponent.bodyPlan,
                                roll: rolls.first,
                                accent: combatAccent
                            )
                        )
                    },
                    onConfirm: { rolls in
                        if let roll = rolls.first {
                            targetZone = HitZoneTable.lookup(roll, plan: opponent.bodyPlan).zone
                        }
                        showingZoneRoll = false
                    },
                    onCancel: { showingZoneRoll = false }
                )
            }
        }
    }

    private func proceed() {
        activeManeuver = selectedManeuver
        if selectedManeuver.preventsDefense {
            vorstossActiveThisRound = true
        }
        announcedZone = hero.isFokusRuleActive(.trefferzonen) ? targetZone : nil

        let modifiers = buildModifierLines()
        let effectiveAT = baseAT + modifiers.reduce(0) { $0 + $1.value }
        let note = selectedManeuver.infoText()

        // The weapon's own damage and the bonuses travel apart: the damage
        // screen prints every part, and nothing can fold the same bonus in twice.
        step = .execution(
            action,
            name: weaponName,
            attributeValue: effectiveAT,
            damageFormula: damageFormula,
            note: note,
            modifierLines: modifiers,
            secondAttack: secondAttack,
            damageLines: damageBonusLines,
            damageMultiplier: karmalDamage,
            opponentDefenseModifiers: opponentDefenseLines
        )
    }

    // MARK: - The other side of the fight

    /// What is set, read off the lid while the section is shut.
    private var opponentSummary: String {
        var parts: [String] = [opponent.reach.rawValue]
        // Only in the saddle, because only there is the toggle on the screen: a
        // chip on the lid for a row the player cannot open and clear is a fact
        // they cannot take back.
        if mountedActive, opponent.isOnFoot == true { parts.append(L("opponent.onFoot.short")) }
        if opponent.size != .mittel { parts.append(L(opponent.size.nameKey)) }
        if opponent.advantageousPosition { parts.append("AT/VW +2") }
        if opponent.fromBehind { parts.append(L("fromBehind")) }
        if opponent.isProne { parts.append(L("opponent.prone")) }
        if opponent.isSurprised { parts.append(L("trefferzone.targetSurprised")) }
        if opponent.isDaemon { parts.append(L("daemon.target.short")) }
        return parts.joined(separator: " · ")
    }

    /// Everything the GM can tell the app about the other side, in one fold.
    ///
    /// These were four separate things in three places: the reach had its own
    /// section at the top, Vorteilhafte Position a loose row above it, "Ziel ist
    /// überrascht" was buried in the Trefferzone picker, and the demon question
    /// sat between the zone and the calculations. They are all the same kind of
    /// fact — something true of the opponent that a rule turns on — and most
    /// attacks answer none of them, which is why the section folds.
    private var opponentSection: some View {
        CombatDisclosureSection(
            title: L("opponent.label"),
            summary: opponentSummary,
            identifier: "combat.attack.opponent"
        ) {
            // Reach. Each option carries what it costs the hero's own weapon —
            // reaching past a longer weapon is -2 per step — the same way the
            // zone chips print their Zonenaufschlag.
            captioned(L("opponentReach.label")) {
                HStack(spacing: 8) {
                    ForEach(WeaponReach.allCases, id: \.self) { reach in
                        let isSelected = opponent.reach == reach
                        let penalty = heroWeaponReach.atPenaltyAgainst(reach)
                        Button { opponent.reach = reach } label: {
                            VStack(spacing: 2) {
                                Text(reach.rawValue)
                                    .font(.dsaBody(.caption))
                                Text(penalty == 0 ? "AT ±0" : "AT \(penalty)")
                                    .font(.dsaMono(.caption2, emphasis: true))
                                    .opacity(isSelected ? 0.85 : 0.6)
                            }
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                            .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)
                        .accessibilityIdentifier("combat.reach.\(reach.rawValue)")
                    }
                }
                .dsaOptionGroup()
            }

            // Which Trefferzonentabelle they are built on. Only under the rule
            // that uses it — and it is the one thing on this screen the app
            // cannot fall back on a sensible default for, because the hero's own
            // table is the wrong answer for anything that is not another person.
            if zonesActive {
                captioned(L("opponent.bodyPlan")) {
                    chipRow(BodyPlanKind.allCases, id: \.id, isSelected: { $0 == opponent.bodyPlanKind }) { kind in
                        opponent.bodyPlanKind = kind
                        opponent.size = kind.size(keeping: opponent.size)
                    } label: { L($0.nameKey) } identifier: { "combat.opponent.plan.\($0.rawValue)" }
                }
            }

            // Größenkategorie. Asked with or without the Trefferzonen rule: a
            // winzig target costs the attack −4 (GRW_groessenkategorie). A size
            // the body plan has no table for rolls on the nearest one.
            captioned(L("opponent.size")) {
                CreatureSizeChipRow(
                    size: $opponent.size,
                    detail: { $0 == .winzig ? "AT −4" : nil },
                    identifierPrefix: "combat.opponent.size"
                )
            }

            // Only a rider can be better placed for being mounted, so the
            // question is only asked in the saddle. Off is "not stated", not
            // "mounted opponent": the evaluator then asks for the fact and the
            // calculation says the rule is waiting on an answer.
            if mountedActive {
                DSAToggleRow(
                    title: L("opponent.onFoot"),
                    isOn: Binding(
                        get: { opponent.isOnFoot == true },
                        set: { opponent.isOnFoot = $0 ? true : nil }
                    ),
                    accent: combatAccent,
                    detail: "AT/VW +2",
                    subtitle: L("advantageousPosition"),
                    identifier: "combat.opponent.onFoot"
                )
            }

            // Vorteilhafte Position. A mounted hero against a foot fighter has
            // it without the toggle (GRW_vorteilhaftePosition asks the roster
            // for onFoot).
            DSAToggleRow(
                title: L("advantageousPosition"),
                isOn: $opponent.advantageousPosition,
                accent: combatAccent,
                detail: "AT/VW +2",
                identifier: "combat.attack.advantageousPosition"
            )

            // Angriff von hinten: an opponent line on the announcement (their
            // defence, subtracted by the GM); the same fact costs the hero's
            // own VW when it is the hero being attacked (Task 5, defence screen).
            DSAToggleRow(
                title: L("fromBehind"),
                isOn: $opponent.fromBehind,
                accent: combatAccent,
                detail: L("fromBehind.attackDetail"),
                identifier: "combat.attack.fromBehind"
            )

            // Status Liegend: the penalty is theirs, on their defence — the
            // rules give the attacker nothing for it.
            DSAToggleRow(
                title: L("opponent.prone"),
                isOn: $opponent.isProne,
                accent: combatAccent,
                detail: "\(L("parry")) −2",
                subtitle: L("opponent.prone.effect"),
                identifier: "combat.attack.prone"
            )

            // Karmale Objekte. Only for a weapon the player has marked as
            // consecrated, because for every other weapon the rule says nothing.
            if weaponIsConsecrated {
                DSAToggleRow(
                    title: L("daemon.target"),
                    isOn: $opponent.isDaemon,
                    accent: combatAccent,
                    subtitle: L("daemon.target.subtitle"),
                    identifier: "combat.attack.daemon"
                )

                if opponent.isDaemon {
                    DSAToggleRow(
                        title: L("daemon.opposingDeity"),
                        isOn: $opponent.isOfOpposingDeity,
                        accent: combatAccent,
                        detail: L("daemon.opposingDeity.detail"),
                        identifier: "combat.attack.opposingDeity"
                    )
                }
            }
        }
    }

    /// A control under the name of what it sets. The section holds several
    /// pickers and a bare row of chips says nothing about which question it
    /// answers.
    private func captioned<Content: View>(
        _ caption: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipRow<T, ID: Hashable>(
        _ options: [T],
        id: KeyPath<T, ID>,
        isSelected: @escaping (T) -> Bool,
        select: @escaping (T) -> Void,
        label: @escaping (T) -> String,
        identifier: @escaping (T) -> String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips(options, id: id, isSelected: isSelected, select: select, label: label, identifier: identifier) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                chips(options, id: id, isSelected: isSelected, select: select, label: label, identifier: identifier)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .dsaOptionGroup()
    }

    @ViewBuilder
    private func chips<T, ID: Hashable>(
        _ options: [T],
        id: KeyPath<T, ID>,
        isSelected: @escaping (T) -> Bool,
        select: @escaping (T) -> Void,
        label: @escaping (T) -> String,
        identifier: @escaping (T) -> String
    ) -> some View {
        ForEach(options, id: id) { option in
            let selected = isSelected(option)
            Button { select(option) } label: {
                Text(label(option))
                    .font(.dsaHeading(.caption))
                    .foregroundStyle(selected ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(selected ? combatAccent : Color(UIColor.secondarySystemBackground))
                    .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier(identifier(option))
        }
    }

    /// The other way of answering "where did it land": 1W20 on the opponent's
    /// own table. The receiving side has had this since the rule went in; the
    /// attacking side could only ever declare a zone and pay its Zonenaufschlag.
    private var rollZoneButton: some View {
        Button { showingZoneRoll = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "dice.fill")
                Text(L("trefferzone.roll"))
            }
            .font(.dsaHeading(.caption))
            .foregroundStyle(targetZone == nil ? Color.white : Color.dsaDisabledLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(targetZone == nil ? combatAccent : Color(UIColor.secondarySystemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.zone.roll")
    }

    /// Everything this attack is evaluated against, for whichever domain asks.
    private func situation(_ domain: RuleDomain) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.mounted = mountedActive
        s.round.water = waterDepth
        s.round.schipIgnoreZustand = schipIgnoreZustandThisRound
        s.round.dualAttackActive = dualAttackPenaltyActive
        s.round.beengteUmgebung = beengteUmgebungActive
        s.round.twoHandedGrip = twoHandedGripActive
        s.round.plaenklerActive = plaenklerActive
        s.round.plaenklerBonus = plaenklerBonus
        s.opponents = OpponentRoster([opponent])
        s.loadoutName = weaponName
        s.maneuver = selectedManeuver
        s.isOffHand = isOffHand
        s.targetHitZone = targetZone
        return s
    }

    private func buildModifierLines() -> [ModifierLine] {
        ModifierEngine.shared.evaluate(context: situation(.meleeAttack))
    }

    /// Where the extra TP come from. The box the player reads and the formula the
    /// dice get are the same call, so they cannot disagree.
    private var damageBonusLines: [ModifierLine] {
        DamageModifiers.lines(situation: situation(.damage))
    }

    /// The AT as it will be rolled. Same box, same rows and the same "Basis /
    /// Effektiv" wording as the execution screen, because it is the same
    /// calculation — this is where it is decided and there it is thrown.
    private var attackBreakdown: some View {
        let lines = buildModifierLines()
        return CombatBreakdownBox(
            baseValue: "\(baseAT)",
            baseSource: L("source.basis"),
            lines: lines,
            totalValue: "AT \(baseAT + lines.reduce(0) { $0 + $1.value })",
            totalSource: L("source.effective"),
            sectionLabel: L("attack.label")
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.announcement.atBreakdown")
    }

    /// What the announcement costs the *other* side. Finte comes from
    /// `OpponentProfile.defenseModifiers`, and it used to say so as grey
    /// subtitle text under the manoeuvre row — the one modifier on the screen
    /// that was not a number in a column. Every other opponent line is the
    /// catalog's (`Evaluation.opponentLines`) — Liegend, so far.
    ///
    /// Nothing is applied: the opponent is not modelled (ADR-0005), so this is
    /// the figure the GM subtracts.
    @ViewBuilder
    private var opponentDefenseBreakdown: some View {
        let lines = opponentDefenseLines
        if !lines.isEmpty {
            CombatBreakdownBox(
                rows: lines.map(BreakdownRow.line),
                totalValue: "VW \(signed(lines.reduce(0) { $0 + $1.value }))",
                totalSource: L("source.opponentDefense"),
                sectionLabel: L("opponentDefense.label")
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("combat.announcement.opponentDefense")
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : (value < 0 ? "\(value)" : "±0")
    }

    private var opponentDefenseLines: [ModifierLine] {
        opponent.defenseModifiers(maneuver: selectedManeuver)
            + ModifierEngine.shared.evaluation(situation(.meleeAttack)).opponentLines.map(\.modifierLine)
    }

    /// The TP calculation, for the same reason the AT one exists: a manoeuvre
    /// bonus that is only ever folded into a formula string cannot be checked
    /// against the rulebook. Hidden when the weapon's damage is all there is.
    @ViewBuilder
    private var damageBreakdown: some View {
        // Always, not only when something modifies it. What the attack will hit
        // for is half of what this screen is announcing, and hiding the box on
        // an unmodified swing left the screen ending on the AT with the "Weiter"
        // apparently welded to it.
        if let formula = damageFormula {
            // Once per render: the rows and the total are the same lines, and
            // working them out asks the evaluator. `karmalDamage` is a second
            // catalog evaluation, so it is taken once here too.
            let bonus = damageBonusLines
            let karmal = karmalDamage
            CombatBreakdownBox(
                rows: damageRows(formula, bonus, karmal),
                totalValue: effectiveDamageLabel(formula, bonus, karmal),
                totalSource: L("source.effective"),
                sectionLabel: L("damage.label")
            )
        }
    }

    /// Rows rather than the base/lines shorthand, because a multiplier is not a
    /// signed term and the shorthand can only add.
    private func damageRows(_ formula: String, _ bonus: [ModifierLine], _ karmal: CriticalDamage) -> [BreakdownRow] {
        var rows: [BreakdownRow] = [BreakdownRow(value: formula, source: L("source.weapon"))]
        rows.append(contentsOf: bonus.map(BreakdownRow.line))
        if let label = karmal.label {
            rows.append(BreakdownRow(
                value: label, source: L("source.karmal.opposing"), tint: Color.groupCombat
            ))
        }
        return rows
    }

    /// "1W6+8", or "(1W6+8) ×2" where the Fokusregel doubles it — the dice are
    /// not rolled yet, so the multiplier stays in the label rather than being
    /// worked into the formula.
    private func effectiveDamageLabel(_ formula: String, _ bonus: [ModifierLine], _ karmal: CriticalDamage) -> String {
        let added = DamageModifiers.applied(to: damageFormula, lines: bonus) ?? formula
        guard let label = karmal.label else { return added }
        return "(\(added)) \(label)"
    }
}

// MARK: - CombatWeaponSelectionView

struct CombatWeaponSelectionView: View {
    let action: CombatAction
    let hero: Hero
    @Binding var step: CombatStep
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    /// Everything the round is in. A defence picked here is rolled straight from
    /// this screen, so this screen is where its modifiers have to come from.
    let situation: CombatSituation
    /// And who the defence is against: a parry is modified by the other side as
    /// well as by the round (GRW_vorteilhaftePosition reads `onFoot`).
    let opponent: OpponentProfile
    var onDismiss: () -> Void

    /// What the attacker's size leaves a parry (`SizeCategoryRules`). Only a
    /// parry is restricted; the attack path lists everything.
    private var allowedDefenses: Set<SizeCategoryRules.Defense> {
        SizeCategoryRules.allowedDefenses(against: opponent.size)
    }
    private var weaponParryBlocked: Bool { action == .parieren && !allowedDefenses.contains(.weaponParry) }
    private var shieldParryBlocked: Bool { action == .parieren && !allowedDefenses.contains(.shieldParry) }

    private var headerLabel: String {
        switch action {
        case .angriff:    return L("attack")
        case .parieren:   return L("selectParryWeapon")
        case .ausweichen: return L("dodge")
        case .fernkampf:  return L("rangedAttack")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = dualAttackPenaltyActive && action == .angriff ? .attackChoice : .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityIdentifier("combat.back")
                Spacer()
                Text(headerLabel)
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
                VStack(spacing: 0) {
                    let statLabel = action == .angriff ? "AT" : "PA"

                    // The rows carry the weapon's own value. The dual-attack,
                    // off-hand and grip penalties used to be added here *and*
                    // again by the modifier engine on the next screen, so a
                    // dual-wield attack was penalised twice.

                    // Main weapon option. Against a groß or riesig attacker a
                    // weapon cannot parry (SizeCategoryRules): only the shield.
                    if !weaponParryBlocked, let w = hero.selectedWeapon {
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        weaponRow(
                            name: w.name,
                            statLabel: statLabel,
                            baseValue: action == .angriff ? w.at : (w.pa + hero.passiveShieldPABonus),
                            damageFormula: action == .angriff ? w.damage : nil,
                            note: nil,
                            isOffHand: false
                        )
                    } else if !weaponParryBlocked, hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        weaponRow(
                            name: "Raufen",
                            statLabel: statLabel,
                            baseValue: action == .angriff ? (raufen?.at ?? 0) : ((raufen?.pa ?? 0) + hero.passiveShieldPABonus),
                            damageFormula: action == .angriff ? "1W6" : nil,
                            note: nil,
                            isOffHand: false
                        )
                    }

                    // Off-hand weapon (dual-wield)
                    if !weaponParryBlocked, let offW = hero.selectedOffHandWeapon {
                        combatSectionLabel("\(L("offHandWeapon")) (\(statLabel))")
                        weaponRow(
                            name: offW.name,
                            statLabel: statLabel,
                            baseValue: action == .angriff ? offW.at : offW.pa,
                            damageFormula: action == .angriff ? offW.damage : nil,
                            note: hero.offHandPenalty != 0 ? "\(L("offHandPenalty")): \(hero.offHandPenalty)" : nil,
                            isOffHand: true
                        )
                    }

                    // Shield option
                    if !shieldParryBlocked, let s = hero.selectedShield {
                        combatSectionLabel("\(L("shieldOption")) (\(statLabel))")
                        weaponRow(
                            name: s.name,
                            statLabel: statLabel,
                            baseValue: action == .angriff ? s.at : s.pa,
                            damageFormula: action == .angriff ? s.damage : nil,
                            note: action == .parieren && !s.note.isEmpty ? s.note : nil,
                            isOffHand: false
                        )
                    }
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }
        }
    }

    /// Modifier lines for a defence rolled from this row, or `nil` on the attack
    /// path where the announcement screen builds them instead.
    ///
    /// `itemInHand` is the piece this row parries with, handed to the engine as
    /// `Situation.itemInHand` so a rule that keys on the *thing* — a Patzer that
    /// damaged the shield — reads the shield rather than the main weapon.
    private func defenseLines(isOffHand: Bool, itemInHand: String?) -> [ModifierLine]? {
        guard action != .angriff else { return nil }
        return situation.defenseModifiers(
            hero: hero,
            isAusweichen: action == .ausweichen,
            isOffHand: isOffHand,
            opponents: OpponentRoster([opponent]),
            itemInHand: itemInHand
        )
    }

    private func weaponRow(name: String, statLabel: String, baseValue: Int, damageFormula: String?, note: String?, isOffHand: Bool) -> some View {
        let lines = defenseLines(isOffHand: isOffHand, itemInHand: action == .parieren ? name : nil)
        let shownValue = baseValue + (lines?.reduce(0) { $0 + $1.value } ?? 0)
        return Button {
            if dualAttackPenaltyActive && action == .angriff {
                // Determine the other weapon for the second attack. It never
                // passes an announcement screen, so its penalties stay explicit
                // here — the engine is not asked twice for them.
                let otherWeapon: MeleeWeapon? = isOffHand ? hero.selectedWeapon : hero.selectedOffHandWeapon
                let otherName = otherWeapon?.name ?? "?"
                let otherBaseAT = otherWeapon?.at ?? 0
                let otherOffHandPenalty = isOffHand ? 0 : hero.offHandPenalty
                let otherAT = otherBaseAT + hero.dualAttackPenalty + otherOffHandPenalty
                let otherDmg = otherWeapon?.damage

                step = .announcement(
                    .angriff,
                    name: name,
                    baseAT: baseValue,
                    damageFormula: damageFormula,
                    isOffHand: isOffHand,
                    secondAttack: (name: otherName, at: otherAT, damage: otherDmg),
                    isMountCharge: false
                )
            } else if action == .angriff {
                step = .announcement(.angriff, name: name, baseAT: baseValue, damageFormula: damageFormula, isOffHand: isOffHand, secondAttack: nil, isMountCharge: false)
            } else {
                step = .execution(
                    action,
                    name: name,
                    attributeValue: shownValue,
                    damageFormula: nil,
                    note: action == .parieren ? note : nil,
                    modifierLines: lines
                )
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.dsaBody(.body))
                        .foregroundStyle(.primary)
                    if let note, !note.isEmpty {
                        Text(note)
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(statLabel) \(shownValue)")
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.dsaDark)
                    if hero.belastungPenalty != 0 {
                        Text("(\(hero.belastungPenalty))")
                            .font(.dsaMono(.caption, emphasis: true))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.weaponRow.\(name)")
        .padding(.bottom, 4)
    }
}
