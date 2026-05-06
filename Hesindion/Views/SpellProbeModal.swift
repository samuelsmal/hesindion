import SwiftUI
import SwiftData

// MARK: - SpellProbeModal

struct SpellProbeModal: View {
    let spell: HeroSpell
    let hero: Hero
    let isLiturgy: Bool
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var expanded = false
    @State private var maintainedCount = 0
    @State private var omitGesture = false
    @State private var omitFormula = false
    @State private var foreignTradition = false
    @State private var ironStein = 0
    @State private var distractionLevel = 0

    // MARK: - Attribute ID → short key mapping

    private static let attrIdToKey: [String: String] = [
        "ATTR_1": "MU", "ATTR_2": "KL", "ATTR_3": "IN",
        "ATTR_4": "CH", "ATTR_5": "FF", "ATTR_6": "GE",
        "ATTR_7": "KO", "ATTR_8": "KK",
    ]

    // MARK: - Spell detail from rules DB

    private var spellDetail: SpellDetail? {
        RulesDatabase.shared.lookup(id: spell.ruleId)?.spellDetail
    }

    // MARK: - Check attributes

    private var checkAttributes: [(key: String, value: Int)]? {
        guard let detail = spellDetail,
              let a1 = detail.checkAttr1,
              let a2 = detail.checkAttr2,
              let a3 = detail.checkAttr3,
              let attrs = hero.attributes else { return nil }
        let ids = [a1, a2, a3]
        let keys = ids.map { Self.attrIdToKey[$0] ?? $0 }
        let values = keys.map { TalentProbeAttributes.attributeValue($0, from: attrs) }
        return zip(keys, values).map { (key: $0, value: $1) }
    }

    // MARK: - Modifier context

    private var modifierContext: ModifierContext {
        var ctx = ModifierContext(
            hero: hero,
            domain: isLiturgy ? .liturgyCasting : .spellCasting
        )
        ctx.maintainedSpellCount = maintainedCount
        ctx.foreignTradition = foreignTradition
        ctx.omitGesture = omitGesture
        ctx.omitFormula = omitFormula
        ctx.ironSteinCarried = ironStein
        ctx.distractionLevel = distractionLevel
        return ctx
    }

    private var modifierLines: [ModifierLine] {
        ModifierEngine.shared.evaluate(context: modifierContext)
    }

    // MARK: - Max modifications

    private var maxModifications: Int {
        spell.value / 4
    }

    // MARK: - AE / KP cost

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
            actual = (cost + 1) / 2 // half, rounded up
        } else if result.succeeded {
            actual = cost
        } else {
            actual = (cost + 1) / 2 // half, rounded up
        }
        if isLiturgy {
            if let current = hero.derivedValues?.karmaenergie?.current {
                hero.derivedValues?.karmaenergie?.current = max(0, current - actual)
            }
        } else {
            if let current = hero.derivedValues?.astralenergie?.current {
                hero.derivedValues?.astralenergie?.current = max(0, current - actual)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        if let checkAttrs = checkAttributes {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                VStack(spacing: 0) {
                    modificationsPanel
                    skillCheckView(checkAttrs: checkAttrs)
                }
                .frame(maxWidth: 400)
                .padding(24)
            }
        } else {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
                Text(L("unknownTalent"))
                    .padding()
            }
        }
    }

    // MARK: - Modifications Panel

    @ViewBuilder
    private var modificationsPanel: some View {
        VStack(spacing: 0) {
            // Header toggle
            Button {
                withAnimation(DSAAnimation.standard) { expanded.toggle() }
            } label: {
                HStack {
                    Text(L("modifications.section"))
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.groupMagic.opacity(0.8))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    // Foreign tradition
                    toggleRow(L("mod.foreignTradition"), isOn: $foreignTradition)

                    // Omit gesture
                    toggleRow(L("mod.omitGesture"), isOn: $omitGesture)

                    // Omit formula
                    toggleRow(L("mod.omitFormula"), isOn: $omitFormula)

                    // Maintained spells
                    stepperRow(L("mod.maintainedSpells"), value: $maintainedCount, range: 0...10)

                    // Iron carried (spells only)
                    if !isLiturgy {
                        stepperRow(L("mod.ironCarried"), value: $ironStein, range: 0...20)
                    }

                    // Distraction picker
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
            }
        }
    }

    // MARK: - Skill Check

    private func skillCheckView(checkAttrs: [(key: String, value: Int)]) -> some View {
        SkillCheckModal(
            config: SkillCheckConfig(
                title: isLiturgy ? L("liturgyProbe") : L("spellProbe"),
                name: spell.name,
                skillValue: spell.value,
                checkAttributes: checkAttrs,
                accentColor: .groupMagic,
                modifierLines: modifierLines,
                logKind: isLiturgy ? "liturgyCheck" : "spellCheck"
            ),
            hero: hero,
            onDismiss: onDismiss,
            onResult: { result in
                deductCost(result: result)
            },
            hints: costHints
        )
    }

    private var costHints: [SkillCheckHint] {
        guard let cost = baseCost else { return [] }
        let label = isLiturgy ? "KaP" : "AsP"
        return [
            SkillCheckHint(
                icon: "bolt.fill",
                text: "\(label): \(cost)",
                color: .groupMagic
            ),
        ]
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
