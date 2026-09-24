# Example 17 — Passierschlag, Angriff von hinten, Beengte Umgebung, Größenkategorie

**Status: draft, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

Four short core rules the app's catalog marks `implemented`. The point of drafting them is what
the app leaves out or gets wrong. The hero is Boronmir: Rabenschnabel and Langschwert (both
mittel), Großschild, on foot and on Kupperus (a Svellttaler Kaltblut, groß).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| GRW_passierschlag | Passierschlag | <https://dsa.ulisses-regelwiki.de/GR_Kampf-Passierschlag.html> | Regelwerk p. 237 (Kodex des Schwertes p. 74) |
| GRW_angriffVonHinten | Angriff von hinten | <https://dsa.ulisses-regelwiki.de/GR_Kampf-AngriffVonHinten.html> | Regelwerk p. 238 (KdS p. 75) |
| GRW_beengteUmgebung | Beengte Umgebung | <https://dsa.ulisses-regelwiki.de/GR_Kampf-BeengteUmgebung.html> | Regelwerk p. 238 (KdS p. 74) |
| GRW_groessenkategorie | Größenkategorie | <https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/groessenkategorie.html> | Regelwerk p. 239 (KdS p. 76) |

## Clauses

**Passierschlag**

- **PS1** Triggers, "for example": a failed Flucht, the opponent's critical parry, some failed
  manoeuvres, running through a new opponent's reach without engaging. The list is open. The
  other triggers are clauses of other rules: SA_62.ST3, SA_172.U2, STATE_10.L4, VP2, RK15.
- **PS2** A melee attack that costs no action and cannot be defended against. AT −4.
- **PS3** Cannot be combined with Kampfsonderfertigkeiten (for example Finte or Wuchtschlag).
- **PS4** No Kritische Erfolge, no Patzer.
- **PS5** Any number per round.
- **PS6** The worked example (AT 15 → 11).

**Angriff von hinten**

- **AH1** Attacked from behind, the defender's Verteidigung is −4. The GM decides whether the
  attack comes from behind.

**Beengte Umgebung**

- **BU1** The GM decides that a place is beengt. Short weapons take no penalty.
- **BU2** Weapons by reach: kurz ±0; mittel AT −4 / PA −4; lang AT −8 / PA −8.
- **BU3** Shields by size: klein −2/−2; mittel AT −4 / PA −3; groß AT −6 / PA −4.

**Größenkategorie**

- **GK1** Five sizes: winzig, klein, mittel, groß, riesig.
- **GK2** The opponent's size decides.
- **GK3** Against a winzig target, AT −4. Klein and mittel ±0.
- **GK4** Against a groß attacker, only a shield parry or AW. Against a riesig one, only AW.

## Situations

In [`situations/kampfsituationen.yaml`](./situations/kampfsituationen.yaml), 17.1–17.24, with
Boronmir's real values (the derivation is at the top of the file). The rules as draft YAML:
[`passierschlag`](./rules/core/passierschlag.yaml),
[`angriff-von-hinten`](./rules/core/angriff-von-hinten.yaml),
[`beengte-umgebung`](./rules/core/beengte-umgebung.yaml),
[`groessenkategorie`](./rules/core/groessenkategorie.yaml). Cross-references, unchanged:
reiterkampf RK2/RK5/RK6/RK11/RK15 (RK11 now through the decided `reiterkampf.passierschlag-on-mount`), SA_62.ST3,
STATE_10.L4, reichweite.RW2, and trefferzonen.TZ5 (the zone penalty replaces GK3; TZ.7).

## What the app gets wrong

Per the page:

- **Beengte Umgebung has no shield rows.** The catalog keys only on weapon reach, and every
  shield imports with reach kurz (`OptolithImportService.parseItems`). So the Großschild never
  takes its −6 AT / −4 PA. The app also has no shield sizes at all: Optolith gives the size only
  in the note text ("großer Schild").
- **The penalty on a parry follows the main weapon, not the piece that parries**
  (`Situation.loadoutReach`; the catalog note says "until step 3"). Langschwert and Großschild,
  shield parry: −4, which is right only by accident (17.15). Bare hands and Großschild: 0 instead
  of −4 (17.16).
