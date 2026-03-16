import SwiftUI
import SwiftData

// MARK: - CombatRootView

struct CombatRootView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var rolledInitiative: Int?
    @Binding var roundNumber: Int
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    @Binding var vorstossActiveThisRound: Bool
    @Binding var beengteUmgebungActive: Bool
    @Binding var defenseCountThisRound: Int
    @Binding var schipDefenseBoostActive: Bool
    @Binding var schipIgnoreZustandThisRound: Bool
    let mountedActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    var onDismiss: () -> Void

    @State private var showInitiativeSheet = false
    @State private var showArmorSheet = false

    private func buildDefenseModifiers(isAusweichen: Bool) -> [ModifierLine] {
        var lines: [ModifierLine] = []

        if defenseCountThisRound > 0 {
            lines.append(ModifierLine(value: -(defenseCountThisRound * 3), source: L("source.multipleDefense")))
        }

        let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
        if be > 0 { lines.append(ModifierLine(value: -be, source: L("source.belastung"))) }

        if !schipIgnoreZustandThisRound && hero.schmerzPenalty != 0 {
            let level = hero.effectiveSchmerzLevel
            lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
        }

        // Schicksalspunkt: Verteidigung stärken (+4)
        if schipDefenseBoostActive {
            lines.append(ModifierLine(value: 4, source: L("source.schipDefense")))
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

        // Beengte Umgebung (PA only, not AW)
        if !isAusweichen && beengteUmgebungActive {
            let heroReach: WeaponReach
            if let w = hero.selectedWeapon {
                heroReach = WeaponReach(rawValue: w.reach) ?? .mittel
            } else {
                heroReach = .kurz // Raufen = kurz
            }
            let buPenalty = heroReach.beengteUmgebungPenalty
            if buPenalty != 0 {
                lines.append(ModifierLine(value: buPenalty, source: L("beengteUmgebung")))
            }
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
            // RUNDE section
            combatSectionLabel(L("round.label"))

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

                Text(L("hero"))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                lpBar

                if mountedActive, let mount = hero.pets.first {
                    Text(mount.name)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

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
                }

                // STATUS section
                combatSectionLabel(L("status.label"))

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

                // Beengte Umgebung toggle
                Button { beengteUmgebungActive.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: beengteUmgebungActive ? "square.split.bottomrightquarter.fill" : "square.split.bottomrightquarter")
                            .font(.system(.caption, weight: .bold))
                        Text(L("beengteUmgebung"))
                            .font(.system(.caption, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(beengteUmgebungActive ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(beengteUmgebungActive ? combatAccent : Color(UIColor.secondarySystemBackground))
                    .overlay(Rectangle().stroke(beengteUmgebungActive ? combatAccent : Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Loadout + Armor in one row
                HStack(spacing: 8) {
                    if let weaponName = hero.selectedWeaponName {
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
                    }

                    Spacer()

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
                }
                .foregroundStyle(.primary)
                .padding(.top, 4)
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

                // Fernkampf
                if hero.selectedRangedWeaponName != nil {
                    Button {
                        step = .fernkampfSetup
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                            Text(L("rangedAttack"))
                        }
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }

                // Parieren -- secondary (outline)
                Button {
                    defenseCountThisRound += 1
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
                    defenseCountThisRound += 1
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

                // Damage buttons — side by side when mounted, full width otherwise
                HStack(spacing: 8) {
                    // Schaden nehmen -- dark
                    Button { step = .takeDamage } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.slash.fill")
                            Text(L("takeDamage"))
                        }
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.dsaDark)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)

                    if mountedActive {
                        Button {
                            step = .mountDamage
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.slash.fill")
                                Text(L("mountTakesDamage"))
                            }
                            .font(.system(.title3, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.dsaDark)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }

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

                // SCHICKSALSPUNKTE section
                let schipsAvailable = hero.derivedValues?.schicksalspunkte.current ?? 0

                if schipsAvailable > 0 || schipDefenseBoostActive || schipIgnoreZustandThisRound {
                    combatSectionLabel(L("schip.label"))

                    // Show current Schip count
                    HStack {
                        Text("\(hero.derivedValues?.schicksalspunkte.current ?? 0)")
                            .font(.system(.title3, weight: .black))
                            .fontDesign(.monospaced)
                        Text("/ \(hero.derivedValues?.schicksalspunkte.max ?? 0)")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    // Verteidigung stärken
                    if !schipDefenseBoostActive {
                        if schipsAvailable > 0 {
                            Button {
                                hero.derivedValues?.schicksalspunkte.current -= 1
                                schipDefenseBoostActive = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkered")
                                    Text(L("schip.defenseBoost"))
                                }
                                .font(.system(.body, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.6, green: 0.5, blue: 0.0))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                            Text(L("schip.defenseBoost"))
                            Image(systemName: "checkmark")
                        }
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.6, green: 0.5, blue: 0.0).opacity(0.1))
                        .overlay(Rectangle().stroke(Color(red: 0.6, green: 0.5, blue: 0.0), lineWidth: 2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Zustand ignorieren
                    if !schipIgnoreZustandThisRound && hero.effectiveSchmerzLevel > 0 {
                        if schipsAvailable > 0 {
                            Button {
                                hero.derivedValues?.schicksalspunkte.current -= 1
                                schipIgnoreZustandThisRound = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bandage")
                                    Text(L("schip.ignoreZustand"))
                                }
                                .font(.system(.body, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.6, green: 0.5, blue: 0.0))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    } else if schipIgnoreZustandThisRound {
                        HStack(spacing: 6) {
                            Image(systemName: "bandage")
                            Text(L("schip.ignoreZustand"))
                            Image(systemName: "checkmark")
                        }
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.6, green: 0.5, blue: 0.0).opacity(0.1))
                        .overlay(Rectangle().stroke(Color(red: 0.6, green: 0.5, blue: 0.0), lineWidth: 2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // End combat -- clears session
                Button {
                    hero.clearCombatSession()
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text(L("endCombat"))
                    }
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
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

struct CombatArmorManagementSheet: View {
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
            .background(armor.isEquipped ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder, lineWidth: armor.isEquipped ? 3 : 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CombatInitiativeSheet

struct CombatInitiativeSheet: View {
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
