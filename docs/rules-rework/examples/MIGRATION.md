# Migration residue

Written by `scripts/rulec/migrate.py` (spec §10.3 step 1). Each item is a key the
mechanical old → new table could not move; it is resolved by hand (plan Tasks 8–15) and
ticked. Line numbers are those of the migrated file.

`- [ ] L<line> <path in the doc>: <old key> — <why not mechanical>`

## rules/abilities/SA_152.yaml

- [ ] L26 clauses[AD1].effects[0].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [ ] L26 clauses[AD1].effects[0].when.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [ ] L31 clauses[AD1].effects[1].when.announced: announced — not a fact in the vocabulary
- [ ] L31 clauses[AD1].effects[1].when.loadout.reach.longer_than: longer_than — snake_case key, no mapping
- [ ] L43 clauses[AD2].effects[0].offer.announce: announce — not a field of `offer`
- [ ] L43 clauses[AD2].effects[0].offer.at: at — not a field of `offer`
- [ ] L43 clauses[AD2].effects[0].offer.lasts: lasts — not a field of `offer`
- [ ] L46 clauses[AD2].effects[1].when.announced: announced — not a fact in the vocabulary
- [ ] L47 clauses[AD2].effects[1].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [ ] L50 clauses[AD2].effects[2].when.announced: announced — not a fact in the vocabulary
- [ ] L50 clauses[AD2].effects[2].when.loadout.reach.not_longer_than: not_longer_than — snake_case key, no mapping

## rules/abilities/SA_160.yaml

