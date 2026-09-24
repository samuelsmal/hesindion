# Example 10 — Sturmangriff (on foot)

**Status: draft.** Page read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

Not the mounted "Sturmangriff zu Pferd", which is an order in Reiterkampf (RK14) — see
[Example 2](./reiterkampf.md) and the decided ruling `two-sturmangriffe`.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| SA_62 | Sturmangriff (Spezialmanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Sturmangriff.html> | Regelwerk p. 250 |

## Clauses

- **ST1** Needs at least 4 Schritt run-up and GS of at least 4; the movement is part of the attack.
- **ST2** On a hit, TP + 2 + half the attacker's GS, at most +10 in total, and at most the natural GS.
- **ST3** Defended normally; on a miss, the defender gets a Passierschlag.
- **ST4** Cannot be combined with Finte. Erschwernis −2.
- **ST5** Combat techniques: Hiebwaffen, Raufen, Schwerter, Stangenwaffen, Zweihandhiebwaffen,
  Zweihandschwerter.
- **ST6** Prerequisites: MU 13, Vorstoß, Wuchtschlag I — purchase only.

## Situations

In [`situations/sturmangriff.yaml`](./situations/sturmangriff.yaml), 10.1–10.8: run-up (10.1),
technique (10.2), Finte (10.3), a miss (10.4), both caps (10.5, 10.6), with Wuchtschlag (10.7),
unarmed (10.8). The plain case, rounding, plate and the mounted ban are
[`reiterkampf.yaml`](./situations/reiterkampf.yaml) 5.9 and 5.12–5.15, not repeated. The rule as
draft YAML: [`SA_62`](./rules/abilities/SA_62.yaml), now with ST5 and ST6.

Where the app is wrong: SA_62 is never offered on foot at all; the one `CombatManeuver.sturmangriff`
is the mounted order (`CombatAttackViews.availableManeuvers` gates it on `mountedActive &&
hero.hasBerittenerKampf`). Every situation here is therefore "not offered" today.

The two caps only bind when the current GS is raised: for GS 4–16, 2 + ⌈GS/2⌉ stays within +10, and
it passes the natural GS only if something lifts the current GS above it. So the caps are rare but
real — a speed spell or elixir reaches them (10.5, 10.6).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md) — look for `SA_62`. New and open:
`sturmangriff-cap-scope` (does "+10 insgesamt" cap other TP bonuses on the same attack). The
cross-cutting ones on techniques and manoeuvre combination decide 10.2 and 10.7.
