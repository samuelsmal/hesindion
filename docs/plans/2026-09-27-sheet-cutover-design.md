# Domain 1 cut-over: the sheet's derived values — design

**Status:** design, approved in conversation 2026-09-27; awaiting review of this document.
**Parent:** [`2026-09-24-rules-engine-design.md`](2026-09-24-rules-engine-design.md) §9, step 1
(ADR-0015). The rules in scope are the sweep [`specs/rules/sweeps/sheet.yaml`](../../specs/rules/sweeps/sheet.yaml).
**Replaces:** the stored derived values and the Swift formulas for LE, Wundschwelle, INI, AW, GS
and AT/PA; the catalog entries `ADV_25`, `ADV_54`, `SA_51`, `DISADV_28`.

## 1. Goal

Every base value the app shows or rolls against comes from `Packages/RulesEngine`, and a tap on
it shows where it comes from: each line with its rule and clause, the facts it used and who
stated them, the *Auslegung* marks (rulings) and the not-applied list.

The base values are: LE max, Wundschwelle, INI Basiswert, AW, GS, AT/PA per combat technique,
AT/PA per weapon and per shield.

Out of scope: the situational lines of a roll (manoeuvres, reach, Zustände, …). They stay in
Swift (`ModifierEngine`) until their own domains switch.

## 2. Structure

```
Hero (SwiftData) ─HeroSheetMapping─▶ HeroSheet ─Situation(sheet:)─▶ Situation
                                                                        │
              views ◀── SheetValues (cache, keyed by HeroSheet) ◀── Engine.evaluate
```

1. **`HeroSheet`** — new, in the package (`Packages/RulesEngine/Sources/RulesEngine/HeroSheet.swift`).
   A plain `Codable, Hashable` struct: `owned` (rule id → level), `attributes` (MU…KK),
   `techniques` (`CT_n` → KtW), `speciesLE`, `purchasedLE`, `speciesGS`, and `loadout` (weapon,
   shield and armour template ids; the armour's Belastung and extra penalty; for an item without
   a template, its own AT/PA modifiers as facts). `Situation(sheet:)` turns it into the same
   facts `scripts/rulec/hero.py` writes (`attr.MU`, `ktw.CT_5`, `hero.purchased.le`,
   `species.le`, the `loadout.*` facts), all owned by `sheet`.
2. **`HeroSheetMapping`** — new, in the app. `Hero` → `HeroSheet`. The only code that knows both
   models. It reads unfolded inputs only (attributes, KtW, template ids), never a stored AT/PA.
   `HeroTrait.tier ?? 1` is the level. Option ids are not needed by any rule of this domain; the
   raw `sid` is not stored today (`HeroTrait.sid` is a display name) and becomes a later domain's
   problem.
3. **`RulesEngineStore`** — new, in the app. Loads the bundled `rules.json` into a `RuleBook`
   once and holds one `Engine`. A vocabulary mismatch shows an error row on the sheet; a test
   catches it before a release.
4. **`SheetValues`** — new, in the app. All base values of one hero, computed in one pass and
   held until the `HeroSheet` changes (it is `Hashable`, so an unchanged sheet does not run the
   engine again). For each value it holds the full `Breakdown` and `withoutBelastung` (the result
   without the `COND_1` lines; §4).
5. **Build.** `make rules-json` also copies `build/rules/rules.json` to
   `Hesindion/Resources/rules.json` (gitignored). A `require-rules-json` guard joins
   `require-rules-db` on every target that ships the app; the test targets depend on `rules-json`.
   The Xcode project adds `Packages/RulesEngine` as a local package. The app's deployment target
   (iOS 26.0) matches the package's.

## 3. Updates

`Hero` is a SwiftData model, so a change redraws the views that read it. They build a new
`HeroSheet` (cheap: copying fields); `SheetValues` runs the engine again only when it differs.
A new attribute, trait, Stufe, weapon, shield or armour therefore updates every screen that
reads a base value.

**No session state in `HeroSheet` until domain 4.** No Zustände, no current LE. The engine
derives Schmerz from the current LE (`schmerz` situations S1–S4); while `StateModifiers` still
adds Schmerz at the roll, putting the current LE into `HeroSheet` would count it twice. When
domain 4 switches, `HeroSheet` gains the Zustände and the current LE, `StateModifiers` goes, and
a loss of LP changes the cache key like any other input.

## 4. What switches, what is deleted

**Every reader of a base value switches in this change**: the sheet (`HeroDetailView`), the
loadout picker, the combat screens (INI, AW, AT/PA bases). About 16 files. The "(−BE)" suffixes
on the sheet go; the Belastung line in the breakdown replaces them.

**Belastung stays in Swift for the rolls until domain 2.** `COND_1` and `SA_41` also feed
combat, spell and liturgy rolls through `SharedModifiers.encumbrance`. So:

- the sheet shows the engine's full breakdown, Belastung included;
- the roll screens read `SheetValues.withoutBelastung` as their base, and Swift adds the
  Belastung line at the roll, as today;
- a guard test proves the engine's `COND_1` lines and `SharedModifiers.encumbrance` agree for
  the sample heroes.

