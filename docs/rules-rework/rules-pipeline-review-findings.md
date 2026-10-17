# Rules Pipeline — Whole-Branch Review Findings

**Branch `feat/rules-data-pipeline`, reviewed at `7b1b15d` against `main` at `487ce37`.**
46 commits, 108 files, +11,638/−480. Review date 2026-09-21.

This is the final whole-branch review, run after every individual task had already been reviewed
and its findings fixed. It therefore looks for what per-task review cannot see: interactions
between tasks, drift across the branch, things that were right when written and wrong by the end,
and inconsistencies the accumulated rulings left behind.

No DSA rule prose appears in this document. Clauses are named by their position (page, clause
number) and by the mechanism they encode, never by their text — see the Data Policy in `AGENTS.md`,
and finding 2, which is about exactly that rule.

Orienting reading, if you have not seen this branch: `docs/rules-rework/rules-pipeline-status.md` (§1, §6, §7,
§8), `docs/rules-rework/2026-09-20-rules-pipeline-and-authoring.md`, ADRs `0012`/`0013`/`0014`, `AGENTS.md`.

---

## 1. Merge recommendation

**Merge after fixing 2 named items: finding 1 and finding 2.**

Everything else on the list below can be filed and scheduled. The two blockers are both small, both
mechanical, and both are cases where the branch broke one of its own binding constraints in its
final documentation commits — after the measurement or the audit that would have caught them.

- **Finding 1** is the more expensive one to leave. Documentation added at the end of the branch
  now states the graded answers for at least four of the ten golden rules, inside files that
  `prepare_workspace` copies into the agents' sanitised workspace. The next calibration run would
  measure contamination and could easily report a *better* score than 7/10 for exactly the reason
  the branch declares disqualifying. Left unfixed, the gate stops being a gate.
- **Finding 2** is verbatim German rule prose committed to `CHANGELOG.md`, to
  `docs/rules-rework/rules-pipeline-status.md` — in a file that opens by asserting it contains none — and to
  `docs/adr/0013`. The Data Policy in `AGENTS.md` names documentation explicitly, and
  `propose.py`'s own leak guard rejects three consecutive words of source text. These are four to
  twelve words each. The fix is to paraphrase; no code moves.

Neither blocker touches the Swift the app ships, and none of the three authorised behaviour changes
is wrong. **The branch's engineering is genuinely strong** — see §5 for what I checked and found
clean. The two blockers are both "the document says the opposite of what the document does", which
is precisely the class that survives per-task review, because neither document existed in its final
form while any task was being reviewed.

A note on what merging does and does not buy, since the plan's claim was asked to be tested rather
than assumed: **the claim that the Swift half is a separate plan holds, and the corpus's guarantees
are prospective, not live.** `Hesindion/Engine/RuleEffectModifiers.swift` is unchanged by this
branch and still has no callers (`grep -rn RuleEffectModifiers Hesindion/` finds only its own
definition). `make rules-db` writes 109 authored effect rows into `rules.db` and nothing reads them.
What this branch delivers *today* is: one authoritative place to author a rule, a linter and a
schema over it, a deterministic drift check that works (11 ok, 0 drifted), an honest measurement
that the LLM half is not ready, and three rule bugs found by hand-comparing corpus against Swift.
That is real value and it is correctly scoped. But no guarantee in ADR-0013 about the *engine* is
enforced by anything that runs today, and finding 4 shows the "one authority" property is already
violated between two live Swift readings of the same `scope` token.

---

## 2. Findings, most severe first

### Finding 1 — Documentation added after the leak audit now hands agents the golden answers

**Severity: blocker for merge.** *Closed 2026-09-21 — ten passages reworded (four more than the six
listed below), plus `tests/rules/test_workspace_leaks.py`. See `CHANGELOG.md` under `[Unreleased]`,
`docs/rules-rework/rules-pipeline-status.md` §2, and the dated notes in ADR-0013 and ADR-0014.*

**Where:**
- `docs/adr/0014-rule-provenance-and-rule-sets.md:13` — states `SA_41`'s complete tier ladder as a
  parenthetical pair of numbers.
- `docs/adr/0013-rules-as-data-combat-engine.md:192-196` — states `SA_661`'s encoded row in full:
  effect type, target, scope, value, and both `when` predicates including the `gmFlag` slug.
- `docs/adr/0013-rules-as-data-combat-engine.md:61` — states `SA_48`'s Stufe II opponent-side value
  as a quoted German display string.
- `docs/adr/0013-rules-as-data-combat-engine.md:64` — states `SA_59`'s `dice.recipient`.
- `docs/adr/0013-rules-as-data-combat-engine.md:125` — states the mounted BE row's value and gate.
- `docs/adr/0014-rule-provenance-and-rule-sets.md:15` — states `CHAP_Reiterkampf` clause 6's value.

`SA_41`, `SA_661`, `SA_48` and `SA_59` are four of the ten golden rules the calibration grades.

**Why it reaches the agents:** `scripts/rules_sync/propose.py:459-461` copies **every** file under
`docs/adr/` into the sanitised workspace. Redaction (`_redact_references`, `propose.py:386-411`)
removes the rule *id* and the German *name* and nothing else — as
`docs/rules-rework/rules-pipeline-status.md` §2 itself says, "redaction removes the identifying token, not the
sentence". An encoded row stated in schema field names carries neither token, so it survives intact.

