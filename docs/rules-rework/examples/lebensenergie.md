# Example 15 — Lebensenergie, Regeneration and Wieder-Aufstehen

**Status: draft.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| ADV_25 | Hohe Lebenskraft I–VII | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Hohe%20Lebenskraft%20I-VII> | Regelwerk p. 166 |
| ADV_49 | Zäher Hund | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Z%C3%A4her%20Hund> | Regelwerk p. 169 |
| ADV_44 | Verbesserte Regeneration (Lebensenergie) I–III | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Verbesserte%20Regeneration%20(Lebensenergie)%20I-III> | Regelwerk p. 169 |
| ADV_75 | Schnell wieder auf den Beinen | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Schnell%20wieder%20auf%20den%20Beinen> | Kneipen & Tavernen p. 13 |
| — | Lebensenergie (Basiswert) (core rule) | <https://dsa.ulisses-regelwiki.de/Heldenerschaffung/schritt-12-basiswerte-berechnen.html> | Regelwerk p. 56f |
| — | Regeneration (core rule) | <https://dsa.ulisses-regelwiki.de/Regeneration.html> | Regelwerk p. 339 |

They meet [Example 4](./schmerz.md)'s Schmerz (COND_6.SZ2, SZ3, SZ5) and Zustand rules
(zustaende.Z3, Z5), and [Example 7](./liegend.md)'s standing up (STATE_10.L4).

**ADV_75 does not do what its name suggests.** The page says nothing about standing up from
Liegend. It halves the time a Stufe of Betäubung or Berauscht takes to wear off, when alcohol
caused it. Standing up costs 1 action and may draw a Passierschlag, exactly as for anyone else
(15.16). Boronmir dropped this advantage on 2026-09-24; the situations about it give it back to
him.

## Clauses

**Lebensenergie (lebensenergie)**

- **LE1** Basiswerte come from a species Grundwert plus attributes; advantages, disadvantages and
  SFs can change them.
- **LE2** After play starts, they can be raised with AP.
- **LE3** LE = species LE-Grundwert (Mensch 5) + 2 × KO ± advantages and disadvantages.
- **LE4** The page's example: 5 + 12 + 12 + Hohe Lebenskraft III = 32.

**Hohe Lebenskraft (ADV_25)**

- **HL1** The LE-Grundwert rises by 1 per Stufe.
- **HL2** Prerequisite: no Niedrige Lebenskraft.

**Zäher Hund (ADV_49)**

- **ZH1** The hero ignores the effects of his highest Stufe of Schmerz and suffers the next
  lower one's.
- **ZH2** The page's example: three Stufen act as Stufe II.
- **ZH3** At Stufe IV he still becomes Handlungsunfähig.
- **ZH4** Stufe I counts as no Schmerz.
- **ZH5** Prerequisite: no Zerbrechlich.

**Regeneration (regeneration)**

- **R1** A hero who lost LeP/AsP/KaP can win some back in the next Regenerationsphase.
- **R2** A Regenerationsphase is at least 6 hours of rest and sleep.
- **R3** At most two per day.
- **R4** 1W6 per energy, plus the situation's modifiers; a negative result counts as 0.
- **R5** Never above the maximum.
- **R6** A restless, wet or cold place halves regeneration; a storm, or being tied to a horse's
  back, stops it.
- **R7** Vergiftet or Krank: no regeneration while it lasts; healing herbs still work.
- **T1** The table: bad camp −1, interrupted night −1, long interruption −2, good inn +1, and
  R6/R7 again.

**Verbesserte Regeneration (ADV_44)**

- **VR1** +1 per Stufe when the hero regenerates. The page's sentence ends in a comma; nothing
  seems to be missing.
- **VR2** Prerequisite: no Schlechte Regeneration (Lebensenergie).

**Schnell wieder auf den Beinen (ADV_75)**

- **SW1** A Stufe of Betäubung or Berauscht caused by alcohol wears off in half the time:
  Betäubung 1½ h instead of 3 h, Berauscht 1 h instead of 2 h.
- **SW2** No prerequisite.

## Situations

In [`situations/lebensenergie.yaml`](./situations/lebensenergie.yaml), 15.1–15.19, all Boronmir
as of the 2026-09-24 export unless stated: his LE (15.1: 5 + 2 × 15 + 2 = 37), a disadvantage the
import drops (15.2), his Schmerz thresholds with Zäher Hund (15.3–15.8: LP 27/18/9/5 start Stufen
I/II/III/IV), a night's regeneration in six settings (15.9–15.15), and standing up, alcohol and
Betäubung with Schnell wieder auf den Beinen given back to him (15.16–15.19).
The rules as draft YAML: [`ADV_25`](./rules/advantages/ADV_25.yaml),
[`ADV_49`](./rules/advantages/ADV_49.yaml), [`ADV_44`](./rules/advantages/ADV_44.yaml),
[`ADV_75`](./rules/advantages/ADV_75.yaml), [`lebensenergie`](./rules/core/lebensenergie.yaml),
[`regeneration`](./rules/core/regeneration.yaml).

