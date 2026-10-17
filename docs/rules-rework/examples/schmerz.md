# Example 4 — Schmerz, the Zustand cap and "Zustand ignorieren"

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| COND_6 | Schmerz (Zustand) | <https://dsa.ulisses-regelwiki.de/Sta_Schmerz.html> | Regelwerk p. 34 |
| GRW_zustandsbegrenzung | Zustände — adding up, the −5 cap, eight Stufen (core rule) | <https://dsa.ulisses-regelwiki.de/GR_Zustand.html> | Regelwerk p. 31f |
| — | Schicksalspunkte, the use "Zustand ignorieren" | <https://dsa.ulisses-regelwiki.de/GR_Schicksalspunkte.html> | Regelwerk p. 29ff |
| COND_1 | Belastung — as the second Zustand in the mix | [`rules/conditions/COND_1.yaml`](../../../specs/rules/conditions/COND_1.yaml) | Example 1 |

## Clauses

**Schmerz (COND_6)**

- **SZ1** Wounds, poison, spells and more cause Schmerz; at worst it incapacitates.
- **SZ2** At Stufe IV, a Selbstbeherrschung (Handlungsfähigkeit bewahren) check keeps the hero
  able to act.
- **SZ3** From LP: one Stufe each at ¾, ½ and ¼ of LE, and one more at 5 LP or fewer. Healing
  above a threshold removes its Stufe.
- **SZ4** Unless stated otherwise, one Stufe goes every 4 hours.
- **SZ5** Stufe I–III: all checks −1/−2/−3, GS −1/−2/−3. Stufe IV: Handlungsunfähig, otherwise all
  checks −4.

**Zustände**

- **Z1** Stufen of the same Zustand add up.
- **Z2** Penalties of different Zustände add up.
- **Z3** The total penalty from Zustände is at most 5, until the summed Stufen fall below 5.
- **Z4** A Zustand from a spell or liturgy that caused Handlungs- or Bewegungsunfähigkeit ends
  when the spell does.
- **Z5** Eight or more Zustandsstufen in total: Handlungsunfähig, even with no single Stufe IV.
- **Z6** Short-term changes from Zustände never recompute derived values.

**Schicksalspunkte — Zustand ignorieren**

- **SP-zustand** 1 Schip: ignore **all** Zustände for one Kampfrunde.

## Situations

In [`situations/schmerz.yaml`](../../../specs/rules/situations/schmerz.yaml), S1–S12. The rules as draft YAML:
[`COND_6`](../../../specs/rules/conditions/COND_6.yaml), [`zustaende`](../../../specs/rules/core/zustaende.yaml),
[`schicksalspunkte`](../../../specs/rules/core/schicksalspunkte.yaml).

Where the app is wrong:

- **Schmerz never lowers GS** (`Hero.effectiveGeschwindigkeit`, `Hero.totalGsPenalty`); the page
  gives GS −1/−2/−3 (S1, S2), and at Stufe IV the hero cannot move at all, GS 0, whether or not
  the check below passed (ruling `COND_6.schmerz-iv-gs`) (S3, S12).
- **Stufe IV has no Selbstbeherrschung check** — the hero is Handlungsunfähig outright
  (`StateCatalog` `schmerz`, `handlungsunfaehigAtLevel: 4`). Per ruling
  `COND_6.schmerz-iv-check` it is rolled before each action the hero wants to take; a success
  lets that action through at −4 (S3, S12).
- **The Zustand cap reaches checks only**: per ruling `zustaende.cap-scope` (answered against
  the recommendation) the −5 caps GS and INI too, so Schmerz III in Platte is GS −5,
  not −6 (S6).
- **A Schip "Zustand ignorieren" leaves Belastung** (`SharedModifiers.encumbrance`,
  `Hero.hasIgnorableZustand`); per ruling `schicksalspunkte.schip-ignore-belastung` it is
  ignored with every other Zustand (S8).

Confirmed correct: the LP thresholds, compared exactly (ruling `COND_6.schmerz-thresholds`, S1,
S4); Schmerz reaches every check including talents and spells (S11); the −5 cap on checks
with its correction line (`ModifierEngine.applyingZustandCap`) (S6); eight Stufen make the hero
Handlungsunfähig, Belastung counted (`Hero.isHandlungsunfaehigFromZustaende`) (S7); the Schip
gives back a round at Stufe IV but not from Bewusstlos (S9, S10).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md) — look for `COND_6`,
`zustaende` and `schicksalspunkte`. The one ruling found already decided in the code
(`schip-lifts-incapacity`, 2026-09-20) is recorded in `schicksalspunkte` with its source.
