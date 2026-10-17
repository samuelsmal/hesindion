# Mount in pain (issue #48) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The rules engine derives a mount's Schmerz from its breed's thresholds and applies COND_6 and Zähes Tier to it; RK14's TP line and every mount value the app shows come from that evaluation.

**Architecture:** A mount is a subject of its own: `CreatureSheet` → `Situation(creature:)` runs the unchanged COND_6 on the mount. `Engine.mountFacts(in:)` turns that evaluation into three derived facts (`mount.gs`, `mount.schmerz`, `mount.handlungsunfaehig`) that the hero's situation states. A new sheet fact `subject` (`hero` unless stated) keeps the hero's fractions (COND_6.SZ3) off a creature and the breed's thresholds off the hero.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData (app), `Packages/RulesEngine` (pure Swift, XCTest), `scripts/rulec` (Python, unittest), rule files in YAML under `specs/rules/`.

**Spec:** `docs/plans/2026-10-01-mount-schmerz-design.md`

## Global Constraints

- Every change a rule makes is shown with its cause (ADR-0018): "a rule that can apply but did not is shown as not applied, with the reason".
- Thresholds: printed value ÷ profile LeP × the mount's max LeP; "5 LeP oder weniger" stays fixed; comparison exact (Stufe I at LeP ≤ 89.5 for 137 LeP).
- Kupperus: profile 75 LeP; build 137 LeP, GS 15 (Schnell included), VW 14, AT Tritt 19 / Biss 16 / Niederreiten 19; has Zähes Tier.
- Svellttaler Kaltblut: 49/75, 33/75, 16/75. Elenviner Vollblut: 49/70, 33/70, 16/70.
- New facts (exact `facts` entries in `vocabulary.json` and `Vocabulary.swift`): `mount.gs` int derived, `mount.schmerz` int derived, `mount.handlungsunfaehig` bool derived, `subject` string sheet. New target: `vw`.
- New accessibility identifiers: `combat.mount.blockedReason`, `combat.mount.schmerz`.
- One xcodebuild-backed target at a time; never widen the destination set (AGENTS.md "Testing").
- `make rules-json` before any package or app test that reads `rules.json`.
- Commit messages end with the two attribution lines given in the session (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and the `Claude-Session:` line). Commits go to `v2/app-rework`, subject prefix `rules:`, `engine:`, `combat:`, `ui:` or `docs:`, issue number `(#48)` at the end.

## Review Focus

