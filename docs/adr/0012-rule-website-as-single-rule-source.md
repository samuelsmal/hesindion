# ADR-0012: The Rule Website as the Single Rule Source, rules.db as a Build Artifact

## Status

Proposed — under review. Accepted as ADR-0007 on `feat/rules-data-pipeline` (2026-09-21); imported for the rules rework, which reviews it before anything is built on it. Paths under `specs/rules/`, `scripts/rules_*` and `tests/rules/` live in the tag `archive/rules-data-pipeline`, not on this branch.

## Context

Rule data reaches the app through four independent authorities, none of which is the rules
themselves:

1. **`specs/data/rules.yaml`** — hand-authored structured effects for 26 rules, written early in the
   project and last touched 2026-03-08.
2. **`HARDCODED_EFFECTS` in `scripts/scrape_effects/scrape_effects.py`** — a *second* hand-authored
   copy of the same effects, kept as a "fallback" for when scraping fails. The two already disagree:
   the YAML gives Finte and Wuchtschlag `scope: combat`, the script gives them `scope: meleeAttack`.
   Nothing detects the divergence because nothing compares them.
3. **Optolith source YAML** at `/Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data/` —
   names, descriptions, prerequisites, costs and book/page references for every rule. It lives
   **outside the repository**, is not version-controlled, and carries no recorded version or
   provenance. A second machine cannot reproduce the build.
4. **`Hesindion/Resources/rules.db`** — a 2.9 MB SQLite binary that is **tracked**, was last written
   at `fafcc12` (2026-03-12) and has not been rebuilt since. There is no Makefile target for it, so
   in practice it is an input, not an output. It is also a standing violation of this repository's
   own Data Policy (*"Actual DSA rules content must NEVER be committed"*): `.gitignore:5` names the
   file, but the entry has never had any effect, because git does not apply ignore rules to a path
   that is already in the index. The policy was written, the guard was added, and the file stayed
   committed anyway — silently, for six months.

The actual source of truth — <https://dsa.ulisses-regelwiki.de/>, already named as the rules
reference in `AGENTS.md` — is consulted by no automated step. `scrape_effects.py` was written to do
this but knows six rule pages by hand and falls back to its hardcoded table.

Both editable copies can drift from the rule website, from each other, and from the printed rules as errata
land. The practical consequence is that a rule can be wrong in the app with no signal anywhere that
it is wrong, and there is no answer to the question "which file do I edit to fix a rule?" other than
"both, and also the script".

## Decision

**The rule website is normative.** Where the rule website and any local copy disagree, the rule website wins, and the
disagreement is a bug to be resolved by updating the local copy — never by editing the app.

**One authored store, and it holds no rule prose.** The Data Policy stands: DSA rule text is not
committed. What we author is our own *mechanical encoding* of a rule plus a pointer to where the
rule can be read — one YAML file per rule under `specs/rules/`:

```yaml
id: SA_62
subgroup: spezialmanoever      # mirrors rules.subgroup_id
source:
  url:     https://dsa.ulisses-regelwiki.de/…
  book:    US25001
  page:    249
  checked: 2026-09-20
  hash:    sha256:…            # of the normalised rule-website text — drift detection without storing it
effects: …                      # schema per ADR-0013
```

There is no `text:` field. Rule prose reaches the app the way it already does — through the
generated database, built from local source data. A reviewer reading an agent-proposed diff has the
`source.url` in that same diff and the text available locally, so the encoding stays reviewable
without the prose being versioned.

One file per rule, not one large file: agent-proposed diffs stay small, and unrelated rules cannot
conflict.

**`rules.db` becomes a generated, untracked build artifact.** `git rm --cached` removes it from the
index, which finally makes the existing `.gitignore:5` entry effective. `make rules-db` builds it;
`make rules-db-verify` rebuilds and compares a canonical SQL dump — not the binary, which SQLite
does not guarantee to be byte-stable — so a stale database fails the build rather than shipping.

**Optolith is demoted to a seed, and is pinned rather than vendored.** It supplies the rule ID
namespace that hero exports use (`SA_62`, `ADV_5`, …) and bootstraps the authored files; after
bootstrap it is authoritative for neither text nor mechanics. It cannot be vendored into the
repository — that would commit rule prose — so it is pinned instead: `specs/rules/SOURCES.yaml`
records its version and per-file checksums, and the build fails on a mismatch. A machine-local data
directory remains a prerequisite; an *unverified* one no longer is.

**Reconciliation is two steps, and only the first is deterministic.**

1. `make rules-sync-check` — fetch each rule's rule-website page, normalise the text, compare against
   `source.hash`. Pure code: no model involved. Output is a drift report naming the rules whose rule-website
   text no longer matches what we authored. Politeness delay and caching as in the existing scraper.
