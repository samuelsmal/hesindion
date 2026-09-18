# AGENTS.md

Instructions for AI coding agents working on this repository.

## Project Overview

iOS companion app for DSA (Das Schwarze Auge / The Dark Eye) tabletop RPG sessions. Features include dice rolling, ability checks, and inventory tracking. Built with SwiftUI and SwiftData.

**Rules reference:** All DSA 5 rules can be looked up at https://dsa.ulisses-regelwiki.de/ — use this for verifying game mechanics (combat formulas, AT/PA, special abilities, etc.).

## Build & Run

This is an Xcode project (no SPM package, no CocoaPods). Open `Hesindion.xcodeproj` in Xcode.

Use `Makefile` targets for all simulator and device operations. If a needed target is missing, add it to the Makefile following the existing patterns rather than running raw commands.

```bash
make run          # Build, install, and launch on iPhone simulator
make run-ipad     # Build, install, and launch on iPad simulator
make deploy       # Build and deploy to physical device (Karl)
make clean        # Clean build artifacts
make rules-db     # Rebuild Hesindion/Resources/rules.db from the Optolith YAML (DSA_DATA) and the rules catalog
make test-rules-db  # The build script's own tests (Python unittest); rules-db runs them first
```

- **Deployment target:** iOS 26.0+
- **Device families:** iPhone and iPad
- **No external dependencies** — uses only Apple frameworks

### Testing

**Always run one xcodebuild-backed target at a time, and never widen the destination set.** The `NO_CLONE` flags in the Makefile pin every test run to the single named simulator; test parallelisation otherwise clones the device and boots several simulators at once.

```bash
make test          # everything in the scheme: HesindionTests + HesindionUITests
make test-ui       # HesindionTests only (unit + swift-snapshot-testing)
make screenshots   # HesindionUITests only, exporting attachments to docs/screenshots/
```

Two test targets:

- **`HesindionTests`** — unit tests plus `swift-snapshot-testing` view snapshots. Runs in-process against in-memory `ModelContainer`s built by `TestData`.
- **`HesindionUITests`** — XCUITest. Drives the real app on the simulator and attaches screenshots (`XCTAttachment`, `.keepAlways`). `make screenshots` exports them with `xcrun xcresulttool export attachments` and `scripts/export_screenshots.py` renames the exports to the attachment names.

The app launches into an empty store, so UI tests use a **debug-only seed**: `UITestSeed` (`Hesindion/UITestSeed.swift`) reacts to the `-uitest-seed-hero` launch argument by wiping a *separate* store file, importing the bundled `Hesindion/Resources/UITestHero.json` (the `docs/sample_heros` Boronmir export with the base64 avatars stripped — 3.1 MB → 8 KB, since the resource ships in Release builds too), switching the Trefferzonen Fokus-Regel on and leaving a combat session open (so `CombatView` resumes at the combat root). It is guarded twice — `#if DEBUG` and the launch argument — and never touches the store a real user's app writes to. A second argument, `-uitest-fokus <comma-separated raw FokusRule values>`, switches further Fokus-Regeln on for a test that needs them (`UITest.launch(fokusRules:)`). A third, `-uitest-shield` (`UITest.launch(shield:)`), equips the hero's shield: with a shield in the loadout a parry goes through the weapon list rather than straight to the roll, and that is the path the defence tests are about. UI tests also reuse the existing `DebugLaunch` hooks (`debug load_default path combat`) for navigation.

Elements the UI tests drive carry `.accessibilityIdentifier`s (`heroSettings.fokusRules`, `commandPalette.search`, `combat.zone.<zone>`, `combat.woundEffectPanel`, `combat.woundEffectReminder`, `combat.takeDamage.increaseTP`, `combat.opponent.onFoot` (the announcement's "fights on foot" toggle), `combat.execution.breakdown` (the execution screen's calculation box, which the UI tests scope their row assertions to), `combat.execution.*`). Prefer adding an identifier to an existing element over reshaping a view for a test.

Five known intermittent failures — none of them regressions:

