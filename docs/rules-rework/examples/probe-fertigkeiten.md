# Example 22 (probe) — Fertigkeitsproben, Begabung, Fertigkeitsspezialisierung

**Status: draft, probe.** Pages read 2026-09-24. Written to find out whether rules outside melee
need engine concepts the draft vocabulary lacks. The hero is generic, not Boronmir.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| fertigkeitsproben | Fertigkeitsproben, QS, Modifikatoren, Kritisch, Patzer | <https://dsa.ulisses-regelwiki.de/grundregeln/fertigkeitsproben.html> and four sub-pages | Kodex des Schwertes pp. 15–18 (as the wiki names it) |
| ADV_4 | Begabung | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Begabung> | Regelwerk p. 163 |
| SA_9 | Fertigkeitsspezialisierung (Talente) | <https://dsa.ulisses-regelwiki.de/SF_FertigkeitsspezialisierungTalente.html> | Regelwerk p. 216 |

## Clauses

**Fertigkeitsproben** (core)

- **FP1–FP5** Three W20, each against one attribute. The FW is a pool, spent on the points by
  which a die exceeds its attribute. The check succeeds if the pool does not go below 0, and
  whatever is left is the FP.
- **FP2** If an effective attribute is 0 or less, the check cannot be made at all.
- **FP8** Every talent check names an Anwendungsgebiet.
- **QS1, QS2** FP map to QS 1–6 through a table. A success with 0 FP counts as 1 FP.
- **FM1, FM2** A modifier applies to all three attributes, not to the FW. FM2 is the GM's scale
  of modifiers.
- **KR1–KR3, PZ1** Doppel-1 is an automatic success, Doppel-20 an automatic failure, and
  Dreifach-1/20 are more of each. There are no confirmation rolls.

**Begabung (ADV_4)**

- **B1, B2** Once per check on the chosen Fertigkeit, reroll one of the three dice after seeing
  them. The better of the two rolls counts.
- **B5** It cannot be used on a Doppel-20 or Dreifach-20.
- **B7** It combines with Schips, before or after.
- **B3, B4, B6, B8–B10** Purchase rules only.

**Fertigkeitsspezialisierung (SA_9)**

- **FS1** +2 on the **FW**, not on the attributes, when the specialised Anwendungsgebiet applies.
- **FS2–FS5** Purchase rules only.

## Rulings

New, both open:

- `SA_9.spezialisierung-when`: how the check knows its Anwendungsgebiet. The recommendation is
  that every talent check carries one, picked on opening.
- `fertigkeitsproben.crit-qs`: what QS a Doppel-1 has. The recommendation is FP = double the FW
  where the talent's own entry says so, otherwise the FP as rolled.

## Situations

[`situations/probe-fertigkeiten.yaml`](./situations/probe-fertigkeiten.yaml), 22.1–22.9.

## What the app gets wrong

| Finding | Where | Basis | Situation |
|---|---|---|---|
| No specialisation is ever applied. Checks carry no Anwendungsgebiet, and the sheet shows the raw `sid2` ("Fertigkeitsspezialisierung: 2") | `TalentProbeModal`, `Situation`, `OptolithImportService` (displaySid), catalog SA_9 `todo` | page (FS1, FP8) | 22.1 |
| Adding the +2 by hand is only possible as a modifier, which changes the attributes instead of the FW and can give a higher QS | `SkillCheckModal.modifiers` | page (FS1, FM1) | 22.3 |
| Begabung does not exist; the only reroll is the Schip, and only on a failure | catalog ADV_4 `todo`, `SkillCheckModal.isRerollEligible` | page (B1) | 22.4, 22.7 |
| Every Kritischer Erfolg is QS 6, and the talent's own critical text is not shown | `SkillCheckEngine.SkillCheckOutcome.qualityLevel` | open ruling `crit-qs` | 22.8 |
| A check with an effective attribute of 0 or less can still be rolled | `SkillCheckModal`, `SkillCheckEngine.evaluate` | page (FP2, FM1) | 22.9 |
| The modifier can be set per attribute; the page applies one modifier to all three | `SkillCheckModal.modBox` | page (FM1) | — |

Confirmed correct: the pool arithmetic, the FP→QS table, 0 FP counting as QS 1, and Doppel-1 and
Doppel-20 overriding the points (`SkillCheckEngine.evaluate`, `qualityLevel(for:)`).
