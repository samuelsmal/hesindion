//
//  ContentView.swift
//  iDSACompanion
//
//  Created by vonbaussnerns on 2026-02-20.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HeroListView()
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
    return ContentView()
        .modelContainer(container)
}
