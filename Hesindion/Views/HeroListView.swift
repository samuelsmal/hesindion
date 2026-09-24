import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private let yamlType = UTType(importedAs: "public.yaml")

enum SidebarSelection: Hashable {
    case rulebook
    case adventure(PersistentIdentifier)
    case hero(PersistentIdentifier)
    case rule(String)
}

struct HeroListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hero.name) private var heroes: [Hero]
    @Query(sort: \Adventure.createdAt, order: .reverse) private var adventures: [Adventure]

    @State private var selection: SidebarSelection? = nil
    @State private var previousSelection: SidebarSelection? = nil
    @State private var isShowingFilePicker = false
    @State private var importError: String?
    @State private var isShowingError = false
    @State private var importResult: HeroImportResult?
    @State private var isShowingChangelog = false
    @State private var isShowingAdventureCreation = false

    /// A re-import waiting on the companion question: the file, the pets still to
    /// ask about (in `petsInOrder` order) and the ones already kept.
    private struct PendingReimport {
        let data: Data
        var remaining: [String]
        var keep: Set<String> = []
    }
    @State private var pendingReimport: PendingReimport?

    private var appVersion: String { AppVersion.display }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .safeAreaInset(edge: .bottom) {
                    sidebarFooter
                }
                .navigationTitle("Hesindion")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Hesindion")
                            .font(.dsaHeading(.title2))
                    }
                }
        } detail: {
            detailContent
        }
        .onChange(of: selection) { oldValue, newValue in
            if case .rule = newValue, oldValue != nil {
                previousSelection = oldValue
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.json, yamlType]
        ) { result in
            switch result {
            case .success(let url):
                handleURL(url)
            case .failure:
                showError(OptolithImportError.fileReadFailed.errorDescription!)
            }
        }
        .onOpenURL { url in
            handleURL(url)
        }
        .alert(L("importError"), isPresented: $isShowingError) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(importError ?? L("unknownError"))
        }
        .alert(
            importResultTitle,
            isPresented: Binding(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } }
            )
        ) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .sheet(isPresented: $isShowingAdventureCreation) {
            NavigationStack {
                AdventureCreationSheet()
            }
        }
        .overlay {
            if let name = pendingReimport?.remaining.first {
                DSAModal(title: String(format: L("companion.reimport.title"), name),
                         accent: .groupEquipment) {
                    Text(L("companion.reimport.message"))
                        .font(.dsaBody(.subheadline))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DSAModalButton(title: L("companion.reimport.keep"), accent: .groupEquipment,
                                   identifier: "companion.reimport.keep") {
                        answerReimport(keep: true)
                    }
                    DSAOrDivider()
                    DSAModalButton(title: L("companion.reimport.discard"), accent: .groupEquipment,
                                   identifier: "companion.reimport.discard") {
                        answerReimport(keep: false)
                    }
                    DSAModalButton(title: L("companion.reimport.cancel"), accent: .groupEquipment,
                                   filled: false, identifier: "companion.reimport.cancel") {
                        pendingReimport = nil
                    }
                }
            }
        }
        .onAppear {
            if DebugLaunch.loadDefault, selection == nil, let first = heroes.first {
                selection = .hero(first.persistentModelID)
            }
            if let url = UITestSeed.reimportFixtureURL {
                handleURL(url)
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed")
                    Text(L("rulebook"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                    .font(.dsaHeading(.title3))
                    .sidebarRow(
                        accent: .groupRulebook,
                        isSelected: selection == .rulebook
                    ) { selection = .rulebook }
            } header: {
                sidebarSectionHeader(L("rulebook"), color: .groupRulebook)
            }

            Section {
                Button {
                    isShowingAdventureCreation = true
                } label: {
                    Label(L("newAdventure"), systemImage: "plus")
                        .font(.dsaHeading(.body))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.black)
                        .dsaBox(.raised, fill: .groupAdventure)
                }
                .buttonStyle(.dsaMotion)
                // Room for the shadow: it draws outside the bounds and reserves
                // no layout space, so a flush row would clip it (ADR-0008).
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 16))
                .listRowBackground(Color(UIColor.systemBackground))

                ForEach(adventures, id: \.persistentModelID) { adventure in
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.sun")
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(Color.groupAdventure.opacity(0.2))
                            .clipShape(Rectangle())
                            .dsaBox(.flush)
                        Text(adventure.name)
                            .font(.dsaHeading(.title3))
                        Spacer(minLength: 0)
                    }
                    .sidebarRow(
                        accent: .groupAdventure,
                        isSelected: selection == .adventure(adventure.persistentModelID)
                    ) { selection = .adventure(adventure.persistentModelID) }
                }
            } header: {
                sidebarSectionHeader(L("adventures"), color: .groupAdventure)
            }

            Section {
                importButton
                    // Room for the shadow — see the newAdventure button above.
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 16))
                    .listRowBackground(Color(UIColor.systemBackground))

                if heroes.isEmpty {
                    Text(L("importHint"))
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color(UIColor.systemBackground))
                } else {
                    ForEach(heroes, id: \.persistentModelID) { hero in
                        HStack(spacing: 12) {
                            heroAvatar(hero)
                            Text(hero.name)
                                .font(.dsaHeading(.title3))
                            Spacer(minLength: 0)
                        }
                        // Each hero keeps its own profession accent, so the
                        // sidebar carries the same identity the detail pane does.
                        .sidebarRow(
                            accent: HeroColorScheme.scheme(for: hero).accentColor,
                            isSelected: selection == .hero(hero.persistentModelID)
                        ) { selection = .hero(hero.persistentModelID) }
                    }
                }
            } header: {
                sidebarSectionHeader(L("heroes"), color: .groupPersonalData)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
    }

    private func sidebarSectionHeader(_ title: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(height: DSALayout.border)
            Text(title)
                .font(.dsaHeading(.subheadline))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(color)
                .frame(height: DSALayout.border)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func heroAvatar(_ hero: Hero) -> some View {
        let size: CGFloat = 36
        if let data = hero.avatar, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Rectangle())
                .dsaBox(.flush)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .frame(width: size, height: size)
                .background(Color.groupPersonalData.opacity(0.2))
                .clipShape(Rectangle())
                .dsaBox(.flush)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .rulebook:
            RulebookView(sidebarSelection: $selection)
        case .adventure(let id):
            if let adventure = adventures.first(where: { $0.persistentModelID == id }) {
                AdventureDetailView(adventure: adventure)
            }
        case .hero(let id):
            if let hero = heroes.first(where: { $0.persistentModelID == id }) {
                HeroDetailView(hero: hero, sidebarSelection: $selection)
            }
        case .rule(let ruleId):
            RuleDetailView(
                ruleId: ruleId,
                sidebarSelection: $selection,
                previousSelection: previousSelection
            )
        case nil:
            ContentUnavailableView(
                heroes.isEmpty ? L("noHeroes") : "Auswahl treffen",
                systemImage: "shield",
                description: Text(
                    heroes.isEmpty
                        ? L("importHint")
                        : L("selectHint")
                )
            )
        }
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button {
            isShowingFilePicker = true
        } label: {
            Label(L("importHero"), systemImage: "square.and.arrow.down")
                .font(.dsaHeading(.body))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.black)
                .dsaBox(.raised, fill: .groupPersonalData)
        }
        .buttonStyle(.dsaMotion)
    }

    // MARK: - Sidebar Footer

    private var sidebarFooter: some View {
        VStack(spacing: 4) {
            Text(appVersion)
                .font(.dsaMono(.caption, emphasis: true))
                .foregroundStyle(.tertiary)

            Button {
                isShowingChangelog = true
            } label: {
                Text("Changelog")
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.quaternary)
            }
            .sheet(isPresented: $isShowingChangelog) {
                NavigationStack {
                    ChangelogView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L("ok")) {
                                    isShowingChangelog = false
                                }
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - File Import

    private func handleURL(_ url: URL) {
        do {
            let service = OptolithImportService()
            let data = try service.readData(from: url)
            let conflicts = try service.companionConflicts(in: data, context: modelContext)
            if conflicts.isEmpty {
                importResult = try service.importHero(from: data, context: modelContext)
            } else {
                pendingReimport = PendingReimport(data: data, remaining: conflicts)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func answerReimport(keep: Bool) {
        guard var pending = pendingReimport, let name = pending.remaining.first else { return }
        if keep { pending.keep.insert(name) }
        pending.remaining.removeFirst()
        guard pending.remaining.isEmpty else {
            pendingReimport = pending
            return
        }
        pendingReimport = nil
        do {
            importResult = try OptolithImportService().importHero(from: pending.data, context: modelContext,
                                                                  keepingCompanionDataFor: pending.keep)
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// A re-import replaces the hero with the same name in place, so without
    /// this the player could not tell it from adding a second hero.
    private var importResultTitle: String {
        switch importResult {
        case .updated: L("import.updated.title")
        case .created, nil: L("import.created.title")
        }
    }

    private var importResultMessage: String {
        switch importResult {
        case .updated(let name): String(format: L("import.updated.message"), name)
        case .created(let name): String(format: L("import.created.message"), name)
        case nil: ""
        }
    }

    private func showError(_ message: String) {
        importError = message
        isShowingError = true
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Hero.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self, MeleeWeapon.self,
            Armor.self, Shield.self, EquipmentItem.self, Money.self, Pet.self, Language.self, HeroSpell.self,
        configurations: config
    )
    return HeroListView()
        .modelContainer(container)
}