**Concrete failure scenario.** Someone closes blocker 1 (resolve rule text from `source.url`) and
re-runs the calibration over the same ten rules, as Task 10/11 schedule. `rule-author` greps its
workspace for precedent, finds `docs/adr/0013-rules-as-data-combat-engine.md`, and reads a sentence
giving `SA_661`'s exact Tier 1 row. It emits that row. `rule-verifier`, reading the same workspace,
does the same. The run reports *agreement*, the grader scores it *pass*, and the gate moves from
7/10 to 8/10 or better. The improvement is attributed to the input fix. It is a copy — which this
branch's own rubric (`tests/rules/test_calibration.py:12-16`,
`docs/rules-rework/rules-pipeline-status.md` §2) calls **evidence of contamination, not success** — and there is
no mechanism left that would say so, because the mechanism that caught it last time was byte
equality with the golden *notes*, and an ADR paragraph does not supply those.

`SA_41` is the sharpest case: it is the one golden rule that has *never* passed in five runs, and
its failure is one of the three the five blockers are derived from. ADR-0014:13 now gives it away.

**Why per-task review could not see it.** ADR-0014 did not exist and ADR-0013's 2026-09-21
amendments were not written when the Task 6 leak audit ran. That audit recorded exactly two residual
leaks (`AGENTS.md`'s unattributed Belastung sentence, and ADR-0013's `CheckDomain` paragraph) and
judged both acceptable. Both are still there and both are still acceptable. What is new is that the
branch then added six more, all of them strictly worse than the two that were judged, because these
state encodings rather than mechanics in prose.

**What fixing it involves.** Two options, in order of preference:

1. **Rewrite the six sentences** so they cite the rule file rather than restate its contents
   (`see specs/rules/SA_661.yaml`, which the workspace withholds). Cheapest, no code, and it keeps
   the ADRs readable by humans who have the repo.
2. **Extend the guard mechanically.** `ids_named_in_agent_briefs` (`propose.py:475`) already exists
   to catch what a workspace cannot. A sibling check that greps the *workspace as built* for the
   golden files' graded field/value pairs would turn "we redacted the names" into "we verified no
   answer survived". This is the durable fix and is worth scheduling regardless of (1), because
   nothing currently stops the seventh instance being written next month.

Update `docs/rules-rework/rules-pipeline-status.md` §2's residual-leak list either way — its "two residual leaks
are on record" is now wrong, and a future reader trusting it will not go looking.

---

### Finding 2 — Verbatim German rule prose is committed, in files that claim it is not

**Severity: blocker for merge.** *Closed 2026-09-21 — all five sites below reworded, plus two the
review did not list (`CHANGELOG.md`'s open-vocabulary entry and `tests/rules/test_lint.py`'s
prose-in-`forbids` fixture). `docs/adr/0006:15` is still open, as this finding says it should be.*
Binding constraint: *no DSA rule prose in git, including YAML
comments, `note` fields, test fixtures and documentation.*

**Where:**
- `CHANGELOG.md:94` — a full clause of `SA_661`'s page quoted verbatim, twelve words, in quotation
  marks and italics.
- `docs/rules-rework/rules-pipeline-status.md:200` — the same clause, same quotation. This file's line 20 reads
  "No DSA rule prose appears here, per the Data Policy in `AGENTS.md`."
- `docs/adr/0013-rules-as-data-combat-engine.md:100-101` — two maneuver-exclusion clauses quoted
  verbatim, seven and eight words.
- `docs/adr/0013-rules-as-data-combat-engine.md:61` and `:66` — two shorter quoted German fragments
  of rule text.
- `scripts/rules_sync/propose.py:153` — a four-word verbatim fragment of seed text in a comment.

All are introduced by this branch. (`docs/adr/0006:15` carries a comparable quotation but is
pre-existing on `main`; out of scope here, worth a separate decision.)

**Why it matters, concretely.** The threshold is not mine, it is the branch's own:
`propose.py`'s `_find_text_leak` rejects any proposal in which **three consecutive words** of the
source text reappear. A twelve-word verbatim clause in `CHANGELOG.md` is four times the length that
the pipeline refuses to write into a YAML file. The linter does not cover `docs/` or `CHANGELOG.md`,
so nothing mechanical caught it — the constraint over documentation is enforced by authors only, and
here the author was writing the commit that *established* the ruling the quote supports.

The failure scenario is not subtle: this repository's stated position is that DSA rules content is
not distributable. A clause of a commercially published rulebook is committed, in German, with its
book and page cited two files away. Whatever the practical risk, the branch asserts a policy and
then does not keep it, in the document whose job is to be the policy's operational state.

**What fixing it involves.** Paraphrase each site in the register the rest of the branch already
uses — "clause 1 raises an existing situational ease rather than adding an independent bonus" is the
reasoning, carries the argument completely, and is already how `specs/rules/SA_661.yaml`'s own note
puts it. Five short edits, no code, no test changes. Optionally add a grep-based check over
`docs/**` and `CHANGELOG.md` to `make rules-lint`; that is a larger change and can be filed.

---

### Finding 3 — A fourth Swift behaviour change ships undeclared, and unlike the other three it has no repair pass

**Severity: important. File it, with a decision attached.**

**Where:** `Hesindion/Services/OptolithImportService.swift:464-467` (`isCombatSpecialAbility`),
landed in `5529a74`.

**What changed.** Classification moved from "the rule has a hand-authored effect with
`scope: combat`" to "the rule's Optolith group is one of 3, 9, 10, 11, 12". I built `rules.db` and
counted: the old rule matched **9** special abilities (the nine in the deleted
`specs/data/rules.yaml` under `combatAbilities`). The new rule matches **232**.

This is an improvement and it is the right rule — ADR-0013 argues it well, and the old predicate
was circular. Two shipped features were dead because of the old one and now work:
`Hero.hasPlaenklerFormation` (`SA_884`, group 3) and the Trefferzonen halving
(`SA_160`/`SA_161`, group 3) could never be true from a real import.

**The problem is the interaction with persistence.** `combatSpecialAbilities` is a stored property
on the `@Model Hero` (`Hesindion/Models/Hero.swift:11`), written once at import
(`OptolithImportService.swift:441-445`). A classification change therefore does not reach heroes
already in the store. After merge:

