# Rules engine and rule format — design

**Status:** design, approved in conversation 2026-09-24; awaiting review of this document.
**Replaces:** `RuleEvaluator`, `ModifierEngine`, the `*Modifiers.swift` definitions,
`specs/data/rules-catalog.yaml` and `RuleVocabulary` (removed domain by domain, see §9).
**Inputs:** the 2026-09-23 decisions in [`docs/rules-rework/README.md`](../rules-rework/README.md);
the worked examples 1–22 in [`docs/rules-rework/examples/`](../rules-rework/examples/) — their
rule files, situations and `# FORMAT:` notes (the rule files and situations are in
[`specs/rules/`](../../specs/rules/) since 2026-09-26, see ADR-0015); the probe beyond melee (examples 20–22).

## 1. The requirement

A person can check that the rules are applied correctly and completely:

- **as a developer**, by reading a rule file: every clause of the page, verbatim, with what the app
  does with it or why it does nothing;
- **as a player, in game**: every number says which rule it came from, and every rule that did
  not apply says why;
- **afterwards**, from an exported log of what the app computed, detailed enough to turn a
  wrong moment at the table into a test case (§8).

## 2. Scope

This design covers the rule format and its compiler, the evaluation core, checks as staged
procedures, and state over time — one engine. Two things follow it as their own work, with
gates set here:

- **The in-game breakdown screens.** No domain switches to the new engine until its screen
  shows every line with its origin (§9).
- **Migration of the rules the app already implements**, domain by domain (§9).

Decided in conversation:

| Question | Decision |
|---|---|
| How rules reach the app | Python (`make rules-db`) validates the YAML and compiles rules and situations to JSON; Swift reads JSON. No YAML parser in the app |
| When the engine is done | Every situation in examples 1–22 passes, except those resting on an open ruling: those run and are reported *pending*. `appToday` is never tested |
| How it replaces the old engine | Built and tested beside it, not wired in; screens switch one domain at a time, each switch deleting that domain's old code. Never a union of two engines |
| Encoding | Declarative: a closed vocabulary of effect verbs on a fixed phase pipeline. A mechanic that does not fit becomes a new verb with an interpreter and a test, never per-rule code |
| Naming | One language everywhere (§3.1) |

## 3. Architecture

```
rules/**/*.yaml ──┐                          ┌─► rules.json ──────► Engine (Swift, pure)
situations/*.yaml ┼─► rulec (Python) ────────┤                        ▲        │
vocabulary.json ──┘   validate + compile     └─► situations.json ─► harness     │
                                                                     │          ▼
                                   screens ── Query / Action + Situation ─► Breakdown / Events
                                                                                │
                                                                                ▼
                                                                    log (§8) ─► export
```

| Unit | Job | Depends on |
|---|---|---|
| `vocabulary.json` | The closed list of verbs, targets, facts (with owners), value forms, reason codes. The one contract between YAML, compiler and Swift | — |
| `rulec` | Validates rule and situation files against the vocabulary; compiles them to JSON; builds the reach index (§5.4). Replaces `catalog.py` in `make rules-db`. `rulings.py` stays beside it | vocabulary |
| Rule model (Swift) | Decoded, immutable rules. No logic | `rules.json` |
| Evaluator (Swift) | `(Query, Situation) → Breakdown`. Pure: never reads SwiftData, never writes | rule model |
| Action layer (Swift) | `(Action, Situation) → [Event]`, and the check procedures (§6). Pure | evaluator |
| Harness (XCTest) | Runs every compiled situation through the evaluator and the action layer | all of the above |

The app builds a `Situation` value from the hero, the loadout, the round and the facts stated, and
applies returned events to the hero in one place. The engine keeps nothing between calls.

### 3.1 One language

Every vocabulary word is spelled the same in the YAML, the compiled JSON and Swift: `useLevel` is
the YAML key, the JSON field and the Swift enum case. YAML therefore uses **lowerCamelCase**
(`useLevel`, `gmFact`, `hero.mounted`, `notApplied`), because Swift cannot spell `use_level`.
There is no mapping layer anywhere. Domain terms stay **German** in all three (Belastung,
Wundschwelle, Zustand, Stufe, Kampfrunde); structural words stay **English** (`add`, `when`,
`forbid`, `lines`). A test holds Swift's vocabulary identical to `vocabulary.json`.

