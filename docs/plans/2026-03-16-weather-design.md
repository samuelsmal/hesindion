# Weather Generation Feature Design

## Summary

Standalone GM tool for generating DSA weather day-by-day or in bulk, organized by adventure. Ports the DSA 4.1 (WdE p.156ff) weather tables into the app with full aventurian calendar support and plain-text export for sharing via Telegram.

## Data Models

### Adventure (`@Model`)

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| name | String | User-given name, e.g. "Reise nach Gareth" |
| region | WeatherRegion | One of 13 climate regions |
| currentDay | Int | Day within current month (1-30, or 1-5 for Namenlose Tage) |
| currentMonth | AventurianMonth | Current month enum |
| currentYear | Int | e.g. 1040 BF |
| desert | Bool | Desert modifier (shifts cloud table toward clear) |
| windy | Bool | Windy modifier (+2 to wind roll) |
| createdAt | Date | Real-world creation timestamp |
| weatherDays | [WeatherDay] | Inverse relationship, cascade delete |
| heroes | [Hero] | Inverse of Hero.activeAdventure |

### WeatherDay (`@Model`)

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| adventure | Adventure | Parent relationship |
| day | Int | 1-30 (or 1-5 for Namenlose Tage) |
| month | AventurianMonth | Month enum |
| year | Int | Aventurian year |
| clouds | CloudCover | none / few / lots / all |
| wind | WindStrength | none / light / soft / fresh / cool / strong / storm |
| dayTemperature | Int | Daytime temperature in degrees |
| nightTemperature | Int | Nighttime temperature in degrees |
| rain | RainLevel | none / little / lots / all |
| isTimeJump | Bool | True if this day starts after a date jump (visual divider) |
| generatedAt | Date | Real-world timestamp |

### Hero Extension

- `activeAdventure: Adventure?` — optional relationship added to existing Hero model

### Enums

**AventurianMonth**: praios, rondra, efferd, travia, boron, hesinde, firun, tsa, phex, peraine, ingerimm, rahja, namenloseTage

**AventurianSeason** (computed from month):
- sommer: Praios, Rondra, Rahja
- herbst: Efferd, Travia, Boron
- winter: Hesinde, Firun, Tsa
- fruehling: Phex, Peraine, Ingerimm
- Namenlose Tage use sommer (they fall between Rahja and Praios)

**WeatherRegion** (13 regions with base temperature tuples `(summer, spring/autumn, winter)`):

| Region | Display Name | Summer | Spring/Autumn | Winter |
|--------|-------------|--------|---------------|--------|
| ewigesEis | Ewiges Eis | -20 | -30 | -40 |
| ehernesSchwert | Höhen des Ehernen Schwerts | -10 | -20 | -30 |
| hoherNorden | Hoher Norden | 0 | -10 | -20 |
| tundra | Tundra und Taiga | 5 | 0 | -5 |
| thorwal | Bornland, Thorwal | 10 | 3 | -5 |
| weiden | Streitende Königreiche bis Weiden | 10 | 5 | 0 |
| mittelreich | Zentrales Mittelreich | 15 | 10 | 5 |
| almada | Nördliches Horasreich, Almada, Aranien | 20 | 15 | 10 |
| raschtulswall | Höhen des Raschtulswalls | 5 | 0 | -10 |
| horasreichSued | Südliches Horasreich, Reich der Ersten Sonne | 25 | 20 | 15 |
| khom | Khom | 40 | 35 | 30 |
| echsensuempfe | Echsensümpfe, Meridiana | 30 | 25 | 20 |
| suedmeer | Altoum, Gewürzinseln, Südmeer | 35 | 30 | 25 |

**CloudCover**: none (+10° mod), few (+5°), lots (+0°), all (-5°)

**WindStrength**: none (+4°), light (+2°), soft (0°), fresh (0°), cool (-2°), strong (-4°), storm (-6°)

**RainLevel**: none, little, lots, all

## Aventurian Calendar

### Structure
- 12 months × 30 days = 360 days
- 5 Namenlose Tage between Rahja and Praios = 365 days total
- Year advances after Namenlose Tage day 5 → Praios day 1

### AventurianDate Struct
Value type with `month`, `day`, `year` fields and:
- `.next()` — advances by one day, handling month/year rollovers
- `.season` — computed from month
- `.formatted()` — e.g. "12. Praios 1040 BF"

### Month Order
Praios → Rondra → Efferd → Travia → Boron → Hesinde → Firun → Tsa → Phex → Peraine → Ingerimm → Rahja → Namenlose Tage → (next year) Praios

## Weather Generation Algorithm