**Deleted in the same change:**

- stored fields: `DerivedValues.ausweichen`, `.initiative`, `.wundschwelle`;
  `LifeEnergyValue.base`, `.bonus`, `.max`; `CombatTechnique.at`, `.pa`; `MeleeWeapon.at`,
  `.pa`; `Shield.at`, `.pa` — a SwiftData lightweight migration. Kept: `lebensenergie.current`
  and `.purchased` (session state and an input), the item modifiers (an input for items without
  a template), `geschwindigkeit`'s species value (an input);
- `DerivedValueFormulas.wundschwelle`, `.ausweichen`, `.initiative`; the matching part of
  `DerivedValueRepair`; the import's computation of these values. `DerivedValueFormulas.geschwindigkeit`
  stays: it supplies the species GS;
- catalog entries `ADV_25`, `ADV_54`, `SA_51`, `DISADV_28`; the snapshot is rebuilt. `COND_1`
  and `SA_41` stay (above).

**Intended differences**, named in the CHANGELOG: Kampfreflexe (`SA_51`) now raises INI;
Niedrige Lebenskraft (`DISADV_28`) now lowers LE; GS now carries the Großschild's −1
(`ITEMTPL_29`) and the armour's extra penalty; the talent checks gain Belastung (§6).

**The log (§8 of the parent).** The sheet makes no rolls and writes no log entries. The talent
check's Belastung line (§6) is a line of a Swift roll until domain 5 and is logged as such.

## 5. The breakdown screen

A tap on a value opens a half-height sheet:

- the result, then one row per line: value, rule name, clause id (`Kampfwerte · KW1`); a line
  with `via` names the rule that changed it;
- under each line, the facts it read with their owner (`MU 14 · Heldenbogen`);
- an *Auslegung* mark on a line resting on a ruling: the ruling id, and a tap shows its answer;
- a folded "Nicht angewandt" list with each reason.

The same view serves the talent check (§6) and, later, the combat screens.

## 6. Before a check: the reminder ("Vor der Probe")

**Principle, for every domain:** the app does not ask the player to keep every state current
during play. Before a check or a roll, it reminds the player of what the current loadout and
state do to that check and offers the choices there.

First use, in this change: the talent check. `COND_1.B3` hinders a talent by its flag in
`checks.yaml` (yes / no / maybe); today the app applies no Belastung to talent checks at all, so
the engine's line cannot count twice. When the loadout changes the check, a row above the roll
says so (`Belastung II: −2 · Plattenrüstung, Großschild`) and offers:

1. **"Für diese Probe abgelegt"** per piece: the engine gets a loadout without it, as a fact
   stated by the player; the breakdown shows `Großschild abgelegt · Spieler`. Rule-true: a
   smaller load, a smaller Belastung.
2. **"Belastung nicht anwenden"**: the line stays in the breakdown, struck through, marked
   `vom Spieler abgeschaltet`. An app decision, not a rule: the rule files do not change.
3. **"Belastung zählt"**, for the "maybe" talents only (ruling `belastung-talents-maybe`).

A choice holds for this check only; the stored loadout does not change. The row links to the
loadout picker for anything lasting. The `COND_1` line joins the Swift check as a Zustand line,
so `ModifierEngine`'s −5 cap counts it. The rest of the talent check stays Swift until domain 5.

## 7. Tests

**Package (`make test-rules-engine`):**

- `Situation(sheet:)` equals `hero.py`'s output for every hero in `specs/heroes`
  (Boronmir, Robak, the two synthetic heroes); `rulec` writes that output as a fixture, so the two mappings cannot drift;
- the sheet situations (`kampfwerte`, the LE part of `lebensenergie`) give the harness's results
  through `HeroSheet`.

**App (`make test`):**

- `HeroSheetMapping` for the UI-test hero and the sample heroes;
- engine values equal the old stored values for each sample hero, except the intended
  differences (§4), each named in the test;
- the Belastung guard (§4);
- the talent check: a hindered talent gets the `COND_1` line, one that is not hindered does
  not, the "maybe" toggle controls it, "abgelegt" and the off switch change the result, the next
  check starts clean, the −5 cap counts the line;
- the bundled `rules.json` loads with the app's `Vocabulary.version`.

**UI (`make test-ui`):** a tap on LE opens the breakdown with its lines, a ruling mark and the
"Nicht angewandt" list; the talent check shows the reminder row. New screenshots take the next
free numbers in `docs/screenshots/`.

## 8. Done

1. Every decided situation of the sheet domain passes.
2. The owner has reviewed `DISADV_28` (the one rule in the sweep still open).
3. Each base value shows its lines with origin, the *Auslegung* marks and the not-applied list.
4. The deletions of §4 are in the change; `COND_1` and `SA_41` stay, with the guard test.
5. `make test`, `make test-ui`, `make test-rules-engine` pass.
6. AGENTS.md's rules paragraph says domain 1 has switched; the CHANGELOG names the intended
   differences.

Not blocking: TZ.9–TZ.11 (a hit zone from a stated die — damage, domain 3) and 15.7 (a gain
withdrawn when its `when` stops holding — Zustände, domain 4).
