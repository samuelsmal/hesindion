# ADR-0007: Regelwiki as the Single Rule Source, rules.db as a Build Artifact

## Status

Accepted

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

Both editable copies can drift from the wiki, from each other, and from the printed rules as errata
land. The practical consequence is that a rule can be wrong in the app with no signal anywhere that
it is wrong, and there is no answer to the question "which file do I edit to fix a rule?" other than
"both, and also the script".

## Decision

**The Regelwiki is normative.** Where the wiki and any local copy disagree, the wiki wins, and the
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
  hash:    sha256:…            # of the normalised wiki text — drift detection without storing it
effects: …                      # schema per ADR-0008
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

1. `make rules-sync-check` — fetch each rule's wiki page, normalise the text, compare against
   `source.hash`. Pure code: no model involved. Output is a drift report naming the rules whose wiki
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
- **Scrape the wiki at build time, with no authored copy.** Rejected on three counts: the build stops
  being reproducible and offline; structured effects cannot be derived from prose reliably enough to
  go unreviewed; and it puts avoidable load on someone else's server on every build.
- **Fully automatic sync — the agent commits its own patches.** Rejected. A wrong effect row is
  indistinguishable from a right one at the table until a rule misfires mid-session. Review is the
  control that makes the rest of this safe.
- **Keep Optolith as the text authority and use the wiki only to spot-check.** Rejected: Optolith
  lags errata, and this ADR exists because "two authorities, no arbiter" is the current bug.

## Consequences

- There is one answer to "where do I fix a rule": its file under `specs/rules/`. The database is
  never edited, and the second hand-authored copy is gone.
- Drift from the wiki becomes **detectable and dated**. `source.checked` says when a rule was last
  verified; `make rules-sync-check` says which rules have moved since.
- The build becomes **verifiable** rather than inherited: the database is generated, and the source
  data it is generated from is checksummed against `SOURCES.yaml`. It does not become
  self-contained — a fresh clone still needs the local source data, which is the price of keeping
  rule prose out of git. `make rules-db` fails with a clear message when it is missing or has
  drifted, instead of the build silently using a six-month-old database.
- The Data Policy becomes enforceable for the first time: `git rm --cached Hesindion/Resources/rules.db`
  makes the long-dormant `.gitignore` entry effective, and nothing in `specs/rules/` carries rule
  text.
- Bootstrapping costs a one-time mapping from rule ID to wiki URL. The Optolith data carries
  `src: {id, firstPage}` for every rule, which narrows the search but does not eliminate the manual
  confirmation. This is a real cost, paid once per rule, and only for rules we choose to author.
- Rules the wiki changes but nobody re-authors stay at their last verified text and are reported as
  drifted. Stale-but-labelled is the intended failure mode; silently-wrong is the one we are leaving.
- Ulisses' rule text is redistributed through the bundled database, as before, but it stops being
  redistributed through git. `source.url` and `source.hash` make the origin of each encoded rule
  explicit, which is the precondition for honouring a future licensing request.
- The agent flow is an *authoring* tool. It runs on a developer machine against the repository; the
  app ships no model dependency and no network dependency for rules.

## Related

- **ADR-0008** — the effect schema the authored files carry, and the engine that consumes it.
