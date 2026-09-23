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

## Open points for the review

- **Stored special-ability split.** Heroes imported before the combat-group
  classification keep combat abilities in `generalSpecialAbilities`. Rule lookups here
  search both lists, so only the hero detail's section is wrong. The pipeline repaired
  it at launch (`SpecialAbilityClassificationRepair`, `983adff`/`e9fff04`); not ported.
- **Which groups are combat.** This branch: 3, 9, 10, 11 (`CombatSpecialAbilityGroup`,
  Befehle and Prügel excluded on purpose). The pipeline: 3, 9, 10, 11, 12.
- **`rules.db` tracked or generated.** This branch commits it on purpose (`bd9b069`);
  the pipeline untracked it and pinned its sources (`5529a74`, ADR-0012).