- `SkillCheckModalSnapshotTests.testFailureWithNoSchips` — intermittent SIGTRAP, passes in isolation.
- `DiceRollerTests.testD20IsUniform` — unseeded chi-square, fails ~1 run in 200 by construction.
- `DiceRollerTests.testD6IsUniform` — the same unseeded chi-square on the D6; it fired once during Task 12, 16.83 against a 16.75 critical value.
- `HeroImportTests.importBoronmirFromOptolith` — fails on `combatTechniques.count == 0` roughly 1 full run in 4, passes in isolation and on rerun. The techniques come from `rules.db`, and `RulesDatabase.allCombatTechniqueIds()` returns `[]` on any `sqlite3_prepare_v2` failure, so a transient one is indistinguishable from an empty table. Worth chasing — the same silent empty would import a hero with no combat techniques.
- `CombatViewSnapshotTests.testPreparation` — the two melee weapon rows swap places between runs; `hero.meleeWeapons` is a SwiftData to-many with no guaranteed order and the reference encodes one of them. Needs a stable sort in the loadout picker, then a re-record.

## Architecture

- **SwiftUI** for all UI with **SwiftData** for persistence
- App entry point: `Hesindion/HesindionApp.swift` — sets up the `ModelContainer` and injects it via environment
- Data models use the `@Model` macro (SwiftData)
- Views use `@Query` for reactive data fetching and `@Environment(\.modelContext)` for mutations
- `NavigationSplitView` used for iPad-compatible two-pane layout

### Combat System

- `CombatView` is a full-screen orchestrator with a `CombatStep` enum driving navigation:
  `combatSetup → initiativeRoll → root → (attack/defense/fernkampf/flucht/passierschlag)`
