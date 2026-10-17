# Example 7 — Liegend

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](../../../specs/rules/RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| STATE_10 | Liegend (Status) | <https://dsa.ulisses-regelwiki.de/Sta_Liegend.html> | Regelwerk p. 36 |
| — | Handlungsunfähig (Status) | <https://dsa.ulisses-regelwiki.de/Sta_Handlungsunf%C3%A4hig.html> | Regelwerk p. 36 |
| — | Bewusstlos (Status) | <https://dsa.ulisses-regelwiki.de/St_Bewusstlos.html> | Regelwerk p. 34 |

## Clauses

**Liegend (STATE_10)**

- **L1** The person is lying down, woken or knocked over; in combat this changes things.
- **L2** While lying, they move only very slowly: GS 1.
- **L3** Their defence is −2, their attacks −4 — melee AT and FK alike (ruling *liegend-attacks*).
- **L4** Standing up costs 1 action. An opponent in reach may take a Passierschlag; a successful
  Körperbeherrschung (Kampfmanöver) check avoids it.

**Handlungsunfähig** — GS 0, no actions and no defences; "in most situations" the person also
counts as Liegend; the GM may allow free actions to speak. Ruling *handlungsunfaehig-liegend*:
when the hero becomes Handlungsunfähig, the app asks whether the hero is now Liegend.

**Bewusstlos** — the body is not hindered, the mind is absent; the person is also Handlungsunfähig.
It does not name Liegend itself; that comes through Handlungsunfähig.

## Situations

In [`situations/liegend.yaml`](../../../specs/rules/situations/liegend.yaml), 7.1–7.8: the hero lying (7.1), shooting
from the ground (7.2), attacking a prone opponent (7.3), Bewusstlos and Handlungsunfähig (7.4, 7.5),
standing up (7.6, 7.7), and Liegend beside capped Zustände (7.8). The rule as draft YAML:
[`STATE_10`](../../../specs/rules/conditions/STATE_10.yaml).

Where the app is wrong: a prone hero shoots at no penalty; the catalog's −4 reaches melee attacks
only (7.2); a Handlungsunfähig hero moves at GS 1 instead of 0, because
`Hero.effectiveGeschwindigkeit` only knows Liegend (7.4); Handlungsunfähig never asks whether the
hero lies: set by hand or through Bewusstlos it always implies Liegend (7.4), and reached through a
Zustand at Stufe IV it neither asks nor lowers GS, because `Hero.impliedStateIDs` reads only states
that are set, not `isHandlungsunfaehigFromZustaende` (7.5); there is no stand-up action,
so its action cost and the opponent's Passierschlag go unmentioned (7.6). The opponent's own AT −4
and GS 1 are not told to the player (7.3) — display only, since opponents are not modelled
(ADR-0005).

The shape the format has to hold: one status whose effects land on whichever side carries it — the
hero's own lines when the hero lies, an opponent line when the opponent does — and a `set` (GS 1)
that competes with another `set` (Handlungsunfähig's GS 0).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](../../../specs/rules/RULINGS.md), generated from the rule
files — look for `STATE_10`.
