# Example 18 — Kupperus und Boronmirs Waffen

**Status: draft, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

Boronmir's horse, and the three things he fights with. The horse's rules sit on the other side
of [Reiterkampf](./reiterkampf.md): that page says what a rider does with the mount's INI, GS and
Niederreiten values, and this example covers where those values come from. The weapons carry the
first rules in the set that belong to a **Fokusregel only for some clauses of a file**, and the
first **creature** rules.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| svellttaler-kaltblut | Svellttaler Kaltblut (profile) | <https://dsa.ulisses-regelwiki.de/Best_Svellttaler_Kaltblut.html> | Aventurische Tiergefährten p. 45 |
| maechtiger-schlag | Mächtiger Schlag (Tier-Kampf-SF, passiv) | <https://dsa.ulisses-regelwiki.de/SF_MaechtigerSchlag.html> | Aventurische Tiergefährten p. 126 (and 12 more) |
| ruhiges-temperament | Ruhiges Temperament (Tiervorteil) | <https://dsa.ulisses-regelwiki.de/vor-und-nachteile/tiervor-und-nachteile/vorteile-tiere/ruhiges-temperament.html> | Aventurische Tiergefährten p. 118 |
| ITEMTPL_19 | Rabenschnabel | <https://dsa.ulisses-regelwiki.de/rabenschnabel.html> | Regelwerk p. 367; Aventurische Rüstkammer p. 83 |
| ITEMTPL_35 | Langschwert | <https://dsa.ulisses-regelwiki.de/langschwert.html> | (page names none) Regelwerk p. 368 per Optolith |
| ITEMTPL_29 | Großschild (table properties only) | <https://dsa.ulisses-regelwiki.de/grossschild.html> | Regelwerk p. 367; Aventurische Rüstkammer p. 67 |
| waffeneigenschaften | Waffeneigenschaften (Fokusregel, Ausrüstung I) | <https://dsa.ulisses-regelwiki.de/Waffeneigenschaften.html> | Aventurische Rüstkammer p. 56 |

Referenced, not written here: [`reiterkampf`](./rules/core/reiterkampf.yaml) RK1, RK7, RK12–RK14;
[`SA_661`](./rules/abilities/SA_661.yaml) GS1–GS3; `schilde` (the shield rules), [`schaden`](./rules/core/schaden.yaml) S3 (the Schadensbonus, from
the [Kampftechniken](https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/kampftechniken.html)
page) and [`groessenkategorie`](./rules/core/groessenkategorie.yaml) GK4 — other agents' files.

**There is no creature ability "Niederreiten".** The wiki's search finds only the Reiterkampf
order, Berittener Kampf, Frontalangriff and profiles with a Niederreiten attack. On a horse it is
an attack line of the profile (SK3) that RK13 reads.

## Clauses

**Svellttaler Kaltblut** — a stat block, drafted as a new kind `creatureProfile`.

- **SK2** INI 14+1W6, GS 12, LeP 75, VW 7, KK 25 — what RK1, RK14/15, RK10 and Mächtiger Schlag read.
- **SK3** Tritt AT 15 1W6+7, Biss AT 12 1W6+2, Niederreiten AT 15 2W6+6 (the line RK13 reads; a
  mount without one gets no Niederreiten order, ruling `niederreiten-without-profile`). Ridden,
  Tritt and Biss are orders like any other (RK12): Boronmir's action instead of his own attack, and
  a Reiten (Kampfmanöver) check (ruling `mount-own-attack`).
- **SK4** RS 0, 1 action. **SK5** Ruhiges Temperament; Mächtiger Schlag. **SK7** Größenkategorie
  groß (the opponent cannot weapon-parry its attacks).
- **SK10** Schmerz at 49/33/16/5 LeP — thresholds that fit 65 LeP, not 75; the printed ones count
  (ruling `svellttaler-schmerz-thresholds`).
- **SK12** *Packesel*: carries up to 210 Stein.
- Size, talents, loot, Kampfverhalten, Tierkunde: text.

**Mächtiger Schlag** — **MS1** after a successful attack, an opponent of size mittel or smaller
must pass Kraftakt or go Liegend; **MS2** the check is −½ of the KK above 20, rounded up by the
page's own example (KK 23: −2) — Kupperus −3; **MS3** only a dodge avoids it; after a parry,
successful or not, the check is still rolled.

