# Rules migration reconciliation

Evidence for Task 3 of the rules-pipeline plan (2026-09-20): every legacy `specs/data/rules.yaml`
/ `HARDCODED_EFFECTS` effect row, mapped to the authored `specs/rules/*.yaml` effect(s) it became.
Tracked here (not under the gitignored `.superpowers/`) because it is the only record tying the 79
legacy rows to their authored replacements, and because fix round 1 (below) added 10 more effects
that have no legacy row of their own.

Contains no DSA rule text (Data Policy) — legacy rows are described by their field values, never
by quoting rule prose.

## Part 1 — the 79 legacy rows → their authored effect(s)

One legacy row maps to exactly one authored effect, **except** `SA_41`, `ADV_25` and `ADV_44`,
where fix round 1 (I1, below) expanded a single flat legacy row into a full tier ladder — those
three are listed with all of their authored effects against the one legacy row they came from.

```
=== COND_1 (conditions) ===
  lvl1 type=modifier attribute=at value=-1 scope=combat
    -> type=modifier target=at scope=combat value=-1 tier=1
  lvl1 type=modifier attribute=pa value=-1 scope=combat
    -> type=modifier target=pa scope=combat value=-1 tier=1
  lvl1 type=modifier attribute=ini value=-1 scope=combat
    -> type=modifier target=ini scope=combat value=-1 tier=1
  lvl1 type=modifier attribute=gs value=-1 scope=combat
    -> type=modifier target=gs scope=combat value=-1 tier=1
  lvl1 type=modifier attribute=talent value=-1 scope=movement
    -> type=modifier target=talent scope=movement value=-1 tier=1
  lvl2 type=modifier attribute=at value=-2 scope=combat
    -> type=modifier target=at scope=combat value=-2 tier=2
  lvl2 type=modifier attribute=pa value=-2 scope=combat
    -> type=modifier target=pa scope=combat value=-2 tier=2
  lvl2 type=modifier attribute=ini value=-2 scope=combat
    -> type=modifier target=ini scope=combat value=-2 tier=2
  lvl2 type=modifier attribute=gs value=-2 scope=combat
    -> type=modifier target=gs scope=combat value=-2 tier=2
  lvl2 type=modifier attribute=talent value=-2 scope=movement
    -> type=modifier target=talent scope=movement value=-2 tier=2
  lvl3 type=modifier attribute=at value=-3 scope=combat
    -> type=modifier target=at scope=combat value=-3 tier=3
  lvl3 type=modifier attribute=pa value=-3 scope=combat
    -> type=modifier target=pa scope=combat value=-3 tier=3
  lvl3 type=modifier attribute=ini value=-3 scope=combat
    -> type=modifier target=ini scope=combat value=-3 tier=3
  lvl3 type=modifier attribute=gs value=-3 scope=combat
    -> type=modifier target=gs scope=combat value=-3 tier=3
  lvl3 type=modifier attribute=talent value=-3 scope=movement
    -> type=modifier target=talent scope=movement value=-3 tier=3
  lvl4 type=incapacitated scope=all
    -> type=actionEconomy forbids=allActions tier=4

=== COND_2 (conditions) ===
  lvl1 type=modifier attribute=all value=-1 scope=all
    -> type=modifier target=all scope=all value=-1 tier=1
  lvl2 type=modifier attribute=all value=-2 scope=all
    -> type=modifier target=all scope=all value=-2 tier=2
  lvl3 type=modifier attribute=all value=-3 scope=all
    -> type=modifier target=all scope=all value=-3 tier=3
  lvl4 type=incapacitated scope=all
    -> type=actionEconomy forbids=allActions tier=4

=== COND_4 (conditions) ===
  lvl1 type=modifier attribute=all value=-1 scope=all
    -> type=modifier target=all scope=all value=-1 tier=1
  lvl2 type=modifier attribute=all value=-2 scope=all
    -> type=modifier target=all scope=all value=-2 tier=2
  lvl3 type=modifier attribute=all value=-3 scope=all
    -> type=modifier target=all scope=all value=-3 tier=3
  lvl4 type=incapacitated scope=all (legacy description named a dropped "Flucht oder
       Handlungsunfaehig" disjunction — see Part 2, M4, for the reminder added alongside this row)
    -> type=actionEconomy forbids=allActions tier=4

=== COND_5 (conditions) ===
  lvl1 type=modifier attribute=all value=-1 scope=all
    -> type=modifier target=all scope=all value=-1 tier=1
  lvl1 type=modifier attribute=gs value=-1 scope=all
    -> type=modifier target=gs scope=all value=-1 tier=1
  lvl2 type=modifier attribute=all value=-2 scope=all
    -> type=modifier target=all scope=all value=-2 tier=2
  lvl2 type=modifier attribute=gs value=-2 scope=all
    -> type=modifier target=gs scope=all value=-2 tier=2
  lvl3 type=modifier attribute=all value=-3 scope=all
    -> type=modifier target=all scope=all value=-3 tier=3
  lvl3 type=modifier attribute=gs value=-3 scope=all
    -> type=modifier target=gs scope=all value=-3 tier=3
  lvl4 type=incapacitated scope=all
    -> type=actionEconomy forbids=allActions tier=4

=== COND_6 (conditions) ===
  lvl1 type=modifier attribute=all value=-1 scope=all
    -> type=modifier target=all scope=all value=-1 tier=1
  lvl1 type=modifier attribute=gs value=-1 scope=all
    -> type=modifier target=gs scope=all value=-1 tier=1
  lvl2 type=modifier attribute=all value=-2 scope=all
    -> type=modifier target=all scope=all value=-2 tier=2
  lvl2 type=modifier attribute=gs value=-2 scope=all
    -> type=modifier target=gs scope=all value=-2 tier=2
  lvl3 type=modifier attribute=all value=-3 scope=all
    -> type=modifier target=all scope=all value=-3 tier=3
  lvl3 type=modifier attribute=gs value=-3 scope=all
    -> type=modifier target=gs scope=all value=-3 tier=3
  lvl4 type=incapacitated scope=all
    -> type=actionEconomy forbids=allActions tier=4

=== COND_7 (conditions) ===
  lvl1 type=modifier attribute=all value=-1 scope=all
    -> type=modifier target=all scope=all value=-1 tier=1
  lvl2 type=modifier attribute=all value=-2 scope=all
    -> type=modifier target=all scope=all value=-2 tier=2
  lvl3 type=modifier attribute=all value=-3 scope=all
    -> type=modifier target=all scope=all value=-3 tier=3
  lvl4 type=incapacitated scope=all
    -> type=actionEconomy forbids=allActions tier=4

=== ADV_5 (advantages) ===
  type=negation attribute=offHandPenalty scope=all
    -> type=parameterOverride parameter=dualWield.penalty set=0

=== ADV_25 (advantages) ===
  [fix round 1, I1: rules.levels=7 in the pinned source; the flat legacy row dropped the Stufe
   ladder entirely (would have fired +1 LE at every Stufe, incl. VII, instead of scaling to +7).
   The one legacy row now maps to a full tier ladder, value = running total per tier.]
  type=modifier attribute=le value=1 scope=derived (no legacy level; "per level" in the legacy
       description, undifferentiated by tier)
    -> type=modifier target=le scope=derived value=1 tier=1
    -> type=modifier target=le scope=derived value=2 tier=2
    -> type=modifier target=le scope=derived value=3 tier=3
    -> type=modifier target=le scope=derived value=4 tier=4
    -> type=modifier target=le scope=derived value=5 tier=5
    -> type=modifier target=le scope=derived value=6 tier=6
    -> type=modifier target=le scope=derived value=7 tier=7

=== ADV_36 (advantages) ===
  type=narrative
    -> type=reminder

=== ADV_44 (advantages) ===
  [fix round 1, I1: rules.levels=3 in the pinned source; same defect and same fix shape as ADV_25.]
  type=recovery attribute=le value=1 scope=all (no legacy level; "per level per regeneration
       cycle" in the legacy description, undifferentiated by tier)
    -> type=recovery attribute=LE value=1 operation=add per=regenerationCycle tier=1
    -> type=recovery attribute=LE value=2 operation=add per=regenerationCycle tier=2
    -> type=recovery attribute=LE value=3 operation=add per=regenerationCycle tier=3

=== ADV_49 (advantages) ===
  type=modifier attribute=painLevel value=-1 scope=all
    -> type=modifier target=painLevel scope=all value=-1

=== ADV_75 (advantages) ===
  type=recovery attribute=duration value=0.5 scope=all condition=anaesthesia or intoxicated
    -> type=recovery value=0.5 operation=scale per=duration when=[{gmFlag: anaesthesiaOrIntoxicated}]
  [fix round 1, M1: `attribute: duration` dropped — recovery.attribute now required only when
   operation: add; this row's operation is scale, and "duration" was never a recovered stat.]

=== DISADV_33 (disadvantages) ===
  type=modifier attribute=talent value=-1 scope=socialTalents
    -> type=modifier target=talent scope=socialTalents value=-1

=== DISADV_34 (disadvantages) ===
  type=modifier attribute=all value=-1 scope=all condition=principles violated
    -> type=modifier target=all scope=all value=-1 when=[{gmFlag: principlesViolated}]

=== DISADV_35 (disadvantages) ===
  type=stateGain attribute=anaesthesia value=1 scope=all condition=sleepwalked last night
    -> type=stateGain state=betaeubung level=1 when=[{gmFlag: sleepwalked}]
  type=recovery attribute=le value=-1 scope=all condition=sleepwalking night
    -> type=recovery attribute=LE value=-1 operation=add per=regenerationCycle when=[{gmFlag: sleepwalked}]

=== DISADV_50 (disadvantages) ===
  type=narrative
    -> type=reminder

=== SA_40 (combatAbilities) ===
  type=modifier attribute=sinnesschaerfe value=2 scope=combat condition=ambush detection
    -> type=modifier target=sinnesschaerfe scope=combat value=2 when=[{gmFlag: ambush}]

=== SA_41 (combatAbilities) ===
  [fix round 1, I1: rules.levels=2 in the pinned source; the flat legacy row (value=-2, from
   specs/data/rules.yaml) was the *wrong* one of two disagreeing legacy sources. The now-deleted
   HARDCODED_EFFECTS table held this rule correctly as two tiered rows (Stufe I: be -1, Stufe II:
   be -2, scope: all) — that shape is restored here instead of the flat -2.]
  type=modifier attribute=be value=-2 scope=combat (legacy specs/data/rules.yaml row; superseded)
    -> type=modifier target=be scope=all value=-1 tier=1   [from the deleted HARDCODED_EFFECTS row]
    -> type=modifier target=be scope=all value=-2 tier=2   [from the deleted HARDCODED_EFFECTS row]

=== SA_43 (combatAbilities) ===
  type=modifier attribute=be value=-1 scope=combat condition=mounted
    -> type=modifier target=be scope=combat value=-1 when=[{mounted: true}]

=== SA_48 (combatAbilities) ===
  lvl1 type=modifier attribute=at value=-1 scope=combat
    -> type=modifier target=at scope=combat value=-1 tier=1
  lvl1 type=opponentModifier attribute=pa value=-2 scope=combat
    -> type=modifier target=pa scope=combat value=-2 side=opponent tier=1
  lvl2 type=modifier attribute=at value=-2 scope=combat
    -> type=modifier target=at scope=combat value=-2 tier=2
  lvl2 type=opponentModifier attribute=pa value=-4 scope=combat
    -> type=modifier target=pa scope=combat value=-4 side=opponent tier=2
  lvl3 type=modifier attribute=at value=-3 scope=combat
    -> type=modifier target=at scope=combat value=-3 tier=3
  lvl3 type=opponentModifier attribute=pa value=-6 scope=combat
    -> type=modifier target=pa scope=combat value=-6 side=opponent tier=3

=== SA_59 (combatAbilities) ===
  type=negation attribute=shieldPaBonus scope=combat
    -> type=parameterOverride parameter=shield.paBonus set=0
  type=damageRedirect scope=combat target=shieldSP
    -> type=dice recipient=defenderShield

=== SA_65 (combatAbilities) ===
  type=modifier attribute=pa value=4 scope=combat
    -> type=modifier target=pa scope=combat value=4
  type=modifier attribute=aw value=4 scope=combat
    -> type=modifier target=aw scope=combat value=4
  type=restriction attribute=at scope=combat
    -> type=actionEconomy forbids=attack

=== SA_66 (combatAbilities) ===
  type=modifier attribute=at value=2 scope=combat
    -> type=modifier target=at scope=combat value=2
  type=restriction attribute=defense scope=combat
    -> type=actionEconomy forbids=defense

=== SA_67 (combatAbilities) ===
  lvl1 type=modifier attribute=at value=-2 scope=combat
    -> type=modifier target=at scope=combat value=-2 tier=1
  lvl1 type=damageModifier value=2 scope=combat
    -> type=dice add=2 tier=1
  lvl2 type=modifier attribute=at value=-4 scope=combat
    -> type=modifier target=at scope=combat value=-4 tier=2
  lvl2 type=damageModifier value=4 scope=combat
    -> type=dice add=4 tier=2
  lvl3 type=modifier attribute=at value=-6 scope=combat
    -> type=modifier target=at scope=combat value=-6 tier=3
  lvl3 type=damageModifier value=6 scope=combat
    -> type=dice add=6 tier=3

=== SA_661 (combatAbilities) ===
  type=modifier attribute=at value=2 scope=combat condition=mounted vs foot fighter
    -> type=modifier target=at scope=combat value=2 when=[{mounted: true}, {gmFlag: opponentOnFoot}]
  [fix round 1, I4: was a single when=[{gmFlag: mountedVsFootFighter}] — collapsed a half-mechanical
   condition into one opaque flag when `mounted` is already checked mechanically on the next effect
   in this same file. Now ANDs the mechanical half with a narrower GM flag for the other half.]
  type=modifier attribute=pa value=1 scope=combat condition=mounted
    -> type=modifier target=pa scope=combat value=1 when=[{mounted: true}]

=== SA_22 (generalAbilities) ===
  type=modifier attribute=Gassenwissen value=1 scope=all condition=at known location
    -> type=modifier target=Gassenwissen scope=all value=1 when=[{gmFlag: knownLocation}]
  type=modifier attribute=Orientierung value=1 scope=all condition=at known location
    -> type=modifier target=Orientierung scope=all value=1 when=[{gmFlag: knownLocation}]
```