2. `make rules-sync-propose` — an LLM agent reads the drifted (or not-yet-authored) rule, and
   proposes a patch to that rule's YAML file: updated text, updated or new structured effects,
   refreshed `checked`/`hash`.

The agent **proposes only**. Its output is a diff a human reads and commits. It never writes
`rules.db`, never edits Swift, and never commits. Structured effects are mechanical claims about
rules; a model drafting them unsupervised is exactly the failure this ADR exists to prevent.

**`HARDCODED_EFFECTS` is deleted** along with the scraper's fallback path. A missing rule must be
visibly missing, not quietly substituted.

## Considered Alternatives

- **Keep the YAML as the only store and drop the database.** Rejected: the app needs indexed lookup
  and full-text search over ~2,000 rules at runtime (`rules_fts`), and parsing YAML on a phone at
  launch is the wrong trade. The database is a good *artifact*; it was only ever a bad *source*.
- **Make the database the authored store and drop the YAML.** Rejected: a 2.9 MB binary cannot be
  code-reviewed. The whole point of the agent flow is that a human reads the proposed change, and a
  diff of a SQLite file is unreadable.
- **Scrape the rule website at build time, with no authored copy.** Rejected on three counts: the build stops
  being reproducible and offline; structured effects cannot be derived from prose reliably enough to
  go unreviewed; and it puts avoidable load on someone else's server on every build.
- **Fully automatic sync — the agent commits its own patches.** Rejected. A wrong effect row is
  indistinguishable from a right one at the table until a rule misfires mid-session. Review is the
  control that makes the rest of this safe.
- **Keep Optolith as the text authority and use the rule website only to spot-check.** Rejected: Optolith
  lags errata, and this ADR exists because "two authorities, no arbiter" is the current bug.

## Consequences

- There is one answer to "where do I fix a rule": its file under `specs/rules/`. The database is
  never edited, and the second hand-authored copy is gone.
- Drift from the rule website becomes **detectable and dated**. `source.checked` says when a rule was last
  verified; `make rules-sync-check` says which rules have moved since.
- The build becomes **verifiable** rather than inherited: the database is generated, and the source
  data it is generated from is checksummed against `SOURCES.yaml`. It does not become
  self-contained — a fresh clone still needs the local source data, which is the price of keeping
  rule prose out of git. `make rules-db` fails with a clear message when it is missing or has
  drifted, instead of the build silently using a six-month-old database.
- The Data Policy becomes enforceable for the first time: `git rm --cached Hesindion/Resources/rules.db`
  makes the long-dormant `.gitignore` entry effective, and nothing in `specs/rules/` carries rule
  text.
- Bootstrapping costs a one-time mapping from rule ID to rule-website URL. The Optolith data carries
  `src: {id, firstPage}` for every rule, which narrows the search but does not eliminate the manual
  confirmation. This is a real cost, paid once per rule, and only for rules we choose to author.
- Rules the rule website changes but nobody re-authors stay at their last verified text and are reported as
  drifted. Stale-but-labelled is the intended failure mode; silently-wrong is the one we are leaving.
- Ulisses' rule text is redistributed through the bundled database, as before, but it stops being
  redistributed through git. `source.url` and `source.hash` make the origin of each encoded rule
  explicit, which is the precondition for honouring a future licensing request.
- The agent flow is an *authoring* tool. It runs on a developer machine against the repository; the
  app ships no model dependency and no network dependency for rules.

## Amendment (2026-09-21): the authored store covers chapter rules, not only rules with an Optolith id

The original decision says "one YAML file per rule under `specs/rules/`" and takes for granted that
a rule has an Optolith id, because Optolith supplies the id namespace. Some rules do not. A DSA 5
*chapter* page states mechanics that bind anyone in the situation it describes — mounted combat,
Beengte Umgebung, multiple defences — and no ability owns them, so Optolith has no id for them and
the corpus had nowhere to put them.

That gap had a cost already being paid: the app hardcoded those constants in Swift, and the corpus
looked complete without them. It also produced a wrong ruling, and the wrongness was about
*existence* rather than about a value: one clause of
<https://dsa.ulisses-regelwiki.de/Reiterkampf.html> was ruled non-existent while the page published
it and the app had implemented it for months. **"There is no clause" is what a reviewer concludes
when the corpus has no shape that could hold one** — the ruling followed from the missing namespace,
not from the page. `specs/rules/SA_43.yaml` and `specs/rules/CHAP_Reiterkampf.yaml` are where the
corpus stands on it today; what either file records is in the file and is not restated here.

**Chapter pages are authored files like any other, under a second id namespace.** A chapter id is
`CHAP_` plus the page's own URL stem, ASCII-folded (`CHAP_Reiterkampf`). Everything else is
unchanged: same schema, same linter, same `source` block, same `make rules-sync-check` drift
detection, no rule prose.

