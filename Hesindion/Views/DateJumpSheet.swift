import SwiftUI
import SwiftData

struct DateJumpSheet: View {
    @Bindable var adventure: Adventure
    @Environment(\.dismiss) private var dismiss

    @State private var month: AventurianMonth = .praios
    @State private var day: Int = 1
    @State private var year: Int = 1040

    var body: some View {
        Form {
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
        .navigationTitle(L("setDate"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("setDate")) {
                    adventure.currentDate = AventurianDate(day: day, month: month, year: year)
                    dismiss()
                }
            }
        }
        .onAppear {
            month = adventure.currentMonth
            day = adventure.currentDay
            year = adventure.currentYear
        }
        .onChange(of: month) { _, newMonth in
            if day > newMonth.dayCount { day = newMonth.dayCount }
        }
    }
}
