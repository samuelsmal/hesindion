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
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("attack"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

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
            let damage = twoHandedGripActive ? adjustDamage(w.damage, bonus: 1) : w.damage
            step = .announcement(.angriff, name: w.name, baseAT: w.at, damageFormula: damage, isOffHand: false, secondAttack: nil, isMountCharge: false)
        } else if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            step = .announcement(.angriff, name: "Raufen", baseAT: raufen?.at ?? 0, damageFormula: "1W6", isOffHand: false, secondAttack: nil, isMountCharge: false)
        }
    }

    /// Adjusts a damage formula like "1W6+2" by adding a bonus.
    private func adjustDamage(_ formula: String, bonus: Int) -> String {
        let pattern = /^(\d+W\d+)([+-]\d+)?$/
        guard let match = formula.firstMatch(of: pattern) else { return formula }
        let base = String(match.1)
        let existing = match.2.flatMap { Int($0) } ?? 0
        let total = existing + bonus
        if total == 0 { return base }
        return total > 0 ? "\(base)+\(total)" : "\(base)\(total)"
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
                    .font(.system(.caption2, weight: .medium))
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
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(combatAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, weight: .semibold))
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
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
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
    let secondAttack: (name: String, at: Int, damage: String?)?
    @Binding var step: CombatStep
    @Binding var activeManeuver: CombatManeuver
    @Binding var vorstossActiveThisRound: Bool
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    var onDismiss: () -> Void

    @State private var vorteilhaftePosition: Bool = false
    @State private var selectedOpponentReach: WeaponReach = .mittel
    @State private var selectedManeuver: CombatManeuver = .normal

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
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 1) {
                    Text(L("announcement"))
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(.white)
                    Text(weaponName)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 8) {
                    // Vorteilhafte Position
                    if golgaritenForced {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.square.fill")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(combatAccent)
                            Text("\(L("advantageousPosition")) (\(L("mounted")))")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("+2")
                                .font(.system(.caption, design: .monospaced, weight: .black))
                                .foregroundStyle(combatAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(combatAccent.opacity(0.1))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                    } else {
                        Button {
                            vorteilhaftePosition.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: vorteilhaftePosition ? "checkmark.square.fill" : "square")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(vorteilhaftePosition ? combatAccent : .secondary)
                                Text(L("advantageousPosition"))
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(vorteilhaftePosition ? .primary : .secondary)
                                Spacer()
                                if vorteilhaftePosition {
                                    Text("+2")
                                        .font(.system(.caption, design: .monospaced, weight: .black))
                                        .foregroundStyle(combatAccent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(vorteilhaftePosition ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(vorteilhaftePosition ? combatAccent : Color.dsaBorder, lineWidth: vorteilhaftePosition ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                    }

                    // Opponent weapon reach
                    combatSectionLabel(L("opponentReach.label"))

                    HStack(spacing: 8) {
                        ForEach(WeaponReach.allCases, id: \.self) { reach in
                            let isSelected = selectedOpponentReach == reach
                            Button { selectedOpponentReach = reach } label: {
                                Text(reach.rawValue)
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Maneuver selection (hidden for mount charge — auto-selected)
                    if !isMountCharge {
                    combatSectionLabel(L("announcement.label"))

                    ForEach(availableManeuvers, id: \.self) { maneuver in
                        let isSelected = selectedManeuver == maneuver
                        Button { selectedManeuver = maneuver } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(isSelected ? combatAccent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(maneuver.displayName)
                                            .font(.system(.body, weight: isSelected ? .bold : .regular))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if maneuver.atModifier != 0 {
                                            Text("AT \(maneuver.atModifier > 0 ? "+" : "")\(maneuver.atModifier)")
                                                .font(.system(.caption, design: .monospaced, weight: .black))
                                                .foregroundStyle(maneuver.atModifier > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : Color.groupCombat)
                                        }
                                    }
                                    if let info = maneuver.infoText() {
                                        Text(info)
                                            .font(.system(.caption2, weight: .medium))
                                            .foregroundStyle(maneuver.preventsDefense ? Color.groupCombat : Color.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(isSelected ? combatAccent : Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                    }
                    } // end if !isMountCharge

                    // Mount charge info
                    if isMountCharge {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(combatAccent)
                            Text(L("sturmangriffPferd.info"))
                                .font(.system(.caption, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(combatAccent.opacity(0.1))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
                    }
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Continue
            Button { proceed() } label: {
                Text(L("continue"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
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
        var lines: [ModifierLine] = []

        let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
        if be > 0 { lines.append(ModifierLine(value: -be, source: L("source.belastung"))) }

        if hero.schmerzPenalty != 0 {
            let level = hero.effectiveSchmerzLevel
            lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
        }

        if golgaritenForced || vorteilhaftePosition {
            lines.append(ModifierLine(value: 2, source: L("source.vorteilhaft")))
        }

        if golgaritenForced {
            lines.append(ModifierLine(value: 2, source: L("source.golgariten")))
        }

        if plaenklerActive && plaenklerBonus == .at {
            lines.append(ModifierLine(value: 1, source: L("source.plaenkler")))
        }

        // Weapon reach
        let heroReach = WeaponReach(rawValue: hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
        let reachPenalty = heroReach.atPenaltyAgainst(selectedOpponentReach)
        if reachPenalty != 0 {
            lines.append(ModifierLine(value: reachPenalty, source: L("source.reach")))
        }

        if selectedManeuver.atModifier != 0 {
            lines.append(ModifierLine(value: selectedManeuver.atModifier, source: selectedManeuver.sourceLabel))
        }

        if dualAttackPenaltyActive {
            let penalty = hero.dualAttackPenalty
            if penalty != 0 { lines.append(ModifierLine(value: penalty, source: L("source.dualAttack"))) }
        }

        if isOffHand && hero.offHandPenalty != 0 {
            lines.append(ModifierLine(value: hero.offHandPenalty, source: L("source.offHand")))
        }

        return lines
    }

    private func adjustedDamage() -> String? {
        guard var formula = damageFormula else { return nil }
        var bonus = selectedManeuver.damageBonus
        if twoHandedGripActive { bonus += 1 }
        if selectedManeuver == .sturmangriff { bonus += hero.sturmangriffDamageBonus }
        if bonus == 0 { return formula }
        let pattern = /^(\d+W\d+)([+-]\d+)?$/
        guard let match = formula.firstMatch(of: pattern) else { return formula }
        let base = String(match.1)
        let existing = match.2.flatMap { Int($0) } ?? 0
        let total = existing + bonus
        if total == 0 { return base }
        formula = total > 0 ? "\(base)+\(total)" : "\(base)\(total)"
        return formula
    }
}

// MARK: - CombatWeaponSelectionView

struct CombatWeaponSelectionView: View {
    let action: CombatAction
    let hero: Hero
    @Binding var step: CombatStep
    let dualAttackPenaltyActive: Bool
    let twoHandedGripActive: Bool
    var onDismiss: () -> Void

    private var headerLabel: String {
        switch action {
        case .angriff: return L("attack")
        case .parieren: return L("selectParryWeapon")
        case .ausweichen: return L("dodge")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = dualAttackPenaltyActive && action == .angriff ? .attackChoice : .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(headerLabel)
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    let statLabel = action == .angriff ? "AT" : "PA"
                    let dualPenalty = dualAttackPenaltyActive ? hero.dualAttackPenalty : 0

                    // Main weapon option
                    if let w = hero.selectedWeapon {
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? w.at : (w.pa + hero.passiveShieldPABonus)
                        let val = baseVal + dualPenalty + (action == .parieren && twoHandedGripActive ? -1 : 0)
                        weaponRow(
                            name: w.name,
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? w.damage : nil,
                            note: nil,
                            isOffHand: false
                        )
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        combatSectionLabel("\(L("mainWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? (raufen?.at ?? 0) : ((raufen?.pa ?? 0) + hero.passiveShieldPABonus)
                        let val = baseVal + dualPenalty
                        weaponRow(
                            name: "Raufen",
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? "1W6" : nil,
                            note: nil,
                            isOffHand: false
                        )
                    }

                    // Off-hand weapon (dual-wield)
                    if let offW = hero.selectedOffHandWeapon {
                        combatSectionLabel("\(L("offHandWeapon")) (\(statLabel))")
                        let baseVal = action == .angriff ? offW.at : offW.pa
                        let val = baseVal + dualPenalty + hero.offHandPenalty
                        weaponRow(
                            name: offW.name,
                            statLabel: statLabel,
                            statValue: val,
                            damageFormula: action == .angriff ? offW.damage : nil,
                            note: hero.offHandPenalty != 0 ? "\(L("offHandPenalty")): \(hero.offHandPenalty)" : nil,
                            isOffHand: true
                        )
                    }

                    // Shield option
                    if let s = hero.selectedShield {
                        combatSectionLabel("\(L("shieldOption")) (\(statLabel))")
                        let val = action == .angriff ? s.at : s.pa
                        weaponRow(
                            name: s.name,
                            statLabel: statLabel,
                            statValue: val,
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

    private func weaponRow(name: String, statLabel: String, statValue: Int, damageFormula: String?, note: String?, isOffHand: Bool) -> some View {
        Button {
            if dualAttackPenaltyActive && action == .angriff {
                // Determine the other weapon for the second attack
                let otherWeapon: MeleeWeapon? = isOffHand ? hero.selectedWeapon : hero.selectedOffHandWeapon
                let otherName = otherWeapon?.name ?? "?"
                let otherBaseAT = otherWeapon?.at ?? 0
                let otherOffHandPenalty = isOffHand ? 0 : hero.offHandPenalty
                let otherAT = otherBaseAT + hero.dualAttackPenalty + otherOffHandPenalty
                let otherDmg = otherWeapon?.damage

                step = .announcement(
                    .angriff,
                    name: name,
                    baseAT: statValue,
                    damageFormula: damageFormula,
                    isOffHand: isOffHand,
                    secondAttack: (name: otherName, at: otherAT, damage: otherDmg),
                    isMountCharge: false
                )
            } else if action == .angriff {
                step = .announcement(.angriff, name: name, baseAT: statValue, damageFormula: damageFormula, isOffHand: isOffHand, secondAttack: nil, isMountCharge: false)
            } else {
                step = .execution(action, name: name, attributeValue: statValue, damageFormula: nil, note: action == .parieren ? note : nil)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let note, !note.isEmpty {
                        Text(note)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(statLabel) \(statValue)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.dsaDark)
                    if hero.belastungPenalty != 0 {
                        Text("(\(hero.belastungPenalty))")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}
