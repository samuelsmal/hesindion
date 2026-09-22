# Rules Pipeline — Operational Status

**As of 2026-09-21, branch `feat/rules-data-pipeline`, last code/corpus commit `f276b14`
(this document landed at `cdcb332`, which changed no code).**

This document holds the state of the rules pipeline that is neither a decision nor a task: what the
calibration gate measured, what that measurement blocks, what is waiting on a ruling, and what was
already settled so it is not re-derived. It exists because that state lived in a session ledger that
is not tracked and does not survive the branch.

Where each kind of thing lives:

| | |
|---|---|
| Decisions | `docs/adr/0007`, `0008`, `0009` — amended, never rewritten |
| Tasks, with status and commit range | `docs/plans/2026-09-20-rules-pipeline-and-authoring.md` |
| What changed, in detail, with evidence | `CHANGELOG.md` under `[Unreleased]` |
| **Operational state — start here before running anything** | this file |

No DSA rule prose appears here, per the Data Policy in `AGENTS.md`. Rule ids, field names and our own
encoded numbers are our encoding, not the rules' text.

---

## 1. The calibration gate FAILED. Do not start an authoring wave.

`tests/rules/test_calibration.py` grades one recorded live run of the two-agent pipeline
(`tests/rules/calibration/2026-09-21-sonnet/`) over the ten hand-authored golden rules. The gate is
Task 7 of the plan, it was user-ordered and non-skippable, and it was closed honestly as a failure.

**Tier 1: 7 of 10.** Author/verifier agreement: 6 of 10. Model: Sonnet — Opus scored the same Tier 1
on identical inputs and a slightly better agreement rate, so the gate is not model-bound and paying
for Opus across 222 rules × 2 agents buys nothing that touches a blocker.

**7/10 is the best of four runs of the same ten rules, not the expectation.** Pooled across those
four seed runs the pipeline matched **23 of 40 ≈ 0.58**, with a 95% interval of roughly
**[0.40, 0.89]**. The per-run scores were 4/10, 6/10, 6/10 (Opus), 7/10; a ten-rule pass on rule-website
text scored 6/10.

**The composition is three genuine failures, not two failures and a better idea.** This correction
matters, because the first reading of the gate recorded one of the three as a defensible divergence:

- **`SA_661` — input-caused.** The driver fed the agent the Optolith seed text, which states the
  bonus on a different target than the rule website's page does. A text saying one target cannot
  yield the other under any brief. The golden file (`specs/rules/SA_661.yaml`) encodes the page's
  reading, per ADR-0007, and its note records the disagreement.
- **`SA_62` — input-caused.** The seed text lacks a clause the live page carries, so the golden's
  row for it is unreachable from the input the agents were given. This run's proposal also failed
  lint and was never written.
- **`SA_41` — a real pipeline error, not attributable to the input.** Three grounds:
  (a) it invents `parameter: armor.beColumn`, and `parameterOverride.parameter` is the one open
  string field nothing validates, so an invented constant lints clean and encodes to a silent no-op
  where the brief's `UNENCODED:` escape hatch was mandated; (b) `schema.json` defines `shiftSteps`
  as scaled by the effect's tier, so the proposal's `2 @ tier 1 / 4 @ tier 2` shifts eight steps at
  Stufe II; (c) it fails on rule-website text too. The golden corpus does **not** need revisiting —
  compare `specs/rules/SA_41.yaml` against `tests/rules/calibration/2026-09-21-sonnet/SA_41.yaml`.

**`SA_661`'s next verdict is not comparable to its recorded one, and the recorded one still stands
(Task 11a, 2026-09-21).** The whole-branch review's §6 found that `specs/rules/CHAP_Reiterkampf.yaml`
encodes the same clause `SA_661` modifies — same `type`, `target`, `scope`, `side`, value and gate —
and that the workspace handed it to the agents, because it carries neither `SA_661` nor its German
ability name and so redaction could not see it. Two facts qualify what that means for the number
above, and they point in opposite directions:

- **The recorded run was not exposed to it.** The chapter file landed six commits *after* the
  calibration run was recorded (`78802fb` after `505c721`), so it was not in the workspace the run
  used. `SA_661`'s recorded Tier 1 verdict is also `false`, and a leak channel can only move a
  verdict toward the golden file. The 7/10 is therefore not overstated by this channel, and §6's
  wording — "`SA_661`'s current Tier 1 pass may rest on this channel" — is wrong on both counts:
  it was not a pass, and the channel post-dated it. **§6 now carries a dated correction saying so
  at source (Task 11a fix round 1); its text and its ruling are unchanged, because only that
  sentence of evidence fails — the generalisation it supports is sound and a second instance has
  since been found.**
