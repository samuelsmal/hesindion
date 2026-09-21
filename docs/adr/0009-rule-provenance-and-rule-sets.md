# ADR-0009: Rule Provenance at Runtime, and Rule Sets as Data

## Status

Accepted — 2026-09-21

## Context

Three defects surfaced in one session's work on the rules corpus. None of them announced itself;
each was found because somebody happened to look.

- **A wrong formula.** `Hero.effectiveBE` reduced Belastung by `2 * belastungsgewoehnungLevel`.
  `specs/rules/SA_41.yaml` had the correct ladder (−1 at Stufe I, −2 at Stufe II) the whole time. The
  two never met, and every hero with the ability got double the relief for months.
- **A number with no attribution.** `DefenseModifiers`' mounted `−2` on Ausweichen is a real clause
  on <https://dsa.ulisses-regelwiki.de/Reiterkampf.html>, but nothing in the code, the breakdown or
  the corpus said so. It read as a magic constant, and a magic constant is indistinguishable from a
  mistake.
- **Two sources disagreeing.** `SA_41` existed twice in the legacy stores with different `scope`
  values, which is ADR-0007's founding bug still producing new instances.

What these share is not a category of rule. It is that **a number the app displays cannot say where
it came from.** `ModifierLine` is `(value: Int, source: String, isZustand: Bool)`, and `source` is a
localised *label* — `L("source.belastung")` — not a citation. A `−1 BE` line in a combat breakdown
cannot name the Reiterkampf chapter, cannot link its page, and cannot be asked whether the app is
even applying the right rule. The same `encumbrance` definition serves six `CheckDomain`s and stands
in for two different rules (the armour's Belastung and the mounted relief), and its one label
covers both. So does every other line the engine emits.

The user's framing, which is the requirement: *"in the UI we should be able to explain where a
limitation, a bonus, a modifier, etc comes from."*

Separately, and for the same reason, **optional rules are code.** `FokusRule`
(`Hesindion/Models/FokusRule.swift`) is a hand-maintained Swift enum with one case,
`Hero.fokusRules: [String]` stores which slugs a hero plays with, and every rule that belongs to a
Fokus-Regel is wired to it by a Swift branch reading that flag. Turning Trefferzonen off works
because `HitZoneModifiers` checks. Nothing in the authored corpus records that a rule is optional at
all, so the corpus cannot answer "which rules is this table playing with", the engine cannot filter
by it, and each new optional rule — or house rule, which is the same shape — costs an enum case plus
every branch that has to learn about it. This is the situation the maintainer named: *"we're running
into this issue a few times, and it will be difficult to keep track what rules are in use."*

And underneath both: **the corpus borrows its identity from Optolith, which only has identity for
abilities.** Optolith names abilities, advantages, disadvantages, Zustände and Kampftechniken.
It does not name the mounted-combat chapter, the multiple-defence penalty, or the rule that a
hero's species sets their base LP. ADR-0007's amendment introduced `CHAP_<PageSlug>` for chapter
pages and framed it as a second namespace beside Optolith's. That framing is too small.

## Decision

### 1. Every engine output carries the rule id it came from

`resolve(context) -> EngineResult` (ADR-0008) returns `lines`, `dice`, `parameters`,
`restrictions`, `probes` and `reminders`. **Each of those carries the id of the rule that produced
it** — `ModifierLine` gains it first, because it is the one the breakdown already renders. A number
that cannot name its rule is not a supported output.

The Swift change belongs to the engine rewrite (ADR-0008), not to the commit that carries this ADR.
What this ADR fixes is that it is required, and what the data must provide for it to be possible.

**The UI renders the rule's own name and text, in German, straight from `rules_i18n` in the
generated database.** No English display text for rules, no translation layer, no UI string table
for rule content. Tapping a `−2` in a breakdown shows the rule that produced it, in the words the
book uses, with a link to its `source.url`. This is a decision and not merely an implementation
detail, because the obvious wrong turn — authoring English display text per rule so the UI has
something to show — would create a second copy of every rule that can drift from the first. That is
ADR-0007's founding defect re-introduced at the presentation layer, and it would cost 232 hand-written
strings to acquire.

**This does not relax the Data Policy.** German rule prose still never enters git. It reaches the
app the way it already does, through the generated `rules.db` built from the local Optolith source
(ADR-0007), and authored files still carry no `text:` key and no German at all — `note` stays ASCII
English naming which clause an effect encodes. "No need to translate anything" is a statement about
what the UI *renders*, not about what the repository *stores*.

What the data side must provide, and where it currently breaks:

1. **Every effect is attributable to exactly one rule.** Already true: one authored file per rule,
   and `effects.rule_id` in the database.
2. **Every emitted id resolves to a row in `rules` with a `source.url`.** True for Optolith ids, and
   true for chapter ids since `build_db.py` creates their row under the `chapter` category.
3. **Every emitted id resolves to a *displayable name and text*.** This is the one that fails.

**Chapter rules have no `rules_i18n` row and cannot be given one**, because there is no Optolith
entry behind them. ADR-0008's amendment recorded that as a consequence for a future consumer; with
this decision it becomes a blocker, because a `CHAP_Reiterkampf` line in a breakdown would have
nothing to display but its id.

**A chapter rule carries its page title in its authored file** — `source.title` — and
`build_db.py` writes that into the chapter rule's `rules` row as its name. Its explanation in the UI
is then: the page title, a link to `source.url`, and its own authored `reminder` notes, which are
English, ours, and already load-bearing under ADR-0008's amendment. It renders no rule text, because
there is none in git and there never will be.

The alternative — have the build fetch the page and take the title from it — is rejected: ADR-0007
requires the database build to be offline and reproducible, and it rejected build-time scraping once
already. The title is not new information in git either: `CHAP_Reiterkampf` *is* the page title,
ASCII-folded, and `lint.py` already enforces that it is. `source.title` restores the display form
(umlauts, spaces) of a name the repository already holds, and a page title is a name rather than
prose — the same line the id itself already walks.

`source.title` is specified here and added with the chapter-rule wave (Task 12), not now: there is
one chapter file today and no engine to read it.

### 2. Rule sets are data — sets now, versions later

**Every authored rule declares a `ruleset`:**

- `core` — a standard rule of the Regelwerk. Always active.
- `focus.<slug>` — a Fokus-Regel, an optional rule the book prints as optional. Active only for a
  hero who has that slug switched on.
- `house.<slug>` — a table's own rule. Same mechanism.

**The engine applies only the sets active for a hero.** Switching a Fokus-Regel off removes its
effects because the data says which rules belong to it, not because a Swift branch checks a flag.
`FokusRule` stops being a hand-maintained enum and becomes a projection of the registry; `Hero.fokusRules`
keeps storing slugs, which is why `focus.trefferzonen` is spelled to match `FokusRule.trefferzonen.rawValue`
— the migration needs no data conversion on existing heroes.

The field is **required and has no default.** `core` is the overwhelmingly common value, which is
exactly why defaulting to it is wrong: an optional rule nobody marked would apply to every hero and
the file would look correct. A required field makes the author state the answer.

**A `focus.`/`house.` slug must be glossed in `specs/rules/vocabulary.yaml`**, the same registration
`gmFlag` and the `actionEconomy` tokens already carry, and `lint.py` enforces it. The set of optional
rules a table can play with is then itself data — a reviewable one-line diff — rather than a Swift
enum somebody has to remember to extend. It also catches the failure an open vocabulary actually dies
of: `focus.trefferZonen` beside `focus.trefferzonen` is one optional rule appearing as two, with heroes
switching on neither.

Where the two ways of being wrong are not symmetric, **guess in the visible direction.** A rule
wrongly marked `core` fires for a table that did not choose it, and somebody sees a number that
should not be there. A rule wrongly marked `focus.` fires for nobody and nothing says so. ADR-0008's
rule is that visible-and-wrong beats silent, so both agent briefs instruct: when the page does not
make it obvious, say so in the rationale and write `core`.

**Versioning is deliberately out of scope.** One current text per rule. `book`, `page`, `checked`
and `hash` record which printing that text was verified against, and `make rules-sync-check` catches
it when the page moves.

The worked example of what is being deferred is `SA_62`. The Optolith seed says page 249; the live
page says 250 and carries two cap clauses the seed is missing. ADR-0007 makes the page normative, so
the authored file records 250 and the seed's 249 is simply stale. Under a versioning scheme it would
instead record *two* printings, which one each clause belongs to, and which printing a given table
plays under — and every rule would carry that dimension forever. That is acceptable to defer because:
the app serves one table at a time, playing one current printing; the drift checker already converts
a silent change into a dated report naming the rule; and the cost of versioning is paid on all 232
rules immediately while the benefit arrives only when a group deliberately plays an older printing,
which has not happened once. It is also reversible: a version dimension would *extend* `ruleset` plus
the `source` block, not replace them.

### 3. Rule identity is ours; Optolith names abilities

Optolith supplies the id namespace for **abilities** — `SA_`, `ADV_`, `DISADV_`, `COND_`, `CT_` —
and that is the whole of what it supplies. It does not identify a chapter rule, a named combat
constant, or a derived-value rule. `CHAP_<PageSlug>` is therefore not a side namespace for pages no
ability owns; it is **the first instance of our own rule namespace**, and Optolith is demoted from
"the id authority" to "the id authority for abilities".

What belongs in that namespace, none of it built and none of it authored by this ADR:

- **Chapter rules.** `CHAP_Reiterkampf` exists; the rest are Task 12.
- **The core-rule constants ADR-0008 turns into named parameters** — the multiple-defence `−3`, the
  dual-wield base, the reach matrix, the zone penalties, the Passierschlag penalty. Each is a
  parameter *and* a rule that can be cited, and today it is a Swift literal that can be cited as
  nothing.
- **Derived-value rules.** A hero's GS and their species base LP, SK and ZK are rules, stated by the
  book and keyed on species. They live in `Hesindion/Engine/DerivedValueFormulas.swift` and in
  `OptolithImportService`'s species tables. ADR-0006 exists because one of those formulas was wrong;
  the 2026-09-21 rounding round corrected more. That is precisely the failure class runtime
  provenance is meant to make visible, and it is invisible today because a derived value has no rule
  to point at.

Task 12 of `docs/plans/2026-09-20-rules-pipeline-and-authoring.md` grows to enumerate these with the
Swift file and line each currently occupies, the way it already does for the chapter pages.

## Considered Alternatives

- **Let the localised `source` string be the provenance.** Rejected. It is a label chosen for
  display, not an identifier: one `encumbrance` definition emits `L("source.belastung")` across six
  domains for two different rules, and no string comparison can undo that. It is also the wrong
  direction of dependency — the UI would become the authority on which rule a number came from.
- **Author an English display name and summary for every rule so the UI has something to show.**
  Rejected. It is a second copy of every rule, hand-written, able to drift from the encoding and from
  the page, with nothing comparing them — ADR-0007's founding defect rebuilt at the presentation
  layer. The database already ships the German text; rendering it costs nothing and cannot drift.
- **Fetch each chapter page's title at database build time.** Rejected. ADR-0007 requires the build
  to be reproducible and offline and rejected build-time scraping on those grounds; nothing about a
  title makes it the exception.
- **Give chapter rules a synthetic `rules_i18n` row written by hand.** Rejected: that row's text
  field is rule prose, and writing one would put German rule text in git — the Data Policy line this
  whole corpus is shaped around.
- **Keep `FokusRule` and add a Swift map from rule to Fokus-Regel.** Rejected. It is the same
  hand-maintained list, now in a second place, and its failure mode is silent: a rule missing from
  the map applies unconditionally, which is the bug this ADR is trying to end.
- **A separate manifest listing which rules belong to which set.** Rejected for ADR-0007's reason:
  two authorities and no arbiter. The rule's own file is where its other classifications already
  live (`subgroup`, `excludes`), and one file per rule keeps agent-proposed diffs small.
- **Make `ruleset` optional, defaulting to `core`.** Rejected. See above: the default is wrong
  exactly where it matters, and wrong in the direction nobody notices.
- **Version rules now** — an effective-dated text per printing, heroes pinned to one. Rejected for
  now, with the `SA_62` example above as the worked case. The decision is "sets now, versions later",
  and the later is not scheduled.

## Consequences

- Every authored rule carries one more line. All 28 existing files are `core`; `make rules-lint`
  rejects a file without a `ruleset` and a `focus.`/`house.` slug without a gloss.
- **The ten golden files changed, and the calibration gate was not re-run.** `ruleset` is a rule-root
  key, and `test_calibration.py`'s Tier 1 grades *effect rows* against `TIER1_FIELDS`, which does not
  list it. No byte the backfill touched is an input to any of the ten recorded verdicts. The hashes in
  `tests/rules/golden/MANIFEST.yaml` are updated, the argument is recorded under `golden_edits` in
  `tests/rules/calibration/2026-09-21-sonnet/RUN.yaml`, and it is pinned by
  `test_ruleset_is_outside_what_tier_1_grades` so that adding `ruleset` to `TIER1_FIELDS` later cannot
  silently invalidate it.
- **The authoring agents now have to judge something about the page, not only about the mechanics.**
  That is a real new cost and a real new failure class, and the input makes it harder: the pipeline
  currently hands the agents `rules_i18n.description` from the Optolith seed, which carries no
  indication of whether a page was printed as optional. Both briefs say to flag the uncertainty
  rather than guess quietly, and `ruleset` joins `subgroup` and `excludes` in the driver's scalar
  diff — two readings disagreeing about it is a disagreement about the rule, because it decides
  whether the rule fires for everybody or for nobody.
- The recorded calibration proposals predate the field and are linted with a one-key waiver
  (`allow_missing_ruleset`), because editing captured agent output would falsify the measurement the
  gate grades. The next recorded run gets no waiver.
- **`rules.db` does not carry `ruleset` yet** and the build ignores the field. Filtering by active
  set, and the `source.title` column chapter rules need, are the engine plan's work; this ADR is the
  data half and the contract.
- The app gains an answerable question — *which rules are affecting this hero right now* — and, once
  the engine carries ids, a breakdown in which every line is a link. The three defects in the Context
  would each have been visible as a wrong citation rather than a plausible number.
- A rule can now be wrong in a new way: right mechanics, wrong set. It is at least a *stated* claim in
  a reviewable file, which none of the current Swift branches are.

## Related

- **ADR-0005** — opponent-side effects stay GM-adjudicated; unchanged here.
- **ADR-0006** — derived-value formulas and the rounding rule; named above as a rule category that
  belongs in our namespace.
- **ADR-0007** — the rule website is normative, `rules.db` is a generated artifact, and the
  `CHAP_` namespace this ADR generalises.
- **ADR-0008** — the effect schema, `EngineResult`, and the named-parameter vocabulary that the
  provenance decision extends.
