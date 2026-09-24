# Example 5 — Reichweite and Unterlaufen

**Status: draft.** Pages read 2026-09-23. Rulings: see [`RULINGS.md`](./RULINGS.md).

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| reichweite (catalog: GRW_reichweite) | Nahkampfreichweite (core rule) | <https://dsa.ulisses-regelwiki.de/Nahkampf/nahkampfreichweite.html> | Regelwerk p. 230f |
| SA_172 | Unterlaufen I–II (Basismanöver) | <https://dsa.ulisses-regelwiki.de/KSF_Unterlaufen.html> | Aventurisches Kompendium p. 155 |
| SA_173 | Verbessertes Unterlaufen (passiv) | <https://dsa.ulisses-regelwiki.de/KSF_VerbessertesUnterlaufen.html> | Aventurisches Kompendium p. 156 |

## Clauses

**Nahkampfreichweite**

- **RW1** Every melee weapon has a reach: kurz, mittel or lang.
- **RW2** Reach also decides the penalties in Beengte Umgebung (not part of this example).
- **RW3** The shorter weapon pays on its AT: kurz against mittel −2, kurz against lang −4, mittel
  against lang −2. The longer weapon gets nothing. Written in the draft as −2 per reach step.
- **RW4** The same as a matrix.

**Unterlaufen (SA_172)**

- **U1** Each Stufe ignores one step of reach disadvantage against a longer weapon; what cannot
  be ignored is at least lowered by one step.
- **U2** Announced before the AT; the AT carries whatever reach penalty remains; a missed AT gives
  the opponent a Passierschlag; it lasts one attack.
- **U3** Cannot be combined with a Spezialmanöver.
- **U4** An opponent's bonus from Auf Distanz halten still counts against the AT.

**Auf Distanz halten (SA_152)**, written for U4

- **AD1** The opponent of a fighter with the longer weapon has AT −1 more per Stufe. Asked as an
  opponent fact, with its Stufe (ruling `SA_172.auf-distanz-halten`).
- **AD2** The user cannot use Basismanöver that round; announced at the start of the round.
- **AD3** Kurz against lang with Auf Distanz halten II: AT −6; it stays against Unterlaufen.

**Verbessertes Unterlaufen (SA_173)**

- **VU1** Lifts U3: Unterlaufen may be combined with Spezialmanöver.

## Situations

In [`situations/reichweite.yaml`](./situations/reichweite.yaml), RW.1–RW.16. The rules as draft
YAML: [`reichweite`](./rules/core/reichweite.yaml), [`SA_172`](./rules/abilities/SA_172.yaml),
[`SA_173`](./rules/abilities/SA_173.yaml), [`SA_152`](./rules/abilities/SA_152.yaml).

Where the app is wrong: the reach matrix is right (`GRW_reichweite` in the catalog,
`WeaponReach.atPenaltyAgainst` for the chips), but **Unterlaufen and Verbessertes Unterlaufen do
not exist in the app** — no manoeuvre, no catalog clause (both `todo`), so a hero who owns them
pays the full reach penalty (RW.7–RW.9, RW.14). Auf Distanz halten does not exist either
(catalog `todo`), so an opponent's −1 per Stufe is never applied (RW.12).

The format needed two new things here: a line lowered **by steps of a scale** rather than by a
number (U1), and a `was:` on a lowered line so the breakdown can show what the ability took away.

## Rulings

All rulings, open and decided, are in [`RULINGS.md`](./RULINGS.md), generated from the rule
files — look for `SA_172` and the shared `sf-technique-lists` and `manoeuvre-combination`.
