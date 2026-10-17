# Example 8 — Finte

**Status: draft.** Page read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

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

In [`situations/finte.yaml`](../../../specs/rules/situations/finte.yaml), 8.1–8.10. The rule as draft YAML:
[`SA_48`](../../../specs/rules/abilities/SA_48.yaml).

Where the app is wrong: only the highest Stufe is offered (`CombatAttackViews.availableManeuvers`
offers `hero.finteTier`), while Wuchtschlag offers every Stufe — the two tiered Basismanöver are
treated differently (8.3; per the decided ruling `tiered-manoeuvre-stufe` any Stufe up to the
owned one may be announced); Finte is offered with any weapon, including techniques not on its list
(8.5; per the decided ruling `sf-technique-lists` it needs one of F3's); the manoeuvre's info text says "Gegner PA −2" although the page says Verteidigung, so a dodge
is mislabelled (`CombatManeuver.infoText`, 8.4). Finte is still `byHand` in the catalog
(`Hero.finteTier`, `OpponentProfile.defenseModifiers`).

What it exercises in the format: an announced Stufe that differs from the owned one
(`chosen_tier`), and an effect split between the hero's AT and the opponent's defence, the second
only on a hit.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md). This example rests on three
cross-cutting ones, all decided: any Stufe up to the owned one may be announced
(`tiered-manoeuvre-stufe`), a manoeuvre needs a listed technique (`sf-technique-lists`), and one
Basismanöver and one Spezialmanöver combine on one attack (`manoeuvre-combination`).
