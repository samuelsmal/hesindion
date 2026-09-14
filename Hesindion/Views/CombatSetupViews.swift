import SwiftUI
import SwiftData

// MARK: - CombatArmorPicker

/// Which pieces of armour are on, and what they add up to.
///
/// This was a screen of its own ahead of the preparation screen — one that could
/// not go back, whose summary bar ran edge to edge under a "Weiter" that did the
/// same, and which asked a question of exactly the same kind as the weapon two
/// steps later. Splitting "what is the hero wearing" from "what is the hero
/// holding" across two screens had nothing behind it.
struct CombatArmorPicker: View {
    let hero: Hero

    var body: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("armorSelection.label"))

            if hero.armors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "shield.slash")
                        .foregroundStyle(.secondary)
                    Text(L("noArmor"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.contentPadding)
                .background(Color(UIColor.systemBackground))
                .dsaBox(.flush)
            } else {
                VStack(spacing: 4) {
                    ForEach(hero.armors, id: \.persistentModelID) { armor in
                        armorRow(armor)
                    }
                }

                // What it comes to. The same dark total bar every calculation in
                // combat ends with, rather than a full-bleed bar pinned to the
                // bottom of a screen.
                HStack(spacing: 16) {
                    Text("\(L("rs")) \(hero.totalRS)")
                    Text("\(L("encumbrance")) \(hero.effectiveBE)")
                    Spacer()
                }
                .font(.dsaMono(.body, emphasis: true))
                .foregroundStyle(.white)
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, 10)
                .background(Color.dsaDark)
                .dsaBox(.raised)
                .padding(.top, 4)
                .accessibilityIdentifier("combat.setup.armorTotal")
            }
        }
    }

    private func armorRow(_ armor: Armor) -> some View {
        Button {
            armor.isEquipped.toggle()
        } label: {
            // Equipped is the fill, like every other option (ADR-0010).
            DSAToggleRowLabel(
                title: armor.name,
                isOn: armor.isEquipped,
                accent: combatAccent,
                subtitle: "\(L("rs")) \(armor.protectionValue)  \(L("encumbrance")) \(armor.encumbrance)"
            )
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.armor.\(armor.name)")
    }
}

// MARK: - CombatSetupView