- **Mounted and attacked from behind, the Großschild still parries, and its passive +3 stays on the
  weapon parry.** Reiterkampf RK5 (a shield blocks only from the front and the shield-arm side) is
  unencoded "because the app does not know the side". But the app already asks `fromBehind`.
  `CombatDefenseSetupView`, `DefenseRoute.parryPossible`, `Hero.passiveShieldPABonus`. Boronmir on
  Kupperus: shield parry 12 and weapon parry 9 today; no shield parry and weapon parry 6 by the
  page and ruling `mounted-from-behind-shield` (17.10). From the weapon-arm side the app never asks
  at all (open ruling `reiterkampf.mounted-attack-side`).
- **Mounted, a Passierschlag from a fighter on foot damages the hero.** RK11 makes the mount the
  target; per ruling `reiterkampf.passierschlag-on-mount` the take-damage screen offers "Reittier
  getroffen", the SP go to the mount's LE and RK10's Reiten check follows (17.9).
  `CombatDamageViews`.

Per ruling:

- **The Angriff-von-hinten −4 is applied to a defence against a ranged attack** (ruling
  `from-behind-ranged`: melee only). The defence screen asks `fromBehind` for every parry and
  dodge and does not know whether the attack was ranged (17.13). `CombatDefenseSetupView`.
- **A Passierschlag cannot be aimed at a zone** (ruling `passierschlag-zone`: it can, at the full
  penalty, without the halving). `CombatAttackViews` hides the zone picker (17.4).
- **A Passierschlag is a plain comparison with the AT** (ruling `passierschlag-dice`: a 1 always
  hits, a 20 always misses). `CombatPassierschlagView.isHit` is `roll <= effectiveAT`, so at AT 0
  (the aimed head shot, 17.4) a 1 misses.

Where the catalog note says less than the code does, or the reverse:

- `GRW_passierschlag`'s only clause is the −4. PS2's "no defence" for the hero's own
  Passierschlag and PS4 are Swift (`CombatPassierschlagView`, `PassierschlagRoll`). The −4 is an
  `offer` that is reachable from every attack announcement, which suits PS1's open list.
- `GRW_angriffVonHinten` matches AH1, but the defence screen asks the question for every parry
  and dodge, including a dodge against a shot (above).
- `GRW_groessenkategorie` matches GK3/GK4. GK4 is Swift, in `SizeCategoryRules`.

Confirmed correct: the Passierschlag −4 with every other AT line on top (17.5, 17.6); no
manoeuvre on a Passierschlag; no defence against a Passierschlag the hero suffers after a
failed Flucht; Angriff von hinten on foot, on both sides of the table; the weapon-reach rows of
Beengte Umgebung, and AW untouched; the winzig −4; the groß and riesig defence restrictions.
Per ruling: passive SF and Kampfstile on a Passierschlag (17.3); the Langschwert's rolls untouched
by the Großschild's row (17.14); a rider counted at his own size (17.22, 17.23).

## Rulings

Decided (@samuelsmal, 2026-09-24), in the rule files:

- `passierschlag.passierschlag-sf` (a): PS3 excludes manoeuvres only; passive SF and Kampfstile
  apply (Golgariten-Stil's +2). 17.3
- `passierschlag.passierschlag-zone` (a): a Passierschlag may aim at a zone, at the full penalty.
  17.4
- `passierschlag.passierschlag-dice` (a): a 1 always hits and a 20 always misses, without
  confirmation or table. 17.1
- `angriff-von-hinten.from-behind-ranged` (a): the −4 is for melee attacks only. 17.13
- `angriff-von-hinten.mounted-from-behind-shield` (a): mounted and attacked from behind, no shield
  parry and no passive shield bonus. 17.10
- `beengte-umgebung.beengt-shield-carried` (a): the shield rows apply only to rolls made with the
  shield. 17.14
- `groessenkategorie.mounted-size` (a): a rider is his own size. 17.22, 17.23
- `reiterkampf.passierschlag-on-mount` (b): "Reittier getroffen" on the take-damage screen. 17.9

Open: `reiterkampf.mounted-attack-side` — how the app learns which side an attack on a mounted hero
comes from (RK5's weapon-arm side). Raised by the owner with `mounted-from-behind-shield`.

## Surprises

- The Flucht screen moves the hero `gs / 2` Schritt on a failure, which rounds down. The decided
  `round-up` ruling says it should round up. Flucht has no rule file yet.
- `trefferzonen.TZ5` points at `groessenkategorie.at`, but the line is `GK3.at` here.
- Optolith's STATE_6 (Eingeengt) text adds "Talentanwendungen … bis zu 2 erschwert". The Beengte
  Umgebung page does not say that.
