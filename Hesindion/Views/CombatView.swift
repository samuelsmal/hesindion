import SwiftUI
import SwiftData

// MARK: - Local types

enum CombatAction {
    case angriff, parieren, ausweichen
}

enum CombatStep {
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
    case mountDamage
    case takeDamage
    case flucht
    case opponentDefense(weaponName: String, damageFormula: String?, isCriticalHit: Bool, isDoubleDamage: Bool, modifierLines: [ModifierLine]?)
    case fumbleChoice(action: CombatAction, weaponName: String, isShieldParry: Bool)
    case fernkampfSetup
    case fernkampfExecution(weaponName: String, attributeValue: Int, damageFormula: String, distanzTP: Int, modifierLines: [ModifierLine])
}

extension CombatStep {
    /// Stable key for onChange observation (associated values stripped).
    var persistenceKey: String {
        switch self {
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
        case .flucht: "flucht"
        case .mountDamage: "mountDamage"
        case .takeDamage: "takeDamage"
        case .opponentDefense: "opponentDefense"
        case .fumbleChoice: "fumbleChoice"
        case .fernkampfSetup: "fernkampfSetup"
        case .fernkampfExecution: "fernkampfExecution"
        }
    }
}

let combatAccent = Color.groupCombat

func combatSectionLabel(_ title: String) -> some View {
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
    @Environment(\.modelContext) private var modelContext
    @State private var activePanel: SidePanel?
    @State private var step: CombatStep = .armorSelection
    @State private var combatId = UUID()
    @State private var rolledInitiative: Int? = nil
    @State private var dualAttackPenaltyActive: Bool = false
    @State private var twoHandedGripActive: Bool = false
    @State private var roundNumber: Int = 1
    @State private var plaenklerActive: Bool = false
    @State private var plaenklerBonus: PlaenklerBonus = .at
    @State private var mountedActive: Bool = false
    @State private var vorstossActiveThisRound: Bool = false
    @State private var beengteUmgebungActive: Bool = false
    @State private var activeManeuver: CombatManeuver = .normal
    @State private var defenseCountThisRound: Int = 0
    @State private var schipDefenseBoostActive: Bool = false
    @State private var schipIgnoreZustandThisRound: Bool = false

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
        case .mountDamage: "mountDamage"
        case .takeDamage: "takeDamage"
        case .opponentDefense: "opponentDefense"
        case .fumbleChoice: "fumbleChoice"
        case .fernkampfSetup: "fernkampfSetup"
        case .fernkampfExecution: "fernkampfExecution"
        case .flucht: "flucht"
        }
    }

    var body: some View {
        SplitContentLayout(hero: hero, activePanel: $activePanel) {
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
                    beengteUmgebungActive: $beengteUmgebungActive,
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
                    beengteUmgebungActive: $beengteUmgebungActive,
                    defenseCountThisRound: $defenseCountThisRound,
                    schipDefenseBoostActive: $schipDefenseBoostActive,
                    schipIgnoreZustandThisRound: $schipIgnoreZustandThisRound,
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
                    beengteUmgebungActive: beengteUmgebungActive,
                    schipIgnoreZustandThisRound: schipIgnoreZustandThisRound,
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
                    hero: hero,
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: note,
                    modifierLines: modifierLines,
                    secondAttackStep: secondAttack.map { .dualAttackSecond(name: $0.name, attributeValue: $0.at, damageFormula: $0.damage) },
                    combatId: combatId,
                    roundNumber: roundNumber,
                    beengteUmgebungActive: beengteUmgebungActive,
                    step: $step,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .dualAttackSecond(let name, let attrValue, let dmgFormula):
                CombatExecutionView(
                    hero: hero,
                    action: .angriff,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: L("dualAttackPenalty"),
                    modifierLines: nil,
                    secondAttackStep: nil,
                    combatId: combatId,
                    roundNumber: roundNumber,
                    beengteUmgebungActive: beengteUmgebungActive,
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
            case .mountDamage:
                if let mount = hero.pets.first {
                    CombatMountDamageView(
                        hero: hero,
                        mount: mount,
                        step: $step,
                        onDismiss: onDismiss,
                        combatId: combatId,
                        roundNumber: roundNumber
                    )
                    .transition(.move(edge: .trailing))
                }
            case .takeDamage:
                CombatTakeDamageView(hero: hero, step: $step, onDismiss: onDismiss, combatId: combatId, roundNumber: roundNumber)
                    .transition(.move(edge: .trailing))
            case .opponentDefense(let name, let dmg, let isCrit, let isDouble, let mods):
                CombatOpponentDefenseView(
                    hero: hero,
                    weaponName: name,
                    damageFormula: dmg,
                    isCriticalHit: isCrit,
                    isDoubleDamage: isDouble,
                    modifierLines: mods,
                    step: $step,
                    onDismiss: onDismiss,
                    combatId: combatId,
                    roundNumber: roundNumber
                )
                .transition(.move(edge: .trailing))
            case .fumbleChoice(let action, let name, let isShield):
                CombatFumbleChoiceView(
                    hero: hero,
                    action: action,
                    weaponName: name,
                    isShieldParry: isShield,
                    step: $step,
                    onDismiss: onDismiss,
                    combatId: combatId,
                    roundNumber: roundNumber
                )
                .transition(.move(edge: .trailing))
            case .flucht:
                CombatFluchtView(
                    hero: hero,
                    step: $step,
                    onDismiss: onDismiss,
                    combatId: combatId,
                    roundNumber: roundNumber
                )
                .transition(.move(edge: .trailing))
            case .fernkampfSetup:
                Color.clear // Task 12
            case .fernkampfExecution:
                Color.clear // Task 13
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
                case .mountDamage:
                    step = .root
                case .takeDamage:
                    step = .root
                case .opponentDefense:
                    step = .root
                case .fumbleChoice:
                    step = .root
                case .fernkampfSetup:
                    step = .root
                case .fernkampfExecution:
                    step = .fernkampfSetup
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
            defenseCountThisRound = 0
            schipDefenseBoostActive = false
            schipIgnoreZustandThisRound = false
            persistCombatState()
        }
        .onChange(of: step.persistenceKey) { _, newKey in
            if newKey == "root" {
                persistCombatState()
            }
        }
        .onAppear {
            if let existingId = hero.activeCombatId {
                combatId = existingId
                roundNumber = hero.activeCombatRound
                rolledInitiative = hero.activeCombatInitiative
                plaenklerActive = hero.activeCombatPlaenkler
                if let bonus = hero.activeCombatPlaenklerBonus {
                    plaenklerBonus = bonus == "at" ? .at : .aw
                }
                mountedActive = hero.activeCombatMounted
                beengteUmgebungActive = hero.activeCombatBeengt
                step = .root
            }
        }
        } // SplitContentLayout
    }

    private func persistCombatState() {
        hero.activeCombatId = combatId
        hero.activeCombatRound = roundNumber
        hero.activeCombatInitiative = rolledInitiative
        hero.activeCombatPlaenkler = plaenklerActive
        hero.activeCombatPlaenklerBonus = plaenklerBonus == .at ? "at" : "aw"
        hero.activeCombatMounted = mountedActive
        hero.activeCombatBeengt = beengteUmgebungActive
    }
}