- **Every run from today would have been exposed to it.** `expected: SA_661: false` in
  `tests/rules/calibration/2026-09-21-sonnet/RUN.yaml` is a gate booleans anyone re-measuring will
  compare against, and the next run could have flipped it to `true` for a reason that is not the
  pipeline's judgment — an improvement nobody could attribute. That is what Task 11a removes: the
  workspace now withholds the chapter file alongside `SA_661` (`scripts/rules_sync/rule_graph.py`),
  and the run reports which files it withheld for which rule.

So: no recorded number changes, and any *future* `SA_661` result is measured under a materially
thinner workspace than the recorded one — see §2 for what "thinner" costs, by rule.

The gate's own headline finding is that **the driver feeds agents `rules_i18n.description` from
`rules.db` — the Optolith seed — while ADR-0007 makes the rule website normative and the golden ten
were authored from it.** Where the two disagree the pipeline is confidently wrong, and the second
agent, reading the same input, agrees: the two-agent design detects *independent* error and is
structurally blind to a bad shared input. Both agent briefs also asserted "the text you are given is
the rule website's", which was never true; that sentence is gone.

This is not new scope. ADR-0007's Decision already demotes Optolith to a seed that after bootstrap
"is authoritative for neither text nor mechanics" and specifies reconciliation as *fetch the page and
normalise it*, then *propose*. The driver substituted the seed for the first step's output. It is an
unbuilt half of an accepted ADR, tracked as Task 10.

## 2. The grading rubric, and why byte equality now means contamination

The rubric was fixed **before** the run, deliberately, because a threshold set after seeing results
is not a gate. It lives in `tests/rules/test_calibration.py` (`TIER1_FIELDS`).

- **Tier 1 — must match, and is the score.** Every non-reminder effect row, compared field by field
  on what the rule *does*: `type`, `tier`, `when` (order-insensitive; the schema ANDs it),
  `stacks`, `target`, `scope`, `side`, `value`, `parameter`, `set`, `shiftSteps`, `scale`, `add`
  (whitespace-normalised), `recipient`, `grants`, `forbids`, `skill`, `state`, `level`, `action`,
  `attribute`, `operation`, `per`. Fields equal to their schema default are dropped before
  comparison, so an explicitly-written default is not a difference.
- **Tier 2 — reported with judgment, never an auto-fail.** Whether a clause became a `reminder` row
  or an `UNENCODED:` root note, note wording, effect ordering, `excludes`.

**The plan's Task 7 originally said "reproduces the hand-authored effect rows for all ten". Read that
with this beside it: byte equality with the golden files is now EVIDENCE OF CONTAMINATION, not
success.** Task 6 found this end-to-end, not in theory: with the repository as cwd and file tools
enabled, both agents read `specs/rules/SA_65.yaml` and returned the hand-authored file byte-identical,
notes and all. "Agreement" measured nothing and the gate would have certified a copy. The fix is a
sanitised per-run workspace that withholds the authored file for every rule in the run and redacts
every remaining mention of those rules — **by German ability name as well as by id**, since a name
identifies a rule to a model with DSA training knowledge as precisely as an id does. A genuine run
therefore *diverges* from the golden notes, and the grader must expect that.

**Two residual leaks were on record from the Task 6 audit. That count was wrong by the end of the
branch, and is corrected here (whole-branch review, finding 1).** The two below are still there and
are still accepted. What the audit could not have seen is that the branch's *final documentation
commits* then added ten more passages — ADR prose stating graded rows outright, in schema field
names, as a tier ladder, as a quoted opponent-side display value and as a `dice` row's recipient in
English, for four of the ten golden rules and for the chapter rule besides. None of them carried a
rule id or a German ability name, so redaction passed over every one, and so did the workspace test,
which greps for exactly those two tokens. The review named six of the ten; the other four surfaced
when the guard below was written. All ten are reworded (2026-09-21) and
`tests/rules/test_workspace_leaks.py` now builds the workspace and reads it back for four shapes an
encoding has actually been restated in. Read that module's docstring before trusting it: it is a
ratchet against shapes already seen, and a leak paraphrased into prose that shares no tokens with
the encoding still defeats it.

- Redaction removes the identifying token, not the sentence. `AGENTS.md` still carries an
  unattributed mechanical statement next to a `a withheld rule` placeholder. Dropping whole
  sentences would gut the reference material.
- `docs/adr/0008-rules-as-data-combat-engine.md`'s `CheckDomain` consequence survives redaction as a
  sentence naming the stats `SA_41`'s row reaches, and that golden file's own note cites that
  paragraph as its reason for `scope: all`. This is the closer call of the two. No observed effect:
  `SA_41` diverged on a different axis entirely and no run ever produced the shape the leak would
  suggest.

