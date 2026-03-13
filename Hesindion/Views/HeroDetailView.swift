import SwiftUI
import SwiftData

// MARK: - HeroDetailView

struct HeroDetailView: View {
    let hero: Hero
    @Binding var sidebarSelection: SidebarSelection?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var activeEdit: ActiveEdit?
    @State private var showCommandSearch = false
    @State private var activeCommand: AppCommand?
    @State private var commandQuery = ""
    @FocusState private var searchFocused: Bool
    @State private var activeTalentProbe: Talent? = nil
    @State private var lookupRuleId: String?
    @State private var showCombatMode = false
    @State private var showRegenerierenSheet = false

    var body: some View {
        ZStack {
            if let attrs = hero.attributes, sizeClass == .regular {
                HStack(spacing: 0) {
                    AttributesColumn(attrs: attrs)
                    ScrollView {
                        LazyVStack {
                            nameHeading
                            groupsContent
                        }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y + geo.contentInsets.top
                    } action: { _, y in
                        if y < -120 && !showCommandSearch {
                            showCommandSearch = true
                            commandQuery = ""
                            searchFocused = true
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(pinnedViews: [.sectionHeaders]) {
                        nameHeading
                        if let attrs = hero.attributes {
                            SwiftUI.Section {
                                groupsContent
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
                    if y < -120 && !showCommandSearch {
                        showCommandSearch = true
                        commandQuery = ""
                        searchFocused = true
                    }
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
        .sheet(isPresented: Binding(
            get: { lookupRuleId != nil },
            set: { if !$0 { lookupRuleId = nil } }
        )) {
            if let ruleId = lookupRuleId {
                RuleDetailView(
                    ruleId: ruleId,
                    sidebarSelection: .constant(nil),
                    previousSelection: nil
                )
                .presentationCornerRadius(0)
            }
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

    // MARK: - Extracted Layout Components

    @ViewBuilder private var nameHeading: some View {
        Text(hero.name)
            .font(.system(.largeTitle, design: .default, weight: .black))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupPersonalData)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    @ViewBuilder private var groupsContent: some View {
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
                    rangedWeaponsSection
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
                    petsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 16)
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
                                label: L("current"),
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
                                label: L("current"),
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
                                label: L("current"),
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
                                label: L("current"),
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
                if dv.ausweichen.max > 0 {
                    FieldRow(label: "ausweichen", value: hero.belastungPenalty != 0 ? "\(dv.ausweichen.max) (\(hero.belastungPenalty))" : "\(dv.ausweichen.max)")
                }
                if dv.initiative.max > 0 {
                    FieldRow(label: "initiative", value: hero.totalIniPenalty != 0 ? "\(dv.initiative.max) (\(hero.totalIniPenalty))" : "\(dv.initiative.max)")
                }
                if dv.geschwindigkeit.max > 0 {
                    FieldRow(label: "geschwindigkeit", value: hero.totalGsPenalty != 0 ? "\(dv.geschwindigkeit.max) (\(hero.totalGsPenalty))" : "\(dv.geschwindigkeit.max)")
                }
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
                ForEach(hero.advantages, id: \.self) { trait in
                    SwipeActionRow(label: traitDisplay(trait), value: "", actions: lookupActions(for: trait))
                    Divider()
                }
            }
        }
    }

    // MARK: - Section 5: Disadvantages

    @ViewBuilder private var disadvantagesSection: some View {
        if !hero.disadvantages.isEmpty {
            CollapsibleSection(L("disadvantages")) {
                ForEach(hero.disadvantages, id: \.self) { trait in
                    SwipeActionRow(label: traitDisplay(trait), value: "", actions: lookupActions(for: trait))
                    Divider()
                }
            }
        }
    }

    // MARK: - Section 6: GeneralSpecialAbilities

    @ViewBuilder private var generalSpecialAbilitiesSection: some View {
        if !hero.generalSpecialAbilities.isEmpty {
            CollapsibleSection(L("generalSpecialAbilities")) {
                ForEach(hero.generalSpecialAbilities, id: \.self) { trait in
                    SwipeActionRow(label: traitDisplay(trait), value: "", actions: lookupActions(for: trait))
                    Divider()
                }
            }
        }
    }

    private func traitDisplay(_ trait: HeroTrait) -> String {
        var result = trait.name
        if let tier = trait.tier {
            result += " (\(L("tierPrefix")) \(tier))"
        }
        if let sid = trait.sid {
            result += ": \(sid)"
        }
        return result
    }

    private func lookupActions(for trait: HeroTrait) -> [SwipeAction] {
        guard let rule = RulesDatabase.shared.lookup(id: trait.ruleId) else { return [] }
        return [SwipeAction(icon: "book.closed", color: .groupRulebook) {
            lookupRuleId = rule.id
        }]
    }

    private func lookupActions(for name: String) -> [SwipeAction] {
        guard let rule = RulesDatabase.shared.lookupByName(name) else { return [] }
        return [SwipeAction(icon: "book.closed", color: .groupRulebook) {
            lookupRuleId = rule.id
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
        "Körpertalente", "Gesellschaftstalente", "Naturtalente",
        "Wissenstalente", "Handwerkstalente"
    ]

    @ViewBuilder private var talentsSections: some View {
        let grouped = Dictionary(grouping: hero.talents, by: \.category)
        ForEach(talentCategoryOrder, id: \.self) { category in
            if let items = grouped[category], !items.isEmpty {
                CollapsibleSection(category) {
                    ForEach(items, id: \.persistentModelID) { talent in
                        SwipeActionRow(actions: talentActions(for: talent)) {
                            TalentSwipeContent(
                                name: talent.name,
                                value: talent.value,
                                probeKeys: TalentProbeAttributes.checks[talent.name]
                            )
                        }
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
                lookupRuleId = rule.id
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
                            if hero.belastungPenalty != 0 {
                                Text("\(ct.at) (\(hero.belastungPenalty))").font(.system(.caption, design: .monospaced))
                            } else {
                                Text("\(ct.at)").font(.system(.caption, design: .monospaced))
                            }
                            Text("PA").font(.system(.caption, weight: .bold))
                            if ct.pa > 0 && hero.belastungPenalty != 0 {
                                Text("\(ct.pa) (\(hero.belastungPenalty))").font(.system(.caption, design: .monospaced))
                            } else {
                                Text("\(ct.pa)").font(.system(.caption, design: .monospaced))
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
            CollapsibleSection(L("combatSpecialAbilities")) {
                ForEach(hero.combatSpecialAbilities, id: \.self) { trait in
                    SwipeActionRow(label: traitDisplay(trait), value: "", actions: lookupActions(for: trait))
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
            ForEach(hero.rangedWeapons, id: \.persistentModelID) { w in
                weightRow(name: w.name, weight: w.weight)
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
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }

    @ViewBuilder private var capacityRow: some View {
        let total = hero.totalEquipmentWeight
        let totalCap = hero.totalCarryingCapacity
        let heroCap = hero.carryingCapacity
        let petsCap = hero.pets.reduce(0) { $0 + $1.carryingCapacity }

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
            if petsCap > 0 {
                Text("\(heroCap) + \(petsCap) = \(totalCap) st")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.leading, 24)
        .padding(.trailing, 12)
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
                            ("combatTechnique", RulesDatabase.shared.lookup(id: w.combatTechniqueId)?.name ?? w.combatTechniqueId),
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

    // MARK: - Section 13b: RangedWeapons

    @ViewBuilder private var rangedWeaponsSection: some View {
        if !hero.rangedWeapons.isEmpty {
            CollapsibleSection(L("rangedWeapons")) {
                ForEach(hero.rangedWeapons, id: \.persistentModelID) { w in
                    SwipeActionRow(
                        actions: [SwipeAction(icon: "bolt.fill", color: .groupCombat) { showCombatMode = true }]
                    ) {
                        SubfieldBlock(label: w.name, subfields: [
                            ("combatTechnique", RulesDatabase.shared.lookup(id: w.combatTechniqueId)?.name ?? w.combatTechniqueId),
                            ("damage", w.damage),
                            ("FK", "\(w.at)"),
                            ("range", w.range),
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
                            ("damage", s.damage),
                            ("AT", "\(s.at)"),
                            ("PA", "\(s.pa)"),
                            ("reach", s.reach),
                            ("SP", "\(s.structurePoints)"),
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
                    SwipeActionRow(
                        actions: [
                            SwipeAction(
                                icon: a.isEquipped ? "xmark.circle.fill" : "checkmark.circle.fill",
                                color: a.isEquipped ? .red : .green
                            ) {
                                a.isEquipped.toggle()
                            }
                        ]
                    ) {
                        HStack {
                            SubfieldBlock(label: a.name, subfields: [
                                ("protectionValue", "RS \(a.protectionValue)"),
                                ("encumbrance", "BE \(a.encumbrance)"),
                                ("weight", String(format: "%.2f st", a.weight))
                            ])
                            if a.isEquipped {
                                Text(L("equipped"))
                                    .font(.system(.caption2, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.groupCombat)
                            }
                        }
                    }
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

    // MARK: - Section 17: Pets

    @ViewBuilder private var petsSection: some View {
        if !hero.pets.isEmpty {
            CollapsibleSection(L("pets")) {
                ForEach(hero.pets, id: \.persistentModelID) { pet in
                    VStack(spacing: 0) {
                        HStack {
                            Text(pet.name).font(.system(.body, weight: .semibold))
                            Spacer()
                            Text(pet.type).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        SubfieldBlock(label: L("attributes"), subfields: [
                            ("MU", "\(pet.attributes.mu)"),
                            ("KL", "\(pet.attributes.kl)"),
                            ("IN", "\(pet.attributes.inValue)"),
                            ("CH", "\(pet.attributes.ch)"),
                            ("FF", "\(pet.attributes.ff)"),
                            ("GE", "\(pet.attributes.ge)"),
                            ("KO", "\(pet.attributes.ko)"),
                            ("KK", "\(pet.attributes.kk)")
                        ])

                        SubfieldBlock(label: L("combat"), subfields: [
                            ("LE", "\(pet.lifeEnergy)"),
                            ("INI", pet.initiative),
                            ("GS", "\(pet.speed)"),
                            ("AT", pet.attack),
                            ("TP", pet.damage),
                            ("RW", pet.reach),
                            ("AK", "\(pet.actions)")
                        ])

                        if !pet.talents.isEmpty {
                            FieldRow(label: "talents", value: pet.talents)
                        }
                        if !pet.skills.isEmpty {
                            FieldRow(label: "skills", value: pet.skills)
                        }
                        if !pet.notes.isEmpty {
                            FieldRow(label: "notes", value: pet.notes)
                        }

                        Divider()
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

/// Talent row content showing name, probe abbreviations, and value.
struct TalentSwipeContent: View {
    let name: String
    let value: Int
    let probeKeys: [String]?

    var body: some View {
        HStack(spacing: 0) {
            Text(L(name)).font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let keys = probeKeys {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.attributeForeground(for: key))
                        .frame(width: 32, height: 24)
                        .background(Color.attributeBackground(for: key).opacity(0.7))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }
            }
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 36, alignment: .trailing)
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
            RangedWeapon.self, Armor.self, Shield.self, EquipmentItem.self, Money.self,
            Pet.self, Language.self, HeroSpell.self,
        configurations: config
    )
    let hero = Hero(name: "Boronmir Siebenfeld von Ferdok")
    container.mainContext.insert(hero)
    return NavigationStack {
        HeroDetailView(hero: hero, sidebarSelection: $selection)
    }
    .modelContainer(container)
}
