# Example 19 — What Boronmir took on 2026-09-24

**Status: draft, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

The 2026-09-24 export of Boronmir
([`Boronmir Siebenfeld von Greifenfurt.json`](../../../specs/heroes/Boronmir%20Siebenfeld%20von%20Greifenfurt.json))
has three rules no earlier example covered: a formation that replaces his Plänkler-Formation, an
advantage on a value that belongs to a Fokusregel, and a disadvantage whose only mechanical part
is a check the GM calls for. His fourth new entry, Belastungsgewöhnung II, is already covered by
[example 1](./belastung.md): in plate he now carries Belastung I.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_862 | Formation (passiv) | <https://dsa.ulisses-regelwiki.de/KSF_Formation.html> | Aventurisches Kompendium II pp. 126–127 |
| ADV_54 | Eisern | <https://dsa.ulisses-regelwiki.de/vorteil.html?vorteil=Eisern> | Aventurisches Kompendium p. 132 |
| DISADV_37 | Schlechte Eigenschaft (Autoritätsglaube) | <https://dsa.ulisses-regelwiki.de/nachteil.html?nachteil=Schlechte%20Eigenschaft> | Regelwerk p. 176 |

## Clauses

**Formation (SA_862)**: Plänkler-Formation made larger. The clauses are SA_884's word for word,
with other numbers.

- **F1** Up to four more fighters, at most half a Schritt in front, behind, left or right, form a
  Formation.
- **F2** Everyone in it gets either +2 AT or +2 VW (every defence).
- **F3** The formation agrees on one of the two when it forms.
- **F4** Only one of them needs the ability. With more holders, more fighters can benefit.
- **F5–F7** Prerequisite Kriegskunst 6 (he raised it to 7 for this); all combat techniques; 20 AP.

**Eisern (ADV_54)**

- **E1** Wundschwelle +1. His Wundschwelle is ⌈KO 15 / 2⌉ = 8 (trefferzonen.TZ8), with Eisern 9.
- **E2, E3** No prerequisite; 5 AP.

**Schlechte Eigenschaft (DISADV_37)**: the hero file gives `sid: 2`, which is Autoritätsglaube.

- **SE1** Faced with a trigger, the hero must pass a Willenskraft check to keep control.
- **SE2** If he passes, nothing happens. If he fails, he acts out the Eigenschaft.
- **SE3** It lasts as long as the trigger does.
- **SE4** The GM may make the check harder or easier, depending on how strong the trigger is.
- **SE5** At most two per hero, and no pair that excludes each other. This is for purchase only.
- **SE6** The list of Eigenschaften with their text and cost. Autoritätsglaube: "zweifelt nicht an
  den Worten höhergestellter Personen, selbst wenn sie unlogische Befehle erteilen oder
  unglaubwürdig sind", −5 AP.
- **SE7–SE9** No prerequisite; cost per Eigenschaft; a note on Sikaryan-Durst.

Three things these rules add to the set:

- **A value that belongs to a Fokusregel.** The Wundschwelle is defined in Trefferzonen, but the
  app treats it as core (AGENTS.md). Eisern raises that value, so it runs into the question
  Verweichlicht already raised: what does a trait do when its Fokusregel is off?
- **A rule whose effect is a check it offers.** Schlechte Eigenschaft changes no value. It asks
  for a Willenskraft check when the GM names a trigger. The check has a cause, as the checks in
  Verweichlicht (a Wundeffekt) and Aufmerksamkeit (a Hinterhalt) do. So a check that carries its
  cause is now needed by three rules.
- **A rule written by copying another one.** Formation is Plänkler-Formation with larger
  numbers. The rulings decided for SA_884 are asked again here rather than carried over, and the
  two SFs meet when a companion holds the smaller one.

## Rulings

New, all open:

- `SA_862.formation-mounted`: can riders form a Formation? The recommendation is no, as decided
  for Plänkler-Formation.
- `SA_862.formation-and-plaenkler`: can a fighter stand in both a Formation and a
  Plänkler-Formation and add +2 and +1? The recommendation is one at a time.
- `ADV_54.eisern-scope`: without the Trefferzonen Fokusregel, does Eisern do anything? The
  recommendation follows Verweichlicht: it works only through the Fokusregel, and the sheet
  says so.
- `DISADV_37.schlechte-eigenschaft-check`: what does the app offer for the Willenskraft check?
  The recommendation is a "Beherrschen" action on the disadvantage that opens the check with its
  cause and the GM's modifier.

Reused: `COND_1.belastung-reach` (Willenskraft is not hindered by Belastung), `ADV_49` Zäher Hund
on the Schmerz line.

## Situations

[`situations/boronmir-neu.yaml`](../../../specs/rules/situations/boronmir-neu.yaml), 19.1–19.12, with Boronmir's
new values: Rabenschnabel 16/11, Langschwert 14/11, Großschild 6/13, AW 7, Belastung I in plate,
LE 37, Wundschwelle 9. The derivation is in the file's header. Rule files:
[`SA_862`](../../../specs/rules/abilities/SA_862.yaml), [`ADV_54`](../../../specs/rules/advantages/ADV_54.yaml),
[`DISADV_37`](../../../specs/rules/disadvantages/DISADV_37.yaml).

## What the app gets wrong

| Finding | Where | Basis | Situation |
|---|---|---|---|
| Formation does not exist: no toggle, no +2 AT or VW. With Plänkler-Formation gone, Boronmir is offered no formation at all | catalog SA_862 `todo`, `CombatAbility`, `CombatSetupView` | page (F1, F2) | 19.1, 19.2 |
| Eisern's +1 is applied but never named: the sheet shows "Wundschwelle 9" with no breakdown, and the take-damage row does not say why it is 9 | `HeroDetailView` (`wundschwelle.max`), `CombatWundschwelleRow` | page (E1) | 19.6–19.8 |
| Schlechte Eigenschaft offers no check. The sheet lists "Schlechte Eigenschaft (Autoritätsglaube)", and the Willenskraft check is left for the player to find, with the GM's modifier as an unnamed free modifier | `HeroDetailView.disadvantagesSection`, `TalentProbeModal`, catalog DISADV_37 `todo` | page (SE1, SE4) | 19.10, 19.11 |

Already in README's table (example 14): a formation is only ever offered to its holder (19.3).

Waiting on an open ruling:

- **Formation mounted:** the app shows AT 20 on Kupperus. That is right only because it has no
  Formation to add (19.4, `formation-mounted`).
- **Formation and Plänkler-Formation:** neither is offered (19.5, `formation-and-plaenkler`).
- **Eisern without Trefferzonen:** the sheet shows Wundschwelle 9 with no note (19.9,
  `eisern-scope`).
- **The check for Schlechte Eigenschaft:** what to offer, and where (19.10–19.12,
  `schlechte-eigenschaft-check`).

Confirmed correct: Wundschwelle 9 (⌈KO/2⌉ + Eisern, `DerivedValueFormulas.wundschwelle`) and the
Wundeffekt multiples that use it (19.7, 19.8).
