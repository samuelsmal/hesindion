# Example 21 (probe) — Fernkampf, Ladezeiten, Schnellladen

**Status: probe, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

This is a probe, not part of Boronmir's set. The question is whether rules outside melee need
engine concepts the drafts so far lack. It covers the core ranged attack and one ranged SF, with
a generic archer.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| fernkampf | Ablauf eines Fernkampfangriffs | <https://dsa.ulisses-regelwiki.de/Fernkampf.html> | Regelwerk p. 241 ff.; cover from Kodex des Schwertes p. 80 |
| ladezeiten | Ladezeiten | <https://dsa.ulisses-regelwiki.de/Spezielle_Fernkampfregeln.html> | Regelwerk p. 245 f. |
| SA_60 | Schnellladen (passiv) | <https://dsa.ulisses-regelwiki.de/KSF_Schnellladen.html> | Regelwerk p. 249 |

Several subpages returned an empty article: Bewegung, Schüsse ins Kampfgetümmel, Schadensbonus
durch Reichweite, the Übersicht and Ladezeiten. The parent pages carry their text. The page
that defines **länger dauernde Handlungen** was not found, and two rules lean on it.

## Clauses

**Fernkampf**
- **FK1–FK3** The FK check. The target must be within the weapon's range. No ranged attack while
  in melee.
- **FK4, FK5** Range bands per weapon: nah +2 FK / +1 TP, mittel ±0, weit −2 FK / −1 TP. Beyond
  the maximum, up to 1.5×, only an untargeted shot.
- **FK6, FK8** Target size −8 … +8. Cover makes the target count as smaller.
- **FK7** Target movement (+2 / 0 / −2, Haken a further −4 and half GS). The archer's own
  movement −2 / −4.
- **FK9** Sicht −2 / −4 / −6. Stufe 4 (invisible) hits only on a 1.
- **FK10** Mounted: Schritt −4, Galopp −8, Trab only on a 1. No Langbogen.
- **FK11** Zielen: +2 per action spent, at most +4. A länger dauernde Handlung.
- **FK12** Shooting into a melee: −2. A failed shot hits nobody.
- **FK13–FK14, FK17–FK18** Critical hits and Patzer, with confirmation rolls. On a hit the
  opponent's VW is halved and the TP doubled.
- **FK15, FK16** Defence: no weapon parry, shield parry and dodge −4 (Schusswaffen) or −2
  (Wurfwaffen). One multiple-defence counter over melee and ranged.

**Ladezeiten**
- **LZ1, LZ2** The Ladezeit is weapon data, in actions. After the last one the weapon is ready.
  At 0, reloading is a free action.
- **LZ3, LZ4** Loading is a länger dauernde Handlung. A loaded crossbow needs only a free action.
- **LZ5–LZ7** Stringing a bow takes 4 actions and nothing else. Arrows and bolts are spent;
  thrown weapons can be picked up again.

**Schnellladen (SA_60)**
- **SL1** Bows and thrown weapons: Ladezeit −1.
- **SL2** Crossbows: half the Ladezeit.
- **SL3** Bought per technique, one instance each (Optolith `sid`).

## Rulings

New, all open:
- `fernkampf.range-input`: does the player name the range band, or the Schritt?
- `fernkampf.cover-as-size`: does cover step the target's size down, or replace it?
- `fernkampf.zielen-interrupted`: what ends aiming without a shot? Asked without the page on
  länger dauernde Handlungen.

Reused: `round-up` for the Schwere Armbrust (15 halves to 7.5, rounded to 8) and for Haken's
half GS.

## Situations

[`situations/probe-fernkampf.yaml`](../../../specs/rules/situations/probe-fernkampf.yaml), 21.1–21.8. Rule files:
[`fernkampf`](../../../specs/rules/core/fernkampf.yaml), [`ladezeiten`](../../../specs/rules/core/ladezeiten.yaml),
[`SA_60`](../../../specs/rules/abilities/SA_60.yaml).

## What the app gets wrong

| Finding | Where | Basis | Situation |
|---|---|---|---|
| No ranged modifier names a rule | `RangedModifiers` (`rules: []` on all eight), `CombatFernkampfViews.distanzTP` | requirement | 21.1, 21.2 |
| A ranged attack can be taken while in melee | `CombatRootView` (the Fernkampf button) | page (FK3) | 21.7 |
| No Sicht Stufe 4: an invisible target is shot at −6 instead of hitting only on a 1 | `CombatFernkampfViews.sichtSection`, `RangedModifiers.sicht` | page (FK9) | 21.4 |
| Mounted: no Trab (hits only on a 1), and the Langbogen is offered | `CombatFernkampfViews.vomPferdSection`, `RangedModifiers.vomPferd` | page (FK10) | 21.5 |
| No Ladezeit: every weapon is ready every action, and Schnellladen does nothing | Fernkampf flow, catalog SA_60 `todo` | page (LZ2, SL1, SL2) | 21.8 |
| Zielen is a picker. The bonus comes without the actions being spent | `CombatFernkampfViews`, `RangedModifiers.zielen` | page (FK11) | 21.6 |
| No cover input; cover can only be entered as a smaller size, labelled "Größe" | `CombatFernkampfViews` | page (FK8) | 21.3 |

Confirmed correct: the numbers of every table the app has (distance, size, movement, Sicht 1–3,
Kampfgetümmel, Zielen's cap, Schritt and Galopp), and the distance TP.

## What the probe found for the engine

See the report in the conversation, and each `# FORMAT:` note in the three files.
