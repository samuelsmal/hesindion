# Example 20 — Probe: Zaubermodifikationen and Verbotene Pforten

**Status: draft, for review.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

A probe, not part of Boronmir's sweep. The examples so far are melee; this one drafts the core
rule every spell cast runs through, and one SF that changes how a cast is paid for. The question
it answers is whether magic needs engine concepts the draft vocabulary does not have yet. The
answer is in [What it means for the engine](#what-it-means-for-the-engine).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| zaubermodifikationen | Zaubermodifikationen (section 2 of Spruchzauberei, and the cost sentences of section 5) | <https://dsa.ulisses-regelwiki.de/Magie_Spruchzauberei.html> | Regelwerk p. 254 ff. |
| SA_74 | Verbotene Pforten | <https://dsa.ulisses-regelwiki.de/allgemeine_magische_sonderfertigkeit.html?sonderfertigkeit=Verbotene+Pforten> | Regelwerk p. 285 |

## Clauses

**Zaubermodifikationen**

- **ZM1** One modification per 4 full points of the spell's FW.
- **ZM2** Kosten, Zauberdauer and Reichweite move along fixed steps, at most one step per
  category. So Erzwingen and Kosten senken exclude each other (a reading).
- **ZM3, ZM4** Reichweite never goes down, and a spell with Reichweite selbst cannot go up.
- **ZM5** A maintained spell's upkeep per interval is one step below its cost and follows
  Kosten senken, never under 1 AsP.
- **ZM6** Any combination is allowed, but none of them twice.
- **ZM7** A spell of another tradition cannot be modified.
- **ZM8** The table of steps: 1–32 Aktionen, Berühren to 64 Schritt, 1–32 AsP.
- **ZM9, ZM10** What counts as a touch. This is text only.
- **ZM11** The six modifications:
  - Erzwingen: cost +1 step, +1 on the check.
  - Kosten senken: cost −1 step, −1.
  - Reichweite erhöhen: range +1 step, −1.
  - Zauberdauer erhöhen: time +1 step, +1.
  - Zauberdauer senken: time −1 step, −1.
  - Geste or Formel weglassen: −2 each.

  Some spells exclude Erzwingen or Kosten senken in their own text.
- **ZM12** The cost after the modifications is paid in AsP. A failed spell pays half,
  counting the base cost plus the first interval.

**Verbotene Pforten (SA_74)**

- **VP1** LeP may pay for the cost in place of AsP, but at least 1 AsP per spell.
- **VP2** This takes a Selbstbeherrschung check. If it fails, the spell fails.
- **VP3** Then half the cost is paid, from AsP first and then from LE.
- **VP4, VP5** MU 12; 10 AP.

## Rulings

New, all open:

- `zaubermodifikationen.omit-counts`: does leaving out a Geste or a Formel use up one of the
  FW/4 modifications? The recommendation is yes: the page lists them among the modifications.
- `zaubermodifikationen.cost-off-table`: what do Erzwingen and Kosten senken do to a cost that
  is not on the table (Armatrutz "4/8/16 AsP", Balsam "1 AsP pro LeP")? The recommendation is
  that a step means ×2 or ÷2 for any amount, rounded up, at least 1 AsP.
- `SA_74.vp-sequence`: is the Selbstbeherrschung check rolled before the spell check or after
  it? The recommendation is before, as a gate, the way Reiterkampf's orders put the Reiten
  check first.

Reused: `round-up`, for the half cost.

## Situations

[`situations/probe-magie.yaml`](./situations/probe-magie.yaml), 20.1–20.8, with a generic
Gildenmagierin (LE 29, AsP 30, Ignifaxius FW 9, Flim Flam and Armatrutz FW 8). Rule files:
[`zaubermodifikationen`](./rules/core/zaubermodifikationen.yaml),
[`SA_74`](./rules/abilities/SA_74.yaml).

## What the app gets wrong

| Finding | Where | Basis | Situation |
|---|---|---|---|
| No spell ever costs AsP. `baseCost` is `Int(detail.aeCostShort)`, and every spell's short cost has a unit ("8 AsP"), so it is nil for all 445 spells and the charge is skipped. Found by reading the code, not by running it | `SpellProbeModal.baseCost`, `CombatSpellViews.baseCost`/`deductCost` | page (ZM12) | 20.1 |
| No Zaubermodifikation can be chosen: the modal shows "max N Modifikationen" as text only. `MagicModifiers.spellMods` exists, but nothing sets `Situation.spellModifications` | `SpellProbeModal.modificationsPanel`, `CombatSpellViews` | page (ZM1, ZM11) | 20.2–20.6 |
| Geste and Formel weglassen are toggles at any FW and never count toward a limit | `SpellProbeModal` | waits on `omit-counts` | 20.4 |
| A maintained spell's upkeep is never charged. Only the −1 on other casts exists, as a stepper the player sets by hand | `MagicModifiers.maintainedSpells` | page (ZM5) | 20.5 |
| Verbotene Pforten does not exist, so a cast is offered however few AsP the caster has | catalog SA_74 `todo`, `SpellProbeModal` | page (VP1) | 20.7, 20.8 |

Outside this probe, noticed in passing: the app's "Ablenkung" picker (+3, ±0, −3) changes the
spell check. On the page, that table is the Selbstbeherrschung (Störungen ignorieren) check for
keeping concentration (section 3; `MagicModifiers.distraction`, `rules: []`).

## What it means for the engine

Every `# FORMAT:` note in the two files, sorted by whether the set already has the concept.

**New: nothing in the set needs these yet.**

1. **An action with parameters that rules move.** A spell has a cost (a base plus an optional
   upkeep per interval), a casting time and a range. Modifications shift them along ordered
   scales (`shift`), and later rules read the result: the charge, the multi-round cast.
   - The set's rules modify check values, TP and derived values, never the cost or duration
     of the action being taken.
   - The export gives these parameters as free text: none of the 445 costs is a plain number.
2. **Resource pools with charges.** Costs are charged to named pools (`charge`), sometimes
   after the roll and depending on its outcome. A cost can be split between two pools at the
   player's choice, with a minimum in one, and fall through in a fixed order (AsP, then LE).
   - Schips have a fixed price, and Reiterkampf redirects *damage*. Neither splits a price or
     falls through.
   - Paying LeP is not damage (no RS, no Wundschwelle) but must still lower LE, so Schmerz
     follows.
3. **A cost that recurs over game time** (ZM5): an amount per 5 Minuten or per Stunde for as
   long as the caster keeps a spell up. The set has spans and durations but no charge that
   runs, and the app keeps no game clock.

**Variations: the concept exists, in a new setting.**

- The FW/4 budget, one step per category and no repeats use `limit`, as in
  `kampfsonderfertigkeiten` (one Basis- and one Spezialmanöver per action). The only difference
  is a max computed from a value.
- The ZM8 steps are an ordered scale (`reichweite`) held in `provides: tables` (`trefferzonen`).
- Legality read from the spell (Reichweite selbst, Fremdtradition) is `forbid`, as
  `reiterkampf.RK4` reads the weapon.
- "Bei einigen Zaubern nicht anwendbar" puts the exceptions in each spell's own text, as the
  Waffenvorteile live in each weapon's file (`waffeneigenschaften`).
- Half cost on a failure is `on_failure` (trefferzonen.TZ8, DISADV_37.SE2) plus the shared
  `round-up` ruling.
- A casting time in Aktionen is a multi-round action. The app already has one, and
  `costs: action` exists (reiterkampf).
- Selbstbeherrschung before the cast is `requires_check` gating an offer, as Reiterkampf's
  orders do. **If `vp-sequence` is answered "after" instead, this becomes new**: one check
  overturning another's result.
- A check with no Anwendungsgebiet is as DISADV_37.SE1.

Three new concepts in two rules, and all three are about resources and actions, which the melee
set never needed. They extend the engine rather than reshape it: a check still sums named lines
and cites clauses. Liturgies (KaP), rituals and other resource SFs are the same concepts again,
but the design has to include them from the start rather than bolt them on later.
