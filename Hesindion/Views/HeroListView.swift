import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private let yamlType = UTType(importedAs: "public.yaml")

enum SidebarSelection: Hashable {
    case rulebook
    case hero(PersistentIdentifier)
    case rule(String)
}

struct HeroListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hero.name) private var heroes: [Hero]

    @State private var selection: SidebarSelection? = nil
    @State private var previousSelection: SidebarSelection? = nil
    @State private var isShowingFilePicker = false
    @State private var importError: String?
    @State private var isShowingError = false
    @State private var isShowingChangelog = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

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
                            .font(.system(.title2, design: .default, weight: .black))
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
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $selection) {
            Section {
                Label(L("rulebook"), systemImage: "book.closed")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .lineLimit(1)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .tag(SidebarSelection.rulebook)
                    .listRowBackground(
                        selection == .rulebook
                            ? Color.groupRulebook.opacity(0.35)
                            : Color(UIColor.systemBackground)
                    )
            } header: {
                sidebarSectionHeader(L("rulebook"), color: .groupRulebook)
            }

            Section {
                importButton
                    .listRowInsets(EdgeInsets())
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
                                .font(.system(.title3, design: .default, weight: .bold))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .tag(SidebarSelection.hero(hero.persistentModelID))
                        .listRowBackground(
                                selection == .hero(hero.persistentModelID)
                                    ? HeroColorScheme.scheme(for: hero).accentColor.opacity(0.35)
                                    : Color(UIColor.systemBackground)
                            )
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
                .frame(height: DSALayout.secondaryBorder)
            Text(title)
                .font(.system(.subheadline, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(color)
                .frame(height: DSALayout.secondaryBorder)
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
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.dsaBorder, lineWidth: 2)
                )
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .frame(width: size, height: size)
                .background(Color.groupPersonalData.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.dsaBorder, lineWidth: 2)
                )
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .rulebook:
            RulebookView(sidebarSelection: $selection)
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
                .font(.system(.body, design: .default, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .foregroundStyle(.black)
                .overlay(
                    Rectangle()
                        .stroke(Color.dsaBorder, lineWidth: 3)
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Sidebar Footer

    private var sidebarFooter: some View {
        VStack(spacing: 4) {
            Text(appVersion)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)

            Button {
                isShowingChangelog = true
            } label: {
                Text("Changelog")
                    .font(.system(.caption2))
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
            try OptolithImportService().importHero(from: url, context: modelContext)
        } catch {
            showError(error.localizedDescription)
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