**A third leak channel is now closed rather than accepted: graph adjacency (Task 11a, 2026-09-21).**
The two above are sentences that survive redaction. This one is a *file* that survives withholding:
a different authored rule encoding the same mechanic as a graded one is that rule's answer key while
carrying neither its id nor its German name, so neither removing the graded file nor redacting its
two tokens reaches it. `specs/rules/CHAP_Reiterkampf.yaml` ↔ `SA_661` is the instance the
whole-branch review recorded as its §6; the class generalises, and grows as the corpus goes from 28
files toward 232. `prepare_workspace` now withholds the **transitive closure** of the run's rules
over four edges computed from the corpus itself — `excludes` (undirected); a shared
`parameterOverride.parameter` path; a non-reminder effect row agreeing on every axis Tier 1 grades a
row's shape by (`type`, `target`, `scope`, `side`), where `scope` collides by **subsumption** as well
as equality because `all` is a domain filter covering `combat` rather than a different label; and two
non-reminder rows gated on the same `when` predicate. There is deliberately **no declared
`related:`/`modifies:` schema field**: the adjacency that leaked is exactly the kind nobody spots,
so an edge depending on an author spotting it inherits the defect. See
`scripts/rules_sync/rule_graph.py`, and the run's own `WITHHELD.md` artefact, which names what was
withheld for which rule under which edge — without it a later reader cannot tell "this rule had no
neighbour" from "the graph missed it".

The last two of those four came from fix round 1, each after the first three were measured against
the corpus and found to leave a live channel standing:

- **`scope` subsumption.** `SA_41` carries the corpus's only `modifier target: be scope: all` row and
  `CHAP_Reiterkampf` its only `modifier target: be scope: combat` row. Under exact equality the
  second stayed in the first's workspace — a worked `modifier target: be` row in front of the rule
  whose recorded failure is that it invented a `parameterOverride` path instead of one, and the only
  golden rule that has never passed in five runs. `target: all` was measured and deliberately **not**
  widened the same way: it links every modifier row to every other and takes the batch to 22 of 28.
- **`when`-predicate identity.** `SA_43`'s entire encoding is one axis-less `legality` row plus one
  predicate, so the first three edges found it no neighbour at all, while a chapter file carrying
  that same gate on every one of its rows — and naming `SA_43` in two notes, so redaction rewrites
  them and leaves the mechanical half standing — sat in its workspace. `SA_43` is the source of the
  2-of-5 gate-dropping datum Task 11 exists to quantify.

**What the closure costs the next measurement, and it is not small.** Over the ten golden rules run
as one batch (the recorded command), it withholds **18 of the 28** authored files rather than 10:
`CHAP_Reiterkampf`, `COND_1`, `COND_2`, `COND_4`, `COND_5`, `COND_6`, `COND_7` and `DISADV_34` join
the ten. Run rule-by-rule instead, `SA_40` and `SA_59` have no neighbour under any edge and withhold
1 file as before; the other eight withhold **16** each. Pinned by
`tests/rules/test_rule_graph.py::test_the_ten_rule_batch_withholds_exactly_the_documented_set` and
its per-rule companion, so an edge change cannot silently rewrite this arithmetic.

**What leaves with them is every `scope: combat` modifier row in the corpus**, checked rather than
asserted (`test_no_surviving_file_carries_a_combat_scoped_modifier_row`). The batch workspace is left
with ten authored files carrying eight distinct non-reminder row shapes, none of them combat:
`modifier` on `le/derived`, `painLevel/all`, `talent/socialTalents`, `Gassenwissen/all`,
`Orientierung/all`, plus `parameterOverride`, `recovery` and `stateGain`.

**Which rules lose all worked precedent? Nine of the ten in the batch, seven of the ten run
rule-by-rule — and the difference between those two numbers is the main thing the choice of
configuration turns on.** Counting non-reminder row shapes, and naming the baseline each figure is
measured against:

| | rules with **no** surviving example of **any** shape they must produce |
|---|---|
| **batch**, closure applied | **9** — all but `SA_59`, which keeps `parameterOverride` and loses `dice` |
| **rule-by-rule**, closure applied | **7** — `SA_40`, `SA_41`, `SA_43`, `SA_48`, `SA_65`, `SA_66`, `SA_661` |

The three rules the per-rule configuration spares are `SA_59`, `SA_62` and `SA_67`, and they spare
each other: run alone, each of the three leaves the other two in the workspace, and `dice` is the
shape all three share. Batch them and all three are graded at once, so the shape goes with them. That
is the *only* precedent difference between the two configurations — every other surviving shape is
identical — and it is worth stating plainly because the plan asks Task 11 to choose between them.

