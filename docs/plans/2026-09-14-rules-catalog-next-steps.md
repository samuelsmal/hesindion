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

## Step 2 landed (plan: `docs/plans/2026-09-14-rules-evaluator-plan.md`)

`Situation`, `RuleVocabulary` + `specs/data/rule-vocabulary.json`, the Python clause validator and JSON compile, `RuleCatalog` decoding, `RuleEvaluator`, the union in `ModifierEngine`, eight `GRW_*` entries, the nine fixtures (`RuleFixtureTests`), the reachability test. Snapshot: implemented 15, byHand 40, todo 2628.

## Next: finish the moves, then step 3

Still in Swift, each a delete-the-definition / add-the-entry / keep-the-test move like Tasks 7–15 of the evaluator plan:

- `SharedModifiers.encumbrance` (COND_1) — needs a `hero.belastung` predicate or `hero.state(belastung)` with a per-level value and the mounted −1 forgiveness.
- `StateModifiers` per-level Zustände (COND_2 Betäubung, COND_4 Furcht, COND_5 Paralyse, COND_6 Schmerz, COND_7 Verwirrung, STATE_7 Fixiert) — needs `per: level` on `add`; `entrueckungDef` (COND_3) needs the gottgefällig sign flip.
- `MeleeModifiers.maneuverAT` (SA_48 Finte, SA_66 Vorstoß), `dualAttackPenalty` / `DefenseModifiers.dualAttackDefense` (SA_42), `offHandPenalty` / `offHandParry` (ADV_5) — need `situation.dualAttack`, `situation.offHand`, and Finte's opponent line.
- `DefenseModifiers.schipDefenseBoost`, `mountedDodgePenalty`, `twoHandedGripPA`; `DamageModifiers`' grip and Sturmangriff (SA_43) — `GRW_*` entries and `situation.twoHandedGrip`, `situation.schip…` predicates.
- `RangedModifiers` (eight) and `MagicModifiers` (seven) — `GRW_*` entries with enumerated `gm.fact`s (distance, size, movement, visibility, aiming, distraction) or numeric ones (maintained spells, iron carried): the vocabulary needs non-boolean facts first.

When the Swift list is empty, `ModifierDefinition`, the union and `Situation`'s flat ranged/magic fields go.

Step 3 (views read the Evaluation): the announcement builds manoeuvres from `offers`, opponent questions from `questions` (a boolean fact is a toggle, `onFoot` and `advantageousPosition` first), shows the not-applied list under the breakdown and "ungeprüft" on unreviewed lines; `CombatView` holds the roster with a current target; `CombatSituation.pendingMultipleDefensePenalty` and `CombatZonePicker`'s chips read the evaluation instead of their own arithmetic; `Situation.choices` / `announced` replace the Plänkler and manoeuvre bridges. Then step 4 (the authoring pipeline).

The per-task reviews left a list of step-3 questions in the evaluator plan's "Follow-ups recorded during execution" section (per-render evaluation cost, display rank of lines, opponent-line labels, offers without a span, `Evaluation.questions` without a reader, off toggle = not stated, the Schip and statuses); read it before designing step 3.

## Vocabulary grown since (2026-09-18 combat bug round)

The predicates `situation.water` (`none | huefthoch | unterWasser`, `GRW_kampfImWasser`/`SA_163`/`SA_418`/`ADV_71`) and `opponent.size` (`CreatureSize`, now with `winzig`; `GRW_groessenkategorie`) and the target `rs` (opponent-only, always via `opponentAdd`, `ITEMTPL_19`'s Dornenspitze) joined the closed vocabulary. An offer's line carries a roman numeral only when its clause has `tiers`: `GRW_passierschlag` is a plain `-4 AT` offer and reads "Passierschlag", not "Passierschlag I"; Wuchtschlag's `tiers: owned` still reads "Wuchtschlag I/II" (`RuleEvaluator`, the `clause.tiers != nil` check). Catalog ids are no longer only `rules.db` ability rows: an id starting `ITEMTPL_` (Optolith's own weapon templates, e.g. `ITEMTPL_19` Rabenschnabel) is validated by id and name against the new `equipment` table instead, and — unlike every other id — is optional, since a weapon with no template entry is fine. The step-3 open question "literal toggle labels not tied to the catalog" (`AT/PA +2` on the advantageous-position toggles, `Parieren −2` on the prone toggle, `TP ×2` on the opposing-deity toggle) now also covers `weaponOffer.<id>` — a weapon-template offer's own toggle text (`weaponOffer.ITEMTPL_19` "Dornenspitze") is written by hand in `Strings.swift`, the same as the others, even though the line it produces once taken is labelled from the rule's `name`; step 3 should draw all of them from the evaluation together.

## Small chores, independent of step 2

- **Weapon-order snapshot flake**: `CombatViewSnapshotTests.testPreparation` swaps the two melee rows between runs because `hero.meleeWeapons` is an unordered SwiftData to-many. Stable sort in `CombatLoadoutPicker` (and wherever weapons are listed), delete the 12 references, re-record with `make test-ui-record-only ONLY=HesindionTests/CombatViewSnapshotTests`. Listed in AGENTS.md as the fifth intermittent.
- `RuleDetailView`: the level label is `.frame(width: 100)` in front of a localized string; no snapshot test covers the view.
- `catalog.note` conflates `note` and `why`; `RulesCatalogTests.testCoverageDoesNotGoBackwards` hard-codes 45 (could read the snapshot JSON); `build_db.py` validates args with `assert`.
- The player-facing labels "Automatisch angewendet" and "Von der App umgesetzt" both mean "the app handles it"; decide whether the screen should collapse them.
- Advantages and disadvantages carry `group: "Vorteil"` / `"Nachteil"`; Optolith's Allgemein/Magisch/Karmal split for them is not in `groups` (seed rows for `advantage`/`disadvantage` if the authoring pass wants it).
- Issue #14's equipment table landed (Task 11 of the combat bug round: `rules.db`'s `equipment` table, `EquipmentEntry`), but item predicates (`Rabenschnabel`, `Großschild`) still match by name string — the table itself is looked up by loadout *name* too (`Hero.equipmentEntry(forLoadoutNamed:)`), since names, not ids, are what the loadout and `applies_with: { loadout.weapon: { item: … } }` identify a weapon by.
- `reviewed: null` on all fifteen implemented entries: read each against its page and put your name and the date on it.

## Working in this repo, learned the hard way

- `make test-ui` is the only sanctioned test run; one simulator; 5–20 minutes. Run it in the background with a 600 s timeout and wait for the notification. Known intermittents are in AGENTS.md.
- The session shell refuses "complex" commands in a worktree (heredocs, loops with variables, `cd` chains, command substitution). Write scripts to the scratchpad with the Write tool and run them plainly.
- Subagents share the index. Commit with an explicit pathspec (`git commit <paths> -m …`) or a docs commit will sweep up someone's staged rename. Tell subagents the same.
- Subagents sometimes add a `Claude-Session:` trailer despite instructions. Check `git log --format=%B | grep Claude-Session` before pushing; nothing was pushed with one this time (history was rewritten first).
- `make rules-db` rebuilds from scratch and rewrites a tracked binary; the build is deterministic, so an unchanged catalog gives an unchanged file.
- Editing even a comment in `rules-catalog.yaml` requires `make rules-db`, or `testTheDatabaseWasBuiltFromTheCommittedCatalog` fails (by design).
