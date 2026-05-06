import SwiftUI
import SwiftData

// MARK: - Attribute ID mapping (shared with SpellProbeModal)

private let attrIdToKey: [String: String] = [
    "ATTR_1": "MU", "ATTR_2": "KL", "ATTR_3": "IN",
    "ATTR_4": "CH", "ATTR_5": "FF", "ATTR_6": "GE",
    "ATTR_7": "KO", "ATTR_8": "KK",
]

// MARK: - CombatSpellSelectionView

struct CombatSpellSelectionView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = .root
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L("spellSelection"))
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
            .background(Color.groupMagic)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(hero.spells.sorted(by: { $0.name < $1.name }), id: \.persistentModelID) { spell in
                        Button {
                            step = .spellSetup(spell: spell)
                        } label: {
                            HStack {
                                Text(spell.name)
                                    .font(.system(.body, weight: .bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("FW \(spell.value)")
                                    .font(.system(.body, design: .monospaced, weight: .black))
                                    .foregroundStyle(Color.groupMagic)
                                Image(systemName: "chevron.right")
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - CombatSpellSetupView

struct CombatSpellSetupView: View {
    let hero: Hero
    let spell: HeroSpell
    @Binding var step: CombatStep
    let roundNumber: Int
    let mountedActive: Bool
    let schipIgnoreZustandThisRound: Bool
    var onDismiss: () -> Void

    @State private var maintainedCount = 0
    @State private var omitGesture = false
    @State private var omitFormula = false
    @State private var foreignTradition = false
    @State private var ironStein = 0
    @State private var distractionLevel = 0

    private var spellDetail: SpellDetail? {
        RulesDatabase.shared.lookup(id: spell.ruleId)?.spellDetail
    }

    private var castingActions: Int {
        guard let detail = spellDetail,
              let short = detail.castingTimeShort else { return 1 }
        // Parse patterns like "1 Aktion", "2 Aktionen", "4 Aktionen"
        let digits = short.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits) ?? 1
    }

    private var baseCost: Int? {
        guard let detail = spellDetail,
              let costStr = detail.aeCostShort,
              let cost = Int(costStr) else { return nil }
        return cost
    }

    private var maxModifications: Int {
        spell.value / 4
    }

    private var modifierContext: ModifierContext {
        var ctx = ModifierContext(
            hero: hero,
            domain: .spellCasting
        )
        ctx.maintainedSpellCount = maintainedCount
        ctx.foreignTradition = foreignTradition
        ctx.omitGesture = omitGesture
        ctx.omitFormula = omitFormula
        ctx.ironSteinCarried = ironStein
        ctx.distractionLevel = distractionLevel
        ctx.mounted = mountedActive
        ctx.schipIgnoreZustand = schipIgnoreZustandThisRound
        return ctx
    }

    private var modifierLines: [ModifierLine] {
        ModifierEngine.shared.evaluate(context: modifierContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = .spellSelection
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(L("spellSetup"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(spell.name)
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(.white)
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
            .background(Color.groupMagic)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    // Spell info
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("FW")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("\(spell.value)")
                                .font(.system(.body, weight: .black))
                                .fontDesign(.monospaced)
                        }

                        if let cost = baseCost {
                            HStack(spacing: 4) {
                                Text("AsP")
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text("\(cost)")
                                    .font(.system(.body, weight: .black))
                                    .fontDesign(.monospaced)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("\(castingActions) \(castingActions == 1 ? "Aktion" : "Aktionen")")
                                .font(.system(.body, weight: .bold))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    // Modifications section
                    combatSectionLabel(L("modifications.section"))

                    VStack(spacing: 0) {
                        toggleRow(L("mod.foreignTradition"), isOn: $foreignTradition)
                        toggleRow(L("mod.omitGesture"), isOn: $omitGesture)
                        toggleRow(L("mod.omitFormula"), isOn: $omitFormula)
                        stepperRow(L("mod.maintainedSpells"), value: $maintainedCount, range: 0...10)
                        stepperRow(L("mod.ironCarried"), value: $ironStein, range: 0...20)
                        distractionPicker

                        // Max modifications info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(Color.groupMagic)
                            Text(String(format: L("maxModifications"), maxModifications))
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(Color.groupMagic)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.groupMagic.opacity(0.1))
                        .overlay(Rectangle().stroke(Color.groupMagic, lineWidth: 1))
                    }
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    // Modifier summary
                    let mods = modifierLines
                    if !mods.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(mods) { line in
                                HStack(spacing: 8) {
                                    Image(systemName: line.value < 0 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                        .font(.system(.caption2, weight: .bold))
                                        .foregroundStyle(line.value < 0 ? Color.groupCombat : Color.groupMagic)
                                    Text("\(line.source): \(line.value >= 0 ? "+" : "")\(line.value)")
                                        .font(.system(.caption2, weight: .bold))
                                        .foregroundStyle(line.value < 0 ? Color.groupCombat : Color.groupMagic)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((line.value < 0 ? Color.groupCombat : Color.groupMagic).opacity(0.1))
                                .overlay(Rectangle().stroke(line.value < 0 ? Color.groupCombat : Color.groupMagic, lineWidth: 2))
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Continue button
                    let currentMods = modifierLines
                    Button {
                        if castingActions <= 1 {
                            step = .spellExecution(spell: spell, modifierLines: currentMods)
                        } else {
                            step = .spellCasting(spell: spell, startRound: roundNumber, totalRounds: castingActions, modifierLines: currentMods)
                        }
                    } label: {
                        Text(castingActions <= 1 ? L("continue") : "\(L("continue")) (\(castingActions) \(castingActions == 1 ? "Aktion" : "Aktionen"))")
                            .font(.system(.title3, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.groupMagic)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Row Helpers

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.groupMagic)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Rectangle().stroke(Color.dsaBorder.opacity(0.3), lineWidth: 1))
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Text("\u{2212}")
                        .font(.system(.body, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.system(.body, weight: .bold))
                    .frame(minWidth: 24)

                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Text("+")
                        .font(.system(.body, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .overlay(Rectangle().stroke(Color.dsaBorder.opacity(0.3), lineWidth: 1))
    }

    private var distractionPicker: some View {
        HStack {
            Text(L("mod.distraction"))
                .font(.system(.caption, weight: .medium))
            Spacer()
            Picker("", selection: $distractionLevel) {
                Text(L("mod.distraction.none")).tag(0)
                Text(L("mod.distraction.minor")).tag(1)
                Text(L("mod.distraction.ship")).tag(2)
                Text(L("mod.distraction.freefall")).tag(3)
            }
            .pickerStyle(.menu)
            .tint(.groupMagic)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .overlay(Rectangle().stroke(Color.dsaBorder.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - CombatSpellExecutionView

struct CombatSpellExecutionView: View {
    let hero: Hero
    let spell: HeroSpell
    let modifierLines: [ModifierLine]
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var spellDetail: SpellDetail? {
        RulesDatabase.shared.lookup(id: spell.ruleId)?.spellDetail
    }

    private var checkAttributes: [(key: String, value: Int)]? {
        guard let detail = spellDetail,
              let a1 = detail.checkAttr1,
              let a2 = detail.checkAttr2,
              let a3 = detail.checkAttr3,
              let attrs = hero.attributes else { return nil }
        let ids = [a1, a2, a3]
        let keys = ids.map { attrIdToKey[$0] ?? $0 }
        let values = keys.map { TalentProbeAttributes.attributeValue($0, from: attrs) }
        return zip(keys, values).map { (key: $0, value: $1) }
    }

    private var baseCost: Int? {
        guard let detail = spellDetail,
              let costStr = detail.aeCostShort,
              let cost = Int(costStr) else { return nil }
        return cost
    }

    private func deductCost(result: SkillCheckResult) {
        guard let cost = baseCost else { return }
        let actual: Int
        if result.isCriticalSuccess {
            actual = (cost + 1) / 2
        } else if result.succeeded {
            actual = cost
        } else {
            actual = (cost + 1) / 2
        }
        if let current = hero.derivedValues?.astralenergie?.current {
            hero.derivedValues?.astralenergie?.current = max(0, current - actual)
        }
    }

    private var costHints: [SkillCheckHint] {
        guard let cost = baseCost else { return [] }
        return [
            SkillCheckHint(
                icon: "bolt.fill",
                text: "AsP: \(cost)",
                color: .groupMagic
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = .root
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(spell.name)
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
            .background(Color.groupMagic)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            if let checkAttrs = checkAttributes {
                SkillCheckModal(
                    config: SkillCheckConfig(
                        title: L("spellProbe"),
                        name: spell.name,
                        skillValue: spell.value,
                        checkAttributes: checkAttrs,
                        accentColor: .groupMagic,
                        modifierLines: modifierLines,
                        logKind: "spellCheck"
                    ),
                    hero: hero,
                    onDismiss: { step = .root },
                    onResult: { result in
                        deductCost(result: result)
                    },
                    hints: costHints
                )
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.secondary)
                    Text(L("unknownTalent"))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
