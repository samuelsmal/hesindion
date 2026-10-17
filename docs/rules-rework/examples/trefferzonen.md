# Example 6 — Trefferzonen, an optional rule set

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| trefferzonen (catalog: GRW_zonenaufschlag) | Trefferzonen-Regeln (Fokusregel Stufe I) | <https://dsa.ulisses-regelwiki.de/Fokus_TrefferzonenRegeln.html> | Aventurisches Kompendium p. 128ff |
| trefferzonen-ruestungsschutz | Trefferzonen-Rüstungsschutz (Fokusregel Stufe II) | <https://dsa.ulisses-regelwiki.de/Fokus_TreffzonenRS.html> | — |
| SA_160 | Gezielter Angriff (Spezialmanöver) | <https://dsa.ulisses-regelwiki.de/KSF_GezielterAngriff.html> | Aventurisches Kompendium p. 152 |
| SA_161 | Gezielter Schuss (Spezialmanöver) | <https://dsa.ulisses-regelwiki.de/KSF_GezielterSchuss.html> | Aventurisches Kompendium p. 153 |
| STATE_13 | Überrascht (Status) | <https://dsa.ulisses-regelwiki.de/Sta_%C3%9Cberrascht.html> | Regelwerk p. 36 |

## How a rule belongs to an optional rule set

Every draft file carries `ruleset:` — `core` (always on), `fokus.<slug>` (on when the group plays
that Fokusregel), or later `house.<slug>`. The flag sits on the **file**, not on each effect, so
a whole page switches on and off together. Three shapes turned up:

- a core page that *is* a Fokusregel (`trefferzonen`: `ruleset: fokus.trefferzonen`);
- a special ability that only means something inside one (`SA_160`, `SA_161`): owned and shown
  either way, applied only when the set is on, and listed as "nicht angewendet: Fokusregel aus"
  otherwise;
- a Fokusregel that depends on another and **replaces** a core computation while on
  (`trefferzonen-ruestungsschutz`: `requires_ruleset`, `replaces: [ruestung-und-belastung.A1]`).

## Clauses

**Trefferzonen-Regeln**

- **TZ1** A Fokusregel, Stufe I, theme Kampf.
- **TZ2** After a hit that is not defended, 1W20 decides the zone.
- **TZ3** Humanoid zones are head, torso, two arms, two legs (plus tail for some). A small
  attacker against a medium hero rolls on the large table; a large attacker on the small table.
  Decided: the table always follows the size difference, mittel for equal sizes
  (`relative-size-table`).
- **TZ4** The tables per body plan and size; odd = left, even = right.
- **TZ5** Anyone may aim at a zone, at the table's penalty; an überrascht target eases it by 2;
  Gezielter Angriff / Schuss halves it; the penalties replace the size modifiers. Decided: ease
  first, then halve (`surprised-then-halved`); both the melee and the ranged size modifier are
  replaced (`zone-replaces-size`).
- **TZ6** Kopf −10, Torso −4, Arme −8, Beine −8.
- **TZ7** Vulnerable spots of creatures, −2 to −8, if the hero knows of them.
- **TZ8–TZ10** Wundschwelle = half KO. Damage ≥ Wundschwelle causes the zone's Wundeffekt unless a
  Selbstbeherrschung check succeeds, harder by 1 per multiple; one check only.
- **TZ11** Kopf: +1 Betäubung. Torso: +1W3+1 SP. Arm: drops what that hand holds (not two-handed
  weapons, not shields). Leg: Liegend. Decided: the app takes the one-handed item out of the
  loadout, asking which hand holds what if it cannot tell (`wundeffekt-arm-drop`).
- **TZ12** Errata: Kopf is −10, not the −8 of the Trefferzonen set.

**Trefferzonen-Rüstungsschutz**

- **RS1** Without it, a complete armour protects every zone fully. Decided: offered only while
  Trefferzonen is on (`requires-trefferzonen`).
- **RS2** With it, RS is per zone, left and right apart, from the piece worn there.
- **RS3** One armour, one helmet, one piece per arm/leg zone; armours do not combine unless
  their description says so. Decided: any armour's zone piece counts as a Rüstungsteil for its
  zone (`pieces-from-other-armours`).
- **RS4** Belastung and the extra GS/INI come from Σ (zone RS × factor) — legs and arms ×2 each,
  torso ×5, head ×1 — read off a banded table. For a complete armour this gives the core table's
  numbers exactly (RS × 14).
- **RS5** Price and weight per zone. Its "Gleiches gilt auch für BE" adds no second BE method
  (`be-sentence`).

