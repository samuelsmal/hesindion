import SwiftUI
import SwiftData

/// Pure gap logic, unit-tested independently of SwiftUI.
enum StretchPlanner {
    static func isGap(start: AventurianDate, after last: AventurianDate?) -> Bool {
        guard let last else { return false }
        return start.ordinal() > last.ordinal() + 1
    }
}

struct AddStretchSheet: View {
    @Bindable var adventure: Adventure
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var region: WeatherRegion = .mittelreich
    @State private var month: AventurianMonth = .praios
    @State private var day: Int = 1
    @State private var year: Int = 1040
    @State private var dayCount = 7

    private var sortedDays: [WeatherDay] {
        adventure.weatherDays.sorted { $0.date.ordinal() > $1.date.ordinal() }
    }

    var body: some View {
        Form {
            Section { RegionPicker(selection: $region) }
            Section(L("adventureStartDate")) {
                Picker("Monat", selection: $month) {
                    ForEach(AventurianMonth.allCases) { Text($0.displayName).tag($0) }
                }
                Stepper("Tag: \(day)", value: $day, in: 1...month.dayCount)
                Stepper("Jahr: \(year) BF", value: $year, in: 0...9999)
            }
            Section { Stepper("\(L("dayCount")): \(dayCount)", value: $dayCount, in: 1...30) }
        }
        .navigationTitle(L("weather.add"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L("cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("generate")) { generate(); dismiss() }
            }
        }
        .onAppear(perform: seedDefaults)
        .onChange(of: month) { _, m in if day > m.dayCount { day = m.dayCount } }
    }

    private func seedDefaults() {
        let last = sortedDays.first
        region = last?.region ?? adventure.region
        let start = last.map { $0.date.next() } ?? adventure.currentDate
        day = start.day; month = start.month; year = start.year
    }

    private func generate() {
        let start = AventurianDate(day: day, month: month, year: year)
        let last = sortedDays.first
        let gen = WeatherGenerator(region: region)

        // Seed continuity only from a contiguous previous day.
        let contiguous = last.flatMap { l in start.ordinal() == l.date.ordinal() + 1 ? l : nil }
        var previous: WeatherResult? = contiguous.map {
            WeatherResult(date: $0.date, clouds: $0.clouds, wind: $0.wind,
                          dayTemperature: $0.dayTemperature, nightTemperature: $0.nightTemperature, rain: $0.rain)
        }

        var date = start
        for index in 0..<dayCount {
            let result = gen.generate(date: date, previousResult: previous)
            let isJump = (index == 0) && StretchPlanner.isGap(start: start, after: last?.date)
            let weatherDay = WeatherDay(from: result, region: region, isTimeJump: isJump)
            weatherDay.adventure = adventure
            modelContext.insert(weatherDay)
            previous = result
            date = date.next()
        }
        adventure.currentDate = start.adding(days: dayCount)
    }
}
