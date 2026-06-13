import SwiftUI

struct WeatherRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("weather.rules.body"))
                    .font(.system(.body))
                ruleLine("cloud", L("weather.rules.clouds"))
                ruleLine("wind", L("weather.rules.wind"))
                ruleLine("globe.europe.africa", L("weather.rules.climate"))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L("weather.rules.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("cancel")) { dismiss() }
            }
        }
    }

    private func ruleLine(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.groupAdventure).frame(width: 22)
            Text(text).font(.system(.subheadline, weight: .medium))
        }
    }
}
