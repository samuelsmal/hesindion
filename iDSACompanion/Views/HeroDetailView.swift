import SwiftUI
import SwiftData

// MARK: - HeroDetailView

struct HeroDetailView: View {
    let hero: Hero
    @Binding var sidebarSelection: SidebarSelection?
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
                        .background(Color.groupPersonalData)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if let attrs = hero.attributes {
                        SwiftUI.Section {
                            VStack(spacing: 0) {
                                CollapsibleGroup(L("groupPersonalData"), color: .groupPersonalData) {
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

                                CollapsibleGroup(L("groupTalents"), color: .groupTalents, textColor: .white) {
                                    VStack(spacing: 8) {
                                        talentsSections
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }

                                CollapsibleGroup(L("groupCombat"), color: .groupCombat) {
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

                                CollapsibleGroup(L("groupEquipment"), color: .groupEquipment, textColor: .white) {
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
                        sidebarSelection: $sidebarSelection,
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
            CollapsibleSection(L("experience")) {
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
            CollapsibleSection(L("personalData")) {
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
            CollapsibleSection(L("derivedValues")) {
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
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            SwipeActionRow(
                label: label,
                value: primary,
                actions: [SwipeAction(icon: "pencil", color: .groupPersonalData) { onEdit() }]
            )

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
            CollapsibleSection(L("advantages")) {
                ForEach(hero.advantages, id: \.self) { item in
                    SwipeActionRow(label: item, value: "", actions: lookupActions(for: item))
                    Divider()
                }
            }
        }
    }

    // MARK: - Section 5: Disadvantages

    @ViewBuilder private var disadvantagesSection: some View {
        if !hero.disadvantages.isEmpty {
            CollapsibleSection(L("disadvantages")) {
                ForEach(hero.disadvantages, id: \.self) { item in
                    SwipeActionRow(label: item, value: "", actions: lookupActions(for: item))
                    Divider()
                }
            }
        }
    }

    // MARK: - Section 6: GeneralSpecialAbilities

    @ViewBuilder private var generalSpecialAbilitiesSection: some View {
        if !hero.generalSpecialAbilities.isEmpty {
            CollapsibleSection(L("generalSpecialAbilities")) {
                ForEach(hero.generalSpecialAbilities, id: \.self) { item in
                    SwipeActionRow(label: item, value: "", actions: lookupActions(for: item))
                    Divider()
                }
            }
        }
    }

    private func lookupActions(for name: String) -> [SwipeAction] {
        guard let rule = RulesDatabase.shared.lookupByName(name) else { return [] }
        return [SwipeAction(icon: "book.closed", color: .groupRulebook) {
            sidebarSelection = .rule(rule.id)
        }]
    }

    // MARK: - Section 7: Languages

    @ViewBuilder private var languagesSection: some View {
        if !hero.languages.isEmpty {
            CollapsibleSection(L("languages")) {
                ForEach(hero.languages, id: \.persistentModelID) { lang in
                    FieldRow(label: lang.name, value: lang.level)
                }
            }
        }
    }

    // MARK: - Section 8: Scripts

    @ViewBuilder private var scriptsSection: some View {
        if !hero.scripts.isEmpty {
            CollapsibleSection(L("scripts")) {
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
                        SwipeActionRow(
                            label: talent.name,
                            value: "\(talent.value)",
                            actions: talentActions(for: talent)
                        )
                        Divider()
                    }
                }
            }
        }
    }

    private func talentActions(for talent: Talent) -> [SwipeAction] {
        var actions: [SwipeAction] = []
        if let rule = RulesDatabase.shared.lookupByName(talent.name) {
            actions.append(SwipeAction(icon: "book.closed", color: .groupRulebook) {
                sidebarSelection = .rule(rule.id)
            })
        }
        actions.append(SwipeAction(icon: "dice.fill", color: .groupCombat) {
            activeTalentProbe = talent
        })
        return actions
    }

    // MARK: - Section 10: CombatTechniques

    @ViewBuilder private var combatTechniquesSection: some View {
        if !hero.combatTechniques.isEmpty {
            CollapsibleSection(L("combatTechniques")) {
                ForEach(hero.combatTechniques, id: \.persistentModelID) { ct in
                    VStack(spacing: 0) {
                        SwipeActionRow(
                            label: ct.name,
                            value: "\(ct.value)",
                            actions: lookupActions(for: ct.name)
                        )

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
            CollapsibleSection(L("combatSpecialAbilities")) {
                ForEach(hero.combatSpecialAbilities, id: \.self) { item in
                    SwipeActionRow(label: item, value: "", actions: lookupActions(for: item))
                    Divider()
                }
            }
        }
    }

    // MARK: - Section 12: Equipment

    @ViewBuilder private var equipmentSection: some View {
        CollapsibleSection(L("equipment")) {
            ForEach(hero.equipment, id: \.persistentModelID) { item in
                SwipeActionRow(
                    label: item.name,
                    value: String(format: "%.2f st", item.weight),
                    actions: [SwipeAction(icon: "trash", color: .red) { modelContext.delete(item) }]
                )
                Divider()
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
            CollapsibleSection(L("meleeWeapons")) {
                ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                    SwipeActionRow(
                        actions: [SwipeAction(icon: "bolt.fill", color: .groupCombat) { showCombatMode = true }]
                    ) {
                        SubfieldBlock(label: w.name, subfields: [
                            ("technique", w.technique),
                            ("damage", w.damage),
                            ("AT", "\(w.at)"),
                            ("PA", "\(w.pa)"),
                            ("reach", w.reach),
                            ("weight", String(format: "%.2f st", w.weight))
                        ])
                    }
                }
            }
        }
    }

    // MARK: - Section 14: Shields

    @ViewBuilder private var shieldSection: some View {
        if !hero.shields.isEmpty {
            CollapsibleSection(L("shields")) {
                ForEach(hero.shields, id: \.persistentModelID) { s in
                    SwipeActionRow(
                        actions: [SwipeAction(icon: "bolt.fill", color: .groupCombat) { showCombatMode = true }]
                    ) {
                        SubfieldBlock(label: s.name, subfields: [
                            ("structure", "\(s.structure)"),
                            ("breakingFactor", "\(s.breakingFactor)"),
                            ("AT", "\(s.at)"),
                            ("PA", "\(s.pa)"),
                            ("weight", String(format: "%.2f st", s.weight))
                        ])
                    }
                }
            }
        }
    }

    // MARK: - Section 15: Armors

    @ViewBuilder private var armorSection: some View {
        if !hero.armors.isEmpty {
            CollapsibleSection(L("armor")) {
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
            CollapsibleSection(L("money")) {
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
            SwipeActionRow(
                label: label,
                value: "\(get())",
                actions: [SwipeAction(icon: "pencil", color: .groupEquipment) {
                    activeEdit = ActiveEdit(label: label, max: Int.max - 1, getCurrent: get, setCurrent: set)
                }]
            )
            Divider()
        }
    }

    // MARK: - Section 17: Mount

    @ViewBuilder private var mountSection: some View {
        if let m = hero.mount {
            CollapsibleSection(L("mount")) {
                FieldRow(label: "mountName", value: m.name)
                FieldRow(label: "mountType", value: m.mountType)
                FieldRow(label: "mountSize", value: String(format: "%.1f", m.size))
                FieldRow(label: "mountLifeEnergy", value: "\(m.lifeEnergy)")
                FieldRow(label: "mountInitiative", value: "\(m.initiative)")
                FieldRow(label: "mountSpeed", value: "\(m.speed)")

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
                            Text(L("mountAttacks")).font(.system(.body, weight: .semibold))
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
                            Text(L("mountTalents")).font(.system(.body, weight: .semibold))
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
                            Text(L("mountSpecialAbilities")).font(.system(.body, weight: .semibold))
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

// MARK: - SwipeActionRow

struct SwipeAction {
    let icon: String
    let color: Color
    let action: () -> Void
}

private struct SwipeActionRow<Content: View>: View {
    let actions: [SwipeAction]
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var settled: Bool = false
    @State private var dragDirection: DragDirection = .undecided

    private var revealWidth: CGFloat { CGFloat(actions.count) * 56 }
    private let triggerThreshold: CGFloat = 120

    private enum DragDirection { case undecided, horizontal, vertical }

    /// Convenience initializer for simple label/value rows.
    init(label: String, value: String, actions: [SwipeAction]) where Content == DefaultSwipeContent {
        self.actions = actions
        self.content = DefaultSwipeContent(label: label, value: value)
    }

    /// Generic initializer for arbitrary content.
    init(actions: [SwipeAction], @ViewBuilder content: () -> Content) {
        self.actions = actions
        self.content = content()
    }

    var body: some View {
        if actions.isEmpty {
            foregroundContent
        } else {
            ZStack(alignment: .trailing) {
                // Background action buttons
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        Button {
                            withAnimation(DSAAnimation.standard) { offset = 0 }
                            settled = false
                            action.action()
                        } label: {
                            Image(systemName: action.icon)
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56)
                        }
                        .buttonStyle(.plain)
                        .background(action.color)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(actions.last?.color ?? .gray)

                foregroundContent
                    .offset(x: offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 16)
                            .onChanged { value in
                                guard !settled else { return }
                                if dragDirection == .undecided {
                                    let dx = abs(value.translation.width)
                                    let dy = abs(value.translation.height)
                                    if dx > dy * 1.5 && value.translation.width < 0 {
                                        dragDirection = .horizontal
                                    } else if dy > dx {
                                        dragDirection = .vertical
                                    }
                                }
                                if dragDirection == .horizontal {
                                    offset = min(0, value.translation.width)
                                }
                            }
                            .onEnded { value in
                                defer { dragDirection = .undecided }
                                guard !settled, dragDirection == .horizontal else { return }
                                if -offset > triggerThreshold, let last = actions.last {
                                    withAnimation(DSAAnimation.standard) { offset = 0 }
                                    last.action()
                                } else if -offset > revealWidth / 2 {
                                    withAnimation(DSAAnimation.standard) { offset = -revealWidth }
                                    settled = true
                                } else {
                                    withAnimation(DSAAnimation.standard) { offset = 0 }
                                }
                            }
                    )
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if settled {
                    withAnimation(DSAAnimation.standard) { offset = 0 }
                    settled = false
                }
            }
        }
    }

    private var foregroundContent: some View {
        content
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
    }
}

/// Default content for SwipeActionRow label/value variant.
struct DefaultSwipeContent: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(L(label)).font(.body)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(.body, design: .monospaced))
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selection: SidebarSelection? = nil
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
        HeroDetailView(hero: hero, sidebarSelection: $selection)
    }
    .modelContainer(container)
}
