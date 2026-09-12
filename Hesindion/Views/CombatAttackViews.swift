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
        let excluded = ["CT_1", "CT_3"] // Dolche, Fechtwaffen
        return !excluded.contains(w.combatTechniqueId)
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
    var onDismiss: () -> Void

    @State private var vorteilhaftePosition: Bool = false
    @State private var selectedOpponentReach: WeaponReach = .mittel
    @State private var selectedManeuver: CombatManeuver = .normal
    @State private var targetZone: HitZone? = nil
    @State private var targetIsSurprised = false

    private var golgaritenForced: Bool {
        hero.golgaritenActive(mounted: mountedActive)
    }

    private var availableManeuvers: [CombatManeuver] {
        var maneuvers: [CombatManeuver] = [.normal]
        if hero.finteTier > 0 { maneuvers.append(.finte(tier: hero.finteTier)) }
        if hero.wuchtschlagTier > 0 { maneuvers.append(.wuchtschlag(tier: hero.wuchtschlagTier)) }
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
                    // Vorteilhafte Position. Forced on for a mounted Golgarit,
                    // so that case renders the same row without the button.
                    if golgaritenForced {
                        DSAToggleRowLabel(
                            title: "\(L("advantageousPosition")) (\(L("mounted")))",
                            isOn: true,
                            accent: combatAccent
                        )
                    } else {
                        DSAToggleRow(
                            title: L("advantageousPosition"),
                            isOn: $vorteilhaftePosition,
                            accent: combatAccent,
                            identifier: "combat.attack.advantageousPosition"
                        )
                    }

                    // Opponent weapon reach
                    combatSectionLabel(L("opponentReach.label"))

                    HStack(spacing: 8) {
                        ForEach(WeaponReach.allCases, id: \.self) { reach in
                            let isSelected = selectedOpponentReach == reach
                            Button { selectedOpponentReach = reach } label: {
                                Text(reach.rawValue)
                                    .font(.dsaBody(.caption))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                                    .dsaBox(.flush)
                            }
                            .buttonStyle(.dsaMotion)
                        }
                    }
                    .dsaOptionGroup()

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

                    // Trefferzone (Fokus-Regel)
                    if hero.isFokusRuleActive(.trefferzonen) {
                        CombatZonePicker(
                            selection: $targetZone,
                            targetIsSurprised: $targetIsSurprised,
                            showsPenalty: true,
                            showsSurprisedToggle: true,
                            hasSonderfertigkeit: hero.combatSpecialAbilities.contains { $0.ruleId == "SA_160" },
                            sfHalvesKey: "trefferzone.sfHalves.melee"
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

                    // What the manoeuvre just did to the damage, if anything.
                    damageBreakdown
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Continue
            Button { proceed() } label: {
                Text(L("continue"))
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
        .onAppear {
            if isMountCharge {
                selectedManeuver = .sturmangriff
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
        let effectiveDamage = adjustedDamage()
        let note = selectedManeuver.infoText()

        step = .execution(
            action,
            name: weaponName,
            attributeValue: effectiveAT,
            damageFormula: effectiveDamage,
            note: note,
            modifierLines: modifiers,
            secondAttack: secondAttack
        )
    }

    private func buildModifierLines() -> [ModifierLine] {
        var context = ModifierContext(hero: hero, domain: .meleeAttack)
        context.targetHitZone = targetZone
        context.targetIsSurprised = targetIsSurprised
        context.mounted = mountedActive
        context.schipIgnoreZustand = schipIgnoreZustandThisRound
        context.dualAttackActive = dualAttackPenaltyActive
        context.beengteUmgebung = beengteUmgebungActive
        context.opponentReach = selectedOpponentReach
        context.maneuver = selectedManeuver
        context.isOffHand = isOffHand
        context.plaenklerActive = plaenklerActive
        context.plaenklerBonus = plaenklerBonus

        var lines = ModifierEngine.shared.evaluate(context: context)

        // Manual vorteilhafte Position toggle (not golgariten-forced)
        if !golgaritenForced && vorteilhaftePosition {
            lines.insert(ModifierLine(value: 2, source: L("source.vorteilhaft")), at: 0)
        }

        return lines
    }

    /// Where the extra TP come from. The box the player reads and the formula the
    /// dice get are the same call, so they cannot disagree.
    private var damageBonusLines: [ModifierLine] {
        DamageModifiers.lines(
            hero: hero,
            maneuver: selectedManeuver,
            twoHandedGrip: twoHandedGripActive,
            mounted: mountedActive
        )
    }

    /// The TP calculation, for the same reason the AT one exists: a manoeuvre
    /// bonus that is only ever folded into a formula string cannot be checked
    /// against the rulebook. Hidden when the weapon's damage is all there is.
    @ViewBuilder
    private var damageBreakdown: some View {
        if let formula = damageFormula, !damageBonusLines.isEmpty {
            CombatBreakdownBox(
                baseValue: formula,
                baseSource: L("source.weapon"),
                lines: damageBonusLines,
                totalValue: adjustedDamage() ?? formula,
                totalSource: L("source.effective"),
                sectionLabel: L("damage.label")
            )
        }
    }

    private func adjustedDamage() -> String? {
        DamageModifiers.applied(to: damageFormula, lines: damageBonusLines)
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
    var onDismiss: () -> Void

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

                    // Main weapon option
                    if let w = hero.selectedWeapon {
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        weaponRow(
                            name: w.name,
                            statLabel: statLabel,
                            baseValue: action == .angriff ? w.at : (w.pa + hero.passiveShieldPABonus),
                            damageFormula: action == .angriff ? w.damage : nil,
                            note: nil,
                            isOffHand: false
                        )
                    } else if hero.selectedWeaponName == "Raufen" {
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
                    if let offW = hero.selectedOffHandWeapon {
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
                    if let s = hero.selectedShield {
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
    private func defenseLines(isOffHand: Bool) -> [ModifierLine]? {
        guard action != .angriff else { return nil }
        return situation.defenseModifiers(
            hero: hero,
            isAusweichen: action == .ausweichen,
            isOffHand: isOffHand
        )
    }

    private func weaponRow(name: String, statLabel: String, baseValue: Int, damageFormula: String?, note: String?, isOffHand: Bool) -> some View {
        let lines = defenseLines(isOffHand: isOffHand)
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
