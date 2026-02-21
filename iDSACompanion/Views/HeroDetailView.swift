import SwiftUI
import SwiftData

// MARK: - ActiveEdit

private struct ActiveEdit {
    let label: String
    let max: Int  // Int.max - 1 signals unbounded (money)
    let getCurrent: () -> Int
    let setCurrent: (Int) -> Void
}

// MARK: - EditCurrentModal

private struct EditCurrentModal: View {
    let edit: ActiveEdit
    @Binding var activeEdit: ActiveEdit?

    private var current: Int { edit.getCurrent() }
    private var maxLabel: String {
        edit.max == Int.max - 1 ? "∞" : "\(edit.max)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { activeEdit = nil }

            VStack(spacing: 20) {
                Text("/ \(maxLabel)")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)

                Text("\(current)")
                    .font(.system(.largeTitle, weight: .black))

                HStack(spacing: 16) {
                    Button {
                        edit.setCurrent(max(0, current - 1))
                    } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.yellow)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    }
                    .buttonStyle(.plain)

                    Button {
                        let cap = edit.max == Int.max - 1 ? Int.max - 2 : edit.max
                        edit.setCurrent(min(cap, current + 1))
                    } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.yellow)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
            .padding(32)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < -50 { activeEdit = nil }
                }
            )
        }
    }
}

// MARK: - AttributesBar

private struct AttributesBar: View {
    let attrs: Attributes

    var body: some View {
        HStack(spacing: 0) {
            attrBox("MU", attrs.mu)
            attrBox("KL", attrs.kl)
            attrBox("IN", attrs.inValue)
            attrBox("CH", attrs.ch)
            attrBox("FF", attrs.ff)
            attrBox("GE", attrs.ge)
            attrBox("KO", attrs.ko)
            attrBox("KK", attrs.kk)
        }
    }

    private func attrBox(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, weight: .bold))
            Text("\(value)")
                .font(.system(.title3, weight: .black))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.yellow)
        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }
}

// MARK: - CollapsibleSection

private struct CollapsibleSection<Content: View>: View {
    let title: String
    @State private var isExpanded = true
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
            }
            .buttonStyle(.plain)

            if isExpanded { content }
        }
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
    }
}

// MARK: - FieldRow

private struct FieldRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !value.isEmpty {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }
}

// MARK: - SubfieldBlock

