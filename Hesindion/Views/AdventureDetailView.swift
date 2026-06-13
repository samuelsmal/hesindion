import SwiftUI
import SwiftData

struct AdventureDetailView: View {
    @Bindable var adventure: Adventure
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingAddStretch = false
    @State private var isShowingRules = false
    @State private var editingDay: WeatherDay?

    private var sortedWeatherDays: [WeatherDay] {
        adventure.weatherDays.sorted { a, b in
            if a.year != b.year { return a.year > b.year }
            if a.monthRaw != b.monthRaw { return a.monthRaw > b.monthRaw }
            return a.day > b.day
        }
    }

    private var currentRegion: WeatherRegion {
        sortedWeatherDays.first?.region ?? adventure.region
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                adventureHeader
                controlsBar
                weatherTimeline
                adventureSettings
            }
            .frame(maxWidth: DSALayout.iPadMaxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle(adventure.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(adventure.name)
                    .font(.system(.title3, design: .default, weight: .black))
            }
        }
        .sheet(isPresented: $isShowingAddStretch) {
            NavigationStack {
                AddStretchSheet(adventure: adventure)
            }
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack {
                WeatherRulesSheet()
            }
        }
        .sheet(item: $editingDay) { day in
            NavigationStack {
                DayEditSheet(weatherDay: day)
            }
        }
    }

    // MARK: - Header

    private var adventureHeader: some View {
        VStack(spacing: 4) {
            Text(currentRegion.displayName)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.secondary)
            Text(adventure.currentDate.formatted())
                .font(.system(.title2, design: .monospaced, weight: .black))

            if !adventure.heroes.isEmpty {
                HStack(spacing: -8) {
                    ForEach(adventure.heroes, id: \.persistentModelID) { hero in
                        heroMiniAvatar(hero)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .background(Color.groupAdventure.opacity(0.15))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.primaryBorder))
    }

    @ViewBuilder
    private func heroMiniAvatar(_ hero: Hero) -> some View {
        let size: CGFloat = 28
        if let data = hero.avatar, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.dsaBorder, lineWidth: 1))
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 12))
                .frame(width: size, height: size)
                .background(Color.groupAdventure.opacity(0.3))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.dsaBorder, lineWidth: 1))
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        VStack(spacing: 8) {
            weatherButton(L("weather.add"), icon: "plus", filled: true) { isShowingAddStretch = true }
            HStack(spacing: 8) {
                weatherButton(L("weather.rules"), icon: "info.circle", filled: false) { isShowingRules = true }
                ShareLink(item: exportText()) {
                    weatherButtonLabel(L("export"), icon: "square.and.arrow.up", filled: false)
                }
            }
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
        .padding(.vertical, 8)
    }

    private func weatherButton(_ title: String, icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { weatherButtonLabel(title, icon: icon, filled: filled) }
    }

    private func weatherButtonLabel(_ title: String, icon: String, filled: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.system(.subheadline, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? Color.groupAdventure : Color.clear)
            .foregroundStyle(filled ? .black : Color.groupAdventure)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
    }

    // MARK: - Timeline

    private var weatherTimeline: some View {
        LazyVStack(spacing: 0) {
            if sortedWeatherDays.isEmpty {
                ContentUnavailableView(
                    L("weather.add"),
                    systemImage: "cloud.sun",
                    description: Text(L("weather.empty"))
                )
                .padding(.vertical, 40)
            }

            ForEach(sortedWeatherDays, id: \.id) { weatherDay in
                VStack(spacing: 0) {
                    if weatherDay.isTimeJump {
                        timeJumpDivider()
                    }
                    Button { editingDay = weatherDay } label: { WeatherDayRow(weatherDay: weatherDay) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
    }

    private func timeJumpDivider() -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.groupAdventure).frame(height: 1)
            Text(L("timeJump"))
                .font(.system(.caption2, weight: .black))
                .foregroundStyle(Color.groupAdventure)
                .textCase(.uppercase)
            Rectangle().fill(Color.groupAdventure).frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Settings

    private var adventureSettings: some View {
        CollapsibleGroup(L("settings"), color: .groupAdventure) {
            VStack(spacing: 12) {
                RegionPicker(selection: $adventure.region, label: L("adventureDefaultRegion"))
            }
            .padding(DSALayout.contentPadding)
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func exportText() -> String {
        var lines = ["\(adventure.name) — Wetter (\(currentRegion.displayName))\n"]
        let chronological = sortedWeatherDays.reversed()
        for day in chronological {
            let date = day.date.formatted()
            let clouds = day.clouds.displayName
            let wind = day.wind.displayName
            let temps = "\(day.dayTemperature)\u{00B0}/\(day.nightTemperature)\u{00B0}"
            let rain = day.rain.displayName
            lines.append("\(date) [\(day.region.displayName)]: \(clouds), \(wind), \(temps), \(rain)")
        }
        return lines.joined(separator: "\n")
    }
}
