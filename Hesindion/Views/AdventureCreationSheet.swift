import SwiftUI
import SwiftData

struct AdventureCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var region: WeatherRegion = .mittelreich
    @State private var month: AventurianMonth = .praios
    @State private var day: Int = 1
    @State private var year: Int = 1040
    @State private var desert = false
    @State private var windy = false

    var body: some View {
        Form {
            Section {
                TextField(L("adventureName"), text: $name)
                    .font(.system(.body, weight: .bold))
            }

            Section {
                Picker(L("adventureRegion"), selection: $region) {
                    ForEach(WeatherRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                Toggle(L("adventureDesert"), isOn: $desert)
                Toggle(L("adventureWindy"), isOn: $windy)
            }

            Section(L("adventureStartDate")) {
                Picker("Monat", selection: $month) {
                    ForEach(AventurianMonth.allCases) { month in
                        Text(month.displayName).tag(month)
                    }
                }
                Stepper("Tag: \(day)", value: $day, in: 1...month.dayCount)
                Stepper("Jahr: \(year) BF", value: $year, in: 0...9999)
            }
        }
        .navigationTitle(L("newAdventure"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("create")) {
                    let adventure = Adventure(
                        name: name,
                        region: region,
                        startDate: AventurianDate(day: day, month: month, year: year),
                        desert: desert,
                        windy: windy
                    )
                    modelContext.insert(adventure)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: month) { _, newMonth in
            if day > newMonth.dayCount { day = newMonth.dayCount }
        }
    }
}
