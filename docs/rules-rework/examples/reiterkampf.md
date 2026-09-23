# Example 2 — Reiterkampf, and the rules that lean on it

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| — | Reiterkampf (core rule, no Optolith id) | <https://dsa.ulisses-regelwiki.de/Reiterkampf.html> | Regelwerk p. 239f |
| GRW_vorteilhaftePosition | Vorteilhafte Position (core rule) | <https://dsa.ulisses-regelwiki.de/GR_Kampf-VorteilhaftePosition.html> | Regelwerk p. 238 |
| SA_43 | Berittener Kampf | <https://dsa.ulisses-regelwiki.de/KSF_BerittenerKampf.html> | Regelwerk p. 247 |
| SA_661 | Golgariten-Stil | <https://dsa.ulisses-regelwiki.de/SF_Kampfstilsonderfertigkeiten/bewaffnete-kampfstile/golgariten-stil.html> | Aventurisches Götterwirken I p. 229 |
| SA_62 | Sturmangriff (on foot) | <https://dsa.ulisses-regelwiki.de/KSF_Sturmangriff.html> | Regelwerk p. 250 |

## Clauses

**Reiterkampf** — otherwise the ordinary combat rules apply, with these exceptions:

- **RK1** The rider uses the mount's INI base value to determine initiative.
- **RK2** Against fighters on foot, a rider counts as being in a vorteilhafte Position.
- **RK3** No Spezialmanöver from a mount, unless the manoeuvre is meant for mounted combat.
  Basismanöver are allowed.
- **RK4** No two-handed weapons from horseback.
- **RK5** A shield blocks only attacks from the front and from the shield-arm side. Attacks from
  the weapon-arm side can only be parried with the weapon held there, or dodged.
- **RK6** Parrying works as usual; dodging on a mount is always −2, unless the rider jumps off,
  which drops the −2.
- **RK7** Belastung counts as 1 lower for Kampfproben (→ [Example 1](./belastung.md)).
- **RK8** A Reiten (Kampfmanöver) check is needed when the mount is hurt, given a special order,
  or moves between walk, trot and gallop.
- **RK9** A change of gait is a free action, used up by both rider and mount.
- **RK10** When the mount takes SP, Reiten (Kampfmanöver) or the rider falls; −1 per full 5 SP.
- **RK11** A foot fighter's Passierschlag can only hit the mount, not the rider.
- **RK12** Instead of an attack, the rider may order the mount (an action and a Reiten
  (Kampfmanöver) check). A failed check: the order is not carried out, nothing worse happens.
- **RK13** *Niederreiten* (order): the mount attacks with its own Niederreiten AT; needs at least
  4 Schritt run-up at a gallop; damage from the mount's profile; only AW defends against it; the
  mount runs on at full GS to the end of the Kampfrunde, and the rider needs an action to turn it.
- **RK14** *Sturmangriff zu Pferd* (order): gallop only; after the Reiten check an attack follows as
  part of the order; the pair do not slow down automatically; it cannot be parried with a weapon,
  only with a shield or dodged; on a hit, TP + 2 + half the **mount's** GS; the order needs SF
  Berittener Kampf.
- **RK15** *Flucht* on horseback: a Reiten (Kampfmanöver) check, −1 per opponent in reach; on
  success the mount moves GS Schritt, taking Passierschläge where it passes through reach.

**Vorteilhafte Position**

- **VP1** +2 on AT and on Verteidigungen (PA and AW).
- **VP2** Getting there in a fight costs at least one action and possibly a Körperbeherrschung
  (Kampfmanöver) check; a Patzer may give the opponent a Passierschlag.

**Berittener Kampf (SA_43)**

- **BK1** Lets the rider give special orders in mounted combat, e.g. Niederreiten or Sturmangriff
  zu Pferd. (Its only clause; the orders themselves are RK13/RK14.)

**Golgariten-Stil (SA_661)**

- **GS1** Mounted against fighters on foot, the AT ease from the vorteilhafte Position rises by +2.
- **GS2** +1 PA while on a mount.
- **GS3** Combat techniques: Hiebwaffen (Rabenschnabel only), Schilde (Großschild only, and only
  from a mount).

**Sturmangriff (SA_62)**, a Spezialmanöver

- **ST1** Needs at least 4 Schritt run-up and GS of at least 4; the movement is part of the attack.
- **ST2** On a hit, TP + 2 + half the attacker's GS, at most +10 TP in total, and at most the
  attacker's natural GS.
- **ST3** Defended normally. On a miss, the defender gets a Passierschlag.
- **ST4** Cannot be combined with Finte. Erschwernis −2.

## Situations

In [`situations/reiterkampf.yaml`](./situations/reiterkampf.yaml), 5.1–5.17. The rules as draft YAML:
[`reiterkampf`](./rules/core/reiterkampf.yaml), [`vorteilhafte-position`](./rules/core/vorteilhafte-position.yaml),
[`SA_43`](./rules/abilities/SA_43.yaml), [`SA_661`](./rules/abilities/SA_661.yaml),
[`SA_62`](./rules/abilities/SA_62.yaml).

Where the app is wrong, per the rulings below: Vorstoß and Schildspalter are offered on horseback
(5.9); SA_62 is never offered on foot (5.12); the mount's GS/2 is rounded down (5.11); the mounted
dodge −2 cites no rule (5.3). To check in code: whether the mounted Sturmangriff asks for the Reiten
check and limits the defence (5.10).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md), generated from the rule
files — look for `reiterkampf`, `SA_62`, `SA_661` and the shared ones.
