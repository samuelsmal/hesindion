import SwiftUI
import SwiftData

struct HeroDetailView: View {
    let hero: Hero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(hero.name)
                    .font(.system(.largeTitle, design: .default, weight: .black))
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow)
                    .overlay(
                        Rectangle()
                            .stroke(Color.black, lineWidth: 3)
                    )

                Text("Hero detail view coming in spec 002.")
                    .font(.system(.body, design: .monospaced))
                    .padding(20)
            }
            .padding(16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground))
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
    let hero = Hero(name: "Boronmir Siebenfeld von Ferdok")
    container.mainContext.insert(hero)
    return NavigationStack {
        HeroDetailView(hero: hero)
    }
    .modelContainer(container)
}