Of the nine in the batch row, **six** (`SA_40`, `SA_41`, `SA_43`, `SA_48`, `SA_62`, `SA_67`) were
already partly or wholly in that position under the old rule measured the same way — i.e. the batch
withholding only the ten. Three were not: `SA_65`, `SA_66` and `SA_661`. (On the per-rule-old
baseline the same count is four, `SA_40`/`SA_41`/`SA_43`/`SA_48`; the two baselines differ and a
figure quoted without one is not a figure.) Pinned by
`tests/rules/test_rule_graph.py::test_the_two_configurations_leave_the_documented_precedent`.

Two consequences the stability write-up must carry rather than discover:

- **No rule's next number is comparable to its recorded verdict.** The recorded run withheld exactly
  the ten; the batch now withholds eighteen, so every rule sees eight fewer precedent files than the
  run that produced the 7/10. A drop is not evidence of regression — it is the leak being removed —
  and per-rule hit rates must be reported as a new baseline, not as a delta.
- **It is measuring a harder question than the recorded run did**: "can the pipeline encode this rule
  from its text with no worked example of the row shape in front of it". That is the honest question
  once neighbours are recognised as answer keys, and it is the one the corpus can support today. It
  is not the same question the 7/10 answered, and an aggregate across the two would be meaningless.

## 3. The five blockers on any 222-rule wave

All five are open. Blocker 1 has had half of its machinery built (Task 10) and is still open — read its
entry for which half. None is an authoring agent's to work around; they are a human's to close.

1. **Resolve each rule's text from its `source.url`, not from `rules.db`.** **Resolution built;
   backfill and driver change still open — this blocker is NOT closed.** Necessary, and **not
   demonstrated sufficient**: the ten-rule pass on rule-website text scored 6/10, *below* the seed
   run, so having the URL is a precondition for the fix, not the fix.

   *What is now done.* `make rules-resolve` (Task 10, `scripts/rules_sync/resolve.py`) resolves each
   combat rule to its page from the site's own category indexes, by anchor text and `href`, never
   from a rule id. Live run over combat groups 3, 9, 10, 11 and 12: 232 rules, **201 resolved, 26
   needs-review, 5 unresolved, 0 ambiguous**, and the ten golden rules resolve to exactly the URLs
   their authored files already record (10/10). The map reaches the untracked `rules.db` as a
   `rules.source_url` column.

   *What is still open, and why this blocker stays open.* Three things. **(a)** The 31 rules the
   resolver reported rather than confirmed need a human: an unresolved rule has no URL, and a
   needs-review rule has one whose identity signals did not all agree. **(b)** No authored file was
   rewritten. Resolving a URL and *authoring provenance* are different acts — a `source.hash` is a
   claim that a specific page was fetched and normalised, and ADR-0007's second 2026-09-21 amendment
   gives that to the driver — so the 17 `UNVERIFIED` files still say `unverified` and
   `make rules-sync-check` still reports them that way. **(c)** `propose.py` still hands the agents
   `rules_i18n.description`. Until it fetches `source_url` and normalises it, the gate's headline
   finding stands unaddressed, and the URL being available changes nothing on its own.
2. **Register `parameterOverride.parameter` paths in `specs/rules/vocabulary.yaml` and lint them**,
   the way `grants`, `forbids`, `legality.action` and `gmFlag` already are. It is currently a free
   string that nothing validates. It produced both a false disagreement and `SA_41`'s invented
   `armor.beColumn`. Both briefs now warn about it; a brief is not a validator.
3. **Budget a vocabulary round per wave.** One of ten proposals was rejected for an unregistered
   `grants` token. That is the linter working as designed, but it needs a human in the loop before
   the YAML can be written at all.
4. **Measure per-rule stability first.** Added in Task 7's fix round and the reason the other four
   cannot yet be evaluated: at a pooled 0.58 with a [0.40, 0.89] interval, a ten-rule gate cannot
   attribute a one-or-two-rule fix, cannot distinguish 6 from 8, and cannot certify what it is being
   asked to certify. Repeating the same configuration costs ~11 calls a pass against a wave of ~450.
   Plan Task 11.
5. **Do not pay for Opus.** Measured on identical inputs it scored the same Tier 1; neither the score
   nor the agreement rate justifies the cost across 222 rules × 2 agents, and neither touches a
   blocker.

Projection at p = 0.6–0.7 over 222 rules: roughly **65–90 wrong encodings, the majority arriving as
`agree / ok / written`**. A wave is a **review queue, not an authoring pass** — every proposal needs
a human against the rule's own page, and re-running a rule that looks wrong is legitimate and cheap.

## 4. `SA_43` — the variance datum