- [ ] L26 clauses[GA1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [ ] L27 clauses[GA1].effects[0].offer.on: on — not a field of `offer`
- [ ] L28 clauses[GA1].effects[0].offer.requires: requires — not a field of `offer`
- [ ] L29 clauses[GA1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_161.yaml

- [ ] L25 clauses[GS1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [ ] L26 clauses[GS1].effects[0].offer.on: on — not a field of `offer`
- [ ] L27 clauses[GS1].effects[0].offer.requires: requires — not a field of `offer`
- [ ] L28 clauses[GS1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_172.yaml

- [ ] L28 clauses[U1].effects[0].lower: lower — no one-to-one verb
- [ ] L28 clauses[U1].effects[0].lower.by_steps: by_steps — snake_case key, no mapping
- [ ] L40 clauses[U2].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [ ] L41 clauses[U2].effects[0].offer.announce: announce — not a field of `offer`
- [ ] L43 clauses[U2].effects[0].offer.requires: requires — not a field of `offer`
- [ ] L43 clauses[U2].effects[0].offer.requires.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [ ] L44 clauses[U2].effects[0].offer.ruling: ruling — not a field of `offer`
- [ ] L64 clauses[U4].ruling: ruling — not a clause key in the vocabulary

## rules/abilities/SA_173.yaml

- [ ] L22 clauses[VU1].lifts: lifts — not a clause key in the vocabulary

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

- [ ] L23 clauses[BK1].enables: enables — not a clause key in the vocabulary

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

- [ ] L28 clauses[SL1].effects[0].when.hero.has.SA_60.option_for: option_for — snake_case key, no mapping
- [ ] L29 clauses[SL1].effects[0].add.floor: floor — not a field of `add`
- [ ] L37 clauses[SL2].effects[0].when.hero.has.SA_60.option_for: option_for — snake_case key, no mapping
- [ ] L74 clauses[SL7].effects[0].requires: requires — a key that is not a fact: hero.has_item, fact
- [ ] L74 clauses[SL7].effects[0].requires.any_of: any_of — snake_case key, no mapping
- [ ] L74 clauses[SL7].effects[0].requires.any_of[0].hero.has_item: hero.has_item — snake_case key, no mapping

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

- [ ] L24 clauses[GS1].effects[0].when.loadout: loadout — not a fact in the vocabulary
- [ ] L25 clauses[GS1].effects[0].raise: raise — no one-to-one verb
- [ ] L35 clauses[GS2].effects[0].when.loadout: loadout — not a fact in the vocabulary
- [ ] L44 clauses[GS3].effects[0].define: define — no one-to-one verb

## rules/abilities/SA_67.yaml

- [x] L23 clauses[W1].effects[0].offer.manoeuvre: manoeuvre — not a field of `offer`
- [x] L24 clauses[W1].effects[0].offer.tiers: tiers — not a field of `offer`
- [x] L25 clauses[W1].effects[0].offer.ruling: ruling — not a field of `offer`

## rules/abilities/SA_74.yaml

- [ ] L35 clauses[VP1].effects[0].offer.amount: amount — not a field of `offer`
- [ ] L36 clauses[VP1].effects[0].offer.when: when — not a field of `offer`
- [ ] L37 clauses[VP1].effects[0].offer.ruling: ruling — not a field of `offer`
- [ ] L40 clauses[VP1].effects[1].forbid.choice: choice — not a field of `forbid`
- [ ] L40 clauses[VP1].effects[1].forbid.when: when — not a field of `forbid`
- [ ] L42 clauses[VP1].effects[2].split: split — no one-to-one verb
- [ ] L50 clauses[VP2].effects[0].when.amount: amount — not a fact in the vocabulary
- [ ] L51 clauses[VP2].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L52 clauses[VP2].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L67 clauses[VP3].effects[0].when.check_failed: check_failed — not a fact in the vocabulary
- [ ] L68 clauses[VP3].effects[0].charge: charge — keys outside the row: round, pools, ruling; missing pool

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

- [ ] L24 clauses[FS1].effects[0].when.check: check — not a fact in the vocabulary

## rules/abilities/SA_923.yaml

- [x] L22 clauses[VS1].effects[0].change: change — no one-to-one verb
- [x] L34 clauses[VS2].ruling: ruling — not a clause key in the vocabulary

## rules/advantages/ADV_25.yaml

No residue.

## rules/advantages/ADV_4.yaml

- [ ] L26 clauses[B1].effects[0].offer.reroll: reroll — not a field of `offer`
- [ ] L27 clauses[B1].effects[0].offer.when: when — not a field of `offer`
- [ ] L28 clauses[B1].effects[0].offer.once_per: once_per — not a field of `offer`
- [ ] L29 clauses[B1].effects[0].offer.after: after — not a field of `offer`
- [ ] L30 clauses[B1].effects[0].offer.before: before — not a field of `offer`
- [ ] L42 clauses[B2].effects[0].choose: choose — no one-to-one verb
- [ ] L43 clauses[B2].effects[0].keep: keep — no one-to-one verb
- [ ] L68 clauses[B5].effects[0].forbid.offer: offer — not a field of `forbid`
- [ ] L68 clauses[B5].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L84 clauses[B7].effects[0].allow: allow — no one-to-one verb

## rules/advantages/ADV_44.yaml

- [x] L20 clauses[VR1].effects[0].when.event: event — not a fact in the vocabulary
- [x] L20 clauses[VR1].effects[0].when.energy: energy — not a fact in the vocabulary
- [x] L20 clauses[VR1].effects[0].when.regenerates: regenerates — not a fact in the vocabulary
- [x] L21 clauses[VR1].effects[0].add.before: before — not a field of `add`

## rules/advantages/ADV_49.yaml

- [ ] L25 clauses[ZH1].effects[0].when.condition: condition — not a fact in the vocabulary
- [ ] L27 clauses[ZH1].effects[0].keeps: keeps — no one-to-one verb
- [ ] L27 clauses[ZH1].effects[0].keeps.condition_level: condition_level — snake_case key, no mapping
- [ ] L41 clauses[ZH3].effects[0].when.condition: condition — not a fact in the vocabulary
- [ ] L42 clauses[ZH3].effects[0].keep: keep — no one-to-one verb
- [ ] L44 clauses[ZH3].effects[1].when.condition: condition — not a fact in the vocabulary
- [ ] L44 clauses[ZH3].effects[1].when.check_passed: check_passed — not a fact in the vocabulary
- [ ] L51 clauses[ZH4].effects[0].when.condition: condition — not a fact in the vocabulary

## rules/advantages/ADV_5.yaml

- [x] L18 clauses[V1].status: status — not a clause key in the vocabulary
- [x] L19 clauses[V1].why: why — `why` without `effects: none`: the clause has no body to carry it

## rules/advantages/ADV_54.yaml

No residue.

## rules/advantages/ADV_75.yaml

- [ ] L24 clauses[SW1].effects[0].when.condition: condition — not a fact in the vocabulary
- [ ] L24 clauses[SW1].effects[0].when.cause: cause — not a fact in the vocabulary
- [ ] L25 clauses[SW1].effects[0].scale: scale — no one-to-one verb
- [ ] L27 clauses[SW1].effects[1].when.condition: condition — not a fact in the vocabulary
- [ ] L27 clauses[SW1].effects[1].when.cause: cause — not a fact in the vocabulary
- [ ] L28 clauses[SW1].effects[1].scale: scale — no one-to-one verb

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

- [ ] L16 level: level — not a rule key in the vocabulary
- [ ] L19 level.from[1].set_by: set_by — snake_case key, no mapping
- [ ] L20 level.effects_lowered_by: effects_lowered_by — snake_case key, no mapping
- [ ] L35 clauses[SZ2].effects[0].when.before: before — not a fact in the vocabulary
- [ ] L36 clauses[SZ2].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L37 clauses[SZ2].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L38 clauses[SZ2].effects[0].on_success: on_success — no one-to-one verb
- [ ] L52 clauses[SZ3].effects[0].sets: sets — no one-to-one verb
- [ ] L62 clauses[SZ4].status: status — not a clause key in the vocabulary
- [ ] L63 clauses[SZ4].why: why — `why` without `effects: none`: the clause has no body to carry it
- [ ] L78 clauses[SZ5].effects[1].unless: unless — next to a `when`: which of the two conditions wins is not mechanical
- [ ] L78 clauses[SZ5].effects[1].unless.check_passed: check_passed — snake_case key, no mapping
- [ ] L79 clauses[SZ5].effects[2].when.check_passed: check_passed — not a fact in the vocabulary

## rules/conditions/STATE_10.yaml

- [ ] L17 applies_to_side: applies_to_side — not a rule key in the vocabulary
- [ ] L29 clauses[L2].effects[0].when.side: side — not a fact in the vocabulary
- [ ] L33 clauses[L2].effects[1].when.side: side — not a fact in the vocabulary
- [ ] L39 clauses[L3].effects[0].when.side: side — not a fact in the vocabulary
- [ ] L41 clauses[L3].effects[1].when.side: side — not a fact in the vocabulary
- [ ] L44 clauses[L3].effects[2].when.side: side — not a fact in the vocabulary
- [ ] L48 clauses[L3].effects[3].when.side: side — not a fact in the vocabulary
- [ ] L59 clauses[L4].effects[0].when.side: side — not a fact in the vocabulary
- [ ] L61 clauses[L4].effects[0].offer.action: action — not a field of `offer`
- [ ] L63 clauses[L4].effects[0].offer.then: then — not a field of `offer`
- [ ] L63 clauses[L4].effects[0].offer.then.remove_state: remove_state — snake_case key, no mapping
- [ ] L64 clauses[L4].effects[0].offer.if_opponent_in_reach: if_opponent_in_reach — not a field of `offer`
- [ ] L65 clauses[L4].effects[0].offer.if_opponent_in_reach.optional_check: optional_check — snake_case key, no mapping
- [ ] L66 clauses[L4].effects[0].offer.if_opponent_in_reach.on_check_failed_or_skipped: on_check_failed_or_skipped — snake_case key, no mapping

## rules/conditions/STATE_13.yaml

- [ ] L22 clauses[UE1].effects[0].when.check: check — not a fact in the vocabulary
- [ ] L25 clauses[UE1].effects[1].when.hero.state: hero.state — not a fact in the vocabulary
- [ ] L26 clauses[UE1].effects[1].forbid.defence: defence — not a field of `forbid`
- [ ] L26 clauses[UE1].effects[1].forbid.until: until — not a field of `forbid`

## rules/core/angriff-von-hinten.yaml

- [ ] L24 clauses[AH1].effects[0].when.side: side — not a fact in the vocabulary
- [ ] L24 clauses[AH1].effects[0].when.attack.kind: attack.kind — not a fact in the vocabulary
- [ ] L24 clauses[AH1].effects[0].when.span: span — not a fact in the vocabulary
- [ ] L30 clauses[AH1].effects[1].when.side: side — not a fact in the vocabulary
- [ ] L30 clauses[AH1].effects[1].when.attack.kind: attack.kind — not a fact in the vocabulary
- [ ] L30 clauses[AH1].effects[1].when.span: span — not a fact in the vocabulary
- [ ] L35 clauses[AH1].effects[2].when.side: side — not a fact in the vocabulary
- [ ] L35 clauses[AH1].effects[2].when.attack.kind: attack.kind — not a fact in the vocabulary
- [ ] L36 clauses[AH1].effects[2].forbid.defence: defence — not a field of `forbid`
- [ ] L37 clauses[AH1].effects[2].from: from — no one-to-one verb
- [ ] L39 clauses[AH1].effects[3].when.side: side — not a fact in the vocabulary
- [ ] L39 clauses[AH1].effects[3].when.attack.kind: attack.kind — not a fact in the vocabulary
- [ ] L40 clauses[AH1].effects[3].exempt: exempt — no one-to-one verb
- [ ] L41 clauses[AH1].effects[3].from: from — no one-to-one verb

## rules/core/at-pa-modifikatoren.yaml

- [x] L23 clauses[M1].effects[0].when.attack.with: attack.with — not a fact in the vocabulary
- [x] L24 clauses[M1].effects[0].add.after: after — not a field of `add`
- [x] L25 clauses[M1].effects[1].when.with: with — not a fact in the vocabulary
- [x] L26 clauses[M1].effects[1].add.after: after — not a field of `add`

## rules/core/beengte-umgebung.yaml

- [ ] L19 applies_when: applies_when — not a rule key in the vocabulary
- [ ] L62 clauses[BU3].ruling: ruling — not a clause key in the vocabulary

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

- [ ] L36 clauses[FK2].effects[0].forbid.attack: attack — not a field of `forbid`
- [ ] L36 clauses[FK2].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L46 clauses[FK3].effects[0].forbid.attack: attack — not a field of `forbid`
- [ ] L46 clauses[FK3].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L61 clauses[FK4].effects[0].provides: provides — a snake_case name, or not a mapping of names
- [ ] L62 clauses[FK4].effects[0].provides.range_band: range_band — snake_case key, no mapping
- [ ] L72 clauses[FK4].effects[1].when.range_band: range_band — not a fact in the vocabulary
- [ ] L73 clauses[FK4].effects[1].forbid.choice: choice — not a field of `forbid`
- [ ] L85 clauses[FK5].effects[0].table: table — no one-to-one verb
- [ ] L120 clauses[FK7].effects[2].when.side: side — not a fact in the vocabulary
- [ ] L121 clauses[FK7].effects[2].set.opponent.gs: opponent.gs — not a field of `set`
- [ ] L136 clauses[FK8].effects[0].offer.fact: fact — not a field of `offer`
- [ ] L139 clauses[FK8].effects[1].set.target.size_for_fk: target.size_for_fk — not a field of `set`
- [ ] L155 clauses[FK9].effects[1].when.sicht: sicht — not a fact in the vocabulary
- [ ] L156 clauses[FK9].effects[1].result: result — no one-to-one verb
- [ ] L175 clauses[FK10].effects[1].result: result — no one-to-one verb
- [ ] L177 clauses[FK10].effects[2].forbid.attack: attack — not a field of `forbid`
- [ ] L177 clauses[FK10].effects[2].forbid.when: when — not a field of `forbid`
- [ ] L189 clauses[FK11].effects[0].process.step: step — not a field of `process`
- [ ] L190 clauses[FK11].effects[0].process.accumulates: accumulates — not a field of `process`
- [ ] L191 clauses[FK11].effects[0].process.ends: ends — not a field of `process`
- [ ] L193 clauses[FK11].effects[0].process.ruling: ruling — not a field of `process`
- [ ] L220 clauses[FK13].effects[0].when.roll: roll — not a fact in the vocabulary
- [ ] L221 clauses[FK13].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L222 clauses[FK13].effects[0].on_success: on_success — no one-to-one verb
- [ ] L225 clauses[FK13].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L238 clauses[FK14].effects[0].when.roll: roll — not a fact in the vocabulary
- [ ] L239 clauses[FK14].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L240 clauses[FK14].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L251 clauses[FK15].effects[0].when.incoming: incoming — not a fact in the vocabulary
- [ ] L252 clauses[FK15].effects[0].forbid.defence: defence — not a field of `forbid`
- [ ] L256 clauses[FK15].effects[1].when.incoming: incoming — not a fact in the vocabulary
- [ ] L258 clauses[FK15].effects[2].when.incoming: incoming — not a fact in the vocabulary
- [ ] L277 clauses[FK17].effects[0].when.defence.roll: defence.roll — not a fact in the vocabulary
- [ ] L278 clauses[FK17].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L279 clauses[FK17].effects[0].on_success: on_success — no one-to-one verb
- [ ] L280 clauses[FK17].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L290 clauses[FK18].effects[0].when.defence.roll: defence.roll — not a fact in the vocabulary
- [ ] L291 clauses[FK18].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L292 clauses[FK18].effects[0].on_failure: on_failure — no one-to-one verb

## rules/core/fertigkeitsproben.yaml

- [ ] L37 clauses[FP1].effects[0].defines: defines — no one-to-one verb
- [ ] L52 clauses[FP2].effects[0].forbid.check: check — not a field of `forbid`
- [ ] L52 clauses[FP2].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L66 clauses[FP3].effects[0].defines: defines — no one-to-one verb
- [ ] L66 clauses[FP3].effects[0].defines.spend_per_die: spend_per_die — snake_case key, no mapping
- [ ] L89 clauses[FP5].effects[0].defines: defines — no one-to-one verb
- [ ] L98 clauses[FP8].effects[0].defines: defines — no one-to-one verb
- [ ] L122 clauses[QS1].effects[0].table: table — no one-to-one verb
- [ ] L131 clauses[QS2].effects[0].set.stage: stage — not a field of `set`
- [ ] L131 clauses[QS2].effects[0].set.when: when — not a field of `set`
- [ ] L143 clauses[FM1].effects[0].defines: defines — no one-to-one verb
- [ ] L143 clauses[FM1].effects[0].defines.applies_to: applies_to — snake_case key, no mapping
- [ ] L158 clauses[FM2].effects[0].offer.gm.modifier: gm.modifier — not a field of `offer`
- [ ] L169 clauses[KR1].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [ ] L170 clauses[KR1].effects[0].set.stage: stage — not a field of `set`
- [ ] L170 clauses[KR1].effects[0].set.success: success — not a field of `set`
- [ ] L170 clauses[KR1].effects[0].set.kind: kind — not a field of `set`
- [ ] L187 clauses[KR2].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [ ] L188 clauses[KR2].effects[0].set.stage: stage — not a field of `set`
- [ ] L188 clauses[KR2].effects[0].set.kind: kind — not a field of `set`
- [ ] L205 clauses[PZ1].effects[0].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [ ] L206 clauses[PZ1].effects[0].set.stage: stage — not a field of `set`
- [ ] L206 clauses[PZ1].effects[0].set.success: success — not a field of `set`
- [ ] L206 clauses[PZ1].effects[0].set.kind: kind — not a field of `set`
- [ ] L207 clauses[PZ1].effects[1].when.stage.roll.count_of: count_of — snake_case key, no mapping
- [ ] L208 clauses[PZ1].effects[1].set.stage: stage — not a field of `set`
- [ ] L208 clauses[PZ1].effects[1].set.kind: kind — not a field of `set`

## rules/core/groessenkategorie.yaml

- [ ] L18 scale: scale — not a rule key in the vocabulary
- [ ] L39 clauses[GK2].ruling: ruling — not a clause key in the vocabulary
- [ ] L47 clauses[GK3].effects[GK3.at].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [ ] L49 clauses[GK3].effects[GK3.at].id: id — no one-to-one verb
- [ ] L57 clauses[GK4].effects[0].when.side: side — not a fact in the vocabulary
- [ ] L58 clauses[GK4].effects[0].forbid.defence: defence — not a field of `forbid`
- [ ] L59 clauses[GK4].effects[1].when.side: side — not a fact in the vocabulary
- [ ] L60 clauses[GK4].effects[1].forbid.defence: defence — not a field of `forbid`

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

- [ ] L30 clauses[LZ1].effects[0].provides: provides — `from` is a pointer, not a named value
- [ ] L43 clauses[LZ2].effects[0].process.of: of — not a field of `process`
- [ ] L45 clauses[LZ2].effects[0].process.step: step — not a field of `process`
- [ ] L50 clauses[LZ2].effects[1].process.step: step — not a field of `process`
- [ ] L52 clauses[LZ2].effects[2].forbid.attack: attack — not a field of `forbid`
- [ ] L52 clauses[LZ2].effects[2].forbid.when: when — not a field of `forbid`
- [ ] L54 clauses[LZ2].effects[3].after: after — no one-to-one verb
- [ ] L64 clauses[LZ3].effects[0].requires: requires — a key that is not a fact: costs, before
- [ ] L84 clauses[LZ5].effects[0].process.of: of — not a field of `process`
- [ ] L84 clauses[LZ5].effects[0].process.step: step — not a field of `process`
- [ ] L99 clauses[LZ7].effects[0].after: after — no one-to-one verb

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

- [ ] L17 scale: scale — not a rule key in the vocabulary
- [ ] L46 clauses[RW3].effects[RW3.at].when.check: check — `check: at` names the kind of check, not a talent: `check.talent` would change the meaning
- [ ] L46 clauses[RW3].effects[RW3.at].when.opponent.reach.longer_than: longer_than — snake_case key, no mapping
- [ ] L48 clauses[RW3].effects[RW3.at].id: id — no one-to-one verb

## rules/core/reiterkampf.yaml

- [ ] L16 applies_when: applies_when — not a rule key in the vocabulary
- [ ] L37 clauses[RK1].effects[0].replace.value: value — not a field of `replace`
- [ ] L46 clauses[RK2].effects[0].grants: grants — no one-to-one verb
- [ ] L54 clauses[RK3].effects[0].forbid.manoeuvre: manoeuvre — not a field of `forbid`
- [ ] L60 clauses[RK4].effects[0].forbid.loadout: loadout — not a field of `forbid`
- [ ] L68 clauses[RK5].effects[0].when.attack.from: attack.from — not a fact in the vocabulary
- [ ] L69 clauses[RK5].effects[0].forbid.defence: defence — not a field of `forbid`
- [ ] L70 clauses[RK5].effects[0].open_ruling: open_ruling — no one-to-one verb
- [ ] L82 clauses[RK6].effects[0].when.check: check — `check: aw` names the kind of check, not a talent: `check.talent` would change the meaning
- [ ] L84 clauses[RK6].effects[1].offer.on: on — not a field of `offer`
- [ ] L84 clauses[RK6].effects[1].offer.then: then — not a field of `offer`
- [ ] L93 clauses[RK7].effects[0].when.check: check — not a fact in the vocabulary
- [ ] L94 clauses[RK7].effects[0].lower: lower — no one-to-one verb
- [ ] L94 clauses[RK7].effects[0].lower.penalty_only: penalty_only — snake_case key, no mapping
- [ ] L105 clauses[RK8].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L112 clauses[RK9].effects[0].costs: costs — no one-to-one verb
- [ ] L120 clauses[RK10].effects[0].when.event: event — not a fact in the vocabulary
- [ ] L121 clauses[RK10].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L122 clauses[RK10].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L127 clauses[RK11].effects[0].when.event: event — not a fact in the vocabulary
- [ ] L128 clauses[RK11].effects[0].offer.on: on — not a field of `offer`
- [ ] L128 clauses[RK11].effects[0].offer.label: label — not a field of `offer`
- [ ] L128 clauses[RK11].effects[0].offer.then: then — not a field of `offer`
- [ ] L143 clauses[RK12].effects[0].defines: defines — no one-to-one verb
- [ ] L143 clauses[RK12].effects[0].defines.requires_check: requires_check — snake_case key, no mapping
- [ ] L157 clauses[RK13].effects[0].offer.order: order — not a field of `offer`
- [ ] L158 clauses[RK13].effects[0].offer.requires: requires — not a field of `offer`
- [ ] L159 clauses[RK13].effects[0].offer.ruling: ruling — not a field of `offer`
- [ ] L163 clauses[RK13].effects[0].offer.attack: attack — not a field of `offer`
- [ ] L164 clauses[RK13].effects[0].offer.opponent_may_only: opponent_may_only — not a field of `offer`
- [ ] L165 clauses[RK13].effects[0].offer.after: after — not a field of `offer`
- [ ] L182 clauses[RK14].ruling: ruling — not a clause key in the vocabulary
- [ ] L185 clauses[RK14].effects[0].offer.order: order — not a field of `offer`
- [ ] L186 clauses[RK14].effects[0].offer.requires: requires — not a field of `offer`
- [ ] L189 clauses[RK14].effects[0].offer.attack: attack — not a field of `offer`
- [ ] L190 clauses[RK14].effects[0].offer.opponent_may_only: opponent_may_only — not a field of `offer`
- [ ] L191 clauses[RK14].effects[0].offer.on_hit: on_hit — not a field of `offer`
- [ ] L207 clauses[RK15].effects[0].offer.order: order — not a field of `offer`
- [ ] L208 clauses[RK15].effects[0].offer.requires_check: requires_check — not a field of `offer`
- [ ] L209 clauses[RK15].effects[0].offer.on_success: on_success — not a field of `offer`

## rules/core/ruestung-und-belastung.yaml

- [x] L30 clauses[A1].effects[0].sets: sets — no one-to-one verb

## rules/core/schaden.yaml

- [ ] L31 clauses[S1].effects[0].roll: roll — no one-to-one verb
- [ ] L34 clauses[S1].effects[1].when.event: event — not a fact in the vocabulary
- [ ] L38 clauses[S1].effects[2].when.event: event — not a fact in the vocabulary
- [ ] L115 clauses[S4].effects[0].when.weapon.leit: weapon.leit — not a fact in the vocabulary
- [ ] L116 clauses[S4].effects[0].replace.value: value — not a field of `replace`
- [ ] L129 clauses[S5].effects[0].offer.on: on — not a field of `offer`
- [ ] L129 clauses[S5].effects[0].offer.then: then — not a field of `offer`
- [ ] L158 clauses[S8].effects[0].when.le.current: le.current — not a fact in the vocabulary

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

- [ ] L6 fokus: fokus — not a rule key in the vocabulary
- [ ] L7 requires_ruleset: requires_ruleset — not a rule key in the vocabulary
- [ ] L10 replaces: replaces — not a rule key in the vocabulary
- [ ] L43 clauses[RS2].effects[0].when.event: event — not a fact in the vocabulary
- [ ] L59 clauses[RS3].effects[0].forbid.loadout: loadout — not a field of `forbid`
- [ ] L95 clauses[RS4].effects[0].sets: sets — no one-to-one verb

## rules/core/trefferzonen.yaml

- [ ] L13 fokus: fokus — not a rule key in the vocabulary
- [ ] L42 clauses[TZ2].effects[0].when.event: event — not a fact in the vocabulary
- [ ] L42 clauses[TZ2].effects[0].when.zone: zone — not a fact in the vocabulary
- [ ] L43 clauses[TZ2].effects[0].roll: roll — no one-to-one verb
- [ ] L43 clauses[TZ2].effects[0].roll.on.chosen_by: chosen_by — snake_case key, no mapping
- [ ] L57 clauses[TZ3].effects[0].table_for: table_for — no one-to-one verb
- [ ] L59 clauses[TZ3].effects[0].table_for.clamp_to: clamp_to — snake_case key, no mapping
- [ ] L114 clauses[TZ4c].effects[0].sets: sets — no one-to-one verb
- [ ] L186 clauses[TZ4i].effects[0].provide.value.7-20.split_evenly: split_evenly — snake_case key, no mapping
- [ ] L211 clauses[TZ5].effects[0].offer.on: on — not a field of `offer`
- [ ] L211 clauses[TZ5].effects[0].offer.zones: zones — not a field of `offer`
- [ ] L216 clauses[TZ5].effects[TZ5.aim].id: id — no one-to-one verb
- [ ] L218 clauses[TZ5].effects[2].raise: raise — no one-to-one verb
- [ ] L223 clauses[TZ5].effects[3].replaces: replaces — no one-to-one verb
- [ ] L240 clauses[TZ6].effects[0].table: table — no one-to-one verb
- [ ] L254 clauses[TZ7].status: status — not a clause key in the vocabulary
- [ ] L255 clauses[TZ7].why: why — `why` without `effects: none`: the clause has no body to carry it
- [ ] L269 clauses[TZ8].effects[0].when.event: event — not a fact in the vocabulary
- [ ] L270 clauses[TZ8].effects[0].requires_check: requires_check — no one-to-one verb
- [ ] L274 clauses[TZ8].effects[0].on_failure: on_failure — no one-to-one verb
- [ ] L300 clauses[TZ11].effects[0].table: table — no one-to-one verb
- [ ] L303 clauses[TZ11].effects[0].table.arme.drop.ask_if: ask_if — snake_case key, no mapping

## rules/core/vorteilhafte-position.yaml

- [ ] L15 applies_when: applies_when — not a rule key in the vocabulary
- [ ] L18 applies_when.any[1].granted_by: granted_by — snake_case key, no mapping
- [ ] L32 clauses[VP1].effects[VP1.at].id: id — no one-to-one verb
- [ ] L42 clauses[VP2].status: status — not a clause key in the vocabulary
- [ ] L43 clauses[VP2].why: why — `why` without `effects: none`: the clause has no body to carry it
- [ ] L49 clauses[VP3].status: status — not a clause key in the vocabulary
- [ ] L50 clauses[VP3].why: why — `why` without `effects: none`: the clause has no body to carry it

## rules/core/waffeneigenschaften.yaml

- [x] L8 fokus: fokus — not a rule key in the vocabulary
- [x] L25 clauses[WE1].effects[0].defines: defines — no one-to-one verb
- [x] L36 clauses[WE2].effects[0].gates: gates — no one-to-one verb

## rules/core/zaubermodifikationen.yaml

- [ ] L40 clauses[ZM1].effects[0].offer.pickers: pickers — not a field of `offer`
- [ ] L40 clauses[ZM1].effects[0].offer.per: per — not a field of `offer`
- [ ] L40 clauses[ZM1].effects[0].offer.before: before — not a field of `offer`
- [ ] L41 clauses[ZM1].effects[1].limit.choice: choice — not a field of `limit`
- [ ] L54 clauses[ZM2].effects[0].limit.category: category — not a field of `limit`
- [ ] L54 clauses[ZM2].effects[0].limit.max_steps: max_steps — not a field of `limit`
- [ ] L62 clauses[ZM3].effects[0].forbid.choice: choice — not a field of `forbid`
- [ ] L71 clauses[ZM4].effects[0].forbid.choice: choice — not a field of `forbid`
- [ ] L71 clauses[ZM4].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L83 clauses[ZM5].effects[0].derive.value: value — not a field of `derive`
- [ ] L83 clauses[ZM5].effects[0].derive.from: from — not a field of `derive`
- [ ] L83 clauses[ZM5].effects[0].derive.steps: steps — not a field of `derive`
- [ ] L83 clauses[ZM5].effects[0].derive.table: table — not a field of `derive`
- [ ] L86 clauses[ZM5].effects[1].cap.value: value — not a field of `cap`
- [ ] L87 clauses[ZM5].effects[2].charge: charge — keys outside the row: every, while
- [ ] L100 clauses[ZM6].effects[0].limit.choice: choice — not a field of `limit`
- [ ] L100 clauses[ZM6].effects[0].limit.each: each — not a field of `limit`
- [ ] L107 clauses[ZM7].effects[0].forbid.choice: choice — not a field of `forbid`
- [ ] L107 clauses[ZM7].effects[0].forbid.when: when — not a field of `forbid`
- [ ] L167 clauses[ZM11].effects[0].shift: shift — the effect already has `add`: two verbs in one effect
- [ ] L170 clauses[ZM11].effects[1].shift: shift — the effect already has `add`: two verbs in one effect
- [ ] L173 clauses[ZM11].effects[2].shift: shift — the effect already has `add`: two verbs in one effect
- [ ] L176 clauses[ZM11].effects[3].shift: shift — the effect already has `add`: two verbs in one effect
- [ ] L179 clauses[ZM11].effects[4].shift: shift — the effect already has `add`: two verbs in one effect
- [ ] L184 clauses[ZM11].effects[5].when.choice: choice — not a fact in the vocabulary
- [ ] L187 clauses[ZM11].effects[6].forbid.choice: choice — not a field of `forbid`
- [ ] L187 clauses[ZM11].effects[6].forbid.when: when — not a field of `forbid`
- [ ] L205 clauses[ZM12].effects[0].on_success: on_success — no one-to-one verb
- [ ] L206 clauses[ZM12].effects[1].on_failure: on_failure — no one-to-one verb

## rules/core/zustaende.yaml

- [ ] L35 clauses[Z3].effects[0].cap.lines: lines — not a field of `cap`
- [ ] L35 clauses[Z3].effects[0].cap.on: on — not a field of `cap`
- [ ] L55 clauses[Z4].status: status — not a clause key in the vocabulary
- [ ] L56 clauses[Z4].why: why — `why` without `effects: none`: the clause has no body to carry it
- [ ] L63 clauses[Z5].effects[0].when.sum: sum — not a fact in the vocabulary
- [ ] L63 clauses[Z5].effects[0].when.sum.condition_levels: condition_levels — snake_case key, no mapping
- [ ] L63 clauses[Z5].effects[0].when.min: min — not a fact in the vocabulary

## rules/creatures/maechtiger-schlag.yaml

- [ ] L36 clauses[MS1].effects[0].tell: tell — tell: the text is a structure, not a text
- [ ] L36 clauses[MS1].effects[0].tell.opponent.on_failure: on_failure — snake_case key, no mapping
- [ ] L49 clauses[MS2].effects[0].opponent_add: opponent_add — keys outside the row: round
- [ ] L61 clauses[MS3].effects[0].cancels: cancels — no one-to-one verb
- [ ] L63 clauses[MS3].effects[1].tell: tell — tell: the text is a structure, not a text
- [ ] L63 clauses[MS3].effects[1].tell.opponent.on_failure: on_failure — snake_case key, no mapping
- [ ] L63 clauses[MS3].effects[1].tell.opponent.whatever_the_parry: whatever_the_parry — snake_case key, no mapping

## rules/creatures/ruhiges-temperament.yaml

- [ ] L24 clauses[RT1].effects[0].when.check: check — not a fact in the vocabulary

## rules/creatures/svellttaler-kaltblut.yaml

- [ ] L26 profile: profile — not a rule key in the vocabulary
- [ ] L88 clauses[SK3].effects[1].offer.order: order — not a field of `offer`
- [ ] L88 clauses[SK3].effects[1].offer.attacks: attacks — not a field of `offer`
- [ ] L88 clauses[SK3].effects[1].offer.via: via — not a field of `offer`
- [ ] L112 clauses[SK5].effects[0].grants: grants — no one-to-one verb
- [ ] L159 clauses[SK10].effects[0].when.mount.lep.at_most: at_most — snake_case key, no mapping

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

- [ ] L28 mount: mount — not a situations-file key in the vocabulary
- [ ] L37 situations["17.1"].choose.attack: attack — not a fact in the vocabulary
- [ ] L40 situations["17.1"].expect.costs: costs — neither an expect key nor a query
- [ ] L41 situations["17.1"].expect.tell: tell — neither an expect key nor a query
- [ ] L42 situations["17.1"].expect.rolls: rolls — neither an expect key nor a query
- [ ] L52 situations["17.2"].choose.attack: attack — not a fact in the vocabulary
- [ ] L63 situations["17.3"].choose.attack: attack — not a fact in the vocabulary
- [ ] L77 situations["17.4"].choose.attack: attack — not a fact in the vocabulary
- [ ] L77 situations["17.4"].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L85 situations["17.4"].expect.rolls: rolls — neither an expect key nor a query
- [ ] L91 situations["17.5"].choose.attack: attack — not a fact in the vocabulary
- [ ] L104 situations["17.6"].choose.attack: attack — not a fact in the vocabulary
- [ ] L116 situations["17.7"].choose.attacks: attacks — not a fact in the vocabulary
- [ ] L118 situations["17.7"].expect.each: each — neither an expect key nor a query
- [ ] L119 situations["17.7"].expect.actions_used: actions_used — neither an expect key nor a query
- [ ] L120 situations["17.7"].expect.counts_as_defence: counts_as_defence — neither an expect key nor a query
- [ ] L126 situations["17.8"].event: event — not a situation key in the vocabulary
- [ ] L129 situations["17.8"].expect.next: next — neither an expect key nor a query
- [ ] L136 situations["17.9"].event: event — not a situation key in the vocabulary
- [ ] L140 situations["17.9"].expect.with_choice: with_choice — neither an expect key nor a query
- [ ] L141 situations["17.9"].expect.target: target — neither an expect key nor a query
- [ ] L142 situations["17.9"].expect.then: then — neither an expect key nor a query
- [ ] L189 situations["17.12"].expect.opponent_lines: opponent_lines — neither an expect key nor a query
- [ ] L195 situations["17.13"].attack: attack — not a situation key in the vocabulary
- [ ] L217 situations["17.15"].choose.defence: defence — not a fact in the vocabulary
- [ ] L225 situations["17.16"].choose.defence: defence — not a fact in the vocabulary
- [ ] L233 situations["17.17"].choose.attack: attack — not a fact in the vocabulary
- [ ] L290 situations["17.22"].expect.tell: tell — neither an expect key nor a query

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

- [ ] L32 mount: mount — not a situations-file key in the vocabulary
- [ ] L42 situations["18.1"].choose.order: order — not a fact in the vocabulary
- [ ] L42 situations["18.1"].choose.gait: gait — not a fact in the vocabulary
- [ ] L42 situations["18.1"].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L45 situations["18.1"].expect.costs: costs — neither an expect key nor a query
- [ ] L46 situations["18.1"].expect.checks_first: checks_first — neither an expect key nor a query
- [ ] L54 situations["18.1"].expect.on_check_failure: on_check_failure — neither an expect key nor a query
- [ ] L56 situations["18.1"].expect.attack: attack — neither an expect key nor a query
- [ ] L59 situations["18.1"].expect.attack.opponent_may_only: opponent_may_only — snake_case key, no mapping
- [ ] L60 situations["18.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L62 situations["18.1"].expect.on_attack_success: on_attack_success — neither an expect key nor a query
- [ ] L64 situations["18.1"].expect.on_attack_success.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [ ] L67 situations["18.1"].expect.after: after — neither an expect key nor a query
- [ ] L80 situations["18.2"].mount: mount — not a situation key in the vocabulary
- [ ] L81 situations["18.2"].choose.order: order — not a fact in the vocabulary
- [ ] L81 situations["18.2"].choose.gait: gait — not a fact in the vocabulary
- [ ] L81 situations["18.2"].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L83 situations["18.2"].expect.attack: attack — neither an expect key nor a query
- [ ] L84 situations["18.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L91 situations["18.3"].choose.order: order — not a fact in the vocabulary
- [ ] L91 situations["18.3"].choose.attack: attack — not a fact in the vocabulary
- [ ] L94 situations["18.3"].expect.costs: costs — neither an expect key nor a query
- [ ] L94 situations["18.3"].expect.costs[0].instead_of: instead_of — snake_case key, no mapping
- [ ] L95 situations["18.3"].expect.checks_first: checks_first — neither an expect key nor a query
- [ ] L104 situations["18.3"].expect.not_asked: not_asked — neither an expect key nor a query
- [ ] L105 situations["18.3"].expect.on_check_failure: on_check_failure — neither an expect key nor a query
- [ ] L107 situations["18.3"].expect.attack: attack — neither an expect key nor a query
- [ ] L110 situations["18.3"].expect.attack.opponent_may_only: opponent_may_only — snake_case key, no mapping
- [ ] L112 situations["18.3"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L114 situations["18.3"].expect.on_attack_success: on_attack_success — neither an expect key nor a query
- [ ] L116 situations["18.3"].expect.on_attack_success.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [ ] L126 situations["18.4"].choose.order: order — not a fact in the vocabulary
- [ ] L126 situations["18.4"].choose.attack: attack — not a fact in the vocabulary
- [ ] L128 situations["18.4"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L129 situations["18.4"].expect.tell: tell — neither an expect key nor a query
- [ ] L130 situations["18.4"].expect.tell[0].opponent.on_failure: on_failure — snake_case key, no mapping
- [ ] L139 situations["18.5"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [ ] L148 situations["18.5"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L160 situations["18.6"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [ ] L164 situations["18.6"].sequence[0].expect.on_hit: on_hit — snake_case key, no mapping
- [ ] L169 situations["18.6"].sequence[1].expect.on_hit: on_hit — snake_case key, no mapping
- [ ] L183 situations["18.7"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L197 situations["18.8"].choose.order: order — not a fact in the vocabulary
- [ ] L197 situations["18.8"].choose.gait: gait — not a fact in the vocabulary
- [ ] L197 situations["18.8"].choose.dornenspitze: dornenspitze — not a fact in the vocabulary
- [ ] L199 situations["18.8"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L222 situations["18.9"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L233 situations["18.10"].choose.attack: attack — not a fact in the vocabulary
- [ ] L235 situations["18.10"].expect.conditions: conditions — neither an expect key nor a query
- [ ] L250 situations["18.11"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L271 situations["18.13"].expect.tell: tell — neither an expect key nor a query
- [ ] L291 situations["18.15"].expect.ini_belastung: ini_belastung — neither an expect key nor a query
- [ ] L297 situations["18.16"].expect.mount_carrying_capacity: mount_carrying_capacity — neither an expect key nor a query
- [ ] L309 situations["18.17"].expect.on_hit: on_hit — neither an expect key nor a query

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

- [ ] L21 situations["7.2"].check: check — not a situation key in the vocabulary
- [ ] L31 situations["7.3"].expect.opponent_lines: opponent_lines — neither an expect key nor a query
- [ ] L33 situations["7.3"].expect.told: told — neither an expect key nor a query
- [ ] L40 situations["7.4"].expect.states: states — neither an expect key nor a query
- [ ] L43 situations["7.4"].expect.actions: actions — neither an expect key nor a query
- [ ] L44 situations["7.4"].expect.defences: defences — neither an expect key nor a query
- [ ] L54 situations["7.5"].expect.states: states — neither an expect key nor a query
- [ ] L66 situations["7.6"].choose.action: action — not a fact in the vocabulary
- [ ] L66 situations["7.6"].choose.check: check — not a fact in the vocabulary
- [ ] L69 situations["7.6"].expect.after: after — neither an expect key nor a query
- [ ] L70 situations["7.6"].expect.told: told — neither an expect key nor a query
- [ ] L77 situations["7.7"].choose.action: action — not a fact in the vocabulary
- [ ] L77 situations["7.7"].choose.check: check — not a fact in the vocabulary
- [ ] L79 situations["7.7"].expect.after: after — neither an expect key nor a query
- [ ] L80 situations["7.7"].expect.told: told — neither an expect key nor a query

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

- [ ] L20 situations["21.1"].target: target — not a situation key in the vocabulary
- [ ] L22 situations["21.1"].expect.range_band: range_band — neither an expect key nor a query
- [ ] L29 situations["21.1"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L38 situations["21.2"].target: target — not a situation key in the vocabulary
- [ ] L39 situations["21.2"].sicht: sicht — not a situation key in the vocabulary
- [ ] L41 situations["21.2"].expect.range_band: range_band — neither an expect key nor a query
- [ ] L50 situations["21.2"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L56 situations["21.3"].target: target — not a situation key in the vocabulary
- [ ] L68 situations["21.4"].sicht: sicht — not a situation key in the vocabulary
- [ ] L71 situations["21.4"].expect.fk.replaced_by: replaced_by — snake_case key, no mapping
- [ ] L72 situations["21.4"].expect.outcomes: outcomes — neither an expect key nor a query
- [ ] L78 situations["21.5"].mount: mount — not a situation key in the vocabulary
- [ ] L81 situations["21.5"].expect.with_Kurzbogen: with_Kurzbogen — neither an expect key nor a query
- [ ] L82 situations["21.5"].expect.with_Kurzbogen.fk.replaced_by: replaced_by — snake_case key, no mapping
- [ ] L90 situations["21.6"].target: target — not a situation key in the vocabulary
- [ ] L99 situations["21.6"].open: open — not a situation key in the vocabulary
- [ ] L113 situations["21.8"].cases: cases — not a situation key in the vocabulary
- [ ] L128 situations["21.8"].cases[5].expect.before_shot: before_shot — snake_case key, no mapping

## situations/probe-fertigkeiten.yaml

- [ ] L26 situations["22.1"].check: check — not a situation key in the vocabulary
- [ ] L29 situations["22.1"].expect.eew: eew — neither an expect key nor a query
- [ ] L30 situations["22.1"].expect.fw: fw — neither an expect key nor a query
- [ ] L42 situations["22.2"].check: check — not a situation key in the vocabulary
- [ ] L45 situations["22.2"].expect.fw: fw — neither an expect key nor a query
- [ ] L53 situations["22.3"].check: check — not a situation key in the vocabulary
- [ ] L57 situations["22.3"].expect.eew: eew — neither an expect key nor a query
- [ ] L58 situations["22.3"].expect.fw: fw — neither an expect key nor a query
- [ ] L70 situations["22.4"].check: check — not a situation key in the vocabulary
- [ ] L72 situations["22.4"].choose.reroll: reroll — not a fact in the vocabulary
- [ ] L72 situations["22.4"].choose.result: result — not a fact in the vocabulary
- [ ] L74 situations["22.4"].expect.before_reroll: before_reroll — neither an expect key nor a query
- [ ] L75 situations["22.4"].expect.dice: dice — neither an expect key nor a query
- [ ] L85 situations["22.5"].check: check — not a situation key in the vocabulary
- [ ] L87 situations["22.5"].choose.reroll: reroll — not a fact in the vocabulary
- [ ] L87 situations["22.5"].choose.result: result — not a fact in the vocabulary
- [ ] L89 situations["22.5"].expect.dice: dice — neither an expect key nor a query
- [ ] L92 situations["22.5"].expect.result: result — neither an expect key nor a query
- [ ] L97 situations["22.6"].check: check — not a situation key in the vocabulary
- [ ] L100 situations["22.6"].expect.result: result — neither an expect key nor a query
- [ ] L106 situations["22.7"].check: check — not a situation key in the vocabulary
- [ ] L108 situations["22.7"].choose.reroll: reroll — not a fact in the vocabulary
- [ ] L108 situations["22.7"].choose.result: result — not a fact in the vocabulary
- [ ] L110 situations["22.7"].expect.before_reroll: before_reroll — neither an expect key nor a query
- [ ] L111 situations["22.7"].expect.dice: dice — neither an expect key nor a query
- [ ] L115 situations["22.7"].expect.offered[0].together_with: together_with — snake_case key, no mapping
- [ ] L122 situations["22.8"].check: check — not a situation key in the vocabulary
- [ ] L125 situations["22.8"].expect.eew: eew — neither an expect key nor a query
- [ ] L127 situations["22.8"].expect.result: result — neither an expect key nor a query
- [ ] L130 situations["22.8"].expect.text: text — neither an expect key nor a query
- [ ] L135 situations["22.9"].check: check — not a situation key in the vocabulary
- [ ] L138 situations["22.9"].expect.eew: eew — neither an expect key nor a query
- [ ] L139 situations["22.9"].expect.forbidden: forbidden — neither an expect key nor a query

## situations/probe-magie.yaml

- [ ] L32 situations["20.1"].cast: cast — not a situation key in the vocabulary
- [ ] L35 situations["20.1"].expect.check: check — neither an expect key nor a query
- [ ] L36 situations["20.1"].expect.spell: spell — neither an expect key nor a query
- [ ] L37 situations["20.1"].expect.charge: charge — neither an expect key nor a query
- [ ] L45 situations["20.2"].cast: cast — not a situation key in the vocabulary
- [ ] L47 situations["20.2"].expect.check: check — neither an expect key nor a query
- [ ] L53 situations["20.2"].expect.spell: spell — neither an expect key nor a query
- [ ] L54 situations["20.2"].expect.spell.cost.lines[0].from_rule: from_rule — snake_case key, no mapping
- [ ] L55 situations["20.2"].expect.spell.castingTime.lines[0].from_rule: from_rule — snake_case key, no mapping
- [ ] L56 situations["20.2"].expect.charge: charge — neither an expect key nor a query
- [ ] L64 situations["20.3"].cast: cast — not a situation key in the vocabulary
- [ ] L65 situations["20.3"].fail: fail — not a situation key in the vocabulary
- [ ] L67 situations["20.3"].expect.check: check — neither an expect key nor a query
- [ ] L73 situations["20.3"].expect.spell: spell — neither an expect key nor a query
- [ ] L74 situations["20.3"].expect.charge: charge — neither an expect key nor a query
- [ ] L79 situations["20.4"].cast: cast — not a situation key in the vocabulary
- [ ] L79 situations["20.4"].cast.formel_weglassen: formel_weglassen — snake_case key, no mapping
- [ ] L86 situations["20.4"].expect.check: check — neither an expect key nor a query
- [ ] L87 situations["20.4"].expect.spell: spell — neither an expect key nor a query
- [ ] L94 situations["20.5"].cast: cast — not a situation key in the vocabulary
- [ ] L95 situations["20.5"].maintain: maintain — not a situation key in the vocabulary
- [ ] L97 situations["20.5"].expect.check: check — neither an expect key nor a query
- [ ] L98 situations["20.5"].expect.spell: spell — neither an expect key nor a query
- [ ] L101 situations["20.5"].expect.charge: charge — neither an expect key nor a query
- [ ] L112 situations["20.6"].cast: cast — not a situation key in the vocabulary
- [ ] L114 situations["20.6"].expect.open: open — neither an expect key nor a query
- [ ] L115 situations["20.6"].expect.check: check — neither an expect key nor a query
- [ ] L116 situations["20.6"].expect.spell: spell — neither an expect key nor a query
- [ ] L117 situations["20.6"].expect.charge: charge — neither an expect key nor a query
- [ ] L125 situations["20.7"].cast: cast — not a situation key in the vocabulary
- [ ] L126 situations["20.7"].choose.payWithLeP: payWithLeP — not a fact in the vocabulary
- [ ] L129 situations["20.7"].expect.checks_first: checks_first — neither an expect key nor a query
- [ ] L131 situations["20.7"].expect.charge: charge — neither an expect key nor a query
- [ ] L134 situations["20.7"].expect.after: after — neither an expect key nor a query
- [ ] L143 situations["20.8"].cast: cast — not a situation key in the vocabulary
- [ ] L144 situations["20.8"].choose.payWithLeP: payWithLeP — not a fact in the vocabulary
- [ ] L145 situations["20.8"].fail: fail — not a situation key in the vocabulary
- [ ] L147 situations["20.8"].expect.cast: cast — neither an expect key nor a query
- [ ] L148 situations["20.8"].expect.charge: charge — neither an expect key nor a query
- [ ] L153 situations["20.8"].expect.after: after — neither an expect key nor a query

## situations/reichweite.yaml

- [ ] L7 weapons: weapons — not a situations-file key in the vocabulary
- [ ] L61 situations[RW.6].check: check — not a situation key in the vocabulary
- [ ] L72 situations[RW.7].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L76 situations[RW.7].expect.on_miss: on_miss — neither an expect key nor a query
- [ ] L83 situations[RW.8].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L92 situations[RW.9].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L116 situations[RW.12].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L132 situations[RW.13].expect.excludes: excludes — neither an expect key nor a query
- [ ] L138 situations[RW.14].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [ ] L138 situations[RW.14].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L150 situations[RW.15].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [ ] L152 situations[RW.15].expect.not_combinable: not_combinable — neither an expect key nor a query
- [ ] L153 situations[RW.15].expect.told: told — neither an expect key nor a query
- [ ] L159 situations[RW.16].choose.manoeuvre: manoeuvre — not a fact in the vocabulary

## situations/reiterkampf.yaml

- [ ] L5 mount: mount — not a situations-file key in the vocabulary
- [ ] L51 situations["5.5"].choose.jumpOff: jumpOff — not a fact in the vocabulary
- [ ] L55 situations["5.5"].expect.after: after — neither an expect key nor a query
- [ ] L123 situations["5.10"].choose.order: order — not a fact in the vocabulary
- [ ] L123 situations["5.10"].choose.gait: gait — not a fact in the vocabulary
- [ ] L125 situations["5.10"].expect.checks_first: checks_first — neither an expect key nor a query
- [ ] L126 situations["5.10"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L128 situations["5.10"].expect.opponent_may_only: opponent_may_only — neither an expect key nor a query
- [ ] L134 situations["5.11"].mount: mount — not a situation key in the vocabulary
- [ ] L135 situations["5.11"].choose.order: order — not a fact in the vocabulary
- [ ] L135 situations["5.11"].choose.gait: gait — not a fact in the vocabulary
- [ ] L137 situations["5.11"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L144 situations["5.12"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L144 situations["5.12"].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L147 situations["5.12"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L149 situations["5.12"].expect.on_miss: on_miss — neither an expect key nor a query
- [ ] L151 situations["5.12"].expect.excludes: excludes — neither an expect key nor a query
- [ ] L157 situations["5.13"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L157 situations["5.13"].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L159 situations["5.13"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L165 situations["5.14"].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L165 situations["5.14"].choose.runUp: runUp — not a fact in the vocabulary
- [ ] L168 situations["5.14"].expect.on_hit: on_hit — neither an expect key nor a query
- [ ] L181 situations["5.16"].expect.not_selectable: not_selectable — neither an expect key nor a query
- [ ] L189 situations["5.17"].expect.ini_belastung: ini_belastung — neither an expect key nor a query

## situations/schmerz.yaml

- [ ] L15 situations[S1].expect.conditions: conditions — neither an expect key nor a query
- [ ] L17 situations[S1].expect.talent: talent — neither an expect key nor a query
- [ ] L18 situations[S1].expect.spell: spell — neither an expect key nor a query
- [ ] L27 situations[S2].expect.conditions: conditions — neither an expect key nor a query
- [ ] L36 situations[S3].expect.conditions: conditions — neither an expect key nor a query
- [ ] L37 situations[S3].expect.requires_check: requires_check — neither an expect key nor a query
- [ ] L38 situations[S3].expect.on_failure: on_failure — neither an expect key nor a query
- [ ] L46 situations[S4].expect.conditions: conditions — neither an expect key nor a query
- [ ] L66 situations[S6].expect.conditions: conditions — neither an expect key nor a query
- [ ] L86 situations[S7].expect.states: states — neither an expect key nor a query
- [ ] L111 situations[S9].expect.states: states — neither an expect key nor a query
- [ ] L120 situations[S10].expect.states: states — neither an expect key nor a query
- [ ] L126 situations[S11].checks: checks — not a situation key in the vocabulary
- [ ] L128 situations[S11].expect.talent: talent — neither an expect key nor a query
- [ ] L129 situations[S11].expect.spell: spell — neither an expect key nor a query
- [ ] L135 situations[S12].passed: passed — not a situation key in the vocabulary

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

- [ ] L26 situations[TZ.2].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L35 situations[TZ.3].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L35 situations[TZ.3].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L45 situations[TZ.4].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L45 situations[TZ.4].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L57 situations[TZ.5].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L57 situations[TZ.5].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L62 situations[TZ.5].expect.tell: tell — neither an expect key nor a query
- [ ] L69 situations[TZ.6].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L80 situations[TZ.7].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L91 situations[TZ.8].check: check — not a situation key in the vocabulary
- [ ] L92 situations[TZ.8].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L92 situations[TZ.8].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L106 situations[TZ.9].expect.zone: zone — neither an expect key nor a query
- [ ] L107 situations[TZ.9].expect.table: table — neither an expect key nor a query
- [ ] L113 situations[TZ.10].attacker: attacker — not a situation key in the vocabulary
- [ ] L116 situations[TZ.10].expect.table: table — neither an expect key nor a query
- [ ] L117 situations[TZ.10].expect.zone: zone — neither an expect key nor a query
- [ ] L124 situations[TZ.11].attacker: attacker — not a situation key in the vocabulary
- [ ] L127 situations[TZ.11].expect.table: table — neither an expect key nor a query
- [ ] L128 situations[TZ.11].expect.zone: zone — neither an expect key nor a query
- [ ] L136 situations[TZ.12].hit: hit — not a situation key in the vocabulary
- [ ] L138 situations[TZ.12].expect.checks_first: checks_first — neither an expect key nor a query
- [ ] L142 situations[TZ.12].expect.on_failure: on_failure — neither an expect key nor a query
- [ ] L149 situations[TZ.13].sequence[0].expect.checks_first: checks_first — snake_case key, no mapping
- [ ] L152 situations[TZ.13].sequence[1].expect.checks_first: checks_first — snake_case key, no mapping
- [ ] L154 situations[TZ.13].sequence[1].expect.on_failure: on_failure — snake_case key, no mapping
- [ ] L161 situations[TZ.14].hit: hit — not a situation key in the vocabulary
- [ ] L162 situations[TZ.14].fail: fail — not a situation key in the vocabulary
- [ ] L164 situations[TZ.14].expect.loadout: loadout — neither an expect key nor a query
- [ ] L165 situations[TZ.14].expect.log: log — neither an expect key nor a query
- [ ] L166 situations[TZ.14].expect.asked: asked — neither an expect key nor a query
- [ ] L175 situations[TZ.15].expect.after: after — neither an expect key nor a query
- [ ] L184 situations[TZ.16].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L184 situations[TZ.16].choose.manoeuvre: manoeuvre — not a fact in the vocabulary
- [ ] L196 situations[TZ.17].choose.manoeuvres: manoeuvres — not a fact in the vocabulary
- [ ] L196 situations[TZ.17].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L198 situations[TZ.17].expect.excludes: excludes — neither an expect key nor a query
- [ ] L214 situations[TZ.27].choose.targetZone: targetZone — not a fact in the vocabulary
- [ ] L229 situations[TZ.20].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [ ] L230 situations[TZ.20].expect.score: score — neither an expect key nor a query
- [ ] L231 situations[TZ.20].expect.conditions: conditions — neither an expect key nor a query
- [ ] L240 situations[TZ.21].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [ ] L241 situations[TZ.21].expect.score: score — neither an expect key nor a query
- [ ] L242 situations[TZ.21].expect.conditions: conditions — neither an expect key nor a query
- [ ] L251 situations[TZ.22].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [ ] L252 situations[TZ.22].expect.score: score — neither an expect key nor a query
- [ ] L253 situations[TZ.22].expect.conditions: conditions — neither an expect key nor a query
- [ ] L265 situations[TZ.23].expect.score: score — neither an expect key nor a query
- [ ] L266 situations[TZ.23].expect.conditions: conditions — neither an expect key nor a query
- [ ] L276 situations[TZ.24].expect.not_selectable: not_selectable — neither an expect key nor a query
- [ ] L276 situations[TZ.24].expect.not_selectable[0].second_armour: second_armour — snake_case key, no mapping
- [ ] L292 situations[TZ.26].expect.rs_by_zone: rs_by_zone — neither an expect key nor a query
- [ ] L293 situations[TZ.26].expect.score: score — neither an expect key nor a query
- [ ] L294 situations[TZ.26].expect.conditions: conditions — neither an expect key nor a query

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

- situations/beidhaendiger-kampf.yaml 11.12: expects `at(with: offHand)` to be the Dolch (`weapon: Dolch`, total −6). No expect key names the piece a query is rolled with, so the weapon is now input (`loadout.other.technique: CT_3`) and a comment; the situation no longer checks which piece the app puts in the off hand, only the −6.
- situations/boronmir-neu.yaml 19.12: expects no state gained on the failed check (`states: []`) beside the log entry. No expect key says "no event of this kind"; `events: [{ logged: … }]` checks the log only, so "no state" is a comment.
- situations/boronmir-sf.yaml 14.13: expects `pa(with: shield)` total −7, result 6, with a −6 line from SA_59.SS2 ("removes schilde.SCH3"). The base 13 (`pa(with: Großschild)`) folds in SCH3's doubled bonus; the rules give the shield parry as KW2's Schilde PA 7 plus SCH3's +6 line, and SS2 is a `suppress` of that line, which lands in notApplied (reason suppressed), not as a −6 line. Faithful to the rules: base 7, no SCH3 line, total −1, result 6.
- situations/boronmir-sf.yaml 14.17: expects `pa` result 11 and `pa(with: shield)` result 13 with only the P2 and B3 lines (total 0). The bases 11 and 13 fold in SCH1's +3 and SCH3's +6; the rules add those as lines (schilde.SCH1, schilde.SCH3), so the totals would be +3 and +6, with the same results.
- situations/boronmir-neu.yaml 19.2: the same as 14.17 for Formation's +2 VW: `pa` result 12 and `pa(with: shield)` result 14 with totals 1 come from folded bases 11 / 13; the rules give SCH1's +3 and SCH3's +6 as lines of their own.

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
