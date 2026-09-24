# Example 9 — Wuchtschlag

**Status: draft.** Page read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_67 | Wuchtschlag I–III (Basismanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Wuchtschlag.html> | Regelwerk p. 250 |

## Clauses

- **W1** AT −2 per Stufe; on a hit, TP +2 per Stufe.
- **W2** Erschwernis −2/−4/−6 — W1 restated.
- **W3** Combat techniques: Hiebwaffen, Kettenwaffen, Raufen, Schwerter, Stangenwaffen,
  Zweihandhiebwaffen, Zweihandschwerter.
- **W4** Prerequisites per Stufe (KK 13/15/17, the previous Stufe) — purchase only.

## Situations

In [`situations/wuchtschlag.yaml`](./situations/wuchtschlag.yaml), 9.1–9.8. The rule as draft
YAML: [`SA_67`](./rules/abilities/SA_67.yaml).

Where the app is wrong: Wuchtschlag is offered with any weapon, including a Dolch (9.5) — on
purpose, per the catalog's note on SA_67, until the loadout can name Raufen (issue #14); the decided
ruling `sf-technique-lists` wants it offered only with a technique of W3. Everything else matches:
the catalog implements W1 (`SA_67`), and every Stufe up to the owned one is offered, so a lower
Stufe can be chosen (9.3), as the decided ruling `tiered-manoeuvre-stufe` has it.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md). This example rests on the same
three cross-cutting ones as Finte, all decided.
