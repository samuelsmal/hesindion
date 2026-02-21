import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private let yamlType = UTType(importedAs: "public.yaml")

struct HeroListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hero.name) private var heroes: [Hero]

    @State private var selectedHero: Hero?
    @State private var isShowingFilePicker = false
    @State private var importError: String?
    @State private var isShowingError = false

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .safeAreaInset(edge: .bottom) {
                    importButton
                }
                .navigationTitle("Heroes")
                .navigationDestination(for: Hero.self) { hero in
                    HeroDetailView(hero: hero)
                }
        } detail: {
            detailContent
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.json, yamlType]
        ) { result in
            switch result {
            case .success(let url):
                handleURL(url)
            case .failure:
                showError(HeroImportError.fileReadFailed.errorDescription!)
            }
        }
        .onOpenURL { url in
            handleURL(url)
        }
        .alert("Import Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        if heroes.isEmpty {
            ContentUnavailableView(
                "No Heroes Yet",
                systemImage: "person.3",
                description: Text("Import a JSON or YAML file to add your first hero.")
            )
        } else {
            List(heroes, id: \.persistentModelID, selection: $selectedHero) { hero in
                NavigationLink(value: hero) {
                    Text(hero.name)
                        .font(.system(.title3, design: .default, weight: .bold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let hero = selectedHero {
            HeroDetailView(hero: hero)
        } else {
            ContentUnavailableView(
                heroes.isEmpty ? "No Heroes" : "Select a Hero",
                systemImage: "shield",
                description: Text(
                    heroes.isEmpty
                        ? "Import a JSON or YAML file using the button below to get started."
                        : "Choose a hero from the list to view their character sheet."
                )
            )
        }
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button {
            isShowingFilePicker = true
        } label: {
            Label("Import Hero", systemImage: "square.and.arrow.down")
                .font(.system(.body, design: .default, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.yellow)
                .foregroundStyle(Color.black)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 3)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - File Import

    private func handleURL(_ url: URL) {
        do {
            try HeroImportService().importHero(from: url, context: modelContext)
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
            Armor.self, Shield.self, EquipmentItem.self, Money.self, Mount.self, Language.self,
        configurations: config
    )
    return HeroListView()
        .modelContainer(container)
}
