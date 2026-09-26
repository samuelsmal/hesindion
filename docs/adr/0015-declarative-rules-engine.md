# ADR-0015: A Declarative Rules Engine, and the Format That Feeds It

## Status

Accepted. Supersedes ADR-0012, ADR-0013 and ADR-0014, which were never accepted and describe
`main` — see `docs/plans/2026-09-24-rules-engine-design.md` §13.

## Context

ADR-0012 through ADR-0014 designed a data pipeline for the app's existing engine: an authored
YAML store, a typed effect union bolted onto `ModifierContext`/`ModifierEngine`, and runtime
provenance added to `ModifierLine`. None of the three was ever accepted on `main` — they were
imported from `feat/rules-data-pipeline` for review on this branch, which is what their own
Status lines say. Working the plan against them (`docs/rules-rework/`, the 22 worked examples,
the whole-session reviews cited inside ADR-0013 and ADR-0014) surfaced a harder problem than any
one of the three addresses on its own:

- **The requirement is all three at once.** A developer needs to read a rule file clause by
  clause against what the app does with it; a player needs every number on screen to say which
  rule produced it; an exported log entry needs to become a regression test. ADR-0012 covers
  where the data lives, ADR-0013 covers the effect union, ADR-0014 covers provenance — but they
  were designed as three separate additions to the same `ModifierEngine`/`ModifierContext` core,
  and that core has neither a phase pipeline nor a notion of an unanswered question. Provenance
  bolted onto `ModifierLine` after the fact is a label; a `when` that can be *unknown*, not just
  true or false, is a different evaluator.
- **"Effects are a closed typed union of nine cases" undercounted the corpus.** The worked
  examples needed staged checks (3W20 Talentproben, the 1W20 combat roll's dice → result →
  consequence chain), pools that fall through in a stated order, processes that outlive a round,
  and rulings that must apply *nothing* while still open. None of that is a `ModifierLine`; it is
  state carried between queries, which ADR-0013's `resolve(context) -> EngineResult` does not
  model.
- **Two engines side by side is the four-authorities problem in a new place** (ADR-0012's own
  diagnosis). ADR-0013 rejected "incremental migration behind a flag" for exactly this reason,
  but its replacement was still designed as edits to the engine already running the app. Building
  the new evaluation core beside the old one, wholly separate, and switching a domain only when
  its screen can show every line's origin, avoids relitigating that rejection while still
  shipping incrementally.
- **The vocabulary the three ADRs left open stayed open under those hands.** ADR-0013's own
  amendment records `parameterOverride.parameter` as "the one open field with no registry, and it
  has already cost a rule" — a free string an agent invented where the authoring brief's
  `UNENCODED:` escape hatch was the mandated answer, and both the linter and the two-agent
  cross-check passed it. A closed vocabulary, checked once by `rulec` and mirrored once in Swift,
  is the fix this design commits to instead of a registry of open strings.

None of this is a rejection of the three ADRs' diagnoses — the four authorities, the missing
provenance, rules as data rather than per-rule code, opponent-side effects staying
GM-adjudicated (ADR-0005, unaffected) — only of the shape of engine they designed to fix them.

## Decision

Built and specified in full in `docs/plans/2026-09-24-rules-engine-design.md`; summarised here,
not restated:

| Question | Decision |
|---|---|
| How rules reach the app | Python (`rulec`: `make rules-check` validates the YAML, `make rules-json` compiles rules and situations to JSON; the design's table says `make rules-db`, which stays the old engine's target); Swift reads JSON. No YAML parser in the app |
| Where the rules live | `specs/rules/`, beside `vocabulary.json`: the rule folders (`abilities/`, `core/`, …) and `rulings.yaml` directly in it, with `situations/`, `sweeps/`, `checks.yaml`, `RULINGS.md`, `MIGRATION.md` and `conflict-fingerprints.json`. `scripts/rulec/layout.py` owns this layout; `rulec` and the review tools (`scripts/rules_review/`) read it from there. The sample heroes the situations name are in `specs/heroes/`. The plain-words write-ups of examples 1–22 stay in `docs/rules-rework/examples/`. Moved there from `docs/rules-rework/examples/` on 2026-09-26: the rules are what the engine runs, not a worked example |
| When the engine is done | Every situation in examples 1–22 passes, except those resting on an open ruling: those run and are reported *pending*. `appToday` is never tested |
| How it replaces the old engine | Built and tested beside it, not wired in; screens switch one domain at a time, each switch deleting that domain's old code. Never a union of two engines |
| Encoding | Declarative: a closed vocabulary of effect verbs on a fixed phase pipeline. A mechanic that does not fit becomes a new verb with an interpreter and a test, never per-rule code |
| Naming | One language everywhere (§3.1): every key, verb, target, fact and reason code is lowerCamelCase and spelled the same in YAML, JSON and Swift — no mapping layer |