- **`combatSetup` is the preparation screen** and every hero sees it: the armour (`CombatArmorPicker`), the loadout (`CombatLoadoutPicker`), Plänkler-Formation, mount and Beengte Umgebung. The armour used to be a screen of its own ahead of it and the weapon two steps *after* the initiative roll, so nothing before the first attack showed what the hero was about to fight with. `loadoutEquipment` is the mid-fight "Ausrüstung wechseln" screen only, reached from the root and returning to it
- **`OpponentProfile` is everything the app has been told about the other side**, held by `CombatView` so it outlives one attack. The shape of an opponent lasts the fight (reach, body plan, size, demon); their posture lasts the swing (`resetPerAttack`). The reach used to be asked for again on every single attack and the hit-zone table was the *hero's*, which is the wrong table for anything that is not another person
- **A modifier row names its source, not its category.** "Auswirkung auf den Schaden" told the reader what they could already see; the row says *Kritischer Treffer*, *Schwerer Treffer*, *Geweihte Waffe der Gegengottheit*, *Von Hand eingetragen*. A multiplier carries the name of the result that produced it (`criticalDamageSource`) rather than being identified by what it does
- **The hero deals Trefferpunkte, full stop.** TP is what the app computes and reports; the Rüstungsschutz that stops some of them and the Lebenspunkte the target is left with belong to the other side, which is not modelled (ADR-0005). "Verlorene Lebenspunkte" is only ever said on the take-damage screen, where the LP being reduced are the hero's own
- **A penalty on the opponent is not a bonus for the hero.** Liegend is −2 on *their* defence and the rules give the attacker nothing for it; a Finte the same. The Finte line is made in `OpponentProfile.defenseModifiers`; the prone opponent's −2 is the catalog's `STATE_10`, an `opponentAdd` line — `CombatAttackViews.opponentDefenseLines` joins the two, and they are printed as their own calculation, on the announcement and again on the damage screen, which is where the GM needs the figure
- **Attack flow**: attackChoice → weaponSelection → announcement (maneuvers, reach, modifiers) → execution (AT roll) → opponentDefense (Pariert/Ausgewichen/Treffer) → damage
- **Defense flow**: PA/AW roll → outcome → fumbleChoice on Patzer, Passierschlag on critical PA
- **Fernkampf flow**: fernkampfSetup (8 modifier categories) → fernkampfExecution (FK roll) → opponentDefense
- **Armor & Belastung**: `Armor.isEquipped` persists across combat sessions. `Hero` computes `totalRS`, `effectiveBE`, and `belastungPenalty` from equipped armor and Belastungsgewöhnung (SA_41). Penalties apply to AT, PA, AW, INI, GS.
- **Damage flow** ("Schaden nehmen"): user enters TP → app shows `max(0, TP - RS)` → confirm applies LP reduction
- **Initiative**: rolled at combat start with Belastung-adjusted base; re-rollable mid-combat via sheet
- **Combat session persistence**: state saved to Hero model; exit/re-enter resumes at root; "Kampf beenden" clears state
- **Schicksalspunkte**: Neuer Wurf (reroll failed AT/PA/AW/FK), W6 wiederholen (damage), Verteidigung stärken (+4), Zustand ignorieren
- **Patzertabellen**: 4 tables (Nahkampf AT, Verteidigung Waffe, Verteidigung Schild, Fernkampf) as alternative to 1W6+2 SP
- **Kritische Erfolge (Fokus-Regeln, optional)**: 3 2W6 tables (Angriff, Verteidigung Nahkampf, Verteidigung Fernkampf) replacing double damage / Passierschlag / the undiminished next defence, each with a nested 1W20 Fokusregel. `CriticalSuccessTable` + `CriticalSuccessRefinements` are the data, `CombatCriticalSuccessView` the screen. Switching a rule on *offers* its table, it does not impose it: the screen asks basic rule or table, the way `CombatFumbleChoiceView` asks 1W6+2 SP or Patzertabelle. Only the damage arithmetic is applied (`CriticalDamage` on `CombatStep.opponentDefense`); opponent conditions and "bis zum Ende der nächsten KR" buffs are stated for the GM — see **ADR-0011**.
- **Weapon reach**: opponent reach selector applies AT penalties (Kurz vs Mittel: -2, Kurz vs Lang: -4, Mittel vs Lang: -2). The hero's side of the comparison is the reach of the thing *in the hand* — `Hero.reach(ofLoadoutNamed:)`, named to the engine as `Situation.loadoutName`; `Situation.loadoutReach` resolves it and the catalog's `GRW_reichweite` reads it — not `selectedWeapon`, which is the wrong answer for an off-hand swing, a Schildattacke and above all for Raufen (kurz; the old fallback was mittel, so a bare-handed hero closed on a spear for free)
- **Beengte Umgebung**: toggleable; Kurz 0, Mittel -4 AT/PA, Lang -8 AT/PA
- **Multiple defenses**: -3 per defence *already made* this round, cumulative, reset per round. **Parries and dodges are counted apart** — the penalty is per defence type, so the round's first dodge is unmodified however often the hero has parried. The count is incremented when a defence roll is set up (`CombatExecutionView.onAppear`), not when the button is tapped, so the first defence of a round is unmodified
- **`CombatSituation`** (`Hesindion/Engine/CombatSituation.swift`) is the round's flags as one value and the single source of defence modifier lines. Both the combat root and the weapon list build from it — the weapon list, which a shield or a second weapon forces you through, used to build none at all. It is the round part of `Situation`
- **A value the player can roll *or* be told is a fork, not two controls**: they choose the route, the chosen route runs at once (a roll rolls immediately), and only its result stays on screen (`WoundEffectDamageControl`). Both routes on screen at once leaves "what wins if I roll and then type?" unanswered
- **Sonderfertigkeit ids live in `CombatAbility`, never as bare strings, and every one of them is covered by a test.** An ability can be ignored silently in three ways — a wrong id, the importer filing it out of reach, or nothing implementing it — and none of them show on screen: the ability is on the hero sheet and the roll is merely a little low. So: `CombatAbilityCoverageTests` checks every id against `rules.db` by name, the importer files an ability as combat by its Optolith group (`CombatSpecialAbilityGroup`, checked against the database by name), and `Hero.specialAbility(_:)` still searches both lists for heroes imported before that fix
- **The rules catalog says what the app does with every rule, and for `implemented` ones it *is* what the app does.** `specs/data/rules-catalog.yaml` has one entry per rule id in `rules.db` plus `GRW_*` entries for core rules and Fokusregeln without an Optolith id, each with a status — `implemented` (clauses the evaluator interprets), `byHand` (a pointer to the Swift symbol), `noRollEffect`, `todo` — and `make rules-db` validates it against `specs/data/rule-vocabulary.json` (the closed vocabulary `RuleVocabulary` exports; a test keeps the two identical), compiles it into the `catalog` table (clauses as JSON), and fails on a missing or unknown id, a name or group that differs from the database, a pointer that does not resolve, a clause outside the vocabulary, a `modifyRule` naming an entry that is not implemented, or status counts that drift from `specs/data/rules-catalog.snapshot.json` (`UPDATE_SNAPSHOT=1` rewrites it; commit it with the catalog and `rules.db`). **`RuleEvaluator`** (`Hesindion/Engine/RuleEvaluator.swift`) reads the compiled rules (`RuleCatalog.bundled`) against a **`Situation`** (`Hesindion/Engine/Situation.swift`: the hero, the domain, the round as `CombatSituation`, the other side as an `OpponentRoster` of `OpponentProfile`s with their stated `states` and GM `facts`, and what belongs to this attack or check) and returns an `Evaluation`: lines, multipliers, opponent lines, offers, questions and the not-applied list with a reason for every owned rule that did not fire. Order of application is fixed: base adds → `modifyRule` (set, multiply, add) → zero lines dropped; the −5 Zustand cap is applied once by `ModifierEngine.applyingZustandCap`. **During the migration `ModifierEngine.evaluate` is the union** of the Swift `ModifierDefinition`s still in `Hesindion/Engine/*Modifiers.swift` and the evaluator; every definition names the catalog ids it stands for (`rules:`) and `ModifierEngineUnionTests` refuses a rule implemented on both sides. Moving a rule: delete the definition, write the entry (`reviewed: null` until a person has read the clauses against the text — nothing reads `RuleLine.reviewed` yet, `modifierLine` drops it, so an unreviewed line looks like any other until step 3 renders it), rebuild with the new snapshot, keep the definition's test finding its line by `ruleId`, add a row to `RuleFixtureTests`; `RuleReachabilityTests` proves every clause can fire. The manoeuvre picker's chips (`CombatManeuver.atModifier`/`damageBonus`), the zone picker's chips (`HitZoneModifiers.penalty`) and the reach chips (`WeaponReach.atPenaltyAgainst`) are Swift mirrors of the catalog's numbers until step 3 reads them off the evaluation instead — `RuleFixtureTests` holds each to the roll (`testTheManoeuvrePickerAndTheCatalogAgreeOnWuchtschlag`, `testTheZoneChipsAndTheRollAgree`; the reach one is an assertion inside `testTheShorterWeaponPaysForReach`, not its own test). The defence button's "n. Parade/Ausweichen · −x" preview is not one of these mirrors: `CombatRootView.defenseCostSubtitle` reads the `GRW_mehrfacheVerteidigung` line off the same lines (`CombatRootView.pendingDefensePenalty`) the roll itself will use, so a style that changes the step (Vinsalt-Stil, SA_923) shows correctly on the button too. A few literal labels are plain prose, not tied to the catalog at all: "AT/PA +2" on the advantageous-position toggles, "Parieren −2" on the prone toggle, "TP ×2" on the opposing-deity toggle. A catalog line is labelled with the rule's `name`, not its id, so before deleting a Swift definition grep `HesindionUITests` for the old label's German *text* (`Strings.swift`, not the rule's name — catalog `note`s themselves are written in English) and run the affected UI test class. A rule applies to a hero exactly when its id is among the hero's traits (`Hero.ownedRuleTier`); `GRW_`, `COND_` and `STATE_` entries apply to everyone and their `when` gates them. Growing the vocabulary is a code change in `RuleVocabulary` with an interpreter case, a decoder case, a reachability case and a test. Design: `docs/plans/2026-09-14-rules-catalog-design.md`; issue #27
- **Combat-technique ids live in `CombatTechniqueID`, never as bare strings.** Three sets of them were written inline with the names in comments and all three comments were wrong: the two-handed grip was withheld from Armbrüste rather than Fechtwaffen, "needs both hands, not from the saddle" was applied to *Lanzen*, and `isSchusswaffe` matched Schleudern and Schwerter. `CombatTechniqueIDTests` checks the enum against `rules.db`
- **SF Symbols has no weapons**, so the melee glyphs are the app's own (`Hesindion/Assets.xcassets/weapon.*.imageset`, drawn flat and hard-edged), mapped from the technique by `WeaponIcon` and rendered by `WeaponIconView`. `hammer.fill` used to stand in for every weapon in the loadout
- **Rules data is looked up, never inferred.** The Trefferzonen size category belongs to the *species* (`HitZoneSizes`: Zwerge klein, Menschen and Elfen mittel), with the player's own setting on top — deriving it from the hero's height would be a plausible-looking guess at a rule that says something else
- **The opponent rolls their own dice.** Where a rule turns on the opponent's check, the app asks the player for the outcome (`WoundEffectReminderCard`) and never rolls for the other side — the opponent is not modelled (ADR-0005)
- **An open question holds the way out.** While the Wundeffekt is still asking — the opponent's check unanswered, or a failed check whose damage is unsettled — the damage screen does not offer "Neue Aktion". Two live controls that mean "answer this" and "leave without answering" read as though the question were optional, and leaving drops an announced Wundeffekt out of the reported total
- **A screen that writes something says what it wrote.** The take-damage confirm reports the life points that remain and every state that went up (`CombatDamageOutcomeBox`), by comparing against a snapshot taken before the write — Schmerz is derived from the LP total and moves without any step of the flow touching it
- **A question most attacks do not answer folds.** `CombatDisclosureSection` — shut by default, with what is set inside readable on the lid. The announcement's opponent facts were four separate things in three places (reach at the top, Vorteilhafte Position loose above it, "Ziel ist überrascht" buried in the zone picker, the demon question below it); they are all the same kind of fact and most swings answer none of them
- **One primary action, one button.** `CombatActionButton` draws "Weiter", "Bestätigen" and "Neue Aktion": same size, same box, in the content column at the end of the flow, and it carries its own clearance (`topGap`) — a raised box's shadow draws outside its bounds and reserves no layout space, so a nominal 8pt gap comes out as 3 and the action reads as the last row of the calculation above it. "Weiter" used to be pinned edge to edge below the scroll view, which reads as a tab bar rather than as the next step
- **The Wundschwelle is core, the Wundeffekt is not**: the take-damage screen states the comparison against the hero's Wundschwelle whether or not the Trefferzonen Fokus-Regel is on (`CombatWundschwelleRow`); the zone effect, its Selbstbeherrschung probe and its extra damage stay behind the rule (`CombatWoundEffectPanel`). Only one of the two prints the comparison at a time. The panel's announced modifier and the modal that actually rolls the probe are built from the same helper, `Situation.woundEffectProbe(hero:talentId:)`, so a catalog rule on that check — Verweichlicht (DISADV_57) among them — shows in both and cannot drift apart
- **Damage parts travel apart**: `CombatStep` carries the weapon's own `damageFormula` *and* `damageLines`, never a pre-folded string, so the damage screen can print every part and no screen can add the same bonus twice. `CombatBreakdownBox` renders both the AT/PA/AW and the TP calculation
- **`DamageModifiers`** (`Hesindion/Engine/DamageModifiers.swift`) is the damage domain's union point: `lines(situation:)` (the two-handed grip and Sturmangriff in Swift, plus the catalog's `damage` lines — e.g. Wuchtschlag's TP) and `multiplier(situation:)` (the catalog's one `tp` multiplier, mapped by `CriticalDamage.init?(factor:)`; `RulesCatalogTests.testEveryTPMultiplierIsKnownAndAtMostOneRuleMultipliesTP` holds the catalog to what the screen can show). The lines and the adjusted formula come from one call, so the box the player reads cannot drift from the formula the dice get. `DamageFormula` parses and rewrites the damage string; nothing else should carry a copy of that regex
- **Karmale Objekte (Fokusregel, optional)**: a consecrated weapon deals regular damage to a demon and *doubles* against a demon of its opposing deity (`GRW_karmaleObjekte`, read through `DamageModifiers.multiplier(situation:)`; what the screen says about a demon is the toggle's subtitle). Both facts are answers, not derivations — which weapon is geweiht is a per-hero setting under the rule's toggle (`Hero.consecratedWeapons`), and what is on the other end is the GM's call, asked on the announcement screen. The multiplier travels beside the critical's own as `damageMultiplier` and gets a row of its own in the calculation
- **What the app cannot know**: no Optolith export carries a weapon's Leiteigenschaft threshold (TP/KK) — there is no equipment table in `rules.db` (issue #14) — so the damage roll has a manual TP modifier for it. Nor does it carry a Weihe, which is why the consecrated-weapon list is a setting
- **Combat views split**: CombatView.swift (orchestrator), CombatSetupViews, CombatRootView, CombatAttackViews, CombatExecutionView, CombatDamageViews, CombatDefenseViews, CombatFernkampfViews

### Trefferzonen (Fokus-Regeln, optional)

- **Activation is per rule and per hero**: `FokusRule` (`Hesindion/Models/FokusRule.swift`) lists the optional Fokus-Regeln; `Hero.fokusRules: [String]` stores which the hero plays with, via `isFokusRuleActive(_:)` / `setFokusRule(_:active:)`. All off by default. These are the table's house rules, not a per-fight choice, so they live with `notes` / `colorSchemeId` — **not** in the combat-session block — and `clearCombatSession()` deliberately does not reset them. The UI is a "Fokus-Regeln" section on **`HeroSettingsView`** with one `ForEach(FokusRule.allCases)` row, so a new rule costs one enum case plus two localized strings. Five rules ship today: `trefferzonen` and the four `kritischeErfolge*` cases.
- **Rules model** — pure value types, no SwiftUI or SwiftData: `HitZone` / `HitZoneTable` (all ten published 1W20 tables; odd rolls hit left, even right) and `WoundEffectCatalog` / `WoundEffectResolver`. `FumbleTable.swift` is the pattern.
- **Offence**: the Zonenaufschlag is the catalog's `GRW_zonenaufschlag` (Kopf −10, Torso −4, Gliedmaßen −8), which `SA_160` halves in melee and `SA_161` at range, and which an überraschter opponent (`STATE_13`, a stated status on `OpponentProfile.isSurprised`, backed by `states`) eases by 2; `HitZoneModifiers.penalty` survives only as the zone picker's chip table, held to the roll by `RuleFixtureTests.testTheZoneChipsAndTheRollAgree`. After a landed hit a read-only `WoundEffectReminderCard` states the effect for the GM — nothing is applied, because opponents are not modelled.
- **Defence**: `CombatTakeDamageView` compares damage against `wundschwelle.max`; at each multiple the Selbstbeherrschung check is one step harder. Only a *failed* check applies Betäubung/Liegend via `setStateLevel`, or folds 1W3+1 into the **single** LP write on confirm; an unrolled probe means the GM has not adjudicated, so nothing is applied. The probe reuses `TalentProbeModal`. Selbstbeherrschung is a DSA 5 basic ability every hero has — a missing talent row is a data anomaly, and `Hero.selbstbeherrschung` falls back to a transient FW-0 stand-in so the probe can still be rolled.
- The offence/defence asymmetry is deliberate and explained in **ADR-0005**.

### Player States (Zustände & Status)

- **Catalog + storage**: `StateCatalog` (`Hesindion/Models/StateCatalog.swift`) is a static in-code list of 8 leveled Zustände (I–IV) and 17 binary Status with localized name/effects/cause/removal, SF Symbol, modifier mechanic, and implication chains. Per-hero state is one generic `@Model HeroStateEntry(stateID, level)` on `Hero` (cascade relationship) — see ADR-0003.
- **ModifierEngine integration**: active Zustände feed penalties into the `ModifierEngine` from `StateModifiers` (`mechanic: .penalty`) or from the catalog (`mechanic: .catalog`, Liegend so far), which applies the DSA −5 Zustand-penalty cap via `isZustand` tagging
- **Derived states**: Schmerz and Belastung are computed (not stored) and excluded from manual editing via `StateCatalog.derivedIDs`; Belastung counts toward the −5 cap
- **UI surfaces**: a "Zustände & Status" section on hero detail (chips + add picker + detail sheet with prominent removal rules), a shared `StatesStrip`, and a combat-root states strip with a Handlungsunfähig/Bewegungsunfähig warning banner and per-round reminders
- **Eingeengt**: the `eingeengt` status is the single source of truth for the Beengte-Umgebung combat penalty (the toggle reads/writes it)
- **Entrückung**: a "gottgefällig" toggle in spell/liturgy casting

## Design

The UI follows a **Neo-Brutalist** design theme.

- **No system dialogs.** A confirmation is `DSAModal` + `DSAModalButton`, never `.alert` or `.confirmationDialog`: a system dialog brings rounded corners, blurred material and tinted text onto a screen built without any of the three. The same goes for `.contextMenu`
- **An either/or is drawn as one group with a `DSAOrDivider` between the branches**, both at the same visual weight. Two controls stacked in a box read as two independent actions, and giving one the red fill turns a free choice into a recommendation the rules do not make
- **The combat root's actions are grouped by rules category** — AKTION, REAKTION, SCHICKSALSPUNKTE, EINTRAGEN — and colour then carries one meaning each: red = it is rolled, gold = it costs a Schicksalspunkt, dark = it only records something. Nothing in the app is teal
- **One calculation grammar: `CombatBreakdownBox`.** Parts on top (value left, where it comes from right), the result in the dark bar inside the same border. A bare number in a dark bar is that grammar's *total*, so anything shown that way must say what it is the total of — a dice sum presented like a result reads as the damage
- **A modal is a sibling of the layout, not a child of a panel.** It is drawn in the root `ZStack` next to `SplitContentLayout` (see `HeroDetailView`, and `SplitContentLayout` itself for the log's delete), because a modal placed inside a side panel is bounded by it — in landscape that is a third of the screen

## Swift Configuration

- Main actor isolation is enabled by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is enabled

## Git Workflow

- **Never commit directly to `main`** — all changes must be on a feature branch and merged via pull request
- Create a descriptive branch name before starting work (e.g., `fix/dark-mode-contrast`, `feat/dice-roller`)

## Code Creation Guidance

- **DSA rounding**: where a calculation yields a fraction and the rules do not clearly say otherwise, round **up** (`Int(ceil(...))`). Two exceptions: *"je volle N Punkte"* wordings are floor by construction, and for penalties "up" is ambiguous (numerically gentler vs. harsher in magnitude) — read the rule. Derived-value formulas live in `Hesindion/Engine/DerivedValueFormulas.swift` so the import and repair paths cannot drift. See **ADR-0006**.
- Create minimal and small pieces of code, favour composing
- Try to find the sweet spot between small and large files, do some housekeeping from time to time

## Documentation Requirements

When making changes, keep the following up to date:

### CHANGELOG

Maintain `CHANGELOG.md` in the project root following [Keep a Changelog v1.0.0](https://keepachangelog.com/en/1.0.0/). Group changes under the `[Unreleased]` section using these categories:

- **Added** — new features
- **Changed** — changes to existing functionality
- **Deprecated** — soon-to-be removed features
- **Removed** — removed features
- **Fixed** — bug fixes
- **Security** — vulnerability fixes

When a release is cut, move `[Unreleased]` items into a versioned section with the date.

The root `CHANGELOG.md` is the only copy. The in-app Changelog screen reads it out
of the app bundle, where the target's *Bundle CHANGELOG.md* script phase puts it at
build time. Do not add a copy under `Hesindion/Resources/` — that directory is a
file-system synchronized group, so a file dropped there is bundled silently, and the
copy that used to live there fell eleven commits behind before anyone noticed.

### Architecture Decision Records (ADRs)

Record significant architecture decisions in `docs/adr/` using the format defined in `docs/adr/0000-template.md`. Create a new ADR when:

- Introducing a new framework, library, or major dependency
- Changing the data model or persistence strategy
- Altering navigation patterns or app structure
- Making a decision that future contributors would question

Number ADRs sequentially (e.g., `0001-use-swiftdata.md`). Existing decisions can be superseded but never deleted.

### Project Documentation

Keep `docs/` current with the state of the project:

- Update or create documentation when adding major features or changing architecture
- Plans live in `docs/plans/`, ADRs in `docs/adr/`
- Sample data lives in `docs/sample_heros/`

## Data Policy

- **The rules data the app ships is committed, deliberately.** `Hesindion/Resources/rules.db` and `specs/data/rules-catalog.yaml` are tracked: the tests read the database, the catalog is the coverage record, and a rebuild has to be reviewable as a diff. What stays out of the repo is the *source* — the Optolith YAML (`DSA_DATA`, a sibling checkout) — because it is someone else's repository, not because its content is secret. When the authoring pass (design §5) adds rule text to catalog entries, that text is committed too
