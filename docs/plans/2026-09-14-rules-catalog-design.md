# Rules Catalog — Design

**Issue:** #27 — Rules engine: the app cannot say which rules apply.
**Status:** Draft for review.
**Date:** 2026-09-14

## 1. The problem, and what the evidence says

The app can list the rules someone wrote code for. It cannot list the rules that apply to a roll, and it cannot tell the two apart. Every missing rule so far was found at the table by a player who noticed the number was a little low.

Issue #27 asked for six measurements before any design. Their results:

**1. Distribution.** A keyword classifier over the German prose of all 1814 rules in the five categories (Sonderfertigkeiten, Vorteile, Nachteile, Zustände, Status) gives a first estimate, validated by reading 24 rules by hand. The regex was right for about half of them and wrong in systematic ways: it over-counts "conditional" (it read "pro Stufe der Sonderfertigkeit" as a condition), under-counts flat modifiers phrased as "um 4 erhöhen", cannot see whether a rule is *passive* or an *offer* the player chooses, and cannot see rules that modify other rules (Vinsalt-Stil, Zäher Hund, Blutrausch, Rondras Trutz-Stil, Golgariten-Stil — five of the 24). The reliable findings are:

- The slice that touches a roll the app makes is around **226 combat Sonderfertigkeiten** plus the combat-relevant Vorteile, Nachteile, Zustände and Status. The other ~1300 SAs (Zeremonialgegenstände, Paktgeschenke, Zauberstile, Stabzauber, …) do not.
- Within that slice, roughly half the rules are **offers** (a manoeuvre with a cost, preconditions, restrictions, and an outcome for the GM), and about a fifth **modify another rule** rather than a value. Unconditional flat modifiers are the rare case.
- Two rules the existing flows should already honour and do not: Verweichlicht (DISADV_57, Selbstbeherrschung on wound effects +2 harder) and Vinsalt-Stil (SA_923, Mehrfache Verteidigung at −2 instead of −3).

**2. Source data.** Optolith carries no mechanics. Its structured fields are cost, prerequisites, levels, `combatTechniques` (which weapons an SA applies with, 215 SAs) and `extended` (which abilities a style unlocks). Its prose has a `penalty` string on 65 of the 226 combat SAs. The 79-row `effects` table was hand-authored in `specs/data/rules.yaml`; the Regelwiki scraper only ever had a hardcoded fallback for six rules. Nothing generates mechanics and nothing can. Every rule's mechanic has to be read, and the Regelwiki is the only complete and authoritative text (Optolith's prose lags: for Golgariten-Stil it says +1 TP where the page says +1 PA, and the app applies both).

**3. Conditions.** From the prose scan and the seven known-breaking cases, predicates come from four sources: **hero** facts the app has (owned rule and tier, loadout, state, Fokus rule, select option), **round** facts the app has (mounted, defences this round, manoeuvre announced), **opponent** facts the GM states (reach, size, body plan, demon, on foot, prone, surprised), and **GM-only** facts (opposing deity, known location, principles violated). Today they are spread over `ModifierContext` (33 fields), `OpponentProfile`, `CombatSituation`, per-view state and persisted hero flags, and the engine returns a flat list of signed lines plus one cap.

**4. Interactions.** Ordering (addends, then multipliers, then the −5 Zustand cap), exclusion between manoeuvres, and rule-on-rule modification are all present in the first 24 rules read.

**5. Coverage.** `CombatAbilityCoverageTests` can only see what a sample hero carries. Boronmir's nine SAs are all handled; Robak's nine are not, and a third hero with Riposte would pass the build.

**6. The tail.** A status for all 2675 rules is cheap when most statuses are "no effect on any roll the app makes". Mechanics are only needed for the ~260.

## 2. Decisions

1. **Scope.** Every rule in `rules.db` gets an explicit status. Mechanics are authored for the app's check domains: melee attack, parry, dodge, ranged, spell, liturgy, talent check, plus damage and initiative.
2. **The rules live in data, not Swift.** One catalog file with a closed vocabulary, compiled into `rules.db`, interpreted by the app. The same file serves the Flutter rewrite.
3. **The Regelwiki page is the source of the rule text.** Optolith contributes only what it has structured: ids, cost, prerequisites, technique ids, unlock ids. Where its prose differs from the page, the page wins and there is no choice to record.
4. **Authoring is an LLM pipeline with human spot review.** The LLM emits catalog entries only, never code. Growing the vocabulary is code and a human decision.
5. **GM facts are asked once and remembered for a declared span.** Facts are keyed to the opponent they were stated about. Unanswered means the rule is off, and the calculation says so.
6. **A rule applies to a hero exactly when its id is among the hero's traits.** Never by profession, never by name match.
7. **The UI is typed per output kind, not generated.** New rules of a known kind cost no UI work.
8. **Applied and not applied are both visible at the roll.**

