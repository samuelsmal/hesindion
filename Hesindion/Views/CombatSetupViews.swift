import SwiftUI
import SwiftData

// MARK: - CombatArmorSelectionView

struct CombatArmorSelectionView: View {
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
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.totalRS)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    Text(L("encumbrance"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.effectiveBE)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .adaptiveContentWidth()
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
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
            .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CombatSetupView

struct CombatSetupView: View {
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

// MARK: - CombatInitiativeRollView

struct CombatInitiativeRollView: View {
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

// MARK: - CombatLoadoutEquipmentView

struct CombatLoadoutEquipmentView: View {
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
