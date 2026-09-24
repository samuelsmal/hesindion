# Example 13 — Verweichlicht

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| DISADV_57 | Verweichlicht | <https://dsa.ulisses-regelwiki.de/nachteil.html?nachteil=Verweichlicht> | Aventurisches Kompendium p. 133 |

It meets the Trefferzonen Fokusregel's Wundeffekte (example 6, not written yet) and
[Example 1](./belastung.md)'s ruling on which talents Belastung reaches.

## Clauses

- **VW1** −2 on the Selbstbeherrschung check (Handlungsfähigkeit bewahren or Störungen ignorieren)
  made because of a **Wundeffekt**.

Two things make this small rule a useful example:

- **The condition is the check's cause, not its talent.** Selbstbeherrschung is rolled for many
  reasons; only one of them is hindered. A check has to carry why it is being rolled.
- **The rule only exists inside a Fokusregel.** Wundeffekte belong to Trefferzonen. With that
  Fokusregel off, the disadvantage does nothing — and a player who bought it for −3 AP should be
  told so, not left to wonder.

Belastung does not reach Selbstbeherrschung: the book flags it "no", which agrees with the ruling
`COND_1.belastung-reach` (not a movement talent). So in plate the check is unchanged (13.2).

## Situations

In [`situations/verweichlicht.yaml`](./situations/verweichlicht.yaml), 13.1–13.5. The rule as draft
YAML: [`DISADV_57`](./rules/disadvantages/DISADV_57.yaml).

The app is right on the check itself (13.1–13.3: catalog `DISADV_57`, `Situation.woundEffectProbe`).
What it lacks is saying *why* the rule did not apply: with Trefferzonen off the disadvantage is
silently inert (13.4), and the not-applied Belastung on a check in armour is not listed (13.2).
Per the decided ruling `verweichlicht-scope`, "Wundeffekte" is the Fokusregel's term: Status
Blutend's Selbstbeherrschung check is not hindered (13.5), and without Trefferzonen the hero sheet
says the disadvantage needs it.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md) — look for `DISADV_57`.