- a hero imported before the merge has `SA_884` and `SA_160` in `generalSpecialAbilities`, so
  Plänkler-Formation and the Trefferzonen halving stay dead for them, permanently;
- the same hero re-imported from the same JSON gets them in `combatSpecialAbilities` and behaves
  differently.

**The concrete failure scenario is the support one:** two players at the same table, same
character file, different numbers, and nothing in the app explains why. The branch's own discipline
for exactly this shape is `DerivedValueRepair` — ADR-0006 exists because "the import runs only at
import, so a fix does not reach heroes already in the store". The GS fix in this very branch added
a repair pass for that reason. This change did not, and it was never surfaced as a behaviour change
at all; it is not in the three that were authorised, and `CHANGELOG.md` files it under the
source-of-truth work rather than as a change to numbers at the table.

**What fixing it involves.** Either (a) add a reclassification pass beside
`DerivedValueRepair.repair` that re-splits `generalSpecialAbilities` / `combatSpecialAbilities`
through `rules.lookupGroupId`, which is idempotent by construction and needs no user data the hero
lacks; or (b) decide explicitly that re-import is the migration path and say so in `CHANGELOG.md`
and ADR-0013. (a) is maybe twenty lines and matches the precedent. Either way it needs to be a
decision rather than an omission.

**Positive note:** I verified no regression in the other direction. All nine previously-combat SAs
(`SA_40`, `41`, `43`, `48`, `59`, `65`, `66`, `67`, `661`) are in groups 3 or 9, so nothing that
used to be a combat SA stopped being one. `SA_41` in particular is group 3, so
`Hero.belastungsgewoehnungLevel` keeps working — worth stating because had it not been, the
Belastungsgewöhnung fix in `3c3ff91` would have been silently neutralised for every new import.

---

### Finding 4 — `scope: combat` has two different meanings in Swift, inside one branch

**Severity: important. File it — it is a live instance of the pattern ADR-0012 exists to remove.**

**Where:**
- `Hesindion/Engine/SharedModifiers.swift:6-11` — `mountedReliefDomains`, **new in this branch**,
  defines the combat domains as `{meleeAttack, meleeParry, meleeDodge, rangedAttack}` — four.
- `Hesindion/Engine/RuleEffectModifiers.swift:52` — `domainsForScope("combat")` returns
  `{meleeAttack, meleeParry, meleeDodge}` — three. **Ranged attack is missing.**

Both claim to implement the same authored token. `specs/rules/CHAP_Reiterkampf.yaml`'s BE row
carries `scope: combat` and is the row `SharedModifiers` implements.

**Why it matters.** ADR-0012's founding argument is "two authorities, no arbiter" — the bug the
branch was written to remove. The branch removed four competing sources of rule *mechanics* and then
introduced a second, disagreeing interpretation of a rule *vocabulary token*, in the same engine
directory, one file apart. It is invisible today only because `RuleEffectModifiers` is dead.

**Concrete failure scenario.** The engine plan wires `RuleEffectModifiers` up and deletes the
hand-written `SharedModifiers.encumbrance` as redundant. A mounted hero's ranged attacks silently
stop getting the BE relief the chapter rule grants them, and the diff that caused it looks like a
pure simplification. Nobody compares the two domain sets because nothing pairs them.

A second, larger hazard sits in the same place: **if `RuleEffectModifiers.load` were appended to the
engine registry as-is, every migrated rule would fire twice.** `ModifierEngine.swift:127-130`
registers the hand-written `SharedModifiers`/`MeleeModifiers`/`DefenseModifiers`, which implement
the same mechanics as the 109 authored effect rows the build now loads into `rules.db`. The branch
made the corpus the documented authority while leaving the double-count hazard undeclared anywhere
in the Swift.

**What fixing it involves.** Cheapest useful step: a comment at both sites naming the other, and a
line in ADR-0013's Consequences saying the engine wiring must delete the hand-written definition in
the same commit that reads its authored row. The real fix is the engine plan's.

---

### Finding 5 — Four hand-synced copies of one list, and the sync comments are themselves already out of sync

**Severity: important. File it.** This is the deferred minor from
`docs/rules-rework/rules-pipeline-status.md` §7; I am ruling it a must-schedule rather than a nice-to-have, for
the reason below.

**Where:**
- `scripts/rules_lint/lint.py:29` — `NON_RULE_FILES = {"SOURCES.yaml", "vocabulary.yaml"}`
- `scripts/rules_sync/check.py:84` — `{"schema.json", "SOURCES.yaml", "vocabulary.yaml"}`
- `scripts/build_rules_db/verify_db.py:21` — `{"SOURCES.yaml", "vocabulary.yaml"}`
- `scripts/build_rules_db/build_db.py:810` — local lowercase `non_rule_files`, same two entries
- plus `CHAPTER_PREFIX` duplicated at `lint.py:76` and `build_db.py:15`.

**The finding that is not in the deferred-minors list:** the hand-sync comments have *already*
drifted, which is the failure mode arriving rather than being predicted.

- `lint.py:23-28` says "three small local constants" and names `check.py` and `build_db.py`. It does
  not name `verify_db.py`. Its last sentence reads "Adding a fourth non-rule file means editing all
  three."
- `verify_db.py:19-21` names `lint.py` and `build_db.py`, not `check.py`.
- `check.py:79-83` names `lint.py` and `build_db.py`, not `verify_db.py`.

**Concrete failure scenario.** ADR-0013 plans a named-DSA-constants registry; call the file
`parameters.yaml` and put it in `specs/rules/` beside `vocabulary.yaml`, which is where it belongs.
A maintainer follows `lint.py`'s comment, edits the three files it names, and stops — the comment
told them there were three. `verify_db.py` is missed. `make rules-lint` passes,
`make rules-db` passes, and `make rules-db-verify` then treats `parameters.yaml` as an authored rule
and fails on a missing `ruleset`, or worse, passes while checking a file that is not a rule. No test
catches it: I grepped `tests/` and **nothing asserts the four sets agree**.