## 4. The rule format

### 4.1 A rule file

```yaml
id: SA_862
name: Formation
kind: specialAbility          # specialAbility | advantage | disadvantage | condition | state
                              # | core | equipment | creature | talent
ruleset: core                 # or fokus.<slug>
source: { url, book, page, checked, hash, also: [...] }
reviewed: null                # or { by, date }
levels: 3                     # when the rule has Stufen
options: sid                  # when the hero file chooses one (Schlechte Eigenschaft)
provides: { ... }             # tables and ordered scales other rules read
clauses: [ ... ]
rulings: [ ... ]
agentPass: null               # the review queue's flag, unchanged in meaning
```

### 4.2 Clauses

Every clause has its verbatim `id` and `text`, and **exactly one** of:

| Key | Meaning |
|---|---|
| `effects: [...]` | What the app does with it |
| `unencoded: <why>` | The app cannot apply it; the player sees the text |
| `none: <why>` | Nothing to do at the table: a prerequisite, a cost, the page's own example |

This replaces the drafts' `effects: none` + `why`, and lets the compiler prove that no clause is
dropped.

### 4.3 Effects

An effect is one verb with its payload, plus `when`, and optionally `ruling` (an id or a list),
`because` (the reason text shown when it forbids or does not apply) and `phase` (§5.2, only
where the default is wrong). Twenty-two verbs:

| Group | Verbs | Folds in from the drafts |
|---|---|---|
| Value | `add`, `set`, `multiply`, `cap`, `floor`, `useLevel` | raise, lower, sets, halve, apply_level, shift, keep, keeps, opponent_add (as a target) |
| Line control | `replace`, `suppress` | replaces, cancel, cancels, exempt |
| Legality | `forbid`, `require`, `limit` | requires, excludes, opponent_may_only, gates, not_allowed |
| Player and GM | `offer`, `ask`, `tell` | choose, show, allow |
| Data | `provide`, `derive` | provides, defines, define, table, table_for, scale |
| Consequence | `check`, `gain`, `cost`, `process`, `item`, `reroll` | requires_check, on_failure, on_success, charge, costs, lasts |

`check` carries `onSuccess` and `onFailure` lists of effects. `gain` covers Zustand Stufen and
Status in both directions (`gain: { condition: COND_6, levels: 1 }`, negative to remove). The
exact payload of each verb is fixed in `vocabulary.json` by the migration (§10) — the table above
is its complete list, and a verb outside it is a compile error.

### 4.4 Targets

One closed list of named values. Context is a parameter, never a separate name:

- `at`, `pa`, `aw`, `fk`, `ini`, `gs`, `leMax`, `wundschwelle`, `tp`, `rs`, `sp`, … —
  `pa(with: weapon | shield)` replaces `pa_weapon`, `shield_parry`, `parries.*`, `parry_main`;
- `opponent.<target>` for effects on the other side of the table;
- `check.attribute`, `check.modifier`, `check.fw`, `check.qs`, `check.dice` for the stages of §6;
- `spell.cost`, `spell.castingTime`, `spell.range` and the like for the parameters of the action
  being taken (probe, example 20);
- `item.<value>` for a weapon or shield value another rule changes (`item.ladezeit`, Schnellladen).

### 4.5 Values

Four forms only — never a free formula, so each clause has one readable encoding:

| Form | Example |
|---|---|
| a number | `2` |
| a level expression | `level - 1` |
| a proportion | `{ per: hero.wundschwelle, of: hit.sp, round: down }` |
| a table lookup | `table(trefferzonen.TZ11, hit.zone)` |

Rounding names the shared ruling it follows (`round-up`) where the page does not say.

### 4.6 Facts and `when`

`when` is `all` / `any` / `not` over named **facts**. Every fact in the vocabulary has one
**owner**, which decides who is asked for it and is recorded on every line that used it:

