//
//  ContentView.swift
//  Hesindion
//
//  Created by vonbaussnerns on 2026-02-20.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didRepair = false

    var body: some View {
        HeroListView()
            .task {
                guard !didRepair else { return }
                didRepair = true
                DerivedValueRepair.repairAll(in: modelContext)
                SpecialAbilityClassificationRepair.repairAll(
                    in: modelContext,
                    lookupGroupId: RulesDatabase.shared.lookupGroupId
                )
            }
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
    return ContentView()
        .modelContainer(container)
}