The sets are also not equal today — `check.py` carries `schema.json` and the others do not. That is
justified (it globs differently) but it means "kept in sync by hand" is already a half-truth, and a
reader diffing them cannot tell an intentional difference from a missed edit.

**What fixing it involves.** One shared constant in a small module the four already import from, or
— if the "four small local constants rather than a shared module" preference is deliberate, which
the comments say it is — one test that imports all four and asserts the relationship between them,
plus corrected cross-references. The test is about fifteen lines and makes the preference safe
instead of merely stated.

---

### Finding 6 — A failed gate reads as a green suite, and the command that starts a wave carries no warning

**Severity: important. File it.**

**What I ran:** `python3 -m pytest tests/ -q` → **258 passed**, exit 0. The calibration gate scored
7/10 and **failed**. Nothing in that output says so. The only printed artefact is the Tier 2
divergence report, which lists five rules with neutral phrasing and no verdict line.

The test names are neutral too: `test_the_tier_1_result_is_the_fraction_the_gate_reported`,
`test_tier_1_matches_what_the_calibration_recorded`. Both are correct names for what they do — they
pin a *measurement*, which `test_calibration.py:212-228` argues carefully and rightly. But the
consequence is that the repository's headline verification command reports success on a branch whose
central gate failed, and a future reader or a CI dashboard has no signal at all.

**The sharper half.** `Makefile:150-163` defines `rules-propose`, the command that starts a wave.
Its comment block explains selectors, review files and the disagreement protocol. It **does not
mention that the gate failed or that a wave is blocked.** `propose.py`'s `main()` prints no warning
either. The knowledge lives in `AGENTS.md` and `docs/rules-rework/rules-pipeline-status.md` §1 and §3 — both
emphatic, both easy not to have read when you are typing a Makefile target you just grepped for.

**Concrete failure scenario.** A contributor picks up Task 9 ("drive waves by group and subgroup",
which the Makefile comment advertises), runs `make rules-propose GROUP=3`, and spends 89 rules × 2
agents of model budget producing what §3 projects as a majority-wrong review queue arriving
labelled `agree / ok / written`. Nothing stopped them or even hesitated.

**What fixing it involves.** Two cheap things: (a) print the verdict, not just the Tier 2 report —
one line in `test_the_tier_1_result_is_the_fraction_the_gate_reported` reading
`CALIBRATION GATE: FAILED — Tier 1 7/10 — no authoring wave (docs/rules-rework/rules-pipeline-status.md §3)`;
(b) a `@test` guard or a printed warning at the top of the `rules-propose` recipe naming the status
doc. Neither changes the gate's semantics, which are right as they are.

---

### Finding 7 — `main()` has no runner seam, so the workspace-sanitising line is only ever executed by a live run

**Severity: important. File it — and it is the cheapest lever on finding 1.**

**Where:** `scripts/rules_sync/propose.py:1394` constructs `SubprocessRunner(...)` inline. There is
no `runner_factory` parameter and no injection point. `propose()` itself takes a runner and is
thoroughly tested with `FakeRunner`; `main()` cannot be.

**What that leaves untested.** `propose.py:1392-1393`:

```
prepare_workspace(Path(workspace), run_ids,
                  exclude_names=[r.name for r in rules])
```

`prepare_workspace` has excellent unit coverage (`test_propose.py:748-904`, including
`test_no_withheld_id_or_name_survives_anywhere_in_the_workspace`). The **wiring** has none. The
deferred-minors list records this; what it does not record is that it is structurally impossible to
test, not merely untested, and that `tests/conftest.py`'s live-agent guard is what makes it so — any
test reaching `main()` trips the guard by design.

**Concrete failure scenario.** Someone refactors `RuleInput` and the list comprehension becomes
`[r.rule_id for r in rules]` — a plausible slip, since both fields exist and the parameter is called
`exclude_names`. Every test still passes, including all of `prepare_workspace`'s. The next live run
withholds the ten authored files but leaves every German ability name unredacted across the ADRs,
`AGENTS.md` and the other eighteen rule files. That is precisely the contamination Task 6 fix round
2 closed, restored silently, and the run that exposes it is the one that costs twenty model calls
and is then graded as if it meant something.

`main()` also prints an unconditional claim at `propose.py:1412-1414` — "holding no authored file
for, and no mention of, the N rule(s) in this run" — which is asserted rather than verified.

**What fixing it involves.** Add `runner_factory: Callable[..., Runner] = SubprocessRunner` to
`main()`'s signature and call it. That is one line, it restores the seam, and it lets one
`FakeRunner` test drive `main()` end to end and assert that what reached the workspace is redacted.
That same test is the natural home for finding 1's mechanical guard.

---

### Finding 8 — The two-hash golden guard is sound, but documented wider than it is

**Severity: moderate. File it (documentation fix).**

The mechanism itself is good and I verified it works. What is wrong is the carve-out's stated scope.

**Where:** `tests/rules/golden/MANIFEST.yaml` (description, ~line 33) says the qualifying shapes are
`note`, `source.checked`, and "a rule-root key that is not an effect row at all". `test_golden.py`'s
`test_the_two_hashes_answer_different_questions:128` pins exactly that generalisation:
`assert graded_digest(root_edited) == graded_digest(base)`.

**What I measured.** I computed `graded_digest` over `specs/rules/SA_48.yaml` with single mutations:

| mutation | `graded` moves? |
|---|---|
| `subgroup: passiv` (was a maneuver subgroup) | **no** |
| `excludes: [SA_67]` added | **no** |
| `id` changed | **no** |
| a `value` changed (per the existing test) | yes |