| Owner | Examples |
|---|---|
| `sheet` | attributes, owned rules, talents, `hero.has` |
| `loadout` | weapon in hand, shield, armour worn, reach |
| `player` | a choice: Formation +2 AT, Dornenspitze, an announced manoeuvre |
| `gm` | `gmFact`: attacked from behind, a trigger, cover, the GM's modifier |
| `round` | defences made so far, round number, double attack |
| `roll` | a stage's dice, faces, result |
| `derived` | a value another query computed |

A fact nobody has stated is **unknown**, not false. An effect whose `when` depends on an unknown
fact produces a **question** (§5.3), not a guess.

### 4.7 Rulings

Kept as today (id, question, context, situations, options, recommended, answer, status, decided,
applies_to, notes), in the rule file or `rules/rulings.yaml`. An effect names the ruling it rests
on. **An effect resting on an open ruling applies nothing**: the engine shows its clause and the
question as text. A line resting on a decided ruling is marked *Auslegung*.

## 5. Evaluation

### 5.1 Queries

A screen asks for one target in one context — `at(with: Rabenschnabel)`, `wundschwelle`,
`check.modifier(talent: Willenskraft)` — against a `Situation`. A query is a value; the same query
and situation always give the same breakdown.

### 5.2 Phases

Every target runs the same order. The drafts' `before:` cases become the phase an effect belongs
to, never a free ordering. The other verbs sit outside the value pipeline: `provide` is data read by
`table(...)`; `offer`, `ask` and `tell` fill the breakdown's offers, questions and texts;
`check`, `gain`, `cost`, `process`, `item` and `reroll` run on the action layer (§6, §7).

| # | Phase | Verbs | Example |
|---|---|---|---|
| 1 | base | `derive` | KtW + (MU−8)/3; ⌈KO/2⌉ |
| 2 | level | `useLevel` | Schmerz III wirkt wie II (Zäher Hund) |
| 3 | add | `add`, `set` | Belastung −1; Formation +2 |
| 4 | lines | `replace`, `suppress` | a line dropped, kept in `notApplied` with the reason |
| 5 | multiply | `multiply` | TP doubled; Ladezeit halved |
| 6 | cap | `cap`, `floor` | the −5 Zustand cap, over the sum |
| 7 | legality | `forbid`, `require`, `limit` | a defence at 0 or below is blocked |

### 5.3 The breakdown

The one output every screen reads:

| Field | Content |
|---|---|
| `lines` | each: value, rule, clause, `via` chain, `ruling` (→ *Auslegung*), the facts used with their owners |
| `total`, `result` | the sum of the lines; the value after base |
| `notApplied` | every rule the hero owns (or that applies to everyone) which reaches this target and did not fire, with a reason code and text |
| `offers` | choices this query could take (Formation, Dornenspitze, a reroll) |
| `questions` | unknown facts that would change the result, with their owner |
| `texts` | unencoded clauses and open rulings that reach this target |
| `legal` | whether the action is allowed, and why not |

### 5.4 Reach

`rulec` builds an index from target to the effects that can reach it. A query evaluates only those;
the same index fills `notApplied` and proves that every clause can fire (the successor of
`RuleReachabilityTests`).

### 5.5 Provenance

Every line, at every stage, carries its origin: rule, clause, `via`, ruling, and each fact it used
**with who stated it** — sheet, loadout, player, GM ("Meister: Stärke des Auslösers −2"), roll.
Steps that are not additions are lines too: a replaced die ("W2: 17 → 5, Begabung"), a level
applied as another, a halved cost, a capped sum. A modifier the player types in freely is a line
"frei eingegeben". **No number changes without a line saying why.**

## 6. Checks as staged procedures

A check is a procedure with named stages; each stage is a target, so rules hook in with the same
verbs.

**Talent, spell and liturgy checks (3W20):**

| Stage | Target | Rules hooking in |
|---|---|---|
| `attributes` | the three Teilprobe values: attribute + one shared `check.modifier` | every Erschwernis; the GM's modifier; Belastung where it reaches; `forbid` on a value ≤ 0 |
| `pool` | `check.fw` | Fertigkeitsspezialisierung (`add: { to: check.fw }` — not an Erleichterung) |
| `dice` | `check.dice` | Begabung and Schips as `reroll` |
| `result` | FP left, success, Doppel-1/Doppel-20 by counting faces | the talent's own crit text |
| `quality` | `check.qs` | the QS table; 0 FP counts as QS 1; the `crit-qs` ruling |