1. **A mount whose `Pet.type` matches no breed rule** (a custom animal, "Pferd" in the unit tests). Expected: the GS and AT stay the build's values, and the app shows "Schmerz <Name>: Schwellen unbekannt (kein Bestiarium-Eintrag)". Pinned in Task 5 (`testAMountWithoutABreedRuleHasNoThresholds`) and Task 7 (snapshot).
2. **A mount at 0 LeP or below** (LE may fall below 0, `Pools.swift`). Expected: Stufe IV, GS 0, Handlungsunfähig, no crash from the proportion terms. Pinned in Task 2 (situation `mount.10`).
3. **The LeP exactly on a scaled threshold or one above it** (decimal `times`). Expected: Stufe changes at ≤ 89 / 60 / 29 for 137 LeP, and at exactly 49 / 33 / 16 for 75 LeP. Pinned in Task 2 (situations `mount.2`–`mount.8`).
4. **The mount heals during the fight** (`MountHealingSheet`, the LP bar's +). Expected: the Stufe goes down, the root line and the buttons follow without a restart. `MountValues` caches per distinct `CreatureSheet`, so a new LE is a new key. Pinned in Task 5 (`testHealingTheMountLowersTheStufe`).
5. **The hero owns the breed rule too** (`kupperus-und-waffen.yaml`: `creatures: { svellttaler-kaltblut }` on the hero). Expected: the breed's derive does not give the *hero* Schmerz. Pinned in Task 2 (situation `mount.12`).

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `specs/rules/vocabulary.json`, `Packages/RulesEngine/Sources/RulesEngine/Vocabulary.swift` | the new facts, `vw`, `mount` situation key | 1, 4 |
| `Packages/RulesEngine/Sources/RulesEngine/Evaluation/Applicability.swift` | `subject` reads `hero` when unstated | 1 |
| `specs/rules/conditions/COND_6.yaml` | SZ3 only for the hero; SZ5 reaches `vw` | 1 |
| `specs/rules/creatures/zaehes-tier.yaml` (new) | the Zähes Tier rule | 2 |
| `specs/rules/creatures/svellttaler-kaltblut.yaml`, `elenviner-vollblut.yaml` | the scaled thresholds | 2 |
| `specs/rules/situations/reittier-schmerz.yaml` (new) | the mount as subject | 2 |
| `Packages/RulesEngine/Sources/RulesEngine/CreatureSheet.swift` (new) | `CreatureSheet`, `Situation(creature:)`, `MountFacts`, `Engine.mountFacts(in:)`, `Situation.stating(_:)` | 3 |
| `scripts/rulec/situations.py`, `Tests/RulesEngineTests/Harness/CompiledSituation.swift`, `SituationsHarnessTests.swift` | the harness `mount:` section | 4 |
| `Hesindion/RulesEngine/PetSheetMapping.swift`, `MountValues.swift` (new) | `Pet` → `CreatureSheet`, cached evaluation | 5 |
| `Hesindion/Engine/DamageModifiers.swift`, `Hesindion/Models/Hero.swift` | RK14 from the engine | 6 |
| `Hesindion/Views/CombatAttackViews.swift`, `CombatRootView.swift`, `Theme/Strings.swift` | mount AT, Stufe IV, root line | 7 |
| `Hesindion/Views/HeroDetailView.swift`, `Hesindion/RulesEngine/FactLabel.swift` | companion sheet values | 8 |
| `HesindionUITests/…`, docs | screenshot, ADR-0020, AGENTS, CHANGELOG, MIGRATION, RULINGS | 9 |

---

### Task 1: The `subject` fact, `vw`, and the hero-only SZ3

**Files:**
- Modify: `specs/rules/vocabulary.json` (`facts`, `targets`)
- Modify: `Packages/RulesEngine/Sources/RulesEngine/Vocabulary.swift:65-150` (`targets`, `facts`)
- Modify: `Packages/RulesEngine/Sources/RulesEngine/Evaluation/Applicability.swift:386-390`
- Modify: `specs/rules/conditions/COND_6.yaml` (SZ3, SZ5)
- Test: `Packages/RulesEngine/Tests/RulesEngineTests/ConditionTests.swift`

**Interfaces:**
- Produces: fact `subject` (`"hero"` | `"creature"`, owner `sheet`, unstated reads `"hero"`); facts `mount.gs` (int), `mount.schmerz` (int), `mount.handlungsunfaehig` (bool), all owner `derived`; target `vw`.

- [ ] **Step 1: Write the failing tests**

Add to `ConditionTests.swift` (it already has a `book` and Boronmir-style helpers; use `HeroSheetTests.book`):

```swift
    // Issue #48: COND_6.SZ3's fractions are the hero's ("ein Held"); a creature has its own.
    func testTheHerosFractionsGiveACreatureNoSchmerz() {
        let engine = Engine(book: HeroSheetTests.book)
        let creature = Situation(owned: [:],
                                 facts: [Fact(name: "subject", value: .string("creature"), owner: .sheet)],
                                 base: ["leMax": 40], pools: [.le: PoolState(current: 10, max: 40)])
        XCTAssertEqual(engine.evaluate(Query("level(rule: COND_6)"), in: creature).result ?? 0, 0)
    }

    func testAnUnstatedSubjectIsTheHero() {
        let engine = Engine(book: HeroSheetTests.book)
        let hero = Situation(owned: [:], facts: [], base: ["leMax": 40],
                             pools: [.le: PoolState(current: 10, max: 40)])
        XCTAssertEqual(engine.evaluate(Query("level(rule: COND_6)"), in: hero).result, 3)
    }

    func testSchmerzLowersTheVW() {
        let engine = Engine(book: HeroSheetTests.book)
        let s = Situation(owned: [:], facts: [], base: ["leMax": 40, "vw": 14],
                          pools: [.le: PoolState(current: 20, max: 40)])
        XCTAssertEqual(engine.evaluate(Query("vw"), in: s).result, 12)
    }

    func testTheMountFactsAreDerived() {
        XCTAssertEqual(Vocabulary.owner(ofFact: "mount.gs"), .derived)
        XCTAssertEqual(Vocabulary.owner(ofFact: "mount.schmerz"), .derived)
        XCTAssertEqual(Vocabulary.owner(ofFact: "mount.handlungsunfaehig"), .derived)
        XCTAssertEqual(Vocabulary.owner(ofFact: "mount.iniBase"), .sheet)
        XCTAssertEqual(Vocabulary.owner(ofFact: "subject"), .sheet)
        XCTAssertTrue(Vocabulary.targets.contains("vw"))
    }
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `make rules-json && swift test --package-path Packages/RulesEngine --filter ConditionTests`
Expected: FAIL — `testTheHerosFractionsGiveACreatureNoSchmerz` gets 3, `testSchmerzLowersTheVW` gets 14 or nil, `testTheMountFactsAreDerived` gets `.sheet`.

- [ ] **Step 3: Vocabulary**

In `specs/rules/vocabulary.json`, add `"vw"` to `targets` (keep the list sorted) and add to `facts`:

```json
"mount.gs": { "owner": "derived", "type": "int" },
"mount.handlungsunfaehig": { "owner": "derived", "type": "bool" },
"mount.schmerz": { "owner": "derived", "type": "int" },
"subject": { "owner": "sheet", "type": "string" },
```

(Match the exact shape the file uses for its other `facts` entries; look at `hero.mounted`.) Mirror both in `Vocabulary.swift`: `"vw"` in `targets` (sorted), and in `facts`:

```swift
        "mount.gs": .derived,
        "mount.handlungsunfaehig": .derived,
        "mount.schmerz": .derived,
        "subject": .sheet,
```

`VocabularyTests` compares the two files; run it in Step 6.

- [ ] **Step 4: `subject` reads `hero` when unstated**

In `Applicability.swift`, after the `rulesets` default (line 386-390), add:

```swift
        if names.contains("subject"), s.fact("subject") == nil {
            // Issue #48: a situation that states no subject is the hero's (every hero file and
            // every situation before the mount had one). `Situation(creature:)` states `creature`.
            s.facts["subject"] = Fact(name: "subject", value: .string("hero"), owner: .sheet)
        }
```

- [ ] **Step 5: COND_6**

In `specs/rules/conditions/COND_6.yaml`, SZ3's derive gets a `when`, and SZ5's first `add` reaches `vw`:

```yaml
  - id: SZ3
    …
    effects:
      - when: { subject: hero }
        derive:
          to: "level(rule: COND_6)"
          sum:
            - { of: leMax, above: leCurrent, times: 4, per: leMax, round: down, max: 3 }
            - { of: 6, above: leCurrent, max: 1 }
        ruling: schmerz-thresholds
        # (keep the existing comment) Issue #48: the fractions are the hero's ("ein Held"). A
        # creature has its own thresholds ("Schmerz +1 bei", Aufbau der Kreaturenbeschreibung),
        # which its profile derives (svellttaler-kaltblut.SK10, elenviner-vollblut.EV10).
```

```yaml
      - when: { level: [1, 2, 3] }
        add: { to: [at, pa, aw, fk, check.modifier, gs, vw], value: -1, per: level }
        # (keep the existing comment, then:) `vw` is a creature's Verteidigung: "Sonstige
        # Erschwernisse, etwa durch einen Zustand oder Status, senken den VW aber wie üblich"
        # (Aufbau der Kreaturenbeschreibung). The hero has no `vw`.
```

- [ ] **Step 6: Run the tests**

Run: `make rules-check && make rules-json && swift test --package-path Packages/RulesEngine --filter 'ConditionTests|VocabularyTests'`
Expected: PASS.

Run: `make test-rules-engine`
Expected: the summary line has the same `failed` count as before the change (0). No harness situation states `subject`, so all read `hero`.

- [ ] **Step 7: Commit**

```bash
git add specs/rules/vocabulary.json specs/rules/conditions/COND_6.yaml Packages/RulesEngine
git commit -m "rules: SZ3's fractions are the hero's; Schmerz lowers a creature's VW (#48)"
```

---

### Task 2: Zähes Tier and the breeds' scaled thresholds

**Files:**
- Create: `specs/rules/creatures/zaehes-tier.yaml`
- Modify: `specs/rules/creatures/svellttaler-kaltblut.yaml` (SK10, ruling `svellttaler-schmerz-thresholds`)
- Modify: `specs/rules/creatures/elenviner-vollblut.yaml` (EV10)
- Create: `specs/rules/situations/reittier-schmerz.yaml`
- Modify: `specs/rules/RULINGS.md`, `specs/rules/MIGRATION.md`

**Interfaces:**
- Consumes: `subject` (Task 1).
- Produces: rule `zaehes-tier` (kind `creature`); in a situation with `subject: creature` that owns `svellttaler-kaltblut` or `elenviner-vollblut`, `level(rule: COND_6)` follows the scaled thresholds.

- [ ] **Step 1: Get the page hash for Zähes Tier**

Run: `grep -n "zaehes-tier.html" specs/rules/pages.yaml`
Copy its `hash:` and `fetched:` values into the file of Step 3.

- [ ] **Step 2: Write the failing situations**

Create `specs/rules/situations/reittier-schmerz.yaml`. The `hero` section *is* the mount here: `sheet: { subject: creature }` makes the creature the subject.

```yaml
# Issue #48 — a mount in pain. DRAFT FORMAT — see ../README.md.
# Each situation's subject is the mount (`sheet: { subject: creature }`), Kupperus by his
# 2026-09-24 build (specs/heroes/…companions.json): LeP 137, GS 15 (Schnell), VW 14,
# Tritt AT 19. His breed prints "Schmerz +1 bei: 49 LeP, 33 LeP, 16 LeP, 5 LeP oder weniger" for
# 75 LeP; ruling svellttaler-kaltblut.svellttaler-schmerz-thresholds scales them to 137:
# ≤ 89.5, ≤ 60.3, ≤ 29.2, and ≤ 5 unscaled.

hero:
  creatures: { svellttaler-kaltblut: true }
  sheet: { subject: creature }
  values: { leMax: 137, gs: 15, vw: 14, "at(with: Tritt)": 19 }

situations:
  - id: mount.1
    name: Unhurt — no Schmerz
    hero: { values: { leCurrent: 137 } }
    expect:
      "level(rule: COND_6)": { result: 0 }
      gs: { result: 15 }

  - id: mount.2
    name: 90 LeP — just above the first threshold (89.5)
    hero: { values: { leCurrent: 90 } }
    expect:
      "level(rule: COND_6)": { result: 0 }

  - id: mount.3
    name: 89 LeP — Schmerz I
    hero: { values: { leCurrent: 89 } }
    expect:
      "level(rule: COND_6)": { result: 1, lines: [{ from: svellttaler-kaltblut.SK10, ruling: svellttaler-kaltblut.svellttaler-schmerz-thresholds }] }
      gs: { result: 14, lines: [{ value: -1, from: COND_6.SZ5 }] }
      vw: { result: 13 }
      "at(with: Tritt)": { result: 18 }

  - id: mount.4
    name: 61 LeP — still Schmerz I
    hero: { values: { leCurrent: 61 } }
    expect:
      "level(rule: COND_6)": { result: 1 }

  - id: mount.5
    name: 60 LeP — Schmerz II
    hero: { values: { leCurrent: 60 } }
    expect:
      "level(rule: COND_6)": { result: 2 }
      gs: { result: 13 }

  - id: mount.6
    name: 30 LeP — still Schmerz II
    hero: { values: { leCurrent: 30 } }
    expect:
      "level(rule: COND_6)": { result: 2 }

  - id: mount.7
    name: 29 LeP — Schmerz III
    hero: { values: { leCurrent: 29 } }
    expect:
      "level(rule: COND_6)": { result: 3 }
      gs: { result: 12 }

  - id: mount.8
    name: 75 LeP profile, exactly 49 LeP — Schmerz I (the printed threshold itself)
    hero: { values: { leMax: 75, leCurrent: 49 } }
    expect:
      "level(rule: COND_6)": { result: 1 }

  - id: mount.9
    name: 5 LeP — Schmerz IV, GS 0, Handlungsunfähig
    hero: { values: { leCurrent: 5 } }
    expect:
      "level(rule: COND_6)": { result: 4 }
      gs: { result: 0 }
      events: [{ gained: STATE_8, from: COND_6.SZ5 }]

  - id: mount.10
    name: −3 LeP — still Schmerz IV
    hero: { values: { leCurrent: -3 } }
    expect:
      "level(rule: COND_6)": { result: 4 }
      gs: { result: 0 }

  - id: mount.11
    name: Zähes Tier at 60 LeP — has II, acts at I
    hero: { creatures: { svellttaler-kaltblut: true, zaehes-tier: true }, values: { leCurrent: 60 } }
    expect:
      "level(rule: COND_6)": { result: 1, lines: [{ kind: levelAs, value: 1, from: zaehes-tier.ZT1 }] }
      gs: { result: 14, lines: [{ value: -1, from: COND_6.SZ5, via: [zaehes-tier.ZT1] }] }

  - id: mount.12
    name: The hero owns the breed — the breed gives the hero no Schmerz
    hero: { sheet: { subject: hero }, values: { leMax: 40, leCurrent: 40 } }
    expect:
      "level(rule: COND_6)": { result: 0 }

  - id: mount.13
    name: Zähes Tier at 89 LeP — Stufe I counts as none
    hero: { creatures: { svellttaler-kaltblut: true, zaehes-tier: true }, values: { leCurrent: 89 } }
    expect:
      gs: { result: 15 }

  - id: mount.14
    name: Zähes Tier at 5 LeP — Handlungsunfähig nevertheless
    hero: { creatures: { svellttaler-kaltblut: true, zaehes-tier: true }, values: { leCurrent: 5 } }
    expect:
      events: [{ gained: STATE_8, from: COND_6.SZ5, via: [zaehes-tier.ZT3] }]

  - id: mount.15
    name: Elenviner Vollblut, 70 LeP profile, 49 LeP — Schmerz I
    hero: { creatures: { elenviner-vollblut: true }, values: { leMax: 70, leCurrent: 49 } }
    expect:
      "level(rule: COND_6)": { result: 1, lines: [{ from: elenviner-vollblut.EV10 }] }
```

Notes for the implementer:
- `creatures: { a: true, b: true }` in a situation's `hero` replaces the file-level map whole (`situations.py` header: "replaced whole by a later layer"), so mount.11/13/14 list the breed again.
- If the matcher wants `total` rather than `result` for a target, follow `lebensenergie.yaml` 15.6–15.7, which this file copies.

- [ ] **Step 3: Write the Zähes Tier rule**

Create `specs/rules/creatures/zaehes-tier.yaml`, modelled on `advantages/ADV_49.yaml`. `hero.levelOf.COND_6` is the subject's Stufe (the mount's, when the mount is the subject).

```yaml
# DRAFT FORMAT — see ../README.md.
# A Tiervorteil, kind `creature`: the animal version of Zäher Hund (ADV_49). Its owner is the
# animal; it acts in the animal's own evaluation (the mount as subject, issue #48), where
# `hero.levelOf.COND_6` is the animal's Stufe.
id: zaehes-tier
name: Zähes Tier
kind: creature
group: Vorteile (Tiere)
source:
  url: https://dsa.ulisses-regelwiki.de/vor-und-nachteile/tiervor-und-nachteile/vorteile-tiere/zaehes-tier.html
  book: Aventurische Tiergefährten
  page: 119
  checked: 2026-10-01
  hash: <the hash from Step 1>
# Kupperus bought it (companions.json, 12 AP).

clauses:
  - id: ZT1
    text: >
      Regel: Dieser Vorteil sorgt dafür, dass das Tier die Auswirkungen der höchsten Stufe des
      Zustands Schmerz ignorieren darf. Es erleidet lediglich die Auswirkungen der nächstniedrigeren
      Stufe.
    effects:
      - when: { hero.levelOf.COND_6: [2, 3] }
        useLevel: { rule: COND_6, as: "level - 1" }
        ruling: ADV_49.zaeher-hund-counts

  - id: ZT2
    text: >
      Wenn es also beispielsweise drei Stufen Schmerz erlitten hat, gelten für das Tier nur die
      Auswirkungen von Stufe II.
    none: the page's own example of ZT1 (reittier-schmerz mount.11 is the same rule at II)

  - id: ZT3
    text: Bei Schmerz Stufe IV wird das Tier dennoch Handlungsunfähig.
    effects:
      - when: { hero.levelOf.COND_6: 4 }
        useLevel: { rule: COND_6, as: level }

  - id: ZT4
    text: Schmerz Stufe I wird so behandelt, als hätte es keine Stufe Schmerz.
    effects:
      - when: { hero.levelOf.COND_6: 1 }
        useLevel: { rule: COND_6, as: 0 }
        ruling: ADV_49.zaeher-hund-counts

  - id: ZT5
    text: >
      Dieser Vorteil lässt sich mit dem Vorteil Zäher Hund kombinieren, wenn dieser bei dem Tier als
      automatischer oder empfohlener Vorteil aufgeführt ist.
    unencoded: >
      no animal in the app has Zäher Hund; how two useLevels on COND_6 combine is open until one does

  - id: ZT6
    text: "Voraussetzungen: kein Nachteil Zerbrechlich oder Zerbrechliches Tier"
    none: purchase prerequisite of the animal

  - id: ZT7
    text: "AP-Wert: 12 Abenteuerpunkte"
    none: cost
```

Check the page number and the exact clause texts against the page (`curl` it as in the brainstorming session) before `reviewed:` is added; leave `reviewed:` out — the owner reviews with `make rules-review`.

- [ ] **Step 4: SK10 with the scaled thresholds**

Replace SK10's four effects in `svellttaler-kaltblut.yaml`. One `proportion` term per threshold: `⌊(leMax − leCurrent) × times / leMax⌋`, at most 1, where `times = profile LeP ÷ (profile LeP − printed threshold)`. Then Stufe I holds exactly when `leCurrent ≤ printed / profile × leMax`.

```yaml
  - id: SK10
    text: "Schmerz +1 bei: 49 LeP, 33 LeP, 16 LeP, 5 LeP oder weniger"
    effects:
      - when: { subject: creature }
        derive:
          to: "level(rule: COND_6)"
          sum:
            - { of: leMax, above: leCurrent, times: 2.8846153846153846, per: leMax, round: down, max: 1 }
            - { of: leMax, above: leCurrent, times: 1.7857142857142858, per: leMax, round: down, max: 1 }
            - { of: leMax, above: leCurrent, times: 1.2711864406779663, per: leMax, round: down, max: 1 }
            - { of: 6, above: leCurrent, max: 1 }
        ruling: svellttaler-schmerz-thresholds
        # The printed thresholds are fractions of the profile's 75 LeP, scaled to the mount's own
        # max LeP (ruling svellttaler-schmerz-thresholds): Stufe I at LeP ≤ 49/75 × leMax, i.e.
        # once (leMax − LeP) ≥ 26/75 × leMax; times = 75/26, 75/42, 75/59. Compared exactly, as
        # COND_6.schmerz-thresholds for the hero; the engine's rounding snaps 0.9999999999 to 1
        # (Values.round), which reittier-schmerz mount.8 (exactly 49 of 75) holds. "5 LeP oder
        # weniger" is not scaled: COND_6.SZ3's own term. Only for the creature as subject
        # (`subject: creature`): a hero who owns the profile gets no Schmerz from it (mount.12).
```

In the ruling `svellttaler-schmerz-thresholds`, replace `notes:` and widen `appliesTo`:

```yaml
    appliesTo: [SK10, elenviner-vollblut.EV10]
    notes: >
      The printed 49/33/16 are fractions of the profile's 75 LeP (they are ¾, ½, ¼ of 65, so the
      profile's LeP or its thresholds are a misprint; the owner's answer keeps the printed
      fractions). A mount whose max LeP grew (Kupperus: 137 after Heldenwuchs, Kampftier and 16
      bought) has its thresholds scaled: ≤ 89.5, ≤ 60.3, ≤ 29.2; "5 LeP oder weniger" stays. The
      owner confirmed on 2026-10-01 that the same holds for every horse with printed thresholds
      (elenviner-vollblut.EV10: 49/70, 33/70, 16/70). Issue #48.
