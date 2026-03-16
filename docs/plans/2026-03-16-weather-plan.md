# Weather Generation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add a standalone weather generation tool organized by adventures, porting DSA 4.1 WdE weather tables with full aventurian calendar support and plain-text export.

**Architecture:** New `Adventure` and `WeatherDay` SwiftData models with a pure `WeatherGenerator` struct for the algorithm. Adventure appears as a new sidebar section. Hero gets an optional `activeAdventure` link.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing framework. No external dependencies.

---

### Task 1: Aventurian Calendar Enums & Date Struct

**Files:**
- Create: `Hesindion/Models/AventurianCalendar.swift`
- Create: `HesindionTests/AventurianCalendarTests.swift`

Pure value types with no SwiftData dependency. Testable in isolation.

**Step 1: Write failing tests**

```swift
import Testing
@testable import Hesindion

struct AventurianCalendarTests {

    // MARK: - Month → Season

    @Test func praiosIsSummer() {
        #expect(AventurianMonth.praios.season == .sommer)
    }

    @Test func efferdIsAutumn() {
        #expect(AventurianMonth.efferd.season == .herbst)
    }

    @Test func hesindeIsWinter() {
        #expect(AventurianMonth.hesinde.season == .winter)
    }

    @Test func phexIsSpring() {
        #expect(AventurianMonth.phex.season == .fruehling)
    }

    @Test func namenloseTageIsSummer() {
        #expect(AventurianMonth.namenloseTage.season == .sommer)
    }

    // MARK: - Month ordering

    @Test func monthAfterPraiosIsRondra() {
        #expect(AventurianMonth.praios.next == .rondra)
    }

    @Test func monthAfterRahjaIsNamenloseTage() {
        #expect(AventurianMonth.rahja.next == .namenloseTage)
    }

    @Test func monthAfterNamenloseTageIsPraios() {
        #expect(AventurianMonth.namenloseTage.next == .praios)
    }

    // MARK: - Month day count

    @Test func regularMonthHas30Days() {
        #expect(AventurianMonth.praios.dayCount == 30)
    }

    @Test func namenloseTageHas5Days() {
        #expect(AventurianMonth.namenloseTage.dayCount == 5)
    }

    // MARK: - Date advancement

    @Test func nextDayWithinMonth() {
        let date = AventurianDate(day: 15, month: .praios, year: 1040)
        let next = date.next()
        #expect(next.day == 16)
        #expect(next.month == .praios)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsOverMonth() {
        let date = AventurianDate(day: 30, month: .praios, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .rondra)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsRahjaToNamenloseTage() {
        let date = AventurianDate(day: 30, month: .rahja, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .namenloseTage)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsOverYear() {
        let date = AventurianDate(day: 5, month: .namenloseTage, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .praios)
        #expect(next.year == 1041)
    }

    // MARK: - Date formatting

    @Test func formattedRegularDate() {
        let date = AventurianDate(day: 12, month: .praios, year: 1040)
        #expect(date.formatted() == "12. Praios 1040 BF")
    }

    @Test func formattedNamenloseTage() {
        let date = AventurianDate(day: 3, month: .namenloseTage, year: 1040)
        #expect(date.formatted() == "3. Namenloser Tag 1040 BF")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `make test` (or `xcodebuild test -scheme Hesindion -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)
Expected: Compilation errors — types don't exist yet.

**Step 3: Implement AventurianCalendar.swift**

```swift
// MARK: - Season

enum AventurianSeason: String, Codable, CaseIterable {
    case sommer, herbst, winter, fruehling
}

// MARK: - Month

enum AventurianMonth: Int, Codable, CaseIterable, Identifiable {
    case praios = 1
    case rondra = 2
    case efferd = 3
    case travia = 4
    case boron = 5
    case hesinde = 6
    case firun = 7
    case tsa = 8
    case phex = 9
    case peraine = 10
    case ingerimm = 11
    case rahja = 12
    case namenloseTage = 13

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .praios: "Praios"
        case .rondra: "Rondra"
        case .efferd: "Efferd"
        case .travia: "Travia"
        case .boron: "Boron"
        case .hesinde: "Hesinde"
        case .firun: "Firun"
        case .tsa: "Tsa"
        case .phex: "Phex"
        case .peraine: "Peraine"
        case .ingerimm: "Ingerimm"
        case .rahja: "Rahja"
        case .namenloseTage: "Namenlose Tage"
        }
    }

    var season: AventurianSeason {
        switch self {
        case .praios, .rondra, .rahja, .namenloseTage: .sommer
        case .efferd, .travia, .boron: .herbst
        case .hesinde, .firun, .tsa: .winter
        case .phex, .peraine, .ingerimm: .fruehling
        }
    }

    var dayCount: Int {
        self == .namenloseTage ? 5 : 30
    }

    var next: AventurianMonth {
        if self == .namenloseTage { return .praios }
        return AventurianMonth(rawValue: rawValue + 1)!
    }
}

// MARK: - Date

struct AventurianDate: Equatable, Codable, Hashable {
    var day: Int
    var month: AventurianMonth
    var year: Int

    var season: AventurianSeason { month.season }

    func next() -> AventurianDate {
        if day < month.dayCount {
            return AventurianDate(day: day + 1, month: month, year: year)
        }
        let nextMonth = month.next
        let nextYear = month == .namenloseTage ? year + 1 : year
        return AventurianDate(day: 1, month: nextMonth, year: nextYear)
    }

    func formatted() -> String {
        if month == .namenloseTage {
            return "\(day). Namenloser Tag \(year) BF"
        }
        return "\(day). \(month.displayName) \(year) BF"
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All AventurianCalendarTests pass.

**Step 5: Commit**

```bash
git add Hesindion/Models/AventurianCalendar.swift HesindionTests/AventurianCalendarTests.swift
git commit -m "feat: add aventurian calendar with months, seasons, and date arithmetic"
```

---

### Task 2: Weather Enums (Region, CloudCover, Wind, Rain)

**Files:**
- Create: `Hesindion/Models/WeatherEnums.swift`
- Create: `HesindionTests/WeatherEnumsTests.swift`

**Step 1: Write failing tests**

```swift
import Testing
@testable import Hesindion

