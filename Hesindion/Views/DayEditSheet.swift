import SwiftUI
import SwiftData

struct DayEditSheet: View {
    @Bindable var weatherDay: WeatherDay
    @Environment(\.dismiss) private var dismiss

    @State private var region: WeatherRegion = .mittelreich

    var body: some View {
        Form {
            Section {
                RegionPicker(selection: $region)
                Button(L("weather.reroll")) { reroll(changingRegion: false) }
            }

            Section(L("weather.editValues")) {
                Picker(L("weather.clouds.none"), selection: cloudsBinding) {
                    ForEach(CloudCover.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker(L("weather.wind.none"), selection: windBinding) {
                    ForEach(WindStrength.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Stepper("\(L("weather.dayTemp")): \(weatherDay.dayTemperature)\u{00B0}", value: dayTempBinding, in: -60...60)
                Stepper("\(L("weather.nightTemp")): \(weatherDay.nightTemperature)\u{00B0}", value: nightTempBinding, in: -60...60)
                Picker(L("weather.rain.none"), selection: rainBinding) {
                    ForEach(RainLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
        }
        .navigationTitle(weatherDay.date.formatted())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(L("save")) { dismiss() } }
        }
        .onAppear { region = weatherDay.region }
        .onChange(of: region) { _, _ in reroll(changingRegion: true) }
    }

    // Bindings that flag the field as a manual override on write.
    private var cloudsBinding: Binding<CloudCover> {
        Binding(get: { weatherDay.clouds }, set: { weatherDay.clouds = $0; weatherDay.overrides.insert(.clouds) })
    }
    private var windBinding: Binding<WindStrength> {
        Binding(get: { weatherDay.wind }, set: { weatherDay.wind = $0; weatherDay.overrides.insert(.wind) })
    }
    private var dayTempBinding: Binding<Int> {
        Binding(get: { weatherDay.dayTemperature }, set: { weatherDay.dayTemperature = $0; weatherDay.overrides.insert(.dayTemp) })
    }
    private var nightTempBinding: Binding<Int> {
        Binding(get: { weatherDay.nightTemperature }, set: { weatherDay.nightTemperature = $0; weatherDay.overrides.insert(.nightTemp) })
    }
    private var rainBinding: Binding<RainLevel> {
        Binding(get: { weatherDay.rain }, set: { weatherDay.rain = $0; weatherDay.overrides.insert(.rain) })
    }

    /// Re-generate this day, keeping any manually overridden fields.
    private func reroll(changingRegion: Bool) {
        if changingRegion { weatherDay.region = region }
        let gen = WeatherGenerator(region: region)
        let result = gen.generate(date: weatherDay.date, previousResult: nil)
        let o = weatherDay.overrides
        if !o.contains(.clouds) { weatherDay.clouds = result.clouds }
        if !o.contains(.wind) { weatherDay.wind = result.wind }
        if !o.contains(.dayTemp) { weatherDay.dayTemperature = result.dayTemperature }
        if !o.contains(.nightTemp) { weatherDay.nightTemperature = result.nightTemperature }
        if !o.contains(.rain) { weatherDay.rain = result.rain }
    }
}