**Ruhiges Temperament** — **RT1** Reiten checks on this animal +1.

**Rabenschnabel** — **RS0** the row (1W6+4, KK 14, 0/−1, mittel); **RS1** geweiht (Boron);
**RS2** *Dornenspitze*: same TP, worn armour with RS 6+ counts −2 (not natural RS; ruling
`dornenspitze-rs`); **RS3** +1 TP when used from a mount;
**RS4** a confirmed Patzer on an attack adds 1 Stufe Betäubung. RS2–RS4 are the Waffenvorteil and
-nachteil, and apply only with the Fokusregel Waffeneigenschaften (ruling
`rabenschnabel-waffeneigenschaft`).

**Langschwert** — **LS0** the row (1W6+4, GE/KK 15, 0/0, mittel); **LS1** no Waffenvorteil or
-nachteil.

**Großschild** — **GR0** the row (1W6+1, KK 16, −6/+3, kurz); **GR1** 30 Strukturpunkte, and
**−1 AT on the main weapon** (Regelwerk, core); **GR2** +1 PA against Pfeile and Bolzen;
**GR3** on an INI tie the opponent strikes first unless they carry one too; **GR4** GS −1.
GR2–GR4 are the Waffenvorteil and -nachteil.

**Waffeneigenschaften** — **WE1–WE2** a Fokusregel, Ausrüstung Stufe I: every weapon's
Waffenvorteil and -nachteil applies only when the group plays it.

## Situations

In [`situations/kupperus-und-waffen.yaml`](./situations/kupperus-und-waffen.yaml), 18.1–18.16,
with Boronmir's real values (derivation in the file's header). The rules as draft YAML:
[`svellttaler-kaltblut`](./rules/creatures/svellttaler-kaltblut.yaml),
[`maechtiger-schlag`](./rules/creatures/maechtiger-schlag.yaml),
[`ruhiges-temperament`](./rules/creatures/ruhiges-temperament.yaml),
[`ITEMTPL_19`](./rules/equipment/ITEMTPL_19.yaml), [`ITEMTPL_35`](./rules/equipment/ITEMTPL_35.yaml),
[`ITEMTPL_29`](./rules/equipment/ITEMTPL_29.yaml),
[`waffeneigenschaften`](./rules/core/waffeneigenschaften.yaml).

