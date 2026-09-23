# Rules Pipeline — State and Next Steps

**Written 2026-09-22, branch `feat/rules-data-pipeline` at `54e0ffe`, 87 commits ahead of `main`.**

This document exists to be read before deciding what to spend next. `docs/rules-rework/rules-pipeline-status.md`
remains the operational state — what the gate measured, what it blocks, what is settled. This one
holds the decision that is open and the arguments on each side of it.

No DSA rule prose appears here, per the Data Policy in `AGENTS.md`. Unlike `docs/adr/`, this file is
**not** copied into the authoring agents' sanitised workspace; it observes the convention anyway.

---

## 1. Where the branch stands

Verified on this tree, not quoted from an older document:

| | |
|---|---|
| `make rules-lint` | 28 rule file(s), 0 errors |
| `python3 -m pytest tests/ -q -m "not live"` | 415 passed, 2 deselected |
| `python3 -m pytest tests/ -q` | 417 passed |
| `make test-ui` | TEST SUCCEEDED |
| `make rules-db-verify` | `rules.db is current` |
| Live model calls made | **none** |

**Cold start order matters and is circular once:** `make rules-db` → `make rules-resolve` →
`make rules-db` → `pytest`. `resolve.py` hard-fails without `rules.db`, and two of the repository's
guards silently skip until `make rules-resolve` has run at least once. See `AGENTS.md` and §9 of the
status doc.

### Done

- **The whole-branch review's list is closed** — both merge blockers (`da75e9a`) and all nine
  remaining findings, each through implement → review → fix → re-review.
- **Task 10** — every combat rule resolves to its own page by name off the site's category indexes:
  201 resolved, 26 needs-review, 5 unresolved, 0 ambiguous, out of 232. The ten golden rules resolve
  byte-identically to the URLs their authored files already record. No URL is ever derived from an id
  or a name; a non-match or a multi-match is reported with its candidates, never guessed.
- **Task 11a** — the calibration workspace withholds the transitive rule graph, not just the rule id,
  over four mechanical edges, with a per-rule withholding report and a measured cost analysis.
- **Three Swift changes**, each authorised rather than assumed: the special-ability reclassification
  repair (with a probe guard and a self-healing design), the Geschwindigkeit `max` correction, and a
  NULL guard on the group lookup.

### Not done

- **Blocker 1 is not closed.** Its *resolution* half is built; its *backfill* half is not. 31 rules
  still need a human, no authored file was rewritten — provenance is the driver's to compute, per
  ADR-0012's second 2026-09-21 amendment — and `propose.py` still reads `rules_i18n.description`,
  which is the seed text rather than the page.
- **Blockers 2, 3 and 5 are untouched.** 17 of 28 authored files still carry the `UNVERIFIED`
  placeholder.
- **Task 11's measurement has not been run**, deliberately.

---

## 2. The measurement changed question

This is the decision's centre of gravity.

| | Recorded run | After the §6 ruling | Now |
|---|---:|---:|---:|
| Batch of ten, files withheld | 10 of 28 | 12 | **18** |
| Files left as precedent | 18 | 16 | **10** |
| Per rule alone | 1 | 8 | **16** (`SA_40`, `SA_59`: 1) |

Rules left with **no surviving example of any row shape they must produce**: **9 of 10** in the batch
configuration (all but `SA_59`), **7 of 10** run rule-by-rule. The difference is exactly `SA_62` and
`SA_67`, and the mechanism is one fact — the corpus's only three files carrying that row shape are
all golden, so singly each leaves the others standing and batched they go together. **That is the
only precedent difference between the two configurations**, and the plan asks Task 11 to choose
between them.

Every figure above was recomputed independently of the tests that pin them, twice, by two different
reviewers.

