# Example 14 — Boronmir's Kampfsonderfertigkeiten

**Status: draft, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

Four combat abilities of Boronmir's that no earlier example covered: two Spezialmanöver he
announces himself, a passive bonus on a talent check, and a formation that also helps the
fighters beside him.

The numbers are his values as of 2026-09-24. He dropped Vorstoß, Schildspalter and
Plänkler-Formation that day (and Finte, which [example 8](./finte.md) covers). He took
Formation instead, which [example 19](./boronmir-neu.md) covers. This example adds the three back
to his new sheet. He still meets their prerequisites (GE 14, KK 14, Wuchtschlag I).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_66 | Vorstoß (Spezialmanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Vorsto%C3%9F.html> | Regelwerk p. 250 |
| SA_59 | Schildspalter (Spezialmanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Schildspalter.html> | Regelwerk p. 249 |
| SA_40 | Aufmerksamkeit (passiv) | <https://dsa.ulisses-regelwiki.de/KSF_Aufmerksamkeit.html> | Regelwerk p. 246 |
| SA_884 | Plänkler-Formation (passiv) | <https://dsa.ulisses-regelwiki.de/KSF_Plaenkler_Formation.html> | Aventurisches Kompendium II p. 129 |

## Clauses

**Vorstoß (SA_66)**: a Spezialmanöver, so not usable on horseback (reiterkampf.RK3, ruling
`mounted-manoeuvres`) or on a double attack (beidhaendiger-kampf.ZW6).

- **V1** AT +2 for the current Kampfrunde. In practice that is the round's one attack: a double
  attack cannot carry a Spezialmanöver, and a Passierschlag combines with no
  Kampfsonderfertigkeit (passierschlag.PS3), so it gets no +2 (14.6).
- **V2** In return, no defence (parry or dodge) for the rest of that round.
- **V3** It must be announced at the start of the round.
- **V4** Not while Liegend.
- **V5–V7** Prerequisite GE 13 (purchase only); the list of combat techniques (not Schilde);
  an editor's note on that list.

**Schildspalter (SA_59)**: a Spezialmanöver, written from both sides: Boronmir splitting a
shield, and an opponent splitting his Großschild.

- **SS1** The attack is aimed at the shield. The defender may only parry with the shield or dodge.
- **SS2** A shield parry against it gets no Parade-Bonus from the shield.
- **SS3** If the defence fails, the damage comes off the shield's Strukturpunkte. At 0 the shield
  is destroyed.
- **SS4** It can only be used against someone fighting with a shield.
- **SS5–SS7** Erschwernis ±0 (no line); prerequisites KK 13, Wuchtschlag I; combat techniques
  Hiebwaffen, Kettenwaffen, Zweihandhiebwaffen, Zweihandschwerter.

**Aufmerksamkeit (SA_40)**

- **A1** In an ambush, or whenever surprise is at stake: +2 on Sinnesschärfe (Hinterhalt
  entdecken).
- **A2, A3** Prerequisite IN 13; all combat techniques. Nothing to apply.

**Plänkler-Formation (SA_884)**: Formation (SA_862, example 19) is the same rule with larger
numbers.

- **P1** Up to three fighters, at most half a Schritt to the left and right, form a line.
- **P2** Everyone in it gets either +1 AT or +1 VW (every defence).
- **P3** The line agrees on one of the two bonuses when it forms.
- **P4** Only one of them needs the ability. With more holders, more fighters can benefit.
- **P5, P6** No prerequisites; all combat techniques.

## Rulings

New, all decided (@samuelsmal, 2026-09-24):

- `SA_59.schildspalter-shield-bonus` (a): against Schildspalter, a shield parry loses its whole
  doubled bonus: Boronmir 13 → 7.
- `SA_59.schildspalter-against-hero` (b): a toggle "Schildspalter" on the defence screen turns off
  the weapon parry, takes the bonus off the shield parry, and on a failed defence takes the TP off
  the shield's current StP; at 0 the shield is destroyed and leaves the loadout. The app needs a
  current-StP field on Shield.
- `SA_40.aufmerksamkeit-when` (a): a toggle "Hinterhalt / Überraschung" on the Sinnesschärfe
  check, off by default, like the Belastung toggle on the same screen; on, the +2 is a line.
- `SA_884.plaenkler-mounted` (a): not while mounted; the toggle is off and disabled on horseback,
  with the reason.

Reused: `mounted-manoeuvres` and `sf-technique-lists`, and `manoeuvre-combination` for Vorstoß
or Schildspalter with Wuchtschlag.

## Situations

[`situations/boronmir-sf.yaml`](./situations/boronmir-sf.yaml), 14.1–14.21, all with Boronmir's
values as of 2026-09-24, plus the three SFs: Rabenschnabel 16/11, Langschwert 14/11 and
Großschild 6/13 (StP 30), all with the shield's passive bonus; AW 7; Belastung I in plate with
Belastungsgewöhnung II. The derivation is in the file's header. Rule files: [`SA_66`](./rules/abilities/SA_66.yaml),
[`SA_59`](./rules/abilities/SA_59.yaml), [`SA_40`](./rules/abilities/SA_40.yaml),
[`SA_884`](./rules/abilities/SA_884.yaml).

## What the app gets wrong

| Finding | Where | Basis | Situation |
|---|---|---|---|
| Vorstoß can be picked at any attack in the round, even after the hero has parried. The page wants it announced at the start of the round | `CombatAttackViews.availableManeuvers`, `proceed()` | page (V3) | 14.2 |
| Vorstoß is offered while Liegend | `CombatAttackViews.availableManeuvers` | page (V4) | 14.3 |
| Schildspalter is offered against any opponent. The app never asks whether the opponent has a shield | `availableManeuvers`, `OpponentProfile` | page (SS4) | 14.9 |
| Schildspalter's note says only "Schaden gegen Schild-SP". It never says the opponent may only parry with the shield (without its bonus) or dodge | `CombatManeuver.infoText` | page (SS1, SS2) | 14.8 |
| Aufmerksamkeit's +2 is never applied. The hint appears on every Sinnesschärfe check and names "Überraschung vermeiden" rather than Hinterhalt entdecken | `TalentProbeModal.hints`, catalog SA_40 `byHand` | page (A1) | 14.14, 14.15 |
| Only the owner of Plänkler-Formation can be in one. The page lets a companion's SF carry everyone in the line | `CombatSetupView` (`hero.hasPlaenklerFormation`), catalog SA_884 note | page (P4) | 14.18 |
| The formation is set once at combat setup and cannot be left mid-fight | `CombatSetupView`, `CombatRootView.plaenklerActive` (read-only) | page (P1) | 14.20 |
| An opponent's Schildspalter cannot be stated: the weapon parry and the full shield parry are offered, the damage goes to Boronmir's LeP, and a shield's StP are never reduced | `CombatDefenseSetupView`, `Shield.structurePoints` (maximum only) | ruling schildspalter-shield-bonus, schildspalter-against-hero | 14.13 |
| Plänkler-Formation's +1 applies on horseback too | `CombatSituation.chosenOptions`, catalog SA_884 | ruling plaenkler-mounted | 14.19 |
| Vorstoß is offered for a Großschild attack and Schildspalter with the Langschwert; neither technique is on the SF's list | `CombatAttackViews.availableManeuvers` (checks no technique) | ruling sf-technique-lists | 14.4, 14.10 |

Already in README's table (example 2): Vorstoß and Schildspalter are offered on horseback (14.5,
14.11) and on a double attack (example 11).

Confirmed correct:
- Plänkler-Formation's +1 AT, or +1 on weapon parry, shield parry and dodge alike (catalog
  SA_884, `vw`).
- Vorstoß's +2 and its blocked defences on the round's first attack, and no +2 on a Passierschlag.
- Schildspalter's AT is unchanged.
