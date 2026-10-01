# Mount in pain (issue #48) — design

## 1. Goal

A mount that loses LeP gets Schmerz, and Schmerz lowers its GS, its AT and its VW. The app keeps the
mount's LeP (`Pet.currentLifeEnergy`) but gives the mount no Schmerz, so the Sturmangriff zu Pferd
(reiterkampf.RK14) always uses the export's GS. Ruling `SA_62.sturmangriff-gs` asks for the current GS.

The mount's Schmerz and everything it changes come from the rules engine, not from Swift in the
app. Success:

- The engine derives the mount's Stufe of Schmerz from the breed's own thresholds and the mount's
  current and max LeP, and applies COND_6.SZ5 and Zähes Tier to the mount.
- RK14's TP line reads the mount's current GS from the engine; the app's Swift Sturmangriff lines go.
- Every screen that shows or uses the mount's GS, AT or VW shows the engine's result and its origin
  (ADR-0018). At Stufe IV the mount's actions are disabled, with the reason.

## 2. What the rules say

- **A creature has its own thresholds.** "Schmerz +1 bei: Hier ist aufgelistet, wann ein Wesen durch
  zu niedrige Lebensenergie eine Stufe Schmerz erleidet." (Aufbau der Kreaturenbeschreibung,
  `RE_AufbauKreaturenbeschreibung.html`.) COND_6.SZ3's fractions (¾, ½, ¼) are the hero's ("ein Held")
  and do not apply to a creature.