**Combat rolls (1W20):** `target` (the §5 breakdown of AT, PA, AW or FK) → `dice` → `result` (a
confirmation roll is itself a `check`) → `consequence`: TP → RS → SP → the Wundschwelle
comparison → the Wundeffekt check, each a target with its own lines.

**Dice come in; the engine never rolls.** The app's `DiceRoller`, or a player entering physical
dice, supplies them. The engine stays deterministic and a situation can state its `rolls`.

A procedure runs as a state machine on the action layer; each step is
`(state, input) → (state, breakdowns, offers, events)`:

1. `start` — the stage breakdowns, awaiting dice;
2. `dice` — the result, and open `reroll` offers (Begabung and a Schip in either order, the
   player's, until confirmed);
3. `reroll` — a replaced die; the log keeps both faces;
4. `confirm` — the events: cost paid (half on failure), QS logged, a Zustand gained on a failed
   Wundeffekt check, "Autoritätsglaube: gibt nach".

## 7. State over time

Everything that lasts beyond one query is data in the `Situation`, changed only by events.

| Kind | Content | From |
|---|---|---|
| Pools | LE, AsP, KaP, Schips, ammunition. `cost` names a pool and an amount (possibly fixed only after the roll), optionally a `split` (player's choice, a minimum in one pool) and a `fallThrough` order (AsP, then LeP). Paying LeP lowers LE so Schmerz follows, but is not damage: no RS, no Wundschwelle | ex. 20 |
| Processes | Zielen, Laden, Bogen spannen, a multi-action cast: id, progress, cap, what advances it, what completes it, what breaks it off. May outlive the round | ex. 21 |
| Item state | loaded, strung, a shield's current StP, damaged. Keyed by item **instance**, so two identical daggers are two items | ex. 14, 21 |
| Spans | `action`, `round`, `fight`, `whileFormed`, `untilCleared` | ex. 3, 14, 19 |
| Game clock | Kampfrunden in a fight; minutes and hours outside. A situation value the player advances — enough for recurring costs ("2 AsP pro 5 Minuten") and Zustand durations | ex. 15, 20 |

Events are plain values — `paid`, `progressed`, `completed`, `brokenOff`, `itemChanged`, `gained`,
`cleared`, `logged` — each carrying its origin like a line. The app applies them in one place.

## 8. The log and its export

The log is the record of what the engine computed, detailed enough to improve the app from.

**Each entry holds:**

- the query or action, and the full `Situation` it ran against (the facts, with their owners);
- the full breakdown(s) — lines with origin, `notApplied`, offers taken, questions and their
  answers, texts shown;
- the dice as rolled, rerolls, and the events applied;
- the app version, the `rules.json` hash and vocabulary version, the hero file id;
- an optional note by the player ("das war falsch: …"), and a flag for "this looks wrong".

**Export:**

- **The session log as JSON Lines**, one entry per line, from the hero's log and the adventure
  view: complete, machine-readable, stable field names in the one language of §3.1.
- **One entry as a situation draft**: a `situations/*.yaml` stub with the entry's hero, loadout,
  facts and rolls as input and what the engine computed as `expect`, plus the player's note as
  `appToday`. Correcting the numbers that were wrong turns the table moment into a regression
  test.

The log's storage replaces today's summary payloads (`TalentCheckPayload`,
`CombatActionPayload`, …) domain by domain with the cut-over; the undo that `Reversible` gives
today keeps working from the stored events. The export screen belongs with the breakdown screens,
but the entry format is part of this design and is tested with the harness: exporting a situation's
run and re-importing it as a situation must reproduce the same breakdown.

## 9. Cut-over

The engine is built beside the old one. Domains switch in this order:

1. derived values and the sheet (LE, Wundschwelle, INI Basiswert, AT/PA/AW with breakdown)
2. melee attack and defence
3. damage (TP → RS → SP → Wundschwelle, Wundeffekte)
4. Zustände and the cap
5. talent checks
6. spells and liturgies
7. ranged combat

**A domain switches only when:** every decided situation of the domain passes; its screen shows
every line with its origin, the *Auslegung* marks and the not-applied list (§5.5); its log entries
use the §8 format; and its old `*Modifiers.swift` definitions and catalog entries are removed in
the same change. When the last domain moves, `RuleEvaluator`, `ModifierEngine`,
`rules-catalog.yaml`, its snapshot and `RuleVocabulary` are deleted.

## 10. Situations, the harness, and moving the examples

### 10.1 The situation format

The same vocabulary as the rules, synonyms removed:

- `hero`: `heroFile` plus overrides, or stated values; `loadout`, `choose`, `gm`, `opponent`,
  `ally`, `rulesets`, `rolls`, `sequence` for multi-step procedures;
- `expect` keyed by **query** (`pa(with: shield)`), each with `total`, `result`, `lines`
  (rule/clause, `via`, `ruling`), `notApplied`, `offered`, `notOffered`, `questions`, `legal`,
  `events`, and per-stage values (`fp`, `qs`, `spent`);
- `appToday` stays as documentation; nothing reads it.

### 10.2 Matching

Lines match exactly by rule and clause, in any order, with value and `via`. What a situation does
not mention is not checked, so a situation about AT is not broken by a new INI rule. `notApplied`
matches by rule and reason code.

**Pending:** a situation whose expected lines cite an open ruling, or whose rules have an open
ruling on the path, runs and is reported pending with the ruling's id. It never fails the build;
answering the ruling makes it required.

### 10.3 Moving the examples and the review tooling

In this order, each step checked:

1. **`migrate.py`** applies a fixed old-key → new-key table (§4.3's right-hand column, the target
   and situation renames of §4.4 and §10.1, snake_case → lowerCamelCase) to every rule file —
   the 68 drafted and the probe's — and every situations file. What it cannot map mechanically is
   listed for a hand edit. A rule whose clause meaning is unchanged keeps `reviewed`; a clause
   changed by hand sets its rule to `reviewed: null`. The result is one commit, reviewed as a
   diff.
2. **`rulec`** validates everything; every file must load. This proves the vocabulary covers all
   22 examples.
3. **The review tooling** — `review.py`, `rulefiles.py`, `rulings.py`, the sweeps and their tests —
   moves to the new keys; the one-key edits (`reviewed`, `answer`, `agentPass`) keep working.
4. **The examples README** (format description) and `RULINGS.md` are regenerated.

## 11. Errors

**At compile time** `rulec` fails, naming the file and line, on: an unknown verb, target, fact or
key; a clause with none, or more than one, of `effects` / `unencoded` / `none`; a `ruling` or `via`
pointing at nothing; a fact without an owner; a value outside the four forms; a `useLevel` or
`replace` naming a rule that cannot reach the target; a clause no query can reach; a situation
expecting a rule or clause that does not exist.

**At run time** the engine never throws. An undecidable situation produces a question; a rule that
cannot be applied produces a text line ("Regel konnte nicht angewandt werden: …") and a log entry,
never silence. The one hard failure — `rules.json` built for another vocabulary version — is
caught by a test.

## 12. Testing

- The situations harness is the acceptance suite (§10.2).
- Unit tests for each verb's interpreter, the phase order, each procedure step, event application.
- `rulec`'s tests cover every compile error of §11.
- Reachability: every clause with effects can fire.
- The Swift vocabulary equals `vocabulary.json`.
- Log round-trip: a run exported as a situation reproduces its breakdown (§8).

## 13. Documents

- A new ADR records this design and supersedes ADR-0012 to ADR-0014, which were never accepted
  and describe `main`.
- AGENTS.md: the rules paragraph and the Data Policy are rewritten; `rules.db` leaves git, as
  decided on 2026-09-23.
- CHANGELOG entries with each domain's cut-over.

## 14. Open

- **Länger dauernde Handlungen.** The page defining them was not found in the probe; Zielen, Laden
  and multi-action casts rest on it. Needed before the process verb's payload is fixed.
- **13 open rulings** in the examples; they make their situations pending, not the design.
- **The verb payloads** are fixed by the migration (§10.3 step 1), not here; the verb list is.
