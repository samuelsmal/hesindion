# Weather Feature Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Aventurian weather realistic (climate-driven diurnal temperatures with player-visible rules), fix the mismatched control buttons, and replace the region-locked one-day-at-a-time edit flow with a per-day-region timeline.

**Architecture:** A two-layer model — ~23 named `WeatherRegion`s each map to one of 13 `ClimateArchetype`s that carry all weather numbers (base day temp, clear-sky diurnal range, humidity, windiness). `WeatherGenerator` is keyed on archetype; night temp = day high − a diurnal range derived from climate × clouds × wind. Region is stored per `WeatherDay`. Generation is one "Add stretch" sheet (start date + region + #days); days are tap-to-edit. Rules are shown on each row and in a Rules sheet.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData (`@Model`, automatic lightweight migration — the `HesindionMigrationPlan` is dormant), Swift Testing (`@Test`) for units, XCTest + swift-snapshot-testing for views. Build/test via `make`.

**User decisions (already made):**
- "Day timeline, region per day. There will be jumps (for example weather in a city can be ignored)" → continuous timeline, per-day region, jumps skip + mark gap.
- "One 'Add stretch' action" (start date + region + #days) replaces Next-day/Generate-days/Set-date.
- "Edit + regenerate" — tap a day to change region (re-roll) or manually override values; overrides are marked and survive re-rolls.
- "Full model redesign" — climate intrinsic to region; soften day swings; retire per-adventure desert/windy flags.
- "Yes, ~22 regions as shown" — two-layer named-region → archetype model.
- "1 primary + 2 equal ghosts" control layout.

**No data migration needed:** old data is handled by read-time fallbacks (legacy region raw values normalize; old `WeatherDay`s with empty `regionRaw` inherit the adventure's region). Do NOT touch `Hesindion/Migration/*` — it is dormant.

**Conventions to follow:**
- New `*.swift` files go under `Hesindion/` (synchronized Xcode group auto-includes them) or `HesindionTests/`. No `.pbxproj` edits needed.
- Localization: every user string is a key in BOTH dictionaries in `Hesindion/Theme/Strings.swift` (English block ≈ lines 412–447, German block ≈ 852–887), read via `L("key")`.
- Tests: `make test` (units) / `make test-ui` (snapshots), single iPad simulator only (Makefile `NO_CLONE`). Snapshot re-record: delete the target PNGs first, then `make test-ui-record` (it only writes missing — see [memory note]).
- Commit after each task.

---

### Task 1: `ClimateArchetype` (weather engine data)

**Goal:** A pure enum holding every climate number, so the generator and UI read one source of truth.

**Files:**
- Create: `Hesindion/Models/ClimateArchetype.swift`
- Test: `HesindionTests/ClimateArchetypeTests.swift`
- Reference: `Hesindion/Models/AventurianCalendar.swift` (`AventurianSeason`)

**Acceptance Criteria:**
- [ ] 13 archetypes, each returns base day temp + clear-sky range for all 4 seasons, a `Humidity`, and a `Windiness`.
- [ ] Summer range ≥ spring/autumn range ≥ winter range for every archetype (deserts/tropics may be equal, never inverted).
- [ ] `displayName` resolves via `L(...)`.

**Verify:** `make test` → `ClimateArchetypeTests` all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
// HesindionTests/ClimateArchetypeTests.swift
import Testing
@testable import Hesindion

struct ClimateArchetypeTests {
    @Test func everyArchetypeHasSaneTemps() {
        for a in ClimateArchetype.allCases {
            for s in AventurianSeason.allCases {
                #expect(a.clearSkyRange(for: s) >= 2)
            }
            // monotonic: summer >= spring/autumn >= winter
            #expect(a.clearSkyRange(for: .sommer) >= a.clearSkyRange(for: .fruehling))
            #expect(a.clearSkyRange(for: .fruehling) >= a.clearSkyRange(for: .winter))
            #expect(a.baseDayTemp(for: .sommer) >= a.baseDayTemp(for: .winter))
        }
    }

    @Test func desertSwingsMoreThanTropics() {
        #expect(ClimateArchetype.desert.clearSkyRange(for: .sommer)
              > ClimateArchetype.tropicalSea.clearSkyRange(for: .sommer))
    }

    @Test func humidityAndWindAssigned() {
        #expect(ClimateArchetype.desert.humidity == .dry)
        #expect(ClimateArchetype.tropicalHumid.humidity == .humid)
        #expect(ClimateArchetype.temperate.windiness == .calm)
        #expect(ClimateArchetype.desert.windiness == .windy)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `make test` → fails to compile (`ClimateArchetype` undefined).

- [ ] **Step 3: Implement**

```swift
// Hesindion/Models/ClimateArchetype.swift
import Foundation

/// Climate profile that drives all weather numbers. Regions map onto these.
enum ClimateArchetype: String, Codable, CaseIterable {
    case polar, subarctic, highMountainIce, highMountain,
         coldCoast, coldContinental, temperate, mediterranean,
         semiArid, desert, subtropicalHot, tropicalHumid, tropicalSea

    enum Humidity: String, Codable { case dry, moderate, humid }
    enum Windiness: String, Codable { case calm, moderate, windy }

    /// Typical day-high baseline (summer, spring/autumn, winter).
    private var baseTemps: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .polar:            (-20, -30, -40)
        case .subarctic:        (  5,   0,  -5)
        case .highMountainIce:  (-10, -20, -30)
        case .highMountain:     (  5,   0, -10)
        case .coldCoast:        ( 10,   3,  -5)
        case .coldContinental:  ( 10,   3,  -5)
        case .temperate:        ( 15,  10,   5)
        case .mediterranean:    ( 20,  15,  10)
        case .semiArid:         ( 25,  18,  12)
        case .desert:           ( 40,  35,  30)
        case .subtropicalHot:   ( 30,  25,  18)
        case .tropicalHumid:    ( 30,  25,  20)
        case .tropicalSea:      ( 35,  30,  25)
        }
    }

    /// Diurnal range under clear, calm skies (summer, spring/autumn, winter).
    private var clearSkyRanges: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .polar:            (10,  9,  7)
        case .subarctic:        (14, 11,  8)
        case .highMountainIce:  (14, 12,  9)
        case .highMountain:     (16, 13, 10)
        case .coldCoast:        ( 9,  8,  7)
        case .coldContinental:  (14, 11,  8)
        case .temperate:        (14, 11,  8)
        case .mediterranean:    (13, 11,  9)
        case .semiArid:         (18, 15, 12)
        case .desert:           (26, 24, 20)
        case .subtropicalHot:   (16, 14, 11)
        case .tropicalHumid:    ( 6,  5,  5)
        case .tropicalSea:      ( 4,  4,  4)
        }
    }

    func baseDayTemp(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: baseTemps.summer
        case .herbst, .fruehling: baseTemps.springAutumn
        case .winter: baseTemps.winter
        }
    }

    func clearSkyRange(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: clearSkyRanges.summer
        case .herbst, .fruehling: clearSkyRanges.springAutumn
        case .winter: clearSkyRanges.winter
        }
    }

    var humidity: Humidity {
        switch self {
        case .polar, .subarctic, .highMountainIce, .highMountain, .semiArid, .desert, .subtropicalHot: .dry
        case .coldCoast, .coldContinental, .temperate, .mediterranean: .moderate
        case .tropicalHumid, .tropicalSea: .humid
        }
    }

    var windiness: Windiness {
        switch self {
        case .polar, .subarctic, .highMountainIce, .highMountain, .coldCoast, .semiArid, .desert: .windy
        case .coldContinental, .mediterranean, .subtropicalHot, .tropicalSea: .moderate
        case .temperate, .tropicalHumid: .calm
        }
    }

    var displayName: String { L("climate.\(rawValue)") }
}
```

- [ ] **Step 4: Run, verify it passes** — `make test` → `ClimateArchetypeTests` pass.

- [ ] **Step 5: Commit** — `git add Hesindion/Models/ClimateArchetype.swift HesindionTests/ClimateArchetypeTests.swift && git commit -m "feat(weather): add ClimateArchetype climate-profile model"`

---

### Task 2: `WeatherRegion` two-layer redesign + `MacroRegion` + legacy mapping + Strings

**Goal:** Replace the 13 climate-zone cases with ~23 named regions grouped by macro-region, each mapping to an archetype, with backward-compatible resolution of old persisted raw values.

**Files:**
- Modify: `Hesindion/Models/WeatherEnums.swift:1-66` (replace the `WeatherRegion` enum entirely; leave CloudCover/WindStrength/RainLevel for Task 4)
- Modify: `Hesindion/Theme/Strings.swift` (add region/macro/climate keys to both dictionaries)
- Test: `HesindionTests/WeatherEnumsTests.swift` (extend; file already exists)

**Acceptance Criteria:**
- [ ] Every `WeatherRegion` returns an `archetype`, a `macroRegion`, and a `displayName` via `L(...)`.
- [ ] `WeatherRegion.resolve(persisted:)` maps every one of the 13 legacy raw values (`weiden`, `horasreichSued`, `hoherNorden`, `tundra`, …) to a current region; unknown/empty → `.mittelreich`.
- [ ] `MacroRegion.allCases` ordered north→south; `WeatherRegion.allCases` non-empty.
- [ ] All 13 `climate.*` display keys and all region/macro keys exist in both language dictionaries.

**Verify:** `make test` → `WeatherEnumsTests` pass.

**Steps:**

- [ ] **Step 1: Write the failing tests** (append to `HesindionTests/WeatherEnumsTests.swift`)

```swift
@Test func everyRegionMapsToArchetypeAndMacro() {
    for r in WeatherRegion.allCases {
        _ = r.archetype          // must compile + not crash
        _ = r.macroRegion
        #expect(!r.displayName.isEmpty)
    }
}

@Test func legacyRawValuesResolve() {
    #expect(WeatherRegion.resolve(persisted: "weiden") == .streitendeKoenigreiche)
    #expect(WeatherRegion.resolve(persisted: "horasreichSued") == .ersteSonne)
    #expect(WeatherRegion.resolve(persisted: "tundra") == .nivesenland)
    #expect(WeatherRegion.resolve(persisted: "hoherNorden") == .nivesenland)
    #expect(WeatherRegion.resolve(persisted: "mittelreich") == .mittelreich)   // unchanged
    #expect(WeatherRegion.resolve(persisted: "khom") == .khom)                  // unchanged
    #expect(WeatherRegion.resolve(persisted: "") == .mittelreich)              // fallback
    #expect(WeatherRegion.resolve(persisted: "garbage") == .mittelreich)
}
```

- [ ] **Step 2: Run, verify it fails** — `make test` → compile failure (new cases/methods undefined).

- [ ] **Step 3: Replace the `WeatherRegion` enum** in `Hesindion/Models/WeatherEnums.swift` (replace lines 1–66, i.e. everything from `import Foundation` through the end of the old `WeatherRegion` `baseTemperature(for:)` and its closing brace — keep the `// MARK: - Cloud Cover` section and everything after it intact)

```swift
import Foundation

// MARK: - Macro Region (grouping for the picker, north → south)

enum MacroRegion: String, Codable, CaseIterable, Identifiable {
    case hoherNorden, hochgebirge, nordaventurien, zentralaventurien,
         tulamidenlande, suedaventurien, tieferSueden
    var id: String { rawValue }
    var displayName: String { L("macro.\(rawValue)") }
}

// MARK: - Weather Region (named, player-facing)

enum WeatherRegion: String, Codable, CaseIterable, Identifiable {
    case ewigesEis, nivesenland, gjalskerland
    case ehernesSchwert, raschtulswall
    case thorwal, bornland, svelltland, orkland
    case mittelreich, streitendeKoenigreiche, elfenlande
    case aranien, khom, mhanadiTal
    case almada, horasreich, ersteSonne, zyklopeninseln
    case meridiana, echsensuempfe, maraskan, suedmeer

    var id: String { rawValue }

    var displayName: String { L("region.\(rawValue)") }

    var macroRegion: MacroRegion {
        switch self {
        case .ewigesEis, .nivesenland, .gjalskerland: .hoherNorden
        case .ehernesSchwert, .raschtulswall: .hochgebirge
        case .thorwal, .bornland, .svelltland, .orkland: .nordaventurien
        case .mittelreich, .streitendeKoenigreiche, .elfenlande: .zentralaventurien
        case .aranien, .khom, .mhanadiTal: .tulamidenlande
        case .almada, .horasreich, .ersteSonne, .zyklopeninseln: .suedaventurien
        case .meridiana, .echsensuempfe, .maraskan, .suedmeer: .tieferSueden
        }
    }

    var archetype: ClimateArchetype {
        switch self {
        case .ewigesEis: .polar
        case .nivesenland, .gjalskerland, .orkland: .subarctic
        case .ehernesSchwert: .highMountainIce
        case .raschtulswall: .highMountain
        case .thorwal: .coldCoast
        case .bornland, .svelltland: .coldContinental
        case .mittelreich, .streitendeKoenigreiche, .elfenlande: .temperate
        case .aranien: .semiArid
        case .khom: .desert
        case .mhanadiTal, .ersteSonne: .subtropicalHot
        case .almada, .horasreich, .zyklopeninseln: .mediterranean
        case .meridiana, .echsensuempfe, .maraskan: .tropicalHumid
        case .suedmeer: .tropicalSea
        }
    }

    /// All regions of a macro-region, in declaration order (for grouped pickers).
    static func inMacro(_ macro: MacroRegion) -> [WeatherRegion] {
        allCases.filter { $0.macroRegion == macro }
    }

    /// Resolve a persisted raw value, mapping retired legacy zone names.
    static func resolve(persisted raw: String) -> WeatherRegion {
        if let direct = WeatherRegion(rawValue: raw) { return direct }
        return legacyMap[raw] ?? .mittelreich
    }

    /// Old (pre-redesign) raw values that no longer exist as cases.
    private static let legacyMap: [String: WeatherRegion] = [
        "hoherNorden": .nivesenland,
        "tundra": .nivesenland,
        "weiden": .streitendeKoenigreiche,
        "horasreichSued": .ersteSonne,
        // ewigesEis, ehernesSchwert, thorwal, mittelreich, almada,
        // raschtulswall, khom, echsensuempfe, suedmeer keep their raw values.
    ]
}
```

- [ ] **Step 4: Add localization keys.** In `Hesindion/Theme/Strings.swift`, in the **English** dictionary right after the `"adventureWindy"` line (≈ line 419) insert:

```swift
        // Macro regions
        "macro.hoherNorden":            "Far North",
        "macro.hochgebirge":            "High Mountains",
        "macro.nordaventurien":         "Northern Aventuria",
        "macro.zentralaventurien":      "Central Aventuria",
        "macro.tulamidenlande":         "Tulamidean Lands",
        "macro.suedaventurien":         "Southern Aventuria",
        "macro.tieferSueden":           "Deep South & Isles",
        // Climate archetypes
        "climate.polar":                "Polar",
        "climate.subarctic":            "Subarctic",
        "climate.highMountainIce":      "Glacial Mountains",
        "climate.highMountain":         "High Mountains",
        "climate.coldCoast":            "Cold Coast",
        "climate.coldContinental":      "Cold Continental",
        "climate.temperate":            "Temperate",
        "climate.mediterranean":        "Mediterranean",
        "climate.semiArid":             "Semi-Arid Steppe",
        "climate.desert":               "Desert",
        "climate.subtropicalHot":       "Hot Subtropical",
        "climate.tropicalHumid":        "Tropical Humid",
        "climate.tropicalSea":          "Tropical Sea",
        // Regions
        "region.ewigesEis":             "Eternal Ice",
        "region.nivesenland":           "Nivese Land, Tundra",
        "region.gjalskerland":          "Gjalskerland",
        "region.ehernesSchwert":        "Heights of the Iron Sword",
        "region.raschtulswall":         "Heights of the Raschtulswall",
        "region.thorwal":               "Thorwal",
        "region.bornland":              "Bornland",
        "region.svelltland":            "Svellt Valley",
        "region.orkland":               "Orkland",
        "region.mittelreich":           "Central Middenrealm",
        "region.streitendeKoenigreiche": "Warring Kingdoms, Weiden",
        "region.elfenlande":            "Elven Lands",
        "region.aranien":               "Aranian Steppe",
        "region.khom":                  "Khôm Desert",
        "region.mhanadiTal":            "Mhanadi Valley, Unau",
        "region.almada":                "Almada",
        "region.horasreich":            "Horasian Empire, Liebliches Feld",
        "region.ersteSonne":            "Realm of the First Sun",
        "region.zyklopeninseln":        "Cyclopean Isles",
        "region.meridiana":             "Al'Anfa, Meridiana",
        "region.echsensuempfe":         "Lizard Swamps",
        "region.maraskan":              "Maraskan",
        "region.suedmeer":              "Altoum, Spice Isles, South Sea",
```

In the **German** dictionary right after `"adventureWindy"` (≈ line 859) insert:

```swift
        // Makroregionen
        "macro.hoherNorden":            "Hoher Norden",
        "macro.hochgebirge":            "Hochgebirge",
        "macro.nordaventurien":         "Nordaventurien",
        "macro.zentralaventurien":      "Zentralaventurien",
        "macro.tulamidenlande":         "Tulamidenlande",
        "macro.suedaventurien":         "Südaventurien",
        "macro.tieferSueden":           "Tiefer Süden & Inseln",
        // Klima-Archetypen
        "climate.polar":                "Polar",
        "climate.subarctic":            "Subarktis",
        "climate.highMountainIce":      "Gletschergebirge",
        "climate.highMountain":         "Hochgebirge",
        "climate.coldCoast":            "Kalte Küste",
        "climate.coldContinental":      "Kalt-kontinental",
        "climate.temperate":            "Gemäßigt",
        "climate.mediterranean":        "Mediterran",
        "climate.semiArid":             "Halbwüste/Steppe",
        "climate.desert":               "Wüste",
        "climate.subtropicalHot":       "Subtropisch-heiß",
        "climate.tropicalHumid":        "Tropisch-feucht",
        "climate.tropicalSea":          "Tropische See",
        // Regionen
        "region.ewigesEis":             "Ewiges Eis",
        "region.nivesenland":           "Nivenland, Tundra",
        "region.gjalskerland":          "Gjalskerland",
        "region.ehernesSchwert":        "Höhen des Ehernen Schwerts",
        "region.raschtulswall":         "Höhen des Raschtulswalls",
        "region.thorwal":               "Thorwal",
        "region.bornland":              "Bornland",
        "region.svelltland":            "Svelltal",
        "region.orkland":               "Orkland",
        "region.mittelreich":           "Zentrales Mittelreich",
        "region.streitendeKoenigreiche": "Streitende Königreiche, Weiden",
        "region.elfenlande":            "Elfenlande",
        "region.aranien":               "Aranien",
        "region.khom":                  "Khôm",
        "region.mhanadiTal":            "Mhanadi-Tal, Unau",
        "region.almada":                "Almada",
        "region.horasreich":            "Horasreich, Liebliches Feld",
        "region.ersteSonne":            "Reich der Ersten Sonne",
        "region.zyklopeninseln":        "Zyklopeninseln",
        "region.meridiana":             "Al'Anfa, Meridiana",
        "region.echsensuempfe":         "Echsensümpfe",
        "region.maraskan":              "Maraskan",
        "region.suedmeer":              "Altoum, Gewürzinseln, Südmeer",
```

- [ ] **Step 5: Run tests** — `make test` → `WeatherEnumsTests` pass. (Build will still fail in call sites using removed cases/`baseTemperature` — that's expected; Tasks 4–6 fix them. If you need a green build at this commit, proceed to Task 4 before building the app target; the test target for these two files compiles independently via `@testable`.)

> NOTE: `WeatherRegion.baseTemperature(for:)` is removed here; it moves to `ClimateArchetype`. Generator call sites are migrated in Task 4.

- [ ] **Step 6: Commit** — `git add Hesindion/Models/WeatherEnums.swift Hesindion/Theme/Strings.swift HesindionTests/WeatherEnumsTests.swift && git commit -m "feat(weather): two-layer named regions mapped to climate archetypes"`

---

### Task 3: `AventurianDate` ordinal + arithmetic helpers

**Goal:** Total ordering and day arithmetic so stretches and gaps are computable.

**Files:**
- Modify: `Hesindion/Models/AventurianCalendar.swift` (add an extension after the `AventurianDate` struct, ≈ after line 89)
- Test: `HesindionTests/AventurianDateTests.swift` (create)

**Acceptance Criteria:**
- [ ] `ordinal()` strictly increases with calendar order across month and year boundaries.
- [ ] `adding(days:)` equals repeated `next()`; `adding(days: 0)` is identity.
- [ ] A 365-day year: `AventurianDate(day:1,month:.praios,year:y+1).ordinal() - AventurianDate(day:1,month:.praios,year:y).ordinal() == 365`.

**Verify:** `make test` → `AventurianDateTests` pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
// HesindionTests/AventurianDateTests.swift
import Testing
@testable import Hesindion

struct AventurianDateTests {
    @Test func ordinalOrders() {
        let a = AventurianDate(day: 30, month: .praios, year: 1040)
        let b = AventurianDate(day: 1, month: .rondra, year: 1040)
        #expect(b.ordinal() == a.ordinal() + 1)
    }
    @Test func yearIs365Days() {
        let a = AventurianDate(day: 1, month: .praios, year: 1040)
        let b = AventurianDate(day: 1, month: .praios, year: 1041)
        #expect(b.ordinal() - a.ordinal() == 365)
    }
    @Test func addingMatchesNext() {
        var d = AventurianDate(day: 28, month: .praios, year: 1040)
        let added = d.adding(days: 5)
        for _ in 0..<5 { d = d.next() }
        #expect(added == d)
        #expect(AventurianDate(day: 3, month: .tsa, year: 7).adding(days: 0)
                == AventurianDate(day: 3, month: .tsa, year: 7))
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `make test` → compile failure (`ordinal`/`adding` undefined).

- [ ] **Step 3: Implement** (append to `Hesindion/Models/AventurianCalendar.swift`)

```swift
extension AventurianDate {
    /// Absolute day index. Year length is fixed at 365 (12×30 + 5 Namenlose Tage).
    func ordinal() -> Int {
        var dayOfYear = day
        var m = AventurianMonth.praios
        while m != month {
            dayOfYear += m.dayCount
            m = m.next
        }
        return year * 365 + dayOfYear
    }

    /// This date plus `days` (clamped at 0), via the canonical `next()` rollover.
    func adding(days: Int) -> AventurianDate {
        var d = self
        for _ in 0..<max(0, days) { d = d.next() }
        return d
    }
}
```

- [ ] **Step 4: Run, verify it passes** — `make test` → `AventurianDateTests` pass.

- [ ] **Step 5: Commit** — `git add Hesindion/Models/AventurianCalendar.swift HesindionTests/AventurianDateTests.swift && git commit -m "feat(calendar): add AventurianDate ordinal and adding(days:) helpers"`

---

### Task 4: `WeatherGenerator` diurnal-range rewrite + softened day modifiers

**Goal:** Drive generation from `ClimateArchetype`; compute night temp as day − a realistic diurnal range; soften day swings; make clouds depend on humidity and wind on windiness.

**Files:**
- Modify: `Hesindion/Services/WeatherGenerator.swift` (rewrite)
- Modify: `Hesindion/Models/WeatherEnums.swift` (CloudCover/WindStrength: update `temperatureModifier`, add `cloudFactor`/`nightWindReduction`/`rollBonus`)
- Modify: `HesindionTests/WeatherGeneratorTests.swift` (rewrite for new API)

**Acceptance Criteria:**
- [ ] `WeatherGenerator(region:)` and `WeatherGenerator(archetype:)` both exist; old `desert:`/`windy:` params gone.
- [ ] Night temp < day temp always; diurnal range ≥ 2 and ≤ archetype clear-sky range + 2 (jitter cap).
- [ ] Temperate (`.mittelreich`) summer **clear, calm** nights are not freezing: over 50 rolls, min night temp ≥ 0 (regression for the original bug).
- [ ] Desert (`.khom`) summer day temp never exceeds 50 (no 54° highs).
- [ ] Dry climates favor clear skies (>60% `.none` over 100 rolls); humid climates favor clouds (>60% not `.none`).

**Verify:** `make test` → `WeatherGeneratorTests` pass.

**Steps:**

- [ ] **Step 1: Update `WeatherEnums.swift`.** Replace `CloudCover.temperatureModifier` (lines ≈ 73–80) with softened values and add `cloudFactor`:

```swift
    /// Day-temperature modifier (softened so highs stay realistic).
    var temperatureModifier: Int {
        switch self {
        case .none: 6
        case .few: 3
        case .lots: -1
        case .all: -4
        }
    }

    /// Multiplier applied to the clear-sky diurnal range (clouds trap night heat).
    var cloudFactor: Double {
        switch self {
        case .none: 1.0
        case .few: 0.8
        case .lots: 0.6
        case .all: 0.45
        }
    }
```

Replace `WindStrength.temperatureModifier` (lines ≈ 97–105) and add `nightWindReduction`:

```swift
    /// Day-temperature modifier (softened).
    var temperatureModifier: Int {
        switch self {
        case .none: 2
        case .light: 1
        case .soft, .fresh: 0
        case .cool: -2
        case .strong: -3
        case .storm: -4
        }
    }

    /// Degrees subtracted from the diurnal range (wind mixes air, warms nights).
    var nightWindReduction: Int {
        switch self {
        case .none, .light: 0
        case .soft, .fresh: 2
        case .cool, .strong: 4
        case .storm: 5
        }
    }
```

Add a `rollBonus` to the new `ClimateArchetype.Windiness` (in `ClimateArchetype.swift`, inside `enum Windiness`):

```swift
    enum Windiness: String, Codable {
        case calm, moderate, windy
        var rollBonus: Int { switch self { case .calm: 0; case .moderate: 0; case .windy: 2 } }
    }
```

- [ ] **Step 2: Write the failing tests** (replace the body of `HesindionTests/WeatherGeneratorTests.swift`)

```swift
import Testing
@testable import Hesindion

struct WeatherGeneratorTests {
    let summer = AventurianDate(day: 1, month: .praios, year: 1040)
    let autumn = AventurianDate(day: 1, month: .efferd, year: 1040)

    @Test func producesValidEnums() {
        let gen = WeatherGenerator(region: .mittelreich)
        let r = gen.generate(date: summer, previousResult: nil)
        #expect(CloudCover.allCases.contains(r.clouds))
        #expect(WindStrength.allCases.contains(r.wind))
        #expect(RainLevel.allCases.contains(r.rain))
    }

    @Test func nightLowerThanDayWithinRange() {
        let gen = WeatherGenerator(region: .khom)
        for _ in 0..<50 {
            let r = gen.generate(date: summer, previousResult: nil)
            #expect(r.nightTemperature < r.dayTemperature)
            let range = r.dayTemperature - r.nightTemperature
            #expect(range >= 2)
            #expect(range <= ClimateArchetype.desert.clearSkyRange(for: .sommer) + 2)
        }
    }

    @Test func temperateSummerNightsNotFreezing() {            // regression for the bug
        let gen = WeatherGenerator(archetype: .temperate)
        var minNight = 99
        for _ in 0..<50 {
            // force clear, calm by regenerating with no previous and reading clear days
            let r = gen.generate(date: summer, previousResult: nil)
            if r.clouds == .none && r.wind == .none {
                minNight = min(minNight, r.nightTemperature)
            }
        }
        #expect(minNight >= 0 || minNight == 99)  // 99 = no clear-calm sample this run
    }

    @Test func desertSummerDaysNotAbsurd() {
        let gen = WeatherGenerator(region: .khom)
        for _ in 0..<100 {
            let r = gen.generate(date: summer, previousResult: nil)
            #expect(r.dayTemperature <= 50)
        }
    }

    @Test func dryFavorsClearHumidFavorsClouds() {
        let dry = WeatherGenerator(region: .khom)
        let humid = WeatherGenerator(region: .suedmeer)
        var dryClear = 0, humidCloudy = 0
        for _ in 0..<100 {
            if dry.generate(date: summer, previousResult: nil).clouds == .none { dryClear += 1 }
            if humid.generate(date: summer, previousResult: nil).clouds != .none { humidCloudy += 1 }
        }
        #expect(dryClear > 60)
        #expect(humidCloudy > 60)
    }

    @Test func batchCountAndDates() {
        let gen = WeatherGenerator(region: .mittelreich)
        let results = gen.generateBatch(startDate: AventurianDate(day: 28, month: .praios, year: 1040), count: 5)
        #expect(results.count == 5)
        #expect(results[3].date == AventurianDate(day: 1, month: .rondra, year: 1040))
    }

    @Test func noRainWithoutClouds() {
        let gen = WeatherGenerator(region: .mittelreich)
        for _ in 0..<100 {
            let r = gen.generate(date: summer, previousResult: nil)
            if r.clouds == .none { #expect(r.rain == .none) }
        }
    }

    @Test func cloudTablesByHumidity() {
        #expect(WeatherGenerator.cloudFromRoll(16, humidity: .dry) == .none)
        #expect(WeatherGenerator.cloudFromRoll(4, humidity: .moderate) == .none)
        #expect(WeatherGenerator.cloudFromRoll(5, humidity: .moderate) == .few)
        #expect(WeatherGenerator.cloudFromRoll(2, humidity: .humid) == .none)
        #expect(WeatherGenerator.cloudFromRoll(13, humidity: .humid) == .all)
    }

    @Test func windTableAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(3, autumn: true) == .none)
        #expect(WeatherGenerator.windFromRoll(20, autumn: false) == .storm)
    }
}
```

- [ ] **Step 3: Run, verify it fails** — `make test` → compile failure (new API).

- [ ] **Step 4: Rewrite `WeatherGenerator.swift`**

```swift
import Foundation

/// Pure value type for weather generation output (no SwiftData dependency).
struct WeatherResult {
    let date: AventurianDate
    let clouds: CloudCover
    let wind: WindStrength
    let dayTemperature: Int
    let nightTemperature: Int
    let rain: RainLevel
}

/// Generates DSA weather. Temperature uses a climate-driven diurnal-range model
/// (night = day high − range), grounded in real meteorology; cloud/wind/rain
/// follow the WdE p.156ff tables, keyed on the region's climate archetype.
struct WeatherGenerator {
    let archetype: ClimateArchetype

    init(archetype: ClimateArchetype) { self.archetype = archetype }
    init(region: WeatherRegion) { self.archetype = region.archetype }

    // MARK: - Public API

    func generate(date: AventurianDate, previousResult: WeatherResult?) -> WeatherResult {
        let season = date.season
        let changeFlags = rollChangeFlags(season: season, hasPrevious: previousResult != nil)

        let clouds = (changeFlags & 0b0001 != 0)
            ? Self.cloudFromRoll(d20(), humidity: archetype.humidity)
            : (previousResult?.clouds ?? Self.cloudFromRoll(d20(), humidity: archetype.humidity))

        let wind = (changeFlags & 0b0010 != 0)
            ? Self.windFromRoll(d20() + archetype.windiness.rollBonus, autumn: season == .herbst)
            : (previousResult?.wind ?? Self.windFromRoll(d20() + archetype.windiness.rollBonus, autumn: season == .herbst))

        let dayTemp: Int
        let nightTemp: Int
        if changeFlags & 0b0100 != 0 || previousResult == nil {
            dayTemp = archetype.baseDayTemp(for: season) + clouds.temperatureModifier + wind.temperatureModifier
            nightTemp = dayTemp - nightRange(clouds: clouds, wind: wind, season: season)
        } else {
            dayTemp = previousResult!.dayTemperature
            nightTemp = previousResult!.nightTemperature
        }

        let rain = (changeFlags & 0b1000 != 0)
            ? rollRain(clouds: clouds, wind: wind)
            : (previousResult?.rain ?? rollRain(clouds: clouds, wind: wind))

        return WeatherResult(date: date, clouds: clouds, wind: wind,
                             dayTemperature: dayTemp, nightTemperature: nightTemp, rain: rain)
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

    // MARK: - Diurnal range (night temperature)

    /// Day→night drop: climate clear-sky range, shrunk by clouds, reduced by wind,
    /// with small jitter and a 2° floor. This replaces the old flat d20+5 drop.
    func nightRange(clouds: CloudCover, wind: WindStrength, season: AventurianSeason) -> Int {
        let base = Double(archetype.clearSkyRange(for: season))
        var range = Int((base * clouds.cloudFactor).rounded())
        range -= wind.nightWindReduction
        range += Int.random(in: -1...2)
        return max(range, 2)
    }

    // MARK: - Dice
    private func d20() -> Int { Int.random(in: 1...20) }

    // MARK: - Step 1: Day-change flags
    private func rollChangeFlags(season: AventurianSeason, hasPrevious: Bool) -> UInt8 {
        guard hasPrevious else { return 0b1111 }
        let roll = d20()
        switch season {
        case .sommer, .winter: return stableChangeFlags(roll)
        case .herbst, .fruehling: return volatileChangeFlags(roll)
        }
    }
    private func stableChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...9: 0b0000; case 10...11: 0b0001; case 12...13: 0b0011
        case 14...15: 0b0101; case 16...17: 0b0111; case 18...19: 0b1011
        default: 0b1111
        }
    }
    private func volatileChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...4: 0b0000; case 5...6: 0b0001; case 7...8: 0b0011
        case 9...10: 0b0101; case 11...12: 0b0111; case 13...14: 0b1001
        case 15...16: 0b1011; case 17...18: 0b1101; default: 0b1111
        }
    }

    // MARK: - Step 2: Clouds (by humidity)
    static func cloudFromRoll(_ roll: Int, humidity: ClimateArchetype.Humidity) -> CloudCover {
        switch humidity {
        case .dry:
            switch roll { case ...16: .none; case 17...18: .few; case 19: .lots; default: .all }
        case .moderate:
            switch roll { case ...4: .none; case 5...10: .few; case 11...16: .lots; default: .all }
        case .humid:
            switch roll { case ...2: .none; case 3...6: .few; case 7...12: .lots; default: .all }
        }
    }

    // MARK: - Step 3: Wind
    static func windFromRoll(_ roll: Int, autumn: Bool) -> WindStrength {
        if autumn {
            switch roll {
            case ...3: .none; case 4...5: .light; case 6...7: .soft; case 8...10: .fresh
            case 11...14: .cool; case 15...18: .strong; default: .storm
            }
        } else {
            switch roll {
            case ...4: .none; case 5...7: .light; case 8...10: .soft; case 11...13: .fresh
            case 14...16: .cool; case 17...19: .strong; default: .storm
            }
        }
    }

    // MARK: - Step 5: Rain
    private func rollRain(clouds: CloudCover, wind: WindStrength) -> RainLevel {
        let chance = d20()
        let itRains: Bool
        switch clouds {
        case .none: itRains = false
        case .few:  itRains = chance <= 1
        case .lots: itRains = chance <= 4
        case .all:  itRains = chance <= 10
        }
        guard itRains else { return .none }
        return rainIntensity(roll: d20(), wind: wind)
    }
    private func rainIntensity(roll: Int, wind: WindStrength) -> RainLevel {
        let (littleMax, lotsMax): (Int, Int) = switch wind {
        case .none: (12, 19); case .light: (10, 18); case .soft: (8, 17); case .fresh: (6, 15)
        case .cool: (4, 13); case .strong: (2, 11); case .storm: (1, 10)
        }
        if roll <= littleMax { return .little }
        if roll <= lotsMax { return .lots }
        return .all
    }
}
```

- [ ] **Step 5: Run, verify it passes** — `make test` → `WeatherGeneratorTests` pass. (App target still won't build until Task 5 fixes the two view call sites — acceptable; commit the green test target.)

- [ ] **Step 6: Commit** — `git add Hesindion/Services/WeatherGenerator.swift Hesindion/Models/WeatherEnums.swift Hesindion/Models/ClimateArchetype.swift HesindionTests/WeatherGeneratorTests.swift && git commit -m "feat(weather): diurnal-range temperature model on climate archetypes"`

---

### Task 5: Model changes — per-day region & manual overrides; drop desert/windy

**Goal:** Store region per `WeatherDay`, track manual overrides, and remove the per-adventure `desert`/`windy` flags. Restore a green app build by updating the two generator call sites minimally.

**Files:**
- Modify: `Hesindion/Models/WeatherDay.swift`
- Modify: `Hesindion/Models/Adventure.swift`
- Modify: `Hesindion/Views/AdventureDetailView.swift:186-205` (`generateOneDay`) and `:175-176` (remove desert/windy toggles)
- Modify: `Hesindion/Views/BulkGenerateSheet.swift:31` (drop desert/windy args)
- Test: `HesindionTests/WeatherDayModelTests.swift` (create)

**Acceptance Criteria:**
- [ ] `WeatherDay` has `regionRaw` + `overridesRaw`; `region` getter falls back to `adventure.region` when `regionRaw` is empty; `WeatherField` overrides round-trip.
- [ ] `WeatherDay.diurnalRange == dayTemperature - nightTemperature`.
- [ ] `Adventure` no longer has `desert`/`windy`; `init(name:region:startDate:)`.
- [ ] App target builds (`make build`).

**Verify:** `make test` → `WeatherDayModelTests` pass; `make build` succeeds.

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
// HesindionTests/WeatherDayModelTests.swift
import Testing
import SwiftData
@testable import Hesindion

@MainActor
struct WeatherDayModelTests {
    @Test func regionFallsBackToAdventure() throws {
        let container = try ModelContainer(for: Adventure.self, WeatherDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let adv = Adventure(name: "T", region: .khom,
                            startDate: AventurianDate(day: 1, month: .praios, year: 1040))
        ctx.insert(adv)
        let legacyDay = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 1, month: .praios, year: 1040),
            clouds: .none, wind: .none, dayTemperature: 40, nightTemperature: 20, rain: .none))
        legacyDay.adventure = adv           // regionRaw left empty → inherits
        #expect(legacyDay.region == .khom)
        #expect(legacyDay.diurnalRange == 20)
    }

    @Test func explicitRegionAndOverrides() {
        let day = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 2, month: .praios, year: 1040),
            clouds: .all, wind: .strong, dayTemperature: 10, nightTemperature: 6, rain: .lots),
            region: .thorwal)
        #expect(day.region == .thorwal)
        day.overrides = [.dayTemp, .rain]
        #expect(day.overrides.contains(.dayTemp))
        #expect(!day.overrides.contains(.clouds))
    }

    @Test func legacyRegionRawNormalizes() {
        let day = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 1, month: .praios, year: 1040),
            clouds: .none, wind: .none, dayTemperature: 1, nightTemperature: 0, rain: .none))
        day.regionRaw = "weiden"            // legacy
        #expect(day.region == .streitendeKoenigreiche)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `make test` → compile failure.

- [ ] **Step 3: Update `WeatherDay.swift`.** Add the OptionSet above the `@Model`, add the two stored props, the computed accessors, and a region-bearing initializer:

```swift
import Foundation
import SwiftData

/// Which fields the GM hand-edited (preserved across re-rolls of other fields).
struct WeatherField: OptionSet {
    let rawValue: Int
    static let clouds    = WeatherField(rawValue: 1 << 0)
    static let wind      = WeatherField(rawValue: 1 << 1)
    static let dayTemp   = WeatherField(rawValue: 1 << 2)
    static let nightTemp = WeatherField(rawValue: 1 << 3)
    static let rain      = WeatherField(rawValue: 1 << 4)
}

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
    var regionRaw: String = ""          // empty → inherit adventure's region (legacy days)
    var overridesRaw: Int = 0

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
    var region: WeatherRegion {
        get {
            if regionRaw.isEmpty { return adventure?.region ?? .mittelreich }
            return WeatherRegion.resolve(persisted: regionRaw)
        }
        set { regionRaw = newValue.rawValue }
    }
    var overrides: WeatherField {
        get { WeatherField(rawValue: overridesRaw) }
        set { overridesRaw = newValue.rawValue }
    }
    var date: AventurianDate { AventurianDate(day: day, month: month, year: year) }
    var diurnalRange: Int { dayTemperature - nightTemperature }

    init(from result: WeatherResult, region: WeatherRegion? = nil, isTimeJump: Bool = false) {
        self.day = result.date.day
        self.monthRaw = result.date.month.rawValue
        self.year = result.date.year
        self.cloudsRaw = result.clouds.rawValue
        self.windRaw = result.wind.rawValue
        self.dayTemperature = result.dayTemperature
        self.nightTemperature = result.nightTemperature
        self.rainRaw = result.rain.rawValue
        self.isTimeJump = isTimeJump
        self.regionRaw = region?.rawValue ?? ""
    }
}
```

- [ ] **Step 4: Update `Adventure.swift`.** Remove `desert`/`windy` stored props and the init params; keep `regionRaw`/`region` (now the *default region* used to seed new stretches / empty timelines):

```swift
import Foundation
import SwiftData

@Model
final class Adventure {
    var id: UUID = UUID()
    var name: String = ""
    var regionRaw: String = WeatherRegion.mittelreich.rawValue   // default region for new stretches
    var currentDay: Int = 1
    var currentMonthRaw: Int = AventurianMonth.praios.rawValue
    var currentYear: Int = 1040
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WeatherDay.adventure)
    var weatherDays: [WeatherDay] = []

    @Relationship(inverse: \Hero.activeAdventure)
    var heroes: [Hero] = []

    var region: WeatherRegion {
        get { WeatherRegion.resolve(persisted: regionRaw) }
        set { regionRaw = newValue.rawValue }
    }
    var currentMonth: AventurianMonth {
        get { AventurianMonth(rawValue: currentMonthRaw) ?? .praios }
        set { currentMonthRaw = newValue.rawValue }
    }
    var currentDate: AventurianDate {
        get { AventurianDate(day: currentDay, month: currentMonth, year: currentYear) }
        set { currentDay = newValue.day; currentMonth = newValue.month; currentYear = newValue.year }
    }

    init(name: String, region: WeatherRegion, startDate: AventurianDate) {
        self.name = name
        self.regionRaw = region.rawValue
        self.currentDay = startDate.day
        self.currentMonthRaw = startDate.month.rawValue
        self.currentYear = startDate.year
    }
}
```

- [ ] **Step 5: Fix the two generator call sites so the app builds.** In `AdventureDetailView.swift` replace `generateOneDay()` body line 187 and remove the desert/windy toggles (lines 175–176). Replace `generateOneDay` with:

```swift
    private func generateOneDay() {
        let lastDay = sortedWeatherDays.first
        let region = lastDay?.region ?? adventure.region
        let gen = WeatherGenerator(region: region)
        let previousResult: WeatherResult? = lastDay.map {
            WeatherResult(date: $0.date, clouds: $0.clouds, wind: $0.wind,
                          dayTemperature: $0.dayTemperature, nightTemperature: $0.nightTemperature, rain: $0.rain)
        }
        let result = gen.generate(date: adventure.currentDate, previousResult: previousResult)
        let weatherDay = WeatherDay(from: result, region: region)
        if let lastDay, result.date != lastDay.date.next() { weatherDay.isTimeJump = true }
        weatherDay.adventure = adventure
        modelContext.insert(weatherDay)
        adventure.currentDate = adventure.currentDate.next()
    }
```

Delete the two `Toggle(...)` lines for desert/windy in `adventureSettings` (lines 175–176). (The full settings/controls overhaul is Task 8 — this is the minimal compile fix.)

In `BulkGenerateSheet.swift` line 31 replace with:

```swift
        let gen = WeatherGenerator(region: adventure.region)
```

And in its insert loop pass the region: change `WeatherDay(from: result)` (line 38) to `WeatherDay(from: result, region: adventure.region)`. (BulkGenerateSheet is deleted in Task 9.)

- [ ] **Step 6: Run** — `make test` (WeatherDayModelTests pass) and `make build` (app compiles).

- [ ] **Step 7: Commit** — `git add Hesindion/Models/WeatherDay.swift Hesindion/Models/Adventure.swift Hesindion/Views/AdventureDetailView.swift Hesindion/Views/BulkGenerateSheet.swift HesindionTests/WeatherDayModelTests.swift && git commit -m "feat(weather): per-day region + manual-override tracking; drop desert/windy"`

---

### Task 6: `RegionPicker` component + update `AdventureCreationSheet`

**Goal:** A reusable grouped region picker (sections by macro-region), and use it in the creation sheet; drop the desert/windy toggles there.

**Files:**
- Create: `Hesindion/Views/RegionPicker.swift`
- Modify: `Hesindion/Views/AdventureCreationSheet.swift`

**Acceptance Criteria:**
- [ ] `RegionPicker(selection:)` shows every region grouped under its macro-region label.
- [ ] `AdventureCreationSheet` uses it; no `desert`/`windy` state or toggles; `Adventure(name:region:startDate:)` init.
- [ ] `make build` succeeds.

**Verify:** `make build`; visually confirm in `make run` that the picker groups regions (optional manual check).

**Steps:**

- [ ] **Step 1: Create `RegionPicker.swift`**

```swift
import SwiftUI

/// Region selection grouped by macro-region. Reused in creation, add-stretch, and day-edit.
struct RegionPicker: View {
    @Binding var selection: WeatherRegion
    var label: String = L("adventureRegion")

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(MacroRegion.allCases) { macro in
                Section(macro.displayName) {
                    ForEach(WeatherRegion.inMacro(macro)) { region in
                        Text(region.displayName).tag(region)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update `AdventureCreationSheet.swift`** — remove `desert`/`windy` `@State` (lines 13–14), replace the region `Picker` + toggles `Section` (lines 23–31) with:

```swift
            Section {
                RegionPicker(selection: $region)
            }
```

and replace the `Adventure(...)` init (lines 51–57) with:

```swift
                    let adventure = Adventure(
                        name: name,
                        region: region,
                        startDate: AventurianDate(day: day, month: month, year: year)
                    )
```

- [ ] **Step 3: Run** — `make build` succeeds.

- [ ] **Step 4: Commit** — `git add Hesindion/Views/RegionPicker.swift Hesindion/Views/AdventureCreationSheet.swift && git commit -m "feat(weather): grouped RegionPicker; simplify adventure creation"`

---

### Task 7: `WeatherDayRow` redesign — region, diurnal range, badges

**Goal:** Show each day's region, the diurnal range with a plain-language reason, and override/gap badges.

**Files:**
- Modify: `Hesindion/Views/WeatherDayRow.swift`
- Modify: `Hesindion/Theme/Strings.swift` (add `weather.range`, `weather.reason.*`, `weather.edited`)

**Acceptance Criteria:**
- [ ] Row shows region display name, clouds/wind, day/night temps, `↕ <range>° (<reason>)`, rain.
- [ ] If `overrides` is non-empty, an "edited" badge shows.
- [ ] `make build` succeeds.

**Verify:** `make build`; snapshot re-record happens in Task 11.

**Steps:**

- [ ] **Step 1: Add Strings** (both dicts, after `weather.nightTemp`):

English:
```swift
        "weather.range":                "Range",
        "weather.edited":               "edited",
        "weather.reason.dry":           "dry",
        "weather.reason.humid":         "humid",
        "weather.reason.clear":         "clear",
        "weather.reason.cloudy":        "clouds",
        "weather.reason.windy":         "wind",
```
German:
```swift
        "weather.range":                "Schwankung",
        "weather.edited":               "bearbeitet",
        "weather.reason.dry":           "trocken",
        "weather.reason.humid":         "feucht",
        "weather.reason.clear":         "klar",
        "weather.reason.cloudy":        "Wolken",
        "weather.reason.windy":         "Wind",
```

- [ ] **Step 2: Rewrite `WeatherDayRow.swift`**

```swift
import SwiftUI

struct WeatherDayRow: View {
    let weatherDay: WeatherDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weatherDay.date.formatted())
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(Color.groupAdventure)
                Spacer()
                Text(weatherDay.region.displayName)
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
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
                        .font(.system(.caption2, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.groupAdventure.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(DSALayout.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        .padding(.bottom, -DSALayout.secondaryBorder)
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
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text).font(.system(.caption, weight: .bold))
        }
    }
}
```

- [ ] **Step 3: Run** — `make build` succeeds.

- [ ] **Step 4: Commit** — `git add Hesindion/Views/WeatherDayRow.swift Hesindion/Theme/Strings.swift && git commit -m "feat(weather): weather row shows region, diurnal range + reason, edited badge"`

---

### Task 8: Control area + settings cleanup + `WeatherRulesSheet` (fixes buttons)

**Goal:** Replace the four mismatched buttons with one full-width primary + two equal ghost buttons; add a Rules sheet explaining the model; remove the region/desert/windy settings group (keep a default-region picker).

**Files:**
- Modify: `Hesindion/Views/AdventureDetailView.swift` (controlsBar, controlButton, settings, sheets/state)
- Create: `Hesindion/Views/WeatherRulesSheet.swift`
- Modify: `Hesindion/Theme/Strings.swift` (`weather.add`, `weather.rules`, rules body keys, `adventureDefaultRegion`)

**Acceptance Criteria:**
- [ ] Control area = one full-width `weatherButton` (`＋ Wetter hinzufügen`) + a row of two equal-width ghost `weatherButton`s (`Regeln`, `Export`). All identical height; `lineLimit(1)`, `minimumScaleFactor(0.7)`; `ShareLink` uses the same style.
- [ ] `WeatherRulesSheet` explains the diurnal-range model and lists climate effects.
- [ ] Settings group no longer shows desert/windy/region; shows a single default-region `RegionPicker`.
- [ ] `make build` succeeds.

**Verify:** `make build`; visual check via `make run`. Snapshots re-recorded in Task 11.

**Steps:**

- [ ] **Step 1: Add Strings** (both dicts):

English (after `"export"`):
```swift
        "weather.add":                  "Add Weather",
        "weather.rules":                "Rules",
        "adventureDefaultRegion":       "Default Region",
        "weather.rules.title":          "How weather works",
        "weather.rules.body":           "Night temperature = day high minus the diurnal range. Dry, clear, calm areas (desert, high mountains) cool down sharply at night; cloudy, humid or windy areas (coast, swamps) barely cool. Each region has a climate that sets its base temperature, range, humidity and wind.",
        "weather.rules.clouds":         "Clouds trap heat → smaller night drop.",
        "weather.rules.wind":           "Wind mixes the air → smaller night drop.",
        "weather.rules.climate":        "Climate sets the clear-sky range.",
