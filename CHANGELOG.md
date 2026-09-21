# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `tests/rules/test_calibration.py` + `tests/rules/calibration/` — the calibration gate. A live run of the pipeline over the ten golden ids is recorded once and graded here on every `pytest`, so the gate is reproducible without spending twenty model calls. Two tiers, fixed before the run: **Tier 1** compares every mechanical effect row on the fields that say what the rule does (`type`, `target`, `value`, `tier`, `when`, `side`, `recipient`, `parameter`/`set`/`shiftSteps`, `grants`/`forbids`, `add`, `action`, `scope`), unordered and with `note` excluded; **Tier 2** — reminder row versus `UNENCODED:` note, note wording, row order — is reported and never graded, because Task 6 established that byte equality with the golden files is the signature of contamination rather than success. **The gate does not pass: Tier 1 is 7 of 10.** The recorded proposals are linted here too, since `make rules-lint` globs `specs/rules/` only
- **The calibration gate does not certify a wave yet, and says so with a range.** 7 of 10 is the best of four runs of the same ten rules; pooled it is 23 of 40 (~0.58, 95% interval roughly [0.40, 0.89]). At that spread the gate cannot attribute a one-or-two-rule fix, cannot distinguish 6 from 8, and cannot certify what it exists to certify — measuring per-rule stability by repeating the same configuration is a blocker in its own right. The sharpest instance: the simplest rule in the corpus, a single `legality` row, dropped its `when: [mounted: true]` gate in 2 of 5 passes on identical input, which unlocks mounted-combat actions for a hero on foot — ADR-0008's named failure, invisible to the linter, and invisible to the two-agent cross-check when both agents drop it
- **The calibration gate's finding: the pipeline reads the wrong source.** The agents are handed `rules_i18n.description` from `rules.db`, which is the Optolith seed, while the golden ten were authored from the Regelwiki that ADR-0007 makes normative — and on the rules where the two disagree the pipeline is confidently wrong. One golden rule's seed text states a damage bonus where the wiki states a defence bonus; another's is missing the Erschwernis clause and both cap clauses the wiki page carries. Re-running the same driver, the same workspace and the same model against the wiki text reproduces both golden encodings, one of them exactly. Both agent briefs told the agents *"the text you are given is the wiki's"*, which was never true. Until a rule's text comes from its `source.url`, a 222-rule wave will encode stale rules cleanly, and the two-agent cross-check cannot see it: both readers share the bad input. **ADR-0007 already decided this** — its Decision demotes Optolith to a seed "authoritative for neither text nor mechanics" after bootstrap and specifies reconciliation as fetch-and-normalise, then propose; the driver substituted the seed for the first step's output. It is necessary and **not demonstrated sufficient**: a ten-rule pass on wiki text scored 6/10, below the seed run
- The rule's tier count (`rules.levels`) now reaches both agents as a `tiers: N` line in the input block, and both briefs state that it is authoritative for a ladder's extent and that each tier's rows carry that tier's *running total*, not its increment. The rule text usually states only a rate ("per Stufe"), leaving the ladder's extent to the wiki page's title and cost line, neither of which survives into `rules.db` — so the first calibration run encoded Stufe I alone for both laddered rules in the golden ten, correctly saying in its rationale that the text did not state how far the ladder ran. The driver had the number the whole time and did not pass it
- Both briefs gained two more encoding shapes that calibration caught: a clause suppressing or replacing a **named DSA constant** is a `parameterOverride` even when the constant belongs to the opponent's equipment (hard rule 5 is about outcomes and states, not numbers), and a `dice` row that only **redirects** damage carries no `add` at all rather than `add: 0`. Each fix moved exactly one rule from mismatch to match, measured live
- `make rules-propose` (`scripts/rules_sync/propose.py`) plus `.claude/agents/rule-author.md` and `.claude/agents/rule-verifier.md` — the authoring half of the rules pipeline. Two agents encode a rule independently from its text and the driver diffs them: the author takes a batch of up to 12 rules, the verifier takes **one rule's text only and never the author's YAML**, and where the two readings disagree the review file says so in its first section and the written YAML carries a `DISAGREEMENT:` prefix on its root note — greppable the way `UNENCODED:` is, and never silently resolved. The driver owns everything deterministic (batching, selectors `--ids`/`--group`/`--subgroup`, provenance, linting, diffing, the summary table) and delegates exactly one operation to a pluggable `Runner`; the shipped `SubprocessRunner` drives headless `claude -p`, and the injectable `FakeRunner` means the test suite makes zero model calls and zero network calls. Nothing is committed by the script
- Provenance stays with the deterministic half: an agent never emits a `source:` block (a guessed URL or hash is worse than none, and one that appears anyway is discarded and reported). A proposal carries its existing file's provenance forward, or the `unverified` placeholder `scripts/rules_sync/check.py` already reports; `--verify-source` re-fetches through `check.Fetcher` and re-hashes with `normalise.hash_html`, and a failed fetch or a `ContentContainerError` carries the old values forward rather than fabricating new ones
- Agents run against a **sanitised workspace** holding the schema, the vocabulary registry, the ADRs and the rest of the corpus, but not the authored file for any rule in the run — and with every remaining *mention* of those rules — **by German ability name as well as by id** — redacted to `a withheld rule`, any parenthetical that named one dropped outright. Found end-to-end rather than in theory, twice: given the repo as their working directory both agents read `specs/rules/SA_65.yaml` and reproduced the hand-authored file down to the wording of every note; and withholding the files alone still left four of the golden ten glossed by id in `vocabulary.yaml`, a fifth named in `schema.json` and a sixth's mechanics restated in ADR-0008 from a paragraph that is now stale. Redacting the id alone left the worse half standing: the same sentences named the ability in German while stating its exact encoding — which field a `dice` row uses, which rule another one excludes — and a token-shaped grep could not see it. To a model that has read the rules a German name identifies it as precisely as `SA_59` does. Both agents have `Grep`, so a hint either can find pushes them toward agreeing with each other rather than toward being right. What a workspace cannot reach — the agent briefs, which arrive as a system prompt — is covered by `ids_named_in_agent_briefs`, and the briefs' worked example is now a synthetic rule whose id belongs to no corpus
- The rule text is fenced and declared untrusted data in both prompts and both briefs. The two-agent design detects *independent* error; the agents share an input, so an instruction injected into a rule's text steers both identically and the run would report `agree / ok / written`. Paired with `parse_agent_output` keeping the first envelope per id, so an injected marker cannot re-open one
- `effects` now requires at least one row (`schema.json`), and the driver refuses an empty encoding before the verdict is computed: two agents that both return nothing used to agree, lint clean and be written, so a systematic authoring failure across 222 rules would have reported as a clean run
- `make rules-lint` rejects an unresolved `DISAGREEMENT:` marker, so a proposal cannot be committed until someone has decided which of the two readings is right; the driver is the one caller that may write it. The marker is also short now, with the summary in the review file — the first version overflowed the schema's 200-character note cap and silently erased the author's `UNENCODED:` prefix, breaking the invariant that `grep -r UNENCODED specs/rules` enumerates the whole encoding debt
- `--force` is required to overwrite a golden-corpus rule in `specs/rules/`, which a bare `make rules-propose RULES=SA_65` otherwise did to the very file the pipeline is calibrated against
- `.proposals/` is git-ignored and every review file opens saying so: the rationales quote the rule's clauses, which is what makes them reviewable and what keeps them out of git (Data Policy). The written YAML gets a second guard beyond the linter — any five consecutive words of the rule text reappearing in an encoding aborts that rule unwritten, which covers the free-form string fields `AGENTS.md` names as the linter's known blind spot
- `specs/rules/SA_62.yaml` (Sturmangriff) — the ability whose absence produced ADR-0008, now authored: `runUp ≥ 4` and `GS ≥ 4` preconditions, `dice: 2 + ceil(self.gs / 2)` (ceil per ADR-0006 — the rule says *half GS*, not *per full 2*), `actionEconomy: opponentPassierschlagOnFailure`, the page's flat −2 Erschwernis, a `reminder` for the defensibility clause, and `excludes: [SA_48]` for the combination ban the rule states
- `specs/rules/vocabulary.yaml` — the open-vocabulary registry. ADR-0008 closes the effect types and the condition predicates but deliberately leaves `actionEconomy.grants`/`forbids`, `legality.action` and the `gmFlag` slug open, because they are not finite over 232 rules and an enum would make every novel ability a schema PR. Open is no longer unrecorded: every token needs a one-line English gloss here, `make rules-lint` rejects any that lacks one, and `schema.json` now constrains all four to a camelCase slug (`legality.action` also allows `+`-joined segments, since its own worked example is `basismanoever+spezialmanoever`). Together these close a real Data Policy hole — `forbids: "keine Verteidigung in dieser KR"` previously linted clean, and the `text`-key and comment scans cannot see inside a free-form string field. The registry becomes the enum once the corpus stops growing
- `tests/rules/golden/MANIFEST.yaml` + `tests/rules/test_golden.py` — the ten hand-authored, fully-provenanced rules are frozen by content hash rather than duplicated. An edit to any of them fails with the remedy named ("golden corpus drifted — re-run calibration"), and the second copy that could have drifted from `specs/rules/` — and was the one place in the repo where a `text:` key or a German comment would have passed CI, since `make rules-lint` globs `specs/rules/` only — no longer exists
- A `note` convention on authored rules, stated in `schema.json` and applied across the corpus: identify a clause by position and mechanism, never restate its content (a `reminder` effect has no field but `note`, so per-clause reminders are exactly where translation pressure lands). Clauses the grammar cannot express are prefixed `UNENCODED:`, so `grep -r UNENCODED specs/rules` enumerates the whole encoding debt in one command
- `make rules-sync-check` (`scripts/rules_sync/check.py`) — deterministic, model-free drift detection for `specs/rules/*.yaml`: normalises the rule text a `source.url` currently serves (`scripts/rules_sync/normalise.py`: BeautifulSoup extraction scoped to `<main>`, `<br>` → newline, NBSP → space, whitespace-run collapse, NFC), hashes it, and compares against the recorded `source.hash`. Reports each rule as `ok`, `drifted`, or `unverified` (the `url: .../UNVERIFIED` placeholder every migrated rule currently carries) and exits non-zero only when something drifted. Requests are cached on disk under `.cache/rules_sync/` (git-ignored) and rate-limited to one per second, reusing the `DELAY`/`HEADERS` convention from `scripts/scrape_effects/scrape_effects.py` — a warm cache makes zero network calls
- `specs/rules/schema.json` — the authored-rule schema (draft 2020-12): the contract for one YAML file per DSA rule, closing the nine ADR-0008 effect types and ten condition predicates as enums, requiring `source.hash` provenance, and forbidding a `text` key (recursively, plus a comment scan) so rule prose stays out of git (Data Policy). `modifier` carries `target`/`scope`/`side`, `dice` carries `recipient`, `actionEconomy` carries `forbids` alongside `grants`, and `recovery` is now a ninth effect type — all per ADR-0008's fix-round-1 amendment closing the contract gaps a review found against the live 79-row effect corpus. `make rules-lint` (`scripts/rules_lint/lint.py`) validates every `specs/rules/*.yaml` file against it and exits non-zero on any violation
- `make rules-db` / `make rules-db-verify` — `Hesindion/Resources/rules.db` is now a generated, untracked build artifact rebuilt from the local Optolith source data (`RULES_SOURCE`), whose checksums are pinned in `specs/rules/SOURCES.yaml` and checked before every build (`scripts/build_rules_db/check_sources.py`)
- Trefferzonen (DSA 5 Fokus-Regeln) — optional hit-zone rules, off by default and switchable per hero. Attacking: a zone picker feeds the Zonenaufschlag (Kopf −10, Torso −4, Gliedmaßen −8, halved by Gezielter Angriff/Schuss, eased by 2 against a surprised target) into the attack roll, and a read-only card states the zone's wound effect for the GM. Taking damage: the zone is tapped or rolled on 1W20, damage is compared against the Wundschwelle, and a failed Selbstbeherrschung check applies Betäubung (Kopf), Liegend (Beine) or an extra 1W3+1 SP (Torso). All ten published zone tables are implemented — humanoid, vierbeinig, sechsbeinig mit Schwanz, Fangarme, and creatures without distinct zones
- Per-rule Fokus-Regeln toggles in the hero settings screen — the optional rules are a table's house rules, so they are a per-hero setting that persists across combats, and a group can adopt individual rules rather than all or nothing
- The Optolith `raceId` is now persisted as `PersonalData.speciesId`, making species-dependent derived values recomputable in future
- `HesindionUITests` XCUITest target — the repo's first end-to-end UI tests. Four tests drive the Trefferzonen surfaces on the simulator and attach screenshots (`docs/screenshots/01-fokus-settings.png` … `04-wound-effect-panel.png`)
- `make screenshots` — runs the UI tests on the single named simulator and exports the attachments to `docs/screenshots/` via `xcresulttool export attachments` (`scripts/export_screenshots.py` renames the exports to the attachment names)
- Debug-only `-uitest-seed-hero` launch argument — seeds a throwaway store with the bundled sample hero, the Trefferzonen Fokus-Regel on and an open combat session, so UI tests start from the same state every run. Compiled out of Release builds and inert without the argument

