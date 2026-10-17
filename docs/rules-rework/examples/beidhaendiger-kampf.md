# Example 11 — Beidhändiger Kampf, the SF and the advantage

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| — | Beidhändiger Kampf (core rule, fighting with two weapons) | <https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/beidhaendiger-kampf.html> | Regelwerk p. 238 |
| SA_42 | Beidhändiger Kampf I–II | <https://dsa.ulisses-regelwiki.de/KSF_Beih%C3%A4ndigerKampf.html> (the wiki's own spelling) | Regelwerk p. 246f |
| ADV_5 | Beidhändig | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Beidh%C3%A4ndig> | Regelwerk p. 164 |

The core rule and the SF share a name. The core rule is `core/beidhaendiger-kampf`; the SF only
lowers one of its penalties.

## Clauses

**Beidhändiger Kampf (core rule)**

- **ZW1** No weapon that needs two hands; no Kettenwaffe, unless paired with a shield.
- **ZW2** One action strikes with both weapons: two separate AT rolls, each defended and each
  damaging on its own.
- **ZW3** −2 on both attacks and on **every defence** of the attacker for the rest of the round —
  only in a round where both weapons attack. Not on a shield defence; yes on a shield attack.
  Beidhändiger Kampf I–II lowers it.
- **ZW4** The weapon in the wrong hand: a further −4 on AT and PA. Beidhändig removes it. Not on a
  shield defence; yes on a shield attack.
- **ZW5** The two attacks may go to different opponents in reach.
- **ZW6** Only Basismanöver on either attack.
- **ZW7** A parry may be made with either weapon; ZW3 and ZW4 apply to it.
- **ZW8** A Patzer on the first attack cancels the second; a Patzer on the second leaves the first
  standing.
- **ZW9** The page's example: right hand −2, left hand −6.

**Beidhändiger Kampf I–II (SA_42)**

- **BH1** The penalty "auf Attacke und Parade" is −1 at Stufe I, 0 at Stufe II.
- **BH2** Techniques: Dolche, Fächer, Fechtwaffen, Hiebwaffen, Raufen, Schilde, Schwerter.

**Beidhändig (ADV_5)**

- **V1** No penalty on skill checks for using the wrong hand.
- **V2** In combat, removes every penalty for a weapon in the wrong hand (ZW4, not ZW3).

## Situations

In [`situations/beidhaendiger-kampf.yaml`](../../../specs/rules/situations/beidhaendiger-kampf.yaml), 11.1–11.12. The
rules as draft YAML: [`beidhaendiger-kampf`](../../../specs/rules/core/beidhaendiger-kampf.yaml),
[`SA_42`](../../../specs/rules/abilities/SA_42.yaml), [`ADV_5`](../../../specs/rules/advantages/ADV_5.yaml).

Where the app is wrong: the off-hand weapon is chosen by alphabetical order of the names, not by
the player — Schwert and Dolch make the Dolch the main hand (11.12, `CombatLoadoutPicker.apply`);
Vorstoß and Schildspalter are offered on a double attack (11.7,
`CombatAttackViews.availableManeuvers`); a Kettenwaffe can be paired with a second weapon (11.10,
`CombatLoadoutPicker.canSelect`); weapon and shield never make a double attack, and there is no
shield attack at all (11.11); Raufen cannot be one hand of a double attack, though each fist
counts as a weapon (11.9, `CombatLoadoutPicker.canSelect`, decided ruling `raufen-double-attack`).
Right: the −2/−4 arithmetic, the round-long defence penalty, the off-hand parry, and the Patzer
rule (11.2–11.4b, 11.6, 11.8); a parry rolled before the double attack in the same round pays no −2
(11.5, decided ruling `zw3-earlier-defences`).

Provenance, today: the −2 line cites SA_42 (`MeleeModifiers.dualAttackPenalty`, `rules: [SA_42]`)
though the penalty is the core rule's and SA_42 only lowers it; the −4 cites ADV_5
(`offHandPenalty`), the advantage that *removes* it. A player reading "Beidhändiger Kampf −2" on a
hero without the SF is told the wrong thing.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md) — look for
`beidhaendiger-kampf`, `SA_42` and the shared `sf-technique-lists` (SA_42 lowers the penalty only
when both pieces are of a technique on its list).
