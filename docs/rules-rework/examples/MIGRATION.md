# Migration residue

Written by `scripts/rulec/migrate.py` (spec §10.3 step 1). Each item is a key the
mechanical old → new table could not move; it is resolved by hand (plan Tasks 8–15) and
ticked. Line numbers are those of the migrated file.

`- [ ] L<line> <path in the doc>: <old key> — <why not mechanical>`

## Counts (Task 16, after the hand migration)

Every item below is ticked. `make rules-check`:
`ok: 76 rules, 483 clauses, 465 effects, 309 situations (283 pending)`; `make rules-json` writes
both files (`309 situations, 283 pending`). Pending counts an open ruling on a `"*"` entry only for
situations that expect situation-level results or have `sequence`/`rolls` (ruling R30); the
pending rulings are mostly fernkampf.range-input (on every `at`/`fk` query through FK2's
`forbid … attack`), zaubermodifikationen.omit-counts, fernkampf.cover-as-size,
SA_9.spezialisierung-when, fernkampf.zielen-interrupted and ladezeiten.laengere-handlungen.

Vocabulary additions per group (`specs/rules/vocabulary.json`, names added):

| Group | Added |
|---|---|
| 1 (Task 8) | facts belastung.source, check.hinderedByBelastung, check.kind, hero.purchased.le, ktw.current, loadout.armour.belastung, loadout.armour.extraPenalty, loadout.other, loadout.other.paMod, species.le, technique.leit; target level; selector kind ruleKind; expect query key base; ruling key see |
| 2 (Task 9) | facts action.runUp, hero.gs, loadout.other.technique, loadout.shield.structurePoints, loadout.twoHanded, query.result, round.defendedThisAttack, round.phase; target gsNatural; item field destroyed |
| 3 (Task 10) | facts action.gait, action.gaitChange, query.target, reach.gap; target carryingCapacity; pools actions, freeActions; item field ridden; line key was |
| 4 (Task 11) | facts hero.leCurrent, hit.heldInHand, hit.mountSp, hit.overWundschwelle, hit.side, hit.zoneRs, loadout.weapon.leit, loadout.weapon.ownLeit, loadout.weapon.schadensschwelle, loadout.weaponHand; fact family loadout.armourPiece.; target armourScore; item field held |
| 5 (Task 12) | fact hero.conditionLevels; fact family hero.levelOf. |
| 6 (Task 13) | facts check.applicationOnOption, check.onOption, check.ones, check.spent, check.twenties, fw.current; expect key result |
| 7 (Task 14) | facts check.spell, hero.aspCurrent; targets aspCurrent, spell.costPerInterval; line key term |
| 8 (Task 15) | facts hero.inMelee, hero.lastMovement, ladezeit.current, loadout.quiver, loadout.weapon.closeRange, loadout.weapon.farRange, loadout.weapon.instance, loadout.weapon.ladezeit, loadout.weapon.loaded, loadout.weapon.mediumRange, loadout.weapon.strung, round.previousDefenceCrit; fact family process. |
| Task 16 | `provide.readBy` (field type reader, list readers: display, loadout, roll); the unused target belastung removed (ruling R18) |

## rules/abilities/SA_152.yaml

- [x] L26 clauses[AD1].effects[0].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L26 clauses[AD1].effects[0].when.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [x] L31 clauses[AD1].effects[1].when.announced: announced — not a fact in the vocabulary
- [x] L31 clauses[AD1].effects[1].when.loadout.reach.longer_than: longer_than — snake_case key, no mapping
- [x] L43 clauses[AD2].effects[0].offer.announce: announce — not a field of `offer`
- [x] L43 clauses[AD2].effects[0].offer.at: at — not a field of `offer`
- [x] L43 clauses[AD2].effects[0].offer.lasts: lasts — not a field of `offer`
- [x] L46 clauses[AD2].effects[1].when.announced: announced — not a fact in the vocabulary
- [x] L47 clauses[AD2].effects[1].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [x] L50 clauses[AD2].effects[2].when.announced: announced — not a fact in the vocabulary
- [x] L50 clauses[AD2].effects[2].when.loadout.reach.not_longer_than: not_longer_than — snake_case key, no mapping

## rules/abilities/SA_160.yaml

