# Example 12 — Kampfreflexe

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_51 | Kampfreflexe I–III | <https://dsa.ulisses-regelwiki.de/KSF_Kampfreflexe.html> | Regelwerk p. 248 |

It meets [Example 1](./belastung.md)'s Belastung (COND_1.B3, INI −1 per Stufe) and the armour's
extra INI penalty, and [Example 2](./reiterkampf.md)'s RK1 (a rider uses the mount's INI base).

## Clauses

- **KR1** The INI Basiswert rises by 1 per Stufe.
- **KR2** Prerequisites (IN 13 / 15 / 17) — not a roll.

The one thing this rule does is change a **derived value**, not a check. So its line belongs in
the INI Basiswert's own breakdown on the hero sheet — the way Eisern belongs in the Wundschwelle's
(ADR-0006) — and from there it reaches every initiative roll.

## Situations

In [`situations/kampfreflexe.yaml`](../../../specs/rules/situations/kampfreflexe.yaml), 12.1–12.5. The rule as draft
YAML: [`SA_51`](../../../specs/rules/abilities/SA_51.yaml).

Where the app is wrong: Kampfreflexe is ignored everywhere. The import computes INI as (MU+GE)/2
with a bonus of 0 (`OptolithImportService`, `DerivedValueFormulas.initiative`), the catalog has
SA_51 as `todo`, and no code reads the SF. Every hero with it rolls initiative 1–3 too low
(12.1–12.4), and mounted, per ruling, from the mount's base as well (12.5). Belastung and the
armour's extra INI penalty already combine correctly with the base; they only need the right base.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md) — look for `SA_51`.
`SA_51.kampfreflexe-mounted` is decided: mounted, Kampfreflexe adds to the mount's INI base (12.5).
`reiterkampf.rider-ini` is decided the other way for the rider's Belastung: it does not come off
the mount's base (12.5 has no Belastung line).
