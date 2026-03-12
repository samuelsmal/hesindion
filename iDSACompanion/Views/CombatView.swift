import SwiftUI

// MARK: - Local types

private enum CombatAction {
    case angriff, parieren, ausweichen
}

private enum CombatStep {
    case armorSelection
    case initiativeRoll
    case loadoutWeapon
    case loadoutShield
    case root
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int, damageFormula: String?, note: String?)
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

    private var stepID: String {
        switch step {
        case .armorSelection: "armorSelection"
        case .initiativeRoll: "initiativeRoll"
        case .loadoutWeapon: "loadoutWeapon"
        case .loadoutShield: "loadoutShield"
        case .root: "root"
        case .weaponSelection: "weaponSelection"
        case .execution: "execution"
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
            case .loadoutWeapon:
                CombatLoadoutWeaponView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .loadoutShield:
                Text("Loadout Shield placeholder")
                    .transition(.move(edge: .trailing))
            case .root:
                CombatRootView(hero: hero, step: $step, rolledInitiative: $rolledInitiative, onDismiss: onDismiss)
                    .transition(.move(edge: .leading))
            case .weaponSelection(let action):
                CombatWeaponSelectionView(action: action, hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .execution(let action, let name, let attrValue, let dmgFormula, let note):
                CombatExecutionView(
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    damageFormula: dmgFormula,
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
                case .loadoutWeapon:
                    step = .initiativeRoll
                case .loadoutShield:
                    step = .loadoutWeapon
                case .root:
                    onDismiss()
                case .takeDamage:
                    step = .root
                default:
                    step = .root
                }
            }
        })
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

// MARK: - CombatLoadoutWeaponView

private struct CombatLoadoutWeaponView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
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

                Text(L("selectWeapon"))
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
                        combatSectionLabel("NAHKAMPFWAFFEN")
                        ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                            loadoutRow(name: w.name, detail: "AT \(w.at) / PA \(w.pa)", isSelected: hero.selectedWeaponName == w.name) {
                                hero.selectedWeaponName = w.name
                                advanceToShieldOrRoot()
                            }
                        }
                    }

                    combatSectionLabel(L("unarmed.label"))
                    loadoutRow(name: "Raufen", detail: "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)", isSelected: hero.selectedWeaponName == "Raufen") {
                        hero.selectedWeaponName = "Raufen"
                        advanceToShieldOrRoot()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func advanceToShieldOrRoot() {
        if hero.shields.isEmpty {
            hero.selectedShieldName = nil
            step = .root
        } else {
            step = .loadoutShield
        }
    }

    private func loadoutRow(name: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(combatAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
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
                combatSectionLabel("BASIS")

                HStack(spacing: 8) {
                    baseButton(label: "Held", value: heroBaseINI)
                    if let mINI = mountBaseINI {
                        baseButton(label: mountName ?? "Reittier", value: mINI)
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
                                    step = .loadoutWeapon
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
            // Animation running: stop it and set result
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
    var onDismiss: () -> Void

    @State private var roundNumber: Int = 1
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
                Text("Runde \(roundNumber)")
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

            // AKTION section
            combatSectionLabel(L("action.label"))

            VStack(spacing: 8) {
                // Angriff -- primary (filled)
                Button {
                    step = .weaponSelection(.angriff)
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
                    step = .weaponSelection(.parieren)
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
                    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw, damageFormula: nil, note: nil)
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
    var onDismiss: () -> Void

    private var headerLabel: String {
        action == .angriff ? "Angriff" : "Parieren"
    }

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
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

                    if !hero.meleeWeapons.isEmpty {
                        combatSectionLabel("NAHKAMPFWAFFEN (\(statLabel))")
                        ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                            let val = action == .angriff ? w.at : w.pa
                            weaponRow(name: w.name, statLabel: statLabel, statValue: val, damageFormula: w.damage)
                        }
                    }

                    if !hero.shields.isEmpty {
                        combatSectionLabel("SCHILDE (\(statLabel))")
                        ForEach(hero.shields, id: \.persistentModelID) { s in
                            let val = action == .angriff ? s.at : s.pa
                            weaponRow(name: s.name, statLabel: statLabel, statValue: val)
                        }
                    }

                    combatSectionLabel(L("unarmed.label"))
                    let rauferVal = action == .angriff ? (raufen?.at ?? 0) : (raufen?.pa ?? 0)
                    weaponRow(name: "Raufen", statLabel: statLabel, statValue: rauferVal, damageFormula: "1W6")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func weaponRow(name: String, statLabel: String, statValue: Int, damageFormula: String? = nil) -> some View {
        Button {
            step = .execution(action, name: name, attributeValue: statValue, damageFormula: action == .angriff ? damageFormula : nil, note: nil)
        } label: {
            HStack {
                Text(name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
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
                // Row 1: AT/PA/AW value
                valueBox("\(attributeValue)", label: attrLabel)

                // Row 2: Modifier
                modifierBox

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
            combatSectionLabel("SCHADEN")

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
                combatSectionLabel("BASIS")

                HStack(spacing: 8) {
                    baseButton(label: "Held", value: heroBaseINI)
                    if let mountINI = mountBaseINI {
                        baseButton(label: mountName ?? "Reittier", value: mountINI)
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
                                    Text("Würfeln...")
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
                                Text("Bestätigen  →  INI \(t)")
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
