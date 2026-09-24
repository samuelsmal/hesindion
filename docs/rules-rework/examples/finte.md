# Example 8 — Finte

**Status: draft.** Page read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_48 | Finte I–III (Basismanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Finte.html> | Regelwerk p. 247 |

## Clauses

- **F1** The attacker makes their own AT harder by 1 per Stufe; if the attack succeeds, the
  opponent's defence is harder by 2 per Stufe.
- **F2** Erschwernis −1/−2/−3 — F1 restated.
- **F3** Combat techniques: Dolche, Fächer, Fechtwaffen, Hiebwaffen, Peitschen, Raufen, Schwerter,
  Stangenwaffen, Zweihandhiebwaffen, Zweihandschwerter. The page notes the list grows with later
  books.
- **F4** Prerequisites per Stufe (GE 13/15/17, the previous Stufe) — purchase only.

Excluded by Sturmangriff (SA_62.ST4).

## Situations

In [`situations/finte.yaml`](./situations/finte.yaml), 8.1–8.10. The rule as draft YAML:
[`SA_48`](./rules/abilities/SA_48.yaml).

Where the app is wrong: only the highest Stufe is offered (`CombatAttackViews.availableManeuvers`
offers `hero.finteTier`), while Wuchtschlag offers every Stufe — the two tiered Basismanöver are
treated differently (8.3); Finte is offered with any weapon, including techniques not on its list
(8.5); the manoeuvre's info text says "Gegner PA −2" although the page says Verteidigung, so a dodge
is mislabelled (`CombatManeuver.infoText`, 8.4). Finte is still `byHand` in the catalog
(`Hero.finteTier`, `OpponentProfile.defenseModifiers`).

What it exercises in the format: an announced Stufe that differs from the owned one
(`chosen_tier`), and an effect split between the hero's AT and the opponent's defence, the second
only on a hit.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md). This example rests on three
cross-cutting ones — which Stufe of a tiered manoeuvre may be announced, whether a manoeuvre needs a
listed technique, and which manoeuvres combine on one attack.