`subgroup` is not cosmetic: `AGENTS.md` states that maneuver slots come from `rules.subgroup_id`,
and moving a rule between Basismanöver and Spezialmanöver changes what a hero may declare in a
Kampfrunde. `excludes` is described in `test_calibration.py:33-37` as "mechanical, but sits in
Tier 2". Both are table-visible, both pass the graded hash, and `BYTES_REMEDY`
(`test_golden.py:43-53`) would instruct the editor to "record why under `golden_edits` … and stop
there".

**Concrete failure scenario.** A later task reclassifies a golden rule's `subgroup` after reading
its page properly. `test_golden_rule_matches_its_recorded_hash` fails; the editor reads the remedy,
sees the graded assertion still passing, correctly concludes "not a Tier 1 field", refreshes `bytes`
and writes a `golden_edits` entry. The corpus's maneuver-slot data has changed, the calibration was
never re-run, and every check in the repository is green — which is the exact reading the manifest
says it exists to prevent, arrived at by following the manifest's own instructions.

This is not a defect in `graded_digest`: it grades what Tier 1 grades, correctly and by
construction. It is the prose generalising from two safe root keys (`ruleset`, `source.title`) to
all root keys.

**What fixing it involves.** Narrow the description from "a rule-root key that is not an effect row"
to the enumerated safe set, and name `subgroup`, `excludes` and `id` as requiring a re-run. Change
`test_the_two_hashes_answer_different_questions` to assert the narrow claim rather than the wide one
— it currently pins the over-generalisation in place.

---

### Finding 9 — The GS repair drops any bonus out of `max`

**Severity: minor, latent. File it.**

**Where:** `Hesindion/Services/DerivedValueRepair.swift:62`:
`dv.geschwindigkeit = ResourceValue(base: gs, bonus: dv.geschwindigkeit.bonus, max: gs)`

The write preserves `bonus` but sets `max` to the species base, not `base + bonus`. A hero with
`base 8, bonus 2, max 10` would be rewritten to `base 8, bonus 2, max 8`, losing two Schritt — and
`HeroDetailView.swift:546` and `CombatDefenseViews.swift:855` both read `.max`.

**Why it is only latent:** nothing writes a non-zero `geschwindigkeit.bonus` today.
`OptolithImportService.swift:892` writes `bonus: 0`, and I grepped every other write site — there is
none. So this cannot fire on current data.

**Why it is still worth a line:** the repair follows `ausweichen` and `initiative`
(`DerivedValueRepair.swift:45,51`), which have the same shape and are pre-existing, but diverges
from `wundschwelle` (`:35`), which correctly uses `max: ws.base + ws.bonus`. The file now has two
conventions and the new code joined the one that is arguably wrong. If a GS bonus ever becomes
reachable — an advantage granting +1 GS is a normal DSA shape — this becomes a silent data loss on
launch, with no test covering it (every case in `DerivedValueRepairTests.swift` uses `bonus: 0`).

**What fixing it involves.** One line, plus one test with a non-zero bonus. Or a deliberate comment
saying `max` is the species cap and `bonus` is display-only — but then say it, because the three
sibling values disagree about what those fields mean.

---

### Finding 10 — `lookupGroupId` cannot distinguish a NULL group from group 0

**Severity: minor. File it.**

**Where:** `Hesindion/Services/RulesDatabase.swift:286-293`. The function returns
`Int(sqlite3_column_int(stmt, 0))`, which is `0` for a SQL NULL, so a rule with no group and a rule
in group 0 are indistinguishable. 110 special abilities in the built database have a NULL
`group_id`.

Harmless today — `isCombatSpecialAbility` tests membership in `[3, 9, 10, 11, 12]` and 0 is not in
it, so NULL correctly yields `false`. It is a trap for the next caller who writes
`if rules.lookupGroupId(id) != nil`. Guard with `sqlite3_column_type(stmt, 0) == SQLITE_NULL`.

---

### Finding 11 — The default `pytest` run makes live network calls

**Severity: minor. File it.**

**Where:** `tests/rules/test_normalise_live.py` fetches two live pages three times, with two
one-second sleeps, inside an unmarked module. It is collected by plain
`python3 -m pytest tests/ -q`, which is the command `docs/rules-rework/rules-pipeline-status.md` §9 and
`AGENTS.md` both give for resuming cold.

The module skips cleanly when the site is unreachable, which is well done. The consequences are
small but real: the documented "258 passed" figure is network-dependent and becomes 256 offline; the
suite's runtime includes a politeness delay; and there is no marker (`@pytest.mark.live`) by which
someone could deselect it, whereas `make rules-sync-check`'s Makefile comment does warn about
network. Add a marker and mention it in §9.

---

## 3. Deferred-minor triage

The list parked in `docs/rules-rework/rules-pipeline-status.md` §7, ruled one by one. Numbering follows the
review brief.

### Must fix before merge

Only the two items promoted to findings 1 and 2. **No item on the parked deferred-minors list is a
merge blocker** — they were parked correctly.

### Must schedule (not blocking, but do not let these age out)

| # | Item | Ruling |
|---|---|---|
| 5 | Four hand-synced copies of `NON_RULE_FILES` (+ `CHAPTER_PREFIX` ×2) | **Schedule.** See finding 5 — the cross-reference comments have already drifted, so this is a realised defect, not a predicted one. |
| 7c | `exclude_names` wiring in `main()` has no end-to-end `FakeRunner` test | **Schedule.** See finding 7. Structurally untestable as written; the one-line seam fix is also the hook for finding 1's durable guard. |

### File it