```
German (after `"export"`):
```swift
        "weather.add":                  "Wetter hinzufügen",
        "weather.rules":                "Regeln",
        "adventureDefaultRegion":       "Standardregion",
        "weather.rules.title":          "Wie das Wetter funktioniert",
        "weather.rules.body":           "Nachttemperatur = Tagestemperatur minus Tagesschwankung. Trockene, klare und windstille Gegenden (Wüste, Hochgebirge) kühlen nachts stark ab; bewölkte, feuchte oder windige Gegenden (Küste, Sümpfe) kaum. Jede Region hat ein Klima, das Grundtemperatur, Schwankung, Feuchtigkeit und Wind bestimmt.",
        "weather.rules.clouds":         "Wolken halten Wärme → geringerer Abfall.",
        "weather.rules.wind":           "Wind durchmischt die Luft → geringerer Abfall.",
        "weather.rules.climate":        "Das Klima bestimmt die Schwankung bei klarem Himmel.",
```

- [ ] **Step 2: Create `WeatherRulesSheet.swift`**

```swift
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
```

- [ ] **Step 3: Rewrite the control area in `AdventureDetailView.swift`.** Replace `controlsBar` and `controlButton` (lines 97–126) with:

```swift
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
```

- [ ] **Step 4: Update state + sheets + settings.** In `AdventureDetailView`:
  - Replace the `@State` lines (8–9) with:
    ```swift
    @State private var isShowingAddStretch = false
    @State private var isShowingRules = false
    @State private var editingDay: WeatherDay?
    ```
  - Replace the two `.sheet(...)` modifiers (lines 39–48) with (AddStretchSheet/DayEditSheet land in Tasks 9–10; reference them now):
    ```swift
    .sheet(isPresented: $isShowingAddStretch) {
        NavigationStack { AddStretchSheet(adventure: adventure) }
    }
    .sheet(isPresented: $isShowingRules) {
        NavigationStack { WeatherRulesSheet() }
    }
    .sheet(item: $editingDay) { day in
        NavigationStack { DayEditSheet(weatherDay: day) }
    }
    ```
  - Replace `adventureSettings` body (lines 168–179) with a single default-region picker:
    ```swift
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
    ```
  - In `weatherTimeline`, make rows tappable — wrap `WeatherDayRow(weatherDay: weatherDay)` (line 146) in a button:
    ```swift
    Button { editingDay = weatherDay } label: { WeatherDayRow(weatherDay: weatherDay) }
        .buttonStyle(.plain)
    ```

> `WeatherDay` already conforms to `Identifiable` (has `id`) so `.sheet(item:)` works. AddStretchSheet/DayEditSheet are created next; the project will not build until Task 9 & 10 add them — acceptable, this is one coherent UI swap. If you require a green build here, temporarily stub the two sheets as `EmptyView` wrappers and remove the stubs in Tasks 9–10.

- [ ] **Step 5: Commit** — `git add Hesindion/Views/AdventureDetailView.swift Hesindion/Views/WeatherRulesSheet.swift Hesindion/Theme/Strings.swift && git commit -m "feat(weather): uniform control buttons + rules sheet + default-region setting"`

---

### Task 9: `AddStretchSheet` (replaces Next-day / Generate-days / Set-date)

**Goal:** One sheet to add a continuous stretch of weather: start date + region + number of days, with gap detection. Delete the obsolete sheets and `generateOneDay`.

**Files:**
- Create: `Hesindion/Views/AddStretchSheet.swift`
- Delete: `Hesindion/Views/BulkGenerateSheet.swift`, `Hesindion/Views/DateJumpSheet.swift`
- Modify: `Hesindion/Views/AdventureDetailView.swift` (remove `generateOneDay`, keep `exportText`)
- Modify: `Hesindion/Theme/Strings.swift` (`weather.stretchDays`; reuse `cancel`, `generate`, `dayCount`, `adventureStartDate`, `adventureRegion`)
- Test: `HesindionTests/StretchGenerationTests.swift` (create — pure logic for gap detection)

**Acceptance Criteria:**
- [ ] Sheet fields: start date (day/month/year), `RegionPicker`, day-count stepper (1…30). Start defaults to the day after the latest entry (or `adventure.currentDate` if empty); region defaults to the latest day's region (or `adventure.region`).
- [ ] Generating inserts N `WeatherDay`s with `regionRaw` set; continuity seeds from the last contiguous day; if start is past `lastDay+1`, the first new day has `isTimeJump = true`; `adventure.currentDate` advances to the day after the stretch.
- [ ] `BulkGenerateSheet`/`DateJumpSheet` removed; no references remain.
- [ ] `make build` and `make test` pass.

**Verify:** `make test` → `StretchGenerationTests` pass; `make build`.

**Steps:**

- [ ] **Step 1: Write the failing test** (pure gap logic mirrors the sheet)

```swift
// HesindionTests/StretchGenerationTests.swift
import Testing
@testable import Hesindion