struct WeatherEnumsTests {

    // MARK: - Region base temperatures

    @Test func mittelreichSummerIs15() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .sommer) == 15)
    }

    @Test func mittelreichWinterIs5() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .winter) == 5)
    }

    @Test func mittelreichSpringAutumnIs10() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .herbst) == 10)
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .fruehling) == 10)
    }

    @Test func khomSummerIs40() {
        #expect(WeatherRegion.khom.baseTemperature(for: .sommer) == 40)
    }

    @Test func ewigesEisWinterIsMinus40() {
        #expect(WeatherRegion.ewigesEis.baseTemperature(for: .winter) == -40)
    }

    // MARK: - Cloud temperature modifiers

    @Test func cloudModifiers() {
        #expect(CloudCover.none.temperatureModifier == 10)
        #expect(CloudCover.few.temperatureModifier == 5)
        #expect(CloudCover.lots.temperatureModifier == 0)
        #expect(CloudCover.all.temperatureModifier == -5)
    }

    // MARK: - Wind temperature modifiers

    @Test func windModifiers() {
        #expect(WindStrength.none.temperatureModifier == 4)
        #expect(WindStrength.light.temperatureModifier == 2)
        #expect(WindStrength.soft.temperatureModifier == 0)
        #expect(WindStrength.fresh.temperatureModifier == 0)
        #expect(WindStrength.cool.temperatureModifier == -2)
        #expect(WindStrength.strong.temperatureModifier == -4)
        #expect(WindStrength.storm.temperatureModifier == -6)
    }

    // MARK: - Display names exist

    @Test func allRegionsHaveDisplayNames() {
        for region in WeatherRegion.allCases {
            #expect(!region.displayName.isEmpty)
        }
    }

    @Test func allCloudCoverHaveDisplayNames() {
        for cloud in CloudCover.allCases {
            #expect(!cloud.displayName.isEmpty)
        }
    }

    @Test func allWindStrengthsHaveDisplayNames() {
        for wind in WindStrength.allCases {
            #expect(!wind.displayName.isEmpty)
        }
    }

    @Test func allRainLevelsHaveDisplayNames() {
        for rain in RainLevel.allCases {
            #expect(!rain.displayName.isEmpty)
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: Compilation errors — types don't exist yet.

**Step 3: Implement WeatherEnums.swift**

```swift
// MARK: - Weather Region

enum WeatherRegion: String, Codable, CaseIterable, Identifiable {
    case ewigesEis
    case ehernesSchwert
    case hoherNorden
    case tundra
    case thorwal
    case weiden
    case mittelreich
    case almada
    case raschtulswall
    case horasreichSued
    case khom
    case echsensuempfe
    case suedmeer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ewigesEis: "Ewiges Eis"
        case .ehernesSchwert: "Höhen des Ehernen Schwerts"
        case .hoherNorden: "Hoher Norden"
        case .tundra: "Tundra und Taiga"
        case .thorwal: "Bornland, Thorwal"
        case .weiden: "Streitende Königreiche bis Weiden"
        case .mittelreich: "Zentrales Mittelreich"
        case .almada: "Nördliches Horasreich, Almada, Aranien"
        case .raschtulswall: "Höhen des Raschtulswalls"
        case .horasreichSued: "Südliches Horasreich, Reich der Ersten Sonne"
        case .khom: "Khom"
        case .echsensuempfe: "Echsensümpfe, Meridiana"
        case .suedmeer: "Altoum, Gewürzinseln, Südmeer"
        }
    }

    /// Base temperature tuple: (summer, spring/autumn, winter)
    private var baseTemps: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .ewigesEis:       (-20, -30, -40)
        case .ehernesSchwert:  (-10, -20, -30)
        case .hoherNorden:     (  0, -10, -20)
        case .tundra:          (  5,   0,  -5)
        case .thorwal:         ( 10,   3,  -5)
        case .weiden:          ( 10,   5,   0)
        case .mittelreich:     ( 15,  10,   5)
        case .almada:          ( 20,  15,  10)
        case .raschtulswall:   (  5,   0, -10)
        case .horasreichSued:  ( 25,  20,  15)
        case .khom:            ( 40,  35,  30)
        case .echsensuempfe:   ( 30,  25,  20)
        case .suedmeer:        ( 35,  30,  25)
        }
    }

    func baseTemperature(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: baseTemps.summer
        case .herbst, .fruehling: baseTemps.springAutumn
        case .winter: baseTemps.winter
        }
    }
}

// MARK: - Cloud Cover

enum CloudCover: String, Codable, CaseIterable {
    case none, few, lots, all

    var temperatureModifier: Int {
        switch self {
        case .none: 10
        case .few: 5
        case .lots: 0
        case .all: -5
        }
    }

    var displayName: String {
        switch self {
        case .none: L("weather.clouds.none")
        case .few: L("weather.clouds.few")
        case .lots: L("weather.clouds.lots")
        case .all: L("weather.clouds.all")
        }
    }
}

// MARK: - Wind Strength

enum WindStrength: String, Codable, CaseIterable {
    case none, light, soft, fresh, cool, strong, storm

    var temperatureModifier: Int {
        switch self {
        case .none: 4
        case .light: 2
        case .soft, .fresh: 0
        case .cool: -2
        case .strong: -4
        case .storm: -6
        }
    }

    var displayName: String {
        switch self {
        case .none: L("weather.wind.none")
        case .light: L("weather.wind.light")
        case .soft: L("weather.wind.soft")
        case .fresh: L("weather.wind.fresh")
        case .cool: L("weather.wind.cool")
        case .strong: L("weather.wind.strong")
        case .storm: L("weather.wind.storm")
        }
    }
}

// MARK: - Rain Level

enum RainLevel: String, Codable, CaseIterable {
    case none, little, lots, all

    var displayName: String {
        switch self {
        case .none: L("weather.rain.none")
        case .little: L("weather.rain.little")
        case .lots: L("weather.rain.lots")
        case .all: L("weather.rain.all")
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All WeatherEnumsTests pass.

**Step 5: Commit**

```bash
git add Hesindion/Models/WeatherEnums.swift HesindionTests/WeatherEnumsTests.swift
git commit -m "feat: add weather enums — regions, cloud cover, wind strength, rain level"
```

---

### Task 3: Weather Generator Algorithm

**Files:**
- Create: `Hesindion/Services/WeatherGenerator.swift`
- Create: `HesindionTests/WeatherGeneratorTests.swift`

Pure struct with no SwiftData dependency. Uses a `WeatherResult` value type (not `@Model`) for output — the view layer converts to `WeatherDay` models later.

**Step 1: Write failing tests**

```swift
import Testing
@testable import Hesindion

struct WeatherGeneratorTests {

    // MARK: - Single day generation

    @Test func generateProducesValidCloudCover() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(CloudCover.allCases.contains(result.clouds))
    }

    @Test func generateProducesValidWind() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(WindStrength.allCases.contains(result.wind))
    }

    @Test func generateProducesValidRain() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(RainLevel.allCases.contains(result.rain))
    }

    @Test func nightTempIsLowerThanDay() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        // Run multiple times since it's random
        for _ in 0..<20 {
            let result = gen.generate(date: date, previousResult: nil)
            #expect(result.nightTemperature < result.dayTemperature)
        }
    }

    // MARK: - Desert mode

    @Test func desertFavorsClearSkies() {
        let gen = WeatherGenerator(region: .khom, desert: true, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        var clearCount = 0
        for _ in 0..<100 {
            let result = gen.generate(date: date, previousResult: nil)
            if result.clouds == .none { clearCount += 1 }
        }
        // Desert: 80% chance of clear (16/20). With 100 rolls, expect > 60.
        #expect(clearCount > 60)
    }

    // MARK: - Batch generation

    @Test func batchGeneratesCorrectCount() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let start = AventurianDate(day: 1, month: .praios, year: 1040)
        let results = gen.generateBatch(startDate: start, count: 5)
        #expect(results.count == 5)
    }

    @Test func batchAdvancesDates() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let start = AventurianDate(day: 28, month: .praios, year: 1040)
        let results = gen.generateBatch(startDate: start, count: 5)
        #expect(results[0].date == AventurianDate(day: 28, month: .praios, year: 1040))
        #expect(results[2].date == AventurianDate(day: 30, month: .praios, year: 1040))
        #expect(results[3].date == AventurianDate(day: 1, month: .rondra, year: 1040))
    }

    // MARK: - No rain without clouds

    @Test func noRainWithoutClouds() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        for _ in 0..<100 {
            let result = gen.generate(date: date, previousResult: nil)
            if result.clouds == .none {
                #expect(result.rain == .none)
            }
        }
    }

    // MARK: - Cloud table lookup (deterministic helper)

    @Test func cloudTableNormalRanges() {
        #expect(WeatherGenerator.cloudFromRoll(4, desert: false) == .none)
        #expect(WeatherGenerator.cloudFromRoll(5, desert: false) == .few)
        #expect(WeatherGenerator.cloudFromRoll(10, desert: false) == .few)
        #expect(WeatherGenerator.cloudFromRoll(11, desert: false) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(16, desert: false) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(17, desert: false) == .all)
    }

    @Test func cloudTableDesertRanges() {
        #expect(WeatherGenerator.cloudFromRoll(16, desert: true) == .none)
        #expect(WeatherGenerator.cloudFromRoll(17, desert: true) == .few)
        #expect(WeatherGenerator.cloudFromRoll(19, desert: true) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(20, desert: true) == .all)
    }

    // MARK: - Wind table lookup (deterministic helper)

    @Test func windTableNonAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(4, autumn: false) == .none)
        #expect(WeatherGenerator.windFromRoll(5, autumn: false) == .light)
        #expect(WeatherGenerator.windFromRoll(11, autumn: false) == .fresh)
        #expect(WeatherGenerator.windFromRoll(17, autumn: false) == .strong)
        #expect(WeatherGenerator.windFromRoll(20, autumn: false) == .storm)
    }

    @Test func windTableAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(3, autumn: true) == .none)
        #expect(WeatherGenerator.windFromRoll(4, autumn: true) == .light)
        #expect(WeatherGenerator.windFromRoll(8, autumn: true) == .fresh)
        #expect(WeatherGenerator.windFromRoll(15, autumn: true) == .strong)
        #expect(WeatherGenerator.windFromRoll(19, autumn: true) == .storm)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: Compilation errors — WeatherGenerator doesn't exist.