- [x] L26 clauses[GA1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L27 clauses[GA1].effects[0].offer.on: on — not a field of `offer`
- [x] L28 clauses[GA1].effects[0].offer.requires: requires — not a field of `offer`
- [x] L29 clauses[GA1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_161.yaml

- [x] L25 clauses[GS1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L26 clauses[GS1].effects[0].offer.on: on — not a field of `offer`
- [x] L27 clauses[GS1].effects[0].offer.requires: requires — not a field of `offer`
- [x] L28 clauses[GS1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_172.yaml

- [x] L28 clauses[U1].effects[0].lower: lower — no one-to-one verb
- [x] L28 clauses[U1].effects[0].lower.by_steps: by_steps — snake_case key, no mapping
- [x] L40 clauses[U2].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L41 clauses[U2].effects[0].offer.announce: announce — not a field of `offer`
- [x] L43 clauses[U2].effects[0].offer.requires: requires — not a field of `offer`
- [x] L43 clauses[U2].effects[0].offer.requires.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [x] L44 clauses[U2].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L64 clauses[U4].ruling: ruling — not a clause key in the vocabulary

## rules/abilities/SA_173.yaml

- [x] L22 clauses[VU1].lifts: lifts — not a clause key in the vocabulary

## rules/abilities/SA_40.yaml

- [x] L22 clauses[A1].effects[0].when.check: check — not a fact in the vocabulary
- [x] L22 clauses[A1].effects[0].when.situation: situation — not a fact in the vocabulary

## rules/abilities/SA_41.yaml

- [x] L25 clauses[G1].effects[0].lower: lower — no one-to-one verb

## rules/abilities/SA_42.yaml

- [x] L22 clauses[BH1].effects[0].raise: raise — no one-to-one verb
- [x] L22 clauses[BH1].effects[0].raise.max_total: max_total — snake_case key, no mapping
- [x] L31 clauses[BH2].effects[0].requires: requires — a key that is not a fact: loadout.mainHand.technique, loadout.offHand.technique

## rules/abilities/SA_43.yaml

- [x] L23 clauses[BK1].enables: enables — not a clause key in the vocabulary

## rules/abilities/SA_48.yaml

- [x] L24 clauses[F1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L25 clauses[F1].effects[0].offer.tiers: tiers — not a field of `offer`
- [x] L26 clauses[F1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L30 clauses[F1].effects[2].opponent_add: opponent_add — keys outside the row: per

## rules/abilities/SA_51.yaml

- [x] L19 clauses[KR1].effects[0].add.after: after — not a field of `add`

## rules/abilities/SA_59.yaml

- [x] L28 clauses[SS1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L29 clauses[SS1].effects[0].offer.opponent_may_only: opponent_may_only — not a field of `offer`
- [x] L30 clauses[SS1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L36 clauses[SS1].effects[2].forbid.defence: defence — not a field of `forbid`
- [x] L61 clauses[SS3].effects[1].damage: damage — no one-to-one verb
- [x] L62 clauses[SS3].effects[1].then: then — no one-to-one verb

## rules/abilities/SA_60.yaml

- [x] L28 clauses[SL1].effects[0].when.hero.has.SA_60.option_for: option_for — snake_case key, no mapping
- [x] L29 clauses[SL1].effects[0].add.floor: floor — not a field of `add`
- [x] L37 clauses[SL2].effects[0].when.hero.has.SA_60.option_for: option_for — snake_case key, no mapping
- [x] L74 clauses[SL7].effects[0].requires: requires — a key that is not a fact: hero.has_item, fact
- [x] L74 clauses[SL7].effects[0].requires.any_of: any_of — snake_case key, no mapping
- [x] L74 clauses[SL7].effects[0].requires.any_of[0].hero.has_item: hero.has_item — snake_case key, no mapping

## rules/abilities/SA_62.yaml

- [x] L25 clauses[ST1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L26 clauses[ST1].effects[0].offer.requires: requires — not a field of `offer`
- [x] L27 clauses[ST1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_65.yaml

- [x] L26 clauses[VH1].effects[0].offer.when: when — not a field of `offer`
- [x] L36 clauses[VH1].effects[2].forbid.action: action — not a field of `forbid`
- [x] L45 clauses[VH2].effects[0].requires: requires — a key that is not a fact: loadout.any.technique

## rules/abilities/SA_66.yaml

- [x] L38 clauses[V2].effects[0].forbid.defence: defence — not a field of `forbid`
- [x] L38 clauses[V2].effects[0].forbid.span: span — not a field of `forbid`
- [x] L47 clauses[V3].effects[0].offer.when: when — not a field of `offer`
- [x] L56 clauses[V4].effects[0].requires: requires — a key that is not a fact: hero.state

## rules/abilities/SA_661.yaml

- [x] L24 clauses[GS1].effects[0].when.loadout: loadout — not a fact in the vocabulary
- [x] L25 clauses[GS1].effects[0].raise: raise — no one-to-one verb
- [x] L35 clauses[GS2].effects[0].when.loadout: loadout — not a fact in the vocabulary
- [x] L44 clauses[GS3].effects[0].define: define — no one-to-one verb

## rules/abilities/SA_67.yaml

- [x] L23 clauses[W1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L24 clauses[W1].effects[0].offer.tiers: tiers — not a field of `offer`
- [x] L25 clauses[W1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_74.yaml

- [x] L35 clauses[VP1].effects[0].offer.amount: amount — not a field of `offer`
- [x] L36 clauses[VP1].effects[0].offer.when: when — not a field of `offer`
- [x] L37 clauses[VP1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L40 clauses[VP1].effects[1].forbid.choice: choice — not a field of `forbid`
- [x] L40 clauses[VP1].effects[1].forbid.when: when — not a field of `forbid`
- [x] L42 clauses[VP1].effects[2].split: split — no one-to-one verb
- [x] L50 clauses[VP2].effects[0].when.amount: amount — not a fact in the vocabulary
- [x] L51 clauses[VP2].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L52 clauses[VP2].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L67 clauses[VP3].effects[0].when.check_failed: check_failed — not a fact in the vocabulary
- [x] L68 clauses[VP3].effects[0].charge: charge — keys outside the row: round, pools, ruling; missing pool

## rules/abilities/SA_862.yaml

- [x] L31 clauses[F1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L35 clauses[F1].effects[1].forbid.choice: choice — not a field of `forbid`
- [x] L35 clauses[F1].effects[1].forbid.when: when — not a field of `forbid`
- [x] L38 clauses[F1].effects[2].forbid.choice: choice — not a field of `forbid`
- [x] L58 clauses[F3].effects[0].offer.when: when — not a field of `offer`

## rules/abilities/SA_884.yaml

- [x] L28 clauses[P1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L33 clauses[P1].effects[1].forbid.choice: choice — not a field of `forbid`
- [x] L33 clauses[P1].effects[1].forbid.when: when — not a field of `forbid`
- [x] L58 clauses[P3].effects[0].offer.when: when — not a field of `offer`

## rules/abilities/SA_9.yaml

- [x] L24 clauses[FS1].effects[0].when.check: check — not a fact in the vocabulary

## rules/abilities/SA_923.yaml

- [x] L22 clauses[VS1].effects[0].change: change — no one-to-one verb
- [x] L34 clauses[VS2].ruling: ruling — not a clause key in the vocabulary

## rules/advantages/ADV_25.yaml

No residue.

## rules/advantages/ADV_4.yaml

- [x] L26 clauses[B1].effects[0].offer.reroll: reroll — not a field of `offer`
- [x] L27 clauses[B1].effects[0].offer.when: when — not a field of `offer`
- [x] L28 clauses[B1].effects[0].offer.once_per: once_per — not a field of `offer`
- [x] L29 clauses[B1].effects[0].offer.after: after — not a field of `offer`
- [x] L30 clauses[B1].effects[0].offer.before: before — not a field of `offer`
- [x] L42 clauses[B2].effects[0].choose: choose — no one-to-one verb
- [x] L43 clauses[B2].effects[0].keep: keep — no one-to-one verb
- [x] L68 clauses[B5].effects[0].forbid.offer: offer — not a field of `forbid`
- [x] L68 clauses[B5].effects[0].forbid.when: when — not a field of `forbid`
- [x] L84 clauses[B7].effects[0].allow: allow — no one-to-one verb

## rules/advantages/ADV_44.yaml

- [x] L20 clauses[VR1].effects[0].when.event: event — not a fact in the vocabulary
- [x] L20 clauses[VR1].effects[0].when.energy: energy — not a fact in the vocabulary
- [x] L20 clauses[VR1].effects[0].when.regenerates: regenerates — not a fact in the vocabulary
- [x] L21 clauses[VR1].effects[0].add.before: before — not a field of `add`

## rules/advantages/ADV_49.yaml

- [x] L25 clauses[ZH1].effects[0].when.condition: condition — not a fact in the vocabulary
- [x] L27 clauses[ZH1].effects[0].keeps: keeps — no one-to-one verb
- [x] L27 clauses[ZH1].effects[0].keeps.condition_level: condition_level — snake_case key, no mapping
- [x] L41 clauses[ZH3].effects[0].when.condition: condition — not a fact in the vocabulary
- [x] L42 clauses[ZH3].effects[0].keep: keep — no one-to-one verb
- [x] L44 clauses[ZH3].effects[1].when.condition: condition — not a fact in the vocabulary
- [x] L44 clauses[ZH3].effects[1].when.check_passed: check_passed — not a fact in the vocabulary
- [x] L51 clauses[ZH4].effects[0].when.condition: condition — not a fact in the vocabulary

## rules/advantages/ADV_5.yaml

- [x] L18 clauses[V1].status: status — not a clause key in the vocabulary
- [x] L19 clauses[V1].why: why — `why` without `effects: none`: the clause has no body to carry it

## rules/advantages/ADV_54.yaml

No residue.

## rules/advantages/ADV_75.yaml

- [x] L24 clauses[SW1].effects[0].when.condition: condition — not a fact in the vocabulary
- [x] L24 clauses[SW1].effects[0].when.cause: cause — not a fact in the vocabulary
- [x] L25 clauses[SW1].effects[0].scale: scale — no one-to-one verb
- [x] L27 clauses[SW1].effects[1].when.condition: condition — not a fact in the vocabulary
- [x] L27 clauses[SW1].effects[1].when.cause: cause — not a fact in the vocabulary
- [x] L28 clauses[SW1].effects[1].scale: scale — no one-to-one verb

## rules/conditions/COND_1.yaml

- [x] L18 level: level — not a rule key in the vocabulary
- [x] L22 level.lowered_by: lowered_by — snake_case key, no mapping
- [x] L50 clauses[B3].effects[2].when.check: check — `check: talent` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L50 clauses[B3].effects[2].when.talent.hinderedByBelastung: talent.hinderedByBelastung — not a fact in the vocabulary
- [x] L53 clauses[B3].effects[3].when.check: check — `check: talent` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L53 clauses[B3].effects[3].when.talent.hinderedByBelastung: talent.hinderedByBelastung — not a fact in the vocabulary
- [x] L58 clauses[B3].effects[4].when.check: check — `check: talent` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L58 clauses[B3].effects[4].when.talent.hinderedByBelastung: talent.hinderedByBelastung — not a fact in the vocabulary
- [x] L61 clauses[B3].effects[5].when.check: check — not a fact in the vocabulary
- [x] L69 clauses[B4].effects[0].gain: gain — gain: keys outside the row: until

## rules/conditions/COND_6.yaml

- [x] L16 level: level — not a rule key in the vocabulary
- [x] L19 level.from[1].set_by: set_by — snake_case key, no mapping
- [x] L20 level.effects_lowered_by: effects_lowered_by — snake_case key, no mapping
- [x] L35 clauses[SZ2].effects[0].when.before: before — not a fact in the vocabulary
- [x] L36 clauses[SZ2].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L37 clauses[SZ2].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L38 clauses[SZ2].effects[0].on_success: on_success — no one-to-one verb
- [x] L52 clauses[SZ3].effects[0].sets: sets — no one-to-one verb
- [x] L62 clauses[SZ4].status: status — not a clause key in the vocabulary
- [x] L63 clauses[SZ4].why: why — `why` without `effects: none`: the clause has no body to carry it
- [x] L78 clauses[SZ5].effects[1].unless: unless — next to a `when`: which of the two conditions wins is not mechanical
- [x] L78 clauses[SZ5].effects[1].unless.check_passed: check_passed — snake_case key, no mapping
- [x] L79 clauses[SZ5].effects[2].when.check_passed: check_passed — not a fact in the vocabulary

## rules/conditions/STATE_10.yaml

- [x] L17 applies_to_side: applies_to_side — not a rule key in the vocabulary
- [x] L29 clauses[L2].effects[0].when.side: side — not a fact in the vocabulary
- [x] L33 clauses[L2].effects[1].when.side: side — not a fact in the vocabulary
- [x] L39 clauses[L3].effects[0].when.side: side — not a fact in the vocabulary
- [x] L41 clauses[L3].effects[1].when.side: side — not a fact in the vocabulary
- [x] L44 clauses[L3].effects[2].when.side: side — not a fact in the vocabulary
- [x] L48 clauses[L3].effects[3].when.side: side — not a fact in the vocabulary
- [x] L59 clauses[L4].effects[0].when.side: side — not a fact in the vocabulary
- [x] L61 clauses[L4].effects[0].offer.action: action — not a field of `offer`
- [x] L63 clauses[L4].effects[0].offer.then: then — not a field of `offer`
- [x] L63 clauses[L4].effects[0].offer.then.remove_state: remove_state — snake_case key, no mapping
- [x] L64 clauses[L4].effects[0].offer.if_opponent_in_reach: if_opponent_in_reach — not a field of `offer`
- [x] L65 clauses[L4].effects[0].offer.if_opponent_in_reach.optional_check: optional_check — snake_case key, no mapping
- [x] L66 clauses[L4].effects[0].offer.if_opponent_in_reach.on_check_failed_or_skipped: on_check_failed_or_skipped — snake_case key, no mapping

## rules/conditions/STATE_13.yaml

- [x] L22 clauses[UE1].effects[0].when.check: check — not a fact in the vocabulary
- [x] L25 clauses[UE1].effects[1].when.hero.state: hero.state — not a fact in the vocabulary
- [x] L26 clauses[UE1].effects[1].forbid.defence: defence — not a field of `forbid`
- [x] L26 clauses[UE1].effects[1].forbid.until: until — not a field of `forbid`

## rules/core/angriff-von-hinten.yaml

- [x] L24 clauses[AH1].effects[0].when.side: side — not a fact in the vocabulary
- [x] L24 clauses[AH1].effects[0].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L24 clauses[AH1].effects[0].when.span: span — not a fact in the vocabulary
- [x] L30 clauses[AH1].effects[1].when.side: side — not a fact in the vocabulary
- [x] L30 clauses[AH1].effects[1].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L30 clauses[AH1].effects[1].when.span: span — not a fact in the vocabulary
- [x] L35 clauses[AH1].effects[2].when.side: side — not a fact in the vocabulary
- [x] L35 clauses[AH1].effects[2].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L36 clauses[AH1].effects[2].forbid.defence: defence — not a field of `forbid`
- [x] L37 clauses[AH1].effects[2].from: from — no one-to-one verb
- [x] L39 clauses[AH1].effects[3].when.side: side — not a fact in the vocabulary
- [x] L39 clauses[AH1].effects[3].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L40 clauses[AH1].effects[3].exempt: exempt — no one-to-one verb
- [x] L41 clauses[AH1].effects[3].from: from — no one-to-one verb

## rules/core/at-pa-modifikatoren.yaml

- [x] L23 clauses[M1].effects[0].when.attack.with: attack.with — not a fact in the vocabulary
- [x] L24 clauses[M1].effects[0].add.after: after — not a field of `add`
- [x] L25 clauses[M1].effects[1].when.with: with — not a fact in the vocabulary
- [x] L26 clauses[M1].effects[1].add.after: after — not a field of `add`

## rules/core/beengte-umgebung.yaml

- [x] L19 applies_when: applies_when — not a rule key in the vocabulary
- [x] L62 clauses[BU3].ruling: ruling — not a clause key in the vocabulary

## rules/core/beidhaendiger-kampf.yaml

- [x] L29 clauses[ZW1].effects[0].forbid.loadout: loadout — not a field of `forbid`
- [x] L30 clauses[ZW1].effects[1].forbid.loadout: loadout — not a field of `forbid`
- [x] L31 clauses[ZW1].effects[2].allow: allow — no one-to-one verb
- [x] L45 clauses[ZW2].effects[0].offer.action: action — not a field of `offer`
- [x] L46 clauses[ZW2].effects[0].offer.requires: requires — not a field of `offer`
- [x] L48 clauses[ZW2].effects[0].offer.then: then — not a field of `offer`
- [x] L61 clauses[ZW3].effects[ZW3.penalty].id: id — no one-to-one verb
- [x] L64 clauses[ZW3].effects[ZW3.penalty].lasts: lasts — no one-to-one verb
- [x] L77 clauses[ZW4].effects[ZW4.offHand].id: id — no one-to-one verb
- [x] L78 clauses[ZW4].effects[ZW4.offHand].when.hand: hand — not a fact in the vocabulary
- [x] L91 clauses[ZW6].effects[0].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [x] L99 clauses[ZW7].effects[0].offer.among: among — not a field of `offer`
- [x] L107 clauses[ZW8].effects[0].when.action: action — not a fact in the vocabulary
- [x] L107 clauses[ZW8].effects[0].when.result: result — not a fact in the vocabulary
- [x] L108 clauses[ZW8].effects[0].cancel: cancel — no one-to-one verb

## rules/core/fernkampf.yaml

- [x] L36 clauses[FK2].effects[0].forbid.attack: attack — not a field of `forbid`
- [x] L36 clauses[FK2].effects[0].forbid.when: when — not a field of `forbid`
- [x] L46 clauses[FK3].effects[0].forbid.attack: attack — not a field of `forbid`
- [x] L46 clauses[FK3].effects[0].forbid.when: when — not a field of `forbid`
- [x] L61 clauses[FK4].effects[0].provides: provides — a snake_case name, or not a mapping of names
- [x] L62 clauses[FK4].effects[0].provides.range_band: range_band — snake_case key, no mapping
- [x] L72 clauses[FK4].effects[1].when.range_band: range_band — not a fact in the vocabulary
- [x] L73 clauses[FK4].effects[1].forbid.choice: choice — not a field of `forbid`
- [x] L85 clauses[FK5].effects[0].table: table — no one-to-one verb
- [x] L120 clauses[FK7].effects[2].when.side: side — not a fact in the vocabulary
- [x] L121 clauses[FK7].effects[2].set.opponent.gs: opponent.gs — not a field of `set`
- [x] L136 clauses[FK8].effects[0].offer.fact: fact — not a field of `offer`
- [x] L139 clauses[FK8].effects[1].set.target.size_for_fk: target.size_for_fk — not a field of `set`
- [x] L155 clauses[FK9].effects[1].when.sicht: sicht — not a fact in the vocabulary
- [x] L156 clauses[FK9].effects[1].result: result — no one-to-one verb
- [x] L175 clauses[FK10].effects[1].result: result — no one-to-one verb
- [x] L177 clauses[FK10].effects[2].forbid.attack: attack — not a field of `forbid`
- [x] L177 clauses[FK10].effects[2].forbid.when: when — not a field of `forbid`
- [x] L189 clauses[FK11].effects[0].process.step: step — not a field of `process`
- [x] L190 clauses[FK11].effects[0].process.accumulates: accumulates — not a field of `process`
- [x] L191 clauses[FK11].effects[0].process.ends: ends — not a field of `process`
- [x] L193 clauses[FK11].effects[0].process.ruling: ruling — not a field of `process`
- [x] L220 clauses[FK13].effects[0].when.roll: roll — not a fact in the vocabulary
- [x] L221 clauses[FK13].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L222 clauses[FK13].effects[0].on_success: on_success — no one-to-one verb
- [x] L225 clauses[FK13].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L238 clauses[FK14].effects[0].when.roll: roll — not a fact in the vocabulary
- [x] L239 clauses[FK14].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L240 clauses[FK14].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L251 clauses[FK15].effects[0].when.incoming: incoming — not a fact in the vocabulary
- [x] L252 clauses[FK15].effects[0].forbid.defence: defence — not a field of `forbid`
- [x] L256 clauses[FK15].effects[1].when.incoming: incoming — not a fact in the vocabulary
- [x] L258 clauses[FK15].effects[2].when.incoming: incoming — not a fact in the vocabulary
- [x] L277 clauses[FK17].effects[0].when.defence.roll: defence.roll — not a fact in the vocabulary
- [x] L278 clauses[FK17].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L279 clauses[FK17].effects[0].on_success: on_success — no one-to-one verb
- [x] L280 clauses[FK17].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L290 clauses[FK18].effects[0].when.defence.roll: defence.roll — not a fact in the vocabulary
- [x] L291 clauses[FK18].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L292 clauses[FK18].effects[0].on_failure: on_failure — no one-to-one verb

## rules/core/fertigkeitsproben.yaml

- [x] L37 clauses[FP1].effects[0].defines: defines — no one-to-one verb
- [x] L52 clauses[FP2].effects[0].forbid.check: check — not a field of `forbid`
- [x] L52 clauses[FP2].effects[0].forbid.when: when — not a field of `forbid`
- [x] L66 clauses[FP3].effects[0].defines: defines — no one-to-one verb
- [x] L66 clauses[FP3].effects[0].defines.spend_per_die: spend_per_die — snake_case key, no mapping
- [x] L89 clauses[FP5].effects[0].defines: defines — no one-to-one verb
- [x] L98 clauses[FP8].effects[0].defines: defines — no one-to-one verb
- [x] L122 clauses[QS1].effects[0].table: table — no one-to-one verb
- [x] L131 clauses[QS2].effects[0].set.stage: stage — not a field of `set`
- [x] L131 clauses[QS2].effects[0].set.when: when — not a field of `set`
- [x] L143 clauses[FM1].effects[0].defines: defines — no one-to-one verb
- [x] L143 clauses[FM1].effects[0].defines.applies_to: applies_to — snake_case key, no mapping
- [x] L158 clauses[FM2].effects[0].offer.gm.modifier: gm.modifier — not a field of `offer`
- [x] L169 clauses[KR1].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [x] L170 clauses[KR1].effects[0].set.stage: stage — not a field of `set`
- [x] L170 clauses[KR1].effects[0].set.success: success — not a field of `set`
- [x] L170 clauses[KR1].effects[0].set.kind: kind — not a field of `set`
- [x] L187 clauses[KR2].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [x] L188 clauses[KR2].effects[0].set.stage: stage — not a field of `set`
- [x] L188 clauses[KR2].effects[0].set.kind: kind — not a field of `set`
- [x] L205 clauses[PZ1].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [x] L206 clauses[PZ1].effects[0].set.stage: stage — not a field of `set`
- [x] L206 clauses[PZ1].effects[0].set.success: success — not a field of `set`
- [x] L206 clauses[PZ1].effects[0].set.kind: kind — not a field of `set`
- [x] L207 clauses[PZ1].effects[1].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [x] L208 clauses[PZ1].effects[1].set.stage: stage — not a field of `set`
- [x] L208 clauses[PZ1].effects[1].set.kind: kind — not a field of `set`

## rules/core/groessenkategorie.yaml

- [x] L18 scale: scale — not a rule key in the vocabulary
- [x] L39 clauses[GK2].ruling: ruling — not a clause key in the vocabulary
- [x] L47 clauses[GK3].effects[GK3.at].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L49 clauses[GK3].effects[GK3.at].id: id — no one-to-one verb
- [x] L57 clauses[GK4].effects[0].when.side: side — not a fact in the vocabulary
- [x] L58 clauses[GK4].effects[0].forbid.defence: defence — not a field of `forbid`
- [x] L59 clauses[GK4].effects[1].when.side: side — not a fact in the vocabulary
- [x] L60 clauses[GK4].effects[1].forbid.defence: defence — not a field of `forbid`

## rules/core/kampfsonderfertigkeiten.yaml

- [x] L30 clauses[KS2].effects[0].when.ability: ability — not a fact in the vocabulary
- [x] L31 clauses[KS2].effects[0].apply: apply — no one-to-one verb
- [x] L36 clauses[KS2].effects[1].show: show — no one-to-one verb
- [x] L46 clauses[KS3].effects[0].limit.manoeuvre: manoeuvre — not a field of `limit`
- [x] L56 clauses[KS4].effects[0].limit.manoeuvre: manoeuvre — not a field of `limit`
- [x] L63 clauses[KS5].effects[0].offer.pickers: pickers — not a field of `offer`
- [x] L63 clauses[KS5].effects[0].offer.per: per — not a field of `offer`
- [x] L65 clauses[KS5].effects[1].show: show — no one-to-one verb
- [x] L69 clauses[KS5].effects[2].when.manoeuvres: manoeuvres — not a fact in the vocabulary
- [x] L69 clauses[KS5].effects[2].when.manoeuvres.excluded_by: excluded_by — snake_case key, no mapping
- [x] L70 clauses[KS5].effects[2].forbid.combination: combination — not a field of `forbid`
- [x] L90 clauses[KS6].ruling: ruling — not a clause key in the vocabulary

## rules/core/kampfwerte.yaml

- [x] L225 clauses[KW21].effects[0].defines: defines — no one-to-one verb
- [x] L248 clauses[KW6].effects[0].when.technique: technique — not a fact in the vocabulary
- [x] L249 clauses[KW6].effects[0].replace.value: value — not a field of `replace`
- [x] L271 clauses[KW7].effects[0].when.technique.leit: technique.leit — not a fact in the vocabulary
- [x] L272 clauses[KW7].effects[0].choose: choose — no one-to-one verb
- [x] L397 clauses[KW10].effects[0].defines: defines — no one-to-one verb
- [x] L397 clauses[KW10].effects[0].defines.once_per: once_per — snake_case key, no mapping
- [x] L423 clauses[KW11].effects[0].when.event: event — not a fact in the vocabulary
- [x] L424 clauses[KW11].effects[0].recompute: recompute — no one-to-one verb

## rules/core/ladezeiten.yaml

- [x] L30 clauses[LZ1].effects[0].provides: provides — `from` is a pointer, not a named value
- [x] L43 clauses[LZ2].effects[0].process.of: of — not a field of `process`
- [x] L45 clauses[LZ2].effects[0].process.step: step — not a field of `process`
- [x] L50 clauses[LZ2].effects[1].process.step: step — not a field of `process`
- [x] L52 clauses[LZ2].effects[2].forbid.attack: attack — not a field of `forbid`
- [x] L52 clauses[LZ2].effects[2].forbid.when: when — not a field of `forbid`
- [x] L54 clauses[LZ2].effects[3].after: after — no one-to-one verb
- [x] L64 clauses[LZ3].effects[0].requires: requires — a key that is not a fact: costs, before
- [x] L84 clauses[LZ5].effects[0].process.of: of — not a field of `process`
- [x] L84 clauses[LZ5].effects[0].process.step: step — not a field of `process`
- [x] L99 clauses[LZ7].effects[0].after: after — no one-to-one verb

## rules/core/lebensenergie.yaml

No residue.

## rules/core/mehrfache-verteidigung.yaml

- [x] L27 clauses[MV1].effects[MV1.step].when.check: check — not a fact in the vocabulary
- [x] L29 clauses[MV1].effects[MV1.step].id: id — no one-to-one verb
- [x] L30 clauses[MV1].effects[1].forbid.second_defence_against: second_defence_against — not a field of `forbid`
- [x] L46 clauses[MV3].effects[0].when.check: check — not a fact in the vocabulary
- [x] L46 clauses[MV3].effects[0].when.value.after: value.after — not a fact in the vocabulary
- [x] L47 clauses[MV3].effects[0].forbid.defence: defence — not a field of `forbid`

## rules/core/passierschlag.yaml

- [x] L25 clauses[PS1].effects[0].when.event: event — not a fact in the vocabulary
- [x] L25 clauses[PS1].effects[0].when.of: of — not a fact in the vocabulary
- [x] L25 clauses[PS1].effects[0].when.not.engages: engages — not a fact in the vocabulary
- [x] L42 clauses[PS2].effects[0].offer.attack: attack — not a field of `offer`
- [x] L42 clauses[PS2].effects[0].offer.domain: domain — not a field of `offer`
- [x] L47 clauses[PS2].effects[2].when.side: side — not a fact in the vocabulary
- [x] L48 clauses[PS2].effects[2].opponent_may_only: opponent_may_only — no one-to-one verb
- [x] L50 clauses[PS2].effects[3].when.side: side — not a fact in the vocabulary
- [x] L51 clauses[PS2].effects[3].forbid.defence: defence — not a field of `forbid`
- [x] L52 clauses[PS2].effects[3].then: then — no one-to-one verb
- [x] L52 clauses[PS2].effects[3].then.go_to: go_to — snake_case key, no mapping
- [x] L63 clauses[PS3].effects[0].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [x] L78 clauses[PS4].effects[0].forbid.roll: roll — not a field of `forbid`
- [x] L80 clauses[PS4].effects[1].when.roll: roll — not a fact in the vocabulary
- [x] L81 clauses[PS4].effects[1].result: result — no one-to-one verb
- [x] L83 clauses[PS4].effects[2].when.roll: roll — not a fact in the vocabulary
- [x] L84 clauses[PS4].effects[2].result: result — no one-to-one verb
- [x] L94 clauses[PS5].effects[0].limit.attack: attack — not a field of `limit`

## rules/core/regeneration.yaml

- [x] L25 clauses[R2].effects[0].offer.action: action — not a field of `offer`
- [x] L25 clauses[R2].effects[0].offer.outside: outside — not a field of `offer`
- [x] L30 clauses[R3].status: status — not a clause key in the vocabulary
- [x] L31 clauses[R3].why: why — `why` without `effects: none`: the clause has no body to carry it
- [x] L39 clauses[R4].effects[0].roll: roll — no one-to-one verb
- [x] L40 clauses[R4].effects[1].add.lines: lines — not a field of `add`
- [x] L41 clauses[R4].effects[2].floor.value: value — not a field of `floor`
- [x] L41 clauses[R4].effects[2].floor.after: after — not a field of `floor`
- [x] L50 clauses[R5].effects[0].cap.value: value — not a field of `cap`
- [x] L59 clauses[R6].effects[0].ask.question: question — not a field of `ask`
- [x] L60 clauses[R6].effects[1].when.answer: answer — not a fact in the vocabulary
- [x] L64 clauses[R6].effects[2].when.answer: answer — not a fact in the vocabulary
- [x] L75 clauses[R7].effects[0].when.hero.states: hero.states — not a fact in the vocabulary
- [x] L96 clauses[T1].effects[0].ask.question: question — not a field of `ask`
- [x] L96 clauses[T1].effects[0].ask.multi: multi — not a field of `ask`
- [x] L97 clauses[T1].effects[0].lines: lines — no one-to-one verb

## rules/core/reichweite.yaml

- [x] L17 scale: scale — not a rule key in the vocabulary
- [x] L46 clauses[RW3].effects[RW3.at].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L46 clauses[RW3].effects[RW3.at].when.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [x] L48 clauses[RW3].effects[RW3.at].id: id — no one-to-one verb

## rules/core/reiterkampf.yaml

- [x] L16 applies_when: applies_when — not a rule key in the vocabulary
- [x] L37 clauses[RK1].effects[0].replace.value: value — not a field of `replace`
- [x] L46 clauses[RK2].effects[0].grants: grants — no one-to-one verb
- [x] L54 clauses[RK3].effects[0].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [x] L60 clauses[RK4].effects[0].forbid.loadout: loadout — not a field of `forbid`
- [x] L68 clauses[RK5].effects[0].when.attack.from: attack.from — not a fact in the vocabulary
- [x] L69 clauses[RK5].effects[0].forbid.defence: defence — not a field of `forbid`
- [x] L70 clauses[RK5].effects[0].open_ruling: open_ruling — no one-to-one verb
- [x] L82 clauses[RK6].effects[0].when.check: check — `check: aw` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L84 clauses[RK6].effects[1].offer.on: on — not a field of `offer`
- [x] L84 clauses[RK6].effects[1].offer.then: then — not a field of `offer`
- [x] L93 clauses[RK7].effects[0].when.check: check — not a fact in the vocabulary
- [x] L94 clauses[RK7].effects[0].lower: lower — no one-to-one verb
- [x] L94 clauses[RK7].effects[0].lower.penalty_only: penalty_only — snake_case key, no mapping
- [x] L105 clauses[RK8].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L112 clauses[RK9].effects[0].costs: costs — no one-to-one verb
- [x] L120 clauses[RK10].effects[0].when.event: event — not a fact in the vocabulary
- [x] L121 clauses[RK10].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L122 clauses[RK10].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L127 clauses[RK11].effects[0].when.event: event — not a fact in the vocabulary
- [x] L128 clauses[RK11].effects[0].offer.on: on — not a field of `offer`
- [x] L128 clauses[RK11].effects[0].offer.label: label — not a field of `offer`
- [x] L128 clauses[RK11].effects[0].offer.then: then — not a field of `offer`
- [x] L143 clauses[RK12].effects[0].defines: defines — no one-to-one verb
- [x] L143 clauses[RK12].effects[0].defines.requires_check: requires_check — snake_case key, no mapping
- [x] L157 clauses[RK13].effects[0].offer.order: order — not a field of `offer`
- [x] L158 clauses[RK13].effects[0].offer.requires: requires — not a field of `offer`
- [x] L159 clauses[RK13].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L163 clauses[RK13].effects[0].offer.attack: attack — not a field of `offer`
- [x] L164 clauses[RK13].effects[0].offer.opponent_may_only: opponent_may_only — not a field of `offer`
- [x] L165 clauses[RK13].effects[0].offer.after: after — not a field of `offer`
- [x] L182 clauses[RK14].ruling: ruling — not a clause key in the vocabulary
- [x] L185 clauses[RK14].effects[0].offer.order: order — not a field of `offer`
- [x] L186 clauses[RK14].effects[0].offer.requires: requires — not a field of `offer`
- [x] L189 clauses[RK14].effects[0].offer.attack: attack — not a field of `offer`
- [x] L190 clauses[RK14].effects[0].offer.opponent_may_only: opponent_may_only — not a field of `offer`
- [x] L191 clauses[RK14].effects[0].offer.on_hit: on_hit — not a field of `offer`
- [x] L207 clauses[RK15].effects[0].offer.order: order — not a field of `offer`
- [x] L208 clauses[RK15].effects[0].offer.requires_check: requires_check — not a field of `offer`
- [x] L209 clauses[RK15].effects[0].offer.on_success: on_success — not a field of `offer`

## rules/core/ruestung-und-belastung.yaml

- [x] L30 clauses[A1].effects[0].sets: sets — no one-to-one verb

## rules/core/schaden.yaml

- [x] L31 clauses[S1].effects[0].roll: roll — no one-to-one verb
- [x] L34 clauses[S1].effects[1].when.event: event — not a fact in the vocabulary
- [x] L38 clauses[S1].effects[2].when.event: event — not a fact in the vocabulary
- [x] L115 clauses[S4].effects[0].when.weapon.leit: weapon.leit — not a fact in the vocabulary
- [x] L116 clauses[S4].effects[0].replace.value: value — not a field of `replace`
- [x] L129 clauses[S5].effects[0].offer.on: on — not a field of `offer`
- [x] L129 clauses[S5].effects[0].offer.then: then — not a field of `offer`
- [x] L158 clauses[S8].effects[0].when.le.current: le.current — not a fact in the vocabulary

## rules/core/schicksalspunkte.yaml

- [x] L36 clauses[SP-verteidigung].effects[0].offer.before: before — not a field of `offer`
- [x] L48 clauses[SP-zustand].effects[1].suppress.kind: kind — not a field of `suppress`
- [x] L79 rulings[schip-lifts-incapacity].source: source — not a ruling key in the vocabulary

## rules/core/schilde.yaml

- [x] L28 clauses[SCH1].effects[0].when.with: with — not a fact in the vocabulary
- [x] L28 clauses[SCH1].effects[0].when.loadout.other: loadout.other — not a fact in the vocabulary
- [x] L43 clauses[SCH2].effects[0].offer.attack: attack — not a field of `offer`
- [x] L43 clauses[SCH2].effects[0].offer.value: value — not a field of `offer`
- [x] L57 clauses[SCH3].effects[0].offer.defence: defence — not a field of `offer`
- [x] L58 clauses[SCH3].effects[0].offer.requires: requires — not a field of `offer`
- [x] L59 clauses[SCH3].effects[0].offer.value: value — not a field of `offer`
- [x] L83 clauses[SCH5].effects[0].exempt: exempt — no one-to-one verb
- [x] L91 clauses[SCH6].effects[0].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L92 clauses[SCH6].effects[0].allow: allow — no one-to-one verb
- [x] L94 clauses[SCH6].effects[1].cap.lines: lines — not a field of `cap`
- [x] L94 clauses[SCH6].effects[1].cap.count: count — not a field of `cap`
- [x] L111 clauses[SCH8].effects[0].when.attack.kind: attack.kind — not a fact in the vocabulary
- [x] L112 clauses[SCH8].effects[0].forbid.defence: defence — not a field of `forbid`

## rules/core/trefferzonen-ruestungsschutz.yaml

- [x] L6 fokus: fokus — not a rule key in the vocabulary
- [x] L7 requires_ruleset: requires_ruleset — not a rule key in the vocabulary
- [x] L10 replaces: replaces — not a rule key in the vocabulary
- [x] L43 clauses[RS2].effects[0].when.event: event — not a fact in the vocabulary
- [x] L59 clauses[RS3].effects[0].forbid.loadout: loadout — not a field of `forbid`
- [x] L95 clauses[RS4].effects[0].sets: sets — no one-to-one verb

## rules/core/trefferzonen.yaml

- [x] L13 fokus: fokus — not a rule key in the vocabulary
- [x] L42 clauses[TZ2].effects[0].when.event: event — not a fact in the vocabulary
- [x] L42 clauses[TZ2].effects[0].when.zone: zone — not a fact in the vocabulary
- [x] L43 clauses[TZ2].effects[0].roll: roll — no one-to-one verb
- [x] L43 clauses[TZ2].effects[0].roll.on.chosen_by: chosen_by — snake_case key, no mapping
- [x] L57 clauses[TZ3].effects[0].table_for: table_for — no one-to-one verb
- [x] L59 clauses[TZ3].effects[0].table_for.clamp_to: clamp_to — snake_case key, no mapping
- [x] L114 clauses[TZ4c].effects[0].sets: sets — no one-to-one verb
- [x] L186 clauses[TZ4i].effects[0].provide.value.7-20.split_evenly: split_evenly — snake_case key, no mapping
- [x] L211 clauses[TZ5].effects[0].offer.on: on — not a field of `offer`
- [x] L211 clauses[TZ5].effects[0].offer.zones: zones — not a field of `offer`
- [x] L216 clauses[TZ5].effects[TZ5.aim].id: id — no one-to-one verb
- [x] L218 clauses[TZ5].effects[2].raise: raise — no one-to-one verb
- [x] L223 clauses[TZ5].effects[3].replaces: replaces — no one-to-one verb
- [x] L240 clauses[TZ6].effects[0].table: table — no one-to-one verb
- [x] L254 clauses[TZ7].status: status — not a clause key in the vocabulary
- [x] L255 clauses[TZ7].why: why — `why` without `effects: none`: the clause has no body to carry it
- [x] L269 clauses[TZ8].effects[0].when.event: event — not a fact in the vocabulary
- [x] L270 clauses[TZ8].effects[0].requires_check: requires_check — no one-to-one verb
- [x] L274 clauses[TZ8].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L300 clauses[TZ11].effects[0].table: table — no one-to-one verb
- [x] L303 clauses[TZ11].effects[0].table.arme.drop.ask_if: ask_if — snake_case key, no mapping

## rules/core/vorteilhafte-position.yaml

- [x] L15 applies_when: applies_when — not a rule key in the vocabulary
- [x] L18 applies_when.any[1].granted_by: granted_by — snake_case key, no mapping
- [x] L32 clauses[VP1].effects[VP1.at].id: id — no one-to-one verb
- [x] L42 clauses[VP2].status: status — not a clause key in the vocabulary
- [x] L43 clauses[VP2].why: why — `why` without `effects: none`: the clause has no body to carry it
- [x] L49 clauses[VP3].status: status — not a clause key in the vocabulary
- [x] L50 clauses[VP3].why: why — `why` without `effects: none`: the clause has no body to carry it

## rules/core/waffeneigenschaften.yaml

- [x] L8 fokus: fokus — not a rule key in the vocabulary
- [x] L25 clauses[WE1].effects[0].defines: defines — no one-to-one verb
- [x] L36 clauses[WE2].effects[0].gates: gates — no one-to-one verb

## rules/core/zaubermodifikationen.yaml

- [x] L40 clauses[ZM1].effects[0].offer.pickers: pickers — not a field of `offer`
- [x] L40 clauses[ZM1].effects[0].offer.per: per — not a field of `offer`
- [x] L40 clauses[ZM1].effects[0].offer.before: before — not a field of `offer`
- [x] L41 clauses[ZM1].effects[1].limit.choice: choice — not a field of `limit`
- [x] L54 clauses[ZM2].effects[0].limit.category: category — not a field of `limit`
- [x] L54 clauses[ZM2].effects[0].limit.max_steps: max_steps — not a field of `limit`
- [x] L62 clauses[ZM3].effects[0].forbid.choice: choice — not a field of `forbid`
- [x] L71 clauses[ZM4].effects[0].forbid.choice: choice — not a field of `forbid`
- [x] L71 clauses[ZM4].effects[0].forbid.when: when — not a field of `forbid`
- [x] L83 clauses[ZM5].effects[0].derive.value: value — not a field of `derive`
- [x] L83 clauses[ZM5].effects[0].derive.from: from — not a field of `derive`
- [x] L83 clauses[ZM5].effects[0].derive.steps: steps — not a field of `derive`
- [x] L83 clauses[ZM5].effects[0].derive.table: table — not a field of `derive`
- [x] L86 clauses[ZM5].effects[1].cap.value: value — not a field of `cap`
- [x] L87 clauses[ZM5].effects[2].charge: charge — keys outside the row: every, while
- [x] L100 clauses[ZM6].effects[0].limit.choice: choice — not a field of `limit`
- [x] L100 clauses[ZM6].effects[0].limit.each: each — not a field of `limit`
- [x] L107 clauses[ZM7].effects[0].forbid.choice: choice — not a field of `forbid`
- [x] L107 clauses[ZM7].effects[0].forbid.when: when — not a field of `forbid`
- [x] L167 clauses[ZM11].effects[0].shift: shift — the effect already has `add`: two verbs in one effect
- [x] L170 clauses[ZM11].effects[1].shift: shift — the effect already has `add`: two verbs in one effect
- [x] L173 clauses[ZM11].effects[2].shift: shift — the effect already has `add`: two verbs in one effect
- [x] L176 clauses[ZM11].effects[3].shift: shift — the effect already has `add`: two verbs in one effect
- [x] L179 clauses[ZM11].effects[4].shift: shift — the effect already has `add`: two verbs in one effect
- [x] L184 clauses[ZM11].effects[5].when.choice: choice — not a fact in the vocabulary
- [x] L187 clauses[ZM11].effects[6].forbid.choice: choice — not a field of `forbid`
- [x] L187 clauses[ZM11].effects[6].forbid.when: when — not a field of `forbid`
- [x] L205 clauses[ZM12].effects[0].on_success: on_success — no one-to-one verb
- [x] L206 clauses[ZM12].effects[1].on_failure: on_failure — no one-to-one verb

## rules/core/zustaende.yaml

- [x] L35 clauses[Z3].effects[0].cap.lines: lines — not a field of `cap`
- [x] L35 clauses[Z3].effects[0].cap.on: on — not a field of `cap`
- [x] L55 clauses[Z4].status: status — not a clause key in the vocabulary
- [x] L56 clauses[Z4].why: why — `why` without `effects: none`: the clause has no body to carry it
- [x] L63 clauses[Z5].effects[0].when.sum: sum — not a fact in the vocabulary
- [x] L63 clauses[Z5].effects[0].when.sum.condition_levels: condition_levels — snake_case key, no mapping
- [x] L63 clauses[Z5].effects[0].when.min: min — not a fact in the vocabulary

## rules/creatures/maechtiger-schlag.yaml

- [x] L36 clauses[MS1].effects[0].tell: tell — tell: the text is a structure, not a text
- [x] L36 clauses[MS1].effects[0].tell.opponent.on_failure: on_failure — snake_case key, no mapping
- [x] L49 clauses[MS2].effects[0].opponent_add: opponent_add — keys outside the row: round
- [x] L61 clauses[MS3].effects[0].cancels: cancels — no one-to-one verb
- [x] L63 clauses[MS3].effects[1].tell: tell — tell: the text is a structure, not a text
- [x] L63 clauses[MS3].effects[1].tell.opponent.on_failure: on_failure — snake_case key, no mapping
- [x] L63 clauses[MS3].effects[1].tell.opponent.whatever_the_parry: whatever_the_parry — snake_case key, no mapping

## rules/creatures/ruhiges-temperament.yaml

- [x] L24 clauses[RT1].effects[0].when.check: check — not a fact in the vocabulary

## rules/creatures/svellttaler-kaltblut.yaml

- [x] L26 profile: profile — not a rule key in the vocabulary
- [x] L88 clauses[SK3].effects[1].offer.order: order — not a field of `offer`
- [x] L88 clauses[SK3].effects[1].offer.attacks: attacks — not a field of `offer`
- [x] L88 clauses[SK3].effects[1].offer.via: via — not a field of `offer`
- [x] L112 clauses[SK5].effects[0].grants: grants — no one-to-one verb
- [x] L159 clauses[SK10].effects[0].when.mount.lep.at_most: at_most — snake_case key, no mapping

## rules/disadvantages/DISADV_37.yaml

- [x] L33 clauses[SE1].effects[0].offer.check: check — not a field of `offer`
- [x] L34 clauses[SE1].effects[0].offer.cause: cause — not a field of `offer`
- [x] L35 clauses[SE1].effects[0].offer.when: when — not a field of `offer`
- [x] L36 clauses[SE1].effects[0].offer.ruling: ruling — not a field of `offer`
- [x] L49 clauses[SE2].effects[0].on_failure: on_failure — no one-to-one verb
- [x] L64 clauses[SE4].effects[0].offer.gm.modifier: gm.modifier — not a field of `offer`
- [x] L90 clauses[SE6].effects[0].provides: provides — a snake_case name, or not a mapping of names
- [x] L90 clauses[SE6].effects[0].provides.text_by_option: text_by_option — snake_case key, no mapping

## rules/disadvantages/DISADV_57.yaml

- [x] L20 clauses[VW1].effects[0].when.check: check — not a fact in the vocabulary
- [x] L21 clauses[VW1].effects[0].when.cause: cause — not a fact in the vocabulary

## rules/equipment/ITEMTPL_19.yaml

- [x] L22 stats: stats — not a rule key in the vocabulary
- [x] L26 stats.at_mod: at_mod — snake_case key, no mapping
- [x] L27 stats.pa_mod: pa_mod — snake_case key, no mapping
- [x] L62 clauses[RS2].effects[0].offer.on: on — not a field of `offer`
- [x] L90 clauses[RS4].effects[0].raise: raise — no one-to-one verb

## rules/equipment/ITEMTPL_29.yaml

- [x] L21 stats: stats — not a rule key in the vocabulary
- [x] L25 stats.at_mod: at_mod — snake_case key, no mapping
- [x] L26 stats.pa_mod: pa_mod — snake_case key, no mapping
- [x] L32 stats.structure_points: structure_points — snake_case key, no mapping
- [x] L33 stats.shield_size: shield_size — snake_case key, no mapping
- [x] L48 clauses[GR1].effects[2].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [x] L48 clauses[GR1].effects[2].when.loadout.hand: loadout.hand — not a fact in the vocabulary
- [x] L59 clauses[GR2].effects[0].when.incoming: incoming — not a fact in the vocabulary
- [x] L72 clauses[GR3].effects[0].when.ini.tie: ini.tie — not a fact in the vocabulary
- [x] L73 clauses[GR3].effects[0].tell.order: order — not a field of `tell`

## rules/equipment/ITEMTPL_35.yaml

- [x] L16 stats: stats — not a rule key in the vocabulary
- [x] L20 stats.at_mod: at_mod — snake_case key, no mapping
- [x] L21 stats.pa_mod: pa_mod — snake_case key, no mapping

## rules/rulings.yaml

- [x] L13 [round-up].see: see — not a ruling key in the vocabulary
- [x] L61 [manoeuvre-combination].see: see — not a ruling key in the vocabulary

## situations/beidhaendiger-kampf.yaml

- [x] L8 weapons: weapons — not a situations-file key in the vocabulary
- [x] L19 situations["11.1"].choose.action: action — not a fact in the vocabulary
- [x] L19 situations["11.1"].choose.with: with — not a fact in the vocabulary
- [x] L29 situations["11.2"].choose.action: action — not a fact in the vocabulary
- [x] L57 situations["11.4"].choose.action: action — not a fact in the vocabulary
- [x] L81 situations[11.4b].choose.action: action — not a fact in the vocabulary
- [x] L100 situations["11.6"].choose.parryWith: parryWith — not a fact in the vocabulary
- [x] L108 situations["11.7"].choose.action: action — not a fact in the vocabulary
- [x] L121 situations["11.8"].choose.action: action — not a fact in the vocabulary
- [x] L122 situations["11.8"].rolls.attack_main: attack_main — snake_case key, no mapping
- [x] L124 situations["11.8"].expect.cancelled: cancelled — neither an expect key nor a query
- [x] L130 situations["11.9"].choose.action: action — not a fact in the vocabulary
- [x] L150 situations["11.10"].expect.not_selectable: not_selectable — neither an expect key nor a query
- [x] L151 situations["11.10"].expect.selectable: selectable — neither an expect key nor a query
- [x] L157 situations["11.11"].choose.action: action — not a fact in the vocabulary
- [x] L170 situations["11.12"].hero.loadout.player_says: player_says — snake_case key, no mapping
- [x] L171 situations["11.12"].choose.action: action — not a fact in the vocabulary

## situations/belastung.yaml

- [x] L13 armour: armour — not a situations-file key in the vocabulary
- [x] L30 situations["1.1"].expect.conditions: conditions — neither an expect key nor a query
- [x] L41 situations["1.2"].expect.conditions: conditions — neither an expect key nor a query
- [x] L58 situations["1.3"].expect.conditions: conditions — neither an expect key nor a query
- [x] L67 situations["1.4"].expect.conditions: conditions — neither an expect key nor a query
- [x] L68 situations["1.4"].expect.states: states — neither an expect key nor a query
- [x] L69 situations["1.4"].expect.actions: actions — neither an expect key nor a query
- [x] L76 situations["1.5"].expect.conditions: conditions — neither an expect key nor a query
- [x] L77 situations["1.5"].expect.states: states — neither an expect key nor a query
- [x] L86 situations["2.1"].expect.conditions: conditions — neither an expect key nor a query
- [x] L94 situations["2.2"].expect.conditions: conditions — neither an expect key nor a query
- [x] L103 situations["2.4"].expect.conditions: conditions — neither an expect key nor a query
- [x] L112 situations["2.8"].expect.conditions: conditions — neither an expect key nor a query
- [x] L121 situations["2.10"].expect.conditions: conditions — neither an expect key nor a query
- [x] L122 situations["2.10"].expect.states: states — neither an expect key nor a query
- [x] L129 situations["2.11"].expect.conditions: conditions — neither an expect key nor a query
- [x] L147 situations["3.1"].expect.spell: spell — neither an expect key nor a query
- [x] L158 situations["3.2"].expect.spell: spell — neither an expect key nor a query
- [x] L164 situations["3.3"].expect.conditions: conditions — neither an expect key nor a query
- [x] L165 situations["3.3"].expect.states: states — neither an expect key nor a query
- [x] L173 situations["3.4"].expect.conditions: conditions — neither an expect key nor a query
- [x] L174 situations["3.4"].expect.states: states — neither an expect key nor a query
- [x] L182 situations["4.1"].check: check — not a situation key in the vocabulary
- [x] L184 situations["4.1"].expect.check: check — neither an expect key nor a query
- [x] L190 situations["4.2"].check: check — not a situation key in the vocabulary
- [x] L192 situations["4.2"].expect.check: check — neither an expect key nor a query
- [x] L198 situations["4.3"].check: check — not a situation key in the vocabulary
- [x] L200 situations["4.3"].expect.check: check — neither an expect key nor a query
- [x] L206 situations["4.4"].check: check — not a situation key in the vocabulary
- [x] L208 situations["4.4"].expect.check: check — neither an expect key nor a query
- [x] L214 situations["4.6"].check: check — not a situation key in the vocabulary
- [x] L216 situations["4.6"].expect.check: check — neither an expect key nor a query
- [x] L222 situations["4.5"].check: check — not a situation key in the vocabulary
- [x] L238 situations["6.1"].expect.not_selectable: not_selectable — neither an expect key nor a query
- [x] L238 situations["6.1"].expect.not_selectable[0].second_armour: second_armour — snake_case key, no mapping

## situations/boronmir-neu.yaml

- [x] L96 situations["19.5"].choose.then: then — not a fact in the vocabulary
- [x] L101 situations["19.5"].expect.exclusive: exclusive — neither an expect key nor a query
- [x] L130 situations["19.7"].hit: hit — not a situation key in the vocabulary
- [x] L132 situations["19.7"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L141 situations["19.8"].hit: hit — not a situation key in the vocabulary
- [x] L143 situations["19.8"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L147 situations["19.8"].expect.on_failure: on_failure — neither an expect key nor a query
- [x] L153 situations["19.9"].hit: hit — not a situation key in the vocabulary
- [x] L155 situations["19.9"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L156 situations["19.9"].expect.sheet: sheet — neither an expect key nor a query
- [x] L174 situations["19.10"].expect.check: check — neither an expect key nor a query
- [x] L187 situations["19.11"].expect.check: check — neither an expect key nor a query
- [x] L201 situations["19.12"].fail: fail — not a situation key in the vocabulary
- [x] L203 situations["19.12"].expect.log: log — neither an expect key nor a query
- [x] L204 situations["19.12"].expect.states: states — neither an expect key nor a query

## situations/boronmir-sf.yaml

- [x] L27 hero.added_for_this_example: added_for_this_example — snake_case key, no mapping
- [x] L38 situations["14.1"].choose.vorstoss: vorstoss — not a fact in the vocabulary
- [x] L38 situations["14.1"].choose.at: at — not a fact in the vocabulary
- [x] L47 situations["14.1"].expect.not_allowed: not_allowed — neither an expect key nor a query
- [x] L53 situations["14.2"].round.parries_so_far: parries_so_far — snake_case key, no mapping
- [x] L84 situations["14.6"].choose.vorstoss: vorstoss — not a fact in the vocabulary
- [x] L84 situations["14.6"].choose.at: at — not a fact in the vocabulary
- [x] L84 situations["14.6"].choose.then: then — not a fact in the vocabulary
- [x] L86 situations["14.6"].expect.passierschlag_at: passierschlag_at — neither an expect key nor a query
- [x] L100 situations["14.7"].choose.vorstoss: vorstoss — not a fact in the vocabulary
- [x] L100 situations["14.7"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L100 situations["14.7"].choose.tier: tier — not a fact in the vocabulary
- [x] L102 situations["14.7"].expect.combinable: combinable — neither an expect key nor a query
- [x] L111 situations["14.8"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L118 situations["14.8"].expect.tell: tell — neither an expect key nor a query
- [x] L121 situations["14.8"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L154 situations["14.12"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L154 situations["14.12"].choose.tier: tier — not a fact in the vocabulary
- [x] L156 situations["14.12"].expect.combinable: combinable — neither an expect key nor a query
- [x] L164 situations["14.13"].expect.not_allowed: not_allowed — neither an expect key nor a query
- [x] L172 situations["14.13"].expect.on_failed_defence: on_failed_defence — neither an expect key nor a query
- [x] L184 situations["14.14"].check: check — not a situation key in the vocabulary
- [x] L187 situations["14.14"].expect.check: check — neither an expect key nor a query
- [x] L198 situations["14.15"].check: check — not a situation key in the vocabulary
- [x] L200 situations["14.15"].expect.check: check — neither an expect key nor a query
- [x] L258 situations["14.20"].choose.then: then — not a fact in the vocabulary
- [x] L267 situations["14.21"].choose.plaenklerFormation: plaenklerFormation — not a fact in the vocabulary
- [x] L267 situations["14.21"].choose.bonus: bonus — not a fact in the vocabulary
- [x] L267 situations["14.21"].choose.vorstoss: vorstoss — not a fact in the vocabulary
- [x] L267 situations["14.21"].choose.at: at — not a fact in the vocabulary

## situations/finte.yaml

- [x] L14 situations["8.1"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L14 situations["8.1"].choose.tier: tier — not a fact in the vocabulary
- [x] L17 situations["8.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L18 situations["8.1"].expect.on_hit.opponent_lines: opponent_lines — snake_case key, no mapping
- [x] L25 situations["8.2"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L25 situations["8.2"].choose.tier: tier — not a fact in the vocabulary
- [x] L28 situations["8.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L29 situations["8.2"].expect.on_hit.opponent_lines: opponent_lines — snake_case key, no mapping
- [x] L36 situations["8.3"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L36 situations["8.3"].choose.tier: tier — not a fact in the vocabulary
- [x] L40 situations["8.3"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L41 situations["8.3"].expect.on_hit.opponent_lines: opponent_lines — snake_case key, no mapping
- [x] L48 situations["8.4"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L48 situations["8.4"].choose.tier: tier — not a fact in the vocabulary
- [x] L49 situations["8.4"].opponent.defends_with: defends_with — snake_case key, no mapping
- [x] L51 situations["8.4"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L52 situations["8.4"].expect.on_hit.opponent_lines: opponent_lines — snake_case key, no mapping
- [x] L53 situations["8.4"].expect.on_hit.opponent_lines.defence.lines[0].applies_to: applies_to — snake_case key, no mapping
- [x] L74 situations["8.7"].expect.not_combinable: not_combinable — neither an expect key nor a query
- [x] L75 situations["8.7"].expect.told: told — neither an expect key nor a query
- [x] L82 situations["8.8"].expect.not_combinable: not_combinable — neither an expect key nor a query
- [x] L83 situations["8.8"].expect.told: told — neither an expect key nor a query
- [x] L96 situations["8.10"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L96 situations["8.10"].choose.tier: tier — not a fact in the vocabulary
- [x] L99 situations["8.10"].expect.on_miss: on_miss — neither an expect key nor a query
- [x] L100 situations["8.10"].expect.on_miss.opponent_lines: opponent_lines — snake_case key, no mapping

## situations/kampfreflexe.yaml

- [x] L8 mount: mount — not a situations-file key in the vocabulary
- [x] L63 situations["12.5"].expect.ini_belastung: ini_belastung — neither an expect key nor a query

## situations/kampfsituationen.yaml

- [x] L28 mount: mount — not a situations-file key in the vocabulary
- [x] L37 situations["17.1"].choose.attack: attack — not a fact in the vocabulary
- [x] L40 situations["17.1"].expect.costs: costs — neither an expect key nor a query
- [x] L41 situations["17.1"].expect.tell: tell — neither an expect key nor a query
- [x] L42 situations["17.1"].expect.rolls: rolls — neither an expect key nor a query
- [x] L52 situations["17.2"].choose.attack: attack — not a fact in the vocabulary
- [x] L63 situations["17.3"].choose.attack: attack — not a fact in the vocabulary
- [x] L77 situations["17.4"].choose.attack: attack — not a fact in the vocabulary
- [x] L77 situations["17.4"].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L85 situations["17.4"].expect.rolls: rolls — neither an expect key nor a query
- [x] L91 situations["17.5"].choose.attack: attack — not a fact in the vocabulary
- [x] L104 situations["17.6"].choose.attack: attack — not a fact in the vocabulary
- [x] L116 situations["17.7"].choose.attacks: attacks — not a fact in the vocabulary
- [x] L118 situations["17.7"].expect.each: each — neither an expect key nor a query
- [x] L119 situations["17.7"].expect.actions_used: actions_used — neither an expect key nor a query
- [x] L120 situations["17.7"].expect.counts_as_defence: counts_as_defence — neither an expect key nor a query
- [x] L126 situations["17.8"].event: event — not a situation key in the vocabulary
- [x] L129 situations["17.8"].expect.next: next — neither an expect key nor a query
- [x] L136 situations["17.9"].event: event — not a situation key in the vocabulary
- [x] L140 situations["17.9"].expect.with_choice: with_choice — neither an expect key nor a query
- [x] L141 situations["17.9"].expect.target: target — neither an expect key nor a query
- [x] L142 situations["17.9"].expect.then: then — neither an expect key nor a query
- [x] L189 situations["17.12"].expect.opponent_lines: opponent_lines — neither an expect key nor a query
- [x] L195 situations["17.13"].attack: attack — not a situation key in the vocabulary
- [x] L217 situations["17.15"].choose.defence: defence — not a fact in the vocabulary
- [x] L225 situations["17.16"].choose.defence: defence — not a fact in the vocabulary
- [x] L233 situations["17.17"].choose.attack: attack — not a fact in the vocabulary
- [x] L290 situations["17.22"].expect.tell: tell — neither an expect key nor a query

## situations/kampfwerte.yaml

- [x] L40 situations["16.1"].expect.techniques: techniques — neither an expect key nor a query
- [x] L78 situations["16.3"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L92 situations["16.4"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L101 situations["16.5"].choose.action: action — not a fact in the vocabulary
- [x] L129 situations["16.7"].expect.parries: parries — neither an expect key nor a query
- [x] L132 situations["16.7"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L139 situations["16.8"].choose.attack: attack — not a fact in the vocabulary
- [x] L147 situations["16.8"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L154 situations["16.9"].incoming: incoming — not a situation key in the vocabulary
- [x] L173 situations["16.10"].expect.conditions: conditions — neither an expect key nor a query
- [x] L179 situations["16.10"].expect.parries: parries — neither an expect key nor a query
- [x] L188 situations["16.11"].roll: roll — not a situation key in the vocabulary
- [x] L204 situations["16.12"].roll: roll — not a situation key in the vocabulary
- [x] L216 situations["16.13"].items: items — not a situation key in the vocabulary
- [x] L219 situations["16.13"].expect.parries: parries — neither an expect key nor a query
- [x] L226 situations["16.14"].choose.defence: defence — not a fact in the vocabulary
- [x] L234 situations["16.15"].items: items — not a situation key in the vocabulary
- [x] L248 situations["16.16"].choose.defence: defence — not a fact in the vocabulary
- [x] L248 situations["16.16"].choose.with: with — not a fact in the vocabulary
- [x] L258 situations["16.17"].event: event — not a situation key in the vocabulary
- [x] L261 situations["16.17"].expect.le: le — neither an expect key nor a query
- [x] L267 situations["16.18"].event: event — not a situation key in the vocabulary
- [x] L270 situations["16.18"].expect.le: le — neither an expect key nor a query
- [x] L276 situations["16.19"].event: event — not a situation key in the vocabulary
- [x] L277 situations["16.19"].choose.ignoresRS: ignoresRS — not a fact in the vocabulary
- [x] L281 situations["16.19"].expect.le: le — neither an expect key nor a query
- [x] L287 situations["16.20"].event: event — not a situation key in the vocabulary
- [x] L289 situations["16.20"].expect.le: le — neither an expect key nor a query
- [x] L290 situations["16.20"].expect.states: states — neither an expect key nor a query
- [x] L299 situations["16.21"].expect.techniques: techniques — neither an expect key nor a query
- [x] L309 situations["16.22"].expect.on_hit: on_hit — neither an expect key nor a query

## situations/kupperus-und-waffen.yaml

- [x] L32 mount: mount — not a situations-file key in the vocabulary
- [x] L42 situations["18.1"].choose.order: order — not a fact in the vocabulary
- [x] L42 situations["18.1"].choose.gait: gait — not a fact in the vocabulary
- [x] L42 situations["18.1"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L45 situations["18.1"].expect.costs: costs — neither an expect key nor a query
- [x] L46 situations["18.1"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L54 situations["18.1"].expect.on_check_failure: on_check_failure — neither an expect key nor a query
- [x] L56 situations["18.1"].expect.attack: attack — neither an expect key nor a query
- [x] L59 situations["18.1"].expect.attack.opponent_may_only: opponent_may_only — snake_case key, no mapping
- [x] L60 situations["18.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L62 situations["18.1"].expect.on_attack_success: on_attack_success — neither an expect key nor a query
- [x] L64 situations["18.1"].expect.on_attack_success.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [x] L67 situations["18.1"].expect.after: after — neither an expect key nor a query
- [x] L80 situations["18.2"].mount: mount — not a situation key in the vocabulary
- [x] L81 situations["18.2"].choose.order: order — not a fact in the vocabulary
- [x] L81 situations["18.2"].choose.gait: gait — not a fact in the vocabulary
- [x] L81 situations["18.2"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L83 situations["18.2"].expect.attack: attack — neither an expect key nor a query
- [x] L84 situations["18.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L91 situations["18.3"].choose.order: order — not a fact in the vocabulary
- [x] L91 situations["18.3"].choose.attack: attack — not a fact in the vocabulary
- [x] L94 situations["18.3"].expect.costs: costs — neither an expect key nor a query
- [x] L94 situations["18.3"].expect.costs[0].instead_of: instead_of — snake_case key, no mapping
- [x] L95 situations["18.3"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L104 situations["18.3"].expect.not_asked: not_asked — neither an expect key nor a query
- [x] L105 situations["18.3"].expect.on_check_failure: on_check_failure — neither an expect key nor a query
- [x] L107 situations["18.3"].expect.attack: attack — neither an expect key nor a query
- [x] L110 situations["18.3"].expect.attack.opponent_may_only: opponent_may_only — snake_case key, no mapping
- [x] L112 situations["18.3"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L114 situations["18.3"].expect.on_attack_success: on_attack_success — neither an expect key nor a query
- [x] L116 situations["18.3"].expect.on_attack_success.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [x] L126 situations["18.4"].choose.order: order — not a fact in the vocabulary
- [x] L126 situations["18.4"].choose.attack: attack — not a fact in the vocabulary
- [x] L128 situations["18.4"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L129 situations["18.4"].expect.tell: tell — neither an expect key nor a query
- [x] L130 situations["18.4"].expect.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [x] L139 situations["18.5"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [x] L148 situations["18.5"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L160 situations["18.6"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [x] L164 situations["18.6"].sequence[0].expect.on_hit: on_hit — snake_case key, no mapping
- [x] L169 situations["18.6"].sequence[1].expect.on_hit: on_hit — snake_case key, no mapping
- [x] L183 situations["18.7"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L197 situations["18.8"].choose.order: order — not a fact in the vocabulary
- [x] L197 situations["18.8"].choose.gait: gait — not a fact in the vocabulary
- [x] L197 situations["18.8"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [x] L199 situations["18.8"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L222 situations["18.9"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L233 situations["18.10"].choose.attack: attack — not a fact in the vocabulary
- [x] L235 situations["18.10"].expect.conditions: conditions — neither an expect key nor a query
- [x] L250 situations["18.11"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L271 situations["18.13"].expect.tell: tell — neither an expect key nor a query
- [x] L291 situations["18.15"].expect.ini_belastung: ini_belastung — neither an expect key nor a query
- [x] L297 situations["18.16"].expect.mount_carrying_capacity: mount_carrying_capacity — neither an expect key nor a query
- [x] L309 situations["18.17"].expect.on_hit: on_hit — neither an expect key nor a query

## situations/lebensenergie.yaml

- [x] L64 situations["15.3"].expect.conditions: conditions — neither an expect key nor a query
- [x] L72 situations["15.4"].expect.conditions: conditions — neither an expect key nor a query
- [x] L73 situations["15.4"].expect.acts_as: acts_as — neither an expect key nor a query
- [x] L86 situations["15.5"].expect.conditions: conditions — neither an expect key nor a query
- [x] L87 situations["15.5"].expect.acts_as: acts_as — neither an expect key nor a query
- [x] L89 situations["15.5"].expect.talent: talent — neither an expect key nor a query
- [x] L99 situations["15.6"].expect.conditions: conditions — neither an expect key nor a query
- [x] L100 situations["15.6"].expect.acts_as: acts_as — neither an expect key nor a query
- [x] L109 situations["15.7"].expect.conditions: conditions — neither an expect key nor a query
- [x] L110 situations["15.7"].expect.states: states — neither an expect key nor a query
- [x] L114 situations["15.7"].expect.after_check_passed: after_check_passed — neither an expect key nor a query
- [x] L115 situations["15.7"].expect.after_check_passed.acts_as: acts_as — snake_case key, no mapping
- [x] L124 situations["15.8"].expect.conditions: conditions — neither an expect key nor a query
- [x] L125 situations["15.8"].expect.states: states — neither an expect key nor a query
- [x] L129 situations["15.8"].expect.at_if_able_to_act: at_if_able_to_act — neither an expect key nor a query
- [x] L146 situations["15.9"].choose.environment: environment — not a fact in the vocabulary
- [x] L146 situations["15.9"].choose.t1: t1 — not a fact in the vocabulary
- [x] L146 situations["15.9"].choose.roll: roll — not a fact in the vocabulary
- [x] L148 situations["15.9"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L154 situations["15.9"].expect.after: after — neither an expect key nor a query
- [x] L154 situations["15.9"].expect.after.acts_as: acts_as — snake_case key, no mapping
- [x] L162 situations["15.10"].choose.environment: environment — not a fact in the vocabulary
- [x] L162 situations["15.10"].choose.roll: roll — not a fact in the vocabulary
- [x] L164 situations["15.10"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L170 situations["15.10"].expect.after: after — neither an expect key nor a query
- [x] L176 situations["15.11"].choose.environment: environment — not a fact in the vocabulary
- [x] L178 situations["15.11"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L186 situations["15.12"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L188 situations["15.12"].expect.told: told — neither an expect key nor a query
- [x] L196 situations["15.13"].choose.environment: environment — not a fact in the vocabulary
- [x] L196 situations["15.13"].choose.t1: t1 — not a fact in the vocabulary
- [x] L196 situations["15.13"].choose.roll: roll — not a fact in the vocabulary
- [x] L198 situations["15.13"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L210 situations["15.14"].choose.environment: environment — not a fact in the vocabulary
- [x] L210 situations["15.14"].choose.roll: roll — not a fact in the vocabulary
- [x] L212 situations["15.14"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L213 situations["15.14"].expect.after: after — neither an expect key nor a query
- [x] L219 situations["15.15"].choose.environment: environment — not a fact in the vocabulary
- [x] L219 situations["15.15"].choose.roll: roll — not a fact in the vocabulary
- [x] L221 situations["15.15"].expect.regeneration: regeneration — neither an expect key nor a query
- [x] L242 situations["15.17"].expect.told: told — neither an expect key nor a query
- [x] L249 situations["15.18"].expect.told: told — neither an expect key nor a query
- [x] L256 situations["15.19"].expect.told: told — neither an expect key nor a query

## situations/liegend.yaml

- [x] L21 situations["7.2"].check: check — not a situation key in the vocabulary
- [x] L31 situations["7.3"].expect.opponent_lines: opponent_lines — neither an expect key nor a query
- [x] L33 situations["7.3"].expect.told: told — neither an expect key nor a query
- [x] L40 situations["7.4"].expect.states: states — neither an expect key nor a query
- [x] L43 situations["7.4"].expect.actions: actions — neither an expect key nor a query
- [x] L44 situations["7.4"].expect.defences: defences — neither an expect key nor a query
- [x] L54 situations["7.5"].expect.states: states — neither an expect key nor a query
- [x] L66 situations["7.6"].choose.action: action — not a fact in the vocabulary
- [x] L66 situations["7.6"].choose.check: check — not a fact in the vocabulary
- [x] L69 situations["7.6"].expect.after: after — neither an expect key nor a query
- [x] L70 situations["7.6"].expect.told: told — neither an expect key nor a query
- [x] L77 situations["7.7"].choose.action: action — not a fact in the vocabulary
- [x] L77 situations["7.7"].choose.check: check — not a fact in the vocabulary
- [x] L79 situations["7.7"].expect.after: after — neither an expect key nor a query
- [x] L80 situations["7.7"].expect.told: told — neither an expect key nor a query

## situations/mehrfache-verteidigung.yaml

- [x] L12 situations[V1].check: check — not a situation key in the vocabulary
- [x] L20 situations[V2].check: check — not a situation key in the vocabulary
- [x] L28 situations[V3].check: check — not a situation key in the vocabulary
- [x] L36 situations[V4].check: check — not a situation key in the vocabulary
- [x] L44 situations[V5].check: check — not a situation key in the vocabulary
- [x] L52 situations[V6].previous_round: previous_round — not a situation key in the vocabulary
- [x] L53 situations[V6].check: check — not a situation key in the vocabulary
- [x] L62 situations[V7].check: check — not a situation key in the vocabulary
- [x] L64 situations[V7].expect.pa.lines[0].changed_by: changed_by — snake_case key, no mapping
- [x] L71 situations[V8].check: check — not a situation key in the vocabulary
- [x] L83 situations[V9].expect.pa.not_selectable: not_selectable — snake_case key, no mapping
- [x] L91 situations[V10].check: check — not a situation key in the vocabulary
- [x] L98 situations[V10].expect.pa_value: pa_value — neither an expect key nor a query
- [x] L108 situations[V11].expect.actions: actions — neither an expect key nor a query
- [x] L108 situations[V11].expect.actions.free_action: free_action — snake_case key, no mapping
- [x] L115 situations[V12].check: check — not a situation key in the vocabulary

## situations/probe-fernkampf.yaml

- [x] L20 situations["21.1"].target: target — not a situation key in the vocabulary
- [x] L22 situations["21.1"].expect.range_band: range_band — neither an expect key nor a query
- [x] L29 situations["21.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L38 situations["21.2"].target: target — not a situation key in the vocabulary
- [x] L39 situations["21.2"].sicht: sicht — not a situation key in the vocabulary
- [x] L41 situations["21.2"].expect.range_band: range_band — neither an expect key nor a query
- [x] L50 situations["21.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L56 situations["21.3"].target: target — not a situation key in the vocabulary
- [x] L68 situations["21.4"].sicht: sicht — not a situation key in the vocabulary
- [x] L71 situations["21.4"].expect.fk.replaced_by: replaced_by — snake_case key, no mapping
- [x] L72 situations["21.4"].expect.outcomes: outcomes — neither an expect key nor a query
- [x] L78 situations["21.5"].mount: mount — not a situation key in the vocabulary
- [x] L81 situations["21.5"].expect.with_Kurzbogen: with_Kurzbogen — neither an expect key nor a query
- [x] L82 situations["21.5"].expect.with_Kurzbogen.fk.replaced_by: replaced_by — snake_case key, no mapping
- [x] L90 situations["21.6"].target: target — not a situation key in the vocabulary
- [x] L99 situations["21.6"].open: open — not a situation key in the vocabulary
- [x] L113 situations["21.8"].cases: cases — not a situation key in the vocabulary
- [x] L128 situations["21.8"].cases[5].expect.before_shot: before_shot — snake_case key, no mapping

## situations/probe-fertigkeiten.yaml

- [x] L26 situations["22.1"].check: check — not a situation key in the vocabulary
- [x] L29 situations["22.1"].expect.eew: eew — neither an expect key nor a query
- [x] L30 situations["22.1"].expect.fw: fw — neither an expect key nor a query
- [x] L42 situations["22.2"].check: check — not a situation key in the vocabulary
- [x] L45 situations["22.2"].expect.fw: fw — neither an expect key nor a query
- [x] L53 situations["22.3"].check: check — not a situation key in the vocabulary
- [x] L57 situations["22.3"].expect.eew: eew — neither an expect key nor a query
- [x] L58 situations["22.3"].expect.fw: fw — neither an expect key nor a query
- [x] L70 situations["22.4"].check: check — not a situation key in the vocabulary
- [x] L72 situations["22.4"].choose.reroll: reroll — not a fact in the vocabulary
- [x] L72 situations["22.4"].choose.result: result — not a fact in the vocabulary
- [x] L74 situations["22.4"].expect.before_reroll: before_reroll — neither an expect key nor a query
- [x] L75 situations["22.4"].expect.dice: dice — neither an expect key nor a query
- [x] L85 situations["22.5"].check: check — not a situation key in the vocabulary
- [x] L87 situations["22.5"].choose.reroll: reroll — not a fact in the vocabulary
- [x] L87 situations["22.5"].choose.result: result — not a fact in the vocabulary
- [x] L89 situations["22.5"].expect.dice: dice — neither an expect key nor a query
- [x] L92 situations["22.5"].expect.result: result — neither an expect key nor a query
- [x] L97 situations["22.6"].check: check — not a situation key in the vocabulary
- [x] L100 situations["22.6"].expect.result: result — neither an expect key nor a query
- [x] L106 situations["22.7"].check: check — not a situation key in the vocabulary
- [x] L108 situations["22.7"].choose.reroll: reroll — not a fact in the vocabulary
- [x] L108 situations["22.7"].choose.result: result — not a fact in the vocabulary
- [x] L110 situations["22.7"].expect.before_reroll: before_reroll — neither an expect key nor a query
- [x] L111 situations["22.7"].expect.dice: dice — neither an expect key nor a query
- [x] L115 situations["22.7"].expect.offered[0].together_with: together_with — snake_case key, no mapping
- [x] L122 situations["22.8"].check: check — not a situation key in the vocabulary
- [x] L125 situations["22.8"].expect.eew: eew — neither an expect key nor a query
- [x] L127 situations["22.8"].expect.result: result — neither an expect key nor a query
- [x] L130 situations["22.8"].expect.text: text — neither an expect key nor a query
- [x] L135 situations["22.9"].check: check — not a situation key in the vocabulary
- [x] L138 situations["22.9"].expect.eew: eew — neither an expect key nor a query
- [x] L139 situations["22.9"].expect.forbidden: forbidden — neither an expect key nor a query

## situations/probe-magie.yaml

- [x] L32 situations["20.1"].cast: cast — not a situation key in the vocabulary
- [x] L35 situations["20.1"].expect.check: check — neither an expect key nor a query
- [x] L36 situations["20.1"].expect.spell: spell — neither an expect key nor a query
- [x] L37 situations["20.1"].expect.charge: charge — neither an expect key nor a query
- [x] L45 situations["20.2"].cast: cast — not a situation key in the vocabulary
- [x] L47 situations["20.2"].expect.check: check — neither an expect key nor a query
- [x] L53 situations["20.2"].expect.spell: spell — neither an expect key nor a query
- [x] L54 situations["20.2"].expect.spell.cost.lines[0].from_rule: from_rule — snake_case key, no mapping
- [x] L55 situations["20.2"].expect.spell.castingTime.lines[0].from_rule: from_rule — snake_case key, no mapping
- [x] L56 situations["20.2"].expect.charge: charge — neither an expect key nor a query
- [x] L64 situations["20.3"].cast: cast — not a situation key in the vocabulary
- [x] L65 situations["20.3"].fail: fail — not a situation key in the vocabulary
- [x] L67 situations["20.3"].expect.check: check — neither an expect key nor a query
- [x] L73 situations["20.3"].expect.spell: spell — neither an expect key nor a query
- [x] L74 situations["20.3"].expect.charge: charge — neither an expect key nor a query
- [x] L79 situations["20.4"].cast: cast — not a situation key in the vocabulary
- [x] L79 situations["20.4"].cast.formel_weglassen: formel_weglassen — snake_case key, no mapping
- [x] L86 situations["20.4"].expect.check: check — neither an expect key nor a query
- [x] L87 situations["20.4"].expect.spell: spell — neither an expect key nor a query
- [x] L94 situations["20.5"].cast: cast — not a situation key in the vocabulary
- [x] L95 situations["20.5"].maintain: maintain — not a situation key in the vocabulary
- [x] L97 situations["20.5"].expect.check: check — neither an expect key nor a query
- [x] L98 situations["20.5"].expect.spell: spell — neither an expect key nor a query
- [x] L101 situations["20.5"].expect.charge: charge — neither an expect key nor a query
- [x] L112 situations["20.6"].cast: cast — not a situation key in the vocabulary
- [x] L114 situations["20.6"].expect.open: open — neither an expect key nor a query
- [x] L115 situations["20.6"].expect.check: check — neither an expect key nor a query
- [x] L116 situations["20.6"].expect.spell: spell — neither an expect key nor a query
- [x] L117 situations["20.6"].expect.charge: charge — neither an expect key nor a query
- [x] L125 situations["20.7"].cast: cast — not a situation key in the vocabulary
- [x] L126 situations["20.7"].choose.payWithLeP: payWithLeP — not a fact in the vocabulary
- [x] L129 situations["20.7"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L131 situations["20.7"].expect.charge: charge — neither an expect key nor a query
- [x] L134 situations["20.7"].expect.after: after — neither an expect key nor a query
- [x] L143 situations["20.8"].cast: cast — not a situation key in the vocabulary
- [x] L144 situations["20.8"].choose.payWithLeP: payWithLeP — not a fact in the vocabulary
- [x] L145 situations["20.8"].fail: fail — not a situation key in the vocabulary
- [x] L147 situations["20.8"].expect.cast: cast — neither an expect key nor a query
- [x] L148 situations["20.8"].expect.charge: charge — neither an expect key nor a query
- [x] L153 situations["20.8"].expect.after: after — neither an expect key nor a query

## situations/reichweite.yaml

- [x] L7 weapons: weapons — not a situations-file key in the vocabulary
- [x] L61 situations[RW.6].check: check — not a situation key in the vocabulary
- [x] L72 situations[RW.7].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L76 situations[RW.7].expect.on_miss: on_miss — neither an expect key nor a query
- [x] L83 situations[RW.8].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L92 situations[RW.9].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L116 situations[RW.12].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L132 situations[RW.13].expect.excludes: excludes — neither an expect key nor a query
- [x] L138 situations[RW.14].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [x] L138 situations[RW.14].choose.runUp: runUp — not a fact in the vocabulary
- [x] L150 situations[RW.15].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [x] L152 situations[RW.15].expect.not_combinable: not_combinable — neither an expect key nor a query
- [x] L153 situations[RW.15].expect.told: told — neither an expect key nor a query
- [x] L159 situations[RW.16].choose.manoeuvre: manoeuvre — not a fact in the vocabulary

## situations/reiterkampf.yaml

- [x] L5 mount: mount — not a situations-file key in the vocabulary
- [x] L51 situations["5.5"].choose.jumpOff: jumpOff — not a fact in the vocabulary
- [x] L55 situations["5.5"].expect.after: after — neither an expect key nor a query
- [x] L123 situations["5.10"].choose.order: order — not a fact in the vocabulary
- [x] L123 situations["5.10"].choose.gait: gait — not a fact in the vocabulary
- [x] L125 situations["5.10"].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L126 situations["5.10"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L128 situations["5.10"].expect.opponent_may_only: opponent_may_only — neither an expect key nor a query
- [x] L134 situations["5.11"].mount: mount — not a situation key in the vocabulary
- [x] L135 situations["5.11"].choose.order: order — not a fact in the vocabulary
- [x] L135 situations["5.11"].choose.gait: gait — not a fact in the vocabulary
- [x] L137 situations["5.11"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L144 situations["5.12"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L144 situations["5.12"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L147 situations["5.12"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L149 situations["5.12"].expect.on_miss: on_miss — neither an expect key nor a query
- [x] L151 situations["5.12"].expect.excludes: excludes — neither an expect key nor a query
- [x] L157 situations["5.13"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L157 situations["5.13"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L159 situations["5.13"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L165 situations["5.14"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L165 situations["5.14"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L168 situations["5.14"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L181 situations["5.16"].expect.not_selectable: not_selectable — neither an expect key nor a query
- [x] L189 situations["5.17"].expect.ini_belastung: ini_belastung — neither an expect key nor a query

## situations/schmerz.yaml

- [x] L15 situations[S1].expect.conditions: conditions — neither an expect key nor a query
- [x] L17 situations[S1].expect.talent: talent — neither an expect key nor a query
- [x] L18 situations[S1].expect.spell: spell — neither an expect key nor a query
- [x] L27 situations[S2].expect.conditions: conditions — neither an expect key nor a query
- [x] L36 situations[S3].expect.conditions: conditions — neither an expect key nor a query
- [x] L37 situations[S3].expect.requires_check: requires_check — neither an expect key nor a query
- [x] L38 situations[S3].expect.on_failure: on_failure — neither an expect key nor a query
- [x] L46 situations[S4].expect.conditions: conditions — neither an expect key nor a query
- [x] L66 situations[S6].expect.conditions: conditions — neither an expect key nor a query
- [x] L86 situations[S7].expect.states: states — neither an expect key nor a query
- [x] L111 situations[S9].expect.states: states — neither an expect key nor a query
- [x] L120 situations[S10].expect.states: states — neither an expect key nor a query
- [x] L126 situations[S11].checks: checks — not a situation key in the vocabulary
- [x] L128 situations[S11].expect.talent: talent — neither an expect key nor a query
- [x] L129 situations[S11].expect.spell: spell — neither an expect key nor a query
- [x] L135 situations[S12].passed: passed — not a situation key in the vocabulary

## situations/sturmangriff.yaml

- [x] L17 situations["10.1"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L25 situations["10.2"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L34 situations["10.3"].expect.not_combinable: not_combinable — neither an expect key nor a query
- [x] L39 situations["10.4"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L39 situations["10.4"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L42 situations["10.4"].expect.on_miss: on_miss — neither an expect key nor a query
- [x] L49 situations["10.5"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L49 situations["10.5"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L51 situations["10.5"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L60 situations["10.6"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L60 situations["10.6"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L62 situations["10.6"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L70 situations["10.7"].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [x] L70 situations["10.7"].choose.tier: tier — not a fact in the vocabulary
- [x] L70 situations["10.7"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L72 situations["10.7"].expect.combinable: combinable — neither an expect key nor a query
- [x] L83 situations["10.8"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L83 situations["10.8"].choose.runUp: runUp — not a fact in the vocabulary
- [x] L86 situations["10.8"].expect.on_hit: on_hit — neither an expect key nor a query

## situations/trefferzonen.yaml

- [x] L26 situations[TZ.2].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L35 situations[TZ.3].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L35 situations[TZ.3].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L45 situations[TZ.4].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L45 situations[TZ.4].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L57 situations[TZ.5].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L57 situations[TZ.5].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L62 situations[TZ.5].expect.tell: tell — neither an expect key nor a query
- [x] L69 situations[TZ.6].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L80 situations[TZ.7].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L91 situations[TZ.8].check: check — not a situation key in the vocabulary
- [x] L92 situations[TZ.8].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L92 situations[TZ.8].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L106 situations[TZ.9].expect.zone: zone — neither an expect key nor a query
- [x] L107 situations[TZ.9].expect.table: table — neither an expect key nor a query
- [x] L113 situations[TZ.10].attacker: attacker — not a situation key in the vocabulary
- [x] L116 situations[TZ.10].expect.table: table — neither an expect key nor a query
- [x] L117 situations[TZ.10].expect.zone: zone — neither an expect key nor a query
- [x] L124 situations[TZ.11].attacker: attacker — not a situation key in the vocabulary
- [x] L127 situations[TZ.11].expect.table: table — neither an expect key nor a query
- [x] L128 situations[TZ.11].expect.zone: zone — neither an expect key nor a query
- [x] L136 situations[TZ.12].hit: hit — not a situation key in the vocabulary
- [x] L138 situations[TZ.12].expect.checks_first: checks_first — neither an expect key nor a query
- [x] L142 situations[TZ.12].expect.on_failure: on_failure — neither an expect key nor a query
- [x] L149 situations[TZ.13].sequence[0].expect.checks_first: checks_first — snake_case key, no mapping
- [x] L152 situations[TZ.13].sequence[1].expect.checks_first: checks_first — snake_case key, no mapping
- [x] L154 situations[TZ.13].sequence[1].expect.on_failure: on_failure — snake_case key, no mapping
- [x] L161 situations[TZ.14].hit: hit — not a situation key in the vocabulary
- [x] L162 situations[TZ.14].fail: fail — not a situation key in the vocabulary
- [x] L164 situations[TZ.14].expect.loadout: loadout — neither an expect key nor a query
- [x] L165 situations[TZ.14].expect.log: log — neither an expect key nor a query
- [x] L166 situations[TZ.14].expect.asked: asked — neither an expect key nor a query
- [x] L175 situations[TZ.15].expect.after: after — neither an expect key nor a query
- [x] L184 situations[TZ.16].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L184 situations[TZ.16].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L196 situations[TZ.17].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [x] L196 situations[TZ.17].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L198 situations[TZ.17].expect.excludes: excludes — neither an expect key nor a query
- [x] L214 situations[TZ.27].choose.targetZone: targetZone — not a fact in the vocabulary
- [x] L229 situations[TZ.20].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [x] L230 situations[TZ.20].expect.score: score — neither an expect key nor a query
- [x] L231 situations[TZ.20].expect.conditions: conditions — neither an expect key nor a query
- [x] L240 situations[TZ.21].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [x] L241 situations[TZ.21].expect.score: score — neither an expect key nor a query
- [x] L242 situations[TZ.21].expect.conditions: conditions — neither an expect key nor a query
- [x] L251 situations[TZ.22].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [x] L252 situations[TZ.22].expect.score: score — neither an expect key nor a query
- [x] L253 situations[TZ.22].expect.conditions: conditions — neither an expect key nor a query
- [x] L265 situations[TZ.23].expect.score: score — neither an expect key nor a query
- [x] L266 situations[TZ.23].expect.conditions: conditions — neither an expect key nor a query
- [x] L276 situations[TZ.24].expect.not_selectable: not_selectable — neither an expect key nor a query
- [x] L276 situations[TZ.24].expect.not_selectable[0].second_armour: second_armour — snake_case key, no mapping
- [x] L292 situations[TZ.26].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [x] L293 situations[TZ.26].expect.score: score — neither an expect key nor a query
- [x] L294 situations[TZ.26].expect.conditions: conditions — neither an expect key nor a query

## situations/verweichlicht.yaml

- [x] L8 fokusregeln: fokusregeln — not a situations-file key in the vocabulary
- [x] L15 situations["13.1"].event: event — not a situation key in the vocabulary
- [x] L16 situations["13.1"].check: check — not a situation key in the vocabulary
- [x] L18 situations["13.1"].expect.check: check — neither an expect key nor a query
- [x] L28 situations["13.2"].event: event — not a situation key in the vocabulary
- [x] L29 situations["13.2"].check: check — not a situation key in the vocabulary
- [x] L31 situations["13.2"].expect.check: check — neither an expect key nor a query
- [x] L43 situations["13.3"].check: check — not a situation key in the vocabulary
- [x] L45 situations["13.3"].expect.check: check — neither an expect key nor a query
- [x] L53 situations["13.4"].fokusregeln: fokusregeln — not a situation key in the vocabulary
- [x] L54 situations["13.4"].event: event — not a situation key in the vocabulary
- [x] L56 situations["13.4"].expect.checks_asked: checks_asked — neither an expect key nor a query
- [x] L57 situations["13.4"].expect.hero_sheet: hero_sheet — neither an expect key nor a query
- [x] L65 situations["13.5"].check: check — not a situation key in the vocabulary
- [x] L67 situations["13.5"].expect.check: check — neither an expect key nor a query

## situations/wuchtschlag.yaml

- [x] L12 situations["9.1"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L12 situations["9.1"].choose.tier: tier — not a fact in the vocabulary
- [x] L15 situations["9.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L22 situations["9.2"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L22 situations["9.2"].choose.tier: tier — not a fact in the vocabulary
- [x] L25 situations["9.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L32 situations["9.3"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L32 situations["9.3"].choose.tier: tier — not a fact in the vocabulary
- [x] L35 situations["9.3"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L42 situations["9.4"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L42 situations["9.4"].choose.tier: tier — not a fact in the vocabulary
- [x] L45 situations["9.4"].expect.on_miss: on_miss — neither an expect key nor a query
- [x] L58 situations["9.6"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [x] L58 situations["9.6"].choose.tier: tier — not a fact in the vocabulary
- [x] L61 situations["9.6"].expect.on_hit: on_hit — neither an expect key nor a query
- [x] L75 situations["9.8"].expect.combinable: combinable — neither an expect key nor a query

## Expectation conflicts for the owner

- situations/boronmir-neu.yaml 19.12: expects no state gained on the failed check (`states: []`) beside the log entry. No expect key says "no event of this kind"; `events: [{ logged: … }]` checks the log only, so "no state" is a comment.
- situations/boronmir-neu.yaml 19.12 (reasoned anew in Task 31 fix round 1: the check now runs as its stated outcome): expects `events: [{ logged: "Autoritätsglaube: gibt der Schlechten Eigenschaft nach", from: DISADV_37.SE2 }]`. On the failed Willenskraft check the procedure logs SE2's `tell` at the confirm, "gibt der Schlechten Eigenschaft nach", from DISADV_37.SE2. The expected entry prefixes the Schlechte Eigenschaft's name ("Autoritätsglaube: "), which no rule composes: the names are SE6's display table (`readBy: display`), and SE2's text names none. The origin and the logged event match.
- situations/boronmir-sf.yaml 14.13: expects `pa(with: shield)` total −7, result 6, with a −6 line from SA_59.SS2 ("removes schilde.SCH3"). The base 13 (`pa(with: Großschild)`) folds in SCH3's doubled bonus; the rules give the shield parry as KW2's Schilde PA 7 plus SCH3's +6 line, and SS2 is a `suppress` of that line, which lands in notApplied (reason suppressed), not as a −6 line. Faithful to the rules: base 7, no SCH3 line, total −1, result 6.
- situations/boronmir-sf.yaml 14.17: expects `pa` result 11 and `pa(with: shield)` result 13 with only the P2 and B3 lines (total 0). The bases 11 and 13 fold in SCH1's +3 and SCH3's +6; the rules add those as lines (schilde.SCH1, schilde.SCH3), so the totals would be +3 and +6, with the same results.
- situations/boronmir-neu.yaml 19.2: the same as 14.17 for Formation's +2 VW: `pa` result 12 and `pa(with: shield)` result 14 with totals 1 come from folded bases 11 / 13; the rules give SCH1's +3 and SCH3's +6 as lines of their own.
- situations/kupperus-und-waffen.yaml 18.3: expects `not_asked: [{ gait: galopp, runUp: 4 }]` (a mount attack does not ask for gait or run-up). No expect key says "not asked" (`questions: []` would assert that nothing at all is asked); it is a comment.
- situations/kupperus-und-waffen.yaml 18.1: expects the mount's Niederreiten attack (AT 15, TP 2W6+6) `from: svellttaler-kaltblut.SK3, via: [reiterkampf.RK13]`, now an `events` entry. The rules make it RK13's `check` of the mount's Niederreiten line, whose values are SK3's provided data, so the event comes from RK13; the AT and TP are data, not lines.
- situations/kupperus-und-waffen.yaml 18.2: expects Niederreiten with an Elenviner Vollblut's AT 15 and TP 2W6+4. There is no profile file for that horse, so nothing states its attack lines (`mount.hasAttack`) or values; RK13's offer is unknown and the numbers cannot come from the rules.
- situations/kupperus-und-waffen.yaml 18.1, 18.3, 18.4: the `texts` entries keep the old structured tells (`{ opponent: { check: Kraftakt, on_failure: STATE_10 } }`, `{ mount: … }`, `{ order: not carried out, nothing worse }`). The rules' `tell`s are plain text to an audience (opponent or player): maechtiger-schlag.MS1/MS3 "Probe auf Kraftakt … Status Liegend (STATE_10)", reiterkampf.RK13's to the player, RK12's "Der Befehl wird nicht ausgeführt …". Matching them needs the owner to say whether a text expectation compares audience and source only.
- situations/kupperus-und-waffen.yaml 18.3: expects the mount-attack order offered `from: svellttaler-kaltblut.SK3, via: [reiterkampf.RK12]`. SK3's own offer carries it; the profile is owned (`creatures`), so no enabling `require` in RK12 could add a `via` (enabling only applies to a rule that does not apply otherwise). RK12 supplies the order's Aktion and Reiten check, which the offered entry does not show.
- situations/kupperus-und-waffen.yaml 18.4: expects `on_hit: { tp: none }` (the parried Tritt rolls no damage). No expect key says "no roll"; it is a comment.
- situations/kupperus-und-waffen.yaml 18.1: every `formula:` (a TP formula or a computation, e.g. "2 + 12/2", "1W6+4 +9", "−⌈(25 − 20)/2⌉") is a comment: no line or query key holds a formula. (Task 32: the two situations this entry named beside 18.1 pass: schaden.S3 with nothing above the Schadensschwelle gives no line and is `conditionFalse`, and the opponent's stated RS is the base of `opponent.rs`.)
- situations/trefferzonen.yaml TZ.9, TZ.10, TZ.11 (reasoned anew in Task 32 fix round 1, ruling R73): the expectation missing. The migration left no expect key for the zone and side a die gives (the old `zone: [{ roll, zone, side }]` and `table:` are comments), so each situation states dice and expects nothing; the harness gives it the shape "no expectation", never a pass. By the rule text (TZ3's table by the size gap, attacker against target, ruling relative-size-table; TZ4–TZ4b's rows; TZ4c's parity) each should give: TZ.9, a mittel hero against a mittel human, table humanoid.mittel (TZ4a): die 2 → kopf, die 13 → arme, links (odd); TZ.10, a klein goblin against the mittel hero, one size smaller, so the groß table (TZ4b): die 8 → arme, rechts (even); TZ.11, a klein goblin against a Zwerg (klein), equal sizes, so the mittel table (TZ4a): die 4 → torso. The owner must restore these expectations (a key for the zone and side a stated die gives). The engine does not resolve a zone from a die either (see "Open questions").
- situations/trefferzonen.yaml TZ.4, TZ.5, TZ.6: expect the eased aiming line `via: [STATE_13, …]`. The easing is trefferzonen.TZ5's own `replace` (the clause whose text says it), conditioned on `opponent.has: STATE_13`; a replaced line's `via` is the replacer, trefferzonen.TZ5, so STATE_13 appears as the fact the replace read, not as a rule in `via`. `via` names clauses; `STATE_13` is a rule. Task 32: this is the one remaining mismatch of the three. TZ.5's `texts` entry now matches (STATE_13.UE1's new `require … enables` lets the opponent's status reach the hero's attack, so UE1's tell `noDefence` shows), and the harness names a replaced line that a multiply then scaled with the value it had before either (`was: −4`, TZ.4).
- situations/trefferzonen.yaml TZ.12, TZ.13, TZ.14, boronmir-neu.yaml 19.8 (plan-mandated: A.4 puts the gain in TZ8's `onFailure`; the owner decides whether TZ8 or TZ11 is the origin): expect the Wundeffekt `from: trefferzonen.TZ11` (a `gained` STATE_10, an item let go, the 1W3+1 SP). Under A.4 the gain, the item change and the torso `tell` run in trefferzonen.TZ8's `check.onFailure`, reading TZ11's provided tables; their origin is TZ8. The 1W3+1 SP (TZ.12, 19.8: `damage: { formula: 1W3+1 }`) has no dice value form and is a `tell` to the player, not a damage event (see "Open questions"). Task 32 (R62) compares these events; every remaining mismatch: TZ.12: the `damage` event is missing (the engine logs TZ8's tell "Wundeffekt Torso: zusätzlich 1W3+1 SP."); the check and its −2 match. TZ.13: the `gained` STATE_10 comes from TZ8, the one mismatch. TZ.14: (a) the `itemChanged` is missing: TZ8's `item: { instance: { loadout: weapon } }` changes the instance in the weapon slot, and the file states the Schwert there but no instance of it, so the engine asks for `loadout.weapon.instance` and changes nothing (as reiterkampf 5.5); `hit.heldInHand` (`weapon`, from `loadout.weaponHand: rechts` and `hit.side: rechts`) and the one-handed Schwert (R61) are no longer the reason; (b) `questions: []` (the old `asked: []`, which meant that the hand is not asked; it is not) asserts that nothing at all is asked, but the hero states neither MU nor Selbstbeherrschung's FW, which the Wundeffekt check's Probe needs (`attr.MU`, `fw.TAL_8`), nor an armour, the LE basis or the mount, so the hit's stages and the check ask for them (`loadout.armour`, `species.le`, `hero.purchased.le`, `hero.mounted`, `gmFact.mountTakesSP`, `gmFact.checkModifier`; fix round 1 gated the `ask`s of regeneration R6/T1, fernkampf.FK8 and zaubermodifikationen.ZM11's check modifiers, which asked on every query); (c) the origin, as above. 19.8: besides the origin and the `damage` event, `check.modifier(talent: TAL_8)` is −2 against the expected −1 `via: [ADV_54.E1]`: E1's +1 rests on the open ruling ADV_54.eisern-scope, so it applies nothing and the Wundschwelle is 8 (⌊17 / 8⌋ = 2).
- situations/boronmir-neu.yaml 19.9: expects `wundschwelle` total 9 with `rulesets: []`. The Wundschwelle's derive (⌈KO/2⌉) is trefferzonen.TZ8's, and the whole file is `ruleset: fokus.trefferzonen`, so with the Fokusregel off only ADV_54's +1 remains. Pending on ADV_54's open ruling eisern-scope, which asks exactly this.
- situations/kampfwerte.yaml 16.20: expects `events: [{ gained: imSterben, from: schaden.S8 }]`. There is no rule `imSterben` and the Regel-Wiki has no page to draft one from; schaden.S8 now `tell`s the hero "Ab 0 Lebenspunkten liegt ein Held im Sterben."
- situations/lebensenergie.yaml 15.7 (Task 30; 15.4–15.6 and 15.8 now pass: a line of a rule whose level a useLevel changed carries that useLevel's rulings, the base line of `level(rule: COND_6)` included, and `hero.conditionLevels` is derived): expects COND_6.SZ2's Selbstbeherrschung check `offered` (`check`, `before: each_action`, no `choice`). An `offer` offers choices; SZ2's check is asked by the rules, not offered, and no expect key holds a check the player may make. The step after the passed check also expects `at` and `gs` at −3 while the hero keeps the Handlungsunfähig the top-level settle gained (gs 0, total −8: STATE_8.H2's set and, since Task 33 fix round 1, its bound; −11 before): that is the engine gap in "Open questions" (a gain is not withdrawn when its `when` stops holding), not this entry's.
- situations/kampfwerte.yaml 16.5 (Task 30): expects the shield parry's base `from: schilde.SCH3, via: [kampfwerte.KW2]` (value 7). The rules give that base as KW2's derive for the Schilde technique (`ktw.current` of the shield: 10 / 2 = 5, KK 14 → +2), from KW2; SCH3 offers the choice and adds the doubled bonus (+6) as its own line, which the entry expects too. A base from SCH3 would be a clause that computes no base. The result 13 and the weapon parry (11: base 8 from KW2, SCH1 +3) match.
- situations/kampfwerte.yaml 16.9 (Task 30): expects the shield parry against an arrow offered `from: schilde.SCH6`. SCH6 is a `none` clause since Task 16 (its `allow` is the default; "Reviews reset by hand edits": schilde.SCH6); the shield parry is offered by SCH3 (`choice: shieldParry`), with the result 13. The dodge (7) and the weapon parry refused by SCH8 match.
- situations/kampfwerte.yaml 16.12 (Task 30): the second step expects `ini: { result: 18, from: kampfwerte.KW11, kept: { w6: 4 } }`. The result matches (the step's `event: { COND_1: 0 }` is Belastung 0: 14 + 4). `from` and `kept` are no query keys: KW11 is a `none` clause ("built into KW10's encoding": the W6 is the stored `roll.ini` KW10's derive reads), so no line or base comes from it, and "the W6 is kept" is the fact `roll.ini` staying 4, which no expect key says.
- situations/kampfwerte.yaml 16.21 (Task 30): expects `pa(with: Peitschen)` `legal: false`. That Peitschen have no parry is out of scope in the rules (kampfwerte's header: "a `forbid: { defence: weaponParry }` for a Peitschen technique or equipment file, not written"; the Regelwerk's Peitschen page is not drafted), so nothing forbids the parry. The AT (KtW 10 from KW1, FF 11 → +1 from KW6) matches.
- situations/lebensenergie.yaml 15.2 (Task 30): expects `leMax` with one line `{ value: 35, from: lebensenergie.LE3 }` (5 + 2 × 15), and DISADV_28.NL1's −2 `via: [lebensenergie.LE3]`. 15.1 expects the same derive as two lines (5 and 30, one per `sum` term), which is how the engine shows a derive's parts; one line of 35 contradicts it. NL1 is an `add` to `leMax` that reads no target (as ADV_25.HL1, which 15.1 expects without a `via`), so nothing puts LE3 in its `via`. The total 33 matches.
- situations/lebensenergie.yaml 15.16: (a) expects the Körperbeherrschung check itself offered (`optional: true`, with FW and attributes) before any choice. `offer` offers choices only: STATE_10.L4 offers `choice.passierschlagVermeiden` beside the stand-up, and its `check` runs once the hero stands up with it chosen, so no check is offered. (b) expects ADV_75 not applied `because: "betrifft nur Betäubung und Berauscht"`, while 15.19 expects `because: "nur durch Alkohol verursacht"` for the same effects. An effect has one `because`; SW1's tells carry the alcohol one (15.19), and the hero without Betäubung or Berauscht fails the same `when` (`hero.has: COND_2 | COND_9`).
- situations/probe-fertigkeiten.yaml 22.4, 22.5, 22.7: expect the rerolled die `from: ADV_4.B2` (`dice: [{ die, rolled, counts, from: ADV_4.B2 }]`). Begabung is one `reroll` effect (plan A.4: `reroll: { die: { dice: any }, keep: better, max: 1, per: action }`), on ADV_4.B1, the clause that makes the offer (22.1 expects `offered: [{ reroll: ADV_4.B1 }]`, 22.6 `notOffered: [{ reroll: ADV_4.B1 }]`); B2's die choice and `keep: better` are that effect's payload, so B2 is `none`. The rerolled line's origin is ADV_4.B1. One effect cannot come from two clauses, so either these three or 22.1/22.6 disagree with the encoding; the owner decides which clause holds the reroll.
- situations/probe-fertigkeiten.yaml 22.7: expects the Schip reroll offered `from: ADV_4.B7`, `togetherWith: ADV_4.B1`. Real: B7 grants no reroll of its own (it only allows a Schip before or after the Begabung), and the Schip's Neuer Wurf is not written (schicksalspunkte says so in its header), so no effect offers it. Also plan-mandated by A.8 (`allow` → nothing), so B7 is `none`. The entry keeps its own `open:` note.
- situations/probe-fertigkeiten.yaml 22.7 (Task 34: every remaining mismatch; the two entries above name the first two): (a) the dice `from: ADV_4.B2` (the reroll is B1's); (b) the Schip reroll `offered … from: ADV_4.B7`, which nothing offers; (c) that expected offer's `togetherWith: ADV_4.B1` and `open: …` fields, which no offer models and which cannot be compared while the offer itself is missing (reported as unsupported shapes; R69 makes the verdict rest on (a), (b) and (d)); (d) the step's `check.fp` line `{ value: 0, from: fertigkeitsproben.FP5 }`. FP5 (Kodex des Schwertes p. 15, "Hast du Punkte übrig …") is the derive `check.fp = check.fw − check.spent`, and the engine shows a derive's `sum` terms as the base's parts: FW 8 (via FP3) and −8 (spent 0 + 5 + 3 after the reroll to 3). Their sum 0 and the step's total 1 (QS2's floor from 0 to 1, which matches) are right; one FP5 line of 0 is the shape lebensenergie 15.2 expects for LE3 (35), which is listed above against 15.1's per-term lines. 22.8's run shows FP5 the same way (4 and −5). The step's `dice` counts, `spent` [0, 5, 3] and `qs` 1 match.
- situations/probe-magie.yaml 20.7 (plan-mandated: A.6 puts the split on SA_74's `cost`, so the payment's origin is VP1): expects the 3 AsP `from: [zaubermodifikationen.ZM12, SA_74.VP1]`. One `paid` event has one origin. With LeP chosen, SA_74.VP1 suppresses ZM12's AsP-only cost and pays the whole cost with its own `split` cost, so the AsP come from VP1 and ZM12 is in `notApplied` (suppressed). The owner decides whether the expectation names VP1 alone, or whether a split cost should keep ZM12 as its origin (with VP1 in `via`), which no verb expresses.
- situations/probe-magie.yaml 20.8: expects the half cost `from: [SA_74.VP3, zaubermodifikationen.ZM12]`. VP3's `cost` ("wie sonst die Hälfte") is its own effect, and ZM12 is suppressed by VP1 once LeP are chosen, so the payments come from VP3 alone; ZM12 is the clause VP3's text points at, not an origin. A third option: ZM12 derives its failure-cost basis (half of the cost plus the first interval) into a target that VP3's `cost` reads, so that ZM12 joins the payment's `via` by ruling R26 (a value that reads a target operand carries the rules whose lines changed it); that would also close VP3's gap of paying half of `spell.cost` only.

- situations/probe-fernkampf.yaml 21.1, 21.2: expect the range band a distance gives (`range_band: { value: nah, from: fernkampf.FK4, ruling: fernkampf.range-input }`, `{ value: weit, from: fernkampf.FK4 }`). No expect key states a fact's value, and while ruling range-input is open the band is stated, not derived from the distance: the band is now input (`target.rangeBand`, with `target.distance` kept) and the expectation a comment. Only the `from: fernkampf.FK4` is lost: range-input stays cited, on 21.1's FK5 lines (FK and TP), which rest on it (FK5's adds read the band).
- situations/probe-fernkampf.yaml 21.1: `on_hit: { tp: { formula: "1W6+4 +1" } }`: the TP formula is a comment (as reiterkampf.yaml); the query `tp(with: Kurzbogen)` keeps its total and line.
- situations/probe-fernkampf.yaml 21.4, 21.5b: expect the FK `replaced_by: { result: "hit only on a 1" }` from fernkampf.FK9 / FK10. No verb sets a roll's result: the rules cap FK at 0 (`cap … max: 0`, a line of kind `capped`) and tell the player, so only a natural 1 hits; the other modifier lines still show (the old comment: "the modifier lines do not apply"). The expectation is a `capped` line from that clause plus a `texts` entry `{ result: "hit only on a 1", from }`; the two outcomes are `sequence` steps with `success`.
- situations/probe-fernkampf.yaml 21.6: the `sequence` steps expect `process: { zielen: 2 }`, `{ zielen: 4, capped: true }`, `{ zielen: ended }`. No expect key names a process's state; they are left as written for Task 28, which defines the steps (the `progressed` / `brokenOff` events and the progress `process.zielen`, whose bonus is 2 per step).
- situations/boronmir-sf.yaml 14.1, 14.6, 14.8, 14.16, 14.17, 14.19, 14.21, situations/boronmir-neu.yaml 19.1, 19.2, 19.4, situations/kampfsituationen.yaml 17.14 (Task 31): the `at` totals leave out the Großschild's "zusätzlich -1 AT auf die Hauptwaffe" (ITEMTPL_29.GR1, the Regelwerk's weapon table, p. 367). Boronmir carries the Großschild in every one of them, and GR1 is a core line of the item, on without any Fokusregel; kampfwerte 16.6, 16.7, 16.10 and kupperus-und-waffen 18.5, 18.9, 18.11 expect it. The files' headers derive the AT without it (boronmir-sf, boronmir-neu: "Rabenschnabel … AT 16"; kampfsituationen says it is "left out"). So each total is 1 lower than expected, and each result too: 14.1 0 (expected 1), 17 → 16; 14.6 −6 (−5); 14.8 −2 (−1); 14.16 −1 (0); 14.19 3 (4); 14.21 1 (2); 19.1 0 (1); 19.4 5 (4, see below); 14.17 and 19.2 −2 (−1); 17.14 −5 (−4). 19.4 also expects no SA_862.F2 line mounted: that rests on the open ruling formation-mounted (F1's forbid of the choice while mounted applies nothing, so the chosen formation's +2 stands), as does its `notOffered formation because SA_862.F1`; 19.1's offer of the formation (F1's offer) rests on it too.
- situations/boronmir-sf.yaml 14.16, 14.20, situations/boronmir-neu.yaml 19.1 (Task 31): expect `pa` total −1, result 10, from the base 11 (`pa(with: Rabenschnabel)`). The header derives 11 as "PA 8, with the Großschild's passive +3: 11", folding the Rabenschnabel's PA-Mod −1 into 8 and the passive shield bonus into 11. The rules give both as lines of their own after the base ("die Modifikatoren werden erst nach der Ermittlung der Basiswerte verrechnet", at-pa-modifikatoren.M1; schilde.SCH1's "+3"), and ruling R66 reads a base keyed by the item in hand as that base, with the weapon's lines on top: 11 − 1 + 3 − 1 (Belastung) = 12, total +1. The same fold as the listed 14.17 and 19.2.
- situations/kampfsituationen.yaml 17.10, 17.11, 17.14, 17.15, 17.16, 17.17, 17.18, 17.20 (Task 31): the file's sheet bases fold in what the rules add as lines. The header gives "shield parry ⌈10/2⌉ + 2 + 2×3 = 13" (`pa(with: Großschild)`: SCH3's doubled +6 folded), "Rabenschnabel … 7 + 2 − 1 = 8" (`pa(with: Rabenschnabel)`: M1's PA −1 folded), "shield AT 10 + 2 − 6 = 6" (`at(with: Großschild)`: M1's AT −6 folded), and states the Langschwert's weapon parry as 8 while its comments count from 11 (SCH1's +3 folded, "11 → 7"). The rules add schilde.SCH3 (+6), schilde.SCH1 (+3) and at-pa-modifikatoren.M1 (−1, −6) as lines after the base (M1: "erst nach der Ermittlung der Basiswerte"; ruling R66). So: 17.11 `pa(with: shield)` total +2 (expected −4), `pa(with: weapon)` −1 (−4); 17.14 `pa(with: weapon)` −1 (−4); 17.15 and 17.16 `pa(with: shield)` +2 (−4); 17.17 `at` −12 (−6); 17.18 `pa` −5 (−4); 17.20 `pa(with: shield)` +6 (0); 17.10 `pa(with: weapon)` −2 (−1). The results the comments give (17.11: 9 and 7; 17.17: 0; …) are the engine's too. Before Task 31 these were counted pending on reiterkampf.mounted-attack-side (RK5's first effect, live while `hero.mounted` was unstated); 17.11 now states it (R61), and the ruling explains none of these numbers.
- situations/reiterkampf.yaml 5.6, 5.8 (Task 31): expect `pa` totals 3 and 0 with the Rabenschnabel in hand, from the file's generic `pa: 8`. The Rabenschnabel's PA-Mod −1 (its row, ITEMTPL_19.RS0) is at-pa-modifikatoren.M1's line after the base, so the totals are 2 and −1. The file names no weapon values; nothing states that 8 is the Rabenschnabel's parry with its Mod folded in.
- situations/mehrfache-verteidigung.yaml V4, V5 (Task 31): expect MV1's −3 `via: [mehrfache-verteidigung.MV4]`. MV4 is a `none` clause ("says what round.defencesMade counts"); no effect comes from it, so no line can carry it in `via` (as kampfwerte 16.12's KW11). The −3 matches.
- situations/boronmir-sf.yaml 14.7, 14.12, situations/sturmangriff.yaml 10.7, situations/wuchtschlag.yaml 9.8 (Task 31): expect the combination `allowed: true, from: kampfsonderfertigkeiten.KS5`. KS5 is a `none` clause (the sum of KS3's and KS4's limits); an allowed combination has no refusing entry and no effect comes from KS5, so nothing can carry its clause. `allowed: true` matches (one Basis- and one Spezialmanöver pass KS3 and KS4).
- situations/finte.yaml 8.7, 8.8, situations/reichweite.yaml RW.15 (Task 31): expect `texts` entries such as "Finte lässt sich nicht mit Wuchtschlag kombinieren — nur ein Basismanöver pro Handlung". No rule tells this: it is the message the UI composes from the refusing entry's `because` and source (kampfsonderfertigkeiten.KS5's note and ruling manoeuvre-combination: "an excluded one stays visible, disabled, with that `because` and its source"), which each situation's `legal.combinations` already checks (and which passes: SA_62.ST4, KS3). Before Task 31 these counted pending on ladezeiten.laengere-handlungen, whose `*` tell explained any missing text.
- situations/kampfsituationen.yaml 17.22 (Task 31, was listed for the `raises` key, which is a comment): expects `texts: []` ("no defence restriction"). `[]` asserts that no `tell` is shown, but every query shows the `*` tell that holds: kampfsonderfertigkeiten.KS2's "passiv — wirkt immer" (regeneration.R7's tell is gated on the Regenerationsphase since fix round 1). The lines and total match.
- situations/kupperus-und-waffen.yaml 18.13 (Task 31): expects `texts: [{ order: opponent acts first, from: ITEMTPL_29.GR3 }]`. GR3's `tell` is plain text to the GM ("Gleiche INI: der Gegner des Großschildträgers schlägt zuerst zu."); `order` is no audience, as the structured tells of 18.1, 18.3 and 18.4.
- situations/boronmir-neu.yaml 19.10 (Task 31): expects the Willenskraft check `offered` with its cause and text. DISADV_37.SE1's check is asked by the rules, not offered (an `offer` offers choices; no expect key holds a check the player may make, as lebensenergie 15.7 and 15.16), and it rests on the open ruling schlechte-eigenschaft-check, so it is not asked either. The queries (`check.fw` 9, `check.modifier` 0, COND_1.B3 not applied) match.
- situations/kampfreflexe.yaml 12.3, 12.4 (Task 31): expect `ini` from KW10's derive, 14 (13) `via: [KW9, SA_51.KR1]`. The file's hero states the sheet value `ini: 12` (its comment: "INI Basiswert (MU+GE)/2 = 12"); a stated base is taken before any derive (plan Task 22, phase 1), so KW10 is overridden and the total is the Belastung lines alone (−3; −2). KW10 also adds the W6 `roll.ini`, which neither states. `iniBase` (14) matches.
- situations/kampfreflexe.yaml 12.5 (Task 31): expects `ini` to show reiterkampf.RK1's zero line (ruling rider-ini: the rider's Belastung does not reach the mount's base). RK1's `useLevel` sets Belastung's Stufe to 0, but 12.5 states no armour, so Belastung's Stufe is unknown (the engine asks for `loadout.armour`) and COND_1 does not apply; no source states that the hero wears none (R61). reiterkampf 5.17 and kupperus-und-waffen 18.15, which state the Plattenrüstung, get the line. `iniBase` (RK1 12 + KR1 2) matches.
- situations/reiterkampf.yaml 5.5 (Task 31, reasoned anew in fix round 1): expects `itemChanged: loadout.mount, change: { ridden: false }` from reiterkampf.RK6. Taking the jump off runs RK6's `item: { instance: { loadout: mount } }`, which changes the instance in the slot `mount`; the slot is now a vocabulary fact (`loadout.mount`, `loadout.mount.instance`), but the file states neither a mount in the loadout nor its instance (only `hero.mounted`; the header's "Kriegspferd" is the mount's kind), and a slot without a stated instance cannot be changed: the engine asks for `loadout.mount.instance` (ItemStateTests, Task 28). The offer and AW 0 match.
- situations/kupperus-und-waffen.yaml 18.1, 18.3 (Task 31 fix round 2: every remaining mismatch). Since fix round 2 the Reiten check's ruling (R71), the Kraftakt −3 (maechtiger-schlag.MS2 reads `mount.kk`), GK4's `via` SK7, the mount's Tritt (R72) and RK12's failure text match. What remains: (a) the Niederreiten attack is expected `from: SK3, via: [RK13]`; the engine's is RK13's check, via SK3's profile row (the 18.1 entry above); (b) 18.3's order is expected `via: [RK12]`, while SK3's own offer carries it (the 18.3 entry above); (c) the structured texts (RK13's `mount`, MS1's `opponent: { check, … }`, RK12's `order: not carried out`) against the rules' plain tells (the 18.1, 18.3, 18.4 entry above): RK12's tell "Der Befehl wird nicht ausgeführt; weitere Folgen hat das nicht." is now shown on the failed check; (d) unmodelled fields, which are comments: 18.1's `offered.requires: [SA_43.BK1]` (RK13's offer reads `hero.has: SA_43`; no offered key names a clause a condition rests on) and the paid events' `of: hero` and `instead_of: hero attack` (a payment's pool, `actions`, is the hero's; no event field says what it replaces).
- situations/schmerz.yaml S3 (Task 33): expects COND_6.SZ2's Selbstbeherrschung check `offered` (`{ check: { talent: Selbstbeherrschung, application: Handlungsfähigkeit bewahren }, before: each_action, from: COND_6.SZ2, ruling: COND_6.schmerz-iv-check }`, the old `requires_check`). The page (Regelwerk p. 34, Schmerz) says "Um trotz immenser Schmerzen (Stufe IV) handlungsfähig zu bleiben, ist eine Probe auf Selbstbeherrschung (Handlungsfähigkeit bewahren) nötig", and the decided ruling schmerz-iv-check has it rolled "before each action the hero wants to take": the check is required, not something the player may take or leave. The rules ask it (SZ2's `check` effect at Stufe IV); an `offer` offers choices, and SZ2 offers none, so no `offered` entry can come from it (as lebensenergie 15.7, which expects the same check, and 15.16, boronmir-neu 19.10). This is the one remaining mismatch: `level(rule: COND_6)` 4 (LeP 5 of 30: three quarters lost and "5 oder weniger"), `gs` 0 set by SZ5 with ruling schmerz-iv-gs, and the step's `gained` STATE_8 from SZ5 on the failed check match. Beside the shape: no action of the engine asks SZ2's check before it yet (the step states the check and its result), so an expectation rewritten as a check an action asks would need that timing in the action layer.

## Reviews reset by hand edits

- kampfwerte.KW1: the MU term is its own `derive` with `when: { not: { loadout.weapon.technique: Peitschen } }`, so KW6's FF term stands in for it; the KtW term stays unconditional
- kampfwerte.KW6: the `replace` of KW1's MU by FF is now its own `derive` term (FF above 8, per 3) for Peitschen; KW1's MU term carries `when: { not: { loadout.weapon.technique: Peitschen } }`
- kampfwerte.KW7: the pick-the-higher `choose` effect is dropped; the higher Leiteigenschaft is the loadout-resolved fact `technique.leit` that KW2 reads (clause now `none`)
- kampfwerte.KW11: the `recompute` effect is dropped; INI is KW10's `derive` over the stored W6 `roll.ini`, so its modifiers are live (clause now `none`)
- COND_1.B3: `level: [1, 3]` (a set: Stufe I or III) is now `[1, 2, 3]`; the talent-check conditions read `check.kind` and `check.hinderedByBelastung`, and the target is `check.modifier`
- COND_1.B4: `gain: { state: handlungsunfaehig, until: level-below-4 }` is now `gain: { rule: STATE_8 }`; the `until` has no span in the vocabulary and is carried by B4's `when`
- regeneration.R2: the offer's `outside: combat` is dropped (a comment: the Regenerieren sheet is not a combat screen)
- regeneration.R4: the `add … lines: [T1, ADV_44.VR1]` effect (a pointer, no value) is dropped; the roll is a `derive` over `roll.regeneration`
- regeneration.R6: new `suppress` of ADV_44's line and of T1's rows, with `because`, when regeneration fails in a storm or tied to a horse (a `set` applies before the `add`s, so it alone would keep them)
- regeneration.R7: the same `suppress` of ADV_44 and T1 while Vergiftet or Krank
- regeneration.T1: one multi-select `ask` with named lines is now one `ask` (a `choice.*` fact) and one `add` per row
- schilde.SCH1: "only the highest" moved from `max(loadout.other.paMod)` into how the loadout fact `loadout.other.paMod` is resolved (the highest PA-Mod among the Parierwaffen and shields carried); `with: mainHand` is `action.with: mainHand`
- schilde.SCH2: the offer is now `offer: { choice: action.with, options: [shield, parryingWeapon] }` when such a piece is carried; its `value: technique.at` is dropped (kampfwerte.KW1 gives it)
- schilde.SCH3: the offer is now `offer: { choice: action.defence, options: [shieldParry] }` when a shield is carried; its `value` is dropped (kampfwerte.KW2 with the Schilde KtW)
- schilde.SCH6: the `allow` (the default) and the one-shield `cap` are dropped; the loadout holds one shield (clause now `none`)
- waffeneigenschaften.WE2: the `gates` effect is dropped; the gate is the `when: { rulesets: fokus.waffeneigenschaften }` on each equipment effect (clause now `none`)
- ADV_44.VR1: the `when: { event: regeneration.R4, energy: le, regenerates: true }` is dropped; the target `regeneration.le` carries R4 and LeP, and "wenn er regeneriert" is regeneration.R6/R7's `suppress` of this line
- schicksalspunkte.SP-verteidigung: the offer's `before: defenceRoll` is dropped (a comment); the timing ("vor dem Würfeln der Verteidigung") is left to the check procedure, which offers it with the defence's breakdown before the dice
- kampfsonderfertigkeiten.KS2: the `apply: always` effect is dropped (every passive SF's lines apply without a choice, the engine's default for a rule with no `manoeuvre` key); the `show` is a `tell` to the player
- kampfsonderfertigkeiten.KS5: its effects are dropped (clause now `none`): the two pickers are each manoeuvre's own `choice.<name>` offer, "one of each" is KS3's and KS4's limits, and the exclusion message is each excluding rule's `forbid` with its `because`; the generic `forbid: { combination: this }` and its template `tell` are gone
- SA_40.A1: `situation: ambush` is now the player's toggle, an `offer` of `choice.hinterhaltUeberraschung` (default off) on a TAL_10 check, per the decided ruling aufmerksamkeit-when; the add reads it, and its target is `check.modifier`
- SA_66.V2: the forbid's `span: round` is dropped; the round is carried by `choice.vorstoss`, which V3 offers with `span: round`
- SA_59.SS1: the offer's `opponent_may_only: [shieldParry, aw]` is its own effect, `forbid: { what: { defence: [opponent.weaponParry] } }` with a `because`, when `choice.schildspalter`
- SA_59.SS3: `damage: { to: loadout.shield.structurePoints, not: le }` and its `then: destroy` are now an `item` change (StP lowered by `hit.tp`), a `suppress` of schaden.S1 (no LeP lost) and a second `item` change (`destroyed: true`) when `loadout.shield.structurePoints` is at most 0; "the defence failed" is `check.result: failure` (was `action.defence: failed`)
- SA_42.BH1: the `raise` of beidhaendiger-kampf.ZW3's line by 1 per Stufe is its own `add: { to: [at, pa, aw], value: level }` under ZW3's `when`; `max_total: 0` is dropped (Stufe II brings the sum to 0 and no Stufe goes higher)
- SA_48.F1: the one offer with `tiers: up_to_owned` is three offers of `choice.finte` (options 1…Stufe), each gated by `level`; the adds read `choice.finte` (was `action.manoeuvre: finte`) and count `per: choice.finte` (was `chosen_tier`); `opponent_add` is an `add` to `opponent.pa`/`opponent.aw`
- SA_67.W1: the same as SA_48.F1 for `choice.wuchtschlag`
- passierschlag.PS2: the offer is `offer: { choice: passierschlag }` (its `costs: none` and `domain: meleeAttack` are a comment) and the effects read `choice.passierschlag`; `opponent_may_only: []` is a `forbid` of `opponent.pa`/`opponent.aw`; the hero's side (`side: opponent`) is `gmFact.incomingAttack: passierschlag`, and its `then: { go_to: takeDamage }` is dropped (a comment)
- passierschlag.PS4: the `result: hit` on a 1 and `result: miss` on a 20 are dropped (the check procedure does that on every check); ruling passierschlag-dice moves onto the `forbid` of the critical and fumble checks
- passierschlag.PS5: the `limit: { …, max: none }` is dropped (clause now `none`): no limit is the default
- beidhaendiger-kampf.ZW1: the `dualWield` loadout forbids are `forbid: { what: { loadout: other } }` when `loadout.twoHanded`, or when either piece is a Kettenwaffe (CT_6) and the second is not a shield; the `allow` of Raufen is dropped (allowed is the default) and its ruling raufen-double-attack moves onto ZW2's offer
- beidhaendiger-kampf.ZW2: the offer is `offer: { choice: doubleAttack }` when a second piece is carried; its `costs: action` and `then: [attack mainHand, attack offHand]` are dropped (a comment)
- beidhaendiger-kampf.ZW3: the effect `id` and `lasts: round` are dropped; the round is carried by the round fact `round.doubleAttack`; SA_42.BH1 is an add of its own
- beidhaendiger-kampf.ZW4: `hand: off` is `action.with: offHand`; the effect `id` is dropped (ADV_5.V2 suppresses the clause)
- beidhaendiger-kampf.ZW8: `cancel: { attack: second }` is `forbid: { what: { attack: offHand } }` with a `because`, when `round.doubleAttack` and `roll.firstAttack: patzer` (was `action: doubleAttack, action.attack: first, result: patzer`)
- DISADV_37.SE1: the offer of a check is `check: { of: { talent: TAL_23 } }` when `gmFact.trigger: DISADV_37`; its `cause` and `application: null` are a comment (still on the open ruling schlechte-eigenschaft-check)
- DISADV_37.SE2: `on_failure: { log: … }` is a `tell` to the player when the Willenskraft check under the trigger fails (`check.result: failure`)
- DISADV_37.SE4: the `gm.modifier` offer is an `ask` of `gmFact.triggerModifier` (the GM) and an `add` of it to `check.modifier` on that check; its `default: 0` is a comment
- DISADV_37.SE6: `provides: { text_by_option: sid }` is `provide: { name: DISADV_37.eigenschaft, value: { sid: name } }`: the name, whose line of SE6's text is the trigger
- mehrfache-verteidigung.MV3: the `check: [pa, aw]` condition is dropped (no such fact); the forbid reads `query.result: { atMost: 0 }` and is limited to defence queries only by its `defence` selector's reach (pa, aw); `this_kind` is `[pa, aw]` per query
- reiterkampf.RK0: the header `applies_when: { hero.mounted: true }` is `hero.mounted: true` in every effect's `when` (RK1–RK15); RK0 stays `none`, its text now says so
- reiterkampf.RK1: `replace: { value: ini.base, with: mount.ini.base }` is a `suppress` of kampfwerte.KW9 and a `derive` of `iniBase` from `mount.iniBase`; ruling rider-ini is now an effect of its own, `useLevel: { rule: COND_1, as: 0 }` on the INI (`query.target: ini`), a zero-valued line
- reiterkampf.RK2: `grants: { rule: vorteilhafte-position }` is `require: { that, enables: true, for: { rule: vorteilhafte-position } }`; the condition (mounted, opponent on foot) is also in vorteilhafte-position.VP1's `when`
- reiterkampf.RK4: `forbid: { loadout: { twoHandedOnly: true } }` is `forbid: { what: { loadout: weapon } }` when `loadout.twoHanded`
- reiterkampf.RK5: `attack.from: weaponArmSide` is the GM's `gmFact.attackSide: weaponArm`; `open_ruling` is the effect's `ruling` (still open: applies nothing); new here: the mounted-from-behind `forbid` of the shield parry and `suppress` of schilde.SCH1 (moved from angriff-von-hinten.AH1, reading `gmFact.fromBehind`, ruling angriff-von-hinten.mounted-from-behind-shield)
- reiterkampf.RK6: `check: aw` is the target; the offer's `on: aw` is `query.target: aw`; its `then: { hero.mounted: false }` is an `item` change of the mount (`ridden: false`)
- reiterkampf.RK7: `lower: { condition: COND_1, by: 1, penalty_only }` is `useLevel: { rule: COND_1, lowerBy: 1, min: 0 }` for the queries of AT, PA, AW, FK and a Reiten (TAL_6) check modifier (`query.target`), so the Stufe itself is untouched
- reiterkampf.RK8: of the three occasions, only the change of gait keeps a check here; the mount hurt is RK10's check and an order RK12's (the old encoding asked for both twice)
- reiterkampf.RK9: `costs: { action: free, of: [hero, mount] }` is `cost: { pool: freeActions, amount: 1 }` on `action.gaitChange`; the mount's own free action is not counted
- reiterkampf.RK10: `event: mountTakesSP` is `gmFact.mountTakesSP` or RK11's `choice.mountHit`; the modifier reads `hit.sp` (was `mount.spTaken`); `on_failure: { rule: sturzschaden }` is a `tell` of the fall (core/sturzschaden newly drafted, all clauses unencoded); ruling passierschlag-on-mount cited on it
- reiterkampf.RK11: the offer's `then: { damage.to: mount }` is a `suppress` of schaden.S1 and a `tell` that the SP go to the mount's LE; `event: passierschlagSuffered` is `gmFact.incomingAttack: passierschlag`
- reiterkampf.RK12: `defines: { action: order, costs: action, requires_check }` is a `cost` of 1 from the new pool `actions` for every `choice.order`, and a Reiten (Kampfmanöver) `check` (a `tell` on failure) for the orders niederreiten, flucht and mountAttack; the Sturmangriff zu Pferd's check is RK14's
- reiterkampf.RK13: the offer is `offer: { choice: order, options: [niederreiten] }` with its requirements in `when` (`mount.hasAttack: Niederreiten` for the profile line); `attack` is a `check` of the mount's Niederreiten attack; `opponent_may_only: [aw]` a `forbid` of the opponent's parries; `after` a `tell`
- reiterkampf.RK14: the clause-level ruling two-sturmangriffe is on the effects; RK14 carries its own Reiten (Kampfmanöver) `check` (its text: "Nach der Probe auf Reiten …"); `opponent_may_only` is a `forbid` of the opponent's weapon parry; the `on_hit` TP "2 + mount.gs / 2" is `{ of: [mount.gs, 4], per: 2, round: up }`
- reiterkampf.RK15: the offer's `requires_check` is RK12's check plus an `add` of −1 per `gmFact.opponentsInReach` to the Reiten check; `on_success: { move }` is a `tell`
- vorteilhafte-position.VP1: the header `applies_when` (GM fact per attack, or granted by reiterkampf.RK2) is each effect's `when: { any: [gmFact.vorteilhaftePosition, mounted against a fighter on foot] }`; the `span: attack` is dropped (a GM fact is stated per attack); the effect `id` is dropped
- beengte-umgebung.BU2: the header `applies_when: { gm.fact: beengt, span: round }` is `gmFact.beengt: true` in each effect's `when`; the `span` is dropped
- beengte-umgebung.BU3: the same `gmFact.beengt`; the clause-level ruling beengt-shield-carried is on each effect
- angriff-von-hinten.AH1: `side` is carried by the targets; `attack.kind: melee` is `not: { gmFact.incomingAttack: ranged }` for the hero's defence and `loadout.weapon.kind: melee` for his attack; `span: attack` dropped; the two mounted-from-behind effects (the shield-parry forbid and the `exempt: { from: schilde.SCH1 }`, the old `from: reiterkampf.RK5`) moved to reiterkampf.RK5
- SA_661.GS1: `raise` of vorteilhafte-position.VP1's AT line by 2 is an `add` of its own under the mounted condition; the style condition is written out (`loadout.weapon` Rabenschnabel or Großschild); ruling passierschlag.passierschlag-sf is cited on it (kampfsituationen 17.3)
- SA_661.GS2: `loadout: { style: SA_661 }` is written out as `loadout.weapon` Rabenschnabel or Großschild
- SA_661.GS3: the `define` of the style condition is gone (clause now `none`): GS1 and GS2 carry it
- SA_172.U1: `lower: { line: reichweite.RW3.at, by_steps: 1, per: tier, min: 0 }` is two `replace`s of reichweite.RW3 (Stufe I: the steps above 1, Stufe II: above 2, at −2 each); reads `choice.unterlaufen` (was `action.manoeuvre`)
- SA_172.U2: the offer is `offer: { choice: unterlaufen, span: action }` (was `span: attack`); its `requires` is `require … for: { choice: unterlaufen }` on `reach.gap`; the tell reads `choice.unterlaufen`
- maechtiger-schlag.MS1: `creature.attack: success` is the mount's attack on the rider's order that hit (`choice.order: [mountAttack, niederreiten]`, `action.attack: hit`); the structured `tell` is a text to the opponent
- maechtiger-schlag.MS2: `opponent_add` to `{ check: Kraftakt }` is an `add` to `opponent.check.modifier` when the opponent's check is Kraftakt (`opponent.check.talent: TAL_5`) after the mount's attack hit (`choice.order: [mountAttack, niederreiten]`, `action.attack: hit`; the old had no attack condition); the value is `{ of: creature.kk, above: 20, per: 2, times: -1, round: up }`; ruling round-up cited on it
- maechtiger-schlag.MS3: gated on the mount's attack (`choice.order: [mountAttack, niederreiten]`); `cancels: MS1` is a `suppress` of MS1 when `opponent.defence: aw` and `opponent.defenceResult: success` (was `action.defence: success`); the structured `tell` is a text
- ruhiges-temperament.RT1: `mount.has: ruhiges-temperament` is dropped from `when` (the rule applies when the mount has it: svellttaler-kaltblut.SK5 enables it); `check: { talent: Reiten }` is `check.talent: TAL_6`, the target `check.modifier`
- svellttaler-kaltblut.SK3: the offer `{ order: mount_attack, attacks, via: reiterkampf.RK12 }` is `offer: { choice: order, options: [mountAttack] }`, an offer of `choice.mountAttack` (Tritt, Biss) and a `check` of that attack; RK12 carries the Aktion and the Reiten check
- svellttaler-kaltblut.SK5: `grants: { rules: [ruhiges-temperament, maechtiger-schlag] }` is one `require … enables: true, for: { rule: … }` per rule
- svellttaler-kaltblut.SK10: `add … per: threshold_crossed` over `mount.lep: { at_most: [49, 33, 16, 5] }` is four `add`s of 1 to `mount.level(rule: COND_6)`, one per threshold of `mount.leCurrent`

- groessenkategorie.GK4: new effect: the opponent may not parry the mount's own attacks (`choice.order: [mountAttack, niederreiten]`) with a weapon when `mount.size: gross` (ruling mounted-size: the mount's attacks come from a groß being); the old encoding had only the hero's defence

- schaden.S1: the TP roll effect is dropped (the combat procedure's consequence stage, spec §6); the SP are `derive: { to: sp, sum: [hit.tp, −rs] }` plus `floor: { to: sp, min: 0 }` (A.5) without the `event: heroHit` condition; the LeP loss moved to S2
- schaden.S2: was `none`; now holds the LeP loss `add: { to: leCurrent, value: −sp }` (the old third effect of S1), so reiterkampf.RK11 and SA_59.SS3 can suppress it without the SP
- schaden.S3: `max(0, leit − weapon.schadensschwelle)` is a proportion `{ of: technique.leit, above: loadout.weapon.schadensschwelle }` (a fact as `above`)
- schaden.S4: `replace: { value: "S3.leit", with: weapon.leit }` is a `replace` of S3's line computed with `loadout.weapon.leit`, when `loadout.weapon.ownLeit`
- schaden.S5: the offer's `on: heroHit` is dropped; its `then` is a `set: { to: sp, value: hit.tp }` when `choice.ignoresRS`
- schaden.S8: `gain: { rule: imSterben }` is a `tell` to the player (no Sterben rule exists or can be drafted from the wiki); `le.current ≤ 0` is `hero.leCurrent: { atMost: 0 }`
- reiterkampf.RK11: the `suppress` names both schaden.S1 (the rider's SP) and schaden.S2 (his LeP loss, split from S1); the mount's SP are the stated roll fact `hit.mountSp`
- reiterkampf.RK10: the check's modifier reads `hit.mountSp` (the mount's SP, stated) instead of `hit.sp` (the rider's SP)
- ruestung-und-belastung.A1: new `forbid: { what: { loadout: secondArmour } }` with a `because`, on the decided ruling several-armour-pieces (one armour at a time); belastung 6.1 and trefferzonen TZ.24 expect it
- trefferzonen.TZ2: the 1W20 `roll` on TZ3's table is `ask: { fact: hit.zone, who: roll }` when no zone is announced (`choice.targetZone: none`); the lookup is the app's roll layer; `event: hitLanded` is dropped
- trefferzonen.TZ3: `table_for` is a `provide` of the table size by the size gap (target − attacker); the clamping to the body plan's tables is a comment
- trefferzonen.TZ4c: `sets: { hit.side }` is a `provide` of the parity table; `hit.side` is a roll fact the app states
- trefferzonen.TZ4j: new `forbid` of `choice.targetZone` against a body plan without zones (was a comment; TZ.18 expects it `because: trefferzonen.TZ4j`)
- trefferzonen.TZ5: the offer is `offer: { choice: targetZone, default: none }` on `query.target: [at, fk]` (its `zones: target.zones` a comment); the aim reads `table(trefferzonen.TZ6, choice.targetZone)` when a zone is announced (the effect id `TZ5.aim` is gone); the surprise easing `raise … by: 2, max: 0, before:` is a `replace` of TZ5's line by the provided eased table (`trefferzonen.TZ5.eased`, TZ6 + 2), on `opponent.has: STATE_13` (was `opponent.state: ueberrascht`), ordered before the halving by phase; `replaces` is a `suppress` of groessenkategorie.GK3 and fernkampf.FK6 (was the undrafted `fernkampf.zielgroesse`), with `because`
- trefferzonen.TZ8: new `derive` of the Wundschwelle (⌈KO/2⌉, A.1); `requires_check`/`on_failure` is a `check` of TAL_8 (A.4), fired by `hit.overWundschwelle ≥ 1` (a derived count, was `hit.sp ≥ hero.wundschwelle`; `event: hitTaken` dropped); on failure a `gain` of `table(trefferzonen.TZ11.effect, hit.zone)` (Kopf, Beine), an `item` change `held: false` of the weapon or other piece in the hit hand (Arme, via `hit.heldInHand`, not two-handed, not a shield), and a `tell` of Torso's 1W3+1 SP
- trefferzonen.TZ11: the `table` is two `provide`s, `trefferzonen.TZ11.application` and `trefferzonen.TZ11.effect` (Kopf COND_2, Beine STATE_10); the Arme drop and the Torso damage are TZ8's; ruling wundeffekt-arm-drop moved onto TZ8's item effects
- trefferzonen-ruestungsschutz.RS1: was `none`; now the header `requires_ruleset` as `require: { that: { rulesets: fokus.trefferzonen } }` (ruling requires-trefferzonen, whose `appliesTo` is now RS1)
- trefferzonen-ruestungsschutz.RS2: `set: { value: hit.rs, to: armour.rs(hit.zone) }` on `event: hitTaken` is `set: { to: rs, value: hit.zoneRs }` (the RS of the zone and side hit), no event condition
- trefferzonen-ruestungsschutz.RS3: the loadout counts are `forbid: { what: { loadout: [secondArmour, secondHelmet, secondPieceInZone] } }` with a `because`
- trefferzonen-ruestungsschutz.RS4: the header `replaces: [ruestung-und-belastung.A1]` is a `suppress` of A1 here; the score is a `derive` of the new target `armourScore`; BE is a `derive` of `level(rule: COND_1)` and the extra an `add` to GS/INI, each a `table(…, armourScore)` lookup in the provided band tables (up to 141–154; the page's "usw." has no rows)
- SA_160.GA1: the offer is `offer: { choice: gezielterAngriff }` on `query.target: at`; its `requires: { choice: targetZone }` is a `require … for: { choice: gezielterAngriff }` that a zone is announced; the halving reads `choice.gezielterAngriff` (was `action.manoeuvre`) and is `multiply: { to: at, by: 0.5, line: { line: trefferzonen.TZ5 } }` (was the effect id `TZ5.aim`)
- STATE_13.UE1: `opponent.state`/`hero.state: ueberrascht` are `opponent.has`/`hero.has: STATE_13`, `check: [at, fk]` is `query.target`; the forbid's `until: surpriseActionResolved` is a new `gain: { rule: STATE_13, levels: -1 }` when `round.phase: start` (the regular round begins), with a `because` on the forbid

- COND_6 (header): the `level:` block (`from`, `set_by`, `effects_lowered_by`) is a comment; SZ3 derives the Stufe, a sheet-stated Stufe is the rule's owned level
- COND_6.SZ2: `requires_check`/`on_failure`/`on_success` are a `check` of Selbstbeherrschung (TAL_8, Handlungsfähigkeit bewahren) at Stufe IV (A.4); `on_failure: gain handlungsunfaehig` is dropped (SZ5's gain holds until a pass), `on_success` is `gain: { rule: STATE_8, levels: -1, span: action }` (lifted for that one action); `before: action` is dropped (the check procedure's timing, ruling schmerz-iv-check)
- COND_6.SZ3: `sets: … count(lp <= le*3/4, …, lp <= 5)` is one `derive` of `level(rule: COND_6)` with two proportions: ⌊4 × (LE − LeP) / LE⌋ at most 3 (the quarters of LE lost, exact) and max(0, 6 − LeP) at most 1 (LeP ≤ 5); checked against the exact count for LE 1–120
- COND_6.SZ5: `level: [1, 3]` (Stufe I or III) is now `[1, 2, 3]`; the target `check` is `[at, pa, aw, fk, check.modifier]`; the gain of `handlungsunfaehig` is `gain: { rule: STATE_8 }` without the `unless: { check_passed: SZ2 }` (SZ2's `onSuccess` lifts it); `check_passed: SZ2` is `check.talent: TAL_8, check.application: Handlungsfähigkeit bewahren, check.result: success`; `level: 4` is `atLeast: 4`
- zustaende.Z3: `cap: { lines: { kind: condition }, on: [check, gs, ini] }` is `cap: { to: [at, pa, aw, fk, check.modifier, gs, ini], over: { ruleKind: condition }, min: -5 }` (`check` spelled out as the check targets)
- zustaende.Z5: `sum: { condition_levels: all }, min: 8` is the new derived fact `hero.conditionLevels: { atLeast: 8 }` (the Stufen the hero has, before any `useLevel`); `gain: { rule: handlungsunfaehig }` is `gain: { rule: STATE_8 }`; ruling ADV_49.zaeher-hund-counts is now on the effect
- ADV_49.ZH1: `condition: COND_6, level: [2, 3]` is `hero.levelOf.COND_6: [2, 3]` (the Stufe the hero has); `useLevel` names the rule COND_6 (was the clause COND_6.SZ5); `keeps: { condition_level: level }` is dropped (it is what `useLevel` means); new second effect: at Stufe IV with COND_6.SZ2's check passed, `as: "level - 1"` on ruling zaeher-hund-iv (moved from ZH3's `useLevel … as: 3`: the −4 and GS 0 are effects of the highest Stufe, which ZH1 ignores)
- ADV_49.ZH3: the `keep: { rule: COND_6.SZ5, level: 4, part: handlungsunfaehig }` is `useLevel: { rule: COND_6, as: level }` when `hero.levelOf.COND_6: 4` (A.2), after ZH1 in clause order; the passed-check `useLevel … as: 3` moved to ZH1 (above). Rests on useLevels chaining in clause order (`as: level` read at the Stufe ZH1 leaves) and on a keep's `levelAs` line counting in `via`
- ADV_49.ZH4: `condition: COND_6, level: 1` is `hero.levelOf.COND_6: 1`; `useLevel` names the rule COND_6
- ADV_75.SW1: `scale: { duration: COND_2.decay | COND_9.decay, by: 0.5 }` is a `tell` of the halved duration (with `because: nur durch Alkohol verursacht`, lebensenergie 15.19) plus a `suppress` of COND_2.BT2's / COND_9.BR4's decay text, with `because`; `condition`/`cause: alcohol` are `hero.has: COND_2 | COND_9` and `gmFact.cause: alcohol`
- STATE_10.L2: `side: hero` / `side: opponent` are `hero.has: STATE_10` / `opponent.has: STATE_10` (the old `applies_to_side`), as STATE_13
- STATE_10.L3: the same `side` → `hero.has` / `opponent.has` re-keying
- STATE_10.L4: the offer `{ action: aufstehen, costs: action, then: remove_state, if_opponent_in_reach: optional_check … }` is `offer: { choice: aufstehen, costs: [1 action] }`, a `gain: { rule: STATE_10, levels: -1 }` on `choice.aufstehen`, and with `opponent.inReach` an `offer: { choice: passierschlagVermeiden }` beside it; standing up with it chosen runs a `check` of Körperbeherrschung (TAL_4, Kampfmanöver) whose `onFailure` tells the opponent `passierschlag`, and standing up without it tells it as well
- STATE_8.H3: was `none`; now `ask: { fact: choice.liegend, who: player }` and, on "ja", `gain: { rule: STATE_10 }`, both on ruling STATE_10.handlungsunfaehig-liegend (liegend 7.4, 7.5 expect the question)

- fertigkeitsproben.FP1: `defines: { check: skill, dice: 3W20, against, stages }` is `none` (the procedure itself, spec §6; plan A.4)
- fertigkeitsproben.FP2: `forbid: { check: skill, when: { any: "stage.attributes[i] <= 0" } }` is `forbid: { what: { check: [talent, spell, liturgy] } }` when `query.target: check.attribute, query.result: { atMost: 0 }` (each Teilprobe's value at 0 or below)
- fertigkeitsproben.FP3: `defines: { stage: pool, start: skill.fw, spend_per_die }` is `derive: { to: check.fw, sum: [{ of: fw.current }] }` (the pool's base, new derived fact `fw.current`); the spend per die is the procedure's (summed in the new derived fact `check.spent`)
- fertigkeitsproben.FP5: `defines: { stage: result, success: "stage.pool >= 0", fp: "stage.pool" }` is `derive: { to: check.fp, sum: [check.fw, −check.spent] }`; success (FP ≥ 0) is the procedure's `check.result`
- fertigkeitsproben.FP8: `defines: { check.application: { of: talent, list, required: true } }` is `ask: { fact: check.application, who: player }` on a talent check (`check.kind: talent`), ruling SA_9.spezialisierung-when kept; the option list is a comment (the talent's Optolith `applications`)
- fertigkeitsproben.QS1: `table: { stage: quality, from: stage.result.fp, rows }` is `provide: { name: fertigkeitsproben.qs, value: rows }` and `derive: { to: check.qs, sum: ["table(fertigkeitsproben.qs, check.fp)"] }` when `check.result: success` (no QS on a failure)
- fertigkeitsproben.QS2: `set: { stage: result.fp, value: 1, when: { success: true, fp: 0 } }` is `floor: { to: check.fp, min: 1 }` when `check.result: success`; it also lifts a Doppel-1's negative FP to 1 (crit-qs options a and b)
- fertigkeitsproben.FM1: `defines: { target: check, applies_to: stage.attributes, spread: all_three }` is `none` (the procedure itself: each `check.attribute(index: i)` is the attribute plus the one `check.modifier` breakdown; plan A.4)
- fertigkeitsproben.FM2: `offer: { gm.modifier: { on: check, presets: FM2 } }` is `ask: { fact: gmFact.checkModifier, who: gm, options: [5, 3, 1, 0, -1, -3, -5] }` on a 3W20 check and two `add`s to `check.modifier` (above 0: `of` the fact; below 0: `of: 0, above: <fact>, times: -1`, since a proportion clamps at 0)
- fertigkeitsproben.KR1: the `set: { stage: result, success: true, kind: kritischerErfolg }` is dropped (the procedure counts Doppel-1 from the faces, spec §6); the `provide: { name: text, value: skill.critical }` with ruling crit-qs moved to the talent's rule (TAL_7.critical, which carries crit-qs on its FP); new `tell` to the GM ("Doppel-1 … entscheidet der Meister") on `check.ones: { atLeast: 2 }`
- fertigkeitsproben.KR2: the `set: { stage: result, kind: dreifach1 }` is dropped (the procedure's); new `tell` to the GM on `check.ones: { atLeast: 3 }`
- fertigkeitsproben.PZ1: the two `set`s of the result (patzer, dreifach20) are dropped (the procedure's, `check.twenties`); the `provide: { name: text, value: skill.botch }` moved to the talent's rule (TAL_7.patzer); new `tell` to the GM on `check.twenties: { atLeast: 3 }` (Dreifach-20)
- ADV_4.B1: `offer: { reroll: { dice: 1, of: check.rolls }, when: { check: { skill: option.sid } }, once_per: check, after: rolled, before: result }` is `reroll: { die: { dice: any }, keep: better, max: 1, per: action }` (plan A.4) when the new derived fact `check.onOption` (the check is on the instance's `sid`); `after`/`before` are the procedure's dice stage
- ADV_4.B2: `choose: { die: player, from: check.rolls }` + `keep: better` is `none`, carried by B1's reroll (`dice: any`, `keep: better`)
- ADV_4.B5: `forbid: { offer: B1, when: { check.result: [patzer] } }` is `forbid: { what: { line: ADV_4.B1 } }` when the new roll fact `check.twenties: { atLeast: 2 }` (Doppel-20 or Dreifach-20)
- ADV_4.B7: `allow: { together: [B1, schicksalspunkte.neuer-wurf], order: any }` is `none` (plan A.8: allowed is the default; the procedure offers every open reroll in either order)
- SA_9.FS1: `add: { to: fw }` is `add: { to: check.fw }` (plan A.4); the gate `check: { talent: option.sid, application: option.sid2 }` is the new derived facts `check.onOption` and `check.applicationOnOption` (the check's Anwendungsgebiet is the instance's `sid2`)

- zaubermodifikationen.ZM1: `offer: { pickers, per: cast, before: check }` is `offer: { choice: spellModification, options: [7 modifications] }` on a spell check; the one `limit` (max `floor(spell.fw / 4)`, ruling omit-counts) is two: over the five parameter modifications with no ruling, and over all seven with ruling omit-counts; `max` is the value `{ of: fw.current, per: 4, round: down }` (limit's `max` now takes a value)
- zaubermodifikationen.ZM2: `limit: { category: [kosten, zauberdauer, reichweite], max_steps: 1 }` is one limit of 1 per category over the modifications that move it (Erzwingen + Kosten senken; Zauberdauer erhöhen + senken), with `because`; Reichweite's one modification is left to ZM6
- zaubermodifikationen.ZM5: the `derive` of the upkeep from `spell.cost.base` is `derive` + `add … scale: zaubermodifikationen.kosten` (−1) + `floor` (min 1, the old `cap … min`) on the new target `spell.costPerInterval`, all on `spell.duration: aufrechterhaltend`; it now reads the cost after the modifications (target `spell.cost`); the `charge … every: spell.interval, while: maintained` is `cost { every: { minutes: spell.interval } }` on `spell.maintained: true`
- zaubermodifikationen.ZM6: `limit: { choice: spellModification, each: 1 }` is seven limits, one per modification, max 1 per action, with `because`
- zaubermodifikationen.ZM8: the provides are named `zaubermodifikationen.zauberdauer | reichweite | kosten` (were `tables.*`), and ruling cost-off-table moved off all three onto ZM11's two cost steps, so the scales apply while it is open
- zaubermodifikationen.ZM11: each `shift` + `add` is two effects: `add` to `check.modifier` (was `check`) and `add … scale` on `spell.cost` / `spell.range` / `spell.castingTime`; the two cost steps carry ruling cost-off-table; the omission's `per: choice` is one −2 effect per omission; the `forbid … when: { spell.forbids: that }` is one forbid per modification on the new spell facts `spell.forbidsErzwingen` / `spell.forbidsKostenSenken`
- zaubermodifikationen.ZM12: `on_success` / `on_failure` + `charge` are two `cost`s on `check.kind: spell` and `check.result: success | failure`; the failure's `half(base + perInterval)` rounded up is `amount: { of: [spell.cost, spell.costPerInterval] }, onFailure: 0.5`
- SA_74.VP1: the offer `payWithLeP` with an `amount` range is `offer: { choice: split.le }` (the split fact of plan Task 25); the forbid reads the new derived fact `hero.aspCurrent`; the `split` is `cost { split: { pools: [asp, le], min: { asp: 1 } } }` on a successful spell check with LeP chosen; new `suppress` of zaubermodifikationen.ZM12 when LeP are chosen, so the cost is paid once
- SA_74.VP2: `requires_check` + `on_failure: { set: { cast.outcome: failed } }` is `check: { of: { talent: TAL_8 } }` whose `onFailure` forbids the spell check (`forbid: { what: { check: [spell] } }`, as fertigkeitsproben.FP2), on `choice.split.le: { atLeast: 1 }`
- SA_74.VP3: `charge { pools: [asp, le], half, round: up }` on `check_failed: VP2` is `cost { onFailure: 0.5, fallThrough: [le] }` on a failed spell check with LeP chosen; it now also rests on vp-sequence (whether a spell check that failed on its own pays this way)

- fernkampf.FK2: the forbid reads the band `target.rangeBand: ausserReichweite` (FK4's table), not `target.distance above farRange × 1.5` (a comparison takes constants); the selector is `{ attack: ranged }`; it rests on ruling range-input (it reads the band, whose source that ruling decides)
- fernkampf.FK4: the band table is `provide: { name: fernkampf.FK4 }` with a fifth band `ausserReichweite`, the weapon ranges `loadout.weapon.closeRange | mediumRange | farRange`; the untargeted shot forbids the choices `zielen`, `targetZone` and `gezielterSchuss` (was `zielen, aimedAttack`)
- fernkampf.FK5: the table is two provides (`fernkampf.FK5.fk`, `.tp`) read by `table(…, target.rangeBand)`; both adds apply on the bands nah / mittel / weit only, and the TP add only with a ranged weapon in hand (`loadout.weapon.kind: ranged`); both adds rest on ruling range-input
- fernkampf.FK6: the add reads `table(fernkampf.FK6, target.size)` (was `target.size_for_fk`); cover is FK8's `replace` of this line
- fernkampf.FK7: both tables are provides; the opponent's Haken halving is `multiply: { to: opponent.gs, by: 0.5, round: up }` (was `set … opponent.gs / 2` with `side: opponent`); the archer's movement is `hero.lastMovement` (was `hero.movement.lastAction`)
- fernkampf.FK8: the cover is asked (`ask: { fact: target.cover, who: gm }`, was an `offer`); the `set` of `target.size_for_fk` by `cover_size(…)` is a `replace` of FK6's line by `table(fernkampf.FK6, target.sizeInCover)`, a new GM fact for the size behind the cover (both on ruling cover-as-size)
- fernkampf.FK9: the table is a provide read by `gmFact.sicht` (was `sicht`), on Stufe 0–3; Stufe 4's `result: { hit: roll == 1, else: miss }` is `cap: { to: fk, max: 0 }` and a `tell`
- fernkampf.FK10: the gait is `action.gait` (was `mount.gait`); the trot's `result` is `cap … max: 0` and a `tell`, as FK9; the Langbogen forbid is `when: { hero.mounted, loadout.weapon: Langbogen }` (the weapon by name, as SA_661 and the situations state it; was the template id ITEMTPL_65), `forbid: { what: { attack: ranged } }`
- fernkampf.FK11: new `offer: { choice: zielen }` costing an Aktion (was the process's `step`); the process is `steps: 2`, `advancedBy: { action: zielen }`, broken off by the shot (`action.attack: [hit, miss]` with a ranged weapon), with ruling zielen-interrupted on the effect; the bonus is `add: { to: fk, value: 2, per: process.zielen }` (was `accumulates … cap: 4`, `ends`, `span: untilShot`)
- fernkampf.FK13: `requires_check` / `on_success` / `on_failure` is `check: { of: { check: confirm, with: fk } }` with nested multiplies on `opponent.pa` / `opponent.aw` (½, round up) and on `tp` (× 2); it fires on `roll.attack: 1` with a ranged weapon (was `roll: 1`, any attack)
- fernkampf.FK14: the same `check` on `roll.attack: 20` with a ranged weapon; the failed confirmation's `damage: 1W6+2 SP` is a `tell` (no dice value form)
- fernkampf.FK17: the confirmation `check` on `roll.defence: 1` against a ranged attack; the `replace` of mehrfache-verteidigung's line with a span of one defence is an `add` on the next defence of the round (+3 confirmed, +1 not), read from the new round fact `round.previousDefenceCrit`; with Vinsalt-Stil (SA_923 with CT_1, CT_4 or CT_16, VS1's step of −2) the confirmed give-back is +2 (ruling kampfstil-techniques), and the unconfirmed +1 does not apply (open question)
- fernkampf.FK18: the `check` on `roll.defence: 20` against a ranged attack; the 1W6+2 SP are a `tell`, as FK14
- ladezeiten.LZ2: new `offer: { choice: laden }` costing an Aktion, or a freie Aktion when the Ladezeit after every rule (`ladezeit.current`) is 0 (was the process's `step`); the process is plan A.7's (`steps: { of: item.ladezeit }`, `completes` an `item` change of the weapon instance, `breaksOff` changed from A.7's never-stated `action.attack: melee` to `action.attack: [hit, miss]` with `loadout.weapon.kind: melee`, as schaden.S3 reads a melee attack); the open ruling laengere-handlungen is cited on a new `tell` stating its question (controller ruling R31), not on the processes, which apply, and the 0 case a one-step process; the forbid reads `loadout.weapon.loaded`; the shot's `after … set item.loaded: false` is an `item` change on `action.attack: [hit, miss]` with a ranged weapon
- ladezeiten.LZ3: `requires: { costs: { freeAction: 1 }, before: { attack: ranged } }` is an `offer: { choice: bereitmachen }` costing a freie Aktion and a `require` of it for the ranged attack, reading `loadout.weapon.loaded`
- ladezeiten.LZ5: new `offer: { choice: spannen }` costing an Aktion (was the process's `step`); the process reads `loadout.weapon.strung` and `completes` an `item` change of the weapon instance; the process does not rest on ruling laengere-handlungen (R31): LZ5's text does not call Spannen a länger dauernde Handlung, so its `tell` is on LZ2 only
- ladezeiten.LZ7: `after: { attack: ranged, costs: { item: weapon.ammunition } }` is `cost: { pool: ammunition, amount: 1 }` on the shot, for Armbrüste, Bögen and Schleudern only (was every ranged attack; thrown weapons spend none)
- SA_60.SL1: the instance gate `option_for: weapon.technique` is `option: 2` with Bögen or `option: 3` with Wurfwaffen; the add's `floor: 0` is its own `floor` effect
- SA_60.SL2: the instance gate is `option: 1` with Armbrüste
- SA_60.SL7: the note is a rule-level `require` (Schnellladen with a bow applies only with a quiver worn, `loadout.quiver`, or the arrows at hand, `gmFact.pfeileGriffbereit`), with `because`
- SA_161.GS1: as SA_160.GA1: the offer is `offer: { choice: gezielterSchuss }` on `query.target: fk`; its `requires: { choice: targetZone }` is a `require … for: { choice: gezielterSchuss }` that a zone is announced; the halving reads `choice.gezielterSchuss` (was `action.manoeuvre`) and is `multiply: { to: fk, by: 0.5, line: { line: trefferzonen.TZ5 } }` (was the effect id `trefferzonen.TZ5.aim`, gone since Group 4)

- DISADV_37.SE4 (Task 16): the one `add` of `{ of: gmFact.triggerModifier }` is two, gated on the modifier's sign (`above: 0` → `of` the fact; `below: 0` → `{ of: 0, above: gmFact.triggerModifier, times: -1 }`), as fertigkeitsproben.FM2, so an Erschwernis survives the proportion's `max(0, …)` clamp (boronmir-neu 19.11's −2) and a 0 gives no line; closes the open question on SE4
- beidhaendiger-kampf.ZW2 (Task 16): the double attack's Aktion is `costs: [{ cost: { pool: actions, amount: 1 } }]` on the `doubleAttack` offer (ruling R23; was a comment)
- schilde.SCH2 (Task 16): the offer `choice: action.with` is `choice: attackWith` (options shield, parryingWeapon), the player fact `choice.attackWith`; the piece picked is the attack's `with:`, read as `action.with`, as beidhaendiger-kampf.ZW7's `parryWith`
- schilde.SCH3 (Task 16): the offer `choice: action.defence, options: [shieldParry]` is `choice: shieldParry` (`choice.shieldParry: true`); taking it is the defence `action.defence: shieldParry`, which SCH3's add, SCH5 and the shield rules read unchanged
- ruestung-und-belastung.A1 (Task 30): the extra GS/INI penalty is `value: 1, per: loadout.armour.extraPenalty` (was `value: { of: loadout.armour.extraPenalty }`, which the proportion's `max(0, …)` clamp turned into 0 for the stated −1); it is two effects, the second for a hero with Belastungsgewöhnung (`hero.has: SA_41`) citing SA_41.table-shift, which decides that the extra penalty stays (belastung 2.4, 2.8)
- COND_1.B4 (Task 30): the Stufe IV `gain` of STATE_8 cites reiterkampf.mounted-jouster, whose `appliesTo` names B4: the mounted relief (RK7) does not lift Stufe IV (belastung 3.3)
- at-pa-modifikatoren.M1 (Task 30): the AT/PA-Mod lines are `value: 1, per: item.atMod` / `item.paMod` (were `{ of: … }`, which the proportion's `max(0, …)` clamp turned into 0 for the Rabenschnabel's PA −1 and the Großschild's AT −6); review reset
- schilde.SCH1 (Task 30): `action.with: mainHand` is `not: { action.with: [offHand, shield, parryingWeapon] }`: the parry of the Hauptwaffe is any weapon parry not made with the off hand, the shield or the Parierwaffe, so `pa(with: weapon)` and a bare-handed Raufen parry (ruling shield-bonus-raufen) get the passive bonus
- ITEMTPL_29.GR1, GR4 (Task 30): `loadout.shield: ITEMTPL_29` is `loadout.shield: Großschild` (the item by name, as fernkampf.FK10 names the Langbogen; the loadout names items, not templates); GR1's `action.with: mainHand` is `[mainHand, weapon]` (`at` and `at(with: weapon)`); review reset
- ITEMTPL_19, ITEMTPL_29, ITEMTPL_35 `provides` (Task 30): the row's `ls: { attribute, threshold }` is `leiteigenschaft: [...]` and `schadensschwelle: n`, and the row states `kind: melee` (it has a Schadensschwelle, schaden.S3): the row keys are the loadout facts the rules read (`loadout.weapon.schadensschwelle`, `loadout.weapon.kind`); reviews of ITEMTPL_29 and ITEMTPL_35 reset
- kampfwerte.KW21 (Task 30): new `provide: { name: kampfwerte.kampftechnik, value: { CT_1: Armbrüste, … }, readBy: loadout }`, the techniques' Optolith ids beside their names, so the loadout reads a technique in either form (an equipment row's `technique: CT_5`, the hero file's `ktw.CT_5`, the Leiteigenschaft table's `Hiebwaffen`)
- situations/kampfwerte.yaml 16.17, 16.18, 16.19 (Task 30, R61): the hero states `values: { rs: 6 }`, the Plattenrüstung's RS the file's header and 16.17's comment ("9 − RS 6") state; nothing derives an armour's RS without the Fokusregel Trefferzonen-RS
- situations/kampfwerte.yaml 16.22 (Task 30, R61): `choose: { action.attack: hit }`, the "on a hit" its comment states (schaden.S3 reads it)
- situations/lebensenergie.yaml file `hero` (Task 30, R61): `sheet: { species.le: 5 }`, the Mensch's LE-Grundwert the header states; `hero.purchased.le` comes from the hero file (`attr.lp`, rulec's import)
- regeneration.R4 (Task 30, ruling R64): new `restore: { pool: le, amount: { of: regeneration.le } }` gated on `choice.regenerationsphase: true`: taking the Regenerationsphase (R2's offer) raises LE by its result ("addiert dann den Wert zu seiner Energie"), a `restored` event held at the maximum by R5's cap (regeneration was unreviewed already)
- DISADV_57.VW1 (Task 30 fix round 1): new `tell` to the player gated on `rulesets: fokus.trefferzonen`, with `because: braucht die Fokusregel Trefferzonen` and ruling verweichlicht-scope, whose notes ask that the sheet show the disadvantage needs the Fokusregel: with it off the tell is not applied (conditionFalse) on every query and on the sheet (situation 13.4); review reset
- schilde.SCH3 (Task 30 fix round 1): new `provide: { name: loadout.shield.technique, value: CT_10, readBy: loadout }`, "den Paradewert der Kampftechnik Schilde": the technique a shield parries with, which the loadout reads for a shield no equipment row describes (the Holzschild, kampfwerte 16.14)
- kampfwerte.KW6, KW7, KW21 (Task 30 fix round 1): the Leiteigenschaft table `kampfwerte.leiteigenschaft` moves from KW21 to KW6 (the Kodex table the PA half is read from); KW7 (was `none`) provides `kampfwerte.hoehereLeiteigenschaft: true`, the datum by which the loadout takes the higher of two, so the line shows "via KW7" (kampfwerte 16.1)
- kampfwerte.KW1, KW6 (Task 30 fix round 1): `loadout.weapon.technique: Peitschen` is `CT_8`: a technique fact reads in its id form, as equipment rows, the hero file and the other rules (ZW1's `CT_6`, ladezeiten, fernkampf, SA_42) name it; the loadout states a technique a situation names by name in its id form
- SA_862.F4, SA_884.P4 (Task 31): the `require` that one fighter in the formation holds the SF is `enables: true` ("Nur einer der Kämpfer benötigt die Sonderfertigkeit, damit alle davon profitieren"): a hero without the SF whose ally holds it gets the formation's offer and bonus, each `via` F4 / P4 (boronmir-neu 19.3, boronmir-sf 14.18); before, a rule the hero did not own never applied, so the require could not act; review reset
- SA_152.AD1 (Task 31): new `require: { that: { opponent.has: SA_152 }, enables: true }` with ruling SA_172.auf-distanz-halten: the opponent's Auf Distanz halten acts on the hero, who does not own the SF, as the ruling's answer has it ("a GM question … which adds the SF's penalty as its own line"); AD1's −1 per Stufe then applies (reichweite RW.12); review reset
- schicksalspunkte.SP-verteidigung (Task 31): the +4's `add` cites SA_65.vh-stacking, whose `appliesTo` names this clause (mehrfache-verteidigung V12); the number and condition are unchanged
- situations/finte.yaml 8.5, situations/beidhaendiger-kampf.yaml 11.10 (Task 31, R61): `loadout: { weapon.technique: CT_6 }`, the Morgenstern's Kettenwaffen the file's header table states; no equipment rule describes the Morgenstern
- situations/wuchtschlag.yaml 9.5, situations/sturmangriff.yaml 10.2 (Task 31, R61): `loadout: { weapon.technique: CT_3 }`, the Dolch's Dolche that the header (9.5) and the situation's name (10.2) state
- situations/mehrfache-verteidigung.yaml V7 (Task 31, R61): `loadout: { weapon.technique: CT_4 }`, the Rapier's Fechtwaffen its comment states
- situations/mehrfache-verteidigung.yaml V5, V7, V12 and situations/kampfsituationen.yaml 17.11 (Task 31, R61): `loadout: { hero.mounted: false }`, "on foot" as the file's header (mehrfache-verteidigung: "No armour, on foot") and 17.11's name say; unstated, reiterkampf.RK5's effects stay live (the open ruling mounted-attack-side) and made these pending
- situations/boronmir-neu.yaml 19.11 (Task 31, R61): `hero: { sheet: { species.le: 5 } }`, the Mensch's LE-Grundwert: the hero file the file names has race R_1 (Mensch), and the situation's comment states the LE 37 it gives (5 + 2 × KO 15 + Hohe Lebenskraft II); without it `leMax`, and so the Schmerz Stufe, is unknown
- regeneration.R7 (Task 31 fix round 1): the `tell` "Heilkräuter wirken dennoch." had no `when` and so showed on every query (a combat roll's among them); it is gated on the Regenerationsphase, `any: [{ choice.regenerationsphase: true }, { query.target: regeneration.le }]` ("in den Regenerationsphasen dennoch"); lebensenergie 15.12 still shows it
- vocabulary (Task 31 fix round 1): new loadout facts `loadout.mount` and `loadout.mount.instance`, the slot reiterkampf.RK6's `item: { instance: { loadout: mount } }` changes (rulec test `test_the_mount_is_a_loadout_slot`)
- situations/beidhaendiger-kampf.yaml 11.10 (Task 31 fix round 1, R61): `loadout: { item.Dolch.technique: CT_3, item.Holzschild.technique: CT_10 }`, the header table's "Dolch Dolche (CT_3)" and "Holzschild Schilde (CT_10)": the loadout entries name the second piece, whose kind the harness reads from its technique (a shield's is the shield slot's, schilde.SCH3)
- maechtiger-schlag.MS2 (Task 31 fix round 2): the Kraftakt penalty reads `mount.kk` (was `creature.kk`, which no rule provides); the `when` gates on the mount's attack on an order, and svellttaler-kaltblut.SK2 provides the mount's KK 25 (kupperus-und-waffen 18.1, 18.3: −3)
- reiterkampf.RK12 (Task 31 fix round 2, ruling R71): the mountAttack order's Aktion and Reiten check are effects of their own citing svellttaler-kaltblut.mount-own-attack (whose `appliesTo` names RK12); the other orders' are unchanged
- ruestung-und-belastung.A2 (Task 32, R61: a default the rules state): was `none` ("data, held by the equipment table"); now `provide: { name: ruestung-und-belastung.ruestungen, value: { Lederrüstung: { rs: 3, belastung: 1, extraPenalty: -1 }, … }, readBy: loadout }`, the page's rows keyed by the armour's name. The loadout reads an armour's field from it when no equipment rule describes the item and nothing states the field (a stated value or an equipment row wins): the RS of a zone piece (trefferzonen-ruestungsschutz.RS2) and an unstated `loadout.armour.belastung` / `extraPenalty` (A1)
- trefferzonen-ruestungsschutz.RS2 (Task 32): new derives of `rs(zone: <zone>)` for the six zones, the RS of the piece worn there (`loadout.armourPiece.<zone>.rs`), 0 with the zone stated empty; they cite pieces-from-other-armours (`appliesTo` names RS2). The clause text says it ("Werden die einzelnen Rüstungsteile getragen, so verleihen sie dem Helden in der angegebenen Zone RS"), and its comment did; nothing derived the zone RS before, so `armourScore` and the Belastung of RS4 had no value (trefferzonen TZ.20–TZ.23, TZ.26)
- trefferzonen-ruestungsschutz.RS4 (Task 32): the `armourScore` derive cites be-sentence (its `appliesTo` names RS4: this sum is BE's one computation) and pieces-from-other-armours (the zones' pieces may come from different armours); the number is unchanged (trefferzonen TZ.22, TZ.26)
- trefferzonen.TZ5 (Task 32): the aiming `add` cites SA_160.halving-by-manoeuvre, whose `appliesTo` names TZ5 and whose answer decides that without the announced manoeuvre the penalty stands in full (trefferzonen TZ.16, TZ.27); the number and condition are unchanged
- situations/trefferzonen.yaml TZ.21, TZ.23, TZ.26 (Task 32, R61): `loadout: { armourPiece.<zone>: null }` for the zones no piece covers: TZ.21's name "without a helmet" (the head), TZ.23's "Only the torso of a Plattenrüstung" (every zone but the torso), TZ.26's name, which lists the torso, arms and legs and no head, and its comment "4·5 + 3·8" (no head term). Unstated, the zone's piece is asked (RS2: 0 only "without one")
- STATE_13.UE1 (Task 32): new `require: { that: { opponent.has: STATE_13 }, enables: true }`: the opponent's Überrascht acts on the hero, who does not have it, as SA_152.AD1's Auf Distanz halten (Task 31); UE1's tell to the opponent ("noDefence") reaches the hero's attack (trefferzonen TZ.5). UE1's other effects are gated on `hero.has: STATE_13` and stay off
- situations/trefferzonen.yaml TZ.14 (Task 32, R61): `loadout: { twoHanded: false }`, the "one-handed Schwert" of its name; trefferzonen.TZ8's arm Wundeffekt reads `loadout.twoHanded` (a two-handed weapon stays in the hands)
- trefferzonen-ruestungsschutz.pieces-from-other-armours (Task 32 fix round 1): `appliesTo` names RS4 too, whose `armourScore` derive cites it (the sum of zone pieces from different armours)
- regeneration.R6, T1 (Task 32 fix round 1): the `ask`s for `choice.environment` and T1's four rows are gated on `query.target: regeneration.le`, the Regenerationsphase's value; ungated, every query asked them (R7's tell was gated for the same reason in Task 31). The `any` form of R7 is not used: `choice.regenerationsphase` has no default, so it is unknown outside the phase and an `ask` with an unknown `when` still asks
- fernkampf.FK8 (Task 32 fix round 1): the `ask` for `target.cover` is gated on `query.target: fk`; ungated, every query asked it
- zaubermodifikationen.ZM11 (Task 32 fix round 1): the seven `check.modifier` adds are gated on `check.kind: spell` beside their choice; a talent check's modifier asked for the spell modifications
- STATE_10.L3 (Task 33): new `require: { that: { opponent.has: STATE_10 }, enables: true }`, as STATE_13.UE1: the opponent's Liegend acts on the hero, who does not have it, so L3's `opponent.pa` / `opponent.aw` −2 and "AT −4" tell and L2's "GS 1" tell reach the hero's attack (liegend 7.3). The hero's own effects stay gated on `hero.has: STATE_10`
- COND_6.SZ5 (Task 33): new `cap: { to: gs, min: 0, max: 0 }` at Stufe IV, citing schmerz-iv-gs ("the hero cannot move (GS 0)"). The `set` to 0 applies before the phase's `add`s (plan Task 22), so Belastung's GS −3 in Platte still counted (schmerz S12: GS −3); the bound holds GS at 0 after every line. The Schip's suppress of every Zustand's lines lifts the bound too (a suppressed `cap` bounds nothing, Task 33)
- schicksalspunkte.SP-zustand (Task 33 fix round 1): new `suppress: { line: { line: zustaende.Z5 } }` on the Schip, citing schip-lifts-incapacity. Z5's Handlungsunfähig from eight Zustandsstufen is carried by Zustände (the ruling lifts it), but zustaende is a core rule, which the `ruleKind: condition` suppress does not reach
- STATE_8.H2 (Task 33 fix round 1): new `cap: { to: gs, min: 0, max: 0 }` beside the `set` to 0, as COND_6.SZ5: "Ihre GS fällt auf 0" after every other line (Belastung's GS −3 in Platte counted after the set). The cap phase now bounds the value after the caps over a sum, so the bound acts after zustaende.Z3 whatever the rule order

## Open questions

- Task 32 fix round 1 (R73): the engine does not resolve a hit's zone from a stated die. TZ2 asks the roll layer for `hit.zone`; the tables that give it (TZ3's choice by the size gap, TZ4–TZ4j's rows, TZ4c's side by parity) are `readBy: roll`, so TZ3's relative-size rule (ruling relative-size-table) is executed nowhere, neither by the engine nor by a situation's check. The zone situations TZ.9–TZ.11 wait on it (and on their restored expectations).

- trefferzonen.TZ11 / TZ8, Torso: "Zusätzlich 1W3+1 SP" needs a dice value form, which the vocabulary does not have (A.4). Until one exists TZ8's failed Wundeffekt check on the torso `tell`s the player to roll it; the SP are not applied by the engine. The same gap holds for core/sturzschaden, and for fernkampf.FK14 / FK18 (a failed confirmation of a Patzer: "1W6+2 SP", a `tell`). Task 32: the harness compares an expected `damage: { formula }` event (trefferzonen TZ.12, boronmir-neu 19.8) with the engine's damage events, which carry an amount; that comparison cannot succeed until the dice value form exists, and must be revisited then (`CombatRunner.events`).
- zustaende.Z5 / SA_41: `hero.conditionLevels` counts each Zustand's Stufe before any `useLevel`, so Zäher Hund does not lower the count (ruling ADV_49.zaeher-hund-counts). The same definition counts Belastung before Belastungsgewöhnung (SA_41.G1's `useLevel`): Boronmir in Plattenrüstung counts Belastung III, not I. lebensenergie 15.8's comment counts I (1 + 3 + 3 + 1 = 8; 10 by this definition). Its expected result (Handlungsunfähig) holds either way. Does Belastungsgewöhnung lower the Stufe the hero has, or only its effects?
- COND_6.SZ3: the Stufe from the LP thresholds is a `derive` (the base of `level(rule: COND_6)`); a Stufe stated on the sheet (a Patzer, a wound effect) is the rule's owned level. The engine plan takes a stated base before a derive, so LP Stufen and stated Stufen do not add up today (zustaende.Z1 says they should: "Die einzelnen Zustände addieren sich auf").
- fertigkeitsproben.QS1: the QS derive reads `table(fertigkeitsproben.qs, check.fp)` (plan A.4, verbatim). `check.fp` is a stage target, not a fact, and the table's keys are ranges ("0-3", "16+"). The engine's `table(name, key)` (plan Task 22) looks up a fact's value by exact key; it must resolve a key that names a target through the target's value, and match a number against range keys (trefferzonen's tables need the same).
- ADV_4 / SA_9: a hero may own several instances of one rule (Begabung up to three Fertigkeiten, Fertigkeitsspezialisierung up to three Anwendungsgebiete per talent). A situation's owned entry and the Optolith import (`hero.py`, `entries[0]`) hold one instance, and `check.onOption` / `check.applicationOnOption` are defined per instance. How the engine evaluates a rule once per instance is open. The same holds for SA_60 (Schnellladen, one instance per combat technique, `sid` 1–6): SL1/SL2 gate on `option` against the technique in hand, so a hero with Schnellladen for Bögen and for Armbrüste holds two instances.
- TAL_7 (kind `talent`): a talent rule is not owned (the sheet has its FW, `fw.TAL_7`) and not core. Its effects are gated on `check.talent: TAL_7`; the engine must apply a talent rule to a check on that talent (situations `pending` counts only owned and core rules).
- zaubermodifikationen (spell data): the `spell.` fact family is owned by `player`, but `spell.duration`, `spell.interval`, `spell.range` (the spell's own), `spell.foreignTradition`, `spell.forbidsErzwingen` and `spell.forbidsKostenSenken` are the spell's data (rules.db spell_details, the spell's text). Unstated they are unknown and ask the player on every cast. Should the engine state them from the spell's data (a new owner or a data-sourced `provide`), and where does a spell's base cost, casting time and range come from (probe-magie states them as the queries' base `values`)?
- zaubermodifikationen.ZM1 (pending): ZM1's second `limit` rests on the open ruling omit-counts, and a `limit` on a `choice` is indexed under `*`, so every situation of every file is pending on omit-counts (before Task 14 the same came from cost-off-table on ZM8's provides). `pending` counts a core rule's `*` effects whatever their `when` (`check.kind: spell`). Either the reach index keys a choice's legality under something narrower, or pending looks at the effect's `when`. Group 8 adds four more to every situation's pending list the same way: fernkampf.range-input (FK4's provide), fernkampf.cover-as-size (FK8's ask), fernkampf.zielen-interrupted (FK11's process) and ladezeiten.laengere-handlungen (LZ2's `tell`), all `*` effects of a core rule. The count stays 309 of 309.

- fernkampf.FK17 with Vinsalt-Stil (Group 8): after an unconfirmed crit defence, "nur um 2 statt um 3 (zusätzlich) erschwert". With Vinsalt-Stil (SA_923.VS1) the step is already −2: does the next defence give back 0 (it is "um 2" erschwert, as always with the style) or 1 (one point off the style's step)? FK17's `+1` is left off the Vinsalt case until this is answered; the confirmed case gives back the style's full step, +2.
- ladezeiten.laengere-handlungen (Group 8): the page "Länger dauernde Handlungen" was searched for again on 2026-09-25 (the wiki's start page, `länger … handlung`) and not found. The `process` payload is kept to what Zielen and Laden need (`steps`, `advancedBy`, `breaksOff`, `completes`); the open ruling asks which other actions continue across rounds. The ruling is cited on a `tell` in LZ2 that states its question (controller ruling R31); the Laden and Spannen processes do not rest on it and apply.
- Stufe IV and the states it gains (Task 30): COND_1.B4's comment says Handlungsunfähig holds "while the Stufe is IV or more … this `when` stops holding" (dropping the load), and COND_6.SZ5's Stufe IV the same. The action layer's `.settle` runs a `gain` when its `when` holds, but never withdraws what it gained when the `when` stops holding (a load dropped, the Selbstbeherrschung check passed under Zäher Hund: lebensenergie 15.7's step). Should settling clear a state whose gaining `when` no longer holds (and only one gained so, not one the GM stated), or does each rule need its own `cleared` effect?
- STATE_10.L2 "GS 1" (Task 33 fix round 1): L2 is a `set`, and a `set` applies before the phase's `add`s (plan Task 22), so Belastung, Schmerz and other GS penalties still count after it (a Liegend hero in Platte with Schmerz III: 1 − 5 = GS −4). Does "sehr langsam fortbewegen (GS 1)" mean GS is 1 whatever else applies (a bound, as COND_6.SZ5 and STATE_8.H2 now have for GS 0), or do the penalties stack on it?
- COND_6.SZ2 and ruling schmerz-iv-check (Task 33 fix round 1): the Selbstbeherrschung check is required "before each action the hero wants to take", but no action of the engine asks it: `.take` asks only the checks gated on the choice taken, and SZ2's `check` is gated on the Stufe alone. Situations state the check and its result directly (schmerz S3's step, S12). The ruling is carried out nowhere until the action layer asks SZ2's check before an action (which actions count, and whether a free action does, is not settled)

## Notes for the engine tasks

Procedure and harness work the rules rest on (Tasks 22–28); no owner decision.

- probe-fertigkeiten 22.3 (Task 26): each `check.attribute(index: i)` breakdown carries the lines of the shared `check.modifier` breakdown (plan Task 26: "the attribute plus one shared `check.modifier` breakdown … the GM's modifier as a line with owner gm"), so the expected `{ value: -1, from: fertigkeitsproben.FM2, source: gm }` on `check.attribute` is FM2's `check.modifier` line shown there.
- probe-fertigkeiten 22.5, 22.6, 22.8 (Task 26): the harness reads the situation-level `result` key (`success`, `kind`, `from`). The procedure classifies the result from the faces (spec §6 result stage) and names the classifying clause: fertigkeitsproben.KR1 for a Doppel-1 (kind kritischerErfolg; KR2 dreifach1), fertigkeitsproben.PZ1 for a Doppel-20 (kind patzer) or Dreifach-20 (dreifach20) — for 22.6, PZ1 even though it is a Doppel-20; `regular` otherwise (22.5).
- ADV_4.B1, SA_9.FS1 (Task 22): the derived facts `check.onOption` and `check.applicationOnOption` take their value from the owned instance of the rule that reads them (`option` = `sid`, `option2` = `sid2`) against the check's `check.talent` / `check.application`. When `check.application` is unknown, the question goes to the player (the fact's owner; fertigkeitsproben.FP8 asks it).
- Talent texts (follow-up, rules authoring): fertigkeitsproben.KR1/PZ1's generic `provide: { name: text, value: skill.critical | skill.botch }` went with the Group 6 migration; only TAL_7 (Schwimmen) has a rule file carrying its Kritischer Erfolg and Patzer. Every other talent's crit/botch text (and the 11 talents' "FP = doppelter FW") is lost until either one rule file per talent exists or a data-sourced `provide` (Optolith de-DE/Skills.yaml `critical`/`botch`, rules.db) supplies them.
- probe-magie 20.2 (Task 22): a step along a scale (`add … scale`) is a line whose `value` is the parameter after the step and whose `was` is the value before (8 → 16), as a lowered line carries `was` (reichweite.yaml); its `via` holds the clause that provides the scale (zaubermodifikationen.ZM8), as ruling R26 adds the rules behind a target operand.
- probe-magie 20.2–20.5 (Task 22/24): the line key `term` names the modification a ZM11 line belongs to ("Erzwingen", "Zauberdauer erhöhen"), since one clause gives several lines. The engine takes it from the choice option the line's `when` read (`choice.spellModification.erzwingen`); the display names of the options (lowerCamelCase ids) must come from somewhere, e.g. the picker's labels.
- probe-magie 20.1, 20.7 (Task 23): an `offered` entry's `max` is the choice's bound: for `spellModification` the max of zaubermodifikationen.ZM1's first `limit` (FW 9 → 2); for `split.le` the cost less the other pools' `split.min` (8 − 1 = 7, SA_74.VP1). A `limit` over a list of choice ids counts how many of them are chosen (`choice.spellModification.<id>: true`); `fw.current` on a spell check is the FW of `check.spell` (`fw.SPELL_…`).
- probe-magie 20.5 (Task 28): the `sequence` step `advanceClock: { minutes: 180 }` advances the game clock; ZM5's `cost { every: { minutes: spell.interval } }` reads the interval from the fact. The expected `paid` of 3 AsP `over: { minutes: 180 }` is the sum of the three payments of 1 in that step: the harness sums the `paid` events of one origin and pool within a step.
- probe-magie 20.7, 20.8 (Tasks 25, 26): SA_74.VP1's `suppress` of zaubermodifikationen.ZM12 drops ZM12's `cost`s (no `paid` event; ZM12 in `notApplied`, suppressed). VP2's failed Selbstbeherrschung forbids the spell check (`onFailure: forbid { check: [spell] }`); the procedure reads a spell check forbidden that way as a failed cast: `result: { success: false, from: SA_74.VP2 }` (20.8) and `check.result: failure` for the spell, on which VP3's cost fires. In 20.7 `rolls: { check.result: success }` stands for both checks.
- probe-magie 20.8 (Task 25): a `fallThrough` payment is expected as one entry `paid: { amount: 4, pools: [{ asp: 3 }, { le: 1 }] }`; the engine gives `paid(asp, 3)`, `paid(le, 1)` (plan Task 25). The harness matches the entry against the events of one `cost` effect: their sum and the pools in order.
- probe-magie 20.7 (Task 25): `notApplied: [{ rule: trefferzonen, clause: TZ8, reason: "LeP aufgewendet, kein Schaden" }]`: paying LeP lowers `leCurrent` but is no hit, so no Wundschwelle or Wundeffekt check follows; the harness matches the entry by rule and clause (TZ8 is also out of its ruleset there).
- probe-fernkampf (Task 28): item state is kept per instance (`item.<instance>.loaded`, `.strung`). The rules read the weapon in hand's as `loadout.weapon.loaded` / `loadout.weapon.strung`, which the engine resolves through `loadout.weapon.instance`; an `item` effect with `instance: { loadout: weapon }` changes that instance. `ladezeit.current` is the result of the query `item.ladezeit` for the weapon in hand (after SA_60), for LZ2's `when`; the weapon's own Ladezeit is `loadout.weapon.ladezeit`, the base of LZ1's `derive`.
- probe-fernkampf 21.6, 21.8 (Task 28): an action that advances a process is offered as a choice with its cost (`offer: { choice: laden, costs: [cost { pool: actions | freeActions }] }`, as STATE_10.L4); taking it is the process's `advancedBy: { action: laden }`. The progress of a running process is the fact `process.<id>` (Zielen's bonus is `2 per process.zielen`); `steps` bounds it, so a third Zielen action gives no progress (`capped`). Zielen's bonus is read by the shot's FK query before the shot states `action.attack` and breaks the process off. An `offered` entry's `costs: { action | freeAction: 1 }` is matched against the offer's `cost` (pool `actions` / `freeActions`, amount 1).
- probe-fernkampf 21.4, 21.5b (Task 27): FK9 Stufe 4 and FK10's trot cap FK at 0; the combat roll gives `success: true` for a natural 1 at FK ≤ 0 and `false` for any other face (a 1 always succeeds, as passierschlag.passierschlag-dice reads it).
- fernkampf.FK13, FK14, FK17, FK18 (Task 27): the combat roll states the d20 of the hero's attack as `roll.attack` and of a defence as `roll.defence`; a `check: { of: { check: confirm, with: … } }` is the confirm stage of that roll (spec §6), running its `onSuccess` / `onFailure` for this attack. After a confirmation on a defence the combat roll states `round.previousDefenceCrit: confirmed | unconfirmed` for the next defence of the round (FK17), and clears it after that defence and at the end of the round.
- probe-fernkampf 21.3 (Task 22): FK8's `replace` of FK6's line keeps FK6 as the origin, puts FK8 in `via` and shows `was:`; its `term` ("Deckung: gilt als klein") names the row the replacement reads (`target.sizeInCover: klein`).
- ladezeiten.LZ2 (Task 28): Laden breaks off on a melee attack, `action.attack: [hit, miss]` with `loadout.weapon.kind: melee`. During that attack `loadout.weapon` is the melee weapon, not the ranged one being loaded: the process is bound to the weapon instance it was started on (its `completes` changes that instance), and its `when` (`loadout.weapon.loaded`, `ladezeit.current`) is resolved against that ranged weapon, not re-read from the weapon in hand while the process runs.
- `process.` facts (Task 28): the progress of a running process (`process.zielen`) is owned by `derived`, as the engine computes it from the Situation's processes; it is not `round` state and is not reset by `.endRound`, since a process may outlive the round (spec §7). Only `breaksOff` or completion ends it.
- Provides with `readBy` (Task 16): a `provide` that no rule reads declares its reader outside the rules: `roll` (trefferzonen.TZ3, TZ4–TZ4j: the tables the app rolls `hit.zone` on when TZ2 asks, TZ4c's side from the die's parity), `loadout` (kampfwerte.KW21: the Leiteigenschaft table the loadout resolves `technique.leit` from) or `display` (DISADV_37.SE6's option names and trigger lines, waffeneigenschaften.WE1's Themenkomplex and Stufe, svellttaler-kaltblut.SK4's RS and Aktionen). The build counts them reachable; the app, not the rule pipeline, consumes them. Equipment rows and mount profiles (`loadout.weapon`, `mount.gs`) are read as facts and need no `readBy`.
- probe-magie 20.5 (Task 22): zaubermodifikationen.ZM5 steps `spell.costPerInterval` one step down the `zaubermodifikationen.kosten` scale; from its bottom step (Flim Flam's 2 → 1, the upkeep one below) the step clamps at the bottom ("nicht unter 1 AsP"), it does not raise an error.
- probe-magie 20.4 (Task 23): a `formelWeglassen` the player chose but ZM1's `limit` refuses (it is in `notOffered`) adds no −2: ZM11's line for a modification reads the choice only once the choice is legal, so the `check.modifier` holds only Erzwingen's +1 and Zauberdauer senken's −1.
- SA_74.VP1 (Task 22/25): its `suppress` of zaubermodifikationen.ZM12 removes action-phase `cost` effects, not value lines; spec §5.2 defines `suppress` in the lines phase of a target's value pipeline only. The engine must support a `suppress` whose named clause's effects are action-layer effects (no `paid` event, the clause in `notApplied` with reason suppressed).
- schilde.SCH2, SCH3, beidhaendiger-kampf.ZW7 (Task 27): a choice that picks the piece or the defence (`choice.attackWith`, `choice.shieldParry`, `choice.parryWith`) becomes the action's `with:` / `action.defence`; the defence and attack screens list it as the action layer's entry (`offered: [{ defence: shieldParry }]`, `[{ attack: shield, from: schilde.SCH2 }]`, kampfwerte 16.5, 16.8), not as a `choice` entry.
- passierschlag.PS2 (Task 25/28): an offer carries its action cost in `costs` (ruling R23); the Passierschlag's has none, so taking it pays nothing (kampfsituationen 17.7 `events: []`). The action layer must not charge an Aktion for the attack a cost-free choice stands for.