- **The effects are COND_6.SZ5's.** A Zustand lowers a creature's VW "wie üblich" (same page). Stufe
  I–III: all checks (AT, VW, the creature's talents) −1 per Stufe, GS −1 per Stufe. Stufe IV:
  Handlungsunfähig (STATE_8), GS 0. INI does not change (an INI roll is not a Probe).
- **Zähes Tier** (`vor-und-nachteile/tiervor-und-nachteile/vorteile-tiere/zaehes-tier.html`): "das
  Tier [darf] die Auswirkungen der höchsten Stufe des Zustands Schmerz ignorieren … Es erleidet
  lediglich die Auswirkungen der nächstniedrigeren Stufe … Bei Schmerz Stufe IV wird das Tier dennoch
  Handlungsunfähig. Schmerz Stufe I wird so behandelt, als hätte es keine Stufe Schmerz." The animal
  version of Zäher Hund (ADV_49).
- **Schnell** gives GS +25 %. Kupperus's GS 15 already includes it; Schmerz lowers GS from 15.
- Reiterkampf, Tierheilkunde and Tierische Begleiter have no other rule on a mount's Schmerz. RK10's
  Reiten check after SP to the mount is the rider's check and does not change.

## 3. Decisions

| Question | Decision |
|---|---|
| Where the Stufe and its effects come from | The rules engine (owner, 2026-10-01) |
| Scope | The mount, plus RK14's TP line from the engine (owner) |
| Thresholds for a mount whose max LeP differs from the profile | printed ÷ profile LeP × the mount's max LeP; "5 LeP oder weniger" stays fixed. This is ruling `svellttaler-schmerz-thresholds`'s decided answer (owner) |
| Comparison with a scaled threshold | Exact, as ruling `COND_6.schmerz-thresholds` for the hero: Stufe I at LeP ≤ 89.5 (owner) |
| Elenviner Vollblut EV10 | The same ruling holds for every horse with printed thresholds: 49/70, 33/70, 16/70 (owner) |
| Engine approach | The mount is a subject of its own (approach A), not `mount.`-prefixed copies of COND_6 (owner) |
| Which effects the app applies | All of SZ5, wherever the app reads the value: GS, the AT of the mount's attacks, VW, Stufe IV (owner: "what the rules say") |
| Fact names on the hero's side | Readable: `mount.gs`, `mount.schmerz`, `mount.handlungsunfaehig` (owner) |

For Kupperus (profile 75 LeP, 137 LeP after Heldenwuchs, Kampftier and 16 bought): Stufe I at
≤ 89 LeP (89.5), II at ≤ 60 (60.3), III at ≤ 29 (29.2), IV at ≤ 5.

## 4. Rule files

1. **Zähes Tier** gets a rule file under `specs/rules/advantages/` with the page hash, encoded as
   ADV_49 with `useLevel`: the effects of Stufe − 1, none at Stufe I, Handlungsunfähig still at IV.
2. **svellttaler-kaltblut.SK10** loses its four `add: { to: "mount.level(rule: COND_6)" }` effects
   (a target nothing reads). It `suppress`es COND_6.SZ3's line and `derive`s `level(rule: COND_6)` for
   the creature that is the subject: three `proportion` terms with `max: 1`, one per scaled threshold,
   plus SZ3's own `{ of: 6, above: leCurrent, max: 1 }` for "5 LeP oder weniger". `times` is a decimal
   number, so the harness covers each edge value (exactly at and one above each threshold).
3. **elenviner-vollblut.EV10** is encoded in the same way (49/70, 33/70, 16/70). Its `unencoded` goes.
4. Ruling **`svellttaler-schmerz-thresholds`**: the notes now match the decided answer (scaled, not
   fixed), and `appliesTo` names EV10 too. RULINGS.md follows.
5. **COND_6.SZ5** adds `vw` to its Stufe I–III list (`[at, pa, aw, fk, check.modifier, gs, vw]`).
   "alle Proben" includes a creature's defence, and the creature page says a Zustand lowers the VW
   "wie üblich". `vw` is a new target in the vocabulary (§5). The hero has no `vw`, so nothing changes
   for the hero.
6. **reiterkampf.RK14** does not change: it reads the fact `mount.gs`, which the hero's situation now
   states from the mount's evaluation.
7. MIGRATION.md records SK10, EV10, SZ5's `vw` and the new rule.

## 5. Engine (`Packages/RulesEngine`)

1. **`CreatureSheet`**: a plain `Codable, Hashable, Sendable` struct, the creature's `HeroSheet`. It
   holds the owned rules (the breed rule, the animal advantages with a rule file), the base values
   from the companion build (`gs`, `leMax`, `vw`, `at(with: <attack>)` per attack) and the current LE.
2. **`Situation(creature:)`** states the owned rules, the base values, and the current LE as the `le`
   pool. COND_6 then applies without change. A base value from the sheet overrides the hero's derives
   (`lebensenergie`'s LE from species and KO), as the pipeline already does when a base exists.
3. **No breed rule:** the creature's Stufe is 0 in the engine (SZ3 is the hero's); `MountValues.hasBreedRule` is false, and the app shows the rule as not applied (§6.7).
4. **The link.** `Engine.mountFacts(in:)` evaluates the mount's situation, then the app states three facts in
   the hero's situation, owner `derived`: `mount.gs` (the mount's `gs` result), `mount.schmerz` (the
   Stufe the mount has, before Zähes Tier) and `mount.handlungsunfaehig`. A stated fact has priority
   over the breed's `provide mount.gs`, so RK14 reads the current GS. Each fact keeps a reference to
   the mount's breakdown, for display.

### Vocabulary

`vocabulary.json` (and `Vocabulary.swift`) get three exact entries in `facts`. An exact entry has
priority over the `mount.` family (owner `sheet`):

| Fact | Type | Owner |
|---|---|---|
| `mount.gs` | int | derived |
| `mount.schmerz` | int | derived |
| `mount.handlungsunfaehig` | bool | derived |

`targets` gets `vw`, a creature's Verteidigung (§4.5). It needs no prefix.

Inside the mount's own evaluation the rule files keep `level(rule: COND_6)`. The hero's
`hero.levelOf.*` names do not change in this issue.

### Harness

A situation file gets a `mount:` section, for example
`mount: { creature: svellttaler-kaltblut, gs: 12, leMax: 75, leCurrent: 75, advantages: [] }`.
`scripts/rulec/situations.py` builds the `CreatureSheet` from it. The `mount.gs: 12` values in
`situations/reiterkampf.yaml` and `situations/kupperus-und-waffen.yaml` move into that section, so
cases 5.10, 5.11 and 18.8 also test the link, with unchanged expected values. New situations: Kupperus
at 137, 89, 90, 60, 61, 29, 30 and 5 LeP, with and without Zähes Tier (Stufe, GS, AT, VW); a mount
without a breed rule (Stufe 0, no question); an RK14 case with a mount at Schmerz II (reiterkampf.yaml "5.18"; 5.12 was taken).