| # | Item | Ruling and reason |
|---|---|---|
| 1 | `HeroImportTests.swift:62` retains a non-emptiness assertion | **File.** Confirmed redundant: the two `contains` assertions at `:65-66` each imply it. Zero risk, zero cost, no reason to touch it in a merge commit. (The status doc cites line 62; the brief cites line 60. Line 62 is the assertion.) |
| 2a | Linter's glob is non-recursive (`lint.py:389`) | **File.** Verified that `build_db.py:811` and `check.py` use the same non-recursive shape, so a rule file in a subdirectory is invisible to all three *consistently* — it is never built, never linted, never drift-checked. That symmetry makes it a latent trap rather than a live hazard, and one line in each fixes it whenever someone wants subdirectories. |
| 2b | Duplicate YAML keys are last-wins and unreported | **File.** Confirmed: `_RuleLoader` (`lint.py:11-18`) subclasses `SafeLoader` and overrides only the timestamp resolver, so PyYAML's silent last-wins applies. Worth closing eventually — a duplicated `effects:` key would drop a whole rule's first encoding with no error — but it needs an author to make the mistake first, and the corpus is 28 files. |
| 2c | `subgroup` NULL policy undocumented | **File.** Documentation only. |
| 2d | Unhelpful `oneOf` error message | **File.** Ergonomics. Worth doing before a wave, since a wave is where authors meet it. |
| 3 | `SA_41`'s `scope: all` parking | **Parking is still correct at branch end — see below.** |
| 4 | Invisible-character content container | **File**, with the second reason recorded. Verified both halves empirically — see §4. |
| 6 | `dice.add` quoting discipline is manual | **File, and downgrade it.** I checked the actual risk: `schema.json` types `add` as `"type": "string"`, so an unquoted `add: 2` parses as an int and **fails lint loudly**; `add: +2` likewise. PyYAML's default dumper also re-quotes a string `'2'` on write, so the driver's round-trip is safe. The missing representer is an authoring ergonomics gap, not a correctness hole. Lower priority than the status doc's placement suggests. |
| 7a | Rule text is untrusted input; the injection defence is a prompt instruction | **File.** This is already the accepted position (ADR-0012's 2026-09-21 amendment) and the reasoning is sound: read-only tools, git-ignored output, closed schema, first-envelope-wins in `parse_agent_output`. Note that finding 1 is the *same structural weakness* arriving from the trusted side — a shared input steers both agents identically whether it is hostile or merely leaked. Worth stating in the ADR that the two are one problem. |
| 7b | `--restricted`'s out-of-cwd denial evidenced only by a live run | **File.** `test_the_runner_asks_for_restricted_mode` (`test_propose.py:1175-1181`) asserts the flag is in `argv` and nothing more, which is honest about what it covers. A constructed negative test means driving the real CLI, which the `conftest.py` guard forbids by design. The honest remedy is a documented manual procedure, not a test. |
| 7d | Parallelism never exercised beyond one batch plus two verifiers | **File.** Blocked behind the gate anyway — blocker 4 says do not re-run the same configuration, and blocker 1 says the input is wrong. Measuring rate limits at 12×2 before the input is fixed measures the wrong thing. |
| — | Prose-leak guard's false positive on rule-website text | **File.** Fails safe (rejects rather than writes), one-line exclusion, and it only fires once blocker 1 is closed. Do it as part of blocker 1. |
| — | Nothing tests the `chapter` category end-to-end in `build_db.py` | **File, but raise its priority.** I built and verified the database (`make rules-db`, `make rules-db-verify` → "rules.db is current") and `CHAP_Reiterkampf` is present with `category=chapter`, `ruleset=core`, `title=Reiterkampf`. So it works today. The gap is real though: the Python suite builds no database, so the silent-skip regression `c93105a` closed has no test guarding it. |
| — | `AbilitySuccessRateSnapshotTests.testLogPanelWithSessionHeaders` one-off failure | **File.** It passed in my run. The decision not to label a single observation as a flake is right and I would not change it. |
| — | Block/inline tag list missing from its CHANGELOG bullet | **File.** Documentation. |
| — | 17 of 28 files still carry the `UNVERIFIED` placeholder | **Not a minor, correctly labelled as such.** Confirmed by running `make rules-sync-check`: 11 ok, 0 drifted, 17 unverified. Blocked on Task 10's URL resolution. |

### Ruling on item 3 — `SA_41`'s `scope: all`

**The parking is still right at branch end. Do not change the scope value.**

I verified the three things that could have invalidated it:

1. **`CheckDomain` still has no INI or GS domain.** `ModifierEngine.swift:5-13` lists exactly seven
   cases — melee attack/parry/dodge, ranged attack, spell and liturgy casting, talent check. Nothing
   in this branch added one. The premise holds.
2. **The path is still dead.** `RuleEffectModifiers` still has no callers (finding 4), so no `scope`
   value on `SA_41` produces any behaviour today. There is no live cost to leaving it.
3. **ADR-0013 still records it as a binding input to the engine plan**
   (`docs/adr/0013-rules-as-data-combat-engine.md:158-165`), and the amendment is intact and
   below the amendment line.

One thing to add to the record while it is parked. The branch has now made the *divergence* concrete
in two places that did not exist when the parking was decided:

- `specs/rules/SA_41.yaml` says `scope: all`, which `RuleEffectModifiers.domainsForScope("all")`
  would expand to **all seven** domains including `talentCheck`;
- `SharedModifiers.encumbrance` (`SharedModifiers.swift:20-27`) declares **six** domains and
  excludes `talentCheck`.

So the data and the Swift now give different answers for the unmounted Belastung penalty too, not
just for the mounted relief (finding 4). Still no live effect, still the same root cause, still not
fixable by picking a string. But the engine plan should be told there are *two* rows to reconcile,
not one — a line in ADR-0013's existing consequence paragraph is enough.

---

## 4. What I verified, and how

**Claims resting on execution:**

- `make rules-lint` → `28 rule file(s), 0 error(s)`, exit 0.
- `python3 -m pytest tests/ -q` → `258 passed` in 16.4s, exit 0. (Includes the live-fetch module —
  finding 11.)
- `make rules-db` → built; `make rules-db-verify` → `rules.db is current`.
- `make rules-sync-check` → `11 ok, 0 drifted, 17 unverified, 0 structure-changed out of 28`,
  0 network calls (warm cache).
- `make test-ui` → `** TEST SUCCEEDED **`, 216 XCTest cases plus the swift-testing suites, 0
  failures. One xcodebuild target, the Makefile's single pinned simulator, destination set not
  widened.
- **Database queries** against the built `rules.db` for finding 3: group ids for all nine
  previously-combat SAs, for `SA_884`/`SA_160`/`SA_161`, and the group histogram (232 SAs in groups
  3/9/10/11/12 versus the 9 the old predicate matched). Also confirmed the `ruleset` column carries
  `core` for all 28 authored rules and NULL elsewhere, and that `CHAP_Reiterkampf` lands with
  `category=chapter` and its title.
- **`graded_digest` probes** for finding 8: computed it over `specs/rules/SA_48.yaml` with `subgroup`,
  `excludes` and `id` mutated independently; all three left the digest unchanged.
- **`normalise.py` probes** for deferred minor 4: a container holding only U+200B hashes a one-
  character string instead of raising `ContentContainerError`; same for U+00AD; a soft hyphen
  inserted mid-word changes the hash with no visible text change, confirming the false-drift half.
- **A real sanitised workspace** for finding 1: called `prepare_workspace` with the ten golden ids
  and their German names pulled from `rules_i18n`, into a temporary directory, then read the
  redacted ADRs. Every line cited in finding 1 is quoted from that built workspace, not from the
  repository — i.e. it is what an agent would actually see.
- **Git hygiene:** `git ls-files` confirms `rules.db` is untracked; `git check-ignore -v` confirms
  `.gitignore` bites for `Hesindion/Resources/rules.db`, `.proposals/`, `.cache/`,
  `scripts/build_rules_db/venv/`, `.worktrees/`, `build/`; working tree clean after a full database
  build; a credential-pattern grep over the whole diff returned only variables named `token` in the
  vocabulary linter and a deliberately-named `"SECRET RULE TEXT"` fixture in `test_propose.py`.
- **Assertion-free test scan** over all of `tests/`: one hit,
  `test_normalise.py:104 test_normalise_never_raises_on_the_fixtures`, which is a legitimate
  smoke test (the assertion is "does not raise"). No other test in the suite lacks an assertion.

**Claims resting on reading:**

- The three authorised Swift behaviour changes, read against their authored rule files and the
  reasoning in `CHANGELOG.md` / `docs/rules-rework/rules-pipeline-status.md` §5 and §6(b). I did **not** fetch
  the rule website pages to re-read the clauses myself — the branch's own deterministic check does
  that job better, and `make rules-sync-check` reports all three rules' source hashes still
  matching what the site serves (`SA_41`, `SA_661`, `CHAP_Reiterkampf` all `ok`). That is stronger
  evidence than my reading a page would be, and it avoids putting rule text anywhere near this
  document.
- `RuleEffectModifiers` having no callers: established by grep, not by building a call graph.
- Finding 4's double-count hazard is reasoned from the code, not demonstrated — demonstrating it
  would mean wiring the dead path up, which is out of scope for a read-only review.

**What I could not check:**

- **Anything requiring a live model call.** The calibration gate's 7/10 is a recorded measurement;
  I verified the grader re-derives it from bytes, and I verified the recorded proposals lint, but I
  cannot confirm the run happened as described. The two-hash manifest and `RUN.yaml` are the only
  evidence and they are internally consistent.
- **`--restricted`'s actual denial behaviour** — same reason (deferred minor 7b).
- **`HesindionUITests`** — I ran `make test-ui` (the unit + snapshot target) only, per the
  one-xcodebuild-target rule.

---

## 5. Checked and found clean

So a later session does not re-derive these:

- **All three authorised Swift behaviour changes are correct against their authored rules.**
  `Hero.effectiveBE` (`Hero.swift:161`) now matches `specs/rules/SA_41.yaml`'s ladder exactly (−1 at
  Stufe I, −2 at Stufe II, tier read from the owned Stufe).
  `SharedModifiers.encumbrance` matches `CHAP_Reiterkampf`'s BE row's combat scoping.
  `MeleeModifiers.vorteilhaftePosition` / `golgariten` and `DefenseModifiers.golgaritenPA` match
  `CHAP_Reiterkampf` clause 2 and `SA_661` clauses 1 and 2 including which one carries the
  `opponentOnFoot` gate and which does not.
  `DerivedValueFormulas.geschwindigkeit` matches the pinned source's per-race values.