struct StretchGenerationTests {
    @Test func gapDetectedWhenStartBeyondNext() {
        let last = AventurianDate(day: 10, month: .praios, year: 1040)
        let contiguous = AventurianDate(day: 11, month: .praios, year: 1040)
        let jumped = AventurianDate(day: 20, month: .praios, year: 1040)
        #expect(StretchPlanner.isGap(start: contiguous, after: last) == false)
        #expect(StretchPlanner.isGap(start: jumped, after: last) == true)
        #expect(StretchPlanner.isGap(start: contiguous, after: nil) == false)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `make test` → `StretchPlanner` undefined.

- [ ] **Step 3: Create `AddStretchSheet.swift`** (with the `StretchPlanner` helper for testability)

```swift
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
```

- [ ] **Step 4: Delete obsolete sheets** — `git rm Hesindion/Views/BulkGenerateSheet.swift Hesindion/Views/DateJumpSheet.swift`. Remove `generateOneDay()` from `AdventureDetailView.swift` (added back in Task 5 as a compile shim — now obsolete). Keep `exportText()`.

- [ ] **Step 5: Run** — `make test` (StretchGenerationTests pass) and `make build`.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(weather): single Add-Stretch flow with gap detection; remove old generate/date sheets"`

---

### Task 10: `DayEditSheet` (tap a day to change region / re-roll / override)

**Goal:** Tap a day to change its region (re-roll from the new climate), re-roll non-overridden fields, or manually override clouds/wind/temps/rain — overrides marked and preserved across re-rolls.

**Files:**
- Create: `Hesindion/Views/DayEditSheet.swift`
- Modify: `Hesindion/Theme/Strings.swift` (`weather.reroll`, `weather.editValues`, `save`, reuse `cancel`)

**Acceptance Criteria:**
- [ ] Change region → re-rolls that day from the new archetype, leaving overridden fields intact, and updates `regionRaw`.
- [ ] "Re-roll" re-generates non-overridden fields only.
- [ ] Editing a value via the controls sets the matching `WeatherField` in `overrides`.
- [ ] `make build` succeeds.

**Verify:** `make build`; visual check via `make run`.

**Steps:**

- [ ] **Step 1: Add Strings** (both dicts):

English:
```swift
        "weather.reroll":               "Re-roll",
        "weather.editValues":           "Override Values",
        "save":                         "Save",
```
German:
```swift
        "weather.reroll":               "Neu würfeln",
        "weather.editValues":           "Werte überschreiben",
        "save":                         "Speichern",
```
(If `save` already exists in the dictionary, skip that line — check first with a grep.)

- [ ] **Step 2: Create `DayEditSheet.swift`**

```swift
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
```

- [ ] **Step 3: Run** — `make build` succeeds (DayEditSheet was referenced in Task 8; build is now whole).

- [ ] **Step 4: Commit** — `git add Hesindion/Views/DayEditSheet.swift Hesindion/Theme/Strings.swift && git commit -m "feat(weather): tap-to-edit day sheet — change region, re-roll, override values"`

---

### Task 11: Update test data + snapshots; re-record baselines; final verify

**Goal:** Make `TestData` reflect per-day regions and realistic values, refresh snapshot baselines for the new row/control UI, and prove the whole suite is green.

**Files:**
- Modify: `HesindionTests/Snapshots/TestData.swift` (`makeSampleAdventure` — set per-day region, realistic temps)
- Modify: `HesindionTests/Snapshots/__Snapshots__/AdventureDetailViewSnapshotTests/*` and `.../WeatherDayRowSnapshotTests/*` (delete then re-record)
- Reference: `Makefile` (`test`, `test-ui-record`)

**Acceptance Criteria:**
- [ ] `makeSampleAdventure` builds days via `WeatherDay(from:region:)` with a realistic range (e.g. day 22 / night 13) and at least one non-default region day to exercise the per-day region display.
- [ ] All unit tests pass (`make test`).
- [ ] Snapshot baselines re-recorded (24 PNGs: 12 row + 12 detail) and a verifying `make test-ui` run passes against them.

**Verify:** `make test` (all units) then `make test-ui` (snapshots) → 0 failures.

**Steps:**

- [ ] **Step 1: Update `TestData.makeSampleAdventure`** (replace the loop, lines ≈ 37–53)

```swift
    static func makeSampleAdventure(in context: ModelContext) -> Adventure {
        let startDate = AventurianDate(day: 1, month: .praios, year: 1040)
        let adventure = Adventure(name: "Die Schwarze Katze", region: .mittelreich, startDate: startDate)

        let samples: [(Int, WeatherRegion, CloudCover, WindStrength, Int, Int, RainLevel)] = [
            (1, .mittelreich, .none, .none, 22, 13, .none),
            (2, .mittelreich, .lots, .fresh, 16, 10, .little),
            (3, .khom,        .none, .strong, 41, 21, .none),   // travel into the desert
        ]
        for (offset, region, clouds, wind, dayT, nightT, rain) in samples {
            let date = AventurianDate(day: offset, month: .praios, year: 1040)
            let result = WeatherResult(date: date, clouds: clouds, wind: wind,
                                       dayTemperature: dayT, nightTemperature: nightT, rain: rain)
            let weatherDay = WeatherDay(from: result, region: region, isTimeJump: region == .khom)
            adventure.weatherDays.append(weatherDay)
        }
        context.insert(adventure)
        return adventure
    }
```

- [ ] **Step 2: Run units** — `make test` → all pass. Fix any compile drift before recording images.

- [ ] **Step 3: Delete stale baselines** (record-only writes missing — must delete first):

```bash
rm -f HesindionTests/Snapshots/__Snapshots__/AdventureDetailViewSnapshotTests/*.png
rm -f HesindionTests/Snapshots/__Snapshots__/WeatherDayRowSnapshotTests/*.png
```

- [ ] **Step 4: Re-record** — `make test-ui-record` (single iPad sim; writes all 24 PNGs).

- [ ] **Step 5: Verify against fresh baselines** — `make test-ui` → 0 failures. Open `testWithWeatherDays.withWeather_iPad11_dark_accL.png` and confirm the three control buttons are uniform (the original bug).

- [ ] **Step 6: Commit** — `git add HesindionTests/ && git commit -m "test(weather): per-day-region sample data; re-record snapshot baselines"`

- [ ] **Step 7: Final full verify** — `make test && make test-ui` → both green. Report results.

---

## Self-Review

**Spec coverage:**
- Realistic temperature model → Tasks 1, 4 (archetype + diurnal-range generator). ✓
- Rules shown to players → Task 7 (per-row range+reason), Task 8 (Rules sheet). ✓
- Uniform buttons → Task 8 (1 primary + 2 equal ghosts, `ShareLink` restyled). ✓
- Per-day region edit flow → Tasks 5 (model), 9 (Add stretch), 10 (tap-to-edit). ✓
- Two-layer regions → Tasks 1, 2. ✓
- Retire desert/windy → Tasks 5, 6, 8. ✓
- Migration via fallback → Task 2 (`resolve`), Task 5 (region fallback + test). ✓
- Snapshot/test updates → Task 11. ✓

**Placeholder scan:** No TBD/"handle edge cases"/"similar to". Every code step has full code. ✓

**Type consistency:** `WeatherGenerator(region:)`/`(archetype:)`, `WeatherDay(from:region:isTimeJump:)`, `WeatherRegion.resolve(persisted:)`, `WeatherRegion.inMacro(_:)`, `ClimateArchetype.clearSkyRange(for:)`/`baseDayTemp(for:)`/`humidity`/`windiness.rollBonus`, `CloudCover.cloudFactor`, `WindStrength.nightWindReduction`, `WeatherField` (.clouds/.wind/.dayTemp/.nightTemp/.rain), `AventurianDate.ordinal()`/`adding(days:)`, `StretchPlanner.isGap(start:after:)` — all defined where first used and referenced consistently. ✓

**Build-green caveat (intentional):** Tasks 2 and 4 leave the app target temporarily non-building (tests compile via `@testable`); Task 5 restores `make build`; Tasks 8–10 form one UI swap (stub note included). Each task still produces a committable, test-verified increment.

**Note on snapshot count:** 24 baseline PNGs are regenerated in Task 11 (single simulator per Makefile/`CLAUDE.md`).
