# Combat bug round (owner report 2026-09-18) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the ten items of the owner's manual-test report of 2026-09-18: the Sturmangriff label, the situations that change mid-fight (mounted, water, attacked from behind, Vorteilhafte Position on defence), the Größenkategorie, Passierschlag and Flucht as real rolls, the Blutend clock, and a first weapon inventory with the Rabenschnabel's rules.

**Architecture:** Every new *modifier* is a `specs/data/rules-catalog.yaml` entry interpreted by `RuleEvaluator` (design `docs/plans/2026-09-14-rules-catalog-design.md`); the vocabulary grows by exactly the predicates/targets listed here. What the vocabulary cannot express — forbidding a defence, a clock, a state added on a Patzer — is Swift, and the catalog entry's `note` names the Swift symbol. Situation that lasts the round or the fight lives on `CombatSituation` / `Hero`; facts about the other side live on `OpponentProfile` (reset per interaction, see its doc comment).

**Tech Stack:** Swift 6 / SwiftUI / SwiftData (iOS), XCTest + swift-snapshot-testing, Python 3 build script for `rules.db`.

**Spec:** this document (owner's bug list, quoted per task) + the rules pages cited per task. The rules catalog design (`docs/plans/2026-09-14-rules-catalog-design.md` §3–§4) is the contract every catalog change follows.

## Global Constraints

- Branch `review/neobrutalism-swiftui-audit`, worktree `review-neobrutalism-swiftui`. Commit locally after every task; **do not push**.
- Commit with an explicit pathspec (`git commit <paths> -m …`); other sessions share the index. Commit messages end with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`. Never a `Claude-Session:` trailer, never a claude.ai link.
- Tests: `make test-ui` (HesindionTests: unit + snapshot) is the sanctioned run; **one simulator only**; run it in the background with a 600 s timeout and wait; never start a second `xcodebuild` while one runs. A UI-test class runs alone with the Makefile's `test` xcodebuild line plus `-only-testing:HesindionUITests/<Class>`. Known flake: `CombatViewSnapshotTests.testPreparation` (weapon order) — not a regression.
- Snapshot re-record: delete the affected reference PNGs first, then `make test-ui-record-only ONLY=HesindionTests/<Class>` (record only writes missing files).
- Any edit to `specs/data/rules-catalog.yaml` (even a comment) requires `make rules-db`; when status counts change, `UPDATE_SNAPSHOT=1 make rules-db`. A vocabulary change: edit `Hesindion/Engine/RuleVocabulary.swift` **and** hand-edit `specs/data/rule-vocabulary.json` to the identical export (keys sorted, 2-space pretty print as the file already is), then `make rules-db`; `RuleVocabularyTests` rewrites the JSON and fails once if the hand edit was off — commit the rewritten file and re-run `make rules-db`.
- The session shell refuses heredocs, loops with variables, `cd` chains and command substitution in the worktree: write helper scripts to the scratchpad with the Write tool and run them plainly.
- Every user-visible string goes through `L("key")` with both the EN and the DE table in `Hesindion/Theme/Strings.swift` (`StringsCoverageTests` enforces both). German game terms stay German in both tables where the app already does so.
- Catalog `note`s are English. New entries carry `reviewed: null` and a `sources:` wiki entry with `fetched: 2026-09-18`.
- Rounding: project convention is **round up** (`docs/plans/2026-09-10-derived-value-rounding-audit.md`).
- Opponents are not modelled (ADR-0005): no opponent LP/RS; what the GM must subtract is printed as an opponent line or a note, never applied.

**User decisions (already made):**
- "fine to keep them as a plan document. then implement the batches one after the other." — batches 1→5 in order, no GitHub issues.
- "for Blutend: there is already a round-by-round flow. the user can press the button to proceed to the next round." — the SP loss and the clock hang off the existing next-round button (`CombatView.onChange(of: roundNumber)`), no new round UI.
- Item 1: Boronmir owns Berittener Kampf (SA_43), not Sturmangriff (SA_62); the app's manoeuvre is Sturmangriff zu Pferd and only its German label is wrong. The +2 + halbe GS des Reittiers and "nicht mit Waffen parierbar" match the Reiterkampf rule. No SA_62 implementation in this round.
- Item 2: the owner calls the Rabenschnabel a consecrated weapon; Optolith's own note says "geweiht (Boron)". The inventory's consecration is the default, the hero-settings toggle can still switch it off. This supersedes the `Hero.consecratedWeapons` doc comment ("never derived").
- Item 3 correction from the page (https://dsa.ulisses-regelwiki.de/GR_Kampf-VorteilhaftePosition.html): "Erleichterungen von jeweils 2 auf Attacke und Verteidigungen" — Ausweichen too, not only PA.

## Batches

| Batch | Tasks | Owner items |
|---|---|---|
| 1 | 1 | #1 |
| 2 — situations that change mid-fight | 2, 3, 4, 5 | #8, #9, #4, #3 |
| 3 — restrictions and roll flows | 6, 7, 8 | #10, #7, #6 |
| 4 — Blutend | 9, 10 | #5 |
| 5 — weapons | 11, 12, 13, 14 | #2 |
| close | 15 | docs |

---

### Task 1: Sturmangriff zu Pferd says so

**Goal:** The manoeuvre picker and the breakdown line read "Sturmangriff zu Pferd" in German, so nobody mistakes it for the SF Sturmangriff (SA_62).

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` (DE table: `"maneuver.sturmangriff"`, `"source.sturmangriff"`, ~l.955/973)
- Test: `HesindionTests/StringsCoverageTests.swift` (add one assertion)

**Acceptance Criteria:**
- [ ] `L("maneuver.sturmangriff")` and `L("source.sturmangriff")` are "Sturmangriff zu Pferd" in DE; EN stays "Mounted Charge".
- [ ] No UI test or snapshot references the old German label (grep `HesindionUITests` and `HesindionTests/Snapshots` for `"Sturmangriff"` as a whole label; re-record only if a snapshot shows it).

**Verify:** `make test-ui` → 0 failures (except the known flake).

**Steps:**
- [ ] **Step 1: Failing test** — in `StringsCoverageTests` add:
```swift
func testMountedChargeIsNotConfusedWithTheSFSturmangriff() {
    XCTAssertEqual(AppStrings.de["maneuver.sturmangriff"], "Sturmangriff zu Pferd")
    XCTAssertEqual(AppStrings.de["source.sturmangriff"], "Sturmangriff zu Pferd")
}
```
(Use whatever accessor the test file already uses for the DE table — read its first test and copy it.)
- [ ] **Step 2:** change both DE values to `"Sturmangriff zu Pferd"`.
- [ ] **Step 3:** `grep -rn '"Sturmangriff"' HesindionUITests HesindionTests` and fix hits.
- [ ] **Step 4:** `make test-ui`, then commit `fix(combat): the mounted charge is called Sturmangriff zu Pferd`.

---

### Task 2: Mounted is a switch that can change mid-fight

**Goal:** Owner #8 — "There is no obvious state check if the hero is mounted … Starting the fight mounted does not mean that you are still mounted." The combat root shows a Beritten/Zu Fuß switch whenever the hero has a mount; changing it changes every later roll, persists with the session, and a hero who ends up Liegend is no longer in the saddle.

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (pass `$mountedActive`; `.onChange(of: mountedActive)` → `persistCombatState()`; `.onChange(of: hero.isLiegend)`)
- Modify: `Hesindion/Views/CombatRootView.swift` (`let mountedActive` → `@Binding var mountedActive`; a toggle chip beside the Beengte-Umgebung chip)
- Modify: `Hesindion/Theme/Strings.swift` (`combat.mounted.on` "Beritten: %@" / "Mounted: %@", `combat.mounted.off` "Zu Fuß" / "On foot", `combat.mounted.fellOff` "Liegend — nicht mehr im Sattel" / "Prone — no longer in the saddle")
- Test: `HesindionTests/CombatSituationTests.swift`, snapshot `HesindionTests/…CombatViewSnapshotTests` (root references)

**Acceptance Criteria:**
- [ ] Root shows the chip only when `hero.hasMount`; tapping flips `mountedActive`; the LP bar for the mount and the mount attack section follow it (they already read `mountedActive`).
- [ ] `hero.activeCombatMounted` equals the switch after each change (restore of a saved session lands mounted/unmounted as left).
- [ ] When `hero.isLiegend` becomes true while mounted, `mountedActive` becomes false.
- [ ] Accessibility id `combat.mounted.toggle`.

**Verify:** `make test-ui` → green; root snapshots re-recorded and visually checked (chip present on a hero with a mount).

**Steps:**
- [ ] **Step 1:** In `CombatRootView` change `let mountedActive: Bool` to `@Binding var mountedActive: Bool`; both `CombatRootView(` call sites in `CombatView` pass `mountedActive: $mountedActive`.
- [ ] **Step 2:** Under the Beengte-Umgebung button in the STATUS section add, only `if hero.hasMount, let mount = hero.pets.first`:
```swift
Button { mountedActive.toggle() } label: {
    HStack(spacing: 6) {
        Image(systemName: mountedActive ? "figure.equestrian.sports" : "figure.walk")
            .font(.dsaBody(.caption))
        Text(mountedActive ? String(format: L("combat.mounted.on"), mount.name) : L("combat.mounted.off"))
            .font(.dsaMono(.caption, emphasis: true))
    }
    .foregroundStyle(mountedActive ? .white : .secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(mountedActive ? combatAccent : Color(UIColor.secondarySystemBackground))
    .dsaBox(.flush, stroke: mountedActive ? combatAccent : Color.dsaBorder)
}
.buttonStyle(.dsaMotion)
.padding(.top, 4)
.frame(maxWidth: .infinity, alignment: .leading)
.accessibilityIdentifier("combat.mounted.toggle")
```
Put both chips in one `HStack(spacing: 8)` if they fit; otherwise stacked is fine (match the existing padding).
- [ ] **Step 3:** In `CombatView.body` add
```swift
.onChange(of: mountedActive) { _, _ in persistCombatState() }
// A hero on the ground is not in the saddle: the Patzer's Sturz and every
// other way to Liegend unseat a rider.
.onChange(of: hero.isLiegend) { _, isDown in
    if isDown && mountedActive { mountedActive = false }
}
```
- [ ] **Step 4:** Test in `CombatSituationTests`: a `CombatSituation(mounted: false)` evaluated for a Golgariten hero on foot has no `SA_661` line, `mounted: true` has it (use the fixture helpers of `RuleFixtureTests` as a pattern) — this pins that the switch, not the setup flag, feeds the roll.
- [ ] **Step 5:** Delete the root snapshot references of `CombatViewSnapshotTests` that show a hero with a mount, `make test-ui-record-only ONLY=HesindionTests/CombatViewSnapshotTests`, inspect the PNGs, then `make test-ui`.
- [ ] **Step 6:** Commit `feat(combat): mounted is a switch on the combat screen`.

---

### Task 3: Kampf im Wasser

**Goal:** Owner #9. Page https://dsa.ulisses-regelwiki.de/GR_Kampf-Wasser.html (Regelwerk 239): "Bei etwa hüfthohem Wasser beträgt diese Erschwernis jeweils −2. Unter Wasser steigen die Erschwernisse auf jeweils −6" on Attacke and Parade; no ranged weapons under water. SA_163 Kampf im Wasser: "sinken die Erschwernisse … um 2". SA_418 Unterwasserkampf (and ADV_71 Wasserlebewesen, which grants it): "gelten die Erschwernisse im Kampf unter Wasser nicht".

**Files:**
- Create: `Hesindion/Models/WaterDepth.swift`
- Modify: `Hesindion/Engine/CombatSituation.swift` (`var water: WaterDepth = .none`)
- Modify: `Hesindion/Engine/RuleVocabulary.swift`, `Hesindion/Engine/RuleCatalog.swift`, `Hesindion/Engine/RuleEvaluator.swift` (predicate `situation.water`)
- Modify: `specs/data/rule-vocabulary.json`, `specs/data/rules-catalog.yaml` (new `GRW_kampfImWasser`; `SA_163`, `SA_418` from todo → implemented)
- Modify: `Hesindion/Models/Hero.swift` (`var activeCombatWater: String = ""`, cleared in `clearCombatSession()`)
- Modify: `Hesindion/Views/CombatView.swift`, `CombatRootView.swift`, `CombatAttackViews.swift` (announcement `situation(_:)` sets `s.round.water`)
- Modify: `Hesindion/Theme/Strings.swift`
- Test: `HesindionTests/RuleFixtureTests.swift`, `RuleCatalogDecodingTests.swift`, `RuleReachabilityTests.swift` (two exhaustive switches, ~l.141 and ~l.390)

**Acceptance Criteria:**
- [ ] `WaterDepth` is `none | huefthoch | unterWasser`, `String` raw values, `CaseIterable`.
- [ ] Hüfthoch: melee AT −2 and PA −2; unter Wasser: −6 / −6; Ausweichen untouched (the page names AT and PA only).
- [ ] With SA_163 each is 2 smaller (−0/−4); with SA_418 under water the line is gone (0 is dropped).
- [ ] Root: a three-way chip row "Wasser: — / hüfthoch / unter Wasser" (ids `combat.water.none|huefthoch|unterWasser`); persisted in `hero.activeCombatWater` and restored in `CombatView.onAppear`.
- [ ] Unter Wasser the Fernkampf button is disabled with the reason `L("water.noRanged")` under it (same pattern as the Ladehemmung reason).
- [ ] Snapshot counts updated (`UPDATE_SNAPSHOT=1 make rules-db`).

**Verify:** `make test-ui` → green, including new fixture tests.

**Steps:**
- [ ] **Step 1: Model**
```swift
// Hesindion/Models/WaterDepth.swift
import Foundation

/// How deep the hero is standing in water (Regelwerk 239, Kampf im Wasser).
/// A situation of the fight that can change between rounds, like Beengte Umgebung.
enum WaterDepth: String, CaseIterable, Identifiable {
    case none, huefthoch, unterWasser

    var id: String { rawValue }
    var nameKey: String { "water.\(rawValue)" }
}
```
- [ ] **Step 2: Vocabulary** — `RuleVocabulary.Predicate.situationWater = "situation.water"`, signature `Signature(value: "list:water")`, enum export `"water": WaterDepth.allCases.filter { $0 != .none }.map(\.rawValue)`. `RulePredicate.situationWater([WaterDepth])`, decoded like `situationTargetZone` (list of raw values, unknown value throws). Evaluator:
```swift
case .situationWater(let depths):
    return depths.contains(s.round.water) ? .yes : .no
```
Reachability helper: `case .situationWater(let depths): s.round.water = depths.first ?? .huefthoch`; collect switch: `case .situationWater: set.insert(.situationWater)`. `RuleVocabularyTests.testTheExportListsEveryEnum` gains `XCTAssertEqual(enums["water"], ["huefthoch", "unterWasser"])`.
- [ ] **Step 3: Failing fixture tests** (`RuleFixtureTests`, new MARK "Kampf im Wasser"):
```swift
private func inWater(_ domain: RuleDomain, _ depth: WaterDepth) -> Situation {
    var s = Situation(hero: hero, domain: domain)
    s.round.water = depth
    s.opponents.current.reach = .kurz   // keep GRW_reichweite out of the lines
    return s
}

func testWaterCostsTwoWaistDeepAndSixUnderwaterOnATAndPA() {
    arm("Schwert", technique: "CT_12", reach: "Kurz")
    XCTAssertNil(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .none))))
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .huefthoch))), -2)
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeParry, .huefthoch))), -2)
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .unterWasser))), -6)
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeParry, .unterWasser))), -6)
    XCTAssertNil(value("GRW_kampfImWasser", in: lines(inWater(.meleeDodge, .unterWasser))), "the page names AT and PA")
}

func testKampfImWasserEasesByTwo() {
    own("SA_163", "Kampf im Wasser", list: \.generalSpecialAbilities)
    arm("Schwert", technique: "CT_12", reach: "Kurz")
    XCTAssertNil(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .huefthoch))), "−2 + 2 is dropped")
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .unterWasser))), -4)
}

func testUnterwasserkampfRemovesTheUnderwaterPenalty() {
    own("SA_418", "Unterwasserkampf", list: \.generalSpecialAbilities)
    arm("Schwert", technique: "CT_12", reach: "Kurz")
    XCTAssertNil(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .unterWasser))))
    XCTAssertEqual(value("GRW_kampfImWasser", in: lines(inWater(.meleeAttack, .huefthoch))), -2, "only under water")
}
```
Check in `rules.db` which trait list SA_163/SA_418 import into (`Hero.ownedRuleTiers` reads all lists, so any list works — pick the one `OptolithImportService` uses for their group). ADV_71 Wasserlebewesen: add a fourth test with `own("ADV_71", "Wasserlebewesen", list: \.advantages)` expecting the SA_418 behaviour.
- [ ] **Step 4: Catalog** (top block, after `GRW_vorteilhaftePosition`):
```yaml
- id: GRW_kampfImWasser
  name: "Kampf im Wasser"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 239 }
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/GR_Kampf-Wasser.html", fetched: 2026-09-18 }
  text: |
    Wer sich im Wasser aufhält, kann sich in der Regel schlechter bewegen als an Land und
    erleidet Erschwernisse auf Attacke und Parade. Bei etwa hüfthohem Wasser beträgt diese
    Erschwernis jeweils -2. Unter Wasser steigen die Erschwernisse auf jeweils -6.
  note: "The depth is a round situation (CombatSituation.water), set on the combat root and persisted in Hero.activeCombatWater. AT and PA only, as the page says; Ausweichen is untouched. No ranged attack under water is Swift: the root disables the Fernkampf button (the vocabulary has no forbid effect)."
  clauses:
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when: [{ situation.water: [huefthoch] }]
      effects: [{ add: { target: at, value: -2 } }, { add: { target: pa, value: -2 } }]
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when: [{ situation.water: [unterWasser] }]
      effects: [{ add: { target: at, value: -6 } }, { add: { target: pa, value: -6 } }]
```
Replace the `todo` entries `SA_163` and `SA_418` (and `ADV_71`) by implemented ones (keep `name`/`group` exactly as the todo entries have them):
```yaml
- id: SA_163
  # name/group: copy from the todo entry
  status: implemented
  reviewed: null
  sources: [{ kind: optolith }]
  note: "Eases GRW_kampfImWasser by 2 on AT and PA."
  clauses:
    - kind: passive
      domains: [meleeAttack, meleeParry]
      effects:
        - { modifyRule: { id: GRW_kampfImWasser, target: at, add: 2 } }
        - { modifyRule: { id: GRW_kampfImWasser, target: pa, add: 2 } }

- id: SA_418
  status: implemented
  reviewed: null
  sources: [{ kind: optolith }]
  note: "Under water GRW_kampfImWasser does not apply (set to 0, dropped). Waist-deep water still costs 2."
  clauses:
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when: [{ situation.water: [unterWasser] }]
      effects:
        - { modifyRule: { id: GRW_kampfImWasser, target: at, set: 0 } }
        - { modifyRule: { id: GRW_kampfImWasser, target: pa, set: 0 } }
```
ADV_71 gets the SA_418 clauses with note "Grants Unterwasserkampf (SA_418); same clauses." Check the entry-shape rules in `scripts/build_rules_db/catalog.py` (`REQUIRED`, `KNOWN_KEYS`) before writing; `sources` needs whatever keys the validator demands for `kind: optolith` (copy `SA_160`'s form).
- [ ] **Step 5:** `make rules-db UPDATE_SNAPSHOT=1` (vocabulary JSON first, see Global Constraints).
- [ ] **Step 6: Round state.** `CombatSituation`: `var water: WaterDepth = .none`. `CombatView`: `@State private var waterDepth: WaterDepth = .none`, included in its `situation`, passed to `CombatRootView` as `@Binding var waterDepth` and to `CombatAnnouncementView` as `let waterDepth: WaterDepth` (its `situation(_:)` sets `s.round.water = waterDepth`); `persistCombatState()` writes `hero.activeCombatWater = waterDepth.rawValue`; `onAppear` restores `WaterDepth(rawValue: hero.activeCombatWater) ?? .none`; `.onChange(of: waterDepth) { _, _ in persistCombatState() }`. `Hero.clearCombatSession()` sets `activeCombatWater = ""`.
- [ ] **Step 7: Root UI.** Under the mounted chip: a caption `L("water.label")` and three chips (`WaterDepth.allCases`, labels `L(depth.nameKey)`), selected one filled with `combatAccent` like the chips in `CombatAnnouncementView.chips`. Root's own `situation` gets `water: waterDepth`. The Fernkampf button: `let underwater = waterDepth == .unterWasser`, disabled when `jammed || underwater`, reason text `L("water.noRanged")` when underwater.
- [ ] **Step 8: Strings** EN/DE: `water.label` "WATER"/"WASSER", `water.none` "—"/"—", `water.huefthoch` "Waist-deep"/"hüfthoch", `water.unterWasser` "Underwater"/"unter Wasser", `water.noRanged` "No ranged attacks under water"/"Unter Wasser kein Fernkampf".
- [ ] **Step 9:** Re-record root snapshots (delete refs first), `make test-ui`, commit `feat(combat): Kampf im Wasser`.

---

### Task 4: Vorteilhafte Position on every defence, Angriff von hinten

**Goal:** Owner #4 (https://dsa.ulisses-regelwiki.de/GR_Kampf-AngriffVonHinten.html: "so ist die Verteidigung des Gegners um −4 erschwert") and the catalog half of #3 (Vorteilhafte Position: "+2 auf Attacke und Verteidigungen" — Ausweichen too).

**Files:**
- Modify: `specs/data/rules-catalog.yaml` (`GRW_vorteilhaftePosition` clause; new `GRW_angriffVonHinten`)
- Modify: `Hesindion/Models/OpponentProfile.swift` (`fromBehindKey`, `fromBehind`)
- Modify: `Hesindion/Views/CombatAttackViews.swift` (toggle in `opponentSection`, `opponentSummary`, "AT/PA +2" → "AT/VW +2")
- Modify: `Hesindion/Theme/Strings.swift`
- Test: `HesindionTests/RuleFixtureTests.swift`

**Acceptance Criteria:**
- [ ] Vorteilhafte Position gives +2 on AT, PA **and** Ausweichen (target `vw`); Golgariten-Stil still raises the AT half only.
- [ ] `gm.fact fromBehind (attack)` true: on a parry/dodge the hero's VW −4; on an attack an opponent line "Angriff von hinten −4" in the opponent-defence box.
- [ ] Announcement: toggle "Angriff von hinten" (id `combat.attack.fromBehind`, detail "Gegner-VW −4"), cleared with the rest of the profile by `reset()`.

**Verify:** `make test-ui` → green.

**Steps:**
- [ ] **Step 1: Failing tests**
```swift
func testVorteilhaftePositionEasesEveryDefence() {
    for domain in [RuleDomain.meleeParry, .meleeDodge] {
        var s = Situation(hero: hero, domain: domain)
        s.opponents.current.advantageousPosition = true
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: lines(s)), 2, "\(domain)")
    }
}

func testAttackedFromBehindCostsFourOnEveryDefence() {
    for domain in [RuleDomain.meleeParry, .meleeDodge] {
        var s = Situation(hero: hero, domain: domain)
        s.opponents.current.fromBehind = true
        XCTAssertEqual(value("GRW_angriffVonHinten", in: lines(s)), -4, "\(domain)")
    }
}

func testAttackingFromBehindIsAnOpponentLine() {
    arm("Schwert", technique: "CT_12", reach: "Mittel")
    var s = Situation(hero: hero, domain: .meleeAttack)
    s.opponents.current.fromBehind = true
    XCTAssertNil(value("GRW_angriffVonHinten", in: lines(s)), "nothing on the hero's own AT")
    XCTAssertEqual(evaluation(s).opponentLines.first { $0.ruleId == "GRW_angriffVonHinten" }?.value, -4)
}
```
Update any existing test that asserted VP only on the parry (`grep -n vorteilhaftePosition HesindionTests`).
- [ ] **Step 2: Profile**
```swift
/// The attack comes from behind — the hero's, or the one the hero is defending
/// against; the domain says which side pays (GRW_angriffVonHinten).
var fromBehind: Bool {
    get { facts[Self.fromBehindKey] == true }
    set { facts[Self.fromBehindKey] = newValue ? true : nil }
}
static let fromBehindKey = FactKey(id: "fromBehind", span: .attack)
```
- [ ] **Step 3: Catalog.** `GRW_vorteilhaftePosition`: `domains: [meleeAttack, meleeParry, meleeDodge]`, effects `at +2` and `vw +2`; update its `note` ("+2 AT and +2 on every defence, Ausweichen included — the page: 'Erleichterungen von jeweils 2 auf Attacke und Verteidigungen'") and add the wiki source. New entry:
```yaml
- id: GRW_angriffVonHinten
  name: "Angriff von hinten"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 238 }
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/GR_Kampf-AngriffVonHinten.html", fetched: 2026-09-18 }
  text: |
    Wenn dies geschieht, so ist die Verteidigung des Gegners um -4 erschwert, da er den
    Angriff nur schlecht sieht oder spät wahrnimmt.
  note: "One fact per interaction (gm.fact fromBehind, span attack): asked on the announcement when the hero attacks — an opponent line the GM subtracts — and on the defence screen (Task 5) when the hero is attacked, where it costs the hero's own VW."
  clauses:
    - kind: passive
      domains: [meleeParry, meleeDodge]
      when: [{ gm.fact: { id: fromBehind, span: attack } }]
      effects: [{ add: { target: vw, value: -4 } }]
    - kind: passive
      domains: [meleeAttack]
      when: [{ gm.fact: { id: fromBehind, span: attack } }]
      effects: [{ opponentAdd: { target: vw, value: -4 } }]
```
`UPDATE_SNAPSHOT=1 make rules-db`.
- [ ] **Step 4: Announcement.** After the Vorteilhafte-Position toggle in `opponentSection`:
```swift
DSAToggleRow(
    title: L("fromBehind"),
    isOn: $opponent.fromBehind,
    accent: combatAccent,
    detail: L("fromBehind.attackDetail"),
    identifier: "combat.attack.fromBehind"
)
```
`opponentSummary` appends `L("fromBehind")` when set; its VP part becomes `"AT/VW +2"`. Strings: `fromBehind` "Attack from behind"/"Angriff von hinten", `fromBehind.attackDetail` "Opponent defence −4"/"Gegner-VW −4", `fromBehind.defenseDetail` "Defence −4"/"VW −4". The opponent-defence box's total is labelled "PA"; change it to the neutral `L("source.opponentDefense")` total `"VW \(signed(...))"` so a dodge-only opponent is not misread (check the snapshot).
- [ ] **Step 5:** `make test-ui` (re-record announcement snapshots if any show the section), commit `feat(combat): Angriff von hinten; Vorteilhafte Position on every defence`.

---

### Task 5: A defence asks who is attacking

**Goal:** Owner #3 — "Similar to the state question during an attack … the app should also ask for a defense. Even Boronmir when fighting mounted might defend against other mounted opponents." Parieren and Ausweichen on the root open a defence screen that asks the attacker questions and shows the resulting VW before the roll.

**Files:**
- Create: `Hesindion/Views/CombatDefenseSetupView.swift`
- Modify: `Hesindion/Views/CombatView.swift` (`CombatStep.defenseSetup(CombatAction)` + `stepID`/`persistenceKey` cases + switch branch + swipe-down → `.root`)
- Modify: `Hesindion/Views/CombatRootView.swift` (Parieren/Ausweichen buttons → `step = .defenseSetup(.parieren|.ausweichen)`; the routing code moves to the new view)
- Modify: `Hesindion/Theme/Strings.swift`
- Modify: `HesindionUITests/UITestSupport.swift`, `DefenseModifierFlowTests.swift`, `FumbleTableFlowTests.swift`, `LandscapeScrollFlowTests.swift` (every `combat.parry`/`combat.dodge` tap continues through the new screen)
- Test: `HesindionTests/CombatDefenseSetupTests.swift` (pure routing), snapshot of the new screen

**Acceptance Criteria:**
- [ ] Screen shows: toggle Vorteilhafte Position (detail "VW +2"), toggle Angriff von hinten (detail "VW −4"), and — only when `mountedActive` — toggle "Angreifer kämpft zu Fuß" (`opponent.isOnFoot`, detail "VW +2"); then a `CombatBreakdownBox` with base PA/AW, the lines of `situation.defenseModifiers(hero:isAusweichen:opponents:)` and the total; then `CombatActionButton` "Würfeln" (id `combat.defense.continue`).
- [ ] Continue routes exactly as the root did: parry with dual-wield or shield → `.weaponSelection(.parieren)`; parry with a weapon → `.execution(.parieren, …)` with the lines; Raufen → same with Raufen's PA; no weapon → `.weaponSelection(.parieren)`; dodge → `.execution(.ausweichen, …)`.
- [ ] The answers live on `CombatView.opponent` (binding) so the weapon list and the execution read them; they are gone at the next `.root` (existing reset).
- [ ] Root's defence cost subtitle ("2. Parade · −3") and the blocked states (Vorstoß, Zu konzentriert) are unchanged; a blocked defence never reaches the new screen.
- [ ] All UI tests that parry/dodge pass.

**Verify:** `make test-ui` → green; then `DefenseModifierFlowTests`, `FumbleTableFlowTests`, `LandscapeScrollFlowTests` each alone via `-only-testing:HesindionUITests/<Class>` → green.

**Steps:**
- [ ] **Step 1: Pure routing, failing test first.** Put the decision in a testable function in the new file:
```swift
/// Where a defence goes once its questions are answered. Pure, so the routing
/// the root used to do inline is tested without a view.
enum DefenseRoute {
    static func next(_ action: CombatAction, hero: Hero, lines: [ModifierLine]) -> CombatStep {
        let total = lines.reduce(0) { $0 + $1.value }
        if action == .ausweichen {
            let aw = hero.derivedValues?.ausweichen.value ?? 0
            return .execution(.ausweichen, name: "Ausweichen", attributeValue: aw + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        if hero.isDualWielding || hero.selectedShield != nil { return .weaponSelection(.parieren) }
        if let w = hero.selectedWeapon {
            return .execution(.parieren, name: w.name, attributeValue: w.pa + hero.passiveShieldPABonus + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            return .execution(.parieren, name: "Raufen", attributeValue: (raufen?.pa ?? 0) + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        return .weaponSelection(.parieren)
    }
}
```
`CombatDefenseSetupTests` (in-memory `TestData.makeContainer()` as `RuleFixtureTests` does): a hero with a selected sword PA 8 and lines `[+2]` → `.execution(.parieren, attributeValue: 10)`; with a shield selected → `.weaponSelection(.parieren)`; dodge with AW 6 and `[-4]` → `.execution(.ausweichen, attributeValue: 2)`. `CombatStep` has no `Equatable`; assert with `if case .execution(let a, _, let v, _, _, _, _, _, _, _) = step { … } else { XCTFail() }`.
- [ ] **Step 2: The view.** `CombatDefenseSetupView(hero:, action:, situation: CombatSituation, mountedActive: Bool, opponent: Binding<OpponentProfile>, step:, onDismiss:)`. Header like `CombatFluchtView`'s (back → `.root`, title `L(action == .ausweichen ? "dodge" : "parry")`). Body in a `ScrollView` + `.adaptiveContentWidth()`: the toggles (`DSAToggleRow`, ids `combat.defense.advantageousPosition|fromBehind|onFoot`), the breakdown (`lines = situation.defenseModifiers(hero: hero, isAusweichen: action == .ausweichen, opponents: OpponentRoster([opponent]))`, base = weapon PA + `passiveShieldPABonus` or AW; with a shield/dual loadout print base "—" and let the weapon list show per-piece values — only the lines matter here), and the continue button `step = DefenseRoute.next(action, hero: hero, lines: lines)`.
- [ ] **Step 3: Wire.** `CombatStep.defenseSetup(CombatAction)`, both `stepID` and `persistenceKey` switches return `"defenseSetup"`; `CombatView` switch branch builds the view with `situation`, `mountedActive`, `$opponent`. Root buttons: `step = .defenseSetup(.parieren)` / `.defenseSetup(.ausweichen)`; delete the now-unused inline routing (keep `buildDefenseModifiers` — the cost subtitle uses it).
- [ ] **Step 4: Strings** EN/DE: `defense.attacker.label` "ATTACKER"/"ANGREIFER", `defense.onFoot` "Attacker fights on foot"/"Angreifer kämpft zu Fuß", `defense.roll` "Roll"/"Würfeln", plus reuse `advantageousPosition`, `fromBehind`, `fromBehind.defenseDetail`.
- [ ] **Step 5: UI tests.** In `UITestSupport` add `func continueDefense(_ app: XCUIApplication)` that taps `combat.defense.continue` (with `scrollUntilVisible`/`ensureVisible` if the helpers exist); after every `combat.parry`/`combat.dodge` tap in the three classes call it (18 call sites: `grep -rn 'combat.parry"\|combat.dodge"' HesindionUITests`).
- [ ] **Step 6:** snapshot test for the new screen (copy the pattern of the nearest combat snapshot test; one mounted hero, one not), record, inspect, `make test-ui`, then the three UI classes alone. Commit `feat(combat): a defence asks who is attacking`.

---

### Task 6: Größenkategorie

**Goal:** Owner #10 (https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/groessenkategorie.html): winzig −4 AT; groß "Nur Parade mit dem Schild oder Ausweichen zulässig"; riesig "Nur Ausweichen zulässig". "This should also block certain actions accordingly."

**Files:**
- Modify: `Hesindion/Models/HitZoneTable.swift` (`CreatureSize` gains `winzig`, first in `allCases`; hit-zone lookups treat it as `klein`)
- Create: `Hesindion/Engine/SizeCategoryRules.swift`
- Modify: `RuleVocabulary.swift`, `RuleCatalog.swift`, `RuleEvaluator.swift`, `rule-vocabulary.json` (predicate `opponent.size`, value `enum:size`)
- Modify: `specs/data/rules-catalog.yaml` (`GRW_groessenkategorie`)
- Modify: `CombatAttackViews.swift` (size row always shown, all five sizes; weapon list filters parries), `CombatDefenseSetupView.swift` (size row; parry blocked/redirected), `Strings.swift` (`creatureSize.winzig`, `size.*`)
- Test: `RuleFixtureTests`, `RuleReachabilityTests` switches, `HitZoneTableTests`, new `SizeCategoryRulesTests.swift`, `CombatDefenseSetupTests`

**Acceptance Criteria:**
- [ ] Attacking a winzig opponent: `GRW_groessenkategorie` AT −4. No line for klein…riesig.
- [ ] `SizeCategoryRules.allowedDefenses(against:)` → mittel/klein/winzig: weapon parry, shield parry, dodge; groß: shield parry, dodge; riesig: dodge.
- [ ] Defence screen: size chips (all five, default mittel). A parry not allowed: the button reads `L("size.parryImpossible")` with the reason, disabled, and a second button "Stattdessen ausweichen" (`combat.defense.switchToDodge`) switches to `.defenseSetup(.ausweichen)`. Groß with a shield: continue goes to the weapon list, which shows only the shield row.
- [ ] Announcement: size row visible without the Trefferzonen rule, all five sizes, winzig chip detail "AT −4"; with Trefferzonen the body-plan picker still resets the size to the plan's first published size, and a size the plan has no table for falls back to the nearest one (existing lookup behaviour).

**Verify:** `make test-ui` → green; `DefenseModifierFlowTests` alone → green.

**Steps:**
- [ ] **Step 1: Failing tests**
```swift
// SizeCategoryRulesTests.swift
import XCTest
@testable import Hesindion

final class SizeCategoryRulesTests: XCTestCase {
    func testTheTable() {
        for size in [CreatureSize.winzig, .klein, .mittel] {
            XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: size), [.weaponParry, .shieldParry, .dodge], "\(size)")
        }
        XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: .gross), [.shieldParry, .dodge])
        XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: .riesig), [.dodge])
    }
}
```
Fixture: `s.opponents.current.size = .winzig` on `.meleeAttack` → `GRW_groessenkategorie` −4; `.gross` → nil.
- [ ] **Step 2: Rules**
```swift
// Hesindion/Engine/SizeCategoryRules.swift
import Foundation

/// Which defences the Größenkategorie of the attacker leaves (Regelwerk,
/// Größenkategorie). Swift because the catalog vocabulary has no "forbid"
/// effect; GRW_groessenkategorie's note points here. The AT −4 against a
/// winzig target is the catalog's.
enum SizeCategoryRules {
    enum Defense: Hashable { case weaponParry, shieldParry, dodge }

    static func allowedDefenses(against size: CreatureSize) -> Set<Defense> {
        switch size {
        case .winzig, .klein, .mittel: [.weaponParry, .shieldParry, .dodge]
        case .gross:                   [.shieldParry, .dodge]
        case .riesig:                  [.dodge]
        }
    }
}
```
- [ ] **Step 3: `winzig`.** Add the case first in `CreatureSize`; fix every non-exhaustive switch the compiler reports; wherever a table is keyed by size, map `.winzig` to `.klein` (one helper `var tableSize: CreatureSize { self == .winzig ? .klein : self }` used by the lookup). `HitZoneTableTests`: a winzig humanoid rolls on the klein table. Strings `creatureSize.winzig` "tiny"/"winzig". Hero settings keep offering klein/mittel/groß only.
- [ ] **Step 4: Predicate** `opponent.size` (`Signature(value: "enum:size")`, export `"size": CreatureSize.allCases.map(\.rawValue)`), `RulePredicate.opponentSize(CreatureSize)`, evaluator `s.opponent.size == size ? .yes : .no`, reachability helpers `s.opponents.current.size = size`. Catalog:
```yaml
- id: GRW_groessenkategorie
  name: "Größenkategorie"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/groessenkategorie.html", fetched: 2026-09-18 }
  note: "Winzig −4 AT for the hero's attack. The defence restrictions against a groß (shield parry or dodge) or riesig (dodge only) attacker are SizeCategoryRules.allowedDefenses, read by CombatDefenseSetupView and the weapon list — the vocabulary cannot forbid a defence. The opponent's size is asked per interaction (OpponentProfile.size)."
  clauses:
    - kind: passive
      domains: [meleeAttack]
      when: [{ opponent.size: winzig }]
      effects: [{ add: { target: at, value: -4 } }]
```
`UPDATE_SNAPSHOT=1 make rules-db`.
- [ ] **Step 5: Views.** Announcement: move the size `captioned(L("opponent.size"))` row out of `if zonesActive`, options `CreatureSize.allCases`; `opponentSummary` shows the size whenever it is not mittel. Defence screen: the same chip row under "ANGREIFER"; `let allowed = SizeCategoryRules.allowedDefenses(against: opponent.size)`; parry is possible iff `allowed.contains(.weaponParry) || (allowed.contains(.shieldParry) && hero.selectedShield != nil)`; when not possible, disable continue, show `L("size.parryImpossible")` as reason and the switch-to-dodge button. `DefenseRoute.next` for a groß attacker with a shield returns `.weaponSelection(.parieren)` (add a `size:` parameter; test it). `CombatWeaponSelectionView` for `.parieren` hides weapon rows unless `allowed.contains(.weaponParry)`.
- [ ] **Step 6: Strings** EN/DE: `size.parryImpossible` "No parry against this size"/"Gegen diese Größe keine Parade", `size.shieldOnly` "Shield parry or dodge only"/"Nur Schildparade oder Ausweichen", `size.dodgeOnly` "Dodge only"/"Nur Ausweichen", `defense.switchToDodge` "Dodge instead"/"Stattdessen ausweichen".
- [ ] **Step 7:** tests, snapshots (announcement section, defence screen), commit `feat(combat): Größenkategorie`.

---

### Task 7: Passierschlag from the attack screen

**Goal:** Owner #7 (https://dsa.ulisses-regelwiki.de/GR_Kampf-Passierschlag.html: "um −4 erschwerte Attacke", no defence, no manoeuvres, no critical success or Patzer, no action). "Let's group that under the Attack view." The announcement's Manöver list offers Passierschlag; the Passierschlag screen rolls with every modifier the hero has, not a bare AT −4.

**Files:**
- Modify: `Hesindion/Engine/RuleEvaluator.swift` (a non-tiered offer's line carries no roman numeral)
- Modify: `specs/data/rules-catalog.yaml` (`GRW_passierschlag` byHand → implemented)
- Modify: `Hesindion/Models/CombatManeuver.swift` (`.passierschlag`), `Hesindion/Engine/Situation.swift` (`announced(for:)`)
- Modify: `Hesindion/Views/CombatAttackViews.swift` (`availableManeuvers`, `proceed()`, zone picker hidden for it)
- Modify: `Hesindion/Views/CombatDefenseViews.swift` (`CombatPassierschlagView` reads the evaluator), `CombatView.swift` (pass `situation`, `opponent`)
- Test: `RuleEvaluatorTests`, `RuleFixtureTests`

**Acceptance Criteria:**
- [ ] `GRW_passierschlag` is an `offer` on `meleeAttack` with `add at −4`; announcing it gives a line named "Passierschlag" (no "I").
- [ ] Wuchtschlag lines still read "Wuchtschlag I/II" (its clause has `tiers: owned`).
- [ ] The Manöver list always ends with "Passierschlag" (subtitle `L("passierschlag.info")`); choosing it hides the Trefferzone picker and "Weiter" goes to `.passierschlag`.
- [ ] `CombatPassierschlagView` shows a `CombatBreakdownBox` (weapon AT, the evaluator's lines for `Situation(maneuver: .passierschlag)` with `round` = the fight's `CombatSituation` and the current opponent, total), rolls against the total, no crit/Patzer (unchanged), and rolls damage with `DamageModifiers.lines(situation:)` applied. The critical-parry route to `.passierschlag` gets the same numbers.

**Verify:** `make test-ui` → green.

**Steps:**
- [ ] **Step 1: Failing evaluator test** (`RuleEvaluatorTests`, using its `rule(...)`/`passive` helpers): an offer clause *without* `tiers`, announced 1, produces a line whose `name` equals the rule name exactly; with `tiers: .owned` it is "Name I".
- [ ] **Step 2:** In `RuleEvaluator.evaluate(_:in:…)` offer branch:
```swift
let label = swung > 0 && clause.tiers != nil ? "\(rule.name) \(CombatManeuver.roman(swung))" : rule.name
```
- [ ] **Step 3: Catalog**
```yaml
- id: GRW_passierschlag
  name: "Passierschlag"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/GR_Kampf-Passierschlag.html", fetched: 2026-09-18 }
  text: |
    Ein Passierschlag ist ein Nahkampfangriff, der keine Handlung erfordert und auf den nicht
    mit einer Verteidigung reagiert werden kann. Es handelt sich um eine um -4 erschwerte Attacke.
  note: "Announced from the Manöver list (CombatManeuver.passierschlag → Situation.announced) or reached after a critical parry; CombatPassierschlagView rolls it with no critical success, no Patzer and no defence (Swift, a flow). Suffered by the hero after a failed Flucht (Task 8): the take-damage screen."
  clauses:
    - kind: offer
      domains: [meleeAttack]
      effects: [{ add: { target: at, value: -4 } }]
```
`UPDATE_SNAPSHOT=1 make rules-db`. Fixture: `s.maneuver = .passierschlag` → `GRW_passierschlag` −4, and SA_67 not applied (no Wuchtschlag announced).
- [ ] **Step 4: Manoeuvre.** `case passierschlag` in `CombatManeuver`; `atModifier` 0 (the catalog carries it), `displayName` `L("passierschlag")`, `sourceLabel` `L("source.passierschlag")`, `infoText()` `L("passierschlag.info")`. `Situation.announced(for:)`: `.passierschlag: ["GRW_passierschlag": 1]`. `availableManeuvers` appends `.passierschlag` last. Fix every other exhaustive switch on `CombatManeuver`.
- [ ] **Step 5: Announcement.** Hide the Trefferzone picker `if selectedManeuver == .passierschlag` (and set `targetZone = nil` on select). `proceed()` first line: `if selectedManeuver == .passierschlag { step = .passierschlag; return }` — the opponent answers stay on `CombatView.opponent`.
- [ ] **Step 6: Screen.** `CombatPassierschlagView` gains `let situation: CombatSituation` and `let opponent: OpponentProfile`; `CombatView` passes them. Replace `baseAT` with:
```swift
private func situation(_ domain: RuleDomain) -> Situation {
    var s = Situation(hero: hero, domain: domain)
    s.round = situation
    s.opponents = OpponentRoster([opponent])
    s.loadoutName = weaponName
    s.maneuver = .passierschlag
    return s
}
private var rawAT: Int { weapon?.at ?? (hero.combatTechniques.first { $0.name == "Raufen" }?.at ?? 0) }
private var lines: [ModifierLine] { ModifierEngine.shared.evaluate(context: situation(.meleeAttack)) }
private var effectiveAT: Int { rawAT + lines.reduce(0) { $0 + $1.value } }
private var effectiveDamage: String {
    DamageModifiers.applied(to: damageFormula, lines: DamageModifiers.lines(situation: situation(.damage))) ?? damageFormula
}
```
Replace the "AT n / Passierschlag" bar with `CombatBreakdownBox(baseValue: "\(rawAT)", baseSource: L("source.basis"), lines: lines, totalValue: "AT \(effectiveAT)", totalSource: L("source.effective"), sectionLabel: L("attack.label"))`; `isHit` uses `effectiveAT`; the damage section parses `effectiveDamage`; the log's `effectiveValue` is `effectiveAT`.
- [ ] **Step 7:** tests, re-record announcement snapshots showing the Manöver list, commit `feat(combat): Passierschlag from the attack screen, with the hero's modifiers`.

---

### Task 8: Flucht is a Körperbeherrschung roll

**Goal:** Owner #6 — "the user can just say that the roll was successful, instead let's do an appropriate Körperbeherrschungs roll." DSA 5 Flucht: Körperbeherrschung (Kampfmanöver), erschwert um die Anzahl der Gegner in Angriffsdistanz; misslungen: nur GS/2 und ein Passierschlag.

**Files:**
- Modify: `Hesindion/Views/TalentProbeModal.swift` (`var onResult: ((SkillCheckResult) -> Void)? = nil`, called beside `onRolled`)
- Modify: `Hesindion/Views/CombatDefenseViews.swift` (`CombatFluchtView`)
- Modify: `Hesindion/Theme/Strings.swift`
- Modify: UI tests that tap the old `flucht.succeeded/failed` buttons, if any (`grep -rn flucht HesindionUITests`)

**Acceptance Criteria:**
- [ ] The Flucht screen keeps the opponent stepper; its only action is "Körperbeherrschung würfeln" (id `combat.flucht.roll`), which opens `TalentProbeModal(talent: hero.koerperbeherrschung, initialModifier: -opponentCount, accent: combatAccent)`.
- [ ] Success → the existing success box (GS). Failure → the existing failure box (GS/2) plus a button "Passierschlag erleiden" (id `combat.flucht.takePassierschlag`) → `.takeDamage(prefilledTP: nil, source: L("source.passierschlag"), thenIncomingHit: false)`, with the note `L("flucht.noDefense")` ("Keine Verteidigung gegen den Passierschlag").
- [ ] The log entry records the real outcome (`logFlucht(succeeded:)` called from the probe result).
- [ ] The manual "Gelungen"/"Misslungen" buttons are gone; their strings are removed if nothing else uses them.

**Verify:** `make test-ui` → green (StringsCoverage included).

**Steps:**
- [ ] **Step 1:** `TalentProbeModal`: add the property and change the call to `onResult: { result in onRolled?(result.succeeded); onResult?(result) }`.
- [ ] **Step 2:** `CombatFluchtView`: `@State private var showingProbe = false`; replace the two outcome buttons with one `CombatActionButton(title: L("flucht.roll"), identifier: "combat.flucht.roll") { showingProbe = true }`; hang the modal as an `.overlay` on the whole view (like `CombatFumbleChoiceView` does):
```swift
.overlay {
    if showingProbe {
        TalentProbeModal(
            talent: hero.koerperbeherrschung,
            hero: hero,
            onDismiss: { showingProbe = false },
            onRolled: { succeeded in
                outcome = succeeded ? .success : .failure
                logFlucht(succeeded: succeeded)
            },
            initialModifier: -opponentCount,
            accent: combatAccent
        )
    }
}
```
In the `.failure` branch, before "Neue Aktion", add the no-defence note and the take-Passierschlag button.
- [ ] **Step 3: Strings** EN/DE: `flucht.roll` "Roll Body Control"/"Körperbeherrschung würfeln", `flucht.takePassierschlag` "Take the free strike"/"Passierschlag erleiden", `flucht.noDefense` "No defence against the free strike"/"Keine Verteidigung gegen den Passierschlag"; `flucht.info` stays.
- [ ] **Step 4:** `make test-ui`, fix UI tests if any, commit `feat(combat): Flucht rolls Körperbeherrschung; a failure takes the Passierschlag`.

---

### Task 9: The Blutend clock (model)

**Goal:** Owner #5 model half. Page https://dsa.ulisses-regelwiki.de/Status_Blutend.html: on receiving the status a Selbstbeherrschung probe; duration 7−QS KR, a Patzer doubles it, a critical success ends it at once; at the end of every KR 1 SP; Heilkunde Wunden +2, 1 Aktion, shortens by QS/2 (rounded up, project convention); never twice — the longer duration wins.

**Files:**
- Create: `Hesindion/Models/Bleeding.swift` (`BleedingRules` + `Hero` extension)
- Modify: `Hesindion/Models/Hero.swift` (`var bleedingRoundsLeft: Int? = nil` in the temporary-combat block; `clearCombatSession()` clears it; `setStateLevel` clears it when `blutend` goes to 0)
- Modify: `Hesindion/Models/Talent.swift` (`heilkundeWunden` accessor, `TAL_50`)
- Test: `HesindionTests/BleedingTests.swift`

**Acceptance Criteria:**
- [ ] `BleedingRules.duration(qualityLevel:succeeded:critical:fumble:)` → crit success 0; otherwise `7 − (succeeded ? QS : 0)`, ×2 on a Patzer.
- [ ] `BleedingRules.treatmentReduction(qs:)` = `(qs + 1) / 2`.
- [ ] `hero.startBleeding(rounds:)`: 0 removes `blutend` and the clock; otherwise sets `blutend` and `bleedingRoundsLeft = max(existing ?? 0, rounds)`.
- [ ] `hero.endOfRoundBleeding()` returns the SP taken (1 or 0): only while `hasState("blutend")`; LP −1 floored at 0; RS never involved; decrements a known clock and ends the status at 0; an unrolled clock (`nil`) still costs the SP and stays nil.
- [ ] `hero.treatBleeding(qs:)` shortens a known clock; ≤ 0 ends the status.

**Verify:** `make test-ui` → `BleedingTests` green.

**Steps:**
- [ ] **Step 1: Failing tests**
```swift
import XCTest
import SwiftData
@testable import Hesindion

@MainActor
final class BleedingTests: XCTestCase {
    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
        hero.derivedValues = TestData.derivedValues(lp: 30)   // use the existing TestData helper for a hero with LP; add one if missing
    }

    func testDuration() {
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 0, succeeded: false, critical: false, fumble: false), 7)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 3, succeeded: true, critical: false, fumble: false), 4)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 0, succeeded: false, critical: false, fumble: true), 14)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 6, succeeded: true, critical: true, fumble: false), 0)
    }

    func testTreatmentRoundsUp() {
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 1), 1)
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 2), 1)
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 3), 2)
    }

    func testEachRoundCostsOneSPAndTheClockEndsIt() {
        hero.startBleeding(rounds: 2)
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 29)
        XCTAssertTrue(hero.hasState("blutend"))
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertFalse(hero.hasState("blutend"))
        XCTAssertEqual(hero.endOfRoundBleeding(), 0)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 28)
    }

    func testTheLongerBleedingWins() {
        hero.startBleeding(rounds: 5)
        hero.startBleeding(rounds: 3)
        XCTAssertEqual(hero.bleedingRoundsLeft, 5)
    }

    func testACriticalSelbstbeherrschungStopsIt() {
        hero.setStateLevel("blutend", level: 1)
        hero.startBleeding(rounds: 0)
        XCTAssertFalse(hero.hasState("blutend"))
    }

    func testUnrolledBleedingStillCosts() {
        hero.setStateLevel("blutend", level: 1)
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertNil(hero.bleedingRoundsLeft)
    }

    func testTreatment() {
        hero.startBleeding(rounds: 3)
        hero.treatBleeding(qs: 3)
        XCTAssertEqual(hero.bleedingRoundsLeft, 1)
        hero.treatBleeding(qs: 1)
        XCTAssertFalse(hero.hasState("blutend"))
    }

    func testRemovingTheStatusDropsTheClock() {
        hero.startBleeding(rounds: 4)
        hero.setStateLevel("blutend", level: 0)
        XCTAssertNil(hero.bleedingRoundsLeft)
    }
}
```
Read `HesindionTests/TestData*` first; if there is no LP helper, build `DerivedValues` the way `HeroStateTests` does.
- [ ] **Step 2: Implementation**
```swift
// Hesindion/Models/Bleeding.swift
import Foundation

/// Status Blutend (https://dsa.ulisses-regelwiki.de/Status_Blutend.html).
enum BleedingRules {
    static let stateId = "blutend"

    /// Rounds the status lasts after the Selbstbeherrschung probe it demands:
    /// 7 − QS, twice that on a Patzer, none at all on a critical success.
    static func duration(qualityLevel: Int, succeeded: Bool, critical: Bool, fumble: Bool) -> Int {
        if critical { return 0 }
        let base = 7 - (succeeded ? qualityLevel : 0)
        return fumble ? base * 2 : base
    }

    /// Heilkunde Wunden shortens it by QS/2, rounded up (project convention).
    static func treatmentReduction(qs: Int) -> Int { (max(qs, 0) + 1) / 2 }
}

extension Hero {
    /// Starts (or, if already bleeding, possibly extends) the clock. A second
    /// Blutend does not stack: the longer duration wins.
    func startBleeding(rounds: Int) {
        guard rounds > 0 else {
            setStateLevel(BleedingRules.stateId, level: 0)
            bleedingRoundsLeft = nil
            return
        }
        setStateLevel(BleedingRules.stateId, level: 1)
        bleedingRoundsLeft = max(bleedingRoundsLeft ?? 0, rounds)
    }

    /// End of a Kampfrunde: 1 SP (Schadenspunkte — armour does not reduce it)
    /// while the status lasts. Returns the SP taken.
    @discardableResult
    func endOfRoundBleeding() -> Int {
        guard hasState(BleedingRules.stateId) else { return 0 }
        if let dv = derivedValues { dv.lebensenergie.current = max(0, dv.lebensenergie.current - 1) }
        if let left = bleedingRoundsLeft {
            if left <= 1 { startBleeding(rounds: 0) } else { bleedingRoundsLeft = left - 1 }
        }
        return 1
    }

    func treatBleeding(qs: Int) {
        guard let left = bleedingRoundsLeft else { return }
        let rest = left - BleedingRules.treatmentReduction(qs: qs)
        if rest <= 0 { startBleeding(rounds: 0) } else { bleedingRoundsLeft = rest }
    }
}
```
`Hero`: `var bleedingRoundsLeft: Int? = nil` with a doc comment (relative count, so `rebaseCombatClocks` leaves it alone); `clearCombatSession()` sets it to nil; in `setStateLevel`, after computing `clamped`: `if stateID == BleedingRules.stateId && clamped == 0 { bleedingRoundsLeft = nil }`. `Talent`: `var heilkundeWunden: Talent { basicTalent(name: "Heilkunde Wunden", ruleId: "TAL_50") }` with constants beside the others.
- [ ] **Step 3:** `make test-ui`, commit `feat(states): the Blutend clock`.

---

### Task 10: Blutend in the fight

**Goal:** Owner #5 UI half — the Selbstbeherrschung probe, the SP at each "next round", and the Heilkunde-Wunden reminder with its effect.

**Files:**
- Create: `Hesindion/Views/CombatBleedingPanel.swift`
- Modify: `Hesindion/Views/CombatRootView.swift` (panel replaces Blutend's line in the per-round reminders; modal overlay)
- Modify: `Hesindion/Views/CombatView.swift` (`.onChange(of: roundNumber) { old, new in … }` calls `hero.endOfRoundBleeding()` only when `new > old`, logs it)
- Modify: `Hesindion/Models/LogEntry.swift` (`CombatActionType.bleeding`), `Hesindion/Views/LogPanelView.swift` (its case)
- Modify: `Hesindion/Theme/Strings.swift` (`bleeding.*`; fix `state.blutend.removal`)
- Test: snapshot of the panel's two states; `HesindionTests/CombatLogDeletionTests.swift` pattern for the new log kind if reversal applies

**Acceptance Criteria:**
- [ ] While `hero.hasState("blutend")` the root STATUS section shows the panel (id `combat.bleeding`): clock unknown → "Dauer: Selbstbeherrschung würfeln" + button (`combat.bleeding.selbstbeherrschung`); clock known → "noch N KR · 1 SP am Ende jeder KR" + button "Heilkunde Wunden +2 (1 Aktion)" (`combat.bleeding.heilkunde`) + the line "verkürzt um QS/2 KR".
- [ ] Selbstbeherrschung: `TalentProbeModal(talent: hero.selbstbeherrschung, onResult:)` → `hero.startBleeding(rounds: BleedingRules.duration(...))` from the `SkillCheckResult`.
- [ ] Heilkunde Wunden: `TalentProbeModal(talent: hero.heilkundeWunden, initialModifier: +2, onResult:)` → on success `hero.treatBleeding(qs: result.qualityLevel)`.
- [ ] Next round while bleeding: LP −1, one `combatAction` log entry `.bleeding` with `lpChange: -1` (reversible like the others); new initiative (round reset to 1) does **not** bleed.
- [ ] `state.blutend.removal` DE: "Nach 7−QS KR (Selbstbeherrschung). Heilkunde Wunden +2 (1 Aktion) verkürzt um QS/2 KR."; EN accordingly.

**Verify:** `make test-ui` → green; panel snapshots inspected.

**Steps:**
- [ ] **Step 1:** Panel view (`hero`, `accent`, `onRollSelbstbeherrschung`, `onRollHeilkunde`), layout like the per-round reminder row + two outline buttons in the style of the root's Fernkampf button. Root: filter `blutend` out of `perRoundReminders` and show the panel instead; hold `@State private var bleedingProbe: BleedingProbe?` (`enum BleedingProbe { case selbstbeherrschung, heilkunde }`) and present the modal in the root's outermost `.overlay`.
- [ ] **Step 2:** `CombatActionType.bleeding`; `LogPanelView` label `L("bleeding.log")` ("Bleeding: 1 SP"/"Blutend: 1 SP"). In `CombatView.onChange(of: roundNumber)` change the signature to `{ old, new in` and before the existing resets:
```swift
if new > old, hero.endOfRoundBleeding() > 0 {
    let entry = LogEntry.create(
        kind: "combatAction",
        payload: CombatActionPayload(
            combatId: combatId, round: old,
            action: .bleeding, weaponName: nil,
            rollValue: nil, damageDealt: nil, damageTaken: 1,
            effectiveValue: nil, outcome: nil,
            schipAction: nil, fumbleTableResult: nil,
            lpChange: -1
        ),
        hero: hero
    )
    modelContext.insert(entry)
}
```
(Check `CombatActionPayload`'s memberwise order in `LogEntry.swift` and the `outcome` type before pasting.)
- [ ] **Step 3:** Strings EN/DE: `bleeding.rollDuration`, `bleeding.roundsLeft` ("%d KR left · 1 SP at the end of each round"/"noch %d KR · 1 SP am Ende jeder KR"), `bleeding.unknownDuration`, `bleeding.heilkunde` ("Heilkunde Wunden +2 (1 action)"/"Heilkunde Wunden +2 (1 Aktion)"), `bleeding.heilkunde.effect` ("shortens by QS/2 rounds"/"verkürzt um QS/2 KR"), `bleeding.log`; corrected `state.blutend.removal`.
- [ ] **Step 4:** snapshots (hero with `blutend`, clock nil and clock 4), `make test-ui`, commit `feat(combat): Blutend asks for Selbstbeherrschung, bleeds each round, offers Heilkunde Wunden`.

---

### Task 11: Weapons in rules.db

**Goal:** Owner #2, data half — "let's start with creating a simple inventory of weapons." Import Optolith's weapon templates (names, stats, and the Vorteil/Nachteil/Hinweis texts) into `rules.db`, the prerequisite issue #14 names.

**Files:**
- Modify: `scripts/build_rules_db/build_db.py` (`equipment` table + `import_equipment`)
- Create: `scripts/build_rules_db/test_equipment.py`
- Modify: `Hesindion/Resources/rules.db` (rebuilt)

**Acceptance Criteria:**
- [ ] Table `equipment(id TEXT PRIMARY KEY, name TEXT NOT NULL, gr INTEGER, combat_technique TEXT, damage TEXT, at INTEGER, pa INTEGER, reach INTEGER, note TEXT, advantage TEXT, disadvantage TEXT)`, rows for every template with `gr` 1 (melee incl. shields) or 2 (ranged) in `univ/Equipment.yaml`.
- [ ] `damage` is "1W6+4" style (`{n}W{sides}{+flat}`), `<br>` in texts becomes a newline, texts are stripped; the note comes from the first version with a `note`, advantage/disadvantage from the last version that has either.
- [ ] `ITEMTPL_19` row: name Rabenschnabel, CT_5, "1W6+4", at 0, pa −1, reach 2, note starting "geweiht (Boron)", advantage containing "Dornenspitze", disadvantage containing "Betäubung".
- [ ] `make test-rules-db` and `make rules-db` pass; the rules/catalog tables are byte-identical in content (only the new table is added).

**Verify:** `make test-rules-db` → OK; `sqlite3 Hesindion/Resources/rules.db "select name,damage,at,pa,reach from equipment where id='ITEMTPL_19'"` → `Rabenschnabel|1W6+4|0|-1|2`.

**Steps:**
- [ ] **Step 1: Failing Python test** (`test_equipment.py`, `unittest`, builds from two small in-test YAML strings written to a temp dir with the same layout `de-DE/Equipment.yaml` + `univ/Equipment.yaml`, calls `create_schema` + `import_equipment`, asserts the Rabenschnabel row and that a `gr: 8` item is not imported).
- [ ] **Step 2: Implementation** in `build_db.py`: schema in `create_schema`; function
```python
def _text(s):
    return s.replace("<br>", "\n").strip() if isinstance(s, str) else None

def import_equipment(conn: sqlite3.Connection, source: Path):
    de_by_id = {e["id"]: e for e in load_yaml(source / "de-DE" / "Equipment.yaml")}
    count = 0
    for u in load_yaml(source / "univ" / "Equipment.yaml"):
        if u.get("gr") not in (1, 2):
            continue
        de = de_by_id.get(u["id"])
        if not de:
            continue
        versions = de.get("versions") or []
        if isinstance(versions, dict):
            versions = [versions]
        note = next((_text(v["note"]) for v in versions if v.get("note")), None)
        rich = [v for v in versions if v.get("advantage") or v.get("disadvantage")]
        adv = _text(rich[-1].get("advantage")) if rich else None
        dis = _text(rich[-1].get("disadvantage")) if rich else None
        sp = u.get("special") or {}
        damage = None
        if sp.get("damageDiceNumber"):
            flat = sp.get("damageFlat") or 0
            damage = f"{sp['damageDiceNumber']}W{sp.get('damageDiceSides', 6)}" + (f"{flat:+d}" if flat else "")
        conn.execute(
            "INSERT INTO equipment VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (u["id"], de["name"], u["gr"], sp.get("combatTechnique"), damage,
             sp.get("at"), sp.get("pa"), sp.get("reach"), note, adv, dis))
        count += 1
    return count
```
Call it from the main build sequence next to the other imports (print the count like they do).
- [ ] **Step 3:** `make rules-db`; spot-check the Verify query; commit `build(rules-db): weapon templates with their Vorteil/Nachteil` (include the db).

---

### Task 12: The weapon inventory in the app

**Goal:** Owner #2, app half — the hero's weapons show what the rules say about them (stats, Vorteil, Nachteil, Hinweis), and a weapon Optolith marks "geweiht (…)" counts as consecrated unless the player switched it off.

**Files:**
- Create: `Hesindion/Models/EquipmentEntry.swift`
- Modify: `Hesindion/Services/RulesDatabase.swift` (`equipment(named:) -> EquipmentEntry?`, cached)
- Modify: `Hesindion/Models/Hero.swift` (`var unconsecratedWeapons: [String] = []`; `isConsecrated`, `setConsecrated`; update the `consecratedWeapons` doc comment)
- Create: `Hesindion/Views/WeaponInfoSheet.swift`
- Modify: the hero-detail weapon rows (`Hesindion/Views/HeroDetailComponents.swift` or wherever `meleeWeapons` are listed — grep) and `CombatLoadoutPicker.swift` (an ⓘ opens the sheet)
- Modify: `Hesindion/Theme/Strings.swift`
- Test: `HesindionTests/WeaponInventoryTests.swift`, `KarmalWeaponTests` (consecration default)

**Acceptance Criteria:**
- [ ] `EquipmentEntry { id, name, combatTechniqueId, damage, at, pa, reach, note, advantage, disadvantage; var consecratedTo: String? }` — `consecratedTo` parses `note` prefix `geweiht (X)` → "X".
- [ ] `RulesDatabase.shared.equipment(named: "Rabenschnabel")?.consecratedTo == "Boron"`; "Langschwert" has neither advantage nor disadvantage; "Großschild" has both.
- [ ] `hero.isConsecrated("Rabenschnabel")` is true with empty lists; `setConsecrated("Rabenschnabel", false)` makes it false (stored in `unconsecratedWeapons`), `true` again removes it from there. Non-inventory weapons behave as before.
- [ ] The info sheet shows name, TP, AT/PA-Mod, RW, "geweiht (Boron)", Vorteil, Nachteil, Hinweis — whatever is present; weapons with no entry show only the hero's own stats.

**Verify:** `make test-ui` → green.

**Steps:**
- [ ] **Step 1: Failing tests** for the three `equipment(named:)` facts and the consecration default/override (use a `Hero` in `TestData.makeContainer()`; `RulesDatabase.shared` is the bundled db — skip if unavailable like `RuleFixtureTests`).
- [ ] **Step 2:** `EquipmentEntry` + reader (follow `RulesDatabase.lookup(id:)` for the SQLite access pattern; cache by name in a dictionary).
- [ ] **Step 3:** Hero:
```swift
func isConsecrated(_ weaponName: String?) -> Bool {
    guard let weaponName else { return false }
    if consecratedWeapons.contains(weaponName) { return true }
    if unconsecratedWeapons.contains(weaponName) { return false }
    return RulesDatabase.shared.equipment(named: weaponName)?.consecratedTo != nil
}

func setConsecrated(_ weaponName: String, _ consecrated: Bool) {
    consecratedWeapons.removeAll { $0 == weaponName }
    unconsecratedWeapons.removeAll { $0 == weaponName }
    let byDefault = RulesDatabase.shared.equipment(named: weaponName)?.consecratedTo != nil
    guard consecrated != byDefault else { return }
    if consecrated { consecratedWeapons.append(weaponName) } else { unconsecratedWeapons.append(weaponName) }
}
```
Rewrite the `consecratedWeapons` doc comment: the inventory's "geweiht (…)" is the default (owner decision 2026-09-18), the two lists are the player's overrides.
- [ ] **Step 4:** `WeaponInfoSheet` (neo-brutalist sheet like `CombatArmorManagementSheet`, `.presentationCornerRadius(0)`), ⓘ buttons in the hero-detail weapon rows and the loadout picker rows (ids `weapon.info.<name>`). Strings EN/DE: `weapon.info.title`, `weapon.advantage` "Advantage"/"Waffenvorteil", `weapon.disadvantage` "Disadvantage"/"Waffennachteil", `weapon.note` "Note"/"Hinweis", `weapon.consecratedTo` "Consecrated (%@)"/"geweiht (%@)".
- [ ] **Step 5:** snapshots where the ⓘ appears, `make test-ui`, commit `feat(weapons): the rules' own text on every weapon; Optolith's geweiht is the default`.

---

### Task 13: Rabenschnabel rules through the catalog

**Goal:** Owner #2 mechanics — Dornenspitze (RS −2 against RS ≥ 6; the owner's "RS reduction … massive" is −2 and only against RS 6+) and "+1 TP von einem Reittier aus" (not tied to the spike).

**Files:**
- Modify: `scripts/build_rules_db/catalog.py` (+ `test_catalog.py`): ids starting `ITEMTPL_` are validated against the `equipment` table's name instead of `rules`; never required to be present (no completeness check for them)
- Modify: `Hesindion/Engine/RuleCatalog.swift` (`needsOwnership` false for `ITEMTPL_`; `RuleTarget.rs` applies to no domain)
- Modify: `RuleVocabulary.swift` + `rule-vocabulary.json` (target `rs`)
- Modify: `specs/data/rules-catalog.yaml` (`ITEMTPL_19`)
- Modify: `Hesindion/Views/CombatAttackViews.swift` (weapon-offer toggle; RS line shown as a note, not added into the PA total; `note` carried to execution)
- Modify: `Hesindion/Theme/Strings.swift` (`weaponOffer.ITEMTPL_19` "Thorn spike"/"Dornenspitze", `opponentRS` "Opponent RS"/"Gegner-RS", `rabenschnabel.rsNote` "only against RS 6 or more"/"nur gegen RS 6 oder mehr")
- Test: `RuleFixtureTests`, `test_catalog.py`, `RuleCatalogDecodingTests`

**Acceptance Criteria:**
- [ ] With the Rabenschnabel in hand and mounted: damage line `ITEMTPL_19` +1 TP; on foot: none; any other weapon: none.
- [ ] Announcing `announced["ITEMTPL_19"] = 1` yields an opponent line target `rs` −2 named "Rabenschnabel"; without it the evaluation lists an offer for `ITEMTPL_19`.
- [ ] Announcement: for every `evaluation.offers` entry whose id starts `ITEMTPL_`, a `DSAToggleRow` titled `L("weaponOffer.<id>")` (id `combat.attack.weaponOffer.<id>`); toggled on it sets `Situation.announced[id] = 1` in `situation(_:)`. The RS line renders under the damage box as "Gegner-RS −2 (nur gegen RS 6 oder mehr)", is excluded from the opponent-defence total, and is appended to the execution `note`.
- [ ] A test asserts every `ITEMTPL_` offer in the catalog has a `weaponOffer.<id>` string (EN and DE).
- [ ] `catalog.py` rejects an `ITEMTPL_` id missing from `equipment` or with the wrong name.

**Verify:** `make test-rules-db` and `make test-ui` → green.

**Steps:**
- [ ] **Step 1: Python first.** `test_catalog.py`: an `ITEMTPL_19` entry with name "Rabenschnabel" passes against a db whose `equipment` has that row; name "Rabe" fails; `ITEMTPL_999` fails. Implement: load `equipment` names beside `rules` (`SELECT id, name FROM equipment`), and in the per-entry check branch `elif rid.startswith("ITEMTPL_")`. Group for these entries: `"Waffe"` (no groups check).
- [ ] **Step 2: Swift vocabulary.** `Target.rs`; `RuleTarget.rs` with `applies(in:)` → `false` (it only ever appears in `opponentAdd`, which does not check the domain); decoding; `needsOwnership`: add `|| id.hasPrefix("ITEMTPL_")`. Hand-edit the JSON (`"target"` gains `"rs"` at the end).
- [ ] **Step 3: Failing fixtures**
```swift
func testRabenschnabelHitsHarderFromTheSaddle() {
    arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
    var s = Situation(hero: hero, domain: .damage)
    XCTAssertNil(value("ITEMTPL_19", in: DamageModifiers.lines(situation: s)))
    s.round.mounted = true
    XCTAssertEqual(value("ITEMTPL_19", in: DamageModifiers.lines(situation: s)), 1)
}

func testTheDornenspitzeIsAnOfferThatCostsTheOpponentsArmour() {
    arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
    var s = Situation(hero: hero, domain: .meleeAttack)
    XCTAssertTrue(evaluation(s).offers.contains { $0.ruleId == "ITEMTPL_19" })
    s.announced["ITEMTPL_19"] = 1
    let line = evaluation(s).opponentLines.first { $0.ruleId == "ITEMTPL_19" }
    XCTAssertEqual(line?.value, -2)
    XCTAssertEqual(line?.target, .rs)
}

func testOtherWeaponsGetNothing() {
    arm("Langschwert", technique: "CT_12", reach: "Mittel")
    var s = Situation(hero: hero, domain: .damage)
    s.round.mounted = true
    XCTAssertNil(value("ITEMTPL_19", in: DamageModifiers.lines(situation: s)))
}
```
(`DamageModifiers.lines(situation:)` returns `[ModifierLine]`; if `value(_:in:)` doesn't fit, look the line up by `ruleId` directly.)
- [ ] **Step 4: Catalog**
```yaml
- id: ITEMTPL_19
  name: "Rabenschnabel"
  group: "Waffe"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, src: US25208, page: 83 }
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/rabenschnabel.html", fetched: 2026-09-18 }
  text: |
    Statt mit der Hammerseite anzugreifen, kann der Held auch die Dornenspitze verwenden. Die
    Dornenspitze verursacht ebenfalls 1W6+4 TP. Rüstungen mit RS 6 oder mehr erleiden dadurch
    einen Malus von -2 auf RS. Von einem Reittier aus geführt, bekommt der Träger des
    Rabenschnabels einen Bonus von +1 TP.
    Nach einem bestätigten Patzer bei einer Attacke erhält der Träger zusätzlich 1 Stufe Betäubung.
  note: "Dornenspitze: an offer the announcement shows as a toggle; the RS −2 is an opponent line (target rs) the GM applies only against RS 6+, the app has no opponent RS (ADR-0005). +1 TP when mounted, whichever end is used. The Patzer's Betäubung is Swift (WeaponFumbleExtras, Task 14): the vocabulary has no state effect. geweiht (Boron) comes from the equipment table (Hero.isConsecrated)."
  applies_with: [{ loadout.weapon: { item: Rabenschnabel } }]
  clauses:
    - kind: passive
      domains: [damage]
      when: [situation.mounted]
      effects: [{ add: { target: tp, value: 1 } }]
    - kind: offer
      domains: [meleeAttack]
      effects: [{ opponentAdd: { target: rs, value: -2 } }]
```
`make rules-db` (implemented count +1 → `UPDATE_SNAPSHOT=1` if the snapshot counts ITEMTPL entries; check `catalog.py` status counting).
- [ ] **Step 5: Announcement.** `@State private var weaponOffers: Set<String> = []`; in `situation(_:)`: `for id in weaponOffers { s.announced[id] = 1 }`; toggles as in the criteria, listed under the Manöver list; `opponentDefenseLines` filters `target != .rs` (keep the Finte line); a new `rsLines` renders under `damageBreakdown` as a `BreakdownRow` per line (`value: "−2", source: "\(L("opponentRS")) · \(line.name) (\(L("rabenschnabel.rsNote")))"`) — generic enough: the note key comes from `"\(ruleId).rsNote"` only if present, else no parenthesis; `proceed()` appends the same text to `note`. Reset `weaponOffers` when `.onAppear` resets the opponent.
- [ ] **Step 6: Strings test** in `StringsCoverageTests`: every `RuleCatalog` implemented rule with id prefix `ITEMTPL_` and an offer clause has `weaponOffer.<id>` in both tables.
- [ ] **Step 7:** `make test-ui`, commit `feat(weapons): Rabenschnabel — Dornenspitze and +1 TP from the saddle`.

---

### Task 14: A Rabenschnabel Patzer stuns the wielder

**Goal:** "Nach einem bestätigten Patzer bei einer Attacke erhält der Träger zusätzlich 1 Stufe Betäubung."

**Files:**
- Create: `Hesindion/Models/WeaponFumbleExtras.swift`
- Modify: `Hesindion/Views/CombatDefenseViews.swift` (`CombatFumbleChoiceView`: apply once on appear for `.angriff`, record a `BreakdownRow`)
- Modify: `Hesindion/Theme/Strings.swift` (`fumble.weaponExtra.betaeubung` "%@: +1 level Stupor"/"%@: +1 Stufe Betäubung")
- Test: `HesindionTests/FumbleEffectTests.swift`

**Acceptance Criteria:**
- [ ] `WeaponFumbleExtras.extraStates(weaponName: "Rabenschnabel", action: .angriff)` → `[("betaeubung", 1)]`; `.parieren` → `[]`; "Langschwert" → `[]`.
- [ ] Opening the fumble screen after a confirmed attack Patzer with the Rabenschnabel raises Betäubung by one level (clamped at IV by `setStateLevel`) exactly once (guard with a `@State` flag so re-renders and back-navigation do not stack it) and lists it among the screen's writes.
- [ ] An agreement test: `RulesDatabase.shared.equipment(named: "Rabenschnabel")?.disadvantage` contains "Betäubung" (ties the Swift table to the imported text).

**Verify:** `make test-ui` → green.

**Steps:**
- [ ] **Step 1: Failing tests** for the three `extraStates` facts and the agreement test.
- [ ] **Step 2:**
```swift
// Hesindion/Models/WeaponFumbleExtras.swift
import Foundation

/// A weapon's Waffennachteil that fires on a confirmed Patzer — Swift because
/// the catalog vocabulary has no "add a state" effect (ITEMTPL_19's note).
/// Keyed by the weapon's name, as the loadout is (issue #14).
enum WeaponFumbleExtras {
    static func extraStates(weaponName: String, action: CombatAction) -> [(stateId: String, levels: Int)] {
        switch (weaponName, action) {
        case ("Rabenschnabel", .angriff): [("betaeubung", 1)]
        default: []
        }
    }
}
```
- [ ] **Step 3:** In `CombatFumbleChoiceView` add `@State private var weaponExtrasApplied = false` and in its `.onAppear`:
```swift
if !weaponExtrasApplied {
    weaponExtrasApplied = true
    for extra in WeaponFumbleExtras.extraStates(weaponName: weaponName, action: action) {
        hero.setStateLevel(extra.stateId, level: hero.level(of: extra.stateId) + extra.levels)
        record(value: "+\(extra.levels)", source: String(format: L("fumble.weaponExtra.betaeubung"), weaponName))
    }
}
```
(Only `betaeubung` exists as an extra; if a second state ever appears the string key must become per-state.)
- [ ] **Step 4:** `make test-ui`, commit `feat(weapons): a Rabenschnabel Patzer adds a level of Betäubung`.

---

### Task 15: Close the round

**Goal:** The repo says what changed, and the full suite is green.

**Files:**
- Modify: `AGENTS.md` (Combat System bullets: defence screen, mounted/water switches, Blutend clock, equipment table, `ITEMTPL_` catalog ids)
- Modify: `docs/plans/2026-09-14-rules-catalog-next-steps.md` (new predicates `situation.water`, `opponent.size`, target `rs`; the non-tiered offer label rule; `ITEMTPL_` ids; the open question "literal toggle labels not tied to the catalog" now also covers `weaponOffer.*`)
- Modify: this plan's `.tasks.json` statuses

**Acceptance Criteria:**
- [ ] `make test-ui` green (known flake excepted, named in the report); `make test` (includes UI tests) green or each failure explained.
- [ ] `git log --format=%B origin/review/neobrutalism-swiftui-audit..HEAD | grep -c Claude-Session` → 0.

**Verify:** the two commands above.

**Steps:**
- [ ] **Step 1:** Doc edits; **Step 2:** full runs (background, one at a time); **Step 3:** commit `docs: combat bug round 2026-09-18`. Do not push — report to the owner.

---

## Deferred (recorded, not in this round)

- SF Sturmangriff (SA_62) and Machtvoller Sturmangriff (SA_966) as manoeuvres for heroes who own them.
- Großschild: +1 PA against arrows and bolts, −1 GS, INI-tie rule — shown as text by Task 12, not computed.
- Blutend from a *second* source while already bleeding re-rolls only when the player adds it again; a hit that causes Blutend does not yet prompt by itself (the status is added by hand or via the states picker).
- Heilkunde Wunden by an ally (their QS) — the panel rolls the hero's own talent.
- Weapons the hero does not own (issue #14 parts 1–3) now have their data source (Task 11) but no picker.
