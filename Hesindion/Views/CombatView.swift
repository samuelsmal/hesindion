import SwiftUI
import SwiftData

// MARK: - Local types

enum CombatAction {
    case angriff, parieren, ausweichen, fernkampf
}

enum CombatStep {
    case combatSetup
    case initiativeRoll
    case loadoutEquipment           // merged from loadoutWeapon + loadoutShield
    case root
    case attackChoice               // pre-attack: one/both weapons, one/two-handed
    case weaponSelection(CombatAction)
    case announcement(CombatAction, name: String, baseAT: Int, damageFormula: String?, isOffHand: Bool, secondAttack: (name: String, at: Int, damage: String?)?, isMountCharge: Bool)
    /// `damageFormula` is the weapon's **own** damage and `damageLines` the TP
    /// bonuses on top of it, carried apart all the way to the roll so the damage
    /// screen can print every part. Folding them into the string here is what
    /// made the manoeuvre bonus unaccountable — and, twice, double-counted.
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?, modifierLines: [ModifierLine]? = nil, secondAttack: (name: String, at: Int, damage: String?)? = nil, damageLines: [ModifierLine] = [], damageMultiplier: CriticalDamage = .unchanged, opponentDefenseModifiers: [ModifierLine] = [])
    case dualAttackSecond(name: String, attributeValue: Int, damageFormula: String?)
    indirect case mountPreCheck(onSuccess: CombatStep)
    case mountDamage
    case takeDamage
    case flucht
    case opponentDefense(weaponName: String, damageFormula: String?, isCriticalHit: Bool, criticalDamage: CriticalDamage, modifierLines: [ModifierLine]?, isRangedAttack: Bool = false, rangedDefensePenalty: Int = 0, damageLines: [ModifierLine] = [], damageMultiplier: CriticalDamage = .unchanged, opponentDefenseModifiers: [ModifierLine] = [], criticalDamageSource: String? = nil)
    case fumbleChoice(action: CombatAction, weaponName: String, isShieldParry: Bool)
    /// The optional "Kritische Erfolge" table (ADR-0011). `table: nil` means the
    /// screen has to ask which defence this was — the app knows the hero parried,
    /// not whether the incoming attack was melee or ranged.
    case criticalSuccess(table: CriticalSuccessTableType?, action: CombatAction, weaponName: String, damageFormula: String?, modifierLines: [ModifierLine]?, isRangedAttack: Bool = false, rangedDefensePenalty: Int = 0, damageLines: [ModifierLine] = [], damageMultiplier: CriticalDamage = .unchanged, opponentDefenseModifiers: [ModifierLine] = [])
    case passierschlag
    case fernkampfSetup
    case fernkampfExecution(weaponName: String, attributeValue: Int, damageFormula: String, distanzTP: Int, modifierLines: [ModifierLine])
    case spellSelection
    case spellSetup(spell: HeroSpell)
    case spellCasting(spell: HeroSpell, startRound: Int, totalRounds: Int, modifierLines: [ModifierLine])
    case spellExecution(spell: HeroSpell, modifierLines: [ModifierLine])
}

extension CombatStep {
    /// Stable key for onChange observation (associated values stripped).
    var persistenceKey: String {
        switch self {
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
        case .criticalSuccess: "criticalSuccess"
        case .passierschlag: "passierschlag"
        case .fernkampfSetup: "fernkampfSetup"
        case .fernkampfExecution: "fernkampfExecution"
        case .spellSelection: "spellSelection"
        case .spellSetup: "spellSetup"
        case .spellCasting: "spellCasting"
        case .spellExecution: "spellExecution"
        }
    }