- **The GS repair is genuinely idempotent.** The guard at `DerivedValueRepair.swift:60-64` compares
  both `base` and `max` against the computed value and the write sets both to it, so a second call
  cannot change anything; `testGeschwindigkeitRepairIsIdempotent` covers it, and the
  unknown-species and nil-species skips are each covered by a test that also isolates GS from the
  other three repairs (the fixture's attributes are chosen so WS/AW/INI are already correct).
- **No double-count in the advantageous-position UI.** `CombatAnnouncementView.positionForced`
  asks `MeleeModifiers.emitsVorteilhaftePosition`, the same predicate the engine definition uses, and
  the manual insert at `CombatAttackViews.swift:637` is gated on its negation. When the GM turns
  `opponentOnFoot` off, the manual toggle correctly reappears. `CombatRootView:32` builds only
  parry/dodge contexts, so its not setting `opponentOnFoot` is harmless, not an inconsistency.
- **`tests/conftest.py`'s live-agent guard genuinely works for the real path.**
  `propose.py` calls `subprocess.run(...)` by attribute lookup at call time (`:594`, `:632`), which
  the autouse monkeypatch intercepts; `test_no_live_model_calls.py` proves reach from a module that
  does not define the fixture, and covers the absolute-path spelling. `Popen`/`check_output` are not
  guarded, but `propose.py` does not use them.
- **The `graded` hash does what it claims for the two cases it was built for:** a note edit does not
  move it, a value edit does. Finding 8 is about the *third* case, not about these.
- **`rules.db` is untracked and the ignore rules bite.** Nothing generated, secret or
  prose-bearing is committed beyond finding 2's prose.
- **The golden corpus freeze works** — no duplicate rule bodies under `tests/rules/golden/`, the
  manifest covers exactly ten ids spelled out independently of the manifest, and the recorded
  calibration proposals are linted rather than trusted (with one deliberately narrow, documented,
  self-expiring waiver).
- **`source.title`'s Data Policy guard is well designed.** Requiring the title to ASCII-fold to the
  same slug as the id means a sentence structurally cannot pass — that is a real mechanism, not a
  hopeful pattern.
- **Test quality overall is high.** Tests assert behaviour rather than mocks, the fixtures are
  synthetic rather than lifted from the site, `FakeRunner` refuses calls nobody recorded so a test
  cannot pass by skipping, and several tests exist specifically to pin an argument that would
  otherwise only live in prose (`test_ruleset_is_outside_what_tier_1_grades`,
  `test_the_two_hashes_answer_different_questions`, `test_this_module_is_covered_by_the_shared_live_agent_guard`).
  I looked for tests passing for the wrong reason and did not find one.

---

## 6. Follow-up recorded after the blocker fixes (controller ruling, 2026-09-21)

**Withholding must follow the rule graph, not just the rule id.** Closing finding 1 surfaced a
leak channel no guard can reach: `specs/rules/CHAP_Reiterkampf.yaml` is a legitimate, un-withheld
authored file that sits in the calibration workspace and encodes the very clause `SA_661` modifies —
same target, scope, value and gate, with a note stating that the withheld rule "raises" it. An agent
grading `SA_661` can read the answer out of a file it is entitled to see.

Two properties make this worth writing down rather than fixing in place:

- It is **new since the 7/10 was measured.** `CHAP_Reiterkampf` was authored after that run, so
  `SA_661`'s current Tier 1 pass may rest on this channel rather than on the pipeline's judgment.
  Treat `SA_661`'s result as unmeasured until a run withholds the chapter file alongside it.
- It **generalises**. Any authored file that encodes a clause a graded rule modifies — a chapter rule
  an ability raises, a parameter an ability overrides, a rule named in another's `excludes` edge — is
  an answer key for that rule. As the corpus grows past 28 files toward 232, this class of adjacency
  grows with it, and id-and-name redaction does not touch it.

**Required before Task 11 (stability measurement) produces a number anyone acts on:** the workspace
builder withholds the transitive set — the graded rule plus every authored file whose effects
reference it or whose clauses it modifies — and the run reports which files were withheld for each
rule, so a reader can tell what the measurement controlled for. Until then, per-rule results for any
rule with an authored neighbour are suggestive rather than measured.

Not a merge blocker: it degrades a measurement that this branch already declares failed, and it
cannot produce a wrong encoding in the app.

### Correction, 2026-09-21 (Task 11a) — the ruling stands; one piece of its evidence does not

**The text above is left as written and its ruling is unchanged.** The generalisation is correct and
load-bearing, the mechanism it required is built (`scripts/rules_sync/rule_graph.py`, commits
`0d55ce3..afe7d80` — the range the plan's status board carries; this line cited the pre-fix-round
range until 2026-09-22), and building it found a *second* adjacency of the same class that this section
did not know about — see the note at the end of this correction. What fails is one sentence of
evidence, and it is corrected here rather than edited above so that a later reader sees both.

**"`SA_661`'s current Tier 1 pass may rest on this channel" is wrong on both halves.** Two checks,
either of which settles it:

- **It was not a pass.** `tests/rules/calibration/2026-09-21-sonnet/RUN.yaml` records
  `expected: SA_661: false`, and its `summary_table` shows `SA_661  DISAGREE  ok  disagreement`. It
  is one of the three Tier 1 failures that make the score 7/10, and §1 of
  `docs/rules-rework/rules-pipeline-status.md` already explains it as input-caused.
- **The recorded run could not have used the channel.** `specs/rules/CHAP_Reiterkampf.yaml` was added
  in `78802fb`, six commits *after* the calibration run was recorded in `505c721` — which is this
  section's own observation ("new since the 7/10 was measured"), and it cuts the other way from the
  conclusion drawn from it. A leak channel can only move a verdict *toward* the golden file, so a
  failure recorded before the channel existed is not called into question by it.

**Therefore no recorded number changes, and "treat `SA_661`'s result as unmeasured" does not apply to
the recorded run.** The risk this section identified was always prospective: every run from the day
the chapter file landed would have been exposed, including one that flipped that recorded `false` to
`true` for a reason nobody could attribute to a fix. That is what the closure removes, and it is why
the requirement it states — withhold the transitive set, and report what was withheld — is unchanged.

**A second instance, found by building the mechanism this section asked for.** `SA_43`'s whole
encoding is one axis-less row plus one `when` predicate, and a chapter file carrying that same gate
on every one of its own rows — and naming `SA_43` in two notes, so redaction rewrites them and leaves
the mechanical half standing — sat in its workspace untouched by the first three edges. A
`when`-predicate edge closes it. `SA_43` is the source of the 2-of-5 gate-dropping datum Task 11
exists to quantify, so this one sits on the rule the measurement most depends on. Recorded here
because it is the same class this section generalised, and because it is evidence *for* the
generalisation where the `SA_661` sentence above is not.