private struct SubfieldBlock: View {
    let label: String
    let subfields: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.system(.body, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ForEach(subfields, id: \.0) { key, val in
                VStack(spacing: 0) {
                    HStack {
                        Text(key).font(.body).foregroundStyle(.secondary)
                        Spacer()
                        Text(val).font(.system(.body, design: .monospaced))
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }
}

// MARK: - EquipmentRow (swipe-to-delete)

private struct EquipmentRow: View {
    let item: EquipmentItem
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = -80

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.red
            Text("Delete")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(.white)
                .padding(.trailing, 20)
                .opacity(offset < -40 ? 1 : 0)

            VStack(spacing: 0) {
                HStack {
                    Text(item.name).font(.body)
                    Spacer()
                    Text(String(format: "%.2f kg", item.weight))
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
                .offset(x: max(offset, threshold))
                Divider()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.width < 0 { offset = v.translation.width } }
                .onEnded { v in
                    if v.translation.width < threshold {
                        onDelete()
                    } else {
                        withAnimation { offset = 0 }
                    }
                }
        )
    }
}

// MARK: - HeroDetailView

struct HeroDetailView: View {
    let hero: Hero
    @Environment(\.modelContext) private var modelContext
    @State private var activeEdit: ActiveEdit?

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    // Name heading — scrolls away
                    Text(hero.name)
                        .font(.system(.largeTitle, design: .default, weight: .black))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if let attrs = hero.attributes {
                        SwiftUI.Section {
                            VStack(spacing: 8) {
                                experienceSection
                                personalDataSection
                                derivedValuesSection
                                advantagesSection
                                disadvantagesSection
                                generalSpecialAbilitiesSection
                                languagesSection
                                scriptsSection
                                talentsSection
                                combatTechniquesSection
                                combatSpecialAbilitiesSection
                                equipmentSection
                                meleeWeaponsSection
                                shieldSection
                                armorSection
                                moneySection
                                mountSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } header: {
                            AttributesBar(attrs: attrs)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }

            if let edit = activeEdit {
                EditCurrentModal(edit: edit, activeEdit: $activeEdit)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section 1: Experience

    @ViewBuilder private var experienceSection: some View {
        if let exp = hero.experience {
            CollapsibleSection("Experience") {
                FieldRow(label: "level", value: exp.level)
                FieldRow(label: "totalAP", value: "\(exp.totalAP)")
                FieldRow(label: "availableAP", value: "\(exp.availableAP)")
                FieldRow(label: "spentAP", value: "\(exp.spentAP)")
            }
        }
    }

    // MARK: - Section 2: PersonalData

    @ViewBuilder private var personalDataSection: some View {
        if let pd = hero.personalData {
            CollapsibleSection("PersonalData") {
                FieldRow(label: "name", value: pd.name)
                FieldRow(label: "family", value: pd.family)
                FieldRow(label: "birthplace", value: pd.birthplace)
                FieldRow(label: "birthdate", value: pd.birthdate)
                FieldRow(label: "age", value: "\(pd.age)")
                FieldRow(label: "gender", value: pd.gender)
                FieldRow(label: "species", value: pd.species)
                FieldRow(label: "height", value: "\(pd.height) cm")
                FieldRow(label: "weight", value: "\(pd.weight) kg")
                FieldRow(label: "hairColor", value: pd.hairColor)
                FieldRow(label: "eyeColor", value: pd.eyeColor)
                FieldRow(label: "culture", value: pd.culture)
                FieldRow(label: "socialStatus", value: pd.socialStatus)
                FieldRow(label: "profession", value: pd.profession)
                FieldRow(label: "title", value: pd.title)
                FieldRow(label: "characteristics", value: pd.characteristics)
            }
        }
    }

    // MARK: - Section 3: DerivedValues

    @ViewBuilder private var derivedValuesSection: some View {
        if let dv = hero.derivedValues {
            CollapsibleSection("DerivedValues") {
                // lebensenergie — interactive
                if dv.lebensenergie.max > 0 {
                    interactiveDerivedRow(
                        label: "lebensenergie",
                        primary: "\(dv.lebensenergie.current) / \(dv.lebensenergie.max)",
                        subfields: [
                            ("base", "\(dv.lebensenergie.base)"),
                            ("bonus", "\(dv.lebensenergie.bonus)"),
                            ("purchased", "\(dv.lebensenergie.purchased)")
                        ],
                        maxVal: dv.lebensenergie.max,
                        get: { dv.lebensenergie.current },
                        set: { dv.lebensenergie.current = $0 }
                    )
                }

                // schicksalspunkte — interactive
                if dv.schicksalspunkte.max > 0 {
                    interactiveDerivedRow(
                        label: "schicksalspunkte",
                        primary: "\(dv.schicksalspunkte.current) / \(dv.schicksalspunkte.max)",
                        subfields: [("bonus", "\(dv.schicksalspunkte.bonus)")],
                        maxVal: dv.schicksalspunkte.max,
                        get: { dv.schicksalspunkte.current },
                        set: { dv.schicksalspunkte.current = $0 }
                    )
                }

                // astralenergie — interactive, hidden when max == 0
                if let ae = dv.astralenergie, ae.max > 0 {
                    interactiveDerivedRow(
                        label: "astralenergie",
                        primary: "\(ae.current) / \(ae.max)",
                        subfields: [("bonus", "\(ae.bonus)")],
                        maxVal: ae.max,
                        get: { dv.astralenergie?.current ?? 0 },
                        set: { dv.astralenergie?.current = $0 }
                    )
                }

                // karmaenergie — interactive, hidden when max == 0
                if let ke = dv.karmaenergie, ke.max > 0 {
                    interactiveDerivedRow(
                        label: "karmaenergie",
                        primary: "\(ke.current) / \(ke.max)",
                        subfields: [("bonus", "\(ke.bonus)")],
                        maxVal: ke.max,
                        get: { dv.karmaenergie?.current ?? 0 },
                        set: { dv.karmaenergie?.current = $0 }
                    )
                }

                // Read-only rows
                if dv.seelenkraft.max > 0 {
                    SubfieldBlock(label: "seelenkraft", subfields: [
                        ("base", "\(dv.seelenkraft.base)"),
                        ("bonus", "\(dv.seelenkraft.bonus)"),
                        ("max", "\(dv.seelenkraft.max)")
                    ])
                }

                if dv.zaehigkeit.max > 0 {
                    SubfieldBlock(label: "zähigkeit", subfields: [
                        ("base", "\(dv.zaehigkeit.base)"),
                        ("bonus", "\(dv.zaehigkeit.bonus)"),
                        ("max", "\(dv.zaehigkeit.max)")
                    ])
                }

                if dv.ausweichen.max > 0 {
                    SubfieldBlock(label: "ausweichen", subfields: [
                        ("value", "\(dv.ausweichen.value)"),
                        ("bonus", "\(dv.ausweichen.bonus)"),
                        ("max", "\(dv.ausweichen.max)")
                    ])
                }

                if dv.initiative.max > 0 {
                    SubfieldBlock(label: "initiative", subfields: [
                        ("value", "\(dv.initiative.value)"),
                        ("bonus", "\(dv.initiative.bonus)"),
                        ("max", "\(dv.initiative.max)")
                    ])
                }

                if dv.geschwindigkeit.max > 0 {
                    SubfieldBlock(label: "geschwindigkeit", subfields: [
                        ("base", "\(dv.geschwindigkeit.base)"),
                        ("bonus", "\(dv.geschwindigkeit.bonus)"),
                        ("max", "\(dv.geschwindigkeit.max)")
                    ])
                }

                if dv.wundschwelle.max > 0 {
                    SubfieldBlock(label: "wundschwelle", subfields: [
                        ("value", "\(dv.wundschwelle.value)"),
                        ("bonus", "\(dv.wundschwelle.bonus)"),
                        ("max", "\(dv.wundschwelle.max)")
                    ])
                }
            }
        }
    }

    private func interactiveDerivedRow(
        label: String,
        primary: String,
        subfields: [(String, String)],
        maxVal: Int,
        get: @escaping () -> Int,
        set: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.body)
                Spacer()
                Text(primary).font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onLongPressGesture {
                activeEdit = ActiveEdit(label: label, max: maxVal, getCurrent: get, setCurrent: set)
            }

            ForEach(subfields, id: \.0) { key, val in
                HStack {
                    Text(key).font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Text(val).font(.system(.body, design: .monospaced))
                }
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
            }
            Divider()
        }
    }

    // MARK: - Section 4: Advantages

    @ViewBuilder private var advantagesSection: some View {
        if !hero.advantages.isEmpty {
            CollapsibleSection("Advantages") {
                ForEach(hero.advantages, id: \.self) { item in
                    FieldRow(label: item, value: "")
                }
            }
        }
    }

    // MARK: - Section 5: Disadvantages

    @ViewBuilder private var disadvantagesSection: some View {
        if !hero.disadvantages.isEmpty {
            CollapsibleSection("Disadvantages") {
                ForEach(hero.disadvantages, id: \.self) { item in
                    FieldRow(label: item, value: "")
                }
            }
        }
    }

    // MARK: - Section 6: GeneralSpecialAbilities

    @ViewBuilder private var generalSpecialAbilitiesSection: some View {
        if !hero.generalSpecialAbilities.isEmpty {
            CollapsibleSection("GeneralSpecialAbilities") {
                ForEach(hero.generalSpecialAbilities, id: \.self) { item in
                    FieldRow(label: item, value: "")
                }
            }
        }
    }

    // MARK: - Section 7: Languages

    @ViewBuilder private var languagesSection: some View {
        if !hero.languages.isEmpty {
            CollapsibleSection("Languages") {
                ForEach(hero.languages, id: \.persistentModelID) { lang in
                    FieldRow(label: lang.name, value: lang.level)
                }
            }
        }
    }

    // MARK: - Section 8: Scripts

    @ViewBuilder private var scriptsSection: some View {
        if !hero.scripts.isEmpty {
            CollapsibleSection("Scripts") {
                ForEach(hero.scripts, id: \.self) { item in
                    FieldRow(label: item, value: "")
                }
            }
        }
    }

    // MARK: - Section 9: Talents

    @ViewBuilder private var talentsSection: some View {
        if !hero.talents.isEmpty {
            CollapsibleSection("Talents") {
                let grouped = Dictionary(grouping: hero.talents, by: \.category)
                let sortedCategories = grouped.keys.sorted()
                ForEach(sortedCategories, id: \.self) { category in
                    VStack(spacing: 0) {
                        HStack {
                            Text(category)
                                .font(.system(.body, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.4))

                        ForEach(grouped[category] ?? [], id: \.persistentModelID) { talent in
                            HStack {
                                Text(talent.name).font(.body)
                                Spacer()
                                Text("\(talent.value)").font(.system(.body, design: .monospaced))
                            }
                            .padding(.leading, 24)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 10: CombatTechniques

    @ViewBuilder private var combatTechniquesSection: some View {
        if !hero.combatTechniques.isEmpty {
            CollapsibleSection("CombatTechniques") {
                ForEach(hero.combatTechniques, id: \.persistentModelID) { ct in
                    VStack(spacing: 0) {
                        HStack {
                            Text(ct.name).font(.body)
                            Spacer()
                            Text("\(ct.value)").font(.system(.body, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        HStack(spacing: 12) {
                            Text("AT").font(.system(.caption, weight: .bold))
                            Text("\(ct.at)").font(.system(.caption, design: .monospaced))
                            if let pa = ct.pa {
                                Text("PA").font(.system(.caption, weight: .bold))
                                Text("\(pa)").font(.system(.caption, design: .monospaced))
                            }
                            Spacer()
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 12)
                        .padding(.bottom, 6)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Section 11: CombatSpecialAbilities

    @ViewBuilder private var combatSpecialAbilitiesSection: some View {
        if !hero.combatSpecialAbilities.isEmpty {
            CollapsibleSection("CombatSpecialAbilities") {
                ForEach(hero.combatSpecialAbilities, id: \.self) { item in
                    FieldRow(label: item, value: "")
                }
            }
        }
    }

    // MARK: - Section 12: Equipment

    @ViewBuilder private var equipmentSection: some View {
        CollapsibleSection("Equipment") {
            ForEach(hero.equipment, id: \.persistentModelID) { item in
                EquipmentRow(item: item) { modelContext.delete(item) }
            }

            let total = hero.totalEquipmentWeight
            let threshold = hero.carryingThreshold
            HStack {
                let label = String(format: "%.2f / %d kg", total, Int(threshold))
                if hero.isOverloaded {
                    Text("⚠ " + label).foregroundStyle(.red)
                } else {
                    Text(label)
                }
                Spacer()
            }
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section 13: MeleeWeapons

    @ViewBuilder private var meleeWeaponsSection: some View {
        if !hero.meleeWeapons.isEmpty {
            CollapsibleSection("MeleeWeapons") {
                ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                    SubfieldBlock(label: w.name, subfields: [
                        ("technique", w.technique),
                        ("damage", w.damage),
                        ("AT", "\(w.at)"),
                        ("PA", "\(w.pa)"),
                        ("reach", w.reach),
                        ("weight", String(format: "%.2f kg", w.weight))
                    ])
                }
            }
        }
    }

    // MARK: - Section 14: Shield

    @ViewBuilder private var shieldSection: some View {
        if let s = hero.shield {
            CollapsibleSection("Shield") {
                FieldRow(label: "name", value: s.name)
                FieldRow(label: "structure", value: "\(s.structure)")
                FieldRow(label: "breakingFactor", value: "\(s.breakingFactor)")
                FieldRow(label: "atMod", value: "\(s.atMod)")
                FieldRow(label: "paMod", value: "\(s.paMod)")
                FieldRow(label: "weight", value: String(format: "%.2f kg", s.weight))
            }
        }
    }

    // MARK: - Section 15: Armor

    @ViewBuilder private var armorSection: some View {
        if let a = hero.armor {
            CollapsibleSection("Armor") {
                FieldRow(label: "name", value: a.name)
                FieldRow(label: "protectionValue", value: "\(a.protectionValue)")
                FieldRow(label: "armorRating", value: "\(a.armorRating)")
                FieldRow(label: "encumbrance", value: "\(a.encumbrance)")
                FieldRow(label: "weight", value: String(format: "%.2f kg", a.weight))
            }
        }
    }

    // MARK: - Section 16: Money

    @ViewBuilder private var moneySection: some View {
        if let m = hero.money {
            CollapsibleSection("Money") {
                moneyRow("dukaten",    get: { m.dukaten },    set: { m.dukaten = $0 })
                moneyRow("silbertaler", get: { m.silbertaler }, set: { m.silbertaler = $0 })
                moneyRow("heller",     get: { m.heller },     set: { m.heller = $0 })
                moneyRow("kreuzer",    get: { m.kreuzer },    set: { m.kreuzer = $0 })
            }
        }
    }

    private func moneyRow(
        _ label: String,
        get: @escaping () -> Int,
        set: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.body)
                Spacer()
                Text("\(get())").font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onLongPressGesture {
                activeEdit = ActiveEdit(label: label, max: Int.max - 1, getCurrent: get, setCurrent: set)
            }
            Divider()
        }
    }

    // MARK: - Section 17: Mount

    @ViewBuilder private var mountSection: some View {
        if let m = hero.mount {
            CollapsibleSection("Mount") {
                FieldRow(label: "name", value: m.name)
                FieldRow(label: "type", value: m.mountType)
                FieldRow(label: "size", value: String(format: "%.1f", m.size))
                FieldRow(label: "lifeEnergy", value: "\(m.lifeEnergy)")
                FieldRow(label: "initiative", value: m.initiative)
                FieldRow(label: "speed", value: "\(m.speed)")

                SubfieldBlock(label: "attributes", subfields: [
                    ("MU", "\(m.attributes.mu)"),
                    ("KL", "\(m.attributes.kl)"),
                    ("IN", "\(m.attributes.inValue)"),
                    ("CH", "\(m.attributes.ch)"),
                    ("FF", "\(m.attributes.ff)"),
                    ("GE", "\(m.attributes.ge)"),
                    ("KO", "\(m.attributes.ko)"),
                    ("KK", "\(m.attributes.kk)")
                ])

                if !m.attacks.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("attacks").font(.system(.body, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        ForEach(m.attacks, id: \.name) { attack in
                            SubfieldBlock(label: attack.name, subfields: [
                                ("AT", "\(attack.at)"),
                                ("damage", attack.damage),
                                ("reach", attack.reach)
                            ])
                        }
                    }
                }

                if !m.talents.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("talents").font(.system(.body, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        ForEach(m.talents, id: \.name) { t in
                            HStack {
                                Text(t.name).font(.body)
                                Spacer()
                                Text("\(t.value)").font(.system(.body, design: .monospaced))
                            }
                            .padding(.leading, 24)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }

                if !m.specialAbilities.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("specialAbilities").font(.system(.body, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        ForEach(m.specialAbilities, id: \.self) { ability in
                            FieldRow(label: ability, value: "")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Hero.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self, MeleeWeapon.self,
            Armor.self, Shield.self, EquipmentItem.self, Money.self, Mount.self, Language.self,
        configurations: config
    )
    let hero = Hero(name: "Boronmir Siebenfeld von Ferdok")
    container.mainContext.insert(hero)
    return NavigationStack {
        HeroDetailView(hero: hero)
    }
    .modelContainer(container)
}
