import SwiftUI
import SwiftData

struct AdventureDetailView: View {
    @Bindable var adventure: Adventure
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDateJump = false
    @State private var isShowingBulkGenerate = false

    private var sortedWeatherDays: [WeatherDay] {
        adventure.weatherDays.sorted { a, b in
            if a.year != b.year { return a.year > b.year }
            if a.monthRaw != b.monthRaw { return a.monthRaw > b.monthRaw }
            return a.day > b.day
        }
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
        .sheet(isPresented: $isShowingDateJump) {
            NavigationStack {
                DateJumpSheet(adventure: adventure)
            }
        }
        .sheet(isPresented: $isShowingBulkGenerate) {
            NavigationStack {
                BulkGenerateSheet(adventure: adventure)
            }
        }
    }

    // MARK: - Header

    private var adventureHeader: some View {
        VStack(spacing: 4) {
            Text(adventure.region.displayName)
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
        HStack(spacing: 8) {
            controlButton(L("nextDay"), icon: "sun.max") { generateOneDay() }
            controlButton(L("generateDays"), icon: "calendar.badge.plus") { isShowingBulkGenerate = true }
            controlButton(L("setDate"), icon: "clock.arrow.2.circlepath") { isShowingDateJump = true }
            ShareLink(item: exportText()) {
                Label(L("export"), systemImage: "square.and.arrow.up")
                    .font(.system(.caption, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.groupAdventure)
                    .foregroundStyle(.black)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
            }
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
        .padding(.vertical, 8)
    }

    private func controlButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(.caption, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.groupAdventure)
                .foregroundStyle(.black)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        }
    }

    // MARK: - Timeline

    private var weatherTimeline: some View {
        LazyVStack(spacing: 0) {
            if sortedWeatherDays.isEmpty {
                ContentUnavailableView(
                    L("nextDay"),
                    systemImage: "cloud.sun",
                    description: Text("Generiere den ersten Wettertag")
                )
                .padding(.vertical, 40)
            }

            ForEach(sortedWeatherDays, id: \.id) { weatherDay in
                VStack(spacing: 0) {
                    if weatherDay.isTimeJump {
                        timeJumpDivider()
                    }
                    WeatherDayRow(weatherDay: weatherDay)
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
                Picker(L("adventureRegion"), selection: $adventure.region) {
                    ForEach(WeatherRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                Toggle(L("adventureDesert"), isOn: $adventure.desert)
                Toggle(L("adventureWindy"), isOn: $adventure.windy)
            }
            .padding(DSALayout.contentPadding)
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func generateOneDay() {
        let gen = WeatherGenerator(region: adventure.region, desert: adventure.desert, windy: adventure.windy)
        let lastDay = sortedWeatherDays.first
        let previousResult: WeatherResult? = lastDay.map {
            WeatherResult(date: $0.date, clouds: $0.clouds, wind: $0.wind,
                          dayTemperature: $0.dayTemperature, nightTemperature: $0.nightTemperature, rain: $0.rain)
        }
        let result = gen.generate(date: adventure.currentDate, previousResult: previousResult)
        let weatherDay = WeatherDay(from: result)
        // Mark as time jump if there's a gap from the last generated day
        if let lastDay = sortedWeatherDays.first {
            let expectedNext = lastDay.date.next()
            if result.date != expectedNext {
                weatherDay.isTimeJump = true
            }
        }
        weatherDay.adventure = adventure
        modelContext.insert(weatherDay)
        adventure.currentDate = adventure.currentDate.next()
    }

    private func exportText() -> String {
        var lines = ["\(adventure.name) — Wetter (\(adventure.region.displayName))\n"]
        let chronological = sortedWeatherDays.reversed()
        for day in chronological {
            let date = day.date.formatted()
            let clouds = day.clouds.displayName
            let wind = day.wind.displayName
            let temps = "\(day.dayTemperature)\u{00B0}/\(day.nightTemperature)\u{00B0}"
            let rain = day.rain.displayName
            lines.append("\(date): \(clouds), \(wind), \(temps), \(rain)")
        }
        return lines.joined(separator: "\n")
    }
}