    /// Whether an already announced Trefferzone survives into this step.
    ///
    /// Default-deny on purpose: the zone is carried only by the steps that *resolve*
    /// the attack it was announced for. Every other step — a new `attackChoice`, the
    /// off-hand `dualAttackSecond`, a `mountPreCheck`, a Passierschlag, a return to
    /// `root` — starts an action that announced nothing, and must not inherit the
    /// previous swing's zone (which would let the player pay the Zonenaufschlag once
    /// and collect the wound effect twice). A future attack path therefore has to opt
    /// *in* to carrying a zone rather than remember to clear it.
    var preservesAnnouncedZone: Bool {
        switch self {
        case .execution, .fernkampfExecution, .criticalSuccess, .opponentDefense: true
        default: false
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
            .font(.dsaHeading(.caption))
            .foregroundStyle(combatAccent)
            .fixedSize()
        Rectangle()
            .frame(height: 2)
            .foregroundStyle(combatAccent)
    }
    .padding(.vertical, 8)
}

/// The bar every combat screen wears: back on the left, the screen's name in
/// the middle, and the way out of the whole flow on the right.
///
/// Written out once per screen before this, which is how three of them ended up
/// with no back button at all.
func combatScreenHeader(
    title: String,
    subtitle: String? = nil,
    onBack: (() -> Void)? = nil,
    onDismiss: @escaping () -> Void
) -> some View {
    HStack {
        if let onBack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("combat.back")
        }

        Spacer()

        VStack(spacing: 1) {
            Text(title)
                .font(.dsaHeading(.headline))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }

        Spacer()

        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.dsaBody(.body))
                .foregroundStyle(.white)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.close")
    }
    .padding(.horizontal, DSALayout.horizontalPadding)
    .padding(.vertical, DSALayout.headerVerticalPadding)
    .frame(maxWidth: .infinity)
    .background(combatAccent)
    .dsaBox(.raised)
}

// MARK: - CombatView (full-screen orchestrator)

struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var activePanel: SidePanel?
    @State private var step: CombatStep = .combatSetup
    @State private var combatId = UUID()
    @State private var rolledInitiative: Int? = nil
    @State private var dualAttackPenaltyActive: Bool = false
    @State private var twoHandedGripActive: Bool = false
    @State private var roundNumber: Int = 1
    @State private var plaenklerActive: Bool = false
    @State private var plaenklerBonus: PlaenklerBonus = .at
    @State private var mountedActive: Bool = false
    /// The other side of the fight. Held here, not on the announcement screen,
    /// because the same opponent is still the same opponent in round four — the
    /// reach used to be asked for again on every single attack.
    @State private var opponent = OpponentProfile()
    @State private var vorstossActiveThisRound: Bool = false
    /// Beengte Umgebung is now backed by the `eingeengt` player status (single source of
    /// truth), so it shows as a chip in the states strip and persists via SwiftData like
    /// every other state. Reads `hero.hasState("eingeengt")`; the binding writes through
    /// `hero.setStateLevel`. The old `activeCombatBeengt` session field is no longer used.
    private var beengteUmgebungActive: Bool { hero.hasState("eingeengt") }
    private var beengteUmgebungBinding: Binding<Bool> {
        Binding(
            get: { hero.hasState("eingeengt") },
            set: { hero.setStateLevel("eingeengt", level: $0 ? 1 : 0) }
        )
    }
    @State private var activeManeuver: CombatManeuver = .normal
    /// Parries and dodges are counted apart: Mehrfache Verteidigung applies per
    /// defence type, so a round's first dodge is unmodified however often the
    /// hero has already parried.
    @State private var parriesThisRound: Int = 0
    @State private var dodgesThisRound: Int = 0
    @State private var schipDefenseBoostActive: Bool = false
    @State private var schipIgnoreZustandThisRound: Bool = false
    /// Trefferzone announced for the attack currently in flight. The app has no opponent
    /// model to apply the wound effect to, so this only carries the zone from the
    /// announcement/setup step to the post-hit damage screen for the read-only reminder card.
    @State private var announcedZone: HitZone? = nil

    /// The round's flags as one value, for the screens that roll a defence.
    private var situation: CombatSituation {
        CombatSituation(
            mounted: mountedActive,
            schipIgnoreZustand: schipIgnoreZustandThisRound,
            dualAttackActive: dualAttackPenaltyActive,
            beengteUmgebung: beengteUmgebungActive,
            twoHandedGrip: twoHandedGripActive,
            parriesThisRound: parriesThisRound,
            dodgesThisRound: dodgesThisRound,
            schipDefenseBoost: schipDefenseBoostActive,
            plaenklerActive: plaenklerActive,
            plaenklerBonus: plaenklerBonus
        )
    }

    private var stepID: String {
        switch step {
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
        case .criticalSuccess: "criticalSuccess"
        case .passierschlag: "passierschlag"
        case .fernkampfSetup: "fernkampfSetup"
        case .fernkampfExecution: "fernkampfExecution"
        case .flucht: "flucht"
        case .spellSelection: "spellSelection"
        case .spellSetup: "spellSetup"
        case .spellCasting: "spellCasting"
        case .spellExecution: "spellExecution"
        }
    }

    var body: some View {
        SplitContentLayout(hero: hero, activePanel: $activePanel) {
        VStack(spacing: 0) {
            switch step {
            case .combatSetup:
                CombatSetupView(
                    hero: hero,
                    step: $step,
                    plaenklerActive: $plaenklerActive,
                    plaenklerBonus: $plaenklerBonus,
                    mountedActive: $mountedActive,
                    beengteUmgebungActive: beengteUmgebungBinding,
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
                    beengteUmgebungActive: beengteUmgebungBinding,
                    parriesThisRound: $parriesThisRound,
                    dodgesThisRound: $dodgesThisRound,
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
                    situation: situation,
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
                    announcedZone: $announcedZone,
                    dualAttackPenaltyActive: dualAttackPenaltyActive,
                    twoHandedGripActive: twoHandedGripActive,
                    plaenklerActive: plaenklerActive,
                    plaenklerBonus: plaenklerBonus,
                    opponent: $opponent,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .execution(let action, let name, let attrValue, let dmgFormula, let note, let modifierLines, let secondAttack, let damageLines, let damageMultiplier, let opponentDefenseModifiers):
                CombatExecutionView(
                    hero: hero,
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: note,
                    modifierLines: modifierLines,
                    damageLines: damageLines,
                    damageMultiplier: damageMultiplier,
                    opponentDefenseModifiers: opponentDefenseModifiers,
                    secondAttackStep: secondAttack.map { .dualAttackSecond(name: $0.name, attributeValue: $0.at, damageFormula: $0.damage) },
                    combatId: combatId,
                    roundNumber: roundNumber,
                    beengteUmgebungActive: beengteUmgebungActive,
                    step: $step,
                    onDefenseAttempted: {
                        if action == .ausweichen { dodgesThisRound += 1 } else { parriesThisRound += 1 }
                    },
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
            case .opponentDefense(let name, let dmg, let isCrit, let criticalDamage, let mods, let isRanged, let rangedPenalty, let damageLines, let damageMultiplier, let opponentDefenseModifiers, let criticalDamageSource):
                CombatOpponentDefenseView(
                    hero: hero,
                    weaponName: name,
                    damageFormula: dmg,
                    isCriticalHit: isCrit,
                    criticalDamage: criticalDamage,
                    modifierLines: mods,
                    damageLines: damageLines,
                    opponentDefenseModifiers: opponentDefenseModifiers,
                    damageMultiplier: damageMultiplier,
                    criticalDamageSource: criticalDamageSource,
                    isRangedAttack: isRanged,
                    rangedDefensePenalty: rangedPenalty,
                    announcedZone: announcedZone,
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
            case .criticalSuccess(let table, let action, let name, let dmg, let mods, let isRanged, let rangedPenalty, let damageLines, let damageMultiplier, let opponentDefenseModifiers):
                CombatCriticalSuccessView(
                    hero: hero,
                    requestedTable: table,
                    action: action,
                    weaponName: name,
                    damageFormula: dmg,
                    modifierLines: mods,
                    damageLines: damageLines,
                    damageMultiplier: damageMultiplier,
                    opponentDefenseModifiers: opponentDefenseModifiers,
                    isRangedAttack: isRanged,
                    rangedDefensePenalty: rangedPenalty,
                    step: $step,
                    onDismiss: onDismiss,
                    combatId: combatId,
                    roundNumber: roundNumber
                )
                .transition(.move(edge: .trailing))
            case .passierschlag:
                CombatPassierschlagView(
                    hero: hero,
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
                CombatFernkampfSetupView(
                    hero: hero,
                    step: $step,
                    mountedActive: mountedActive,
                    beengteUmgebungActive: beengteUmgebungActive,
                    schipIgnoreZustandThisRound: schipIgnoreZustandThisRound,
                    announcedZone: $announcedZone,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            case .fernkampfExecution(let name, let attrValue, let dmg, let distTP, let mods):
                CombatFernkampfExecutionView(
                    hero: hero,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmg,
                    distanzTP: distTP,
                    modifierLines: mods,
                    step: $step,
                    onDismiss: onDismiss,
                    combatId: combatId,
                    roundNumber: roundNumber
                )
                .transition(.move(edge: .trailing))
            case .spellSelection:
                CombatSpellSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .spellSetup(let spell):
                CombatSpellSetupView(hero: hero, spell: spell, step: $step, roundNumber: roundNumber, mountedActive: mountedActive, schipIgnoreZustandThisRound: schipIgnoreZustandThisRound, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .spellCasting(let spell, let startRound, let totalRounds, let modifierLines):
                CombatRootView(
                    hero: hero,
                    step: $step,
                    rolledInitiative: $rolledInitiative,
                    roundNumber: $roundNumber,
                    dualAttackPenaltyActive: $dualAttackPenaltyActive,
                    twoHandedGripActive: $twoHandedGripActive,
                    vorstossActiveThisRound: $vorstossActiveThisRound,
                    beengteUmgebungActive: beengteUmgebungBinding,
                    parriesThisRound: $parriesThisRound,
                    dodgesThisRound: $dodgesThisRound,
                    schipDefenseBoostActive: $schipDefenseBoostActive,
                    schipIgnoreZustandThisRound: $schipIgnoreZustandThisRound,
                    mountedActive: mountedActive,
                    plaenklerActive: plaenklerActive,
                    plaenklerBonus: plaenklerBonus,
                    onDismiss: onDismiss,
                    castingSpell: (spell: spell, startRound: startRound, totalRounds: totalRounds, modifierLines: modifierLines)
                )
            case .spellExecution(let spell, let modifierLines):
                CombatSpellExecutionView(hero: hero, spell: spell, modifierLines: modifierLines, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(DSAAnimation.standard, value: stepID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .gesture(DragGesture().onEnded { v in
            if v.translation.height > 80 {
                switch step {
                case .combatSetup:
                    onDismiss()
                case .initiativeRoll:
                    step = .combatSetup
                case .loadoutEquipment:
                    step = .root
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
                case .criticalSuccess:
                    step = .root
                case .passierschlag:
                    step = .root
                case .fernkampfSetup:
                    step = .root
                case .fernkampfExecution:
                    step = .fernkampfSetup
                case .spellSelection:
                    step = .root
                case .spellSetup:
                    step = .spellSelection
                case .spellExecution:
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
            parriesThisRound = 0
            dodgesThisRound = 0
            schipDefenseBoostActive = false
            schipIgnoreZustandThisRound = false
            announcedZone = nil
            persistCombatState()
        }
        .onChange(of: step.persistenceKey) { _, newKey in
            if !step.preservesAnnouncedZone {
                announcedZone = nil
            }
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
                // Beengte Umgebung restores automatically via the `eingeengt` status (SwiftData).
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
        // Beengte Umgebung is the `eingeengt` status now and persists itself; no field to write.
    }
}
