# Rules catalog — where things stand and what comes next

**Written:** 2026-09-14, at the end of the session that delivered steps 0 and 1.
**For:** the next session, starting with an empty context.

## Read these first

1. `docs/plans/2026-09-14-rules-catalog-design.md` — the evidence for issue #27 and the approved design. Sections §3 (runtime contract), §4 (catalog schema and vocabulary), §6 (fixtures) and §7 (landing steps) are what step 2 implements.
2. `docs/plans/2026-09-14-rules-catalog-registry-plan.md` — the plan for steps 0 and 1, all eight tasks done (`…plan.md.tasks.json` says so). Read it for the shape of a task in this repo, not for work to do.
3. `AGENTS.md` — the "Combat System" bullet on the rules catalog and the Build & Run block (`make rules-db`, `make test-rules-db`).

## State of the branch

Branch `review/neobrutalism-swiftui-audit`, worktree `Hesindion/review-neobrutalism-swiftui`, pushed, PR #10 open against `main` with a section on this work. Tree clean. Last full `make test-ui`: 315 XCTest + 49 Swift Testing cases, 0 failures.

What exists now:

| thing | where |
|---|---|
| The catalog: one entry per rule id, 45 `byHand`, 2630 `todo` | `specs/data/rules-catalog.yaml` |
| Per-status counts the build enforces | `specs/data/rules-catalog.snapshot.json` |
| Validation, snapshot, `catalog` table, `catalog_meta` (source SHA-256) | `scripts/build_rules_db/catalog.py` (+ `test_catalog.py`, 25 tests) |
| Build: atomic temp-file build, runs the Python tests first | `make rules-db` (`UPDATE_SNAPSHOT=1` to rewrite the snapshot), `make test-rules-db` |
| Skeleton generator (one-shot; re-scaffold to a temp path and merge) | `scripts/build_rules_db/scaffold_catalog.py` |
| Swift read side: `CatalogStatus`, `CatalogEntry`, `lookupCatalogEntry`, `catalogEntries(status:)`, `catalogStatusCounts`, `ruleIdsWithoutCatalogEntry`, `catalogSourceHash`, `ruleCount`; `RuleDetail.catalog` and `.levelTexts` | `Hesindion/Services/RulesDatabase.swift` |
| "In Hesindion" section and the Stufe I–IV rows | `Hesindion/Views/RuleDetailView.swift` (notes render `#if DEBUG` only) |
| Tests holding the bundled db to the catalog | `HesindionTests/RulesCatalogTests.swift` |
| Combat classification by Optolith group | `Hesindion/Models/CombatSpecialAbilityGroup.swift` (+ tests) |
| The ids the app handles (12, ids only, no `wiring` any more) | `Hesindion/Models/CombatAbility.swift` |

Gone: the `effects` table, `specs/data/rules.yaml`, `scripts/scrape_effects/`, `RuleEffectModifiers`, `CombatAbility.Wiring`.

## Decisions taken this session (do not re-litigate)

- Scope: every rule has a status; mechanics only for the app's check domains (+ damage, initiative).
- Rules live in data with a closed vocabulary, interpreted by the app; the same file serves the Flutter rewrite.
- The Regelwiki page is the source of the rule text; Optolith contributes ids, cost, prerequisites, technique ids, unlock ids. Where they differ, the page wins, no `chosen` field.
- Authoring is an LLM pipeline with human spot review; the LLM emits entries only, never code.
- GM facts are asked once and remembered for a declared span, keyed to the opponent (an opponent *roster*, not one profile).
- A rule applies to a hero exactly when its id is among the hero's traits.
- The reviewed-date key is `date`, not `on` (YAML 1.1 reads `on` as `true`).
- Rules data the app ships (`rules.db`, the catalog, later the rule text) is committed on purpose (AGENTS.md Data Policy). The Optolith source stays a sibling checkout at `../../dsa_companion_data/Data`.
- Prügel (group 21, 9 abilities) and Befehle (group 12, 6) are outside the four combat groups by the design's count. Revisit when the authoring pass reaches them; the enum's doc comment says so.

## Next: step 2, the evaluator (design §7 step 2)

Write a plan for it with the writing-plans skill, from design §3, §4, §6. The order the design fixes:

