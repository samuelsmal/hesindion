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
                nameHeading
                adventureHeader
                controlsBar
                weatherTimeline
                adventureSettings
            }
            .frame(maxWidth: DSALayout.iPadMaxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    /// The adventure's name, in the boxed heading the hero pane uses.
    ///
    /// It used to be the bare navigation title — system chrome, on a screen where
    /// everything else is a bordered box. A heading that is not in the design
    /// language reads as belonging to the OS rather than to the app.
    private var nameHeading: some View {
        Text(adventure.name)
            .font(.dsaHeading(.largeTitle))
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupAdventure)
            .dsaBox(.raised)
            .padding(.horizontal, DSALayout.horizontalPadding)
            .padding(.bottom, 12)
    }

    private var adventureHeader: some View {
        VStack(spacing: 4) {
            Text(currentRegion.displayName)
                .font(.dsaBody(.subheadline))
                .foregroundStyle(.secondary)
            Text(adventure.currentDate.formatted())
                .font(.dsaMono(.title2, emphasis: true))

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
        .dsaBox(.flush)
        // Inset like everything below it. The heading and this bar were the only
        // content flush with the pane edges, which is what made them read as too
        // wide next to the hero pane's boxed name.
        .padding(.horizontal, DSALayout.horizontalPadding)
    }

    @ViewBuilder
    private func heroMiniAvatar(_ hero: Hero) -> some View {
        let size: CGFloat = 28
        if let data = hero.avatar, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Rectangle())
                .dsaBox(.flush)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 12))
                .frame(width: size, height: size)
                .background(Color.groupAdventure.opacity(0.3))
                .clipShape(Rectangle())
                .dsaBox(.flush)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        // The buttons cast now, and a shadow draws outside its own bounds without
        // reserving layout space, so an 8pt stack put each shadow on top of the
        // next button. Every gap on this screen is the visible gap plus the
        // offset the shadow spends.
        VStack(spacing: 8 + DSALayout.shadowOffset) {
            weatherButton(L("weather.add"), icon: "plus", filled: true) { isShowingAddStretch = true }
            // 8pt of visible gap plus the 5pt the left button's shadow spends
            // outside its own bounds.
            HStack(spacing: 8 + DSALayout.shadowOffset) {
                weatherButton(L("weather.rules"), icon: "info.circle", filled: false, fillHeight: true) { isShowingRules = true }
                ShareLink(item: exportText()) {
                    weatherButtonLabel(L("export"), icon: "square.and.arrow.up", filled: false, fillHeight: true)
                }
                .buttonStyle(.dsaMotion)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 12 + DSALayout.shadowOffset)
    }

    private func weatherButton(_ title: String, icon: String, filled: Bool, fillHeight: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { weatherButtonLabel(title, icon: icon, filled: filled, fillHeight: fillHeight) }
            .buttonStyle(.dsaMotion)
    }

    private func weatherButtonLabel(_ title: String, icon: String, filled: Bool, fillHeight: Bool = false) -> some View {
        Label(title, systemImage: icon)
            .font(.dsaBody(.subheadline))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: fillHeight ? .infinity : nil)
            .padding(.vertical, 12)
            .background(filled ? Color.groupAdventure : Color(UIColor.systemBackground))
            .foregroundStyle(filled ? .black : Color.groupAdventure)
            // Full-width action buttons, so they cast (ADR-0009). They were the
            // last screen the promotion sweep missed: it matched call sites that
            // applied `.dsaBox` directly, and these three route through a shared
            // label builder.
            .dsaBox(.raised)
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

            // One box around the run of days, dividers within — rather than a
            // bordered card per day, which read as a stack of heavy black bands.
            VStack(spacing: 0) {
                ForEach(sortedWeatherDays, id: \.id) { weatherDay in
                    if weatherDay.isTimeJump {
                        timeJumpDivider()
                    }
                    Button { editingDay = weatherDay } label: { WeatherDayRow(weatherDay: weatherDay) }
                        .buttonStyle(.dsaMotion)
                }
            }
            .dsaBox(.raised, fill: Color(UIColor.systemBackground))
        }
        .padding(.horizontal, DSALayout.horizontalPadding)
    }

    private func timeJumpDivider() -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.groupAdventure).frame(height: 1)
            Text(L("timeJump"))
                .font(.dsaHeading(.caption2))
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
        .padding(.top, 12 + DSALayout.shadowOffset)
        .padding(.bottom, 16)
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