`specs/rules/SA_43.yaml` is the simplest rule in the corpus: one `legality` row, one predicate. It
**dropped its `when: [{mounted: true}]` gate in 2 of 5 passes on identical input**, with no change to
either brief between them.

An unconditional legality row unlocks mounted-combat actions for a hero on foot. That is ADR-0008's
named failure mode — a conditional bonus silently becoming unconditional — and it is invisible twice
over: `make rules-lint` cannot see it (the file is valid either way), and the author/verifier
cross-check cannot see it when both agents drop the gate, which is what happened.

If the simplest rule in the corpus is a coin flip on a precondition, the review burden on 222 is not
"read the ones that disagree". This datum is why blocker 4 exists, and why Task 11's acceptance
criteria require every rule that *ever* loses a `when` predicate across passes to be named.

Four rules were stable across all passes (`SA_40`, `SA_65`, `SA_66` always passed; `SA_41` never
did). The other six moved.

## 5. Two live bugs, found and fixed — and how they were found

The method is the reusable part: **both were found by comparing the authored corpus against the Swift
that implements the same rule.** Nothing automated compares them. The data-driven path is dead code
(ADR-0008), so an authored file and a wrong constant can sit beside each other indefinitely without
contradicting each other — which is exactly what happened in the first case, for months.

**Doubled Belastungsgewöhnung relief — `3c3ff91`.** Found while recording real provenance for the
golden ten (Task 4): the rule's own worked example on its page proves a reduction of 1 per Stufe, and
`specs/rules/SA_41.yaml` had the correct ladder the whole time, while `Hero.effectiveBE` computed
`totalEquippedBE - 2 * belastungsgewoehnungLevel`. The doc comment asserted the wrong number too.
Every hero with the ability had double relief at both tiers, flowing through `belastungPenalty` into
AT, PA, AW, INI and GS. It was surfaced to the user and **not fixed unilaterally**, because it changes
numbers at the table; the fix landed on authorisation with 4 tests against the page's worked example.
No existing test or sample hero had encoded the old behaviour — which is why nothing caught it.

**Species-blind GS — `f276b14` (Task 13 in the plan).** Found while enumerating the derived-value
rules for Task 12: `OptolithImportService.swift:888` was `ResourceValue(base: 8, bonus: 0, max: 8)`,
commented as the human base. GS is keyed on species; the pinned Optolith source carries `mov` per
race and **dwarves are 6**, every other race in the source is 8. Every dwarf hero was two Schritt too
fast. Same discipline: blast radius investigated first, fix on the user's authorisation, not as a side
effect of authoring. The table now lives in `DerivedValueFormulas.geschwindigkeit(speciesId:)`;
unknown species returns `nil` and the import and the repair make *different* deliberate choices for
it. The corpus half is still open — GS has no rule to cite, which is Task 12's derived-value work.

Both are in `CHANGELOG.md` under `[Unreleased]` → `Fixed`, with the full blast radius.

## 6. Open questions awaiting the user

Each of these is a ruling, not a task. They are stated so they can be answered without the branch's
conversation.

**(a) Ruleset versioning — deferred, with a worked example.** ADR-0009 decides "sets now, versions
later": one current text per rule, with `book`/`page`/`checked`/`hash` recording which printing it was
verified against. The worked example of what that defers is `SA_62`: the Optolith seed says page 249,
the live page says 250 and carries two cap clauses the seed lacks. ADR-0007 makes the page normative,
so the authored file records 250 and the seed's 249 is simply stale — a stale page number and a stale
text are the same staleness. Under a versioning scheme the file would instead record *two* printings,
which one each clause belongs to, and which printing a table plays under, and every rule would carry
that dimension forever. Reversible: a version dimension would extend `ruleset` and the `source` block
rather than replace them. **Nothing needs deciding until a group deliberately plays an older
printing.**

**(b) ~~The `golgaritenActive` gate on the *baseline* advantageous position.~~ ANSWERED — the user
authorised the fix, which landed in `6df4d21`.** Kept here because the reasoning is the clearest
worked example of what this corpus is for. `MeleeModifiers` held two `+2 AT` definitions, both
guarded by `golgaritenActive(mounted:)` — which demands `SA_661` *plus* a Rabenschnabel *plus* a
Großschild. Reading both source pages together settled it: `CHAP_Reiterkampf` clause 2 grants the
advantageous position to **every** mounted hero facing someone on foot, while `SA_661` clause 1
*raises* the AT ease that the advantageous position already confers, rather than granting one of its
own — it raises an ease that already exists, so it cannot be the thing being raised. The arithmetic (+2
baseline plus +2 style = +4) was right; the gating was wrong **in both directions**: a rider without
the style got nothing automatic, and a Golgarite against *another rider* was handed +4 that no rule
grants. `ModifierContext` gained an `opponentOnFoot` GM flag on the `targetIsSurprised` pattern
(ADR-0005) — a name both authored files had already used, before anyone looked at the Swift. Neither
page alone would have shown the bug.