**Step 3: Implement WeatherGenerator.swift**

```swift
/// Pure value type for weather generation output (no SwiftData dependency).
struct WeatherResult {
    let date: AventurianDate
    let clouds: CloudCover
    let wind: WindStrength
    let dayTemperature: Int
    let nightTemperature: Int
    let rain: RainLevel
}

/// Generates DSA weather using WdE p.156ff tables.
struct WeatherGenerator {
    let region: WeatherRegion
    let desert: Bool
    let windy: Bool

    // MARK: - Public API

    func generate(date: AventurianDate, previousResult: WeatherResult?) -> WeatherResult {
        let season = date.season
        let changeFlags = rollChangeFlags(season: season, hasPrevious: previousResult != nil)

        let clouds = (changeFlags & 0b0001 != 0)
            ? Self.cloudFromRoll(d20(), desert: desert)
            : (previousResult?.clouds ?? Self.cloudFromRoll(d20(), desert: desert))

        let wind = (changeFlags & 0b0010 != 0)
            ? Self.windFromRoll(d20() + (windy ? 2 : 0), autumn: season == .herbst)
            : (previousResult?.wind ?? Self.windFromRoll(d20() + (windy ? 2 : 0), autumn: season == .herbst))

        let base = region.baseTemperature(for: season)
        let dayTemp: Int
        let nightTemp: Int
        if changeFlags & 0b0100 != 0 {
            dayTemp = base + clouds.temperatureModifier + wind.temperatureModifier
            nightTemp = base + wind.temperatureModifier - clouds.temperatureModifier - (d20() + 5)
        } else if let prev = previousResult {
            dayTemp = prev.dayTemperature
            nightTemp = prev.nightTemperature
        } else {
            dayTemp = base + clouds.temperatureModifier + wind.temperatureModifier
            nightTemp = base + wind.temperatureModifier - clouds.temperatureModifier - (d20() + 5)
        }

        let rain = (changeFlags & 0b1000 != 0)
            ? rollRain(clouds: clouds, wind: wind)
            : (previousResult?.rain ?? rollRain(clouds: clouds, wind: wind))

        return WeatherResult(
            date: date,
            clouds: clouds,
            wind: wind,
            dayTemperature: dayTemp,
            nightTemperature: nightTemp,
            rain: rain
        )
    }

    func generateBatch(startDate: AventurianDate, count: Int) -> [WeatherResult] {
        var results: [WeatherResult] = []
        var date = startDate
        var previous: WeatherResult? = nil
        for _ in 0..<count {
            let result = generate(date: date, previousResult: previous)
            results.append(result)
            previous = result
            date = date.next()
        }
        return results
    }

    // MARK: - Dice

    private func d20() -> Int {
        Int.random(in: 1...20)
    }

    // MARK: - Step 1: Day-change flags

    private func rollChangeFlags(season: AventurianSeason, hasPrevious: Bool) -> UInt8 {
        guard hasPrevious else { return 0b1111 }
        let roll = d20()
        switch season {
        case .sommer, .winter:
            // Stable: 45% no change
            return stableChangeFlags(roll)
        case .herbst, .fruehling:
            // Volatile: 20% no change
            return volatileChangeFlags(roll)
        }
    }

    private func stableChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...9:  0b0000  // nothing changes
        case 10...11: 0b0001  // clouds
        case 12...13: 0b0011  // clouds + wind
        case 14...15: 0b0101  // clouds + temp
        case 16...17: 0b0111  // clouds + wind + temp
        case 18...19: 0b1111 & ~0b0100  // clouds + wind + rain (0b1011)
        default:     0b1111  // all change
        }
    }

    private func volatileChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...4:  0b0000  // nothing changes
        case 5...6:  0b0001  // clouds
        case 7...8:  0b0011  // clouds + wind
        case 9...10: 0b0101  // clouds + temp
        case 11...12: 0b0111  // clouds + wind + temp
        case 13...14: 0b1001  // clouds + rain
        case 15...16: 0b1011  // clouds + wind + rain
        case 17...18: 0b1101  // clouds + temp + rain
        default:     0b1111  // all change
        }
    }

    // MARK: - Step 2: Clouds

    static func cloudFromRoll(_ roll: Int, desert: Bool) -> CloudCover {
        if desert {
            switch roll {
            case ...16: return .none
            case 17...18: return .few
            case 19: return .lots
            default: return .all
            }
        }
        switch roll {
        case ...4: return .none
        case 5...10: return .few
        case 11...16: return .lots
        default: return .all
        }
    }

    // MARK: - Step 3: Wind

    static func windFromRoll(_ roll: Int, autumn: Bool) -> WindStrength {
        if autumn {
            switch roll {
            case ...3: return .none
            case 4...5: return .light
            case 6...7: return .soft
            case 8...10: return .fresh
            case 11...14: return .cool
            case 15...18: return .strong
            default: return .storm
            }
        }
        switch roll {
        case ...4: return .none
        case 5...7: return .light
        case 8...10: return .soft
        case 11...13: return .fresh
        case 14...16: return .cool
        case 17...19: return .strong
        default: return .storm
        }
    }

    // MARK: - Step 5: Rain

    private func rollRain(clouds: CloudCover, wind: WindStrength) -> RainLevel {
        // Phase 1: does it rain?
        let rainChanceRoll = d20()
        let itRains: Bool
        switch clouds {
        case .none: itRains = false
        case .few: itRains = rainChanceRoll <= 1
        case .lots: itRains = rainChanceRoll <= 4
        case .all: itRains = rainChanceRoll <= 10
        }
        guard itRains else { return .none }

        // Phase 2: how much? (cross-reference with wind)
        let intensityRoll = d20()
        return rainIntensity(roll: intensityRoll, wind: wind)
    }

    private func rainIntensity(roll: Int, wind: WindStrength) -> RainLevel {
        // Thresholds: (little_max, lots_max) — roll > lots_max = all
        let (littleMax, lotsMax): (Int, Int) = switch wind {
        case .none:   (12, 19)
        case .light:  (10, 18)
        case .soft:   (8, 17)
        case .fresh:  (6, 15)
        case .cool:   (4, 13)
        case .strong: (2, 11)
        case .storm:  (1, 10)
        }
        if roll <= littleMax { return .little }
        if roll <= lotsMax { return .lots }
        return .all
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All WeatherGeneratorTests pass.

**Step 5: Commit**

```bash
git add Hesindion/Services/WeatherGenerator.swift HesindionTests/WeatherGeneratorTests.swift
git commit -m "feat: add weather generator porting DSA 4.1 WdE tables"
```

---

### Task 4: SwiftData Models (Adventure, WeatherDay) + Migration

**Files:**
- Create: `Hesindion/Models/Adventure.swift`
- Create: `Hesindion/Models/WeatherDay.swift`
- Create: `Hesindion/Migration/SchemaV4.swift`
- Modify: `Hesindion/Migration/MigrationPlan.swift`
- Modify: `Hesindion/Models/Hero.swift` — add `activeAdventure` relationship

**Step 1: Create Adventure.swift**

```swift
import Foundation
import SwiftData