The three asked for: Kupperus's Niederreiten with Boronmir riding (18.1: Reiten check 0 = −1
Belastung +1 Ruhiges Temperament; AT 15, 2W6+6, dodge only, Kraftakt −3), a Tritt (18.3: an
order, so Boronmir's action and the same Reiten check, then AT 15, 1W6+7, shield parry or dodge),
and the Dornenspitze against plate (18.5: AT 11, 1W6+5, RS 6 → 4).

## How the app models the mount today

It reads pets (`OptolithImportService.parsePets` → `Pet`). *The* mount is the first pet with an
initiative, by name (`Hero.mount`). INI base: the number before "+" in `Pet.initiative`
(`CombatSetupViews.mountBaseINI`), offered only while mounted. GS: `Pet.speed`
(`Hero.mountGS` → `sturmangriffDamageBonus`, floored — reiterkampf 5.11). Attacks: parsed by a
regex from the free-text `notes` (`parsePetAttacks`); the export's own `at` is ignored. Niederreiten
and the mount's other attacks are buttons on the attack screen (`CombatAttackViews.mountAttackSection`);
Niederreiten and Sturmangriff zu Pferd go through the gallop question and a Reiten check
(`CombatMountPreCheckView`), the other attacks straight to the roll. The mount's LeP is tracked
(`CombatMountDamageView`, RK10 with −1 per 5 SP). Not read or not held: VW (`pa`), RS (`pro`),
Größenkategorie, the animal's Vorteile, its Schmerz.

## What the app gets wrong

| Finding | Where | Basis |
|---|---|---|
| Niederreiten takes the AT of the **first** parsed attack, not the Niederreiten line: an Elenviner Vollblut attacks at 16 instead of 15 (Kupperus is right by luck, Tritt is also 15) | `CombatAttackViews.niederreitenButton` (`mount.attacks.first?.at`) | page (RK13) |
| Mächtiger Schlag's Kraftakt penalty is floored: Kupperus −2, the page −3 (its own example rounds KK 23 to −2) | `CombatAttackViews` (`(kk - 20) / 2`), string `mightyBlow` | page |
| The Schadensbonus (L+S) is never added: Boronmir's Rabenschnabel does 1W6+4, not 1W6+5. The code says no export carries the threshold, but his file has `primaryThreshold` on every weapon | `OptolithImportService.parseItems`, `FumbleEffectResolver` comment | page (Kampftechniken) |
| The Großschild's "−1 AT on the main weapon" is not applied: Boronmir's Rabenschnabel and Langschwert AT are 1 too high whenever the shield is carried | `OptolithImportService.shieldNote`, `MeleeModifiers` | page (Regelwerk table note) |
| Waffenvorteile and -nachteile are applied always; they belong to the Fokusregel Waffeneigenschaften, which the app does not have | catalog `ITEMTPL_19`, `WeaponFumbleExtras`, `FokusRule` | page (Waffeneigenschaften); ruling `rabenschnabel-waffeneigenschaft` |
| With that Fokusregel on, the Großschild's GS −1 and INI-tie rule are missing, and its +1 PA is a note that says "Fernkampf" where the page says Pfeile and Bolzen | `Hero.totalGsPenalty`, `shieldNote` | page |
| Kupperus can carry 210 Stein (Packesel); the app gives every pet KK × 2 = 50 | `Pet.carryingCapacity`, `Hero.totalCarryingCapacity` | page |
| Ruhiges Temperament (+1 on Reiten) is unknown to the app; the export does not carry an animal's Vorteile, and there is no Bestiarium profile to fill the gap | `CombatMountPreCheckView`, `parsePets` | page; source per ruling `mount-profile-data` |
| Tritt and Biss are offered beside the rider's own attack and rolled straight away; they are orders, taking his action and a Reiten (Kampfmanöver) check | `CombatAttackViews.mountAttackSection` | page (RK12); ruling `mount-own-attack` |
| Niederreiten is offered for a mount with no Niederreiten line, with the first attack's AT and the export's `dp` | `CombatAttackViews.niederreitenButton` | ruling `niederreiten-without-profile` |
| The Dornenspitze's RS note ("nur gegen RS 6 oder mehr") also invites the −2 against a creature's natural RS | `rsNote`, `CombatAttackViews.rsText` | ruling `dornenspitze-rs` |

Also noted, smaller: Niederreiten is offered without checking Berittener Kampf (RK13's `requires`
in reiterkampf.yaml) and without asking the run-up; the Mächtiger Schlag note says "(mittel/klein)"
where the page says "mittel und kleiner" (winzig too). Confirmed correct: the weapon table values
in Optolith, the hero file and the app match the pages for all three items; the Rabenschnabel's
+1 TP mounted applies with either end; the Patzer's Betäubung; the Mächtiger Schlag note's
"a parry does not help".

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md). New here, all decided
(@samuelsmal, 2026-09-24):

- `svellttaler-kaltblut.mount-profile-data` (c) — a table of Bestiarium profiles keyed by the pet's
  type, the export's numbers overriding it; a pet with no profile gets editable VW, RS, size and
  Vorteile.
- `svellttaler-kaltblut.mount-own-attack` (a) — a ridden horse's Tritt or Biss is an order (RK12):
  the rider's action and a Reiten (Kampfmanöver) check.
- `svellttaler-kaltblut.niederreiten-without-profile` (a) — no Niederreiten line, no Niederreiten
  order.
- `svellttaler-kaltblut.svellttaler-schmerz-thresholds` (a, against the recommendation) — the
  printed thresholds, 49/33/16/5, count.
- `ITEMTPL_19.rabenschnabel-waffeneigenschaft` (a) — every weapon's Waffenvorteil and -nachteil
  needs the Fokusregel.
- `ITEMTPL_19.dornenspitze-rs` (a) — worn armour only; with Trefferzonen-RS, the armour on the zone
  hit.

Reused: `round-up`, `reiterkampf.rk7-reiten`, `reiterkampf.rider-ini`, `COND_1.belastung-reach`,
`kampfstil-techniques` (the Golgarite with a Schwert, reiterkampf 5.7).