- Zustände & Status tracking per hero — a static catalog of 8 DSA 5 Zustände (leveled I–IV) and 17 binary Status with localized effects, cause, and removal rules; managed via a "Zustände & Status" section on hero detail (swipe-to-remove rows, add picker, detail sheet with prominent removal rules) and a shared `StatesStrip` of chips in combat
- Automatic modifier integration for states: active Zustände feed penalties into the ModifierEngine with the DSA −5 Zustand-penalty cap; combat root shows a states strip, a Handlungsunfähig/Bewegungsunfähig warning banner, and per-round reminders
- Entrückung "gottgefällig" toggle in spell and liturgy casting
- Command palette (Cmd+K) entries for states — "Zustand: …" / "Status: …" set a level (0 removes), covering add/level/remove from the keyboard
- Drag-to-reveal (swipe) removal of states in hero detail, matching the app's `SwipeActionRow` edit style; the reusable `SwipeActionRow` was extracted to its own file
- Schip (fate point) reroll option on failed skill and spell checks — on a regular failure, the locked 3W20 dice become reroll-selectable (all selected by default) and a "Schip: Neuer Wurf" button spends one Schip to reroll the chosen dice
- UI snapshot testing infrastructure using swift-snapshot-testing
- Snapshot tests for 7 views (HeroList, HeroDetail, Combat, CombatRoot, Adventure, DiceRoll, WeatherDay) across 12 iPad/color/dynamic-type variants
- `make test-ui` and `make test-ui-record` Makefile targets
- TestData factory for creating fake SwiftData models in tests
- `DiceRoller` engine — pure, testable dice rolling with an injectable `RandomNumberGenerator`
- Statistical tests for dice fairness (`DiceRollerTests`): chi-square uniformity for W3/W6/W20, mean, serial-independence, and end-to-end 3d20 → SkillCheckEngine critical-rate checks
- Success-probability tests verifying sampled pass rates for realistic ability profiles match exact enumeration of all 8000 outcomes
- Per-ability **theoretical success rate** on each talent row — traffic-light dot + % computed by exact enumeration (`SkillCheckEngine.successProbability`)
- Per-ability **recorded success rate** (overall %, number of Proben, sessions, and best session), revealed under every talent row at once via the Talents section's **"Aufgezeichnete Werte"** toggle
- **Session grouping** of the action log into play sessions separated by ≥ 8h gaps (`SessionGrouper`), with per-session success-rate headers in the Log panel
- `TalentStatistics` engine for aggregating recorded checks, plus tests (`SessionGrouperTests`, `TalentStatisticsTests`, `SuccessProbabilityTests`)
- `specs/rules/*.yaml` — the 26 hand-authored rule files (89 effect rows: the 79-row legacy migration plus 10 rows added in fix round 1 — restored tier ladders for `SA_41`/`ADV_25`/`ADV_44` and a `reminder` for `COND_4`'s Stufe IV) migrated from the legacy `specs/data/rules.yaml`/`HARDCODED_EFFECTS` stores per the ten-type mapping in ADR-0007/ADR-0008, one file per rule, all passing `make rules-lint`
- An eleventh `when` predicate, `gmFlag(<slug>)` — a GM-adjudicated condition (e.g. "at a known location", "principles violated") for the eight legacy free-text conditions with no mechanical predicate, surfaced as a GM toggle rather than silently becoming unconditional
- `effects.payload` column in `rules.db` — the authored effect stored as JSON verbatim, so a schema field added later costs no DB migration
- `note` key in `specs/rules/schema.json` (rule root and effect level; ASCII-only, length-capped) — an English annotation of which clause/mechanic a non-obvious authored encoding carries, since `lint.py` bans every `#` comment and the corpus otherwise carries no trace of what an effect means
- `docs/rules-migration-reconciliation.md` — the tracked reconciliation report tying all 79 legacy `specs/data/rules.yaml` rows to their authored `specs/rules/*.yaml` effect (plus the 10 rows added in fix round 1), so the migration's evidence survives independent of `.superpowers/` (gitignored)

### Changed

- `DiceRollSheet` and `SkillCheckModal` now route all rolls through `DiceRoller` instead of calling `Int.random(in:)` inline
- Recorded talent stats moved from per-row tap-to-expand to a single section-level toggle, keeping rows uncluttered while still showing the theoretical % inline
- `scripts/build_rules_db/build_db.py`: `--effects` now takes the `specs/rules/` directory (one authored YAML file per rule) instead of a single hand-authored file; `RULES_EFFECTS` in the `Makefile` now defaults to `specs/rules`
- `specs/rules/schema.json`: `recovery`'s `attribute` is now required only when `operation: add` (a `scale`/`duration` recovery like `ADV_75` has no "stat recovered"); the `modifier.target` enum drops `duration`/`offHandPenalty`/`shieldPaBonus`/`anaesthesia`/`defense` — the exact legacy attributes the migration moved onto other effect types, so leaving them in `target` invited authoring `modifier target: shieldPaBonus` instead of the correct `parameterOverride`
- The ten golden-corpus rules (`SA_40`, `SA_41`, `SA_43`, `SA_48`, `SA_59`, `SA_62`, `SA_65`, `SA_66`, `SA_67`, `SA_661`) carry real provenance instead of the `UNVERIFIED` migration marker — a resolved Regelwiki URL, the Optolith `book`/`page`, today's `checked` date, and a `source.hash` computed with `scripts/rules_sync/normalise.py`, so `make rules-sync-check` reports them `ok` rather than `unverified`
- Encodings reviewed against the live rule text while the provenance was recorded: `SA_40`'s perception bonus moves from `scope: combat` to `scope: all` (it fires on a talent check, which no combat `CheckDomain` covers); `SA_48` gains an `aw` opponent row per Stufe (the rule penalises *defence*, which is PA or AW, and the schema has no combined target); `SA_59`'s two effects gain the `gmFlag: opponentUsesShield` precondition the rule states, plus a `reminder` for the shield-destruction outcome; `SA_65`'s `actionEconomy` changes from `forbids: attack` to `forbids: furtherActions` (the rule removes *all* remaining Aktionen, but not Reaktionen, so it is neither `attack` nor `allActions`); `SA_66` gains a `reminder` for the prone-legality clause; `SA_43` loses its `-1 BE` row and gains a `legality` effect for the mounted-command clause — that clause is the only one its page states, while the BE row had no clause on either source and no Swift implementation, so keeping it would have taught the pipeline that the dead engine outranks both sources. Every effect now carries a `note` naming the clause it encodes
- `SA_62`'s `source.page` is 250, from the wiki, not the Optolith seed's 249 — ADR-0007's "the wiki wins and the local copy is the bug" is unqualified, and on this rule the seed is demonstrably pre-erratum (it is missing both cap clauses the live page carries), so a stale page number and a stale text are the same staleness. `book` is unaffected. The other nine agree with the seed exactly

### Removed

- `specs/data/rules.yaml` and `HARDCODED_EFFECTS` (plus the scraper's fallback path) in `scripts/scrape_effects/scrape_effects.py` — `specs/rules/` is now the single authored store for rule mechanics (ADR-0007)

### Fixed

- **Combat special abilities were classified by whether someone had already hand-written an effect for them, not by the ruleset's own grouping.** `OptolithImportService.isCombatSpecialAbility` asked "does this rule already have a `scope: "combat"` effect?" — a circular check that misfiled every combat SF without authored effects (e.g. `SA_884` Plänkler-Formation, `SA_661` Golgariten-Stil) under `generalSpecialAbilities`, where no combat code looks. Classification now uses `rules.group_id IN (3, 9, 10, 11, 12)` (Kampf, Kampfstile bewaffnet/unbewaffnet, Kampf erweitert, Befehle) via the new `RulesDatabase.lookupGroupId(_:)`. See ADR-0008
- `git rm --cached Hesindion/Resources/rules.db` — the file has been listed in `.gitignore` since it was added but was already tracked, so the ignore rule never applied and the app kept shipping a stale, committed database
- **Wundschwelle, Ausweichen and Initiative rounded down instead of up.** DSA 5 rounds derived values up — the Regelwiki's own example is KO 11 → Wundschwelle 6, which the app computed as 5. Every hero with an odd KO had a Wundschwelle one point too low; odd GE cost a point of Ausweichen and odd MU+GE a point of Initiative. Ausweichen and Initiative affect defence and turn order, so this is a visible change at the table. Existing heroes are corrected automatically at next launch
- The Wundschwelle modifiers Eisern (`ADV_54`, +1) and Gläsern (`DISADV_56`, −1) were never applied — the bonus was hardcoded to 0, unlike the neighbouring Seelenkraft and Zähigkeit traits
- Trefferzonen: the Fokus-Regeln activation was stored in the combat-session block and wiped by "Kampf beenden", so a group's house rules had to be re-enabled at the start of every fight. Activation is now a persistent per-hero setting on the hero settings screen and is no longer part of the combat flow
- Trefferzonen: a hero without a Selbstbeherrschung talent row had the Wundeffekt applied automatically, with no probe offered. Selbstbeherrschung is a DSA 5 basic ability every hero has, so that case was never a rules outcome — the probe is now always offered (falling back to Fertigkeitswert 0 if the row is missing), and a wound effect is applied only on a rolled, failed probe. Not rolling now means "the GM has not adjudicated" and applies nothing, removing the asymmetry where declining to roll was better than rolling
- Trefferzonen: the Arme Wundeffekt's "Waffe ablegen" button cleared the hero's equipped weapon immediately instead of participating in the confirm transaction, so navigating away from an unconfirmed take-damage flow left the hero disarmed with no LP change and no log entry. The action is now staged and only applied on confirm, alongside the single LP write and the log entry
- `make test`/`test-ui`/`test-ui-record` no longer clone the simulator per test worker (`-parallel-testing-enabled NO`, `-maximum-concurrent-test-simulator-destinations 1`); `test-ui-record` uses the correct `SNAPSHOT_TESTING_RECORD=all` value
- **`SA_41`/`ADV_25`/`ADV_44` lost their Stufe ladder in the rules migration.** All three are leveled (`levels` 2/7/3) but were authored as one flat effect, so `RuleEffectModifiers`'s exact-tier match fired that single value at *every* owned Stufe (`SA_41` gave −2 BE at Stufe I instead of −1; `ADV_25` gave +1 LE at Stufe VII instead of +7; `ADV_44` gave +1 LE/cycle at Stufe III instead of +3). The migration had in fact kept the wrong one of the two duplicate legacy sources — `HARDCODED_EFFECTS` held `SA_41` correctly as two tiered rows before it was deleted. All three are now authored as full tier ladders
- `scripts/build_rules_db/build_db.py`: the `effects.attribute`/`.value` display columns now fall back across each effect type's own field (`state`, `parameter`, `forbids`, `grants`, `recipient`, `add`, `level`, `action`) instead of reading only `target`/`value`, so the live `RuleDetailView` no longer renders a `parameterOverride`, `actionEconomy`, `dice` or `stateGain` row as a bare, empty type token (e.g. `SA_59`, `SA_65`, `SA_67`)
- `specs/rules/SA_661.yaml`: the "mounted vs. foot fighter" AT bonus was encoded as one opaque `gmFlag`, discarding the half of the condition (`mounted`) the engine already checks mechanically elsewhere in the same file. `when` now ANDs `{mounted: true}` with a narrower `{gmFlag: opponentOnFoot}`
- `scripts/rules_lint/lint.py` printed "27 rule file(s)" while linting 26 — the file count included `SOURCES.yaml`, which is deliberately excluded from linting
- `scripts/scrape_effects/scrape_effects.py` silently dropped rules it couldn't scrape and couldn't fall back for; it now collects every missing rule id and prints them unconditionally at the end, per ADR-0007's "a missing rule must be visibly missing"
- **`scripts/rules_sync/normalise.py` hashed a page with an empty content container as the SHA-256 of the empty string.** It failed loudly when `#main`/`<main>` was *missing*, but a container that exists and is empty normalised to `""` — and five real Regelwiki pages are exactly that (`sf_kampfsonderfertigkeiten.html`, `Best_Tiere.html`, `ruestkammer.html`, `RS_Waffen.html`, `RS_Ruestung.html`, whose content is rendered client-side or sits outside `#main`), all verified live to produce the identical hash `sha256:e3b0c442…b855`. Recorded as a rule's `source.hash`, that would have compared `ok` forever while verifying nothing. An empty or whitespace-only extraction (including a container holding only stripped elements such as `<script>` or the CAPTCHA widget) now raises `ContentContainerEmpty`, a sibling of `ContentContainerNotFound` under the new `ContentContainerError` base, and `make rules-sync-check` reports it as `structure-changed` and exits non-zero, naming the URL and distinguishing "no content container" (the site's markup changed) from "empty content container" (the rule text is not in the fetched HTML at all)

### Changed

- Schmerz now flows through the new states system rather than a standalone computation, with Belastung counting toward the −5 Zustand cap
- The Beengte-Umgebung combat toggle now persists as the `eingeengt` status (its single source of truth) and survives combat exit

## [0.3.0] - 2026-03-28

### Added

- General-purpose dice roller ("Würfeln") command with configurable count and sides, tumble animation, and action log integration

## [0.2.0] - 2026-03-23

### Added

- Generic ModifierEngine for unified modifier calculation across melee, ranged, defense, magic, liturgy, and talent checks
- Magic casting flow — standalone SpellProbeModal with expandable modifications section
- Combat spell casting — "Zaubern" action with spell selection, setup, multi-round casting with round tracker, and 3d20 execution
- Magic & Karma section in hero detail showing spells, liturgies, cantrips, and blessings with swipe-to-roll
- SkillCheckModal — unified 3d20 skill check UI shared by talents and spells
- Magic-specific modifiers: maintained spells, foreign tradition, gestures/formula, Bann des Eisens, distraction, spell modifications
- Effects scraper for populating rule effects from ulisses-regelwiki.de
- DB-sourced rule effect modifiers via RuleEffectModifiers loader

### Changed

- Melee attack, defense, and ranged modifiers now use ModifierEngine instead of hardcoded logic
- TalentProbeModal refactored to delegate to generic SkillCheckModal
- CheckDomain split: meleeParry and meleeDodge replace single meleeDefense for cleaner modifier targeting
- RulesDatabase.lookupEffects() made internal for engine access
- build_db.py now accepts both dict and flat list YAML formats for effects import

### Added (prior)

- Abenteuer (Adventure) system with weather generation
- Aventurian calendar with 12 months + Namenlose Tage
- Weather generator porting DSA 4.1 WdE p.156ff tables
- 13 climate regions from Ewiges Eis to Südmeer
- Day-by-day and bulk weather generation
- Date jumping with time-jump markers in timeline
- Plain-text weather export via share sheet
- Hero ↔ Adventure linking via hero settings
- New sidebar section for adventures

- Fernkampf (ranged) execution view: W20 FK roll with animated dice, modifier breakdown, critical/fumble confirmation, Schip reroll, and distance-adjusted damage formula
- Fernkampf criticals and fumbles mirror melee: roll 1 confirms critical hit (halved defense + double damage), roll 20 confirms fumble using the dedicated FK fumble table
- Opponent defense view now shows "Keine Parade mit Waffe möglich" and defense penalty hint for ranged attacks
- `CombatAction.fernkampf` added so FK fumbles route to the correct `FumbleTableType.fernkampf` table

- Passierschlag (free strike) view: AT-4 attack with no maneuvers, no critical successes or fumbles, with animated dice rolling and damage calculation
- Passierschlag button on critical parry success in defense outcome
- Per-profession color schemes for hero detail views (19 palettes: priests by deity, warriors, mages, mundane)
- Hero settings view accessible via command palette ("Einstellungen für <Hero>")
- Color scheme picker with visual swatch previews and automatic profession-based detection
- Combat execution rolls (AT/PA/AW) now logged automatically with outcome and effective value
- Schip reroll usage logged as dedicated combat action entry

### Changed

- Combat log descriptions enriched: critical/fumble markers on attacks, TP instead of "Schaden ausgeteilt", structured schip/fumble/flucht/opponent-defense text

- Mount pre-check (Galopp + Reiten) redesigned as single-screen vertical flowchart with collapsing steps and connector arrow
- Talent probe modal: enlarged modifier buttons (44pt tap targets) for easier use
- Talent probe modal: constrained max width to 400pt on wide screens
- Sidebar title centered via toolbar principal item
- Panel toggle buttons now have filled backgrounds with white icons (no borders)
- Redesigned landscape sidebar panel buttons — bold 48×48 squares flush to screen edge with distinct amber/teal/purple colors, dark mode adaptive

### Fixed

- LP (Lebenspunkte) calculation now includes species base value (e.g., +5 for humans, +8 for dwarves) — previously only used KO × 2
- "Held importieren" button text readability (black text on gold background)
- Selected hero row visibility in sidebar (increased highlight opacity)
- Removed unnecessary trailing border from attributes column

### Added

- Action log (Protokoll) with event sourcing — all talent checks, combat damage, healing, and resting are recorded as reversible log entries
- Log panel (Protokoll) viewable in split-screen with combat grouping, swipe-to-delete with automatic state reversal
- Split-screen layout — Notes, Protokoll, and Regelwerk panels available in 50/50 split (landscape) or full-screen overlay (portrait)
- Heilung command — heal hero with source tracking and logging
- Reittier: Heilung command — heal mount with logging
- SchemaV3 migration with LogEntry model
- Adaptive content width modifier for iPad: proportional margins (~6% per side) with 700pt max-width cap, standard 16pt padding on iPhone
- Notes panel ("Notizen") sidebar toggleable via toolbar button on iPad in both hero detail and combat views
- Hero.notes property persisted via SwiftData with SchemaV2 lightweight migration
- ContentWithNotesLayout wrapper for consistent notes panel integration across views
- Adaptive attributes column fixed to left side in iPad landscape mode
- Inline probe attribute abbreviations (e.g., KL, CH, GE) in talent rows
- Personal data fields display in responsive grid layout (2-3 columns)
- Ctrl+K keyboard shortcut to open command palette
- LP (Lebenspunkte) bar for all pets in hero detail view
- Mount LP bar in combat view when mounted combat is active
- Mount damage with automatic Reiten (Kampfmanöver) check — penalty scales +1 per 5 SP; Sturz warning on failure
- "Reittier: Schaden" command in command palette for normal mode
- TalentProbeModal now accepts an initial modifier for pre-applied penalties

### Changed

- Replaced notes-only right sidebar (ContentWithNotesLayout) with flexible SplitContentLayout supporting Notes, Protokoll, and Regelwerk panels
- Panel toggle buttons now built into layout instead of toolbar
- Combat view: replaced per-element horizontal padding with adaptive content width modifier for consistent iPad margins
- Mount combat: Reiten check now uses the full talent probe modal with dice rolls instead of a simple Yes/No dialog
- Moved mount attacks from combat root view to attack selection screen
- "Ausruestung wechseln" button restyled with teal accent for better visual distinction
- Weapon and shield selection merged into single loadout step
- Renamed project from iDSACompanion to Hesindion (after Hesinde, DSA goddess of wisdom)

### Added

- Niederreiten and Sturmangriff zu Pferd as selectable attacks in the attack choice screen
- Galopp confirmation and Reiten (Kampfmanöver) check flow before mounted charge attacks
- Mount attacks (regular, Niederreiten, Sturmangriff zu Pferd) grouped in attack choice view alongside hero attacks
- Mächtiger Schlag reminder for mount attacks: when the mount has "Mächtiger Schlag" in its special skills, an info banner shows during attack execution explaining the Kraftakt check rule, including the calculated penalty from the mount's KK
- SwiftData VersionedSchema and SchemaMigrationPlan for safe schema migrations
- Modifier breakdown for defense actions: Parieren and Ausweichen now compute and display labeled modifier lines (Belastung, Schmerz, Golgariten-Stil PA bonus, Plänkler-Formation AW bonus, mounted dodge penalty, dual-attack penalty) with an effective total, matching the attack announcement breakdown
- Vorstoß defense lock: Parieren and Ausweichen buttons disabled (grey) when Vorstoß active this round, with warning note below
- Schmerz indicator in combat root view: badge showing pain level and penalty when effectiveSchmerzLevel > 0
- Mount attacks section in combat root: when mounted, show pet attack list with AT values; each attack skips the announcement step
- Two-handed weapon selection disabled when mounted (greyed out with "Beritten" note in loadout view)
- Auto-select mount INI base on initiative screen when mounted mode is active
- Modifier breakdown in combat execution view: labeled rows show base AT/PA/AW, each situational modifier (Belastung, Schmerz, Vorteilhafte Position, maneuver, dual-wield, off-hand) and manual zusätzlich adjustment, with a dark "Effektiv" total bar; falls back to simple value box for defense paths without a full breakdown
- Announcement step between weapon selection and execution: maneuver selection (Normal, Finte, Wuchtschlag, Vorstoß, Schildspalter, Sturmangriff) with Vorteilhafte Position toggle and full AT/damage modifier pre-calculation
- Combat setup step between armor selection and initiative: Plänkler-Formation toggle (AT or AW bonus) and mounted toggle for eligible heroes
- Vorstoß and active maneuver state reset on round advance
- Schmerz penalty warning and modifier applied to talent probe results in TalentProbeModal
- Aufmerksamkeit (SA_40) contextual hint shown in talent probe for Sinnenschärfe (TAL_8)
- Schmerz (pain) tracking: raw level from LP thresholds, Zäher Hund (ADV_49) reduction, penalty computation
- Combat ability detection helpers: Aufmerksamkeit, Golgariten-Stil, Berittener Kampf, Finte, Wuchtschlag, Vorstoß, Schildspalter, Plänkler-Formation
- Mount detection and Sturmangriff damage bonus computation
- Combat setup screen flag (needsCombatSetup) for Plänkler-Formation and mounted heroes
- Combined equipment loadout view (weapons + shields in one screen with checkboxes)
- Dual-wielding support for heroes with Beidhaendig (ADV_5) advantage
- Pre-attack choice: "Eine Waffe" vs "Beide Waffen" for dual-wield heroes
- Two-handed grip option (+1 TP, -1 PA) for eligible one-handed weapons
- Vorteilhafte Position per-roll toggle (+2 AT/PA/AW) on combat execution screen
- Off-hand penalty display and calculation for dual-wield combat
- Dual-attack penalty tracking per combat round (resets on round advance)
- Dual-attack second strike flow with fumble handling (Patzer cancels second attack)
- Combat loadout system: select main weapon + shield at combat start, persists across sessions
- Passive shield PA bonus on main weapon parade (single modifier per DSA 5 rules)
- Active shield parry with doubled PA bonus
- Shield-specific combat notes (e.g., Großschild "+1 PA vs. Fernkampf")
- Loadout-aware Angriff/Parieren: skip weapon list when no shield, simplified choice when shield equipped
- "Ausrüstung wechseln" button to change loadout mid-combat
- Armor equip/unequip system with `isEquipped` toggle (swipe-left in hero detail, toggle in combat)
- Belastung (encumbrance) system: effective BE, Belastungsgewöhnung support, penalties on AT/PA/AW/INI/GS
- Belastung penalty display as separate modifiers on combat stats (e.g., "AT 12 (-1)")
- Combat flow: armor selection → initiative roll → combat root (replaces direct-to-root)
- "Schaden nehmen" combat action: TP input → RS calculation → LP reduction with confirm
- Armor management during combat via shield button and modal sheet
- INI/GS direct modifiers on armor model (parsed from Optolith `iniMod`/`movMod`)
- 17 new DE/EN localization strings for damage and armor system
- Adaptive border colors and combat technique AT/PA design docs
- Ranged weapons UI with combat technique ID-to-name resolution
- RangedWeapon model and ranged weapons import
- Attribute-by-ID resolver to Attributes model
- Combat technique detail lookup in RulesDatabase
- Full set of 59 standard talents included on import (missing ones default)
- Hero avatar display in sidebar list rows
- Direct Optolith export import (replacing custom hero JSON import)
- Rule lookup sheet, app icon variants, and UI polish
- Rules system with spells, liturgies, and rulebook UI
- Regenerieren command to restore Lebensenergie via 1W6 roll
- Combat section labels, step transitions, and expanded combat spec

### Fixed

- PA rounding: use ceil(KtW/2) instead of floor per DSA 5 rules
- Initiative re-roll sheet now includes Belastung penalty in base INI
- Weapon AT/PA calculations to use DSA 5 formulas
- AT/PA calculation and listing of all combat techniques
- Numeric select-option IDs resolved to names during hero import
- Button heights in combat root view
- LP bar display at zero value

### Changed

- Parieren/Ausweichen moved to own rows
- LP bar pattern reused in hero view Lebensenergie modal
- INI row height reduced by halving vertical padding
- Added Makefile, fixed UIFileSharingEnabled, and simplified command palette