@Model
final class Adventure {
    var id: UUID = UUID()
    var name: String = ""
    var regionRaw: String = WeatherRegion.mittelreich.rawValue
    var currentDay: Int = 1
    var currentMonthRaw: Int = AventurianMonth.praios.rawValue
    var currentYear: Int = 1040
    var desert: Bool = false
    var windy: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WeatherDay.adventure)
    var weatherDays: [WeatherDay] = []

    @Relationship(inverse: \Hero.activeAdventure)
    var heroes: [Hero] = []

    var region: WeatherRegion {
        get { WeatherRegion(rawValue: regionRaw) ?? .mittelreich }
        set { regionRaw = newValue.rawValue }
    }

    var currentMonth: AventurianMonth {
        get { AventurianMonth(rawValue: currentMonthRaw) ?? .praios }
        set { currentMonthRaw = newValue.rawValue }
    }

    var currentDate: AventurianDate {
        get { AventurianDate(day: currentDay, month: currentMonth, year: currentYear) }
        set {
            currentDay = newValue.day
            currentMonth = newValue.month
            currentYear = newValue.year
        }
    }

    init(name: String, region: WeatherRegion, startDate: AventurianDate, desert: Bool = false, windy: Bool = false) {
        self.name = name
        self.regionRaw = region.rawValue
        self.currentDay = startDate.day
        self.currentMonthRaw = startDate.month.rawValue
        self.currentYear = startDate.year
        self.desert = desert
        self.windy = windy
    }
}
```

**Step 2: Create WeatherDay.swift**

```swift
import Foundation
import SwiftData