1. **`Situation`** — one struct, a plain value the view assembles, absorbing `ModifierContext`; `CombatSituation` and `OpponentProfile` become its round and opponent parts and keep their names; an opponent roster with a current target; the GM answers keyed by fact id, span, subject.
2. **The vocabulary** — `Hesindion/Engine/RuleVocabulary.swift`: closed enums for predicates (hero / loadout / situation / opponent / gm), effects (`add`, `multiply`, `choice`, `opponentAdd`, `modifyRule`, `modifyState`, `restrict`, `formula`, `gmNote`), targets, domains (+ `damage`, `initiative`), spans; exported as a JSON schema the Python validator reads. `catalog.validate` already rejects unknown top-level keys and requires `clauses` on `implemented`; it needs the clause-level vocabulary check and the `GRW_*` exemption (today a `GRW_` id is rejected because it is not in `rules.db`, and `testTheCountsAddUpToTheRules` would also fail on one).
3. **`GRW_*` entries** for the core rules: Vorteilhafte Position (+2 AT and +2 PA, mounted vs foot or GM toggle), Mehrfache Verteidigung, reach, Beengte Umgebung, the −5 Zustand cap, Passierschlag.
4. **`RuleEvaluator`** returning the five-part `Evaluation` (lines, opponent lines, offers, questions, not-applied); during migration `ModifierEngine.evaluate` returns the union with a test that no rule id is produced by both; the 37 Swift `ModifierDefinition`s move one at a time, each move deleting a definition, adding an entry, keeping the definition's test.
5. **Fixtures first** (design §6): Plänkler-Formation (choice), Gezielter Angriff/Schuss (multiply, fokus rule), Golgariten-Stil (`applies_with`, `modifyRule`, `opponent.onFoot`; the current code is wrong three ways, see its catalog note), Karmale Objekte (hero-span fact, `opponent.type(demon)`, `gm.fact`), Wuchtschlag (offer with tiers), Liegend (opponent line, attack span), Mehrfache Verteidigung (`situation.defencesThisRound`), Verweichlicht (talent target, currently not applied at all), Vinsalt-Stil (`modifyRule … set` on a `GRW_*`).
6. **Reachability test**: for every `implemented` clause, a generated hero + Situation satisfying its predicates yields a line/offer/opponent line.

Then step 3 (views read the Evaluation) and step 4 (the authoring pipeline, `scripts/author_catalog`, wiki fetch mandatory, batches: sample heroes' rules → four combat groups → Vorteile/Nachteile/Zustände → the rest).

## Small chores, independent of step 2

- **Weapon-order snapshot flake**: `CombatViewSnapshotTests.testPreparation` swaps the two melee rows between runs because `hero.meleeWeapons` is an unordered SwiftData to-many. Stable sort in `CombatLoadoutPicker` (and wherever weapons are listed), delete the 12 references, re-record with `make test-ui-record-only ONLY=HesindionTests/CombatViewSnapshotTests`. Listed in AGENTS.md as the fourth intermittent.
- `RuleDetailView`: the level label is `.frame(width: 100)` in front of a localized string; no snapshot test covers the view.
- `catalog.note` conflates `note` and `why`; `RulesCatalogTests.testCoverageDoesNotGoBackwards` hard-codes 45 (could read the snapshot JSON); `build_db.py` validates args with `assert`.
- The player-facing labels "Automatisch angewendet" and "Von der App umgesetzt" both mean "the app handles it"; decide whether the screen should collapse them.
- Advantages and disadvantages carry `group: "Vorteil"` / `"Nachteil"`; Optolith's Allgemein/Magisch/Karmal split for them is not in `groups` (seed rows for `advantage`/`disadvantage` if the authoring pass wants it).
- Issue #14 (no equipment table) means item predicates (`Rabenschnabel`, `Großschild`) match by name string.

## Working in this repo, learned the hard way

- `make test-ui` is the only sanctioned test run; one simulator; 5–20 minutes. Run it in the background with a 600 s timeout and wait for the notification. Known intermittents are in AGENTS.md.
- The session shell refuses "complex" commands in a worktree (heredocs, loops with variables, `cd` chains, command substitution). Write scripts to the scratchpad with the Write tool and run them plainly.
- Subagents share the index. Commit with an explicit pathspec (`git commit <paths> -m …`) or a docs commit will sweep up someone's staged rename. Tell subagents the same.
- Subagents sometimes add a `Claude-Session:` trailer despite instructions. Check `git log --format=%B | grep Claude-Session` before pushing; nothing was pushed with one this time (history was rewritten first).
- `make rules-db` rebuilds from scratch and rewrites a tracked binary; the build is deterministic, so an unchanged catalog gives an unchanged file.
- Editing even a comment in `rules-catalog.yaml` requires `make rules-db`, or `testTheDatabaseWasBuiltFromTheCommittedCatalog` fails (by design).
