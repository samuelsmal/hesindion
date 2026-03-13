import SwiftUI

// MARK: - Local types

private enum CombatAction {
    case angriff, parieren, ausweichen
}

private enum CombatStep {
    case armorSelection
    case initiativeRoll
    case loadoutEquipment           // merged from loadoutWeapon + loadoutShield
    case root
    case attackChoice               // pre-attack: one/both weapons, one/two-handed
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?, secondAttack: (name: String, at: Int, damage: String?)? = nil)
    case dualAttackSecond(name: String, attributeValue: Int, damageFormula: String?)
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
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}

// MARK: - CombatView (full-screen orchestrator)

struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @State private var step: CombatStep = .armorSelection
    @State private var rolledInitiative: Int? = nil
    @State private var dualAttackPenaltyActive: Bool = false
    @State private var twoHandedGripActive: Bool = false
    @State private var roundNumber: Int = 1

    private var stepID: String {
        switch step {
        case .armorSelection: "armorSelection"
        case .initiativeRoll: "initiativeRoll"
        case .loadoutEquipment: "loadoutEquipment"
        case .root: "root"
        case .attackChoice: "attackChoice"
        case .weaponSelection: "weaponSelection"
        case .execution: "execution"
        case .dualAttackSecond: "dualAttackSecond"
        case .takeDamage: "takeDamage"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .armorSelection:
                CombatArmorSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .leading))
            case .initiativeRoll:
                CombatInitiativeRollView(hero: hero, step: $step, rolledInitiative: $rolledInitiative, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .loadoutEquipment:
                CombatLoadoutEquipmentView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .root:
                CombatRootView(
                    hero: hero,
                    step: $step,
                    rolledInitiative: $rolledInitiative,
                    roundNumber: $roundNumber,
                    dualAttackPenaltyActive: $dualAttackPenaltyActive,
                    twoHandedGripActive: $twoHandedGripActive,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .leading))
            case .attackChoice:
                CombatAttackChoiceView(
                    hero: hero,
                    step: $step,
                    dualAttackPenaltyActive: $dualAttackPenaltyActive,
                    twoHandedGripActive: $twoHandedGripActive,
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
            case .execution(let action, let name, let attrValue, let dmgFormula, let note, let secondAttack):
                CombatExecutionView(
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
                    note: note,
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
                    secondAttackStep: nil,
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
                case .initiativeRoll:
                    step = .armorSelection
                case .loadoutEquipment:
                    step = .initiativeRoll
                case .root:
                    onDismiss()
                case .attackChoice:
                    step = .root
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

            // Continue button
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
            items.append((w.name, "AT \(w.at) / PA \(w.pa)", nil, false, false, isTwoHanded))
        }
        for s in hero.shields {
            items.append((s.name, "AT \(s.at) / PA \(s.pa)", s.note.isEmpty ? nil : s.note, true, false, false))
        }
        items.append(("Raufen", "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)", nil, false, true, false))
        return items
    }

    private func canSelect(_ item: (name: String, detail: String, note: String?, isShield: Bool, isRaufen: Bool, isTwoHandedOnly: Bool)) -> Bool {
        if selected.contains(item.name) { return true } // can always deselect
        if item.isRaufen { return selected.isEmpty } // Raufen = both hands free
        if item.isTwoHandedOnly { return selected.isEmpty } // two-handed weapon needs both hands
        if selected.count >= 2 { return false }
        if selected.count == 1 {
            let currentItem = allItems.first { selected.contains($0.name) }
            if currentItem?.isRaufen == true { return false }
            if currentItem?.isTwoHandedOnly == true { return false }
            // Can't pick two weapons without Beidhaendig
            if !item.isShield && currentItem?.isShield == false && !hero.hasBeidhaendig { return false }
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
                .padding(.horizontal, 16)
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
                    } else {
                        // Shouldn't reach here, but handle gracefully
                        Color.clear.onAppear { proceedSingleAttack() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            Spacer()
        }
    }

    // MARK: - Dual-wield options

    private var dualWieldOptions: some View {
        VStack(spacing: 8) {
            combatSectionLabel(L("attack"))

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
            combatSectionLabel(L("attack"))

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
            step = .execution(.angriff, name: w.name, attributeValue: w.at, damageFormula: damage, note: nil)
        } else if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            step = .execution(.angriff, name: "Raufen", attributeValue: raufen?.at ?? 0, damageFormula: "1W6", note: nil)
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
                Button { step = .armorSelection } label: {
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
    var onDismiss: () -> Void

    @State private var showInitiativeSheet = false
    @State private var showArmorSheet = false

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
            .padding(.horizontal, 16)
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
                .padding(.horizontal, 16)
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
                .padding(.horizontal, 16)
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

                    if isDualWield || canTwoHand {
                        step = .attackChoice
                    } else if hasShield {
                        step = .weaponSelection(.angriff)
                    } else if let w = hero.selectedWeapon {
                        step = .execution(.angriff, name: w.name, attributeValue: w.at, damageFormula: w.damage, note: nil)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        step = .execution(.angriff, name: "Raufen", attributeValue: raufen?.at ?? 0, damageFormula: "1W6", note: nil)
                    } else {
                        step = .attackChoice
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
                        let paValue = w.pa + hero.passiveShieldPABonus + (twoHandedGripActive ? -1 : 0) + (dualAttackPenaltyActive ? hero.dualAttackPenalty : 0)
                        step = .execution(.parieren, name: w.name, attributeValue: paValue, damageFormula: nil, note: nil)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        let paValue = (raufen?.pa ?? 0) + (dualAttackPenaltyActive ? hero.dualAttackPenalty : 0)
                        step = .execution(.parieren, name: "Raufen", attributeValue: paValue, damageFormula: nil, note: nil)
                    } else {
                        step = .weaponSelection(.parieren)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                        Text(L("parry"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                }
                .buttonStyle(.plain)

                // Ausweichen -- tertiary (outline)
                Button {
                    let aw = hero.derivedValues?.ausweichen.value ?? 0
                    let penalty = dualAttackPenaltyActive ? hero.dualAttackPenalty : 0
                    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw + penalty, damageFormula: nil, note: nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text(L("dodge"))
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                }
                .buttonStyle(.plain)

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
            .padding(.horizontal, 16)

            Spacer()
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
            .padding(.horizontal, 16)
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
                .padding(.horizontal, 16)

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
                .padding(.horizontal, 16)

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
                    .padding(.horizontal, 16)
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
                    .padding(.horizontal, 16)
                }
            }

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
                .padding(.horizontal, 16)
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

                step = .execution(
                    .angriff,
                    name: name,
                    attributeValue: statValue,
                    damageFormula: damageFormula,
                    note: L("dualAttackPenalty"),
                    secondAttack: (name: otherName, at: otherAT, damage: otherDmg)
                )
            } else {
                step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil, note: action == .parieren ? note : nil)
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
    let secondAttackStep: CombatStep?
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var modifier: Int = 0
    @State private var vorteilhaftePosition: Bool = false
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

    private var effectiveValue: Int { attributeValue + modifier + (vorteilhaftePosition ? 2 : 0) }

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
                // Row 1: AT/PA/AW value
                valueBox("\(attributeValue)", label: attrLabel)

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(combatAccent)
                        .padding(.top, 2)
                }

                // Row 2: Modifier
                modifierBox

                // Vorteilhafte Position toggle
                Button {
                    guard finalRoll == nil else { return }
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
                .disabled(finalRoll != nil)

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
            }
            .padding(16)

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
                    .padding(.horizontal, 16)
                } else if secondAttackStep != nil && computedOutcome == .kritischerPatzer {
                    // Fumble -- second attack lost
                    Text(L("fumbleSecondLost"))
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.dsaDark)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        .padding(.horizontal, 16)

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
                    .padding(.horizontal, 16)
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
                    .padding(.horizontal, 16)
                }
            }

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
        case .kritischerErfolg: return "!!! Kritischer Erfolg!"
        case .kritischerPatzer: return "!!! Kritischer Patzer!"
        case .erfolg:           return "Erfolg"
        case .misserfolg:       return "Misserfolg"
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