```

Keep the `appliesTo` cross-reference form the other rulings use; if a ruling may not name another file's clause, put the EV10 note on EV10's effect instead (`ruling: svellttaler-kaltblut.svellttaler-schmerz-thresholds`).

- [ ] **Step 5: EV10**

In `elenviner-vollblut.yaml`, replace EV10's `unencoded:` with:

```yaml
    effects:
      - when: { subject: creature }
        derive:
          to: "level(rule: COND_6)"
          sum:
            - { of: leMax, above: leCurrent, times: 3.3333333333333335, per: leMax, round: down, max: 1 }
            - { of: leMax, above: leCurrent, times: 1.8918918918918919, per: leMax, round: down, max: 1 }
            - { of: leMax, above: leCurrent, times: 1.2962962962962963, per: leMax, round: down, max: 1 }
            - { of: 6, above: leCurrent, max: 1 }
        ruling: svellttaler-kaltblut.svellttaler-schmerz-thresholds
        # As svellttaler-kaltblut.SK10, for the profile's 70 LeP: times = 70/21, 70/37, 70/54.
```

- [ ] **Step 6: RULINGS.md and MIGRATION.md**

Run: `make test-rules-review` — it runs `RULINGS.md --check` and names what to regenerate. Follow its message (the ruling's row changes). Append to `MIGRATION.md`, under the creature section:

```markdown
- svellttaler-kaltblut.SK10 (issue #48): the four `add: { to: "mount.level(rule: COND_6)" }` (a target nothing read) are one `derive` of `level(rule: COND_6)` for the creature as subject, its printed thresholds scaled to the mount's max LeP (ruling svellttaler-schmerz-thresholds, notes corrected); elenviner-vollblut.EV10 encoded the same way; zaehes-tier newly drafted; COND_6.SZ3 `when: { subject: hero }`, SZ5 reaches `vw`.
```

- [ ] **Step 7: Run the harness**

Run: `make rules-check && make test-rules-engine RULES_FILES=reittier-schmerz,lebensenergie`
Expected: every `mount.*` situation passes; lebensenergie unchanged.

Run: `make test-rules-engine`
Expected: `failed` 0.

- [ ] **Step 8: Commit**

```bash
git add specs/rules
git commit -m "rules: a mount's Schmerz from its breed's scaled thresholds; Zähes Tier (#48)"
```

---

### Task 3: `CreatureSheet` and the link to the hero

**Files:**
- Create: `Packages/RulesEngine/Sources/RulesEngine/CreatureSheet.swift`
- Test: `Packages/RulesEngine/Tests/RulesEngineTests/CreatureSheetTests.swift`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:

```swift
public struct CreatureSheet: Codable, Hashable, Sendable {
    public var owned: [String: OwnedRule]
    public var gs: Int
    public var leMax: Int
    public var leCurrent: Int
    public var vw: Int?
    public var attacks: [String: Int]
    public init(owned: [String: OwnedRule], gs: Int, leMax: Int, leCurrent: Int, vw: Int? = nil, attacks: [String: Int] = [:])
}
extension Situation {
    public init(creature: CreatureSheet)
    public func stating(_ facts: [Fact]) -> Situation
}
public struct MountFacts: Sendable {
    public let gs: Breakdown
    public let schmerzBreakdown: Breakdown
    public let handlungsunfaehig: Bool
    public var schmerz: Int { get }   // the Stufe the mount has (base line)
    public var facts: [Fact] { get }
}
extension Engine {
    public func mountFacts(in mount: Situation) -> MountFacts
}
```

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import RulesEngine

/// Issue #48: the mount as a subject of its own, and the three facts it hands the hero.
final class CreatureSheetTests: XCTestCase {
    let engine = Engine(book: HeroSheetTests.book)

    static func kupperus(le: Int, advantages: [String] = ["zaehes-tier"]) -> CreatureSheet {
        var owned: [String: OwnedRule] = ["svellttaler-kaltblut": .init()]
        for a in advantages { owned[a] = .init() }
        return CreatureSheet(owned: owned, gs: 15, leMax: 137, leCurrent: le, vw: 14,
                             attacks: ["Tritt": 19, "Biss": 16, "Niederreiten": 19])
    }

    func testTheCreatureIsTheSubject() {
        let s = Situation(creature: Self.kupperus(le: 137))
        XCTAssertEqual(s.facts["subject"]?.value, .string("creature"))
        XCTAssertEqual(s.base["gs"], 15)
        XCTAssertEqual(s.base["at(with: Tritt)"], 19)
        XCTAssertEqual(s.pools[.le], PoolState(current: 137, max: 137))
    }

    func testKupperusAt60LePHasSchmerzIIAndActsAtI() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60)))
        XCTAssertEqual(m.schmerz, 2)                       // has II
        XCTAssertEqual(m.schmerzBreakdown.result, 1)       // acts at I (Zähes Tier)
        XCTAssertEqual(m.gs.result, 14)
        XCTAssertFalse(m.handlungsunfaehig)
    }

    func testWithoutZaehesTierTheGSFallsByTheFullStufe() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60, advantages: [])))
        XCTAssertEqual(m.gs.result, 13)
    }

    func testAt5LePTheMountIsHandlungsunfaehig() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 5)))
        XCTAssertEqual(m.schmerz, 4)
        XCTAssertEqual(m.gs.result, 0)
        XCTAssertTrue(m.handlungsunfaehig)
    }

    func testTheFactsAreDerived() {
        let facts = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60))).facts
        XCTAssertEqual(Set(facts.map(\.name)), ["mount.gs", "mount.schmerz", "mount.handlungsunfaehig"])
        XCTAssertTrue(facts.allSatisfy { $0.owner == .derived })
        XCTAssertEqual(facts.first { $0.name == "mount.gs" }?.value, .int(14))
    }

    /// RK14 reads the stated `mount.gs`, not the profile's `provide mount.gs: 12`.
    func testTheChargeReadsTheMountsCurrentGS() {
        let mount = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60, advantages: [])))
        var sheet = HeroSheetTests.boronmir()
        sheet.owned["SA_43"] = .init()
        sheet.owned["svellttaler-kaltblut"] = .init()
        let charge = Situation(sheet: sheet).stating(mount.facts + [
            Fact(name: "hero.mounted", value: .bool(true), owner: .loadout),
            Fact(name: "choice.order", value: .string("sturmangriffZuPferd"), owner: .player),
            Fact(name: "action.gait", value: .string("galopp"), owner: .player),
            Fact(name: "action.attack", value: .string("hit"), owner: .player),
        ])
        let rk14 = engine.evaluate(Query("tp"), in: charge).lines.filter { $0.origin?.rule == "reiterkampf" }
        XCTAssertEqual(rk14.map(\.value), [9])   // 2 + ⌈13/2⌉
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `swift test --package-path Packages/RulesEngine --filter CreatureSheetTests`
Expected: FAIL — `CreatureSheet` is not defined.

- [ ] **Step 3: Implement**

Create `CreatureSheet.swift`:

```swift
import Foundation

/// A creature as the subject of its own evaluation (issue #48, ADR-0020): the mount's
/// `HeroSheet`. Its Zustände are the rules' own — COND_6 runs on it unchanged — and its profile
/// rule (`svellttaler-kaltblut`) gives the Schmerz thresholds the hero's fractions do not.
public struct CreatureSheet: Codable, Hashable, Sendable {
    /// The profile rule and the animal advantages with a rule file (`zaehes-tier`), by rule id.
    public var owned: [String: OwnedRule]
    /// The build's values: the base of `gs`, `leMax`, `vw` and `at(with: <attack>)`.
    public var gs: Int
    public var leMax: Int
    public var leCurrent: Int
    public var vw: Int?
    /// Attack name → AT.
    public var attacks: [String: Int]

    public init(owned: [String: OwnedRule], gs: Int, leMax: Int, leCurrent: Int, vw: Int? = nil,
                attacks: [String: Int] = [:]) {
        self.owned = owned; self.gs = gs; self.leMax = leMax; self.leCurrent = leCurrent
        self.vw = vw; self.attacks = attacks
    }
}

extension Situation {
    /// The creature's situation: `subject: creature`, the build's values as the base, the
    /// current LE as the `le` pool (R39).
    public init(creature c: CreatureSheet) {
        var base = ["gs": c.gs, "leMax": c.leMax]
        if let vw = c.vw { base["vw"] = vw }
        for (name, at) in c.attacks { base["at(with: \(name))"] = at }
        self.init(owned: c.owned,
                  facts: [Fact(name: "subject", value: .string("creature"), owner: .sheet)],
                  base: base,
                  pools: [.le: PoolState(current: c.leCurrent, max: c.leMax)])
    }

    /// This situation with `facts` stated (a stated fact replaces one of the same name).
    public func stating(_ facts: [Fact]) -> Situation {
        var s = self
        for f in facts { s.state(f) }
        return s
    }
}

/// What the mount's evaluation hands the hero's: the three `mount.*` facts, and the breakdowns
/// they come from, for display.
public struct MountFacts: Sendable {
    public let gs: Breakdown
    /// The `level(rule: COND_6)` breakdown. Its result is the Stufe the mount *acts at* (after
    /// Zähes Tier's `levelAs` line, lebensenergie 15.6); its base line is the Stufe it *has*.
    public let schmerzBreakdown: Breakdown
    public let handlungsunfaehig: Bool

    /// The Stufe the mount has, before Zähes Tier (ruling ADV_49.zaeher-hund-counts: `useLevel`
    /// changes the Stufe acted at only).
    public var schmerz: Int { schmerzBreakdown.lines.first { $0.kind == .base }?.value ?? 0 }

    public var facts: [Fact] {
        var out: [Fact] = []
        if let v = gs.result { out.append(Fact(name: "mount.gs", value: .int(v), owner: .derived)) }
        out.append(Fact(name: "mount.schmerz", value: .int(schmerz), owner: .derived))
        out.append(Fact(name: "mount.handlungsunfaehig", value: .bool(handlungsunfaehig), owner: .derived))
        return out
    }
}

extension Engine {
    /// The mount's `gs` and Stufe of Schmerz, and whether settling its situation gains
    /// Handlungsunfähig (STATE_8: COND_6.SZ5 at Stufe IV, Zähes Tier or not).
    public func mountFacts(in mount: Situation) -> MountFacts {
        let settled = ActionLayer(engine: self).perform(.settle, in: mount)
        let gained = settled.events.contains { $0.kind == .gained && $0.rule == "STATE_8" }
        return MountFacts(gs: evaluate(Query("gs"), in: mount),
                          schmerzBreakdown: evaluate(Query("level(rule: COND_6)"), in: mount),
                          handlungsunfaehig: gained)
    }
}
```

`Situation.state(_:)` is used in `Situation.init`; if it is `private`, make it internal. Check two names against the package: the event kind's case (`EventKind` in `Actions/Event.swift`; the harness writes it as `gained`) and the line kind's case (`LineKind` in `Breakdown.swift`; the harness writes `base` and `levelAs`). With no Schmerz at all, the breakdown has no base line and `schmerz` is 0.

- [ ] **Step 4: Run the tests**

Run: `swift test --package-path Packages/RulesEngine --filter CreatureSheetTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/RulesEngine
git commit -m "engine: a creature is a subject of its own; its mount facts for the hero (#48)"
```

---

### Task 4: The harness `mount:` section

**Files:**
- Modify: `specs/rules/vocabulary.json` (`situationKeys`, `situationFileKeys`: add `mount`)
- Modify: `scripts/rulec/situations.py` (`compile`, `situation`)
- Test: `scripts/rulec/test_situations.py` (or the existing rulec test that covers `situation()`; find it with `grep -ln "def test" scripts/rulec/test_*.py | xargs grep -l situation`)
- Modify: `Packages/RulesEngine/Tests/RulesEngineTests/Harness/CompiledSituation.swift`
- Modify: `Packages/RulesEngine/Tests/RulesEngineTests/SituationsHarnessTests.swift:107`
- Modify: `specs/rules/situations/reiterkampf.yaml`, `specs/rules/situations/kupperus-und-waffen.yaml`

**Interfaces:**
- Consumes: `Engine.mountFacts(in:)`, `Situation.stating(_:)` (Task 3).
- Produces: a compiled situation's optional `"mount": {owned, facts, base}`, the mount's situation; `CompiledSituation.mount: Situation?`.

- [ ] **Step 1: Write the failing rulec test**

```python
    def test_a_mount_section_compiles_to_the_mounts_own_situation(self):
        out = self.compile_one("""
mount: { creatures: { svellttaler-kaltblut: true }, values: { gs: 12, leMax: 75, leCurrent: 75 } }
situations:
  - id: m.1
    loadout: { hero.mounted: true }
    expect: { tp: { total: 0 } }
""")
        m = out["mount"]
        self.assertEqual(m["owned"], {"svellttaler-kaltblut": {"level": 1}})
        self.assertEqual(m["base"], {"gs": 12, "leMax": 75, "leCurrent": 75})
        self.assertIn({"name": "subject", "value": "creature", "owner": "sheet"}, m["facts"])
```

Use the helper the existing situations tests use to compile a YAML string (`compile_one` stands for it; match its real name).

- [ ] **Step 2: Run it to see it fail**

Run: `make test-rulec`
Expected: FAIL — `unknown key mount`.

- [ ] **Step 3: Compile the section**

In `vocabulary.json`, add `"mount"` to `situationKeys` and `situationFileKeys`. In `situations.py`:
- In `compile` (line 162), read the file-level `mount` the way it reads `hero` (`self.hero(doc["mount"], line)`) into `file_mount`, and pass it to `situation(...)`.
- In `situation(...)`, after `layer = …`:

```python
        mount = None
        if "mount" in s or file_mount is not None:
            m_layer = _merge(file_mount or _empty_layer(), self.hero(s["mount"], _line(s, "mount"))) if "mount" in s else file_mount
            m_owned = {rid: e for m in m_layer["owned"].values() for rid, e in m.items()}
            m_facts = {"subject": {"name": "subject", "value": "creature", "owner": "sheet"}}
            for name, n in m_layer["sheet"].items():
                m_facts[name] = {"name": name, "value": n, "owner": "sheet"}
            mount = {"owned": m_owned, "facts": [m_facts[k] for k in sorted(m_facts)],
                     "base": dict(m_layer["values"])}
```

and add `"mount": mount` to the returned dict. The mount's rulings count toward `pending` the way the hero's do: add the mount's owned ids to `owned` only for the reach walk (`ref["rule"] in owned or ref["rule"] in m_owned`).

- [ ] **Step 4: The harness states the mount's facts**

In `CompiledSituation.swift`: add `var mount: Situation?` and the coding key `mount`; decode it with `try c.decodeIfPresent(Situation.self, forKey: .mount)`. Give the mount the same `leCurrent` → pool step `engineSituation` gives the hero (factor that loop into a `static func withPools(_ s: Situation) -> Situation` and call it for both).

In `SituationsHarnessTests.judge`, first line:

```swift
        var s = s
        if let mount = s.mount {
            // Issue #48: the mount is evaluated as its own subject; the hero reads its facts.
            s.situation = s.situation.stating(engine.mountFacts(in: CompiledSituation.withPools(mount)).facts)
        }
```

(`situation` must be `var`; it is.)

- [ ] **Step 5: Move the stated `mount.gs`**

`reiterkampf.yaml` line 14: drop `mount.gs: 12` from `hero.values` and add a file-level

```yaml
mount: { values: { gs: 12, leMax: 40, leCurrent: 40 } }   # a Kriegspferd, unhurt; no profile rule
```

Situation 5.11: replace `values: { mount.gs: 11 }` with `mount: { values: { gs: 11 } }` (keeping `hero: { abilities: { SA_43: 1 } }`). Add after 5.11:

```yaml
  - id: "5.12"
    name: Sturmangriff zu Pferd, Kupperus at 60 LeP — the mount's current GS (issue #48)
    hero: { abilities: { SA_43: 1 } }
    mount: { creatures: { svellttaler-kaltblut: true }, values: { gs: 15, leMax: 137, leCurrent: 60 } }
    loadout: { hero.mounted: true }
    choose: { choice.order: sturmangriffZuPferd, action.gait: galopp, action.attack: hit }
    expect:
      tp: { total: 9, lines: [{ value: 9, from: reiterkampf.RK14, ruling: round-up }] }   # 2 + ⌈13/2⌉, GS 15 − 2 Schmerz II
```

`kupperus-und-waffen.yaml` line 54: drop `mount.gs: 12`; add a file-level `mount: { creatures: { svellttaler-kaltblut: true }, values: { gs: 12, leMax: 75, leCurrent: 75 } }`. Update the header comment lines 29-31 that say `mount.gs` is a stated value.

- [ ] **Step 6: Run everything that compiles or runs situations**

Run: `make test-rulec && make rules-check && make test-rules-engine`
Expected: PASS; 5.10, 5.11, 18.8 unchanged; 5.12 passes. If a listed conflict's fingerprints moved, re-record with `make test-rules-engine RECORD_CONFLICT_FINGERPRINTS=1` and commit the JSON.

- [ ] **Step 7: Commit**

```bash
git add specs/rules scripts/rulec Packages/RulesEngine
git commit -m "rules: a situation states its mount, which the harness evaluates as its own subject (#48)"
```

---

### Task 5: `PetSheetMapping` and `MountValues` (app)

**Files:**
- Create: `Hesindion/RulesEngine/PetSheetMapping.swift`
- Create: `Hesindion/RulesEngine/MountValues.swift`
- Test: `HesindionTests/MountValuesTests.swift`

**Interfaces:**
- Consumes: `CreatureSheet`, `Situation(creature:)`, `Engine.mountFacts(in:)`, `MountFacts` (Task 3); `SheetValue` (`SheetValues.swift`).
- Produces:

```swift
enum PetSheetMapping {
    /// nil `breed` when no creature rule has `Pet.type` as its name.
    static func sheet(for pet: Pet, book: RuleBook?) -> (sheet: CreatureSheet, breed: String?)
}
@MainActor final class MountValues {
    static func of(_ pet: Pet) -> MountValues?
    let hasBreedRule: Bool
    var facts: MountFacts { get }
    var gs: SheetValue { get }
    var schmerz: Int { get }
    var handlungsunfaehig: Bool { get }
    var vw: SheetValue? { get }
    func at(with attack: String) -> SheetValue?
}
```

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// Issue #48: the mount's values come from its own engine evaluation.
@MainActor
final class MountValuesTests: XCTestCase {
    private var context: ModelContext!

    override func setUpWithError() throws {
        guard RulesEngineStore.shared != nil else { throw XCTSkip("rules.json unavailable") }
        context = ModelContext(try TestData.makeContainer())
    }

    private func kupperus(le: Int, type: String = "Svellttaler Kaltblut",
                          advantages: [String] = ["Zähes Tier"]) -> Pet {
        let pet = Pet(
            petId: "PET_1", name: "Kupperus", size: 1.9, type: type,
            attributes: PetAttributes(mu: 15, kl: 10, inValue: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28),
            lifeEnergy: 137, currentLifeEnergy: le, spirit: 0, toughness: 0, initiative: "15+1W6", speed: 15,
            attack: "Tritt", damage: "1W6+8", reach: "mittel", actions: 1,
            talents: "", skills: "", notes: "")
        pet.defense = 14
        pet.advantages = advantages
        pet.attacks = [PetAttack(name: "Tritt", at: 19, damage: "1W6+8", reach: "mittel"),
                       PetAttack(name: "Niederreiten", at: 19, damage: "2W6+7", reach: "mittel")]
        context.insert(pet)
        return pet
    }

    func testTheBreedIsFoundByItsName() {
        let mapped = PetSheetMapping.sheet(for: kupperus(le: 137), book: RulesEngineStore.shared?.engine.book)
        XCTAssertEqual(mapped.breed, "svellttaler-kaltblut")
        XCTAssertNotNil(mapped.sheet.owned["zaehes-tier"])
        XCTAssertEqual(mapped.sheet.attacks["Niederreiten"], 19)
    }

    func testKupperusAt60LeP() throws {
        let v = try XCTUnwrap(MountValues.of(kupperus(le: 60)))
        XCTAssertEqual(v.schmerz, 2)
        XCTAssertEqual(v.gs.result, 14)               // Zähes Tier: acts at I
        XCTAssertEqual(v.at(with: "Tritt")?.result, 18)
        XCTAssertEqual(v.vw?.result, 13)
        XCTAssertFalse(v.handlungsunfaehig)
    }

    func testAMountWithoutABreedRuleHasNoThresholds() throws {
        let v = try XCTUnwrap(MountValues.of(kupperus(le: 10, type: "Pferd")))
        XCTAssertFalse(v.hasBreedRule)
        XCTAssertEqual(v.schmerz, 0)
        XCTAssertEqual(v.gs.result, 15)
    }

    func testHealingTheMountLowersTheStufe() throws {
        let pet = kupperus(le: 29)
        XCTAssertEqual(MountValues.of(pet)?.schmerz, 3)
        pet.currentLifeEnergy = 100
        XCTAssertEqual(MountValues.of(pet)?.schmerz, 0)
    }
}
```

Check `Pet.init`'s real parameter list (`Pet.swift:100-130`) and adjust the call; `currentLifeEnergy:` is a parameter there.

- [ ] **Step 2: Run them to see them fail**

Run: `make test-only ONLY=HesindionTests/MountValuesTests`
Expected: FAIL — `PetSheetMapping` is not defined.

- [ ] **Step 3: Implement `PetSheetMapping`**

```swift
import Foundation
import RulesEngine

/// `Pet` → `CreatureSheet` (issue #48): the only code that knows both. The breed is the creature
/// rule whose name is the export's type (`Pet` has no breed field; #49 covers the import); the
/// animal advantages are the creature rules named in `Pet.advantages`.
enum PetSheetMapping {
    static func sheet(for pet: Pet, book: RuleBook? = RulesEngineStore.shared?.engine.book)
        -> (sheet: CreatureSheet, breed: String?) {
        let creatures = book?.rules.values.filter { $0.kind == .creature } ?? []
        let breed = creatures.first { $0.name == pet.type && $0.group == nil }?.id
        var owned: [String: OwnedRule] = [:]
        if let breed { owned[breed] = OwnedRule() }
        for name in pet.advantages {
            if let rule = creatures.first(where: { $0.name == name && $0.group == "Vorteile (Tiere)" }) {
                owned[rule.id] = OwnedRule()
            }
        }
        let attacks = Dictionary(pet.attacks.map { ($0.name, $0.at) }, uniquingKeysWith: { a, _ in a })
        let sheet = CreatureSheet(owned: owned, gs: pet.speed, leMax: pet.lifeEnergy,
                                  leCurrent: pet.currentLifeEnergy, vw: pet.defense, attacks: attacks)
        return (sheet, breed)
    }
}
```

Check the `Rule` model's field names (`Model/Rule.swift`: `id`, `name`, `kind`, `group`). If `group` is not decoded, tell a profile from an advantage by the profile's `provides:` (a profile has one) or by the rule ids the app knows; keep the check in this one function.

- [ ] **Step 4: Implement `MountValues`**

```swift
import Foundation
import RulesEngine

/// The mount's values from its own engine evaluation (issue #48), as `SheetValues` is the
/// hero's: one instance per distinct `CreatureSheet`, so a hit or a heal is a new evaluation.
@MainActor
final class MountValues {
    let sheet: CreatureSheet
    let hasBreedRule: Bool
    private let engine: Engine
    private let situation: RulesEngine.Situation
    private var memo: [String: SheetValue] = [:]

    private init(sheet: CreatureSheet, hasBreedRule: Bool, engine: Engine) {
        self.sheet = sheet
        self.hasBreedRule = hasBreedRule
        self.engine = engine
        self.situation = RulesEngine.Situation(creature: sheet)
    }

    private static var cache: [ObjectIdentifier: MountValues] = [:]

    static func of(_ pet: Pet) -> MountValues? {
        guard let store = RulesEngineStore.shared else { return nil }
        let mapped = PetSheetMapping.sheet(for: pet, book: store.engine.book)
        let key = ObjectIdentifier(pet)
        if let hit = cache[key], hit.sheet == mapped.sheet { return hit }
        let values = MountValues(sheet: mapped.sheet, hasBreedRule: mapped.breed != nil, engine: store.engine)
        cache[key] = values
        return values
    }

    private(set) lazy var facts: MountFacts = engine.mountFacts(in: situation)

    var gs: SheetValue { SheetValue(breakdown: facts.gs) }
    var schmerz: Int { facts.schmerz }
    var handlungsunfaehig: Bool { facts.handlungsunfaehig }
    var vw: SheetValue? { sheet.vw == nil ? nil : value("vw") }

    func at(with attack: String) -> SheetValue? {
        sheet.attacks[attack] == nil ? nil : value("at(with: \(attack))")
    }

    private func value(_ query: String) -> SheetValue {
        if let hit = memo[query] { return hit }
        let v = SheetValue(breakdown: engine.evaluate(Query(query), in: situation))
        memo[query] = v
        return v
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `make test-only ONLY=HesindionTests/MountValuesTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Hesindion/RulesEngine HesindionTests/MountValuesTests.swift
git commit -m "engine: the mount's values come from its own evaluation (#48)"
```

---

### Task 6: The Sturmangriff zu Pferd TP from RK14

**Files:**
- Modify: `Hesindion/Engine/DamageModifiers.swift:27-38`
- Modify: `Hesindion/Models/Hero.swift:950-964` (remove `mountGS`, `sturmangriffHalfMountGS`, `sturmangriffDamageBonus`)
- Modify: `Hesindion/Views/CombatAttackViews.swift:260-280` (`sturmangriffZuPferdButton` subtitle)
- Modify: `Hesindion/Theme/Strings.swift:295-297, 1150-1152`
- Test: `HesindionTests/DamageModifiersTests.swift:120-170`, `HesindionTests/MountSelectionTests.swift`

**Interfaces:**
- Consumes: `MountValues.of(_:)`, `MountValues.facts` (Task 5); `HeroSheetMapping.sheet(for:)`; `Situation.stating(_:)` (Task 3).
- Produces: `DamageModifiers.sturmangriffLine(hero: Hero) -> ModifierLine?` — the RK14 line, `nil` without a mount or without the rules.

- [ ] **Step 1: Write the failing tests**

Replace the two Sturmangriff tests in `DamageModifiersTests.swift`:

```swift
    /// RK14 from the engine: 2 + ⌈GS/2⌉ of the mount, one line, its GS the mount's current one.
    func testSturmangriffIsRK14WithTheMountsGS() throws {
        try XCTSkipIf(RulesEngineStore.shared == nil, "rules.json unavailable")
        let rider = riderWithMount(speed: 12)
        rider.combatSpecialAbilities.append(HeroTrait(ruleId: "SA_43", name: "Berittener Kampf"))
        var charge = Situation(hero: rider, domain: .damage)
        charge.maneuver = .sturmangriff
        charge.round.mounted = true
        let line = DamageModifiers.lines(situation: charge).first { $0.source.hasPrefix(L("source.sturmangriff")) }
        XCTAssertEqual(line?.value, 8)
        XCTAssertEqual(line?.source, String(format: L("source.sturmangriff.rk14"), "Kupperus", 12))
    }

    func testSturmangriffWithAMountInPain() throws {
        try XCTSkipIf(RulesEngineStore.shared == nil, "rules.json unavailable")
        let rider = riderWithMount(speed: 15, type: "Svellttaler Kaltblut", lifeEnergy: 137, current: 60)
        rider.combatSpecialAbilities.append(HeroTrait(ruleId: "SA_43", name: "Berittener Kampf"))
        var charge = Situation(hero: rider, domain: .damage)
        charge.maneuver = .sturmangriff
        charge.round.mounted = true
        let line = DamageModifiers.lines(situation: charge).first { $0.source.hasPrefix(L("source.sturmangriff")) }
        XCTAssertEqual(line?.value, 9)            // 2 + ⌈13/2⌉: GS 15, Schmerz II
        XCTAssertEqual(line?.source, String(format: L("source.sturmangriff.rk14"), "Kupperus", 13))
    }
```

Extend `riderWithMount(speed:)` with `type: String = "Pferd", lifeEnergy: Int = 40, current: Int? = nil` and pass them to `Pet(...)`. Check how `HeroTrait` is built elsewhere in the tests (`grep -n "HeroTrait(" HesindionTests | head`) and use that form.

In `MountSelectionTests.swift`, replace each `hero.mountGS` assertion with `hero.mount?.speed` (the test is about *which* animal; the speed identifies it).

- [ ] **Step 2: Run them to see them fail**

Run: `make test-only ONLY=HesindionTests/DamageModifiersTests`
Expected: FAIL — `source.sturmangriff.rk14` is missing; the old two lines are there.

- [ ] **Step 3: Implement**

`Strings.swift`, replace the three `source.sturmangriff*` keys in both languages with:

```swift
        "source.sturmangriff":       "Mounted Charge",
        "source.sturmangriff.rk14":  "Mounted Charge: 2 + ½ GS %@ (%d)",
```

```swift
        "source.sturmangriff":       "Sturmangriff zu Pferd",
        "source.sturmangriff.rk14":  "Sturmangriff zu Pferd: 2 + ½ GS %@ (%d)",
```

(`source.sturmangriff` stays: `CombatManeuver.swift:80` reads it.)

`DamageModifiers.swift`, replace the Sturmangriff block:

```swift
        // Sturmangriff zu Pferd (RK14): one line from the engine, the mount's current GS in it
        // (issue #48). A tap on the line's GS opens the mount's breakdown (CombatRootView).
        if situation.maneuver == .sturmangriff, let line = sturmangriffLine(hero: situation.hero) {
            lines.append(line)
        }
```

and add:

```swift
    /// RK14's TP line for a hit with the Sturmangriff zu Pferd, evaluated by the engine with the
    /// mount's facts (`MountValues`). nil without a mount, without the rules, or when RK14 does
    /// not apply (no Berittener Kampf).
    @MainActor
    static func sturmangriffLine(hero: Hero) -> ModifierLine? {
        guard let mount = hero.mount, let values = MountValues.of(mount),
              let store = RulesEngineStore.shared else { return nil }
        let charge = RulesEngine.Situation(sheet: HeroSheetMapping.sheet(for: hero)).stating(values.facts.facts + [
            Fact(name: "hero.mounted", value: .bool(true), owner: .loadout),
            Fact(name: "choice.order", value: .string("sturmangriffZuPferd"), owner: .player),
            Fact(name: "action.gait", value: .string("galopp"), owner: .player),
            Fact(name: "action.attack", value: .string("hit"), owner: .player),
        ])
        let rk14 = store.engine.evaluate(Query("tp"), in: charge).lines
            .filter { $0.origin?.rule == "reiterkampf" && $0.origin?.clause == "RK14" }
        guard !rk14.isEmpty, let gs = values.gs.result else { return nil }
        return ModifierLine(value: rk14.reduce(0) { $0 + $1.value },
                            source: String(format: L("source.sturmangriff.rk14"), mount.name, gs))
    }
```

`DamageModifiers.lines` is called from `@MainActor` views; if the compiler rejects the call from a non-isolated context, mark `lines(situation:)` `@MainActor` too (all callers are views and `@MainActor` tests). Add `import RulesEngine` at the top and qualify the app's own `Situation` where both are in scope. Check `Line.origin`'s field names (`Breakdown.swift`: `origin?.rule`, `origin?.clause` or a `ClauseRef`); match them.

`Hero.swift`: delete `mountGS`, `sturmangriffHalfMountGS`, `sturmangriffDamageBonus` (lines 950-964).

`CombatAttackViews.swift` `sturmangriffZuPferdButton`: the subtitle reads the engine's bonus:

```swift
        if hero.hasBerittenerKampf, let w = hero.selectedWeapon {
            let damageBonus = DamageModifiers.sturmangriffLine(hero: hero)?.value ?? 0
```

- [ ] **Step 4: Run the tests**

Run: `make test-only ONLY=HesindionTests/DamageModifiersTests` then `make test-only ONLY=HesindionTests/MountSelectionTests`
Expected: PASS.

Run: `grep -rn "mountGS\|sturmangriffHalfMountGS\|sturmangriffDamageBonus\|halfGSRoundedUp\|sturmangriff.halfGS" Hesindion HesindionTests HesindionUITests`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add Hesindion HesindionTests
git commit -m "combat: the Sturmangriff zu Pferd TP is RK14's line with the mount's current GS (#48)"
```

---

### Task 7: Mount AT, Stufe IV, and the root's Schmerz line

**Files:**
- Modify: `Hesindion/Views/CombatAttackViews.swift:186-290` (`mountAttackSection`, `niederreitenButton`, `sturmangriffZuPferdButton`, `choiceButton`)
- Modify: `Hesindion/Views/CombatRootView.swift:296-314` (mount name and LP bar)
- Modify: `Hesindion/Theme/Strings.swift` (new keys, both languages)
- Test: `HesindionTests/CombatViewSnapshotTests.swift` (or the snapshot class that renders `CombatRootView`; `grep -ln "CombatRootView" HesindionTests`)

**Interfaces:**
- Consumes: `MountValues` (Task 5).
- Produces: identifiers `combat.mount.blockedReason`, `combat.mount.schmerz`; `MountValues.statusText(name:) -> String?` (below).

- [ ] **Step 1: Write the failing tests**

Unit test in `MountValuesTests.swift`:

```swift
    func testTheStatusLineNamesTheStufeAndTheGS() throws {
        XCTAssertNil(MountValues.of(kupperus(le: 137))?.statusText(name: "Kupperus"))
        XCTAssertEqual(MountValues.of(kupperus(le: 60, advantages: []))?.statusText(name: "Kupperus"),
                       String(format: L("mount.schmerz.status"), "II", 13))
        XCTAssertEqual(MountValues.of(kupperus(le: 10, type: "Pferd"))?.statusText(name: "Kupperus"),
                       String(format: L("mount.schmerz.noThresholds"), "Kupperus"))
    }
```

Snapshot tests (follow the class's existing setup for a mounted hero; record new references with the class's record switch, then turn it off):

```swift
    func testRootWithAMountInPain() { /* Kupperus at 60 LeP, mounted: assert snapshot */ }
    func testMountActionsAtSchmerzIV() { /* Kupperus at 5 LeP: the attack picker, the three mount actions disabled, the reason line */ }
```

Write them in the class's own style (look at its nearest mounted test).

- [ ] **Step 2: Run them to see them fail**

Run: `make test-only ONLY=HesindionTests/MountValuesTests`
Expected: FAIL — `statusText` is not defined.

- [ ] **Step 3: Strings**

English:

```swift
        "mount.schmerz.status":       "Schmerz %@ · GS %d",
        "mount.schmerz.noThresholds": "Schmerz %@: thresholds unknown (no Bestiarium entry)",
        "mount.blocked.handlungsunfaehig": "%@: Schmerz IV — incapacitated",
```

German:

```swift
        "mount.schmerz.status":       "Schmerz %@ · GS %d",
        "mount.schmerz.noThresholds": "Schmerz %@: Schwellen unbekannt (kein Bestiarium-Eintrag)",
        "mount.blocked.handlungsunfaehig": "%@: Schmerz IV — handlungsunfähig",
```

- [ ] **Step 4: `statusText`**

In `MountValues.swift`:

```swift
    /// The root's line under the mount's name: its Stufe and current GS, or that its thresholds
    /// are unknown (ADR-0018: a rule that cannot apply says why). nil when nothing is wrong.
    func statusText(name: String) -> String? {
        guard hasBreedRule else { return String(format: L("mount.schmerz.noThresholds"), name) }
        guard schmerz > 0, let gs = gs.result else { return nil }
        let roman = ["I", "II", "III", "IV"][min(schmerz, 4) - 1]
        return String(format: L("mount.schmerz.status"), roman, gs)
    }
```

If the app already has a roman-numeral helper for Stufen (`grep -rn "\"III\"" Hesindion | head`), use it.

- [ ] **Step 5: The combat root**

In `CombatRootView.swift`, below `Text(mount.name)` (line 297-301):

```swift
                    if let status = MountValues.of(mount)?.statusText(name: mount.name) {
                        Text(status)
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(combatAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("combat.mount.schmerz")
                    }
```

- [ ] **Step 6: The mount's actions**

In `CombatAttackViews.swift`:
- `choiceButton` gets `disabled: Bool = false` and applies `.disabled(disabled)` to the `Button`.
- At the top of `mountAttackSection(mount:)`: `let values = MountValues.of(mount)` and `let blocked = values?.handlungsunfaehig ?? false`.
- Each mount attack's AT: `let at = values?.at(with: attack.name)?.result ?? attack.at`; use `at` in the subtitle and in `attributeValue:`; pass `disabled: blocked`.
- `niederreitenButton(mount:values:blocked:)`: `let niederreitenAT = values?.at(with: "Niederreiten")?.result ?? niederreitenAttack?.at ?? mount.attacks.first?.at ?? 0` (this also stops it taking the first attack's AT when a Niederreiten line exists, kupperus-und-waffen 18.2); `disabled: blocked`.
- `sturmangriffZuPferdButton(mount:blocked:)`: `disabled: blocked`.
- After the three buttons:

```swift
            if blocked {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(String(format: L("mount.blocked.handlungsunfaehig"), mount.name))
                }
                .font(.dsaBody(.caption2))
                .foregroundStyle(combatAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("combat.mount.blockedReason")
            }
```

When a mount attack's AT came from the engine with a Schmerz line, the execution screen should show it. Pass `modifierLines: nil` as today: the AT handed on already includes the line. ADR-0018 asks the breakdown to show it, so put the engine's Schmerz line into the attack's note: `note: values?.at(with: attack.name)?.breakdown.lines.first { $0.origin?.rule == "COND_6" }.map { "Schmerz \($0.value)" }`. Check how `note` is shown on the execution screen and phrase it the way other notes are.

- [ ] **Step 7: Run the tests**

Run: `make test-only ONLY=HesindionTests/MountValuesTests` then the snapshot class.
Expected: PASS (snapshots recorded once, then PASS with recording off).

- [ ] **Step 8: Commit**

```bash
git add Hesindion HesindionTests
git commit -m "combat: a mount in pain shows its Stufe and GS; at Schmerz IV its actions are shut (#48)"
```

---

### Task 8: The companion sheet and the fact labels

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:1206-1215, 1237-1272`
- Modify: `Hesindion/RulesEngine/FactLabel.swift:42-51`
- Modify: `Hesindion/Theme/Strings.swift` (`fact.*` keys)
- Test: `HesindionTests/FactLabelTests.swift` (exists? `ls HesindionTests | grep -i factlabel`; else add the cases to `MountValuesTests`)

**Interfaces:**
- Consumes: `MountValues` (Task 5); `BreakdownItem(title:value:)` (`HeroDetailView.swift:7`).

- [ ] **Step 1: Write the failing test**

```swift
    func testTheMountFactsHaveLabels() {
        XCTAssertEqual(FactLabel.label("mount.gs", book: nil), L("fact.mount.gs"))
        XCTAssertEqual(FactLabel.label("mount.schmerz", book: nil), L("fact.mount.schmerz"))
        XCTAssertEqual(FactLabel.label("mount.handlungsunfaehig", book: nil), L("fact.mount.handlungsunfaehig"))
        XCTAssertEqual(FactLabel.label("subject", book: nil), L("fact.subject"))
    }
```

- [ ] **Step 2: Run it to see it fail**

Run: `make test-only ONLY=HesindionTests/FactLabelTests`
Expected: FAIL — the raw name comes back.

- [ ] **Step 3: Implement**

`FactLabel.knownFacts` gets:

```swift
        "mount.gs": "fact.mount.gs",
        "mount.schmerz": "fact.mount.schmerz",
        "mount.handlungsunfaehig": "fact.mount.handlungsunfaehig",
        "subject": "fact.subject",
```

Strings — English: `"GS mount"`, `"Schmerz mount"`, `"mount incapacitated"`, `"subject"`; German: `"GS Reittier"`, `"Schmerz Reittier"`, `"Reittier handlungsunfähig"`, `"Subjekt"`. (`FactLabel.label` has no mount name, so the label names the role.)

`HeroDetailView`, the pet's "combat" block: for the mount only (`pet === hero.mount`), GS reads the engine and opens its breakdown:

```swift
                        let mountValues = pet === hero.mount ? MountValues.of(pet) : nil
                        SubfieldBlock(label: L("combat"), subfields: [
                            ("LE", "\(pet.currentLifeEnergy)/\(pet.lifeEnergy)"),
                            ("INI", pet.initiative),
                            ("GS", "\(mountValues?.gs.result ?? pet.speed)"),
                            …
                        ])
                        if let v = mountValues, let status = v.statusText(name: pet.name) {
                            Button { breakdown = BreakdownItem(title: "GS \(pet.name)", value: v.gs) } label: {
                                Text(status).font(.dsaBody(.caption2))
                            }
                            .accessibilityIdentifier("pet.schmerz.\(pet.name)")
                        }
```

`companionBlock`'s VW: `companionValue("VW", MountValues.of(pet)?.vw?.result ?? pet.defense, …)` for the mount; wrap it in a `Button` that opens `BreakdownItem(title: "VW \(pet.name)", value: vw)` when the engine value exists. Look at how the hero's tappable sheet values do it (`HeroDetailView.swift:60-80`) and copy that form.

- [ ] **Step 4: Run the tests**

Run: `make test-only ONLY=HesindionTests/FactLabelTests` then `make test-ui` (HesindionTests, includes the snapshots of HeroDetailView).
Expected: PASS. A changed HeroDetailView snapshot is expected only for a mount in pain; an unhurt mount's snapshot does not change.

- [ ] **Step 5: Commit**

```bash
git add Hesindion HesindionTests
git commit -m "ui: the companion sheet shows the mount's engine values and their breakdown (#48)"
```

---

### Task 9: UI test, screenshot, and docs

**Files:**
- Modify: `Hesindion/UITestSeed.swift` (a `-uitest-mount-le <n>` argument)
- Modify: `HesindionUITests/<the combat UI test class>` (`grep -ln "combat.action.spentReason" HesindionUITests`)
- Create: `docs/adr/0020-a-creature-is-a-subject-of-its-own.md`
- Modify: `AGENTS.md`, `CHANGELOG.md`, `docs/plans/2026-10-01-mount-schmerz-design.md` (§5.3, §6.7, §6.9)

- [ ] **Step 1: Write the failing UI test**

```swift
    /// Issue #48: Kupperus at 5 LeP is handlungsunfähig; the mount's actions say why they are shut.
    func testAMountAtSchmerzIVShutsItsActions() throws {
        let app = UITest.launch(extraArguments: ["-uitest-mount-le", "5"])
        // Navigate to the attack picker the way the class's other attack tests do.
        let reason = app.staticTexts["combat.mount.blockedReason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "67-mount-schmerz-iv"
        shot.lifetime = .keepAlways
        add(shot)
    }
```

Match `UITest.launch`'s real signature (it has `fokusRules:` and `shield:`); add `mountLE: Int? = nil` the same way.

- [ ] **Step 2: Run it to see it fail**

Run: `make screenshots ONLY=<the class>`
Expected: FAIL — the argument does nothing, the reason line does not exist.

- [ ] **Step 3: The seed argument**

In `UITestSeed.swift`, after the hero import, read `-uitest-mount-le <n>` and set `hero.mount?.currentLifeEnergy = n`, inside the existing `#if DEBUG` and launch-argument guard. The seed hero is the 2026-09-24 Boronmir export; check that its mount carries the companion block (`type` "Svellttaler Kaltblut", 137 LeP). If the bundled `UITestHero.json` predates the companion data, regenerate it the way AGENTS.md describes (strip the avatars) from `specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json`.

- [ ] **Step 4: Run it**

Run: `make screenshots ONLY=<the class>`
Expected: PASS; `docs/screenshots/67-mount-schmerz-iv.png` exists. Delete any simulator crash log the run drops in `docs/screenshots/`.

- [ ] **Step 5: Docs**

- ADR-0020 from `docs/adr/0000-template.md`: Context (COND_6 is the hero's; a mount's Zustände; issue #48), Decision (`CreatureSheet`, `Situation(creature:)`, `subject`, `Engine.mountFacts`, the three readable facts), Alternatives (B: `mount.`-prefixed copies of COND_6 — every effect twice, prefix special cases in the engine and compiler; C: the app computes the Stufe — the thresholds would stay outside the rules), Consequences (a companion or an opponent can be a subject the same way; `hero.levelOf.*` reads the subject's Stufe in a creature's situation).
- AGENTS.md: in the rules-engine paragraph, a sentence after domain 1: "The mount slice reads the engine too (issue #48): `PetSheetMapping` → `CreatureSheet` → `MountValues`; the hero's situation states `mount.gs`, `mount.schmerz` and `mount.handlungsunfaehig` from it, and RK14's TP line is the engine's." In the identifiers list: `combat.mount.schmerz` (the root's line under the mount's name) and `combat.mount.blockedReason` (why the mount's actions are shut at Schmerz IV), issue #48. In the UI-test paragraph: the `-uitest-mount-le <n>` argument.
- CHANGELOG: one entry, as the others are written.
- The design doc: §5.3 now reads "No breed rule: the creature's Stufe is 0 in the engine (SZ3 is the hero's); `MountValues.hasBreedRule` is false, and the app shows the rule as not applied (§6.7)." §6.9: the labels name the role ("GS Reittier"), since `FactLabel` has no mount name.

- [ ] **Step 6: Full verification**

Run, one at a time: `make test-rulec`, `make test-rules-review`, `make rules-check`, `make test-rules-engine`, `make test-ui`, `make test`.
Expected: all PASS, apart from the four known intermittent failures in AGENTS.md (rerun those in isolation).

- [ ] **Step 7: Commit**

```bash
git add Hesindion HesindionUITests docs AGENTS.md CHANGELOG.md
git commit -m "docs: ADR-0020, a creature is a subject of its own; mount screenshot (#48)"
```
