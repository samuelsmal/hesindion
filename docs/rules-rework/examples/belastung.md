# Example 1 — Belastung, Belastungsgewöhnung and the mounted relief

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| COND_1 | Belastung (Zustand) | <https://dsa.ulisses-regelwiki.de/Sta_Belastung.html> | Regelwerk p. 32 |
| — | Rüstung und Belastung (core rule, armour table) | <https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/ruestung-und-belastung.html> | Regelwerk p. 237 |
| SA_41 | Belastungsgewöhnung I–II | <https://dsa.ulisses-regelwiki.de/KSF_Belastungsgew%C3%B6hnung.html> | Regelwerk p. 246 |
| — | Reiterkampf, the Belastung clause (core rule) | <https://dsa.ulisses-regelwiki.de/Reiterkampf.html> | Regelwerk p. 239f |

## Clauses

**Belastung (COND_1)**

- **B1** Heavy loads and armour give the wearer levels of Belastung while carried; the levels go
  when the load is set down.
- **B2** Armour weight does not count when Belastung from carried weight (Traglast) is worked out.
- **B3** Stufe I–III: −1/−2/−3 on talent checks for talents marked as hindered by Belastung, on
  AT, on Verteidigung (PA and AW), on INI and on GS.
- **B4** Stufe IV: Handlungsunfähig until the load is dropped.

**Rüstung und Belastung**

- **A1** An armour has RS, a Belastung (Stufe), and possibly extra penalties on GS and INI on top.
- **A2** The table, top to bottom:

  | Row | Armour | RS | Belastung | Extra |
  |---|---|---|---|---|
  | 0 | Normale Kleidung, Felle, nackt | 0 | 0 | – |
  | 1 | Schwere Kleidung, Winterkleidung | 1 | 0 | −1 GS, −1 INI |
  | 2 | Stoffrüstung, Gambeson | 2 | 1 | – |
  | 3 | Lederrüstung | 3 | 1 | −1 GS, −1 INI |
  | 4 | Kettenrüstung | 4 | 2 | – |
  | 5 | Schuppenrüstung | 5 | 2 | −1 GS, −1 INI |
  | 6 | Plattenrüstung | 6 | 3 | – |
  | 7 | Gestechrüstung | 7 | 4 | – |
  | 8 | Turnierrüstung | 8 | 5 | – |

  (Belastungsgewöhnung's own page prints the same table without rows 7 and 8.)
- **A3** The page's worked example: Stoffrüstung gives −1 on AT, Verteidigung, INI, GS;
  Lederrüstung the same −1 plus its extra, so −2 on INI and GS.

**Belastungsgewöhnung (SA_41)**

- **G1** The armour's Belastung column *and* its extra penalties move up **two rows per Stufe**.
  The page's example: plate at Stufe I hinders like chain, "as far as BE, GS and INI go".
- **G2** RS is unchanged.

**Reiterkampf**

- **RK7** From horseback, Belastung counts as 1 lower **for Kampfproben**.

## Situations

In [`situations/belastung.yaml`](../../../specs/rules/situations/belastung.yaml): armour alone (1.x), Belastungsgewöhnung
(2.x), mounted (3.x), and which checks Belastung reaches (4.x), each with the rule and clause
behind every line and what the app does today. The rules as draft YAML: [`COND_1`](../../../specs/rules/conditions/COND_1.yaml),
[`ruestung-und-belastung`](../../../specs/rules/core/ruestung-und-belastung.yaml), [`SA_41`](../../../specs/rules/abilities/SA_41.yaml),
[`reiterkampf` RK7](../../../specs/rules/core/reiterkampf.yaml).

Where the app is wrong, per the rulings below: talents are never hindered (4.1), and the seven
talents the book marks "evtl." have no "Belastung zählt" toggle (4.5); Belastung IV and beyond
does not make a hero Handlungsunfähig (1.4, 1.5).

Confirmed correct, per ruling: Belastung takes its AT penalty off ranged attacks too
(`COND_1.belastung-fk`, answered against the recommendation); mounted, the rider rolls INI from the
mount's base with no Belastung taken off (`reiterkampf.rider-ini`, 3.1). A Schip "Zustand
ignorieren" suppresses Belastung with every other Zustand (`schicksalspunkte.schip-ignore-belastung`,
[Example 4](./schmerz.md) S8), which the app does not do.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md), generated from the rule
files — look for `COND_1`, `ruestung-und-belastung`, `SA_41` and `reiterkampf`.

**Provenance gap, today:** the INI and GS penalties are computed in `Hero.totalIniPenalty` and
`totalGsPenalty` and cite no rule at all; the AT/defence line cites COND_1 and SA_41 together.
