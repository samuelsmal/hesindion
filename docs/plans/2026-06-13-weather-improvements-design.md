# Weather Feature Improvements — Design

**Date:** 2026-06-13
**Status:** Approved design, ready for implementation planning
**Worktree:** `weather-improvements`

## Problem

Three issues with the current weather feature:

1. **Unrealistic temperatures.** Night temp = `dayTemp − (d20+5)`, a flat 6–25° drop with no regard for clouds, season, or climate. Clear calm summer nights freeze. Separately, day temp = `base + cloudMod + windMod` with large swings stacks into impossible highs (Khôm clear summer = 40 +10 +4 = **54°**). The rules are invisible to players.
2. **Inconsistent buttons.** The control bar has four buttons (`Nächster Tag`, `Tage generieren`, `Datum setzen`, `Exportieren`) with mismatched widths and heights; `ShareLink` is styled separately from `controlButton`, and labels wrap unpredictably at large text sizes. Visible in `testWithWeatherDays.withWeather_iPad11_dark_accL.png`.
3. **Poor edit flow.** Region is locked per-adventure, but heroes travel region to region. Generation is one-day-at-a-time or bulk, auto-advancing a single `currentDate`. Players don't continuously generate days — they jump (e.g. ignore weather in a city).

## Decisions captured (brainstorming)