@Model
final class WeatherDay {
    var id: UUID = UUID()
    var adventure: Adventure?
    var day: Int = 1
    var monthRaw: Int = AventurianMonth.praios.rawValue
    var year: Int = 1040
    var cloudsRaw: String = CloudCover.none.rawValue
    var windRaw: String = WindStrength.none.rawValue
    var dayTemperature: Int = 0
    var nightTemperature: Int = 0
    var rainRaw: String = RainLevel.none.rawValue
    var isTimeJump: Bool = false
    var generatedAt: Date = Date()

    var month: AventurianMonth {
        get { AventurianMonth(rawValue: monthRaw) ?? .praios }
        set { monthRaw = newValue.rawValue }
    }

    var clouds: CloudCover {
        get { CloudCover(rawValue: cloudsRaw) ?? .none }
        set { cloudsRaw = newValue.rawValue }
    }

    var wind: WindStrength {
        get { WindStrength(rawValue: windRaw) ?? .none }
        set { windRaw = newValue.rawValue }
    }

    var rain: RainLevel {
        get { RainLevel(rawValue: rainRaw) ?? .none }
        set { rainRaw = newValue.rawValue }
    }

    var date: AventurianDate {
        AventurianDate(day: day, month: month, year: year)
    }

    init(from result: WeatherResult, isTimeJump: Bool = false) {
        self.day = result.date.day
        self.monthRaw = result.date.month.rawValue
        self.year = result.date.year
        self.cloudsRaw = result.clouds.rawValue
        self.windRaw = result.wind.rawValue
        self.dayTemperature = result.dayTemperature
        self.nightTemperature = result.nightTemperature
        self.rainRaw = result.rain.rawValue
        self.isTimeJump = isTimeJump
    }
}
```

**Step 3: Add activeAdventure to Hero.swift**

Add to Hero model properties (near other optional relationships):

```swift
var activeAdventure: Adventure?
```

**Step 4: Create SchemaV4.swift**

```swift
import SwiftData

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Hero.self,
            PersonalData.self,
            Experience.self,
            Attributes.self,
            DerivedValues.self,
            Talent.self,
            CombatTechnique.self,
            MeleeWeapon.self,
            RangedWeapon.self,
            Armor.self,
            Shield.self,
            EquipmentItem.self,
            Money.self,
            Pet.self,
            Language.self,
            HeroSpell.self,
            LogEntry.self,
            Adventure.self,
            WeatherDay.self,
        ]
    }
}
```

**Step 5: Update MigrationPlan.swift**

```swift
import SwiftData

enum HesindionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )
}
```

**Step 6: Build to verify models compile and migration is valid**

Run: `make build` (or `xcodebuild build -scheme Hesindion -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)
Expected: Compiles without errors.

**Step 7: Commit**

```bash
git add Hesindion/Models/Adventure.swift Hesindion/Models/WeatherDay.swift \
    Hesindion/Migration/SchemaV4.swift Hesindion/Migration/MigrationPlan.swift \
    Hesindion/Models/Hero.swift
git commit -m "feat: add Adventure and WeatherDay SwiftData models with V4 migration"
```

---

