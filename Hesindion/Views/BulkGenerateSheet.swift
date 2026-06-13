import SwiftUI
import SwiftData

struct BulkGenerateSheet: View {
    @Bindable var adventure: Adventure
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var dayCount = 7

    var body: some View {
        Form {
            Stepper("\(L("dayCount")): \(dayCount)", value: $dayCount, in: 1...30)
        }
        .navigationTitle(L("generateDays"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("generate")) {
                    generateDays()
                    dismiss()
                }
            }
        }
    }

    private func generateDays() {
        let gen = WeatherGenerator(region: adventure.region)

        // Check if first day should be marked as time jump
        let lastDay = adventure.weatherDays.sorted(by: { $0.generatedAt < $1.generatedAt }).last

        let results = gen.generateBatch(startDate: adventure.currentDate, count: dayCount)
        for (index, result) in results.enumerated() {
            let weatherDay = WeatherDay(from: result, region: adventure.region)
            if index == 0, let lastDay = lastDay {
                let expectedNext = lastDay.date.next()
                if result.date != expectedNext {
                    weatherDay.isTimeJump = true
                }
            }
            weatherDay.adventure = adventure
            modelContext.insert(weatherDay)
        }
        var date = adventure.currentDate
        for _ in 0..<dayCount { date = date.next() }
        adventure.currentDate = date
    }
}
