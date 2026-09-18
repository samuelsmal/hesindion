import SwiftUI

struct WeatherDayRow: View {
    let weatherDay: WeatherDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weatherDay.date.formatted())
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(Color.groupAdventure)
                Spacer()
                Text(weatherDay.region.displayName)
                    .font(.dsaMono(.caption2, emphasis: true))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                weatherItem(icon: "cloud", text: weatherDay.clouds.displayName)
                weatherItem(icon: "wind", text: weatherDay.wind.displayName)
            }

            HStack(spacing: 16) {
                weatherItem(icon: "thermometer.sun", text: "\(L("weather.dayTemp")): \(weatherDay.dayTemperature)\u{00B0}")
                weatherItem(icon: "thermometer.snowflake", text: "\(L("weather.nightTemp")): \(weatherDay.nightTemperature)\u{00B0}")
            }

            weatherItem(icon: "arrow.up.arrow.down", text: rangeText)

            HStack(spacing: 8) {
                weatherItem(icon: "cloud.rain", text: weatherDay.rain.displayName)
                if !weatherDay.overrides.isEmpty {
                    Text(L("weather.edited"))
                        .font(.dsaBody(.caption2))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.groupAdventure.opacity(0.25))
                        .clipShape(Rectangle())
                }
            }
        }
        .padding(DSALayout.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Rows are separated, not boxed. Each used to draw its own 2pt rectangle
        // and then pull the next one up by exactly that much to collapse the
        // seam — which still left a heavy black band between every day. One
        // divider is what a list of days needs (ADR-0007).
        .dsaRowDivider()
    }

    private var rangeText: String {
        let reason = rangeReason()
        let base = "\(L("weather.range")): \(weatherDay.diurnalRange)\u{00B0}"
        return reason.isEmpty ? base : "\(base) (\(reason))"
    }

    /// Plain-language drivers of the range, from climate + clouds + wind.
    private func rangeReason() -> String {
        var parts: [String] = []
        switch weatherDay.region.archetype.humidity {
        case .dry: parts.append(L("weather.reason.dry"))
        case .humid: parts.append(L("weather.reason.humid"))
        case .moderate: break
        }
        switch weatherDay.clouds {
        case .none: parts.append(L("weather.reason.clear"))
        case .lots, .all: parts.append(L("weather.reason.cloudy"))
        case .few: break
        }
        if weatherDay.wind.nightWindReduction > 0 { parts.append(L("weather.reason.windy")) }
        return parts.joined(separator: ", ")
    }

    private func weatherItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text).font(.dsaBody(.caption))
        }
    }
}
