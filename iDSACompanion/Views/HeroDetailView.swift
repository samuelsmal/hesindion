import SwiftUI
import SwiftData

// MARK: - HeroDetailView

struct HeroDetailView: View {
    let hero: Hero
    @Environment(\.modelContext) private var modelContext
    @State private var activeEdit: ActiveEdit?
    @State private var showCommandSearch = false
    @State private var activeCommand: AppCommand?
    @State private var commandQuery = ""
    @FocusState private var searchFocused: Bool
    @State private var activeTalentProbe: Talent? = nil
    @State private var showCombatMode = false
    @State private var showRegenerierenSheet = false

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
                            VStack(spacing: 0) {
                                CollapsibleGroup("Personal Data", color: .groupPersonalData) {
                                    VStack(spacing: 8) {
                                        personalDataSection
                                        experienceSection
                                        derivedValuesSection
                                        advantagesSection
                                        disadvantagesSection
                                        generalSpecialAbilitiesSection
                                        languagesSection
                                        scriptsSection
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }

                                CollapsibleGroup("Talents", color: .groupTalents, textColor: .white) {
                                    VStack(spacing: 8) {
                                        talentsSections
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }

                                CollapsibleGroup("Combat", color: .groupCombat) {
                                    VStack(spacing: 8) {
                                        combatTechniquesSection
                                        combatSpecialAbilitiesSection
                                        meleeWeaponsSection
                                        armorSection
                                        shieldSection
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }

                                CollapsibleGroup("Equipment", color: .groupEquipment, textColor: .white) {
                                    VStack(spacing: 8) {
                                        equipmentSection
                                        moneySection
                                        mountSection
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.bottom, 16)
                        } header: {
                            AttributesBar(attrs: attrs)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                // y == 0 at rest; goes negative when overscrolled past the top
                if y < -120 && !showCommandSearch {
                    showCommandSearch = true
                    commandQuery = ""
                    searchFocused = true
                }
            }

            if let edit = activeEdit {
                EditCurrentModal(edit: edit, activeEdit: $activeEdit)
            }

            if showCommandSearch {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { dismissSearch() }

                VStack {
                    CommandSearchOverlay(
                        query: $commandQuery,
                        isVisible: $showCommandSearch,
                        activeCommand: $activeCommand,
                        commands: filteredCommands,
                        isFocused: $searchFocused
                    )
                    Spacer()
                }
            }

            if let cmd = activeCommand {
                CommandModal(command: cmd, activeCommand: $activeCommand)
            }

            if let talent = activeTalentProbe {
                TalentProbeModal(talent: talent, hero: hero) { activeTalentProbe = nil }
            }

        }
        .fullScreenCover(isPresented: $showCombatMode) {
            CombatView(hero: hero) { showCombatMode = false }
        }
        .sheet(isPresented: $showRegenerierenSheet) {
            RegenerierenSheet(hero: hero)
                .presentationCornerRadius(0)
                .presentationDetents([.medium])
        }
        .onChange(of: activeCommand?.id) { _, _ in
            guard let cmd = activeCommand else { return }
            if cmd.name == "Kampf" {
                showCombatMode = true
                activeCommand = nil
                return
            }
            if cmd.name == "Regenerieren" {
                showRegenerierenSheet = true
                activeCommand = nil
                return
            }
            guard cmd.name == "Probe" else { return }
            if let name = cmd.subparameter,
               let talent = hero.talents.first(where: { $0.name == name }) {
                activeTalentProbe = talent
            }
            activeCommand = nil
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dismissSearch() {
        showCommandSearch = false
        commandQuery = ""
        searchFocused = false
    }

    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "ä", with: "ae")
         .replacingOccurrences(of: "ö", with: "oe")
         .replacingOccurrences(of: "ü", with: "ue")
         .replacingOccurrences(of: "ß", with: "ss")
         .replacingOccurrences(of: "Ä", with: "ae")
         .replacingOccurrences(of: "Ö", with: "oe")
         .replacingOccurrences(of: "Ü", with: "ue")
         .lowercased()
    }

    private var filteredCommands: [AppCommand] {
        let all = hero.commandRegistry
        guard !commandQuery.isEmpty else {
            return all.sorted { $0.displayName < $1.displayName }
        }
        let tokens = commandQuery.split(separator: " ").map { normalize(String($0)) }
        let t0 = tokens[0]
        let t1 = tokens.count > 1 ? tokens[1] : nil
        return all.compactMap { cmd -> (AppCommand, Double)? in
            let normName = normalize(cmd.name)
            let normSub  = normalize(cmd.subparameter ?? "")
            if let t1 {
                // Two tokens: name must match first, subparameter must match second
                guard normName.contains(t0), normSub.contains(t1) else { return nil }
                return (cmd, Double(t0.count) / Double(normName.count))
            }
            // Single token: match name OR subparameter
            if normName.contains(t0) {
                return (cmd, Double(t0.count) / Double(normName.count))
            }
            if !normSub.isEmpty, normSub.contains(t0) {
                return (cmd, 0.5 * Double(t0.count) / Double(normSub.count))
            }
            return nil
        }
        .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.displayName < $1.0.displayName) }
        .map(\.0)
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
                FieldRow(label: "weight", value: "\(pd.weight) st")
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
                if dv.lebensenergie.max > 0 {
                    interactiveDerivedRow(
                        label: "lebensenergie",
                        primary: "\(dv.lebensenergie.current) / \(dv.lebensenergie.max)",
                        subfields: []
                    ) {
                        activeCommand = AppCommand(
                            id: UUID(),
                            name: "lebensenergie",
                            subparameter: nil,
                            input: .integerAmount(
                                label: "Aktuell",
                                min: 0,
                                max: dv.lebensenergie.max,
                                initial: dv.lebensenergie.current
                            ),
                            execute: { result in
                                if case .integerAmount(let v) = result {
                                    dv.lebensenergie.current = v
                                }
                            }
                        )
                    }
                }
                if dv.schicksalspunkte.max > 0 {
                    interactiveDerivedRow(
                        label: "schicksalspunkte",
                        primary: "\(dv.schicksalspunkte.current) / \(dv.schicksalspunkte.max)",
                        subfields: []
                    ) {
                        activeCommand = AppCommand(
                            id: UUID(),
                            name: "schicksalspunkte",
                            subparameter: nil,
                            input: .integerAmount(
                                label: "Aktuell",
                                min: 0,
                                max: dv.schicksalspunkte.max,
                                initial: dv.schicksalspunkte.current
                            ),
                            execute: { result in
                                if case .integerAmount(let v) = result {
                                    dv.schicksalspunkte.current = v
                                }
                            }
                        )
                    }
                }
                if let ae = dv.astralenergie, ae.max > 0 {
                    interactiveDerivedRow(
                        label: "astralenergie",
                        primary: "\(ae.current) / \(ae.max)",
                        subfields: []
                    ) {
                        activeCommand = AppCommand(
                            id: UUID(),
                            name: "astralenergie",
                            subparameter: nil,
                            input: .integerAmount(
                                label: "Aktuell",
                                min: 0,
                                max: ae.max,
                                initial: ae.current
                            ),
                            execute: { result in
                                if case .integerAmount(let v) = result {
                                    dv.astralenergie?.current = v
                                }
                            }
                        )
                    }
                }
                if let ke = dv.karmaenergie, ke.max > 0 {
                    interactiveDerivedRow(
                        label: "karmaenergie",
                        primary: "\(ke.current) / \(ke.max)",
                        subfields: []
                    ) {
                        activeCommand = AppCommand(
                            id: UUID(),
                            name: "karmaenergie",
                            subparameter: nil,
                            input: .integerAmount(
                                label: "Aktuell",
                                min: 0,
                                max: ke.max,
                                initial: ke.current
                            ),
                            execute: { result in
                                if case .integerAmount(let v) = result {
                                    dv.karmaenergie?.current = v
                                }
                            }
                        )
                    }
                }
                if dv.seelenkraft.max > 0 { FieldRow(label: "seelenkraft", value: "\(dv.seelenkraft.max)") }
                if dv.zaehigkeit.max > 0 { FieldRow(label: "zähigkeit", value: "\(dv.zaehigkeit.max)") }
                if dv.ausweichen.max > 0 { FieldRow(label: "ausweichen", value: "\(dv.ausweichen.max)") }
                if dv.initiative.max > 0 { FieldRow(label: "initiative", value: "\(dv.initiative.max)") }
                if dv.geschwindigkeit.max > 0 { FieldRow(label: "geschwindigkeit", value: "\(dv.geschwindigkeit.max)") }
                if dv.wundschwelle.max > 0 { FieldRow(label: "wundschwelle", value: "\(dv.wundschwelle.max)") }
            }
        }
    }

    private func interactiveDerivedRow(
        label: String,
        primary: String,
        subfields: [(String, String)],
        onLongPress: @escaping () -> Void
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
            .onLongPressGesture { onLongPress() }

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

    private let talentCategoryOrder = [
        "körpertalente", "gesellschaftstalente", "naturtalente",
        "wissenstalente", "handwerkstalente"
    ]

    @ViewBuilder private var talentsSections: some View {
        let grouped = Dictionary(grouping: hero.talents, by: \.category)
        ForEach(talentCategoryOrder, id: \.self) { category in
            if let items = grouped[category], !items.isEmpty {
                CollapsibleSection(category) {
                    ForEach(items, id: \.persistentModelID) { talent in
                        HStack {
                            Text(talent.name).font(.body)
                            Spacer()
                            Text("\(talent.value)").font(.system(.body, design: .monospaced))
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onLongPressGesture { activeTalentProbe = talent }
                        Divider()
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
                            Text("PA").font(.system(.caption, weight: .bold))
                            Text("\(ct.pa)").font(.system(.caption, design: .monospaced))
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
            ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                weightRow(name: w.name, weight: w.weight)
            }
            ForEach(hero.shields, id: \.persistentModelID) { s in
                weightRow(name: s.name, weight: s.weight)
            }
            ForEach(hero.armors, id: \.persistentModelID) { a in
                weightRow(name: a.name, weight: a.weight)
            }
            capacityRow
        }
    }

    private func weightRow(name: String, weight: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).font(.body)
                Spacer()
                Text(String(format: "%.2f st", weight))
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }

    @ViewBuilder private var capacityRow: some View {
        let total = hero.totalEquipmentWeight
        let totalCap = hero.totalCarryingCapacity
        let heroCap = hero.carryingCapacity
        let mountCap = hero.mount?.carryingCapacity ?? 0

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                let label = String(format: "%.2f / %d st", total, totalCap)
                if hero.isOverloaded {
                    Text("⚠ " + label).foregroundStyle(.red)
                } else {
                    Text(label)
                }
                Spacer()
            }
            if mountCap > 0 {
                Text("\(heroCap) + \(mountCap) = \(totalCap) st")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                        ("weight", String(format: "%.2f st", w.weight))
                    ])
                    .contentShape(Rectangle())
                    .onLongPressGesture { showCombatMode = true }
                }
            }
        }
    }

    // MARK: - Section 14: Shields

    @ViewBuilder private var shieldSection: some View {
        if !hero.shields.isEmpty {
            CollapsibleSection("Shields") {
                ForEach(hero.shields, id: \.persistentModelID) { s in
                    SubfieldBlock(label: s.name, subfields: [
                        ("structure", "\(s.structure)"),
                        ("breakingFactor", "\(s.breakingFactor)"),
                        ("AT", "\(s.at)"),
                        ("PA", "\(s.pa)"),
                        ("weight", String(format: "%.2f st", s.weight))
                    ])
                    .contentShape(Rectangle())
                    .onLongPressGesture { showCombatMode = true }
                }
            }
        }
    }

    // MARK: - Section 15: Armors

    @ViewBuilder private var armorSection: some View {
        if !hero.armors.isEmpty {
            CollapsibleSection("Armors") {
                ForEach(hero.armors, id: \.persistentModelID) { a in
                    SubfieldBlock(label: a.name, subfields: [
                        ("protectionValue", "\(a.protectionValue)"),
                        ("armorRating", "\(a.armorRating)"),
                        ("encumbrance", "\(a.encumbrance)"),
                        ("weight", String(format: "%.2f st", a.weight))
                    ])
                }
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
                FieldRow(label: "initiative", value: "\(m.initiative)")
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