**What follows from it:** the measurement now asks *"can the pipeline encode this rule from its text
with no worked example of the row shape in front of it?"* That is the honest question once a
neighbour's file is an answer key. It is **not** the question the recorded 7/10 answered. Every rule
sees eight fewer precedent files than the recorded run did, so **no rule's next number is comparable
to its recorded verdict**, and a drop would be the leak being removed rather than a regression.

**~110 live model calls buys a new baseline, not a comparison.**

Task 11's own acceptance criteria require a pass bar fixed *before* the runs. That bar now has to be
written against this baseline rather than carried over.

---

## 3. The options

### A. Fix the pass bar, then run the five passes (~110 calls)

**For.** Task 11's criteria require the bar anyway. It produces the first honest per-rule reliability
number the branch has had; blocker 4 exists precisely because a single-sample gate cannot attribute a
fix, distinguish 6 from 8, or certify what it is asked to certify.

**Against.** It buys a baseline comparable to nothing yet. Its main use is as the reference for a
*second* run after blocker 1's backfill, so the spend only pays off if that second run happens.

### B. Fix the pass bar, do not run

**For.** The bar is the part that must exist first, and writing it is free. Nothing is spent, and the
next session starts with the expensive decision already made and reviewed.

**Against.** The branch ends still not knowing the pipeline's per-rule reliability, so blocker 4 stays
open and Task 9 stays blocked regardless.

### C. Close blocker 1's backfill first, then measure once

**For.** One measurement instead of two, against the input ADR-0012 actually mandates. The gate's own
headline finding is that the driver feeds seed text where the page is normative; measuring the
pipeline on the wrong input measures the wrong thing.

**Against.** The backfill is 31 rules needing human review plus a driver change — its own session. And
`docs/rules-rework/rules-pipeline-status.md` §3 records that a ten-rule pass on page text scored 6/10, *below* the
seed run, so resolving the input is necessary and **not demonstrated sufficient**.

### D. Stop here and merge what exists

**For.** The branch already delivers: one authoritative place to author a rule, a linter and schema
over it, a deterministic drift check, a URL resolver, an honest failed gate, a withholding mechanism,
and three fixed rule bugs that changed numbers at the table. All of it reviewed.

**Against.** The withholding mechanism ships unexercised. Its arithmetic is pinned by real-corpus
tests, but no run has used it.

**Recommendation: C, then A.** The branch's own evidence says the input is wrong, and a reliability
number measured on a known-wrong input is one you would have to discard. If a number is wanted sooner,
B is the cheap honest stop.

---

## 4. Open rulings, for whoever picks this up

1. **Does the graph closure apply to authoring waves, or only to graded runs?** At 232 rules the
   scope-subsumption edge plus transitivity could make the closure approach the whole corpus for any
   combat rule. It does not affect Task 11 (that arithmetic is pinned), but it should be settled
   before Task 9.
2. **Which configuration does Task 11 use** — batch or rule-by-rule? They are not comparable, and the
   run must state which it used and report `SA_661` separately.
3. **`rules.title` versus `rules_i18n.name` for chapter-rule display** — still open, from §6(c) of the
   status doc. Cheap now, expensive once the engine and the breakdown UI both read it.
4. **`CombatDefenseViews` reads `geschwindigkeit.max` raw** — §6(d), unchanged and still undecided.

---

## 5. Two properties worth not breaking

**The leak guard is copy-list-driven, and that is load-bearing.**
`tests/rules/test_workspace_leaks.py` walks whatever `prepare_workspace` actually produced. So
`CHANGELOG.md` and the status documents may state encoded rows freely *because they are not copied* —
and the day one of them joins the copy list in `scripts/rules_sync/propose.py`, the probes arm
themselves on it automatically and the suite goes red. **Do not "simplify" that guard to a hardcoded
file set**; the property is the whole defence.

**The probes cannot see prose.** They read code spans and numbers. The strongest leak found in the
whole-session review — a *negative* statement about a graded rule's row set, in plain English with no
identifier and no digit — returned zero hits from all five probes. The guards are a ratchet against
shapes already seen. Reading is still the check.
