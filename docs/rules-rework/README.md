# Rules rework — inputs

The rules engine, the sourcing of rules and their attribution are to be reworked: first
a review, then the implementation. This folder holds what the earlier attempt learned.

That attempt lived on `feat/rules-data-pipeline` (PR #28). It branched from `main` at
`487ce37`, in parallel with this branch rather than on top of it, so the two built
different rules systems on the same files. It is archived as the tag
`archive/rules-data-pipeline`; its code, `specs/rules/*.yaml`, scripts and Python tests
were not brought over. Paths in these documents that point there resolve in the tag.

## What was imported

- ADR-0012, ADR-0013, ADR-0014 — the pipeline's ADR-0007/0008/0009, renumbered because
  this branch already used 0007–0011. Status *Proposed*: they are review input, not
  decisions this branch has taken.
- `2026-09-20-rules-pipeline-and-authoring.md` — the pipeline's plan.
- `rules-pipeline-status.md`, `rules-pipeline-next-steps.md`,
  `rules-pipeline-review-findings.md`, `rules-migration-reconciliation.md`.

## Fixes ported to this branch

- Belastungsgewöhnung eases 1 BE per Stufe, not 2 (pipeline `3c3ff91`).
- The mounted Belastung relief eases Kampfproben only (`030230e`).
- GS by species, Zwerge 6, with a launch repair (`f276b14`, GS half of `86bf436`).

## Decisions (2026-09-23)

- **The requirement.** A person can check that the rules are applied correctly and
  completely — as a developer, reading the rule files, and as a player, in game, where
  every number says which rule it came from and every rule that did not apply says why.
  The rules engine, the rule format and the way rules are authored may be rewritten
  wholesale to meet it.
- **Rules are committed as YAML**, both the rules of special abilities, advantages and
  disadvantages and the core rules without an Optolith id (Reiterkampf, Belastung, …).
  The copyright question is deferred, to be settled with Ulisses.
- **One file per rule**, grouped by kind, instead of the one `rules-catalog.yaml`
  (3,360 lines, 2,625 of its entries `todo` stubs). A rule without a file is `todo`;
  coverage is computed, not stored as stubs. Each file carries its own source (page URL,
  hash, date checked) and whether a person has reviewed it.
- **`rules.db` leaves git.** It is a binary derived from the rule files and the Optolith
  YAML, and is built, not committed. This reverses `bd9b069` and the Data Policy
  bullet in `AGENTS.md`, which both need updating when it lands.
- **The Optolith YAML moves into this repository.** `rules.db` is already built from the
  export at `DSA_DATA` (`../../dsa_companion_data/Data`), which is not under version
  control, so no build is reproducible. The parts `build_db.py` reads (`de-DE/`, `univ/`,
  about 4 MB) are vendored so the database builds from the repository alone.
- **Worked examples before any design.** A set of core rules and special abilities is
  written up with concrete situations and the numbers the app must show, independent
  of any encoding. They are the acceptance cases every design is checked against, and
  the place surprises are meant to show up early. See [`examples/`](./examples/).
- **Rulings are data, answered in the files, not in chat.** Each lives in the rule file it
  interprets, with lettered options and a recommendation; the owner answers by editing
  `answer:`; decisions are signed with a GitHub handle; `examples/RULINGS.md` is the generated
  index. See [`examples/README.md`](./examples/README.md#how-rulings-are-kept).

## What the pipeline's error rate was

The calibration gate's 7/10 (0.58 pooled over four runs) is mostly not the model
misreading rules. Of the best run's three failures, two were the driver feeding the
Optolith text where the rule website differs (`SA_661`: TP where the page says PA;
`SA_62`: a clause missing), and one was the schema having no shape for the rule
(`SA_41`: a row shift in the armour table, which the golden file replaced by a derived
BE value, while `shiftSteps` was scaled by tier in `schema.json` and written as a running
total per the brief). Grading was all-or-nothing per rule over ten rules. The lesson for
the rewrite: fix the input (the page) and a vocabulary in which every clause has exactly
one readable encoding or is explicitly marked unencoded. The one model-attributable
signal is `SA_43` dropping its `mounted` condition in 2 of 5 runs.

In the tag: `scripts/rules_sync/propose.py:183-213` (text source),
`.claude/agents/rule-author.md`, `specs/rules/schema.json:181-183`,
`tests/rules/calibration/2026-09-21-sonnet/` against `specs/rules/SA_*.yaml`.

## Open points for the review

- **Stored special-ability split.** Heroes imported before the combat-group
  classification keep combat abilities in `generalSpecialAbilities`. Rule lookups here
  search both lists, so only the hero detail's section is wrong. The pipeline repaired
  it at launch (`SpecialAbilityClassificationRepair`, `983adff`/`e9fff04`); not ported.
- **Which groups are combat.** This branch: 3, 9, 10, 11 (`CombatSpecialAbilityGroup`,
  Befehle and Prügel excluded on purpose). The pipeline: 3, 9, 10, 11, 12.
- **ADR-0012 to 0014 describe `main`, not this branch.** Their Context sections name
  `rules.yaml`, the scraper, a dead `RuleEffectModifiers` and circular combat
  classification — all gone here, replaced by the catalog and `RuleEvaluator`. They
  need rewriting against this branch before any of them is accepted.