Why the URL stem rather than a number:

- **It cannot collide with Optolith.** Every Optolith id ends in digits and every chapter id ends in
  letters, so the two namespaces are disjoint by construction rather than by convention — including
  against Optolith ids that do not exist yet.
- **It needs no registry.** A sequential `CHAP_1` would need a file mapping numbers to pages, and
  this ADR exists because "two authorities, no arbiter" is a bug. The id derives from `source.url`,
  which is already in the file, and `scripts/rules_lint/lint.py` checks the derivation — so "one
  file per page, and the id says which page" is enforced, not documented.
- **It is stable exactly as far as the provenance is.** If the page moves, `make rules-sync-check`
  says so; renaming the file is then the same deliberate act as re-verifying the rule.

The ASCII fold is not injective, and two known ways it can collapse two pages onto one slug are
recorded here rather than coded around: the transliteration order keeps `Grätsche`/`Gratsche` apart
(the umlaut becomes `ae` before the fold) but collapses `Vorstoß`/`Vorstoss` (both become
`Vorstoss`), and `_TRANSLITERATE` is keyed on precomposed characters with no NFC normalisation, so an
NFD-encoded URL would skip the table entirely and lose the umlaut to the fold. Neither pair is
reachable from today's site, and both fail loudly rather than silently — one file per page plus
"filename must match id" means two pages sharing a slug cannot both be authored — so the cost of
carrying them is a paragraph, while normalising pre-emptively would be a guess at which of two
spellings the site will one day use.

Consequences, beyond those of the original decision:

- Chapter rules have no `rules_i18n` row, because there is no Optolith entry to carry text. The
  "degrade to rule text" fallback (ADR-0013) therefore cannot fire for them; they degrade to their
  own authored `reminder` rows instead, which is why `CHAP_Reiterkampf` carries seven of them.
- `scripts/build_rules_db/build_db.py` creates the `rules` row for a chapter id itself, under a new
  `chapter` category. Without that its effects would be skipped with a warning — the silent-drop
  failure this pipeline exists to stop.
- The pipeline does not propose chapter rules. `scripts/rules_sync/propose.py` selects by Optolith
  group and subgroup out of `rules.db`, so a chapter page has to be authored by hand against its
  page, as `CHAP_Reiterkampf` was. Whether the two-agent pipeline should learn to read them is a
  question for after the calibration gate passes.

## Amendment (2026-09-21): provenance is the deterministic half's, and the cross-check has one blind spot

This ADR's Decision describes the propose step as an agent that proposes "updated text, updated or
new structured effects, refreshed `checked`/`hash`". The last of those is withdrawn, and the reason
is the ADR's own: a hash is a claim that a specific page was fetched and normalised, and an agent
cannot make that claim truthfully. A guessed URL or an invented hash is worse than none, because it
converts "unverified" — a state `make rules-sync-check` reports and a reviewer can act on — into a
silent, permanent `ok`.

**An authoring agent never emits a `source:` block.** Provenance is computed by the driver, which has
exactly three outcomes and invents nothing: carry forward the existing file's real provenance; else
write the `unverified` placeholder this ADR's checker already reports; else, with `--verify-source`,
re-fetch through the checker's own fetcher and re-hash through the shared normaliser — and on a
network or content-container failure, carry the old values forward rather than fabricate new ones. A
`source:` block that appears in agent output anyway is discarded **and reported**, because silently
dropping it would hide an agent doing the one thing it was told not to.

**The two-agent cross-check detects independent error and has no defence against a shared input.**
This ADR justifies the propose step's safety with "the agent proposes; a human commits", and the
implementation strengthened that with a second agent that never sees the first one's answer. That
design's guarantee is narrower than it looks: both agents read the *same* third-party rule text, so
anything wrong with that text — stale prose, or instructions injected into it — steers both
identically, and the run reports `agree / ok / written`. The gate demonstrated the benign half of
this for real, on two rules, with both agents confidently agreeing on an encoding the normative page
contradicts.

The accepted position, stated so it is not rediscovered as news: **exfiltration risk is low**
(read-only tools by construction, git-ignored output, a closed schema), **integrity risk is medium**,
and the mitigation — fencing the rule text and declaring it untrusted data in both prompts and both
briefs, plus keeping only the first envelope per rule id so an injected marker cannot re-open a
resolved one — is a *prompt instruction, not a mechanism*. That is acceptable while the pipeline runs
on a developer machine against a human review queue, which is what this ADR already requires. It is
not acceptable as the basis for trusting a run at wave scale, and it is a standing reason why "author
and verifier agree" is a weaker signal than it reads as.

## Related

- **ADR-0013** — the effect schema the authored files carry, and the engine that consumes it.