**Gezielter Angriff / Gezielter Schuss** — **GA1 / GS1** a Spezialmanöver for an aimed attack,
"entsprechend dem Zonenaufschlag erschwert"; the halving itself is stated on the Fokusregel page (TZ5).

**Überrascht** — **UE1** one action against a surprised person that cannot be defended.
Decided: the hero's Parade and Ausweichen are disabled while it is set; it is set on the
combat-setup screen and cleared when the INI roll starts the regular round (`hero-no-defence`).

## Situations

In [`situations/trefferzonen.yaml`](../../../specs/rules/situations/trefferzonen.yaml), TZ.1–TZ.27, each with one
result. The rules as draft
YAML: [`trefferzonen`](../../../specs/rules/core/trefferzonen.yaml),
[`trefferzonen-ruestungsschutz`](../../../specs/rules/core/trefferzonen-ruestungsschutz.yaml),
[`SA_160`](../../../specs/rules/abilities/SA_160.yaml), [`SA_161`](../../../specs/rules/abilities/SA_161.yaml),
[`STATE_13`](../../../specs/rules/conditions/STATE_13.yaml).

Where the app is wrong, on what the pages state outright:

- An aimed attack at a winzig opponent pays the size modifier **and** the zone penalty (TZ.7) —
  `GRW_groessenkategorie` has no gate on an announced zone.
- When the hero is hit, the zone is rolled on the hero's own size table, never the attacker's
  (TZ.10) — `CombatDamageViews` uses `hero.bodyPlan`; the page's own example (small attacker,
  medium hero → large table) comes out Torso instead of Arm. Per ruling `relative-size-table`
  the same holds between equal sizes: a Zwerg hit by a goblin rolls on the mittel table, not
  the klein one (TZ.11).
- Trefferzonen-Rüstungsschutz does not exist: no armour by zone (TZ.20–TZ.26), and without it
  any number of armours can be equipped and summed (TZ.24, as belastung 6.1).

And per decided ruling:

- Having Gezielter Angriff/Schuss halves every aimed attack; the halving belongs to the announced
  Spezialmanöver, so it is lost on horseback (TZ.16), with Unterlaufen without Verbessertes
  Unterlaufen (TZ.17), and when the hero aims without announcing it (TZ.27) —
  `CombatZonePicker`, `HitZoneModifiers.penalty` (ruling `SA_160.halving-by-manoeuvre`).
- Against an überrascht opponent the app halves first, then eases: 1 too easy (Torso 0 instead
  of −1, Kopf −3 instead of −4; TZ.4, TZ.5) — `HitZoneModifiers.penalty` (ruling
  `surprised-then-halved`).
- An aimed shot keeps the ranged target-size modifier: Kopf of a groß target with Gezielter
  Schuss is −1 instead of −5 (TZ.8) — `RangedModifiers.groesse` (ruling `zone-replaces-size`).
- A failed Wundeffekt check on an arm only reminds; the one-handed weapon stays in hand (TZ.14) —
  `WoundEffectCatalog` (ruling `wundeffekt-arm-drop`).
- A surprised hero can still parry and dodge, and combat setup never asks whether the hero is
  surprised (TZ.15) — `StateCatalog.ueberrascht`, `CombatSetupView` (ruling `hero-no-defence`).

## Surprises

- A **Kettenhelm on a Lederrüstung** costs a Belastung Stufe under Trefferzonen-RS: 42 → 43
  crosses a band (TZ.22). Plate **on the torso alone** picks up the −1 GS/INI that complete plate
  does not have (TZ.23).
- Anyone may aim while the Fokusregel is on (TZ.2). But the SF pages call Gezielter
  Angriff/Schuss a **Spezialmanöver**, and the Fokusregel page says that *having* the SF halves
  the penalty. Decided: the halving comes only from announcing the manoeuvre, so it is lost on
  horseback, with Unterlaufen and next to Sturmangriff, and the hero aims at the full penalty
  instead (TZ.16, TZ.17, TZ.27; ruling `SA_160.halving-by-manoeuvre`).
- The order of "halve" and "ease by 2" is a one-point difference nobody wrote down (TZ.4, TZ.5).
  Decided in the order the page names them: ease, then halve.
- The surprise action comes *before* the regular Kampfrunde, so a surprised hero's fight starts
  with a defenceless step ahead of the INI roll (TZ.15).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md), generated from the rule
files — look for `trefferzonen`, `trefferzonen-ruestungsschutz`, `SA_160` and `STATE_13`.