## What the app gets wrong

- **Niedrige Lebenskraft is ignored**: `OptolithImportService.computeDerivedValues` reads only
  ADV_25, so a hero with DISADV_28 II has 2 LE too many (15.2). Basis: the page (LE3, "+/− Punkte
  aus Vor- und Nachteilen"); catalog `DISADV_28` is `todo`.
- **Verbesserte Regeneration III gives +2, not +3**: `Hero.verbessertRegenerationLEBonus` stops
  at Stufe II (15.15). Basis: the page (VR1, "für jede Stufe"). Boronmir, at Stufe II, is not
  affected.
- **Regeneration ignores Vergiftet and Krank**: the Regenerieren sheet rolls 1W6 + bonus for a
  poisoned or sick hero, though the app has both statuses (15.12). Basis: the page (R7).
- **Regeneration knows no environment**: no halving in a wet camp, no "fällt aus" in a storm or
  tied to a horse, and the bonus is added even then (`RegenerierenSheet`) (15.10, 15.11). Basis:
  the page (R6, and VR1's "wenn er regeneriert"); in a wet camp the whole result, bonus included,
  is halved and rounded up (ruling `ADV_44.vr-halving`: Boronmir rolling 3 regains 3, the app 5).
- **Schnell wieder auf den Beinen is ignored**: Betäubung and Berauscht chips give the full 3 h
  and 2 h (15.17, 15.18). Basis: the page (SW1); catalog `ADV_75` is `todo`. Text only — the app
  keeps no time. Only a Zustand caused by alcohol wears off faster; Betäubung from a blow keeps its
  3 h (15.19, ruling `ADV_75.alcohol-scope`).
- **Zäher Hund lowers the Stufe the hero has, not only its effects.** `Hero.effectiveSchmerzLevel`
  feeds `level(of:)`, the chip, and `totalZustandLevels`, so Boronmir with Belastung I, Schmerz
  III, Betäubung III and Furcht I counts 7 Stufen and keeps acting where the page's 8 make him
  Handlungsunfähig (15.8), and at Schmerz I shows no chip (15.4). Basis: ruling
  `ADV_49.zaeher-hund-counts` — the chip shows the Stufe he has (at most IV) and "wirkt wie" the
  lower one.
- **Zäher Hund does nothing at Stufe IV**: after a passed Selbstbeherrschung check he should act
  at −3 and GS −3, as Stufe III (15.7). Basis: ruling `ADV_49.zaeher-hund-iv`; the app has no such
  check at all (example 4) and `Hero.effectiveSchmerzLevel` returns 4 before subtracting.

Not rules but the requirement: the LE total names no rule (15.1 — "37" with no breakdown in
`HeroDetailView`), the Schmerz line lowered by Zäher Hund cites only COND_6 and shows the lowered
Stufe (`StateModifiers.penaltyDefinitions`) (15.5), and the regeneration table's rows are one
unnamed stepper (`RegenerierenSheet.userModifier`) (15.9).

Confirmed correct: LE 37 for Boronmir, Hohe Lebenskraft +1 per Stufe (15.1); the Schmerz
thresholds for LE 37 (`Hero.lebenspunkteSchmerzLevel`, which equals the exact comparison of
`COND_6.schmerz-thresholds` a); Zäher Hund's effects at Stufen I–III (15.4–15.6); the
regeneration floor at 0 and cap at the maximum (15.13, 15.14); Verbesserte Regeneration +2 for
Stufe II, and only on the regeneration sheet, not on healing (ruling `ADV_44.vr-scope`).

## Rulings

All rulings are in [`RULINGS.md`](./RULINGS.md). Decided 2026-09-24: `ADV_49.zaeher-hund-counts`
(effects only; the hero keeps his Stufe, at most IV), `ADV_49.zaeher-hund-iv` (Stufe III's effects
after a passed check), `ADV_44.vr-scope` (only in a Regenerationsphase), `ADV_44.vr-halving` (the
bonus is halved with the roll) and `ADV_75.alcohol-scope` (both Zustände only from alcohol). The
halving of regeneration is rounded up under the decided shared ruling
`round-up`.