Pure Swift `WeatherGenerator` struct. No side effects, easy to test.

### API

```
struct WeatherGenerator {
    var region: WeatherRegion
    var desert: Bool
    var windy: Bool
    var previousDay: WeatherDay?  // nil = fresh roll

    func generate(date: AventurianDate) -> WeatherDay
    func generateBatch(startDate: AventurianDate, count: Int) -> [WeatherDay]
}
```

### Steps (all d20-based)

**Step 1 — Day-change flags (d20)**
If previousDay exists, roll to determine which aspects re-roll vs. carry over:
- Summer/Winter (stable): 1-9 = nothing changes (45%), progressively more up to 20 = all change
- Spring/Autumn (volatile): 1-4 = nothing changes (20%), changes start at 5, 19-20 = all change
- Uses bitmask: clouds=0b0001, wind=0b0010, temp=0b0100, rain=0b1000
- If no previous day (first day or after time jump), all flags set to 0b1111

**Step 2 — Clouds (d20)**
- Normal: 1-4 = none, 5-10 = few, 11-16 = lots, 17-20 = all
- Desert: 1-16 = none, 17-18 = few, 19 = lots, 20 = all

**Step 3 — Wind (d20, +2 if windy)**
- Autumn: 1-3 = none, 4-5 = light, 6-7 = soft, 8-10 = fresh, 11-14 = cool, 15-18 = strong, 19+ = storm
- Other seasons: 1-4 = none, 5-7 = light, 8-10 = soft, 11-13 = fresh, 14-16 = cool, 17-19 = strong, 20+ = storm

**Step 4 — Temperature**
- day_temp = region.baseTemp(season) + cloudMod + windMod
- night_temp = region.baseTemp(season) + windMod - cloudMod - (d20 + 5)

**Step 5 — Rain (two-phase d20)**
- Phase 1 — does it rain? Based on cloud cover:
  - none = never, few = on 1, lots = on 1-4, all = on 1-10
- Phase 2 — how much? Cross-referenced with wind:
  - Higher wind shifts toward heavier rain
  - E.g., no wind: little 1-12, lots 13-19, all 20
  - Storm wind: little 1, lots 2-10, all 11-20

### Randomness
Uses `Int.random(in: 1...20)` with Swift's system RNG. No seeded RNG needed — reproducibility comes from persisted results.

## Navigation & Views

### Sidebar

New "Abenteuer" section between Helden and Regelwerk:
- `SidebarSelection.adventure(PersistentIdentifier)` case added
- List of adventures with "+" button to create new ones

### AdventureDetailView

```
AdventureDetailView
├── Header: name + region + current date
├── Controls Bar
│   ├── "Nächster Tag" — generate one day
│   ├── "Tage generieren..." — bulk generate (pick count)
│   ├── "Datum setzen..." — jump to new date
│   └── Share button — export weather log
├── Weather Timeline (scrollable, newest on top)
│   ├── [Time jump divider if applicable]
│   ├── WeatherDayRow: date + clouds + wind + temps + rain
│   └── ...
└── Settings (collapsible)
    ├── Region picker
    ├── Desert toggle
    └── Windy toggle
```

### AdventureCreationSheet

Modal with: name, region picker, starting date (month + day + year), desert/windy toggles.

### DateJumpSheet

Month + day + year pickers. Inserts visual divider in timeline. Next generation starts fresh (no carry-over).

## Hero ↔ Adventure Linking

- Hero gets optional `activeAdventure` relationship
- Set via HeroDetailView or HeroSettingsView picker
- Multiple heroes can share one adventure
- Adventure header shows linked hero avatars
- Purely organizational for now — no gameplay impact

## Export

Plain text via iOS share sheet:

```
Reise nach Gareth — Wetter (Zentrales Mittelreich)

12. Praios 1040 BF: Wenige Wolken, leichter Wind, 20°/5°, kein Niederschlag
11. Praios 1040 BF: Bedeckt, frischer Wind, 12°/-2°, leichter Regen
```

## Styling

- New group color for Abenteuer: warm orange/amber
- 3px primary borders on adventure header and cards
- 2px secondary borders on weather day rows
- Bold `.black` weight for headers, monospaced for temperatures
- Existing `CollapsibleGroup` for settings section
- iPad: `SplitContentLayout` wrapper, no side panel needed

## Source Reference

Algorithm ported from [dsa-tools-rust](https://github.com/lHeidbreder/dsa-tools-rust) (`src/bin/dsa-wetter.rs`), which implements DSA 4.1 "Wege der Entdeckungen" p.156ff weather tables. Desert cloud table bug fixed in our port.