## Part 2 — authored effects added in fix round 1 with no legacy row

10 effects were added on review (see `.superpowers/sdd/2026-09-20-rules-pipeline-and-authoring/task-3-report.md`
for the full findings and rulings). None of these represent a *new* legacy row — they either
restore ladder rungs a flat legacy row had collapsed, or mark a dropped detail:

| # | Rule | Effect added | Why (finding) |
|---|------|---------------|----------------|
| 1 | `SA_41` | `modifier target=be scope=all value=-1 tier=1` | I1 — tier ladder restored (Stufe I rung; Stufe II rung already counted in Part 1) |
| 2 | `ADV_25` | `modifier target=le scope=derived value=2 tier=2` | I1 — tier ladder restored |
| 3 | `ADV_25` | `modifier target=le scope=derived value=3 tier=3` | I1 |
| 4 | `ADV_25` | `modifier target=le scope=derived value=4 tier=4` | I1 |
| 5 | `ADV_25` | `modifier target=le scope=derived value=5 tier=5` | I1 |
| 6 | `ADV_25` | `modifier target=le scope=derived value=6 tier=6` | I1 |
| 7 | `ADV_25` | `modifier target=le scope=derived value=7 tier=7` | I1 |
| 8 | `ADV_44` | `recovery attribute=LE value=2 tier=2` | I1 — tier ladder restored |
| 9 | `ADV_44` | `recovery attribute=LE value=3 tier=3` | I1 |
| 10 | `COND_4` | `reminder tier=4` | M4 — marks the Stufe IV "Flucht oder Handlungsunfaehig" disjunction the `actionEconomy` row alone doesn't state |

`SA_41`'s Stufe I rung and `ADV_25`/`ADV_44`'s Stufe I rungs are **not** counted in this table —
they already existed as the original flat legacy-row mapping in Part 1 (a flat effect with no
`tier` is mechanically equivalent to "Stufe I only" once its siblings are added; carrying it
forward as the tier-1 rung avoids double-counting).

## Totals

- 79 legacy rows (Part 1), all accounted for.
- 79 + 10 = **89 authored effects** in `specs/rules/*.yaml` after fix round 1, matching
  `select count(*) from effects` in the rebuilt `rules.db`.
- `select count(*) from effects where payload is null` = 0.