## 3. Runtime contract

### Situation

One struct, a plain Swift value assembled by the view, replacing `ModifierContext`. It holds:

- the hero (traits, loadout, states, Fokus rules, select options, derived values),
- the check domain,
- the round: mounted, Beengte Umgebung, parries and dodges made this round, the manoeuvre announced, two-handed grip, off-hand, Schicksalspunkt flags (today's `CombatSituation`),
- the opponent roster: a list of labelled entries, each holding the facts stated about that opponent for the fight (reach, size, body plan, demon, on foot) and for the current attack (prone, surprised), plus which entry is the current target (today's single `OpponentProfile`, made plural),
- the answers: GM facts given so far, keyed by fact id, span and subject.

### Evaluation

`RuleEvaluator.evaluate(hero:catalog:situation:) -> Evaluation`. The result has five parts:

| part | what it is | who renders it |
|---|---|---|
| `lines` | modifiers that fired, each naming its rule id and whether it is reviewed | `CombatBreakdownBox` |
| `opponentLines` | penalties on the other side's value | the opponent calculation on announcement and damage screens |
| `offers` | things the hero may do because of a rule: tiered manoeuvres, either-or choices, round-start announcements, each with cost, exclusions and restrictions | option group, fork, toggle on the announcement screen |
| `questions` | facts a rule needs that nobody has stated, each with the asking rule, its span and its subject | `CombatDisclosureSection` (attack span), the roster entry (opponent span), hero settings (hero span) |
| `notApplied` | every owned rule that did not fire, with a reason: condition false, question unanswered, wrong domain, by hand, no roll effect, not reviewed | a "Nicht angewendet" list under the breakdown |

### Spans

Every askable fact declares one:

| span | lifetime | examples | where it lives |
|---|---|---|---|
| `hero` | until changed in settings | consecrated weapons | `Hero`, under the Fokus rule's toggle |
| `opponent` | the fight | demon, size, reach, on foot | the roster entry |
| `attack` | this attack, pre-filled from the last answer for the same opponent | prone, surprised, advantageous position | the disclosure section |
| `round` | the round | defences made | `CombatSituation` |

### Order of application

Fixed in the evaluator: base adds → rule-on-rule modifications → multipliers → the −5 Zustand cap → correction lines. Offers are collected independently of lines; choosing an offer changes the Situation (manoeuvre announced), and the next evaluation reflects it.

### The UI

One renderer per output kind. A boolean question is a toggle, an enumerated one a picker, a numeric one a stepper; a tiered offer is an option group, an either-or a fork (`WoundEffectDamageControl` style), a round announcement a toggle with its cost stated. Every line and every not-applied entry names its rule and shows "ungeprüft" when the entry is unreviewed. The flows themselves (attack → defence → damage) remain hand-built; the catalog never drives navigation.

## 4. The catalog

### File

`specs/data/rules-catalog.yaml`. One entry per rule id in `rules.db`, plus entries for core rules that have no Optolith id (`GRW_*`: Vorteilhafte Position, Mehrfache Verteidigung, reach, Beengte Umgebung, the Zustand cap, Passierschlag), so a Sonderfertigkeit can modify them by name and the not-applied list is complete. Compiled by `scripts/build_rules_db/build_db.py` into a `catalog` table. The `effects` table, `specs/data/rules.yaml`, `RuleEffectModifiers` and `scripts/scrape_effects` are deleted.

### Entry

```yaml
- id: SA_661
  name: Golgariten-Stil
  group: Kampfstile (bewaffnet)
  status: implemented                       # implemented | byHand | noRollEffect | todo
  reviewed: { by: sam, date: 2026-09-14 }     # or null
  sources:
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/…/golgariten-stil.html", fetched: 2026-09-14 }
    - { kind: book, title: "Aventurisches Götterwirken I", page: 229 }
    - { kind: book, title: "Kodex des Schwertes", page: 318 }
  text: |
    Kämpft der Held beritten gegen Fußkämpfer, erhöht sich die aus der vorteilhaften
    Position resultierende Erleichterung auf AT um +2. Außerdem bekommt der Abenteurer
    noch einen Bonus von +1 PA, wenn er sich auf dem Rücken eines Reittiers befindet.
  note: >
    Beritten mit Rabenschnabel oder Großschild: +1 PA. Gegen Fußkämpfer zusätzlich
    +2 AT auf die Vorteilhafte Position, also +4 AT und +3 PA insgesamt.
  cost: 10
  prerequisites: { attributes: { MU: 13 } }
  unlocks: [SA_200, SA_207, SA_210]
  applies_with:
    all:
      - situation.mounted
      - any:
          - { loadout.weapon: { technique: CT_5, item: Rabenschnabel } }
          - { loadout.shield: { item: Großschild } }
  clauses:
    - kind: passive
      domains: [meleeAttack]
      when: [opponent.onFoot]
      effects: [{ modifyRule: { id: GRW_vorteilhaftePosition, target: at, add: 2 } }]
    - kind: passive
      domains: [meleeParry]
      effects: [{ add: { target: pa, value: 1 } }]
```

Field by field:

- `name`, `group`, `text` (verbatim from the page), `note` (one line, what the rule does): the entry must be readable from nothing but an id, and reviewable without a browser.
- `status`: `implemented` has clauses; `byHand` has a `pointer` to a Swift symbol that a test resolves; `noRollEffect` has a note saying why; `todo` has a `why` saying what the vocabulary could not express.
- `reviewed`: null until a person checked the clauses against `text`. Unreviewed entries run and are marked "ungeprüft" in the app.
- `sources`: the wiki URL with fetch date, and the publications the page lists.
- `cost`, `prerequisites`, `unlocks`: from Optolith, never read at roll time, kept so the entry describes the whole rule.
- `applies_with`: a loadout and situation predicate shared by every clause (a style's Kampftechniken field).
- `clauses`: `kind` passive or offer; `domains`; `when` predicates; `effects`. Offers add `tiers`, `excludes` (rule ids), `cost` (actions), `restrictions`, and `outcome` (a GM note).

The worked result for a mounted Golgarit with a Rabenschnabel against a foot fighter: AT +4 (Vorteilhafte Position +2, Golgariten-Stil +2), PA +3 (Vorteilhafte Position +2, Golgariten-Stil +1). Against a mounted opponent: +1 PA only. On foot: nothing, and the not-applied list says "Golgariten-Stil: nicht beritten".

### Vocabulary

Closed enums in one Swift file (`Hesindion/Engine/RuleVocabulary.swift`), exported as a JSON schema for the build-time validator and for Flutter. Each item has exactly one renderer and one test.

**Predicates**, by source:

- hero: `hero.hasRule(id, minTier)`, `hero.selectOption(id, sid)`, `hero.state(id, minLevel)`, `hero.fokusRule(id)`, `hero.attribute(id, min)`
- loadout: `loadout.weapon { technique, item, twoHanded }`, `loadout.shield { item }`, `loadout.offHand`, `loadout.reach`
- situation: `situation.mounted`, `situation.beengt`, `situation.defencesThisRound(kind, min)`, `situation.maneuver(id)`, `situation.roundStart`
- opponent: `opponent.reach`, `opponent.size`, `opponent.bodyPlan`, `opponent.onFoot`, `opponent.state(id)`, `opponent.type(demon | dragon | undead | …)`
- gm: `gm.fact(id)` with a declared span; missing becomes a question

Combinators: a list is `all`; `any` and `not` are explicit.

**Effects:** `add { target, value, perTier }`, `multiply { target, factor }`, `choice [effect, effect]`, `opponentAdd { target, value }`, `modifyRule { id, target, add | set | multiply }`, `modifyState { id, delta }`, `restrict { kind }` (no parry with this weapon, dodge only, no further defence this round, no action this round), `formula { target, expression }` (damage overrides such as +1W6 or "+2 + GS/2"), `gmNote { key }`.

**Targets:** `at`, `pa`, `aw`, `fk`, `tp`, `ini`, `gs`, `talent(id)`, `spell`, `liturgy`, `fumbleRange`, `qsCap`.

**Domains:** the existing `CheckDomain` cases plus `damage` and `initiative`.

### What fails the build

- A rule id in `rules.db` with no catalog entry, or a catalog id not in `rules.db` and not `GRW_*`.
- Any predicate, effect, target, domain or span outside the vocabulary.
- A `byHand` pointer whose symbol does not exist.
- The per-status counts differing from `specs/data/rules-catalog.snapshot.json` unless that file changes in the same commit: `implemented` may not shrink, `todo` may not grow silently.
- An `implemented` clause that cannot fire: because the vocabulary is closed, a test constructs a hero owning the rule and a Situation satisfying its predicates, and asserts a line, offer or opponent line results.
- The fixture table (section 6) not matching.

## 5. Authoring pipeline

`scripts/author_catalog/`. For each rule id:

1. Gather: the Regelwiki page (fetched, cached with date), and from Optolith the cost, prerequisites, technique ids, unlock ids, levels.
2. Prompt with the vocabulary JSON schema, the entry schema, and the reviewed exemplars (the nine fixtures of section 6 to begin with).
3. Receive an entry, or `status: todo` with a `why` sentence.
4. Validate against the schema; reject and retry once on failure; write.

Batches, in order: rules owned by the sample heroes; the four combat groups; Vorteile, Nachteile, Zustände, Status; everything else (expected to be mostly `noRollEffect`). Each batch updates the snapshot and is spot-reviewed before merge. The `why` sentences of `todo` entries are the backlog for vocabulary growth, taken in batches by a person.

The Optolith prose is not stored. The script may log where it differs from the page; nothing reads that log.

## 6. Fixtures

A table test: hero traits and loadout, Situation, answers → expected lines, opponent lines, offers, questions, not-applied. The initial rows, chosen because together they exercise every vocabulary item:

| rule | exercises |
|---|---|
| Plänkler-Formation SA_884 | `choice`, offer at fight setup |
| Gezielter Angriff SA_160 / Schuss SA_161 | `multiply` on the Zonenaufschlag, `hero.fokusRule` |
| Golgariten-Stil SA_661 | `applies_with`, `modifyRule`, `opponent.onFoot` as a question |
| Karmale Objekte (Fokus) | `hero` span fact, `opponent.type(demon)`, `gm.fact(opposingDeity)`, `multiply` on TP |
| Wuchtschlag SA_67 | offer with `tiers`, `perTier`, `damage` domain |
| Liegend (opponent) | `opponentAdd`, `attack` span |
| Mehrfache Verteidigung GRW | `situation.defencesThisRound`, per-kind counting |
| Verweichlicht DISADV_57 | `talent(Selbstbeherrschung)` target in a non-combat flow |
| Vinsalt-Stil SA_923 | `modifyRule … set` on a `GRW_*` rule |

## 7. Landing it

Each step leaves the build green.

**Step 0 — importer.** `isCombatSpecialAbility` reads Optolith's group id (Kampf, Kampf (erweitert), Kampfstile bewaffnet/unbewaffnet) instead of the effects table. Test: every SA in those groups is filed as combat. Fixes 217 misfilings; depends on nothing below.

**Step 1 — registry.** The catalog file with an entry for every id: `byHand` with pointers for the nineteen rules the app handles, `todo` for the rest. Build script compiles it; the effects table, `rules.yaml`, `RuleEffectModifiers` and the scraper are deleted. `CombatAbility.wiring` is replaced by the catalog status. Tests: structural checks and the snapshot. This alone makes coverage a measured number.

**Step 2 — evaluator.** `Situation` absorbs `ModifierContext`; `CombatSituation` and `OpponentProfile` become its parts and keep their names. `RuleEvaluator` reads the catalog. During migration `ModifierEngine.evaluate` returns the union of the Swift definitions and the evaluator, with a test that no rule id is produced by both. The 37 definitions move one at a time, each move deleting a definition, adding an entry, and keeping the definition's existing test. The nine fixtures go first. The Zustände become `COND_` entries; the cap becomes a catalog rule. When the Swift list is empty, the definition machinery goes.

**Step 3 — views.** The announcement screen builds manoeuvres from `offers`, opponent questions from `questions`, and shows the not-applied list; `CombatView` holds the roster with a current target; the defence, damage and talent-probe screens follow for their domains. `isFokusRuleActive` branches that decide which screens exist stay.

**Step 4 — pipeline.** The authoring script runs batch by batch until `todo` is empty for the combat slice, then for the rest.

## 8. Tests, by kind

- Structural: at build time in Python and again in Swift against the bundled table.
- Reachability: one generated case per `implemented` clause.
- Fixtures: section 6, extended with every reviewed exemplar.
- The existing modifier tests, unchanged, as the regression net through step 2.
- Snapshot tests for the announcement screen with offers, questions and the not-applied list.
- The sample-hero smoke test: no rule on any sample hero is `todo`.

## 9. Out of scope

- Modelling opponents beyond stated facts (ADR-0005 holds; the roster is facts, not combatants).
- An equipment table (issue #14); item predicates match the hero's item name until one exists.
- Driving navigation from the catalog.
- Aligning `FokusRule` raw values with Optolith's `FR_*` ids; worth doing, separate change.

## 10. Consequences

- Adding a rule of a known shape is a catalog entry and a fixture row, no Swift.
- Coverage is a number in a committed file, and the build fails when it moves the wrong way.
- The player sees, on every roll, which owned rules were applied, which were not and why, and which are unreviewed.
- Discrepancies between the code and the page surface during authoring, as the Golgariten +1 TP did, rather than at the table.
- The Flutter rewrite shares the catalog and the schema; only the interpreter is written twice.
