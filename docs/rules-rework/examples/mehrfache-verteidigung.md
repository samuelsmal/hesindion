# Example 3 — Mehrfache Verteidigung, Vinsalt-Stil and Verteidigungshaltung

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| GRW_mehrfacheVerteidigung | Mehrfache Verteidigung (core rule; section "3. Verteidigung" of the Nahkampf chapter) | <https://dsa.ulisses-regelwiki.de/Nahkampf.html> | Regelwerk p. 229ff |
| SA_923 | Vinsalt-Stil | <https://dsa.ulisses-regelwiki.de/SF_Kampfstilsonderfertigkeiten/bewaffnete-kampfstile/vinsalt-stil.html> | Aventurisches Kompendium 2 p. 138 |
| SA_65 | Verteidigungshaltung | <https://dsa.ulisses-regelwiki.de/KSF_Verteidigungshaltung.html> | Regelwerk p. 250 |
| — | Schicksalspunkte, the use "Verteidigung" | <https://dsa.ulisses-regelwiki.de/GR_Schicksalspunkte.html> | Regelwerk p. 29ff |

## Clauses

**Mehrfache Verteidigung**

- **MV1** One defence per attack. Several defences per Kampfrunde are allowed against different
  attacks; the first is unmodified, each further one −3 more.
- **MV2** So −3, −6, −9 …; the count starts over each Kampfrunde.
- **MV3** When the penalties bring a defence's value to 0 or below, no more defences of that
  kind; another kind whose value is still above 0 may still be used.
- **MV4** The penalties carry over to **every** kind of defence, whether they came from melee or
  ranged attacks.
- **MV5** Only heroes and people with Schicksalspunkte get several defences (no Schip needs to be
  spent); other beings get one per round.
- **MV6** Non-humanoid beings always defend at full value.

**Vinsalt-Stil (SA_923)**

- **VS1** The step for multiple defences is −2 instead of −3.
- **VS2** Techniques: Armbrüste, Fechtwaffen, Zweihänder.
- **VS3** Compatible with Meisterparade and Machtvolle Meisterparade.

**Verteidigungshaltung (SA_65)**

- **VH1** +4 on the Verteidigungswert for the current Kampfrunde; no actions that round; must be
  announced at the start of the round. Per the decided rulings: the +4 is on PA and AW against any
  attack (`vh-scope`), free actions stay (`vh-free-actions`), and it stacks with the Schip
  "Verteidigung" to +8 (`vh-stacking`; V11, V12).
- **VH2** Melee techniques only.
- **VH3** Visible to the other combatants.

**Schicksalspunkte — Verteidigung**

- **SP-verteidigung** 1 Schip: +4 on all defences until the end of the round, at any time
  before the defence is rolled. It also raises how many defences are possible, because the value
  reaches 0 later (MV3).

## Situations

In [`situations/mehrfache-verteidigung.yaml`](./situations/mehrfache-verteidigung.yaml), V1–V13.
The rules as draft YAML: [`mehrfache-verteidigung`](./rules/core/mehrfache-verteidigung.yaml),
[`SA_923`](./rules/abilities/SA_923.yaml), [`SA_65`](./rules/abilities/SA_65.yaml),
[`schicksalspunkte`](./rules/core/schicksalspunkte.yaml).

Where the app is wrong, independent of the open rulings:

- **Parries and dodges are counted apart** (`CombatSituation.defensesSoFar`, fed by
  `CombatView`'s `parriesThisRound` / `dodgesThisRound`). MV4 carries the penalty across every
  kind: a dodge after a parry is −3, not 0 (V4, V5, V7). The catalog note on
  `GRW_mehrfacheVerteidigung` states the per-kind counting as intended.
- **A defence at 0 or below is never blocked** (`CombatRootView.defenseBlocked`); MV3 takes that
  kind away (V9).
- **Verteidigungshaltung does not exist in the app** (catalog status `todo`) (V11–V13).
- **The Schip +4 on defences cites no rule** (`DefenseModifiers.schipDefenseBoost`, `rules: []`)
  (V10).

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md) — look for
`mehrfache-verteidigung`, `SA_65`, and the shared `kampfstil-techniques`, which Vinsalt-Stil's
technique list raises again (and more sharply: a defensive style that lists Armbrüste).