- **Usage model:** a continuous day-by-day timeline; **region is set per day**; **jumps skip days and are marked as gaps** (no fill).
- **Generate flow:** one **"Add stretch"** action (start date + region + #days) replaces the three separate buttons.
- **Editing:** tap a day to **edit + regenerate** — change its region (re-roll from the new climate) or manually override any value; overrides are marked and survive re-rolls of other fields.
- **Model scope:** **full redesign** — climate becomes intrinsic to region; night = day − realistic diurnal range; day swings softened; per-adventure `desert`/`windy` flags retired.
- **Regions:** **two layers** — ~22 named regions (from the Aventurien wiki) each mapped to one of ~12 **climate archetypes**. Players pick the place; the archetype carries the weather numbers.
- **Buttons:** **1 full-width primary + 2 equal-width ghost buttons** (Wetter hinzufügen / Regeln / Export), uniform at all text sizes.

---

## Architecture

### Layer 1 — `ClimateArchetype` (the weather engine)

A new enum. Each case carries the full climate profile. This is the single source of truth for the weather math; the WdE per-zone tables become archetype properties.

```
enum ClimateArchetype {
  case polar, subarctic, highMountainIce, highMountain,
       coldCoast, coldContinental, temperate, mediterranean,
       semiArid, desert, subtropicalHot, tropicalHumid, tropicalSea
}
```

Each archetype provides:

| Property | Meaning | Drives |
|---|---|---|
| `baseDayTemp(season) -> Int` | typical day high baseline (summer/spring-autumn/winter) | day temperature |
| `clearSkyRange(season) -> Int` | diurnal range under clear, calm skies (°C) | night temperature |
| `humidity: Dry \| Moderate \| Humid` | dryness of the air | cloud table + rain probability |
| `windiness: Calm \| Moderate \| Windy` | prevailing wind | wind roll bonus |

**Base day temps** reuse the existing WdE zone numbers (re-homed onto archetypes). **Diurnal ranges** are grounded in real meteorology anchors mapped to each wiki-classified zone:

| Archetype | base day S/SA/W | clear-sky range S/SA/W | humidity | wind |
|---|---|---|---|---|
| polar | −20 / −30 / −40 | 10 / 9 / 7 | Dry | Windy |
| subarctic | 5 / 0 / −5 | 14 / 11 / 8 | Dry | Windy |
| highMountainIce | −10 / −20 / −30 | 14 / 12 / 9 | Dry | Windy |
| highMountain | 5 / 0 / −10 | 16 / 13 / 10 | Dry | Windy |
| coldCoast (Thorwal) | 10 / 3 / −5 | 9 / 8 / 7 | Moderate | Windy |
| coldContinental (Bornland) | 10 / 3 / −5 | 14 / 11 / 8 | Moderate | Moderate |
| temperate (Mittelreich) | 15 / 10 / 5 | 14 / 11 / 8 | Moderate | Calm |
| mediterranean (Almada) | 20 / 15 / 10 | 13 / 11 / 9 | Moderate | Moderate |
| semiArid (Aranien) | 25 / 18 / 12 | 18 / 15 / 12 | Dry | Windy |
| desert (Khôm) | 40 / 35 / 30 | 26 / 24 / 20 | Dry | Windy |
| subtropicalHot (Erste Sonne) | 30 / 25 / 18 | 16 / 14 / 11 | Dry | Moderate |
| tropicalHumid (Meridiana, Echsensümpfe, Maraskan) | 30 / 25 / 20 | 6 / 5 / 5 | Humid | Calm |
| tropicalSea (Südmeer) | 35 / 30 / 25 | 4 / 4 / 4 | Humid | Moderate |

(Numbers are tunable; they live in one place.)

### Layer 2 — `WeatherRegion` (player-facing, named)

The existing enum is replaced by a richer list of ~22 recognizable regions, each mapping to one archetype and grouped by macro-region for the picker:

- **Hoher Norden:** Ewiges Eis → polar · Nivesenland/Tundra → subarctic · Gjalskerland → subarctic
- **Hochgebirge:** Ehernes Schwert → highMountainIce · Raschtulswall → highMountain
- **Nordaventurien:** Thorwal → coldCoast · Bornland → coldContinental · Svelltland → coldContinental · Orkland → subarctic
- **Zentralaventurien:** Zentrales Mittelreich → temperate · Streitende Königreiche/Weiden → temperate · Elfenlande → temperate
- **Tulamidenlande:** Aranien → semiArid · Khôm → desert · Mhanadi-Tal/Unau → subtropicalHot
- **Südaventurien:** Almada → mediterranean · Horasreich/Liebliches Feld → mediterranean · Reich der Ersten Sonne → subtropicalHot · Zyklopeninseln → mediterranean
- **Tiefer Süden & Inseln:** Al'Anfa/Meridiana → tropicalHumid · Echsensümpfe → tropicalHumid · Maraskan → tropicalHumid · Altoum/Gewürzinseln/Südmeer → tropicalSea

`WeatherRegion` provides: `displayName`, `macroRegion` (for grouped picker), `archetype`.

---

## Weather generation model

`WeatherGenerator` is keyed on a `ClimateArchetype` (resolved from the day's region), not on the old `region/desert/windy` triple.

### Day temperature (softened swings)

```
dayTemp = archetype.baseDayTemp(season) + cloudDayMod + windDayMod
```

Softened modifiers so highs stay sane (old values in parentheses):

- Clouds: none **+6** (was +10) · few **+3** (+5) · lots **−1** (0) · all **−4** (−5)
- Wind: none **+2** (+4) · light **+1** (+2) · soft **0** · fresh **−1** (0) · cool **−2** · strong **−3** (−4) · storm **−4** (−6)

Result: Khôm clear summer = 40 +6 +2 = **48°** (plausible desert extreme); Mittelreich clear calm summer = 15 +6 +2 = **23°**.

### Night temperature (the diurnal-range heuristic)

```
range = round(archetype.clearSkyRange(season) × cloudFactor) − windReduction + jitter
range = max(range, 2)                      // floor
nightTemp = dayTemp − range
```

- `cloudFactor`: none **1.0** · few **0.8** · lots **0.6** · all **0.45** (clouds trap heat overnight)
- `windReduction` (°C): none/light **0** · soft/fresh **2** · cool/strong **4** · storm **5** (wind mixes the boundary layer, warms nights)
- `jitter`: random **−1…+2** (small, never the dominant term — this was the old bug)

Worked examples:
- Mittelreich · summer · clear · calm → range 15 → day 23 / **night 8**
- Khôm · summer · clear · calm → range 26 → day 48 / **night 22** (no more freezing desert summer night)
- Thorwal · autumn · overcast · strong wind → range 8×0.45−4=−0.4→floor 2 → day ~2 / **night ~0**

### Humidity → clouds & rain (replaces `desert` flag)

- `Dry`: clear-favoring cloud table (today's desert table), low rain probability
- `Moderate`: today's normal cloud table
- `Humid`: cloud-favoring table (new), higher rain probability — tropical/swamp/sea

### Windiness → wind roll (replaces `windy` flag)

- `Calm` +0 · `Moderate` +0 · `Windy` +2 to the wind roll (today's `windy` behavior, now intrinsic)

### Rules shown to players (requirement)

- **Per day:** each row shows `↕ <range>° (<reason>)`, e.g. "↕ 6° (Wolken + Wind)" or "↕ 20° (Wüste, klar)". The night temperature is no longer a black box.
- **"Regeln" panel** (opened from the screen): plain-language explanation —
  > *Die Nachttemperatur ergibt sich aus der Tagestemperatur minus der Tagesschwankung. Trockene, klare und windstille Gegenden (Wüste, Hochgebirge) kühlen nachts stark ab; bewölkte, feuchte oder windige Gegenden (Küste, Sümpfe) kaum. Jede Region hat ein Klima, das Grundtemperatur, Schwankung, Feuchtigkeit und Wind bestimmt.*
  Plus a compact table of the climate of the currently-shown regions and the cloud/wind effects.

---

## Data model changes

### `WeatherDay` (SwiftData `@Model`)

- **Add** `regionRaw: String` — the region for *this day* (was per-adventure).
- **Add** `manualOverrides: Set<Field>` (or per-field bool flags) — which of {clouds, wind, dayTemp, nightTemp, rain} the GM hand-edited. Overridden fields are preserved when other fields are re-rolled.
- Keep `isTimeJump` (gap marker), `generatedAt`, the value fields, `adventure`.

### `Adventure` (SwiftData `@Model`)

- **Remove** `desert`, `windy` (folded into archetype).
- **Replace** `regionRaw` semantics: keep a `defaultRegionRaw` used only to seed the Add-stretch sheet for an empty timeline; the "current region" otherwise derives from the latest `WeatherDay`.
- Keep `currentDate` as the timeline cursor (= day after the latest entry, or a user-set jump target).

### Migration

Lightweight SwiftData migration:
- Map each old `WeatherRegion` case → nearest new region (e.g. `mittelreich → zentralesMittelreich`, `khom → khom`, `thorwal → thorwal`). Table in the migration.
- Stamp every existing `WeatherDay.regionRaw` with the adventure's old region.
- Drop `desert`/`windy` (their effect now comes from the archetype).
- No recompute of historical temperatures (past days keep their stored values).

### `AventurianDate`

- Add an **ordinal/serialization** helper (`func ordinal() -> Int` over day/month/year, 365-day year with 5 Namenlose Tage) to support: ordering days, computing a stretch of N consecutive dates from a start, and **gap detection** (a new stretch whose start > lastDay+1 marks its first day `isTimeJump`).

---

## UI changes (`AdventureDetailView` + sheets)

### Control area (fixes buttons)

Replace `controlsBar`'s four mismatched buttons with:
- One **full-width primary** button `＋ Wetter hinzufügen` → opens `AddStretchSheet`.
- A row of **two equal-width ghost buttons** `ⓘ Regeln` (→ `WeatherRulesSheet`) and `⤴ Export` (the `ShareLink`, restyled to match).
- Single shared button style (one `weatherButton` helper); equal height, `lineLimit(1)`/`minimumScaleFactor`, no wrapping at accessibility sizes. `ShareLink` uses the same style.

### `AddStretchSheet` (new — replaces NextDay/BulkGenerate/DateJump)

Fields:
- **Start date** — defaults to day after the latest entry; editable (a past/future jump). If start > lastDay+1, the first generated day is marked a gap.
- **Region** — grouped picker (macro-region → region), defaults to the latest day's region. Changing it = travel.
- **Number of days** — stepper (1…N).
Generates a continuous stretch via `generateBatch`, seeding continuity from the previous contiguous day (no continuity across a gap), inserts `WeatherDay`s with `regionRaw` set, advances `currentDate`.

### `DayEditSheet` (new — tap a day)

- Change the day's **region** → re-roll that day from the new archetype.
- **Re-roll** button (new dice for non-overridden fields).
- **Manual override** controls for clouds / wind / day temp / night temp / rain; edited fields get the `✎ bearbeitet` badge and are preserved on re-roll.

### `WeatherDayRow`

- Show the day's **region** (small, since it now varies per day).
- Show the **diurnal range + reason** line.
- Show badges: `↦ Sprung` (gap), `✎ bearbeitet` (manual override).

### `WeatherRulesSheet` (new)

The player-facing explanation described above (text + climate/effect table).

### Settings group

- Remove the `desert`/`windy` toggles and the per-adventure region picker. Optionally keep a "Standardregion" (default region for the first stretch of an empty timeline).

---

## Testing

- **`WeatherGeneratorTests`** — update: night temp ≥ day − maxRange and ≤ day − 2 (floor); summer clear nights are *not* freezing for temperate (regression for the bug); desert nights swing more than tropical; humidity/windiness behavior; archetype table lookups.
- **`WeatherEnumsTests`** — every `WeatherRegion` maps to an archetype; every archetype returns sane temps/ranges for all seasons.
- **New `ClimateArchetypeTests`** — range/temperature monotonicity and bounds.
- **Snapshot tests** — `WeatherDayRow` (now shows region + range + badges) and `AdventureDetailView` (new control area, AddStretch/DayEdit/Rules sheets). Re-record baselines after layout settles (per repo: delete old refs first, single simulator only — see CLAUDE.md notes).
- **Migration test** — old adventure with region/desert/windy + weatherDays loads, days carry the mapped region, no crash.

## Localization

New `L(...)` keys: ~22 region names, ~12 archetype names, macro-region group names, the rules-panel text, `weather.add`, `weather.rules`, `weather.range`, `weather.gap`, `weather.edited`, AddStretch/DayEdit/Rules sheet labels. (App is German-first.)

## Out of scope

- No per-hero independent weather (party shares one timeline).
- No automatic gap-fill on jumps (explicitly skipped + marked).
- No recompute of historical days on model change.
- No new artwork; reuse SF Symbols and existing DSA styling.

## Risks / notes

- **Tuning:** all numbers centralized in `ClimateArchetype`; expect a tuning pass after seeing real output.
- **Snapshot churn:** layout + row changes will require re-recording many baselines (single simulator, delete-first).
- **Migration correctness:** the old→new region map must cover all 13 old cases.