**(c) `rules.title` versus `rules_i18n.name` for chapter-rule display — settle before the engine
reads it.** ADR-0009 says a chapter rule's page title goes in "the chapter rule's `rules` row as its
name", and `scripts/build_rules_db/build_db.py:852` writes it to a `rules.title` column. But
`Hesindion/Services/RulesDatabase.swift` INNER JOINs `rules_i18n` on all three of its lookups, so a
chapter id returns `nil` and `RuleDetailView` is never reached. A consumer that looks names up in
`rules_i18n` will find nothing for a chapter id and must know to fall back to `rules.title`. Deciding
which column is "the name" is cheap now and expensive once the engine and the breakdown UI both read
it.

**(d) `CombatDefenseViews` reads `geschwindigkeit.max` raw.** `CombatDefenseViews.swift:855` renders
the flight outcome from `hero.derivedValues?.geschwindigkeit.max` with no penalty applied, while
`HeroDetailView.swift:545-546` shows the same value with `Hero.totalGsPenalty`
(`belastungPenalty + armorGsModifier`) beside it. Pre-existing and unrelated to the GS fix; noticed
while measuring that fix's blast radius and deliberately left alone, because it is a second
table-number question. Either the flight figures should carry the penalty or the two views are
answering different questions on purpose — nobody has decided which.

## 7. Deferred minors

Parked for a final review pass that has not happened. Each was judged real but not worth interrupting
the task that found it. Verified against the tree as of `f276b14`; the four that have since been
closed are marked so and left visible rather than deleted.

**Corpus and tooling**

- *(closed)* `NON_RULE_FILES` exists in **four** hand-synced copies with two spellings:
  `scripts/rules_lint/lint.py:29`, `scripts/rules_sync/check.py:84` (which additionally lists
  `schema.json`), `scripts/build_rules_db/verify_db.py:21`, and `build_db.py:810` as a local
  lowercase `non_rule_files`. A file added to one and not the others is a silent skip.
  `build_db.py`'s copy is now a module-level `NON_RULE_FILES` matching the other three's spelling,
  the cross-reference comments name all four sites, and `tests/rules/test_shared_constants.py`
  asserts the stated relationship (three equal; `check.py` equal plus `schema.json`) and fails if
  a site is missed.
- The linter's glob is non-recursive (`glob("*.yaml")`, `lint.py:389`) — a rule file in a
  subdirectory of `specs/rules/` is silently unlinted.
- Duplicate YAML keys are last-wins and unreported.
- `subgroup` NULL policy is undocumented.
- The `oneOf` schema error message is unhelpful when it fires.
- The `dice.add` quoting discipline is manual — the authoring-time representer script was specified
  and never committed.
- *(closed)* `rules-lint` absent from `AGENTS.md` — it is documented there now.
- *(closed)* No `$defs` in `schema.json` — it has five.

**Normalisation**

- A content container holding only invisible non-whitespace characters (zero-width space, soft
  hyphen) bypasses `normalise.py`'s emptiness guard and hashes a one-character string. It is *not*
  the identical-hash bug that `b616f48` fixed — each such page still gets its own hash — and it needs
  an editor to leave a bare ZWSP. Worth the triage for a second reason nobody raised: stripping
  format characters would also remove a false-drift source, since a soft hyphen added mid-word
  changes the hash without changing visible text.
- The block/inline tag list that `64d4128`/`b382892` established is not mentioned in the `CHANGELOG`
  feature bullet it belongs to.

**Authoring pipeline**

- **Rule text reaching the agents is untrusted input in a prompt.** Nothing treats it as
  instructions and the toolset is read-only, but no adversarial text was ever tried. See §8 for the
  standing decision this sits under.
- Parallelism was never exercised wider than one batch plus verifiers. The 12-rule batch cap is
  unexercised and rate limits at 12 rules × 2 agents are unmeasured.
- `--restricted`'s out-of-cwd denial is evidenced only by a live run, never by a constructed negative
  test.
- *(closed)* `exclude_names` wiring in `main()` has no end-to-end `FakeRunner` test; it is covered
  by `prepare_workspace` unit tests plus the live run. `main()` now takes a `runner_factory` seam,
  and `test_main_end_to_end_redacts_the_workspace_it_builds` (`tests/rules/test_propose.py`) drives
  `main()` end to end with a `FakeRunner` and asserts that neither the withheld rule's id nor its
  German name survives the workspace `main()` built — it fails if `exclude_names=[r.name for r in
  rules]` regresses to `[r.rule_id for r in rules]`.
