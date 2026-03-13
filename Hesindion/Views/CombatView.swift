import SwiftUI

// MARK: - Local types

private enum CombatAction {
    case angriff, parieren, ausweichen
}

private enum CombatStep {
    case armorSelection
    case combatSetup
    case initiativeRoll
    case loadoutEquipment           // merged from loadoutWeapon + loadoutShield
    case root
    case attackChoice               // pre-attack: one/both weapons, one/two-handed
    case weaponSelection(CombatAction)
    case announcement(CombatAction, name: String, baseAT: Int, damageFormula: String?, isOffHand: Bool, secondAttack: (name: String, at: Int, damage: String?)?, isMountCharge: Bool)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?, modifierLines: [ModifierLine]? = nil, secondAttack: (name: String, at: Int, damage: String?)? = nil)
    case dualAttackSecond(name: String, attributeValue: Int, damageFormula: String?)
    indirect case mountPreCheck(onSuccess: CombatStep)
    case takeDamage
}

private let combatAccent = Color.groupCombat

private func combatSectionLabel(_ title: String) -> some View {
    HStack(spacing: 8) {
        Rectangle()
            .frame(height: 2)
            .foregroundStyle(combatAccent)
        Text(title)
            .font(.system(.caption, weight: .black))
            .foregroundStyle(combatAccent)
            .fixedSize()
        Rectangle()
            .frame(height: 2)
            .foregroundStyle(combatAccent)
    }
    .padding(.vertical, 8)
}

// MARK: - CombatView (full-screen orchestrator)

struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showNotes = false
    @State private var step: CombatStep = .armorSelection
    @State private var rolledInitiative: Int? = nil
    @State private var dualAttackPenaltyActive: Bool = false
    @State private var twoHandedGripActive: Bool = false
    @State private var roundNumber: Int = 1
    @State private var plaenklerActive: Bool = false
    @State private var plaenklerBonus: PlaenklerBonus = .at
    @State private var mountedActive: Bool = false
    @State private var vorstossActiveThisRound: Bool = false
    @State private var activeManeuver: CombatManeuver = .normal

    private var stepID: String {
        switch step {
        case .armorSelection: "armorSelection"
        case .combatSetup: "combatSetup"
        case .initiativeRoll: "initiativeRoll"
        case .loadoutEquipment: "loadoutEquipment"
        case .root: "root"
        case .attackChoice: "attackChoice"
        case .weaponSelection: "weaponSelection"
        case .announcement: "announcement"
        case .execution: "execution"
        case .dualAttackSecond: "dualAttackSecond"
        case .mountPreCheck: "mountPreCheck"
        case .takeDamage: "takeDamage"
        }
    }

    var body: some View {
        ContentWithNotesLayout(hero: hero, showNotes: $showNotes) {
        VStack(spacing: 0) {
            switch step {
            case .armorSelection:
                CombatArmorSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .leading))
            case .combatSetup:
                CombatSetupView(
                    hero: hero,
                    step: $step,
                    plaenklerActive: $plaenklerActive,
                    plaenklerBonus: $plaenklerBonus,
                    mountedActive: $mountedActive,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .initiativeRoll:
                CombatInitiativeRollView(
                    hero: hero,
                    step: $step,
                    rolledInitiative: $rolledInitiative,
                    mountedActive: mountedActive,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .loadoutEquipment:
                CombatLoadoutEquipmentView(hero: hero, step: $step, mountedActive: mountedActive, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .root:
                CombatRootView(
                    hero: hero,
                    step: $step,
                    rolledInitiative: $rolledInitiative,
                    roundNumber: $roundNumber,
                    dualAttackPenaltyActive: $dualAttackPenaltyActive,
                    twoHandedGripActive: $twoHandedGripActive,
                    vorstossActiveThisRound: $vorstossActiveThisRound,
                    mountedActive: mountedActive,
                    plaenklerActive: plaenklerActive,
                    plaenklerBonus: plaenklerBonus,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .leading))
            case .attackChoice:
                CombatAttackChoiceView(
                    hero: hero,
                    step: $step,
                    dualAttackPenaltyActive: $dualAttackPenaltyActive,
                    twoHandedGripActive: $twoHandedGripActive,
                    mountedActive: mountedActive,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .weaponSelection(let action):
                CombatWeaponSelectionView(
                    action: action,
                    hero: hero,
                    step: $step,
                    dualAttackPenaltyActive: dualAttackPenaltyActive,
                    twoHandedGripActive: twoHandedGripActive,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .announcement(let action, let name, let baseAT, let dmgFormula, let isOffHand, let secondAttack, let isMountCharge):
                CombatAnnouncementView(
                    hero: hero,
                    action: action,
                    weaponName: name,
                    baseAT: baseAT,
                    damageFormula: dmgFormula,
                    isOffHand: isOffHand,
                    mountedActive: mountedActive,
                    isMountCharge: isMountCharge,
                    secondAttack: secondAttack,
                    step: $step,
                    activeManeuver: $activeManeuver,
                    vorstossActiveThisRound: $vorstossActiveThisRound,
                    dualAttackPenaltyActive: dualAttackPenaltyActive,
                    twoHandedGripActive: twoHandedGripActive,
                    plaenklerActive: plaenklerActive,
                    plaenklerBonus: plaenklerBonus,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .execution(let action, let name, let attrValue, let dmgFormula, let note, let modifierLines, let secondAttack):
                CombatExecutionView(
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: note,
                    modifierLines: modifierLines,
                    secondAttackStep: secondAttack.map { .dualAttackSecond(name: $0.name, attributeValue: $0.at, damageFormula: $0.damage) },
                    step: $step,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .dualAttackSecond(let name, let attrValue, let dmgFormula):
                CombatExecutionView(
                    action: .angriff,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: L("dualAttackPenalty"),
                    modifierLines: nil,
                    secondAttackStep: nil,
                    step: $step,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .mountPreCheck(let onSuccess):
                CombatMountPreCheckView(
                    hero: hero,
                    onSuccess: onSuccess,
                    step: $step,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .takeDamage:
                CombatTakeDamageView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(DSAAnimation.standard, value: stepID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .gesture(DragGesture().onEnded { v in
            if v.translation.height > 80 {
                switch step {
                case .armorSelection:
                    onDismiss()
                case .combatSetup:
                    step = .armorSelection
                case .initiativeRoll:
                    step = hero.needsCombatSetup ? .combatSetup : .armorSelection
                case .loadoutEquipment:
                    step = .initiativeRoll
                case .root:
                    onDismiss()
                case .attackChoice:
                    step = .root
                case .announcement(let action, _, _, _, _, _, _):
                    step = .weaponSelection(action)
                case .mountPreCheck:
                    step = .attackChoice
                case .takeDamage:
                    step = .root
                default:
                    step = .root
                }
            }
        })
        .onChange(of: roundNumber) { _, _ in
            dualAttackPenaltyActive = false
            twoHandedGripActive = false
            vorstossActiveThisRound = false
            activeManeuver = .normal
        }
        .overlay(alignment: .topTrailing) {
            if sizeClass == .regular {
                Button {
                    withAnimation(DSAAnimation.standard) {
                        showNotes.toggle()
                    }
                } label: {
                    Image(systemName: "note.text")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(showNotes ? combatAccent : .white)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 48)
                .padding(.top, 15)
            }
        }
        } // ContentWithNotesLayout
    }
}

// MARK: - CombatAnnouncementView

private struct CombatAnnouncementView: View {
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

// MARK: - CombatSetupView

private struct CombatSetupView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var plaenklerActive: Bool
    @Binding var plaenklerBonus: PlaenklerBonus
    @Binding var mountedActive: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .armorSelection } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("combatSetup"))
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
                    // Plänkler-Formation
                    if hero.hasPlaenklerFormation {
                        combatSectionLabel(L("formation.label"))

                        Button { plaenklerActive.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: plaenklerActive ? "checkmark.square.fill" : "square")
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(plaenklerActive ? combatAccent : .secondary)
                                Text(L("plaenkler"))
                                    .font(.system(.body, weight: plaenklerActive ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(plaenklerActive ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(plaenklerActive ? combatAccent : Color.dsaBorder, lineWidth: plaenklerActive ? 3 : 2))
                        }
                        .buttonStyle(.plain)

                        if plaenklerActive {
                            HStack(spacing: 8) {
                                ForEach(PlaenklerBonus.allCases, id: \.self) { bonus in
                                    let isSelected = plaenklerBonus == bonus
                                    Button { plaenklerBonus = bonus } label: {
                                        Text(bonus == .at ? L("plaenklerAT") : L("plaenklerAW"))
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
                            .padding(.top, 4)
                        }
                    }

                    // Mount toggle
                    if hero.hasMount {
                        combatSectionLabel(L("mount.label"))

                        let mountName = hero.pets.first?.name ?? L("mount")
                        Button { mountedActive.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mountedActive ? "checkmark.square.fill" : "square")
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(mountedActive ? combatAccent : .secondary)
                                Text("\(L("mounted")) (\(mountName))")
                                    .font(.system(.body, weight: mountedActive ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(mountedActive ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(mountedActive ? combatAccent : Color.dsaBorder, lineWidth: mountedActive ? 3 : 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }

            // Continue
            Button { step = .initiativeRoll } label: {
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
    }
}

// MARK: - CombatArmorSelectionView

private struct CombatArmorSelectionView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("armorSelection"))
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

            if hero.armors.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "shield.slash")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.secondary)
                    Text(L("noArmor"))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(hero.armors, id: \.persistentModelID) { armor in
                            armorRow(armor)
                        }
                    }
                    .adaptiveContentWidth()
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }

            // Summary bar
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text(L("rs"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.totalRS)")
                        .font(.system(.body, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    Text(L("encumbrance"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.effectiveBE)")
                        .font(.system(.body, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dsaDark)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

            // Continue button
            Button { step = hero.needsCombatSetup ? .combatSetup : .initiativeRoll } label: {
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
    }

    private func armorRow(_ armor: Armor) -> some View {
        Button {
            armor.isEquipped.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: armor.isEquipped ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(armor.isEquipped ? combatAccent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(armor.name)
                        .font(.system(.body, weight: armor.isEquipped ? .bold : .regular))
                        .foregroundStyle(.primary)
                    Text("\(L("rs")) \(armor.protectionValue)  \(L("encumbrance")) \(armor.encumbrance)")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CombatLoadoutEquipmentView

private struct CombatLoadoutEquipmentView: View {
    let hero: Hero
    @Binding var step: CombatStep
    let mountedActive: Bool
    var onDismiss: () -> Void

    /// Tracks selected item names (max 2).
    @State private var selected: Set<String> = []

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
    }

    /// All selectable items: weapons, shields, and Raufen.
    private var allItems: [(name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)] {
        var items: [(String, String, String?, Bool, Bool, Bool)] = []
        for w in hero.meleeWeapons {
            let twoHandedTechniques = ["CT_7", "CT_14"] // Zweihandschwerter, Stangenwaffen
            let isTwoHanded = twoHandedTechniques.contains(w.combatTechniqueId)
            let mountedNote: String? = (mountedActive && isTwoHanded) ? "(\(L("mounted")))" : nil
            items.append((w.name, "AT \(w.at) / PA \(w.pa)", mountedNote, false, false, isTwoHanded))
        }
        for s in hero.shields {
            items.append((s.name, "AT \(s.at) / PA \(s.pa)", s.note.isEmpty ? nil : s.note, true, false, false))
        }
        items.append(("Raufen", "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)", nil, false, true, false))
        return items
    }

    private func canSelect(_ item: (name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)) -> Bool {
        if selected.contains(item.name) { return true } // can always deselect
        if mountedActive && item.isTwoHandedOnly { return false } // two-handed weapons not usable when mounted
        if item.isRaufen { return selected.isEmpty } // Raufen = both hands free
        if item.isTwoHandedOnly { return selected.isEmpty } // two-handed weapon needs both hands
        if selected.count >= 2 { return false }
        if selected.count == 1 {
            let currentItem = allItems.first { selected.contains($0.name) }
            if currentItem?.isRaufen == true { return false }
            if currentItem?.isTwoHandedOnly == true { return false }
            // Can't pick two shields
            if item.isShield && currentItem?.isShield == true { return false }
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .initiativeRoll } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L("selectEquipment"))
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
                    if !hero.meleeWeapons.isEmpty {
                        combatSectionLabel(L("meleeWeapons.label"))
                        ForEach(allItems.filter({ !$0.isShield && !$0.isRaufen }), id: \.name) { item in
                            equipmentRow(item)
                        }
                    }

                    if !hero.shields.isEmpty {
                        combatSectionLabel(L("shields.label"))
                        ForEach(allItems.filter(\.isShield), id: \.name) { item in
                            equipmentRow(item)
                        }
                    }

                    combatSectionLabel(L("unarmed.label"))
                    ForEach(allItems.filter(\.isRaufen), id: \.name) { item in
                        equipmentRow(item)
                    }
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }

            // Continue button
            Button {
                applySelection()
                step = .root
            } label: {
                Text(L("continue"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selected.isEmpty ? Color.gray : combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
        }
        .onAppear { loadCurrentSelection() }
    }

    private func equipmentRow(_ item: (name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)) -> some View {
        let isSelected = selected.contains(item.name)
        let enabled = canSelect(item)
        return Button {
            if isSelected {
                selected.remove(item.name)
            } else {
                if item.isRaufen || item.isTwoHandedOnly {
                    selected.removeAll()
                }
                selected.insert(item.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(isSelected ? combatAccent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(.body, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(enabled ? .primary : .tertiary)
                    Text(item.detail)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(enabled ? .secondary : .tertiary)
                    if let note = item.note {
                        Text(note)
                            .font(.system(.caption2))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(isSelected ? combatAccent : Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.bottom, 4)
    }

    private func loadCurrentSelection() {
        selected.removeAll()
        if let name = hero.selectedWeaponName { selected.insert(name) }
        if let name = hero.selectedOffHandName { selected.insert(name) }
        // Legacy: also check selectedShieldName
        if let name = hero.selectedShieldName, !selected.contains(name) { selected.insert(name) }
    }

    private func applySelection() {
        let items = allItems
        let selectedItems = items.filter { selected.contains($0.name) }

        // Determine main weapon and off-hand
        let mainWeapon = selectedItems.first { !$0.isShield && !$0.isRaufen } ?? selectedItems.first { $0.isRaufen }
        let offHand = selectedItems.first { $0.name != mainWeapon?.name }

        hero.selectedWeaponName = mainWeapon?.name
        hero.selectedOffHandName = offHand?.name
        // Keep selectedShieldName in sync for backwards compat
        hero.selectedShieldName = offHand?.isShield == true ? offHand?.name : nil
    }
}

// MARK: - CombatAttackChoiceView

private struct CombatAttackChoiceView: View {
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

// MARK: - CombatInitiativeRollView

private struct CombatInitiativeRollView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var rolledInitiative: Int?
    let mountedActive: Bool
    var onDismiss: () -> Void

    @State private var selectedBase: Int? = nil
    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var animTask: Task<Void, Never>? = nil

    private var heroBaseINI: Int {
        (hero.derivedValues?.initiative.value ?? 0) + hero.totalIniPenalty
    }

    private var mountBaseINI: Int? {
        hero.pets.first.flatMap { pet in
            Int(pet.initiative.split(separator: "+").first ?? "")
        }
    }

    private var mountName: String? {
        hero.pets.first?.name
    }

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return base + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = hero.needsCombatSetup ? .combatSetup : .armorSelection } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L("newInitiative"))
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

            VStack(spacing: 0) {
                // Base selector
                combatSectionLabel(L("basis.label"))

                HStack(spacing: 8) {
                    baseButton(label: L("hero"), value: heroBaseINI)
                    if let mINI = mountBaseINI {
                        baseButton(label: mountName ?? L("mount"), value: mINI)
                    }
                }

                // Dice + result
                if let base = selectedBase {
                    VStack(spacing: 8) {
                        // D6 box
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.system(.largeTitle, weight: .black))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text(L("tapToRoll"))
                                        .font(.system(.caption2, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            .contentShape(Rectangle())
                            .onTapGesture { tapDice() }
                            Text("W6")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // Calculation box
                        Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                            .font(.system(.title3, weight: .black))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                            .opacity(d6Result == nil ? 0.4 : 1)

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                rolledInitiative = t
                                if hero.selectedWeaponName != nil {
                                    step = .root
                                } else {
                                    step = .loadoutEquipment
                                }
                            } label: {
                                Text("\(L("confirm"))  \u{2192}  INI \(t)")
                                    .font(.system(.body, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
            .adaptiveContentWidth()
            .padding(.bottom, 16)
        }
        .onAppear {
            if mountedActive, let mINI = mountBaseINI {
                selectedBase = mINI
                startD6Animation()
            }
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(label: String, value: Int) -> some View {
        let isSelected = selectedBase == value
        return Button {
            selectedBase = value
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, weight: .bold))
                Text("\(value)")
                    .font(.system(.title3, weight: .black))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private func tapDice() {
        if d6Result == nil && animTask != nil {
            animTask?.cancel()
            d6Result = Int.random(in: 1...6)
        }
    }

    private func startD6Animation() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            var count = 0
            while !Task.isCancelled && count < 12 {
                d6Display = Int.random(in: 1...6)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            d6Result = Int.random(in: 1...6)
        }
    }
}

// MARK: - CombatRootView

private struct CombatRootView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var rolledInitiative: Int?
    @Binding var roundNumber: Int
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    @Binding var vorstossActiveThisRound: Bool
    let mountedActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    var onDismiss: () -> Void

    @State private var showInitiativeSheet = false
    @State private var showArmorSheet = false

    private func buildDefenseModifiers(isAusweichen: Bool) -> [ModifierLine] {
        var lines: [ModifierLine] = []

        let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
        if be > 0 { lines.append(ModifierLine(value: -be, source: L("source.belastung"))) }

        if hero.schmerzPenalty != 0 {
            let level = hero.effectiveSchmerzLevel
            lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
        }

        // Golgariten PA bonus (parry only, not dodge)
        if !isAusweichen && hero.golgaritenActive(mounted: mountedActive) {
            lines.append(ModifierLine(value: 1, source: L("source.golgariten")))
        }

        // Plänkler AW bonus (dodge only)
        if isAusweichen && plaenklerActive && plaenklerBonus == .aw {
            lines.append(ModifierLine(value: 1, source: L("source.plaenkler")))
        }

        // Mounted dodge penalty
        if isAusweichen && mountedActive {
            lines.append(ModifierLine(value: -2, source: L("source.mounted")))
        }

        // Dual-attack penalty
        if dualAttackPenaltyActive {
            let penalty = hero.dualAttackPenalty
            if penalty != 0 { lines.append(ModifierLine(value: penalty, source: L("source.dualAttack"))) }
        }

        return lines
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("combat"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text(hero.name)
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
            // INITIATIVE section
            combatSectionLabel(L("initiative.label"))

            // INI + round counter + Neu button
            HStack(spacing: 0) {
                // INI box
                VStack(spacing: 2) {
                    Text("INI")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(rolledInitiative ?? hero.derivedValues?.initiative.value ?? 0)")
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .frame(width: 64)
                .background(Color.dsaDark)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                // Round counter
                Text("\(L("roundPrefix")) \(roundNumber)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                // Next round button
                Button { roundNumber += 1 } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52)
                        .frame(maxHeight: .infinity)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                // Neuer Kampf compact button
                Button { showInitiativeSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                            .font(.system(.caption, weight: .bold))
                        Text(L("new"))
                            .font(.system(.caption, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
            .sheet(isPresented: $showInitiativeSheet) {
                CombatInitiativeSheet(
                    heroBaseINI: (hero.derivedValues?.initiative.value ?? 0) + hero.totalIniPenalty,
                    mountBaseINI: hero.pets.first.flatMap { pet in
                        Int(pet.initiative.split(separator: "+").first ?? "")
                    },
                    mountName: hero.pets.first?.name
                ) { result in
                    rolledInitiative = result
                    roundNumber = 1
                    showInitiativeSheet = false
                }
                .presentationCornerRadius(0)
            }

            if hero.derivedValues != nil {
                // LEBENSPUNKTE section
                combatSectionLabel(L("lifePoints.label"))
                lpBar

                if mountedActive, let mount = hero.pets.first {
                    LPBarView(
                        current: mount.currentLifeEnergy,
                        max: mount.lifeEnergy,
                        accent: Color(red: 0x0d / 255, green: 0x96 / 255, blue: 0x88 / 255)
                    ) {
                        guard mount.currentLifeEnergy > 0 else { return }
                        mount.currentLifeEnergy -= 1
                    } onIncrement: {
                        guard mount.currentLifeEnergy < mount.lifeEnergy else { return }
                        mount.currentLifeEnergy += 1
                    }

                    Text(mount.name)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Schmerz indicator
                if hero.effectiveSchmerzLevel > 0 {
                    let level = hero.effectiveSchmerzLevel
                    let label = level >= 4 ? L("schmerz.IV") : L("schmerz.\(String(repeating: "I", count: level))")
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(.caption, weight: .bold))
                        Text("\(label) (\(hero.schmerzPenalty))")
                            .font(.system(.caption, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.groupCombat)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Armor management button
                Button { showArmorSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(.caption, weight: .bold))
                        Text("\(L("rs")) \(hero.totalRS)")
                            .font(.system(.caption, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .sheet(isPresented: $showArmorSheet) {
                    CombatArmorManagementSheet(hero: hero)
                        .presentationCornerRadius(0)
                }
            }

            // Loadout display
            if let weaponName = hero.selectedWeaponName {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(.caption, weight: .bold))
                    Text(weaponName)
                        .font(.system(.caption, design: .monospaced, weight: .black))
                    if let offHandName = hero.selectedOffHandName {
                        Text("+")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.secondary)
                        let isShield = hero.selectedShield != nil
                        Image(systemName: isShield ? "shield.fill" : "hammer.fill")
                            .font(.system(.caption, weight: .bold))
                        Text(offHandName)
                            .font(.system(.caption, design: .monospaced, weight: .black))
                    }
                    Spacer()
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 8)
            }

            // AKTION section
            combatSectionLabel(L("action.label"))

            VStack(spacing: 8) {
                // Angriff -- primary (filled)
                Button {
                    let isDualWield = hero.isDualWielding
                    let hasShield = hero.selectedShield != nil
                    let canTwoHand: Bool = {
                        guard !isDualWield, !hasShield else { return false }
                        guard let w = hero.selectedWeapon else { return false }
                        let excluded = ["CT_1", "CT_3"]
                        return !excluded.contains(w.combatTechniqueId)
                    }()

                    if isDualWield || canTwoHand || mountedActive {
                        step = .attackChoice
                    } else if hasShield {
                        step = .weaponSelection(.angriff)
                    } else if let w = hero.selectedWeapon {
                        step = .announcement(.angriff, name: w.name, baseAT: w.at, damageFormula: w.damage, isOffHand: false, secondAttack: nil, isMountCharge: false)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        step = .announcement(.angriff, name: "Raufen", baseAT: raufen?.at ?? 0, damageFormula: "1W6", isOffHand: false, secondAttack: nil, isMountCharge: false)
                    } else {
                        step = .loadoutEquipment
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(L("attack"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)

                // Parieren -- secondary (outline)
                Button {
                    let isDualWield = hero.isDualWielding
                    if isDualWield || hero.selectedShield != nil {
                        step = .weaponSelection(.parieren)
                    } else if let w = hero.selectedWeapon {
                        let mods = buildDefenseModifiers(isAusweichen: false)
                        let basePA = w.pa + hero.passiveShieldPABonus + (twoHandedGripActive ? -1 : 0)
                        let effectivePA = basePA + mods.reduce(0) { $0 + $1.value }
                        step = .execution(.parieren, name: w.name, attributeValue: effectivePA, damageFormula: nil, note: nil, modifierLines: mods)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        let mods = buildDefenseModifiers(isAusweichen: false)
                        let basePA = raufen?.pa ?? 0
                        let effectivePA = basePA + mods.reduce(0) { $0 + $1.value }
                        step = .execution(.parieren, name: "Raufen", attributeValue: effectivePA, damageFormula: nil, note: nil, modifierLines: mods)
                    } else {
                        step = .weaponSelection(.parieren)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                        Text(L("parry"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(vorstossActiveThisRound ? .white : combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vorstossActiveThisRound ? Color.gray : Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(vorstossActiveThisRound ? Color.gray : combatAccent, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .disabled(vorstossActiveThisRound)

                // Ausweichen -- tertiary (outline)
                Button {
                    let mods = buildDefenseModifiers(isAusweichen: true)
                    let baseAW = hero.derivedValues?.ausweichen.value ?? 0
                    let effectiveAW = baseAW + mods.reduce(0) { $0 + $1.value }
                    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: effectiveAW, damageFormula: nil, note: nil, modifierLines: mods)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text(L("dodge"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(vorstossActiveThisRound ? .white : combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vorstossActiveThisRound ? Color.gray : Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(vorstossActiveThisRound ? Color.gray : combatAccent, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .disabled(vorstossActiveThisRound)

                // Vorstoß warning
                if vorstossActiveThisRound {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(.caption2, weight: .bold))
                        Text(L("noDefenseWarning"))
                            .font(.system(.caption2, weight: .bold))
                    }
                    .foregroundStyle(combatAccent)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                // Schaden nehmen -- dark
                Button { step = .takeDamage } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.slash.fill")
                        Text(L("takeDamage"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)

                // Change loadout -- visually distinct (teal)
                Button { step = .loadoutEquipment } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(.body, weight: .bold))
                        Text(L("changeLoadout"))
                            .font(.system(.body, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0x0d / 255, green: 0x96 / 255, blue: 0x88 / 255)) // teal
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }

            } // inner VStack
            .adaptiveContentWidth()
            } // ScrollView
        }
    }

    @ViewBuilder
    private var lpBar: some View {
        if let dv = hero.derivedValues {
            LPBarView(
                current: dv.lebensenergie.current,
                max: dv.lebensenergie.max
            ) {
                guard dv.lebensenergie.current > 0 else { return }
                dv.lebensenergie.current -= 1
            } onIncrement: {
                guard dv.lebensenergie.current < dv.lebensenergie.max else { return }
                dv.lebensenergie.current += 1
            }
        }
    }

}

// MARK: - CombatArmorManagementSheet

private struct CombatArmorManagementSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("armorSelection"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
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

            if hero.armors.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "shield.slash")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.secondary)
                    Text(L("noArmor"))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(hero.armors, id: \.persistentModelID) { armor in
                            armorRow(armor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }

            // Summary bar
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text(L("rs"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.totalRS)")
                        .font(.system(.body, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    Text(L("encumbrance"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.effectiveBE)")
                        .font(.system(.body, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dsaDark)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
    }

    private func armorRow(_ armor: Armor) -> some View {
        Button {
            armor.isEquipped.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: armor.isEquipped ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(armor.isEquipped ? combatAccent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(armor.name)
                        .font(.system(.body, weight: armor.isEquipped ? .bold : .regular))
                        .foregroundStyle(.primary)
                    Text("\(L("rs")) \(armor.protectionValue)  \(L("encumbrance")) \(armor.encumbrance)")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CombatTakeDamageView

private struct CombatTakeDamageView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var tpInput: Int = 0
    @State private var confirmed: Bool = false

    private var rs: Int { hero.totalRS }
    private var effectiveDamage: Int { max(0, tpInput - rs) }

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

                Text(L("takeDamage"))
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

            VStack(spacing: 16) {
                // TP input stepper
                combatSectionLabel(L("tp"))

                HStack(spacing: 0) {
                    Button {
                        if tpInput > 0 { tpInput -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.gray : combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed || tpInput <= 0)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Text("\(tpInput)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(minWidth: 80)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button {
                        tpInput += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.gray : combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .fixedSize(horizontal: false, vertical: true)

                // Calculation display
                VStack(spacing: 4) {
                    Text("\(tpInput) \(L("tp")) \u{2212} \(rs) \(L("rs")) = \(effectiveDamage)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                    if effectiveDamage == 0 {
                        Text(L("absorbed"))
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(effectiveDamage) \(L("lpLost"))")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                if !confirmed {
                    // Confirm button
                    Button {
                        if let dv = hero.derivedValues {
                            dv.lebensenergie.current = max(0, dv.lebensenergie.current - effectiveDamage)
                        }
                        confirmed = true
                    } label: {
                        Text(L("confirm"))
                            .font(.system(.title3, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Neue Aktion button
                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .adaptiveContentWidth()

            Spacer()
        }
    }
}

// MARK: - CombatWeaponSelectionView

private struct CombatWeaponSelectionView: View {
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

// MARK: - CombatExecutionView

private struct CombatExecutionView: View {
    let action: CombatAction
    let weaponName: String
    let attributeValue: Int
    let damageFormula: String?
    let note: String?
    let modifierLines: [ModifierLine]?
    let secondAttackStep: CombatStep?
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var modifier: Int = 0
    @State private var displayRoll: Int = 1
    @State private var finalRoll: Int? = nil
    @State private var confirmRoll: Int? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var confirmAnimTask: Task<Void, Never>? = nil

    // Damage rolling state
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil

    private var attrLabel: String {
        switch action {
        case .angriff:   "AT"
        case .parieren:  "PA"
        case .ausweichen: "AW"
        }
    }

    private var actionLabel: String {
        switch action {
        case .angriff:   "Angriff"
        case .parieren:  "Parieren"
        case .ausweichen: "Ausweichen"
        }
    }

    private var effectiveValue: Int { attributeValue + modifier }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = action == .ausweichen ? .root : .weaponSelection(action)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(actionLabel)
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

            VStack(spacing: 8) {
                // Row 1: modifier breakdown or simple value
                modifierBreakdown

                // Manual modifier stepper (ZUSÄTZLICH)
                modifierBox

                // Maneuver reminder note
                if let note, !note.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(.caption2, weight: .bold))
                        Text(note)
                            .font(.system(.caption2, weight: .bold))
                    }
                    .foregroundStyle(combatAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(combatAccent.opacity(0.1))
                    .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
                }

                // Row 3: Dice box
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                // Row 3: Confirm (only for 1/20 rolls)
                if let fr = finalRoll, needsConfirm(fr) {
                    confirmBox
                }

                if let outcome = computedOutcome {
                    outcomeBar(outcome)

                    if isHit(outcome), let formula = damageFormula, let parsed = parseDamage(formula) {
                        damageSection(parsed: parsed)
                    }
                }

            if showNeueAktion {
                if let secondStep = secondAttackStep, computedOutcome != .kritischerPatzer {
                    // Second dual-wield attack
                    Button { step = secondStep } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text(L("dualAttack") + " 2")
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                } else if secondAttackStep != nil && computedOutcome == .kritischerPatzer {
                    // Fumble -- second attack lost
                    Text(L("fumbleSecondLost"))
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.dsaDark)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            }
            .adaptiveContentWidth()
            .padding(.vertical, 16)

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear {
            animationTask?.cancel()
            confirmAnimTask?.cancel()
            damageAnimTask?.cancel()
        }
    }

    // MARK: - Box helpers

    private func valueBox(_ text: String, label: String? = nil, dark: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .foregroundStyle(dark ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(dark ? Color.dsaDark : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            if let label {
                Text(label)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var modifierBox: some View {
        let locked = finalRoll != nil
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    modifier -= 1
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(minWidth: 64)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Button {
                    modifier += 1
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            Text(L("modifier"))
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Modifier breakdown

    /// The raw base value (weapon AT/PA/AW) before any situation modifiers are applied.
    /// attributeValue already includes the lines sum, so subtract it back to recover the base.
    private var baseValue: Int {
        let linesSum = modifierLines?.reduce(0) { $0 + $1.value } ?? 0
        return attributeValue - linesSum
    }

    @ViewBuilder
    private var modifierBreakdown: some View {
        if let lines = modifierLines, !lines.isEmpty {
            VStack(spacing: 0) {
                combatSectionLabel(L("calculation.label"))

                // Base value row
                HStack {
                    Text("\(attrLabel) \(baseValue)")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                    Spacer()
                    Text(L("source.basis"))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))

                // Modifier lines
                ForEach(lines) { line in
                    HStack {
                        Text(line.value > 0 ? "+\(line.value)" : "\(line.value)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(line.value > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : Color.groupCombat)
                        Spacer()
                        Text(line.source)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }

                // Manual modifier row (only when non-zero)
                if modifier != 0 {
                    HStack {
                        Text(modifier > 0 ? "+\(modifier)" : "\(modifier)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(modifier > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : Color.groupCombat)
                        Spacer()
                        Text(L("source.additional"))
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }

                // Effective total row
                HStack {
                    Text("\(attrLabel) \(effectiveValue)")
                        .font(.system(.body, design: .monospaced, weight: .black))
                    Spacer()
                    Text("Effektiv")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dsaDark)
                .foregroundStyle(.white)
            }
        } else {
            // Fallback: simple display (for defense/dodge without full breakdown)
            valueBox("\(attributeValue)", label: attrLabel)
        }
    }

    private var diceBox: some View {
        let isAnimating = finalRoll == nil
        let display = finalRoll ?? displayRoll
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(display)")
                    .font(.system(.largeTitle, weight: .black))
                    .fontDesign(.monospaced)
                if isAnimating {
                    Text(L("tapToRoll"))
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            Text("W20")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var confirmBox: some View {
        let isAnimating = confirmRoll == nil
        let display: String = {
            if let cr = confirmRoll { return "\(cr)" }
            return "\(displayRoll)"
        }()
        return VStack(spacing: 0) {
            Text(display)
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            Text(L("confirmation"))
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Outcome

    private enum CombatOutcome {
        case kritischerErfolg, kritischerPatzer, erfolg, misserfolg
    }

    private var computedOutcome: CombatOutcome? {
        guard let fr = finalRoll else { return nil }
        if needsConfirm(fr) {
            guard let cr = confirmRoll else { return nil }
            if fr == 1 {
                return cr <= effectiveValue ? .kritischerErfolg : .erfolg
            } else {
                return cr > effectiveValue ? .kritischerPatzer : .misserfolg
            }
        }
        return fr <= effectiveValue ? .erfolg : .misserfolg
    }

    private func needsConfirm(_ roll: Int) -> Bool { roll == 1 || roll == 20 }

    private func outcomeBar(_ outcome: CombatOutcome) -> some View {
        let isCritical = outcome == .kritischerErfolg || outcome == .kritischerPatzer
        return Text(outcomeText(outcome))
            .font(.system(isCritical ? .title3 : .body, weight: .bold))
            .foregroundStyle(outcomeTextColor(outcome))
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCritical ? 14 : 10)
            .background(outcomeBackground(outcome))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    private func outcomeText(_ outcome: CombatOutcome) -> String {
        switch outcome {
        case .kritischerErfolg: return L("criticalSuccess")
        case .kritischerPatzer: return L("criticalFumble")
        case .erfolg:           return L("success")
        case .misserfolg:       return L("failure")
        }
    }

    private func outcomeBackground(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return Color(red: 0x00 / 255.0, green: 0xc8 / 255.0, blue: 0x53 / 255.0)
        case .kritischerPatzer: return .groupCombat
        case .erfolg:           return Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
        case .misserfolg:       return .dsaDark
        }
    }

    private func outcomeTextColor(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return .primary
        default:                return .white
        }
    }

    // MARK: - Animation & rolling

    private func startAnimation() {
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                displayRoll = Int.random(in: 1...20)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { break }
            }
        }
    }

    private var showNeueAktion: Bool {
        guard computedOutcome != nil else { return false }
        guard let outcome = computedOutcome, isHit(outcome), damageFormula != nil else { return computedOutcome != nil }
        return damageFinalRolls != nil
    }

    private func rollDice() {
        guard finalRoll == nil else { return }
        animationTask?.cancel()
        let rolled = Int.random(in: 1...20)
        finalRoll = rolled
        if needsConfirm(rolled) { startConfirmAnimation() }
    }

    private func startConfirmAnimation() {
        confirmAnimTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
            var count = 0
            while !Task.isCancelled && count < 10 {
                displayRoll = Int.random(in: 1...20)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            confirmRoll = Int.random(in: 1...20)
        }
    }

    // MARK: - Damage

    private struct ParsedDamage {
        let count: Int
        let sides: Int
        let bonus: Int
    }

    private func parseDamage(_ formula: String) -> ParsedDamage? {
        // Matches formats like "1W6", "2W6+4", "1W6-1"
        let pattern = /(\d+)W(\d+)([+-]\d+)?/
        guard let match = formula.firstMatch(of: pattern) else { return nil }
        let count = Int(match.1) ?? 1
        let sides = Int(match.2) ?? 6
        let bonus = match.3.flatMap { Int($0) } ?? 0
        return ParsedDamage(count: count, sides: sides, bonus: bonus)
    }

    private func isHit(_ outcome: CombatOutcome) -> Bool {
        outcome == .erfolg || outcome == .kritischerErfolg
    }

    private func damageSection(parsed: ParsedDamage) -> some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("damage.label"))

            let isAnimating = damageFinalRolls == nil
            let rolls = damageFinalRolls ?? damageDisplayRolls

            // Individual dice
            HStack(spacing: 6) {
                ForEach(0..<parsed.count, id: \.self) { i in
                    Text(i < rolls.count ? "\(rolls[i])" : "-")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
            }

            // Formula + total
            if let finalRolls = damageFinalRolls {
                let diceSum = finalRolls.reduce(0, +)
                let total = max(0, diceSum + parsed.bonus)
                let bonusStr = parsed.bonus > 0 ? "+\(parsed.bonus)" : parsed.bonus < 0 ? "\(parsed.bonus)" : ""

                Text("\(diceSum)\(bonusStr) = \(total) TP")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    .padding(.top, 6)
            }

            if isAnimating {
                Text(L("tapToRoll"))
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { rollDamage(parsed: parsed) }
        .onAppear { startDamageAnimation(parsed: parsed) }
    }

    private func startDamageAnimation(parsed: ParsedDamage) {
        damageAnimTask?.cancel()
        damageAnimTask = Task { @MainActor in
            while !Task.isCancelled {
                damageDisplayRolls = (0..<parsed.count).map { _ in Int.random(in: 1...parsed.sides) }
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { break }
            }
        }
    }

    private func rollDamage(parsed: ParsedDamage) {
        guard damageFinalRolls == nil else { return }
        damageAnimTask?.cancel()
        damageFinalRolls = (0..<parsed.count).map { _ in Int.random(in: 1...parsed.sides) }
    }
}

// MARK: - CombatInitiativeSheet

private struct CombatInitiativeSheet: View {
    let heroBaseINI: Int
    let mountBaseINI: Int?
    let mountName: String?
    var onConfirm: (Int) -> Void

    @State private var selectedBase: Int? = nil
    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var animTask: Task<Void, Never>? = nil

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return base + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L("newInitiative"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(combatAccent)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 0) {
                // Base selector
                combatSectionLabel(L("basis.label"))

                HStack(spacing: 8) {
                    baseButton(label: L("hero"), value: heroBaseINI)
                    if let mountINI = mountBaseINI {
                        baseButton(label: mountName ?? L("mount"), value: mountINI)
                    }
                }
                .padding(.horizontal, 16)

                // Dice + result
                if let base = selectedBase {
                    VStack(spacing: 8) {
                        // D6 box
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.system(.largeTitle, weight: .black))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text(L("rolling"))
                                        .font(.system(.caption2, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            Text("W6")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // Calculation box
                        Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                            .font(.system(.title3, weight: .black))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                            .opacity(d6Result == nil ? 0.4 : 1)

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                onConfirm(t)
                            } label: {
                                Text("\(L("confirmIni")) \(t)")
                                    .font(.system(.body, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(label: String, value: Int) -> some View {
        let isSelected = selectedBase == value
        return Button {
            selectedBase = value
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, weight: .bold))
                Text("\(value)")
                    .font(.system(.title3, weight: .black))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private func startD6Animation() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            var count = 0
            while !Task.isCancelled && count < 12 {
                d6Display = Int.random(in: 1...6)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            d6Result = Int.random(in: 1...6)
        }
    }
}

// MARK: - CombatMountPreCheckView

private struct CombatMountPreCheckView: View {
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
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("reitenCheck"))
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

            Spacer()

            VStack {
                if !galoppConfirmed {
                    galoppCheck
                } else {
                    reitenCheck
                }
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

    private var galoppCheck: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.equestrian.sports")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(L("galoppConfirm"))
                .font(.system(.title3, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
                } label: {
                    Text(L("no"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(DSAAnimation.standard) {
                        galoppConfirmed = true
                    }
                } label: {
                    Text(L("yes"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
    }

    private var reitenCheck: some View {
        VStack(spacing: 16) {
            if let talent = reitenTalent {
                if let succeeded = probeSucceeded {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

                    Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    Button {
                        if succeeded {
                            step = onSuccess
                        } else {
                            step = .attackChoice
                        }
                    } label: {
                        Text(succeeded ? L("continue") : L("back"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(succeeded ? combatAccent : Color.dsaDark)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(combatAccent)

                    Text(L("reitenCheck"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    Button {
                        showingProbeModal = true
                    } label: {
                        Text(L("rollReitenCheck"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(combatAccent)

                Text(L("reitenCheckPrompt"))
                    .font(.system(.title3, weight: .bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        step = .attackChoice
                    } label: {
                        Text(L("no"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Button {
                        step = onSuccess
                    } label: {
                        Text(L("yes"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
