import SwiftUI

struct WeatherDayRow: View {
    let weatherDay: WeatherDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weatherDay.date.formatted())
                .font(.system(.caption, design: .monospaced, weight: .black))
                .foregroundStyle(Color.groupAdventure)

            HStack(spacing: 16) {
                weatherItem(icon: "cloud", text: weatherDay.clouds.displayName)
                weatherItem(icon: "wind", text: weatherDay.wind.displayName)
            }

            HStack(spacing: 16) {
                weatherItem(icon: "thermometer.sun", text: "\(L("weather.dayTemp")): \(weatherDay.dayTemperature)\u{00B0}")
                weatherItem(icon: "thermometer.snowflake", text: "\(L("weather.nightTemp")): \(weatherDay.nightTemperature)\u{00B0}")
            }

            weatherItem(icon: "cloud.rain", text: weatherDay.rain.displayName)
        }
        .padding(DSALayout.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        .padding(.bottom, -DSALayout.secondaryBorder)
    }

    private func weatherItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(.caption, weight: .bold))
        }
    }
}