- A failing model reply reaches `proposal.error` at up to 400 characters
  (`scripts/rules_sync/propose.py:645,654`) and may quote German. It reaches the terminal and the
  git-ignored review file only, so it is not a git leak.
- The prose leak guard has a **false positive on rule-website text**: a tier label in a note matched
  three consecutive words of a page title. The window-3 threshold was measured against seed text
  only, and page text is 2–5× longer with much more boilerplate. It fails *safe* (rejects rather than
  writes), and it is a one-line exclusion.
- Nothing tests the `chapter` category end-to-end in `build_db.py`. The Python suite builds no
  database at all, so a refactor of `import_effects` could reintroduce the silent skip that `c93105a`
  closed.

**Swift / tests**

- `HesindionTests/HeroImportTests.swift:62` retains a non-emptiness assertion that the two
  `contains`-assertions below it already imply.
- `AbilitySuccessRateSnapshotTests.testLogPanelWithSessionHeaders` failed once and passed on every
  run since. Investigated rather than labelled: the view reads no Belastung-derived number, so it
  cannot be a regression from `030230e`. **Deliberately not added to `AGENTS.md`'s known-flakes list
  on one observation** — labelling a real regression a flake is the expensive mistake. Add it if it
  recurs.

**Also open, not a minor:** 17 of 28 authored files still carry the `UNVERIFIED` placeholder URL and
the zero hash, so `make rules-sync-check` reports them `unverified`. Only the golden ten and
`CHAP_Reiterkampf` have real provenance.

## 8. Settled — do not re-derive these

Each of these was reached the hard way, and each has a shape that invites being re-litigated by
someone reading only the code.

**`SA_43`'s removed `-1 BE` row: the removal was right, the first reason was wrong.** The original
note claimed the clause existed on neither the rule website nor in the Optolith seed, and that no
Swift implemented it. Two of those three were false — the clause is on the mounted-combat chapter
page, and `Hesindion/Engine/SharedModifiers.swift` had implemented it all along. The reviewer had
checked only `SA_43`'s own call sites, and "no Swift implementation" was taken to mean "nowhere in
the app". **The removal stands for a better reason:** it is not that ability's effect at all, it is a
chapter rule binding any rider, and it now lives in `CHAP_Reiterkampf`. Corrected in `576d8b0`;
`SA_43` is a golden file, so a wrong reason there is a lesson taught at scale. This is also what
produced ADR-0007's and ADR-0008's 2026-09-21 amendments: a reviewer concludes "there is no clause"
when the corpus has no shape that could hold one.

**The same mistake repeated once more, on the page that corrects it.** `CHAP_Reiterkampf`'s clause 2
was first filed `UNENCODED:` as "reads off the mount, which is not a modelled entity" — true of the
clause it was bundled with, false of this one, which reads off the *opponent's* stance.
`specs/rules/SA_661.yaml` already encoded exactly that shape and the app had hardcoded it all along.
The page therefore contributes **three** hardcoded mechanics, not two; `9aef3d2` corrected the file,
the CHANGELOG and ADR-0008's amendment. A note that states a *reason* can be wrong even when the
encoding is right, and that is its own defect class.

**`SA_41` is a pipeline error, not a divergence where the pipeline chose better.** See §1. The first
reading took one `schema.json` sentence as endorsement of the pipeline's shape; the same sentence
contained the refutation. The score is 7/10 either way — `SA_41` was already counted as a failure —
but the composition is what the blockers are derived from.

**The "decisive experiment" on the input diagnosis was confounded.** A two-rule
`prepare_workspace` withholds only those two, leaving the other eight golden files and their German
names in the tree, and the batch size changed as well. The `excludes` win it appeared to produce came
from exactly that leak and is discarded. **The diagnosis survives deductively** — a seed text stating
one target cannot yield another, and a row is unreachable from a text without its clause, both
verified against the live pages — but it is corroboration, not proof, and the headline must not read
as "fix the input and the gate passes". The ten-rule pass on page text scored 6/10.

**The mounted Belastung relief is combat-scoped.** It had been applied in spell and liturgy casting.
User ruling: Kampf and Zaubern are neither the same nor related, so no non-combat action gets the
reduction. Settled in the data's favour, `030230e`, and recorded in ADR-0008's amendment. The
*unmounted* Belastung penalty still reaches all six domains and is unchanged.

**`SA_41`'s `scope: all` is not a settled answer.** Neither `combat` nor `all` can express what BE
reaches, because `CheckDomain` has no domain for INI or GS at all: `combat` under-covers and `all`
over-covers into spell and liturgy casting. The path is dead code today, so there is no live effect.
Recorded in ADR-0008's Consequences as a binding input to the engine plan rather than settled by
picking a string. Do not "fix" it by changing the scope value.