## 6. App

1. **`PetSheetMapping`** (`Hesindion/RulesEngine/`) is the only code that knows both `Pet` and
   `CreatureSheet`. The breed rule is found by `Pet.type` against the rule's `name` (`Pet` has no
   breed field; issue #49 covers the import). The animal advantages are found by name in
   `Pet.advantages`. `gs` ← `speed`, `leMax` ← `lifeEnergy`, current LE ← `currentLifeEnergy`,
   `vw` ← `defense`, `at(with:)` ← `attacks`.
2. **`MountValues`** works as `SheetValues`: one evaluation per distinct `CreatureSheet`, cached. It
   gives `gs`, `schmerz`, `handlungsunfaehig`, `vw` and `at(with:)`, each with its breakdown.
3. **Sturmangriff zu Pferd TP.** `DamageModifiers` drops its two Swift lines and reads the RK14 line
   from an engine evaluation of `tp` with `choice.order: sturmangriffZuPferd`, `action.gait: galopp`,
   `action.attack: hit` and the `mount.*` facts. A tap opens `BreakdownSheet`, which shows the mount's
   GS breakdown (15 − 2 Schmerz II = 13). `Hero.mountGS`, `sturmangriffHalfMountGS` and
   `sturmangriffDamageBonus` go; the button subtitle reads the engine's value.
4. **The mount's AT** (Tritt, Biss, Niederreiten) comes from `MountValues.at(with:)`, not from
   `PetAttack.at`. The announcement box shows the Schmerz line.
5. **Stufe IV.** Sturmangriff zu Pferd, Niederreiten and the mount's own attacks are disabled. One
   reason line gives the cause ("Kupperus: Schmerz IV — handlungsunfähig"), identifier
   `combat.mount.blockedReason`.
6. **Combat root.** Below the mount name: "Schmerz II · GS 13", identifier `combat.mount.schmerz`.
   Nothing at Stufe 0.
7. **A mount without a breed rule.** The app uses the base GS and AT and shows the rule as not
   applied: "Schmerz Kupperus: Schwellen unbekannt (kein Bestiarium-Eintrag)".
8. **Companion sheet** (`HeroDetailView`): GS, VW and the AT of each attack show the engine's results;
   a tap opens the breakdown.
9. `FactLabel` gets labels for the three facts. They name the role ("GS Reittier", "Schmerz Reittier", "Reittier handlungsunfähig"), since `FactLabel` has no mount name.

## 7. Tests

- Package: unit tests for `Situation(creature:)` and the link (a mount at 60 LeP gives RK14 the
  lowered GS); the harness situations of §5.
- `PetSheetMapping`: breed by name, Zähes Tier, no breed.
- `MountValues`: Kupperus at the edge values of §5.
- `DamageModifiersTests`: the RK14 line, with and without Schmerz; the existing Sturmangriff cases
  move from `hero.sturmangriffDamageBonus` to the engine's line. `MountSelectionTests` moves from
  `hero.mountGS` to `MountValues`.
- Snapshots: the combat root with a mount at Schmerz II; the blocked mount actions at Stufe IV.
- UI test with a screenshot: the reason line at Stufe IV, at the next free number in
  `docs/screenshots/`.

## 8. Docs

- ADR-0020: a creature is a subject of its own (`CreatureSheet`, the link facts, why not prefixed
  copies of COND_6).
- AGENTS.md: the mount slice reads the engine (`PetSheetMapping` → `CreatureSheet` → `MountValues`);
  the new identifiers.
- CHANGELOG.
- MIGRATION.md, RULINGS.md (§4).

## 9. Out of scope

- The hero's own Schmerz (domain 4).
- Readable names for `hero.levelOf.*` and other rule-id facts.
- The companion import (#49), and a breed field on `Pet`.
- Companions that are not the mount.