/// The preparation screen: everything that is true about the hero *before* the
/// first initiative is rolled, in one place and every part of it changeable.
///
/// It used to carry three toggles — Plänkler-Formation, mounted, Beengte
/// Umgebung — and was skipped entirely for a hero with neither the formation nor
/// a horse. The weapon and the shield were chosen two steps further on, *after*
/// the initiative roll, and the armour a step before, so at no point did the app
/// show what the hero was about to fight with.
struct CombatSetupView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var plaenklerActive: Bool
    @Binding var plaenklerBonus: PlaenklerBonus
    @Binding var mountedActive: Bool
    @Binding var beengteUmgebungActive: Bool
    var onDismiss: () -> Void

    @State private var selected: Set<String> = []
    @State private var selectedRanged: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            combatScreenHeader(
                title: L("combatSetup"),
                onDismiss: onDismiss
            )

            ScrollView {
                VStack(spacing: 0) {
                    CombatArmorPicker(hero: hero)

                    CombatLoadoutPicker(
                        hero: hero,
                        mountedActive: mountedActive,
                        selected: $selected,
                        selectedRanged: $selectedRanged
                    )

                    // Plänkler-Formation
                    if hero.hasPlaenklerFormation {
                        combatSectionLabel(L("formation.label"))

                        DSAToggleRow(
                            title: L("plaenkler"),
                            isOn: $plaenklerActive,
                            accent: combatAccent,
                            identifier: "combat.setup.plaenkler"
                        )

                        if plaenklerActive {
                            HStack(spacing: 8) {
                                ForEach(PlaenklerBonus.allCases, id: \.self) { bonus in
                                    let isSelected = plaenklerBonus == bonus
                                    Button { plaenklerBonus = bonus } label: {
                                        Text(bonus == .at ? L("plaenklerAT") : L("plaenklerAW"))
                                            .font(.dsaBody(.caption))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                                            .dsaBox(.flush)
                                    }
                                    .buttonStyle(.dsaMotion)
                                    .accessibilityIdentifier("combat.setup.plaenkler.\(bonus.rawValue)")
                                }
                            }
                            .dsaOptionGroup()
                            .padding(.top, 4)
                        }
                    }

                    // Mount toggle
                    if hero.hasMount {
                        combatSectionLabel(L("mount.label"))

                        let mountName = hero.pets.first?.name ?? L("mount")
                        DSAToggleRow(
                            title: "\(L("mounted")) (\(mountName))",
                            isOn: $mountedActive,
                            accent: combatAccent,
                            identifier: "combat.setup.mounted"
                        )
                    }

                    // Beengte Umgebung toggle
                    combatSectionLabel(L("beengteUmgebung.label"))

                    DSAToggleRow(
                        title: L("beengteUmgebung"),
                        isOn: $beengteUmgebungActive,
                        accent: combatAccent,
                        identifier: "combat.setup.beengteUmgebung"
                    )

                    CombatActionButton(
                        title: L("continue"),
                        identifier: "combat.setup.continue",
                        isEnabled: !selected.isEmpty
                    ) {
                        CombatLoadoutPicker.apply(selected: selected, ranged: selectedRanged, to: hero)
                        step = .initiativeRoll
                    }
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            let current = CombatLoadoutPicker.load(from: hero)
            selected = current.selected
            selectedRanged = current.ranged
        }
        // A two-handed weapon cannot be swung from the saddle, so mounting up has
        // to be able to take one out of the hero's hands rather than leave the
        // screen showing a selection the rules forbid.
        .onChange(of: mountedActive) {
            guard mountedActive else { return }
            let forbidden = hero.meleeWeapons
                .filter { CombatTechniqueID(rawValue: $0.combatTechniqueId)?.isTwoHandedOnly ?? false }
                .map(\.name)
            selected.subtract(forbidden)
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

    /// Which base the roll uses. Identity, not the number: hero and mount can
    /// share an INI value, and comparing by value then lit both buttons.
    private enum INIBase: Equatable { case hero, mount }

    @State private var selectedBase: INIBase? = nil
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

    /// The mount's base is only on offer while the hero is actually mounted —
    /// an unmounted hero rolling the horse's INI was the one thing this screen
    /// could get wrong without saying so.
    private var mountBaseAvailable: Bool {
        mountedActive && mountBaseINI != nil
    }

    private func value(of base: INIBase) -> Int {
        switch base {
        case .hero:  heroBaseINI
        case .mount: mountBaseINI ?? heroBaseINI
        }
    }

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return value(of: base) + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .combatSetup } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)

                Spacer()

                Text(L("newInitiative"))
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

            VStack(spacing: 0) {
                // Base selector
                combatSectionLabel(L("basis.label"))

                HStack(spacing: 8) {
                    baseButton(.hero, label: L("hero"), value: heroBaseINI)
                    if mountBaseAvailable, let mINI = mountBaseINI {
                        baseButton(.mount, label: mountName ?? L("mount"), value: mINI)
                    }
                }

                // Dice + result
                if let selected = selectedBase {
                    let base = value(of: selected)
                    VStack(spacing: 8) {
                        // D6 box
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.dsaHeading(.largeTitle))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text(L("tapToRoll"))
                                        .font(.dsaBody(.caption2))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                            .contentShape(Rectangle())
                            .onTapGesture { tapDice() }
                            Text("W6")
                                .font(.dsaBody(.caption2))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // Calculation box
                        Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                            .font(.dsaHeading(.title3))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                            .opacity(d6Result == nil ? 0.4 : 1)

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                rolledInitiative = t
                                step = .root
                            } label: {
                                Text("\(L("confirm"))  \u{2192}  INI \(t)")
                                    .font(.dsaHeading(.body))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .dsaBox(.raised)
                            }
                            .buttonStyle(.dsaMotion)
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
            if mountBaseAvailable {
                selectedBase = .mount
                startD6Animation()
            }
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(_ base: INIBase, label: String, value: Int) -> some View {
        let isSelected = selectedBase == base
        return Button {
            selectedBase = base
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.dsaBody(.caption))
                Text("\(value)")
                    .font(.dsaHeading(.title3))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
    }

    private func tapDice() {
        if d6Result == nil && animTask != nil {
            animTask?.cancel()
            d6Result = DiceRoller.roll(sides: 6)
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
            d6Result = DiceRoller.roll(sides: 6)
        }
    }
}

// MARK: - CombatLoadoutEquipmentView

/// Changing the loadout mid-fight, reached from the combat root. Before the
/// fight the same picker sits on the preparation screen, where the question
/// belongs.
struct CombatLoadoutEquipmentView: View {
    let hero: Hero
    @Binding var step: CombatStep
    let mountedActive: Bool
    var onDismiss: () -> Void

    @State private var selected: Set<String> = []
    @State private var selectedRanged: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            combatScreenHeader(
                title: L("selectEquipment"),
                onBack: { step = .root },
                onDismiss: onDismiss
            )

            ScrollView {
                VStack(spacing: 0) {
                    CombatLoadoutPicker(
                        hero: hero,
                        mountedActive: mountedActive,
                        selected: $selected,
                        selectedRanged: $selectedRanged
                    )

                    CombatActionButton(
                        title: L("continue"),
                        identifier: "combat.loadout.continue",
                        isEnabled: !selected.isEmpty
                    ) {
                        CombatLoadoutPicker.apply(selected: selected, ranged: selectedRanged, to: hero)
                        step = .root
                    }
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            let current = CombatLoadoutPicker.load(from: hero)
            selected = current.selected
            selectedRanged = current.ranged
        }
    }
}