**The golden corpus is frozen by hash, and note-only edits have a mechanical carve-out.**
`tests/rules/golden/MANIFEST.yaml` holds two hashes per rule: the whole file, and a `graded` hash over
the file reduced to `TIER1_FIELDS` on its non-reminder rows. A genuinely note-only edit provably
cannot move the second; a mechanical edit moves it even with a refreshed byte hash and a plausible
`golden_edits` entry in `tests/rules/calibration/2026-09-21-sonnet/RUN.yaml`. Two carve-outs are on
record (the `ruleset` backfill and `SA_43`'s note), both argued in `RUN.yaml` and both pinned by
`test_ruleset_is_outside_what_tier_1_grades`. **The dangerous reading is "call it note-only and skip
the gate"** — the limit is written into the manifest's description and the test's remedy string for
that reason. If `TIER1_FIELDS` ever gains `note`, both carve-outs become wrong and must be deleted
with their `golden_edits` entries; nothing enforces that coupling.

**The two-agent design has no defence against a shared-input attack, and the mitigation is a prompt
instruction, not a mechanism.** Exfiltration risk is low (read-only tools, git-ignored output, closed
schema); integrity risk is medium. Rule text is fenced and declared untrusted in both prompts and
both briefs, and `parse_agent_output` keeps the first envelope per id so an injected marker cannot
re-open a resolved one. That is the accepted position, recorded in ADR-0007's 2026-09-21 amendment —
worth remembering at wave scale rather than rediscovering.

**The linter cannot catch prose in a free-form string field**, and this is documented rather than
fixed: `dice.add`, `actionEconomy.grants`/`forbids`, `parameter`, `skill`, `state`, `action`,
`attribute` cannot be distinguished from a sentence by shape alone. Authors and reviewers are the
backstop, plus `propose.py`'s shingle guard for anything the pipeline writes. See `AGENTS.md`'s Data
Policy.

**The model knows DSA 5, and no workspace can change that.** In one diagnostic an agent resolved a
German ability name to a rule id with that rule withheld and redacted from its entire workspace. The
counter-evidence is stronger than the worry, though: fed the stale seed text, the same model encoded
the stale value rather than the one both the page and the golden carry. **It encodes its input** —
which is why blocker 1 is blocker 1.

## 9. Resuming cold

```bash
make rules-lint                       # 28 rule file(s), 0 error(s)
make rules-db                         # first: rules-resolve reads names and seed text out of it
make rules-resolve                    # network; arms two guards the suite otherwise skips (see below)
make rules-db                         # again, so the resolution reaches rules.source_url
python3 -m pytest tests/ -q           # 416 passed (includes 2 live tests, network)
python3 -m pytest tests/ -q -m "not live"   # 414 passed, 2 deselected (offline)
make rules-db-verify
make rules-sync-check                 # network; 11 ok, 17 unverified
```

**The `rules-db → rules-resolve → rules-db` order is not a preference.** `resolve.load_targets`
raises `FileNotFoundError` when `rules.db` is absent, so a cold clone that runs `make rules-resolve`
first aborts at step 2 and the two guards below stay unarmed — the silent skip this section exists
to close. The dependency is circular by one step and the `Makefile` says so above the
`rules-resolve` target; `AGENTS.md` carries the same order.

**`make rules-resolve` must run before `pytest` for the resolver's two guards to mean anything.**
Task 10's closed-loop test and `verify_db.py`'s `check_resolution_reached_the_db` both **skip** when
`.cache/rules_resolve/resolved_urls.json` is absent — which is every fresh clone and every CI run,
since nothing chains the two. The Data Policy forbids committing the map (it carries ability names),
so the skip is correct behaviour; what was missing is anybody being told to arm them. A green suite
on a cold clone is therefore two guards short, and says so nowhere else.

`tests/rules/test_normalise_live.py` is marked `live` (whole-branch review, finding 11):
it fetches the rule website three times and is the only thing that makes the full-suite
count network-dependent. `-m "not live"` deselects it for a cold, offline resume.

Then read, in this order: this file, `docs/plans/2026-09-20-rules-pipeline-and-authoring.md` for what
is done and what is left, and ADR-0007/0008/0009 for why. `CHANGELOG.md` under `[Unreleased]` carries
the evidence for every claim above.

The next piece of work is **Task 10** (resolve every rule to its page by name) followed by **Task 11**
(measure per-rule stability). Task 12 (the rules the app hardcodes) is authoring work that does not
depend on the gate. **No authoring wave starts before blockers 1–4 close.**