In shape: `vocabulary.json` is the one closed contract between the authored YAML, `rulec` (the
compiler, replacing `catalog.py`) and `Packages/RulesEngine`'s Swift (`Vocabulary.swift`, a test
holding the two identical). A rule file's clauses each carry exactly one of `effects`,
`unencoded` or `none`, so the compiler can prove no clause is dropped. Twenty-two effect verbs run
through a fixed seven-phase pipeline (base → level → add → lines → multiply → cap → legality);
every `when` is evaluated against **facts with owners**, so a fact nobody has stated produces a
**question**, never a guess, and an effect resting on an open ruling applies nothing (§4.7). Every
output line carries its full provenance — rule, clause, `via` chain, ruling, and each fact used
with who stated it (§5.5) — as a first-class field of the evaluator's own output type, not an
afterthought on a modifier line. Checks (talent/spell/liturgy 3W20, the combat 1W20 roll) are
staged procedures over the same targets (§6); pools, processes, item state and the game clock are
data in a `Situation`, changed only by events (§7). The talent/spell → attribute table that used
to come from `rules.db` at runtime now lives in `specs/rules/checks.yaml`,
compiled into `build/rules/situations.json` — the engine package and its tests read no `rules.db`
at all.

## Consequences

- **The cut-over gates (design §9).** The engine is built beside `RuleEvaluator`/`ModifierEngine`
  and wired into no screen yet. Domains switch in a fixed order — derived values and the sheet;
  melee attack and defence; damage; Zustände and the cap; talent checks; spells and liturgies;
  ranged combat — and a domain switches only when every decided situation of that domain passes,
  its screen shows every line with its origin (the *Auslegung* marks, the not-applied list), its
  log entries use the §8 format, and the old `*Modifiers.swift` definitions and catalog entries
  for that domain are deleted in the same change. Never a union of two engines for the same
  domain. When the last domain moves, `RuleEvaluator`, `ModifierEngine`, `rules-catalog.yaml`, its
  snapshot and `RuleVocabulary` are deleted outright.
- **The current state, measured.** `make test-rules-engine` (all situations files) reports
  `harness: 223 passed, 0 failed, 15 pending, 71 conflict, 0 unsupported` over 309 situations
  (`specs/rules/MIGRATION.md`). The design's done criterion (every situation
  passes, except those resting on an open ruling, which are reported pending) holds except for
  the 71 conflicts, which wait on the owner's decisions (ruling R60): situations whose expectation
  the engine, following the rule text, does not meet, each recorded with its reasoning under that
  file's "Expectation conflicts for the owner" section in three categories (ruling R77): (a) the
  expectation is wrong per the rule text, 52; (b) an input convention, a sheet base with the item
  and shield modifiers folded in (R66, see the base contract below), 16; (c) rule data not
  written, 3. Nothing fails and nothing is unsupported; every pending situation is explained by an
  open ruling on its path. Each conflict's mismatches are recorded as fingerprints
  (`conflict-fingerprints.json`, ruling R78), so a new mismatch inside a listed situation still
  fails. No domain has switched yet — this is the engine passing its own acceptance suite, not the
  app's behaviour changing.
- **The base contract.** A sheet base handed to the engine (`Situation.base`) is the unfolded
  base: the technique or sheet value without the item's and the shield's modifiers, which the
  engine adds as lines after it (ruling R66; at-pa-modifikatoren.M1: "erst nach der Ermittlung der
  Basiswerte"). The app's current sheet values are folded (`OptolithImportService` adds a weapon's
  AT/PA-Mod and a shield's doubled PA bonus into the AT and PA it stores), so a domain that
  switches must hand the engine the unfolded values, not the ones the sheet shows today.
- **The vocabulary is closed, not merely reviewed.** A new verb, target, fact, payload field or
  reason code is added in one change to `specs/rules/vocabulary.json` **and**
  `Packages/RulesEngine/Sources/RulesEngine/Vocabulary.swift`, with a `rulec` test and (for a verb)
  an interpreter test — never `if rule.id == "SA_…"` anywhere in Python or Swift. This closes the
  exact hole ADR-0013's amendment recorded against `parameterOverride.parameter`.
- **Situations are the acceptance data, not something to fit.** An executor must not change a
  situation's `expect` values, or a clause's `text`, to make a test pass; a wrong-looking
  expectation is reported against the situation id, not silently adjusted (global constraint,
  design §10.2).
- **ADR-0012 through ADR-0014's diagnoses are not lost**, only their fix. The four authorities
  problem, the missing runtime provenance, rules-as-data, and opponent-side effects staying
  GM-adjudicated (ADR-0005) are all still true and are addressed by this design instead: `rulec` +
  `vocabulary.json` is the one authority the three ADRs wanted; every line's `via`/fact/owner
  chain is the provenance ADR-0014 wanted, built into the evaluator's output type rather than
  added to `ModifierLine`; the closed verb vocabulary is "rules are data" without the effect union
  ADR-0013 found undercounted.
- **`rules.db` still leaves git**, as ADR-0012 already decided and Task 38 of this plan carries
  out — that decision survives the supersession unchanged; only the engine reading structured
  rule effects is replaced.
- Reviewing an ADR that was never accepted, by superseding it, is unusual but deliberate: the
  three files are not deleted (ADRs are never deleted), and their Context sections remain the
  historical record of the defects that motivated this work in the first place.

## Related

- `docs/plans/2026-09-24-rules-engine-design.md` — the full design this ADR records.
- `docs/plans/2026-09-24-rules-engine-plan.md` — the implementation plan and its task log.
- **ADR-0005** — opponent-side effects stay GM-adjudicated; unaffected by this design.
- **ADR-0012, ADR-0013, ADR-0014** — superseded; their Context sections stand as the record of
  the defects this design was written to fix.