### Task 5: Localization Strings & Theme Color

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` — add weather-related strings
- Modify: `Hesindion/Theme/AttributeColors.swift` — add `groupAdventure` color

**Step 1: Add groupAdventure color to AttributeColors.swift**

Add alongside the existing group colors:

```swift
static let groupAdventure = Color(red: 0xf0 / 255, green: 0x8c / 255, blue: 0x00 / 255) // warm amber/orange
```

**Step 2: Add weather strings to Strings.swift**

Add to the `translations` dictionary (German):

```swift
// Adventure & Weather
"adventures": "Abenteuer",
"newAdventure": "Neues Abenteuer",
"adventureName": "Name",
"adventureRegion": "Region",
"adventureStartDate": "Startdatum",
"adventureDesert": "Wüste",
"adventureWindy": "Windig",
"nextDay": "Nächster Tag",
"generateDays": "Tage generieren…",
"setDate": "Datum setzen…",
"export": "Exportieren",
"settings": "Einstellungen",
"dayCount": "Anzahl Tage",
"timeJump": "Zeitsprung",
"generate": "Generieren",

// Weather display
"weather.clouds.none": "Wolkenlos",
"weather.clouds.few": "Wenige Wolken",
"weather.clouds.lots": "Bewölkt",
"weather.clouds.all": "Bedeckt",
"weather.wind.none": "Windstill",
"weather.wind.light": "Leichter Wind",
"weather.wind.soft": "Sanfter Wind",
"weather.wind.fresh": "Frischer Wind",
"weather.wind.cool": "Kühler Wind",
"weather.wind.strong": "Starker Wind",
"weather.wind.storm": "Sturm",
"weather.rain.none": "Kein Niederschlag",
"weather.rain.little": "Leichter Niederschlag",
"weather.rain.lots": "Starker Niederschlag",
"weather.rain.all": "Dauerregen",
"weather.dayTemp": "Tag",
"weather.nightTemp": "Nacht",
```

Add to the `englishFallback` dictionary:

```swift
"adventures": "Adventures",
"newAdventure": "New Adventure",
"adventureName": "Name",
"adventureRegion": "Region",
"adventureStartDate": "Start Date",
"adventureDesert": "Desert",
"adventureWindy": "Windy",
"nextDay": "Next Day",
"generateDays": "Generate Days…",
"setDate": "Set Date…",
"export": "Export",
"settings": "Settings",
"dayCount": "Number of Days",
"timeJump": "Time Jump",
"generate": "Generate",
"weather.clouds.none": "Clear",
"weather.clouds.few": "Few Clouds",
"weather.clouds.lots": "Cloudy",
"weather.clouds.all": "Overcast",
"weather.wind.none": "Calm",
"weather.wind.light": "Light Wind",
"weather.wind.soft": "Soft Wind",
"weather.wind.fresh": "Fresh Wind",
"weather.wind.cool": "Cool Wind",
"weather.wind.strong": "Strong Wind",
"weather.wind.storm": "Storm",
"weather.rain.none": "No Precipitation",
"weather.rain.little": "Light Rain",
"weather.rain.lots": "Heavy Rain",
"weather.rain.all": "Continuous Rain",
"weather.dayTemp": "Day",
"weather.nightTemp": "Night",
```

**Step 3: Build to verify**

Run: `make build`
Expected: Compiles without errors.

**Step 4: Commit**

```bash
git add Hesindion/Theme/Strings.swift Hesindion/Theme/AttributeColors.swift
git commit -m "feat: add weather localization strings and groupAdventure color"
```

---

### Task 6: Sidebar Integration

**Files:**
- Modify: `Hesindion/Views/HeroListView.swift` — add adventure section to sidebar + detail switch

**Step 1: Add adventure case to SidebarSelection**

At `HeroListView.swift:7-11`, change to:

```swift
enum SidebarSelection: Hashable {
    case rulebook
    case hero(PersistentIdentifier)
    case rule(String)
    case adventure(PersistentIdentifier)
}
```

**Step 2: Add @Query for adventures**

Add near line 15 (after heroes query):

```swift
@Query(sort: \Adventure.createdAt, order: .reverse) private var adventures: [Adventure]
@State private var isShowingAdventureCreation = false
```

**Step 3: Add Abenteuer section to sidebarContent**

Insert between the Rulebook section and the Heroes section in the `List(selection: $selection)` body (after line 97, before line 99):

```swift
Section {
    Button {
        isShowingAdventureCreation = true
    } label: {
        Label(L("newAdventure"), systemImage: "plus")
            .font(.system(.body, design: .default, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.groupAdventure)
            .foregroundStyle(.black)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color(UIColor.systemBackground))

    ForEach(adventures, id: \.persistentModelID) { adventure in
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color.groupAdventure.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.dsaBorder, lineWidth: 2)
                )
            Text(adventure.name)
                .font(.system(.title3, design: .default, weight: .bold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .tag(SidebarSelection.adventure(adventure.persistentModelID))
        .listRowBackground(
            selection == .adventure(adventure.persistentModelID)
                ? Color.groupAdventure.opacity(0.35)
                : Color(UIColor.systemBackground)
        )
    }
} header: {
    sidebarSectionHeader(L("adventures"), color: .groupAdventure)
}
```

**Step 4: Add adventure case to detailContent**

In the `switch selection` block (around line 181), add before `case nil:`:

```swift
case .adventure(let id):
    if let adventure = adventures.first(where: { $0.persistentModelID == id }) {
        AdventureDetailView(adventure: adventure)
    }
```

**Step 5: Add sheet for adventure creation**

Add to the view modifiers (after `.alert` block, around line 70):

```swift
.sheet(isPresented: $isShowingAdventureCreation) {
    NavigationStack {
        AdventureCreationSheet()
    }
}
```

**Step 6: Build to verify** (will have compile errors until Task 7 creates AdventureCreationSheet and Task 8 creates AdventureDetailView — that's fine, verify the sidebar changes look correct in the diff)

**Step 7: Commit**

```bash
git add Hesindion/Views/HeroListView.swift
git commit -m "feat: add Abenteuer section to sidebar navigation"
```

---

### Task 7: Adventure Creation Sheet

**Files:**
- Create: `Hesindion/Views/AdventureCreationSheet.swift`

**Step 1: Implement AdventureCreationSheet**

```swift
import SwiftUI
import SwiftData

struct AdventureCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var region: WeatherRegion = .mittelreich
    @State private var month: AventurianMonth = .praios
    @State private var day: Int = 1
    @State private var year: Int = 1040
    @State private var desert = false
    @State private var windy = false

    var body: some View {
        Form {
            Section {
                TextField(L("adventureName"), text: $name)
                    .font(.system(.body, weight: .bold))
            }

            Section {
                Picker(L("adventureRegion"), selection: $region) {
                    ForEach(WeatherRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }

                Toggle(L("adventureDesert"), isOn: $desert)
                Toggle(L("adventureWindy"), isOn: $windy)
            }

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
        .navigationTitle(L("newAdventure"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("create")) {
                    let adventure = Adventure(
                        name: name,
                        region: region,
                        startDate: AventurianDate(day: day, month: month, year: year),
                        desert: desert,
                        windy: windy
                    )
                    modelContext.insert(adventure)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: month) { _, newMonth in
            // Clamp day if switching to namenloseTage (max 5)
            if day > newMonth.dayCount {
                day = newMonth.dayCount
            }
        }
    }
}
```

**Step 2: Add "cancel" and "create" strings to Strings.swift if not already present**

Check if `"cancel"` and `"create"` exist. If not, add:

```swift
// translations
"cancel": "Abbrechen",
"create": "Erstellen",

// englishFallback
"cancel": "Cancel",
"create": "Create",
```

**Step 3: Build to verify**

Run: `make build`
Expected: Compiles (AdventureDetailView may not exist yet — that's OK if Task 6 is also pending).

**Step 4: Commit**

```bash
git add Hesindion/Views/AdventureCreationSheet.swift Hesindion/Theme/Strings.swift
git commit -m "feat: add adventure creation sheet with region, date, and modifier pickers"
```

---

### Task 8: Adventure Detail View + Weather Timeline

**Files:**
- Create: `Hesindion/Views/AdventureDetailView.swift`

This is the main view. It has the header, controls bar, weather timeline, and settings.

**Step 1: Implement AdventureDetailView**

```swift
import SwiftUI
import SwiftData

struct AdventureDetailView: View {
    @Bindable var adventure: Adventure
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDateJump = false
    @State private var isShowingBulkGenerate = false

    private var sortedWeatherDays: [WeatherDay] {
        adventure.weatherDays.sorted { a, b in
            // Newest first: compare by year desc, month desc, day desc
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
        .overlay(
            Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.primaryBorder)
        )
    }

    @ViewBuilder
    private func heroMiniAvatar(_ hero: Hero) -> some View {
        let size: CGFloat = 28
        if let data = hero.avatar, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
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
            controlButton(L("nextDay"), icon: "sun.max") {
                generateOneDay()
            }
            controlButton(L("generateDays"), icon: "calendar.badge.plus") {
                isShowingBulkGenerate = true
            }
            controlButton(L("setDate"), icon: "clock.arrow.2.circlepath") {
                isShowingDateJump = true
            }
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
        let gen = WeatherGenerator(
            region: adventure.region,
            desert: adventure.desert,
            windy: adventure.windy
        )
        let lastDay = sortedWeatherDays.first
        let previousResult: WeatherResult? = lastDay.map {
            WeatherResult(
                date: $0.date,
                clouds: $0.clouds,
                wind: $0.wind,
                dayTemperature: $0.dayTemperature,
                nightTemperature: $0.nightTemperature,
                rain: $0.rain
            )
        }
        let result = gen.generate(date: adventure.currentDate, previousResult: previousResult)
        let weatherDay = WeatherDay(from: result)
        weatherDay.adventure = adventure
        modelContext.insert(weatherDay)
        adventure.currentDate = adventure.currentDate.next()
    }

    private func exportText() -> String {
        var lines = ["\(adventure.name) — Wetter (\(adventure.region.displayName))\n"]
        // Export in chronological order (oldest first)
        let chronological = sortedWeatherDays.reversed()
        for day in chronological {
            let date = day.date.formatted()
            let clouds = day.clouds.displayName
            let wind = day.wind.displayName
            let temps = "\(day.dayTemperature)°/\(day.nightTemperature)°"
            let rain = day.rain.displayName
            lines.append("\(date): \(clouds), \(wind), \(temps), \(rain)")
        }
        return lines.joined(separator: "\n")
    }
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: May fail if WeatherDayRow, DateJumpSheet, BulkGenerateSheet don't exist yet. That's expected — they come in Task 9 and 10.

**Step 3: Commit**

```bash
git add Hesindion/Views/AdventureDetailView.swift
git commit -m "feat: add adventure detail view with header, controls, and weather timeline"
```

---

### Task 9: WeatherDayRow + BulkGenerateSheet

**Files:**
- Create: `Hesindion/Views/WeatherDayRow.swift`
- Create: `Hesindion/Views/BulkGenerateSheet.swift`

**Step 1: Implement WeatherDayRow**

```swift
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
                weatherItem(
                    icon: "thermometer.sun",
                    text: "\(L("weather.dayTemp")): \(weatherDay.dayTemperature)°"
                )
                weatherItem(
                    icon: "thermometer.snowflake",
                    text: "\(L("weather.nightTemp")): \(weatherDay.nightTemperature)°"
                )
            }

            weatherItem(icon: "cloud.rain", text: weatherDay.rain.displayName)
        }
        .padding(DSALayout.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder)
        )
        .padding(.bottom, -DSALayout.secondaryBorder) // collapse adjacent borders
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
```

**Step 2: Implement BulkGenerateSheet**

```swift
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
        let gen = WeatherGenerator(
            region: adventure.region,
            desert: adventure.desert,
            windy: adventure.windy
        )
        let results = gen.generateBatch(startDate: adventure.currentDate, count: dayCount)
        for result in results {
            let weatherDay = WeatherDay(from: result)
            weatherDay.adventure = adventure
            modelContext.insert(weatherDay)
        }
        // Advance adventure date past the last generated day
        var date = adventure.currentDate
        for _ in 0..<dayCount {
            date = date.next()
        }
        adventure.currentDate = date
    }
}
```

**Step 3: Build to verify**

Run: `make build`
Expected: Compiles (assuming DateJumpSheet from Task 10 doesn't exist yet — the sheet modifier in AdventureDetailView will cause a compile error. If so, create a stub first).

**Step 4: Commit**

```bash
git add Hesindion/Views/WeatherDayRow.swift Hesindion/Views/BulkGenerateSheet.swift
git commit -m "feat: add weather day row component and bulk generate sheet"
```

---

### Task 10: Date Jump Sheet

**Files:**
- Create: `Hesindion/Views/DateJumpSheet.swift`

**Step 1: Implement DateJumpSheet**

```swift
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
            if day > newMonth.dayCount {
                day = newMonth.dayCount
            }
        }
    }
}
```

Note: When the user jumps to a new date, the next weather day generated after the jump should have `isTimeJump = true`. This is handled by checking in `generateOneDay()` whether the new date is non-contiguous with the last generated day. Update `AdventureDetailView.generateOneDay()`:

After `let weatherDay = WeatherDay(from: result)`, add:

```swift
// Mark as time jump if there's a gap from the last generated day
if let lastDay = sortedWeatherDays.first {
    let expectedNext = lastDay.date.next()
    if result.date != expectedNext {
        weatherDay.isTimeJump = true
    }
}
```

The same logic applies to the first day in `BulkGenerateSheet.generateDays()` — the first result should check for discontinuity:

```swift
if let lastDay = adventure.weatherDays.sorted(by: { $0.generatedAt < $1.generatedAt }).last {
    let expectedNext = lastDay.date.next()
    if results.first?.date != expectedNext {
        // Mark first day of batch as time jump
    }
}
```

For simplicity, set `isTimeJump = true` on the first WeatherDay created when the adventure's date was changed by a date jump. A clean way: add `@State private var pendingTimeJump = false` to AdventureDetailView and set it when the date jump sheet dismisses. But the simpler approach is to compare dates at generation time as shown above.

**Step 2: Build and run on simulator**

Run: `make run`
Expected: App launches, sidebar shows "Abenteuer" section, can create adventure, generate weather days, jump dates, bulk generate, and export.

**Step 3: Commit**

```bash
git add Hesindion/Views/DateJumpSheet.swift Hesindion/Views/AdventureDetailView.swift \
    Hesindion/Views/BulkGenerateSheet.swift
git commit -m "feat: add date jump sheet with time-jump markers in weather timeline"
```

---

### Task 11: Hero ↔ Adventure Linking UI

**Files:**
- Modify: `Hesindion/Views/HeroSettingsView.swift` — add adventure picker

Look at the existing HeroSettingsView and add an adventure picker section. Pattern follows existing pickers in that view.

**Step 1: Add adventure picker to HeroSettingsView**

Add a `@Query` for adventures and a section:

```swift
@Query(sort: \Adventure.createdAt, order: .reverse) private var adventures: [Adventure]
```

Add a section to the form:

```swift
Section(L("adventures")) {
    Picker(L("adventures"), selection: $hero.activeAdventure) {
        Text("—").tag(Adventure?.none)
        ForEach(adventures, id: \.persistentModelID) { adventure in
            Text(adventure.name).tag(Adventure?.some(adventure))
        }
    }
}
```

**Step 2: Add localization strings if needed**

The "adventures" key should already exist from Task 5.

**Step 3: Build and run**

Run: `make run`
Expected: Hero settings shows adventure picker. Selecting an adventure links the hero. Adventure header shows hero avatars.

**Step 4: Commit**

```bash
git add Hesindion/Views/HeroSettingsView.swift
git commit -m "feat: add hero-adventure linking via settings picker"
```

---

### Task 12: Update Docs

**Files:**
- Modify: `CHANGELOG.md` — add weather feature to [Unreleased]

**Step 1: Add to CHANGELOG.md under [Unreleased] → Added**

```markdown
### Added
- Abenteuer (Adventure) system with weather generation
- Aventurian calendar with 12 months + Namenlose Tage
- Weather generator porting DSA 4.1 WdE p.156ff tables
- 13 climate regions from Ewiges Eis to Südmeer
- Day-by-day and bulk weather generation
- Date jumping with time-jump markers in timeline
- Plain-text weather export via share sheet
- Hero ↔ Adventure linking
- New sidebar section for adventures
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add weather generation feature to changelog"
```

---

## Task Dependency Summary

```
Task 1 (Calendar) ─┐
Task 2 (Enums)    ─┼─► Task 3 (Generator) ─► Task 4 (Models + Migration) ─► Task 5 (Strings/Colors)
                    │                                                            │
                    │                                                            ▼
                    │                                                     Task 6 (Sidebar)
                    │                                                            │
                    │                                          ┌─────────────────┼──────────────┐
                    │                                          ▼                 ▼              ▼
                    │                                   Task 7 (Create)   Task 8 (Detail)  Task 10 (DateJump)
                    │                                                            │
                    │                                                            ▼
                    │                                                     Task 9 (Row+Bulk)
                    │                                                            │
                    │                                                            ▼
                    │                                                     Task 11 (Hero Link)
                    │                                                            │
                    │                                                            ▼
                    └───────────────────────────────────────────────────► Task 12 (Docs)
```
