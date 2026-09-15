# Rules Catalog — Evaluator Implementation Plan (step 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rules with `status: implemented` in `specs/data/rules-catalog.yaml` drive the roll through a `RuleEvaluator` that reads the catalog, and the nine fixture rules of design §6 are the first to move out of Swift.

**Architecture:** A `Situation` value replaces `ModifierContext` (the round is `CombatSituation`, the other side is an `OpponentRoster` of `OpponentProfile`s). A closed vocabulary of predicates, effects, targets, domains and spans lives in `Hesindion/Engine/RuleVocabulary.swift` and is exported to `specs/data/rule-vocabulary.json`, which the Python build reads to validate clauses before compiling them (normalised to JSON) into the `catalog` table. `RuleEvaluator` interprets those clauses and returns an `Evaluation` (lines, multipliers, opponent lines, offers, questions, not-applied). During migration `ModifierEngine.evaluate` returns the union of the remaining Swift definitions and the evaluator, and a test asserts no rule id is produced by both. Each fixture task deletes a Swift definition, adds the catalog entry, and keeps the definition's test.

**Tech Stack:** Swift/SwiftUI, SwiftData, XCTest; Python 3.11 + PyYAML (`unittest`); SQLite.

**User decisions (already made):**
- Design approved at `docs/plans/2026-09-14-rules-catalog-design.md`; this plan is §7 step 2, in the order fixed by `docs/plans/2026-09-14-rules-catalog-next-steps.md`: Situation → vocabulary → `GRW_*` entries → RuleEvaluator → the nine fixtures → reachability test.
- Rules live in data with a closed vocabulary; growing the vocabulary is code and a human decision.
- The Regelwiki page wins over Optolith prose; Golgariten-Stil is +1 PA, no TP bonus, Rabenschnabel *or* Großschild, and the +2 AT raises an existing Vorteilhafte Position against foot fighters only.
- GM facts are asked once, remembered for a declared span, keyed to the opponent; unanswered means the rule is off and the calculation says so.
- A rule applies to a hero exactly when its id is among the hero's traits.
- The reviewed-date key is `date`.
- `rules.db` and the catalog are committed; `make rules-db` after any catalog edit.
- Step 3 (views read the Evaluation) and step 4 (authoring pipeline) are separate plans.

**Decisions this plan makes (flag if you disagree; none contradicts the record):**
- **Vocabulary scope.** The enums hold exactly what the nine fixtures and the `GRW_*` entries need (listed in Task 2). Design §4 items nobody uses yet (`hero.selectOption`, `hero.attribute`, `loadout.offHand`, `situation.maneuver`, `situation.roundStart`, `opponent.size`, `opponent.bodyPlan`, `modifyState`, `restrict`, `formula`, `gmNote`, targets `ini`, `gs`, `spell`, `liturgy`, `fumbleRange`, `qsCap`, offer fields `excludes`, `cost`, `restrictions`, `outcome`) arrive with the authoring batch that needs them, because every vocabulary item must have a renderer and a test, and the reachability test would fail on an item the evaluator cannot render.
- **The vocabulary file** is `specs/data/rule-vocabulary.json`: a plain listing of names, arguments and enums that both sides read, not a JSON-Schema-draft document. `jsonschema` is not installed and `requirements.txt` has only PyYAML; the hand-written check is forty lines.
- **A line's label is the catalog `name`** (German, the same in both app locales, as talent and spell names already are). Snapshot references that show a moved line are re-recorded in the task that moves it. `ModifierLine` gains `ruleId` so tests find lines by id, not by label.
- **`text` stays optional** on `implemented` entries until step 4 makes the wiki fetch mandatory. The fixtures carry `note`, `sources` and, where the design or Optolith quotes the page, `text`.
- **Fokusregeln without an Optolith id use the `GRW_` prefix too** (`GRW_zonenaufschlag`, `GRW_karmaleObjekte`), with group `Fokusregel` and the `FR_*` id in `sources`; the validator exempts the prefix, not the group.
- **The −5 Zustand cap and Passierschlag are `byHand` `GRW_*` entries**: the cap has no vocabulary effect (the design puts it in the evaluator's fixed order) and Passierschlag is a flow, not a modifier.
- **Six parts, not five:** `Evaluation` carries `multipliers` beside `lines`, because a `ModifierLine` is an `Int` and a doubling is not.
- **The Swift definitions the fixtures do not touch stay in Swift** (31 of the 42 in `ModifierEngine.shared`, listed at the end) and move in a follow-up plan. This plan proves the machinery and the migration pattern; the design's "move one at a time" continues at the same pace afterwards.

---

## File structure

**Create**
- `Hesindion/Engine/Situation.swift` — `RuleDomain`, `Situation`, `OpponentRoster`, `FactSpan`, `FactKey`.
- `Hesindion/Engine/RuleVocabulary.swift` — the closed enums and the JSON export.
- `Hesindion/Engine/RuleCatalog.swift` — `CatalogRule`, `RuleClause`, `RulePredicate`, `RuleEffect`, `RuleTarget`, decoded from the table's JSON columns; `RuleCatalog` (the bundled set).
- `Hesindion/Engine/RuleEvaluator.swift` — `Evaluation`, `RuleLine`, `RuleMultiplier`, `RuleOffer`, `RuleQuestion`, `NotApplied`, the evaluator.
- `specs/data/rule-vocabulary.json` — exported vocabulary, committed.
- `HesindionTests/RuleVocabularyTests.swift`, `RuleCatalogDecodingTests.swift`, `RuleEvaluatorTests.swift`, `ModifierEngineUnionTests.swift`, `RuleFixtureTests.swift`, `RuleReachabilityTests.swift`.

**Modify**
- `Hesindion/Models/OpponentProfile.swift` — label, `isOnFoot`, `states`, `facts`; the old flags become bridges.
- `Hesindion/Engine/ModifierEngine.swift` — `ModifierContext` deleted; `ModifierDefinition.rules`; the union.
- `Hesindion/Engine/CombatSituation.swift` — builds a `Situation`; `chosenOptions`.
- `Hesindion/Engine/{Shared,State,Melee,Defense,Ranged,Magic,HitZone,Damage}Modifiers.swift` — read from `Situation`; definitions deleted as their rules move.
- `Hesindion/Models/CombatManeuver.swift` — `ModifierLine.ruleId`.
- `Hesindion/Models/StateCatalog.swift` — `StateMechanic.catalog`.
- `Hesindion/Models/Hero.swift` — `ownedRuleTier(_:)`; `golgaritenActive` deleted.
- `Hesindion/Services/RulesDatabase.swift` — `implementedRules()`, `catalogEntries(idPrefix:)`.
- `Hesindion/Views/{CombatAttackViews,CombatFernkampfViews,CombatSpellViews,SpellProbeModal,TalentProbeModal,CombatDamageViews}.swift` — build a `Situation`; nothing else changes on screen.
- `scripts/build_rules_db/catalog.py`, `test_catalog.py`, `build_db.py`, `Makefile` — vocabulary check, `GRW_` exemption, JSON columns.
- `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`.
- `HesindionTests/{WeaponReachTests,HitZoneEngineIntegrationTests,HitZoneModifiersTests,StateModifiersTests,CombatSituationTests,DamageModifiersTests,KarmalWeaponTests,RulesCatalogTests}.swift`.
- `AGENTS.md`, `CHANGELOG.md`, `docs/plans/2026-09-14-rules-catalog-next-steps.md`.

The Xcode project uses file-system synchronized groups: new Swift files need no `project.pbxproj` edit.

**Commands.** `make test-ui` is the only sanctioned Swift test run (one simulator, 5–20 min; run it in the background with a 600 s timeout and wait). Python: `make test-rules-db`. Rebuild: `make rules-db` (`UPDATE_SNAPSHOT=1 make rules-db` when the counts change; commit the snapshot and `rules.db` with the YAML). Known intermittent failures are listed in AGENTS.md; `CombatViewSnapshotTests.testPreparation` (weapon order) is one of them. Commit with an explicit pathspec, never `git add -A`. No `Claude-Session:` trailers.

**Rule ids used below.** SA_661 Golgariten-Stil, SA_884 Plänkler-Formation, SA_67 Wuchtschlag, SA_160 Gezielter Angriff, SA_161 Gezielter Schuss, SA_923 Vinsalt-Stil, DISADV_57 Verweichlicht, STATE_10 Liegend, STATE_13 Überrascht, COND_1 Belastung, TAL_8 Selbstbeherrschung. Combat techniques: CT_1 Armbrüste, CT_4 Fechtwaffen, CT_5 Hiebwaffen, CT_10 Schilde, CT_12 Schwerter, CT_16 Zweihandschwerter.

---

### Task 1: `Situation` replaces `ModifierContext`

**Goal:** One plain value the view assembles carries everything a roll is evaluated against; `CombatSituation` and `OpponentProfile` become its parts and keep their names. No behaviour changes.

**Files:**
- Create: `Hesindion/Engine/Situation.swift`
- Modify: `Hesindion/Models/OpponentProfile.swift`
- Modify: `Hesindion/Engine/ModifierEngine.swift`
- Modify: `Hesindion/Engine/CombatSituation.swift:33-53`
- Modify: `Hesindion/Engine/SharedModifiers.swift`, `StateModifiers.swift`, `MeleeModifiers.swift`, `DefenseModifiers.swift`, `RangedModifiers.swift:85-95`, `HitZoneModifiers.swift:36-45`
- Modify: `Hesindion/Views/CombatAttackViews.swift:812-834`, `CombatFernkampfViews.swift:28-44`, `CombatSpellViews.swift:129-145`, `SpellProbeModal.swift:52-66`, `TalentProbeModal.swift:21-24`
- Modify: `Hesindion/Models/CombatManeuver.swift:126-131`
- Test: `HesindionTests/WeaponReachTests.swift`, `HitZoneEngineIntegrationTests.swift`, `HitZoneModifiersTests.swift`, `StateModifiersTests.swift`, new `HesindionTests/SituationTests.swift`

**Acceptance Criteria:**
- [ ] `ModifierContext` no longer exists; every former call site builds a `Situation`.
- [ ] `OpponentProfile.isProne`, `isSurprised`, `advantageousPosition`, `isOfOpposingDeity` still read and write as before (the views' bindings compile unchanged) and are backed by `states` and `facts`.
- [ ] `resetPerAttack()` clears `states` and every `facts` key with span `.attack`, and nothing else.
- [ ] `ModifierLine` has `ruleId: String?`, `nil` for every Swift definition.
- [ ] Every existing test passes unchanged in its assertions; no snapshot reference changes.

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`; `git status` shows no changed files under `HesindionTests/Snapshots/__Snapshots__`.

**Steps:**

- [ ] **Step 1: Write the failing tests**

`HesindionTests/SituationTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// The value a roll is evaluated against, and the two parts it is made of.
@MainActor
final class SituationTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    func testTheDefaultSituationHasOneOpponentWhoIsTheTarget() {
        let s = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertEqual(s.opponents.entries.count, 1)
        XCTAssertEqual(s.opponent, OpponentProfile())
        XCTAssertEqual(s.checkDomain, .meleeAttack)
        XCTAssertNil(Situation(hero: hero, domain: .damage).checkDomain, "damage has no Swift definitions")
    }

    func testTheCurrentOpponentIsWrittenInPlace() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.entries = [OpponentProfile(label: "Ork"), OpponentProfile(label: "Goblin")]
        s.opponents.currentIndex = 1
        s.opponents.current.isProne = true
        XCTAssertEqual(s.opponents.entries[1].label, "Goblin")
        XCTAssertTrue(s.opponents.entries[1].isProne)
        XCTAssertFalse(s.opponents.entries[0].isProne)
    }

    func testDefencesThisRoundFollowTheDomain() {
        var s = Situation(hero: hero, domain: .meleeParry)
        s.round.parriesThisRound = 2
        s.round.dodgesThisRound = 1
        XCTAssertEqual(s.defencesThisRound, 2)
        var dodge = Situation(hero: hero, domain: .meleeDodge)
        dodge.round = s.round
        XCTAssertEqual(dodge.defencesThisRound, 1)
    }

    // MARK: - OpponentProfile: the old flags are the new facts

    func testProneAndSurprisedAreStates() {
        var o = OpponentProfile()
        o.isProne = true
        o.isSurprised = true
        XCTAssertEqual(o.states, ["liegend", "ueberrascht"])
        o.isProne = false
        XCTAssertEqual(o.states, ["ueberrascht"])
    }

    func testAdvantageousPositionIsAnAttackFactAndOpposingDeityAFightFact() {
        var o = OpponentProfile()
        o.advantageousPosition = true
        o.isOfOpposingDeity = true
        XCTAssertEqual(o.facts[FactKey(id: "advantageousPosition", span: .attack)], true)
        XCTAssertEqual(o.facts[FactKey(id: "opposingDeity", span: .opponent)], true, "the same demon stays the same demon")
        o.advantageousPosition = false
        XCTAssertNil(o.facts[FactKey(id: "advantageousPosition", span: .attack)], "false is not stated, it is withdrawn")
    }

    func testResetPerAttackKeepsWhatLastsTheFight() {
        var o = OpponentProfile()
        o.reach = .lang
        o.isDaemon = true
        o.isOnFoot = true
        o.facts[FactKey(id: "knownLocation", span: .opponent)] = true
        o.isOfOpposingDeity = true
        o.isProne = true
        o.advantageousPosition = true
        o.resetPerAttack()
        XCTAssertEqual(o.reach, .lang)
        XCTAssertTrue(o.isDaemon)
        XCTAssertEqual(o.isOnFoot, true)
        XCTAssertTrue(o.isOfOpposingDeity)
        XCTAssertEqual(o.facts, [FactKey(id: "knownLocation", span: .opponent): true,
                                 OpponentProfile.opposingDeityKey: true])
        XCTAssertTrue(o.states.isEmpty)
        XCTAssertFalse(o.advantageousPosition)
    }

    func testAModifierLineCarriesNoRuleIdUnlessGivenOne() {
        XCTAssertNil(ModifierLine(value: 1, source: "x").ruleId)
        XCTAssertEqual(ModifierLine(value: 1, source: "x", ruleId: "SA_1").ruleId, "SA_1")
    }
}
```

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui`
Expected: `cannot find 'Situation' in scope`, `'OpponentProfile' has no member 'label'`.

- [ ] **Step 3: Create `Situation.swift`**

```swift
import Foundation

/// The domains a catalog clause can name: every check the app rolls, plus the
/// damage roll. `CheckDomain` stays the key the Swift definitions and the
/// state catalog use; `damage` has no Swift definitions, only catalog ones.
enum RuleDomain: String, CaseIterable, Codable {
    case meleeAttack, meleeParry, meleeDodge, rangedAttack
    case spellCasting, liturgyCasting, talentCheck
    case damage

    init(_ check: CheckDomain) { self = RuleDomain(rawValue: check.rawValue)! }
    var checkDomain: CheckDomain? { CheckDomain(rawValue: rawValue) }
}

/// How long an answer the GM gives is good for (design §3).
enum FactSpan: String, CaseIterable, Codable {
    /// Until changed in settings. Lives on `Hero`.
    case hero
    /// The fight. Lives on the roster entry.
    case opponent
    /// This attack. Lives on the roster entry, cleared by `resetPerAttack`.
    case attack
    /// The round. Lives on `CombatSituation`.
    case round
}

/// A GM fact, named and scoped. The subject is whichever entry holds it.
struct FactKey: Hashable {
    let id: String
    let span: FactSpan
}

/// The opponents the GM has described, and which one the hero is facing.
///
/// Never empty: a fight with nobody described still has one unnamed opponent
/// with default facts, which is what `OpponentProfile()` has always meant.
struct OpponentRoster: Equatable {
    var entries: [OpponentProfile]
    var currentIndex: Int

    init(_ entries: [OpponentProfile] = [OpponentProfile()], currentIndex: Int = 0) {
        precondition(!entries.isEmpty, "a roster has at least one opponent")
        self.entries = entries
        self.currentIndex = min(max(currentIndex, 0), entries.count - 1)
    }

    var current: OpponentProfile {
        get { entries[currentIndex] }
        set { entries[currentIndex] = newValue }
    }
}

/// Everything a roll is evaluated against, as one plain value the view
/// assembles (design §3). It replaces `ModifierContext`, whose 33 flat fields
/// mixed what the hero is, what the round is, and what the GM said about the
/// other side. The round is `CombatSituation`; the other side is the roster;
/// what belongs to this one attack or check sits beside them.
///
/// The ranged and magic inputs are still flat: their Swift definitions have
/// not moved to the catalog yet, and they move with them.
struct Situation {
    let hero: Hero
    let domain: RuleDomain

    var round = CombatSituation()
    var opponents = OpponentRoster()

    // MARK: This attack

    /// The loadout piece in the hand — a weapon, a shield, or "Raufen". `nil`
    /// means the main weapon.
    var loadoutName: String? = nil
    var maneuver: CombatManeuver = .normal
    var isOffHand = false
    var targetHitZone: HitZone? = nil

    // MARK: This check

    /// The talent under check, for `talentCheck`.
    var talentId: String? = nil
    /// The Selbstbeherrschung check a Wundeffekt demands, not a free-standing one.
    var isWoundEffectProbe = false
    var gottgefaellig = false

    // MARK: Ranged (moves with RangedModifiers)

    var distanz: Int = 1
    var groesse: Int = 2
    var bewegungZiel: Int = 1
    var bewegungSchuetze: Int = 0
    var sicht: Int = 0
    var kampfgetuemmel: Bool = false
    var zielen: Int = 0
    var vomPferd: Int = 0

    // MARK: Magic (moves with MagicModifiers)

    var maintainedSpellCount: Int = 0
    var foreignTradition: Bool = false
    var omitGesture: Bool = false
    var omitFormula: Bool = false
    var ironSteinCarried: Int = 0
    var distractionLevel: Int = 0
    var spellModifications: [SpellModification] = []

    init(hero: Hero, domain: RuleDomain) {
        self.hero = hero
        self.domain = domain
    }

    var checkDomain: CheckDomain? { domain.checkDomain }
    var opponent: OpponentProfile { opponents.current }
    /// Defences of this domain's kind already made this round.
    var defencesThisRound: Int { round.defensesSoFar(isAusweichen: domain == .meleeDodge) }
}
```

- [ ] **Step 4: Rewrite `OpponentProfile`**

Replace the `struct OpponentProfile` block in `Hesindion/Models/OpponentProfile.swift` (keep `BodyPlanKind` above it):

```swift
/// Everything the app has been *told* about one opponent.
///
/// The opponent is not modelled (ADR-0005): there is no LP, no RS and no sheet.
/// What there is, is a handful of facts the GM states and several rules turn on.
/// Split by how long each fact lasts: the shape of the opponent holds for the
/// fight, their posture and the GM's calls about this swing hold for the attack.
///
/// `states` and `facts` are what the catalog predicates read
/// (`opponent.state`, `gm.fact`); the named flags below them are the same
/// facts under the names the views bind to.
struct OpponentProfile: Equatable {

    /// What the GM calls this one ("der Ork links"). Empty for the unnamed
    /// single opponent every fight starts with.
    var label: String = ""

    // MARK: The opponent, for as long as the fight lasts

    var reach: WeaponReach = .mittel
    var bodyPlanKind: BodyPlanKind = .humanoid
    var size: CreatureSize = .mittel
    /// A demon. Only a consecrated weapon has anything to say about it.
    var isDaemon: Bool = false
    /// Fights on foot. `nil` means nobody has said; a mounted hero's
    /// Vorteilhafte Position turns on it, so the evaluator asks.
    var isOnFoot: Bool? = nil

    // MARK: This attack

    /// Statuses the GM has stated for this attack, by `StateCatalog` id.
    var states: Set<String> = []
    /// GM answers about this opponent. A missing key is "not stated", which is
    /// how a rule becomes a question rather than being silently off.
    var facts: [FactKey: Bool] = [:]

    // MARK: The same facts under the names the views bind to

    /// Status Liegend: −2 on *their* defence. The penalty is theirs.
    var isProne: Bool {
        get { states.contains("liegend") }
        set { if newValue { states.insert("liegend") } else { states.remove("liegend") } }
    }
    /// Eases the Zonenaufschlag by 2 (Trefferzonen Fokusregel).
    var isSurprised: Bool {
        get { states.contains("ueberrascht") }
        set { if newValue { states.insert("ueberrascht") } else { states.remove("ueberrascht") } }
    }
    /// The hero is better placed than this opponent: Vorteilhafte Position.
    var advantageousPosition: Bool {
        get { facts[Self.advantageousPositionKey] == true }
        set { facts[Self.advantageousPositionKey] = newValue ? true : nil }
    }
    /// A demon of the deity this weapon is sworn against — doubled TP. Lasts
    /// the fight, like `isDaemon`: the same demon stays the same demon.
    var isOfOpposingDeity: Bool {
        get { facts[Self.opposingDeityKey] == true }
        set { facts[Self.opposingDeityKey] = newValue ? true : nil }
    }

    static let advantageousPositionKey = FactKey(id: "advantageousPosition", span: .attack)
    static let opposingDeityKey = FactKey(id: "opposingDeity", span: .opponent)

    /// The table their hit zones are rolled on.
    var bodyPlan: BodyPlan { bodyPlanKind.plan(size: size) }

    /// Everything that changes between one attack and the next, cleared.
    mutating func resetPerAttack() {
        states = []
        facts = facts.filter { $0.key.span != .attack }
    }

    /// What the announcement does to the opponent's own defence.
    ///
    /// Nothing is applied — they have no PA to subtract from — so this is the
    /// figure the GM takes off theirs.
    func defenseModifiers(maneuver: CombatManeuver, isCriticalHit: Bool = false) -> [ModifierLine] {
        var lines: [ModifierLine] = []
        if case .finte(let tier) = maneuver {
            lines.append(ModifierLine(value: -tier * 2, source: L("maneuver.finte")))
        }
        if isProne {
            lines.append(ModifierLine(value: -2, source: L("opponent.prone")))
        }
        return lines
    }
}
```

- [ ] **Step 5: `ModifierLine.ruleId`**

In `Hesindion/Models/CombatManeuver.swift`:

```swift
struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
    var isZustand: Bool = false
    /// The catalog rule that produced it; `nil` for a line a Swift definition
    /// still makes. Tests look lines up by this, not by the label.
    var ruleId: String? = nil
}
```

- [ ] **Step 6: `ModifierEngine` reads a `Situation`**

In `Hesindion/Engine/ModifierEngine.swift`, delete the whole `// MARK: - ModifierContext` block (the struct with its 33 fields) and change the definition and engine:

```swift
// MARK: - ModifierDefinition

struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    let evaluate: (Situation) -> ModifierLine?
}

// MARK: - ModifierEngine

struct ModifierEngine {
    private let modifiers: [ModifierDefinition]

    init(modifiers: [ModifierDefinition]) {
        self.modifiers = modifiers
    }

    func evaluate(context situation: Situation) -> [ModifierLine] {
        guard let domain = situation.checkDomain else { return [] }
        let lines = modifiers
            .filter { $0.domains.contains(domain) }
            .compactMap { $0.evaluate(situation) }
        return Self.applyingZustandCap(lines)
    }
```

Keep `applyingZustandCap`, `totalModifier(context:)` (now taking a `Situation`) and the shared instance as they are.

- [ ] **Step 7: `CombatSituation` builds the `Situation`**

Replace `defenseModifiers(hero:isAusweichen:isOffHand:)` in `Hesindion/Engine/CombatSituation.swift`:

```swift
    func defenseModifiers(hero: Hero, isAusweichen: Bool, isOffHand: Bool = false) -> [ModifierLine] {
        var situation = Situation(hero: hero, domain: isAusweichen ? .meleeDodge : .meleeParry)
        situation.round = self
        situation.isOffHand = isOffHand
        return ModifierEngine.shared.evaluate(context: situation)
    }
```

- [ ] **Step 8: The definitions read the new paths**

Mechanical, one file at a time. `ctx` is now a `Situation`.

`SharedModifiers.swift`: `ctx.mounted` → `ctx.round.mounted`.

`StateModifiers.swift`: both `ctx.schipIgnoreZustand` → `ctx.round.schipIgnoreZustand`; in `penaltyDefinitions` replace `case .fixed(let map):  penalty = map[ctx.domain] ?? 0` with `case .fixed(let map):  penalty = ctx.checkDomain.flatMap { map[$0] } ?? 0`.

`MeleeModifiers.swift`: `ctx.mounted` → `ctx.round.mounted` (twice); `ctx.plaenklerActive` → `ctx.round.plaenklerActive`, `ctx.plaenklerBonus` → `ctx.round.plaenklerBonus`; `ctx.dualAttackActive` → `ctx.round.dualAttackActive`; `ctx.beengteUmgebung` → `ctx.round.beengteUmgebung`. Replace `attackerReach` and `weaponReach`:

```swift
    /// The reach of the thing being swung: the announced loadout piece where the
    /// screen says which, the main weapon otherwise.
    static func attackerReach(_ ctx: Situation) -> WeaponReach {
        if let name = ctx.loadoutName { return ctx.hero.reach(ofLoadoutNamed: name) }
        return WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
    }

    /// Weapon reach mismatch penalty.
    static let weaponReach = ModifierDefinition(
        id: "weaponReach",
        domains: [.meleeAttack]
    ) { ctx in
        let penalty = attackerReach(ctx).atPenaltyAgainst(ctx.opponent.reach)
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.reach"))
    }
```

`DefenseModifiers.swift`: `ctx.defenseCount` → `ctx.defencesThisRound`; `ctx.schipDefenseBoost` → `ctx.round.schipDefenseBoost`; `ctx.mounted` → `ctx.round.mounted` (twice); `ctx.plaenklerActive`/`ctx.plaenklerBonus` → `ctx.round.…`; `ctx.dualAttackActive` → `ctx.round.dualAttackActive`; `ctx.twoHandedGrip` → `ctx.round.twoHandedGrip`; `ctx.beengteUmgebung` → `ctx.round.beengteUmgebung`. `ctx.isOffHand` and `ctx.hero.selectedWeapon` stay.

`RangedModifiers.swift`: in `vomPferd`, `ctx.mounted` → `ctx.round.mounted`.

`HitZoneModifiers.swift`: `targetIsSurprised: ctx.targetIsSurprised` → `targetIsSurprised: ctx.opponent.isSurprised`.

`MagicModifiers.swift`: nothing changes (its fields kept their names).

- [ ] **Step 9: The views build a `Situation`**

`CombatAttackViews.swift`, replace `buildModifierLines()`:

```swift
    /// Everything this attack is evaluated against, for whichever domain asks.
    private func situation(_ domain: RuleDomain) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.mounted = mountedActive
        s.round.schipIgnoreZustand = schipIgnoreZustandThisRound
        s.round.dualAttackActive = dualAttackPenaltyActive
        s.round.beengteUmgebung = beengteUmgebungActive
        s.round.twoHandedGrip = twoHandedGripActive
        s.round.plaenklerActive = plaenklerActive
        s.round.plaenklerBonus = plaenklerBonus
        s.opponents = OpponentRoster([opponent])
        s.loadoutName = weaponName
        s.maneuver = selectedManeuver
        s.isOffHand = isOffHand
        s.targetHitZone = targetZone
        return s
    }

    private func buildModifierLines() -> [ModifierLine] {
        var lines = ModifierEngine.shared.evaluate(context: situation(.meleeAttack))

        // Manual vorteilhafte Position toggle (not golgariten-forced)
        if !golgaritenForced && opponent.advantageousPosition {
            lines.insert(ModifierLine(value: 2, source: L("source.vorteilhaft")), at: 0)
        }

        return lines
    }
```

`CombatFernkampfViews.swift`, in `buildModifierLines()`: `var context = Situation(hero: hero, domain: .rangedAttack)`; `context.targetIsSurprised = targetIsSurprised` → `context.opponents.current.isSurprised = targetIsSurprised`; `context.mounted = mountedActive` → `context.round.mounted = mountedActive`; `context.schipIgnoreZustand = …` → `context.round.schipIgnoreZustand = …`. The eight ranged assignments stay.

`CombatSpellViews.swift` and `SpellProbeModal.swift`: `ModifierContext(` → `Situation(`; `ctx.mounted = mountedActive` → `ctx.round.mounted = mountedActive`; `ctx.schipIgnoreZustand = …` → `ctx.round.schipIgnoreZustand = …`. The magic assignments and `gottgefaellig` stay.

`TalentProbeModal.swift`:

```swift
    private var modifierLines: [ModifierLine] {
        var situation = Situation(hero: hero, domain: .talentCheck)
        situation.talentId = talent.ruleId
        return ModifierEngine.shared.evaluate(context: situation)
    }
```

- [ ] **Step 10: The tests build a `Situation`**

`StateModifiersTests.swift`: every `ModifierContext(hero:` → `Situation(hero:`; `ctx.schipDefenseBoost = true` → `ctx.round.schipDefenseBoost = true`; `ctx.schipIgnoreZustand = true` → `ctx.round.schipIgnoreZustand = true` (twice, one is `mctx`); `ctx.beengteUmgebung = hero.hasState("eingeengt")` → `ctx.round.beengteUmgebung = hero.hasState("eingeengt")`; `bonusCtx.gottgefaellig`, `ctx.gottgefaellig` stay.

`HitZoneEngineIntegrationTests.swift` and `HitZoneModifiersTests.swift`: `ModifierContext(` → `Situation(`; `targetHitZone` assignments stay.

`WeaponReachTests.swift`: add a Mittel weapon to `armedHero()` (the Beengte test needs one now that reach is looked up by name):

```swift
            MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12",
                        damage: "1W6+3", at: 13, pa: 7, reach: "Mittel", weight: 1.2),
```

and replace the "Through the engine" helpers:

```swift
    private func atPenalty(_ hero: Hero, loadout: String?, opponent: WeaponReach) -> Int {
        var situation = Situation(hero: hero, domain: .meleeAttack)
        situation.opponents.current.reach = opponent
        situation.loadoutName = loadout
        return ModifierEngine.shared.evaluate(context: situation)
            .filter { $0.source == L("source.reach") }
            .reduce(0) { $0 + $1.value }
    }

    func testTheEngineUsesTheAnnouncedWeaponNotTheMainOne() {
        let hero = armedHero()   // main weapon is Lang
        XCTAssertEqual(atPenalty(hero, loadout: "Langschwert", opponent: .lang), 0)
        XCTAssertEqual(atPenalty(hero, loadout: "Dolch", opponent: .lang), -4,
                       "The dagger in the off hand reaches like a dagger")
    }

    func testTheEngineFallsBackToTheMainWeapon() {
        XCTAssertEqual(atPenalty(armedHero(), loadout: nil, opponent: .lang), 0)
    }

    func testBeengteUmgebungFollowsTheSameReach() {
        let hero = armedHero()
        func penalty(_ loadout: String) -> Int {
            var situation = Situation(hero: hero, domain: .meleeAttack)
            situation.round.beengteUmgebung = true
            situation.loadoutName = loadout
            return ModifierEngine.shared.evaluate(context: situation)
                .filter { $0.source == L("beengteUmgebung") }
                .reduce(0) { $0 + $1.value }
        }
        XCTAssertEqual(penalty("Langschwert"), -8)
        XCTAssertEqual(penalty("Säbel"), -4)
        XCTAssertEqual(penalty("Dolch"), 0)
```

Keep whatever assertions follow in that test unchanged apart from the same substitution.

- [ ] **Step 11: Run the whole target**

Run: `make test-ui` (background, 600 s timeout)
Expected: `** TEST SUCCEEDED **`, `SituationTests` listed. Check `git status`: no `__Snapshots__` changes.

- [ ] **Step 12: Commit**

```bash
git add Hesindion/Engine/Situation.swift Hesindion/Models/OpponentProfile.swift Hesindion/Engine/ModifierEngine.swift Hesindion/Engine/CombatSituation.swift Hesindion/Engine/SharedModifiers.swift Hesindion/Engine/StateModifiers.swift Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DefenseModifiers.swift Hesindion/Engine/RangedModifiers.swift Hesindion/Engine/HitZoneModifiers.swift Hesindion/Models/CombatManeuver.swift Hesindion/Views/CombatAttackViews.swift Hesindion/Views/CombatFernkampfViews.swift Hesindion/Views/CombatSpellViews.swift Hesindion/Views/SpellProbeModal.swift Hesindion/Views/TalentProbeModal.swift HesindionTests/SituationTests.swift HesindionTests/WeaponReachTests.swift HesindionTests/HitZoneEngineIntegrationTests.swift HesindionTests/HitZoneModifiersTests.swift HesindionTests/StateModifiersTests.swift
git commit -m "refactor(rules): a roll is evaluated against one Situation, not 33 flags"
```

### Task 2: The vocabulary, in Swift and as JSON

**Goal:** `Hesindion/Engine/RuleVocabulary.swift` is the closed list of predicates, effects, targets, domains and spans; its export is committed at `specs/data/rule-vocabulary.json` and a test keeps the two identical.

**Files:**
- Create: `Hesindion/Engine/RuleVocabulary.swift`
- Create: `specs/data/rule-vocabulary.json` (written by the test on first run)
- Test: `HesindionTests/RuleVocabularyTests.swift`

**Acceptance Criteria:**
- [ ] `RuleVocabulary.Predicate`, `.Effect`, `.Target`, `.Per`, `.ClauseKind`, `.OpponentType`, `.Combinator` are `String, CaseIterable` enums with exactly the cases listed in Step 3.
- [ ] `RuleVocabulary.exportJSON()` is deterministic (sorted keys) and ends with a newline.
- [ ] `specs/data/rule-vocabulary.json` equals the export byte for byte; when it does not, the test rewrites it and fails with a message naming the file.

**Verify:** `make test-ui` → `RuleVocabularyTests` passes; `git diff --stat specs/data/rule-vocabulary.json` empty after the second run.

**Steps:**

- [ ] **Step 1: Write the failing test**

`HesindionTests/RuleVocabularyTests.swift`:

```swift
import XCTest
@testable import Hesindion

/// The vocabulary is closed: what the Swift enums list is what the Python
/// build accepts and what the authoring pipeline may emit. The JSON file is
/// the handshake between the three, so it must equal the enums exactly.
final class RuleVocabularyTests: XCTestCase {

    /// `HesindionTests/RuleVocabularyTests.swift` → repository root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Record-style: on a mismatch the fresh export is written over the file
    /// and the test fails once, the way a snapshot test records. Commit the
    /// file and rerun.
    func testTheCommittedFileEqualsTheExport() throws {
        let url = Self.repoRoot.appending(path: "specs/data/rule-vocabulary.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.repoRoot.appending(path: "AGENTS.md").path),
                          "source tree not reachable (device run)")
        let fresh = RuleVocabulary.exportJSON()
        let onDisk = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if onDisk != fresh {
            try fresh.write(to: url, atomically: true, encoding: .utf8)
            XCTFail("specs/data/rule-vocabulary.json did not match RuleVocabulary; it has been rewritten — commit it and rerun")
        }
    }

    func testTheExportListsEveryEnum() throws {
        let data = Data(RuleVocabulary.exportJSON().utf8)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let predicates = try XCTUnwrap(root["predicates"] as? [String: Any])
        XCTAssertEqual(Set(predicates.keys), Set(RuleVocabulary.Predicate.allCases.map(\.rawValue)))
        let effects = try XCTUnwrap(root["effects"] as? [String: Any])
        XCTAssertEqual(Set(effects.keys), Set(RuleVocabulary.Effect.allCases.map(\.rawValue)))
        let enums = try XCTUnwrap(root["enums"] as? [String: [String]])
        XCTAssertEqual(enums["domain"], RuleDomain.allCases.map(\.rawValue))
        XCTAssertEqual(enums["target"], RuleVocabulary.Target.allCases.map(\.rawValue))
        XCTAssertEqual(enums["span"], FactSpan.allCases.map(\.rawValue))
        XCTAssertEqual(enums["reach"], WeaponReach.allCases.map(\.rawValue))
        XCTAssertEqual(enums["zone"], HitZone.allCases.map(\.rawValue))
        XCTAssertEqual(enums["kind"], RuleVocabulary.ClauseKind.allCases.map(\.rawValue))
        XCTAssertEqual(root["version"] as? Int, RuleVocabulary.version)
    }

    func testTheExportIsDeterministicAndEndsWithANewline() {
        let a = RuleVocabulary.exportJSON(), b = RuleVocabulary.exportJSON()
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasSuffix("\n"))
    }
}
```

- [ ] **Step 2: Run to see it fail**

Run: `make test-ui`
Expected: `cannot find 'RuleVocabulary' in scope`.

- [ ] **Step 3: Create `RuleVocabulary.swift`**

```swift
import Foundation

/// The closed vocabulary a catalog clause is written in (design §4).
///
/// Every item has one interpreter in `RuleEvaluator` and one test; adding one
/// is a code change and a human decision. `exportJSON()` writes the same
/// vocabulary for the Python build, which refuses a clause outside it, and for
/// the Flutter rewrite, which interprets the same file.
///
/// Only what the first nine fixtures and the `GRW_*` entries need is here.
/// The rest of design §4 arrives with the authoring batch that needs it.
enum RuleVocabulary {
    static let version = 1

    enum Combinator: String, CaseIterable { case all, any, not }

    enum Predicate: String, CaseIterable {
        case heroHasRule = "hero.hasRule"
        case heroState = "hero.state"
        case heroFokusRule = "hero.fokusRule"
        case loadoutWeapon = "loadout.weapon"
        case loadoutShield = "loadout.shield"
        case loadoutReach = "loadout.reach"
        case situationMounted = "situation.mounted"
        case situationBeengt = "situation.beengt"
        case situationDefencesThisRound = "situation.defencesThisRound"
        case situationTargetZone = "situation.targetZone"
        case situationWoundEffect = "situation.woundEffect"
        case opponentReach = "opponent.reach"
        case opponentOnFoot = "opponent.onFoot"
        case opponentState = "opponent.state"
        case opponentType = "opponent.type"
        case gmFact = "gm.fact"
    }

    enum Effect: String, CaseIterable { case add, multiply, opponentAdd, modifyRule, choice }

    /// `vw` is the Verteidigungswert — parry and dodge both. `talent` carries
    /// a `talentId`.
    enum Target: String, CaseIterable { case at, pa, aw, vw, fk, tp, talent }

    /// What an `add` value is multiplied by.
    enum Per: String, CaseIterable, Codable { case tier, defencesThisRound }

    enum ClauseKind: String, CaseIterable, Codable { case passive, offer }

    enum OpponentType: String, CaseIterable, Codable { case demon }

    // MARK: - Signatures

    /// Argument types: `string`, `strings` (one or a list), `int`, `number`,
    /// `bool`, `enum:<name>`, `list:<enum name>`.
    struct Signature {
        var args: [String: String] = [:]
        var required: [String] = []
        /// For items written as `{ name: scalar }` rather than `{ name: {…} }`.
        var value: String? = nil

        var json: [String: Any] {
            var d: [String: Any] = ["args": args, "required": required]
            if let value { d["value"] = value }
            return d
        }
    }

    static let predicateSignatures: [Predicate: Signature] = [
        .heroHasRule: Signature(args: ["id": "string", "minTier": "int"], required: ["id"]),
        .heroState: Signature(args: ["id": "string", "minLevel": "int"], required: ["id"]),
        .heroFokusRule: Signature(value: "string"),
        .loadoutWeapon: Signature(args: ["technique": "strings", "item": "string", "consecrated": "bool"]),
        .loadoutShield: Signature(args: ["item": "string"]),
        .loadoutReach: Signature(value: "enum:reach"),
        .situationMounted: Signature(),
        .situationBeengt: Signature(),
        .situationDefencesThisRound: Signature(args: ["min": "int"], required: ["min"]),
        .situationTargetZone: Signature(value: "list:zone"),
        .situationWoundEffect: Signature(),
        .opponentReach: Signature(value: "enum:reach"),
        .opponentOnFoot: Signature(),
        .opponentState: Signature(value: "string"),
        .opponentType: Signature(value: "enum:opponentType"),
        .gmFact: Signature(args: ["id": "string", "span": "enum:span"], required: ["id", "span"]),
    ]

    static let effectSignatures: [Effect: Signature] = [
        .add: Signature(args: ["target": "enum:target", "talentId": "string", "value": "int", "per": "enum:per"],
                        required: ["target", "value"]),
        .multiply: Signature(args: ["target": "enum:target", "talentId": "string", "factor": "number"],
                             required: ["target", "factor"]),
        .opponentAdd: Signature(args: ["target": "enum:target", "value": "int"], required: ["target", "value"]),
        .modifyRule: Signature(args: ["id": "string", "target": "enum:target", "talentId": "string",
                                      "add": "int", "set": "int", "multiply": "number"],
                               required: ["id", "target"]),
        .choice: Signature(value: "list:effect"),
    ]

    // MARK: - Export

    static func exportJSON() -> String {
        let root: [String: Any] = [
            "version": version,
            "combinators": Combinator.allCases.map(\.rawValue),
            "predicates": Dictionary(uniqueKeysWithValues: predicateSignatures.map { ($0.key.rawValue, $0.value.json) }),
            "effects": Dictionary(uniqueKeysWithValues: effectSignatures.map { ($0.key.rawValue, $0.value.json) }),
            "enums": [
                "target": Target.allCases.map(\.rawValue),
                "domain": RuleDomain.allCases.map(\.rawValue),
                "span": FactSpan.allCases.map(\.rawValue),
                "per": Per.allCases.map(\.rawValue),
                "reach": WeaponReach.allCases.map(\.rawValue),
                "zone": HitZone.allCases.map(\.rawValue),
                "opponentType": OpponentType.allCases.map(\.rawValue),
                "kind": ClauseKind.allCases.map(\.rawValue),
                "tiers": ["owned"],
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
```

- [ ] **Step 4: Run twice**

Run: `make test-ui`. First run: `testTheCommittedFileEqualsTheExport` fails with "has been rewritten" and `specs/data/rule-vocabulary.json` appears. Run again: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Hesindion/Engine/RuleVocabulary.swift specs/data/rule-vocabulary.json HesindionTests/RuleVocabularyTests.swift
git commit -m "feat(rules): the clause vocabulary is a closed list, exported for the build"
```

---

### Task 3: The build validates clauses and compiles them to JSON

**Goal:** `make rules-db` refuses a clause outside the vocabulary, accepts `GRW_*` ids that are not in `rules.db`, and writes each entry's name, `applies_with` and `clauses` (normalised JSON) into the `catalog` table.

**Files:**
- Modify: `scripts/build_rules_db/catalog.py`
- Modify: `scripts/build_rules_db/build_db.py:19-27, 876-877`
- Modify: `Makefile:133-140`
- Test: `scripts/build_rules_db/test_catalog.py`

**Acceptance Criteria:**
- [ ] A `GRW_x` entry passes validation without a `rules.db` row; a `GRW_x` name or group is not checked against the database; any other id not in `rules.db` still fails.
- [ ] Unknown predicate, effect, target, domain, span, clause kind or clause key each produce one problem line naming the entry and the clause.
- [ ] `modifyRule.id` must name an `implemented` entry.
- [ ] `catalog` has columns `name`, `applies_with`, `clauses`; the design's Golgariten example normalises to the JSON in Step 3's test.
- [ ] `--vocabulary` is required by `build_db.py` and passed by the Makefile.
- [ ] `catalog_meta` carries `vocabulary_sha256`, the SHA-256 of the vocabulary file the build validated against, so a Swift test (Task 4) can tell a database built against a stale export.
- [ ] `load_vocabulary` checks the vocabulary itself once, at load: every `args` value and every `value` in both tables is one of `string`, `strings`, `int`, `number`, `bool`, `enum:X` / `list:X` with `X` under `enums`, or the one documented exception `list:effect`; `enums` carries `kind`, `domain`, `target` and `span`; anything else is a `CatalogError` naming the table, the item and the token. `_check_type` rejects an unknown token rather than accepting it. (`VocabularyLoadTests`, seven cases; added after review.) The `INSERT INTO catalog` names its columns; `build_db.py` asserts the vocabulary file exists before the import.

**Verify:** `make test-rules-db` → `OK`; `make rules-db` → the existing catalog (no clauses yet) builds, `git diff --stat` shows only `Hesindion/Resources/rules.db`.

**Steps:**

- [ ] **Step 1: Write the failing tests**

Append to `scripts/build_rules_db/test_catalog.py` (keep the existing classes; `entry`, `RULES` and the imports are already there):

```python
REPO_ROOT = Path(__file__).resolve().parents[2]

# A cut-down vocabulary with the same shape as specs/data/rule-vocabulary.json.
VOCAB = {
    "version": 1,
    "combinators": ["all", "any", "not"],
    "predicates": {
        "situation.mounted": {"args": {}, "required": []},
        "opponent.onFoot": {"args": {}, "required": []},
        "hero.fokusRule": {"args": {}, "required": [], "value": "string"},
        "loadout.reach": {"args": {}, "required": [], "value": "enum:reach"},
        "situation.targetZone": {"args": {}, "required": [], "value": "list:zone"},
        "loadout.weapon": {"args": {"technique": "strings", "item": "string", "consecrated": "bool"}, "required": []},
        "loadout.shield": {"args": {"item": "string"}, "required": []},
        "gm.fact": {"args": {"id": "string", "span": "enum:span"}, "required": ["id", "span"]},
    },
    "effects": {
        "add": {"args": {"target": "enum:target", "talentId": "string", "value": "int", "per": "enum:per"},
                "required": ["target", "value"]},
        "modifyRule": {"args": {"id": "string", "target": "enum:target", "talentId": "string",
                                "add": "int", "set": "int", "multiply": "number"},
                       "required": ["id", "target"]},
        "choice": {"args": {}, "required": [], "value": "list:effect"},
    },
    "enums": {
        "target": ["at", "pa", "vw", "talent"],
        "domain": ["meleeAttack", "meleeParry", "talentCheck"],
        "span": ["hero", "opponent", "attack", "round"],
        "per": ["tier", "defencesThisRound"],
        "reach": ["Kurz", "Mittel", "Lang"],
        "zone": ["kopf", "torso"],
        "kind": ["passive", "offer"],
        "tiers": ["owned"],
    },
}

GOLGARITEN = {
    "id": "SA_1", "name": "Erste", "group": "Kampf", "status": "implemented",
    "applies_with": {"all": [
        "situation.mounted",
        {"any": [
            {"loadout.weapon": {"technique": "CT_5", "item": "Rabenschnabel"}},
            {"loadout.shield": {"item": "Großschild"}},
        ]},
    ]},
    "clauses": [
        {"kind": "passive", "domains": ["meleeAttack"], "when": ["opponent.onFoot"],
         "effects": [{"modifyRule": {"id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}}]},
        {"kind": "passive", "domains": ["meleeParry"],
         "effects": [{"add": {"target": "pa", "value": 1}}]},
    ],
}

GRW = {"id": "GRW_vorteilhaftePosition", "name": "Vorteilhafte Position", "group": "Grundregel",
       "status": "implemented",
       "clauses": [{"kind": "passive", "domains": ["meleeAttack"], "when": ["situation.mounted", "opponent.onFoot"],
                    "effects": [{"add": {"target": "at", "value": 2}}]}]}


class ClauseValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def validate(self, *entries):
        # Pad with a plain entry for every rules.db id the test did not supply,
        # so the coverage check ("SA_1: no catalog entry") stays out of the way.
        given = {e["id"] for e in entries}
        pad = [entry(id=rid, name=name) for rid, name in RULES.items() if rid not in given]
        return catalog.validate(list(entries) + pad, RULES, self.root, vocabulary=VOCAB)

    def test_the_design_example_is_valid(self):
        self.assertEqual(self.validate(GOLGARITEN, GRW), [])

    def test_a_grw_id_needs_no_rules_row_but_others_still_do(self):
        problems = self.validate(GRW, dict(GRW, id="GRX_nope"))
        self.assertIn("GRX_nope: not in rules.db", problems)
        self.assertFalse(any(p.startswith("GRW_vorteilhaftePosition:") for p in problems))

    def test_a_grw_name_and_group_are_not_checked_against_the_database(self):
        groups = {"SA_1": "Kampf", "SA_2": "Kampf"}
        self.assertEqual(catalog.validate([entry(), entry(id="SA_2", name="Zweite"), GRW], RULES, self.root, groups, VOCAB), [])

    def test_an_unknown_predicate_effect_target_domain_and_kind_are_named(self):
        bad = dict(GRW, id="GRW_bad", clauses=[{
            "kind": "sometimes", "domains": ["meleeAttack", "swimming"],
            "when": ["situation.raining", {"gm.fact": {"id": "x", "span": "century"}}],
            "effects": [{"add": {"target": "luck", "value": 1}}, {"sing": {}}],
        }])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: kind 'sometimes' is not one of passive, offer", problems)
        self.assertIn("GRW_bad: clause 0: unknown domain 'swimming'", problems)
        self.assertIn("GRW_bad: clause 0: unknown predicate 'situation.raining'", problems)
        self.assertIn("GRW_bad: clause 0: gm.fact.span is 'century', expected enum:span", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: add.target is 'luck', expected enum:target", problems)
        self.assertIn("GRW_bad: clause 0 effect 1: unknown effect 'sing'", problems)

    def test_an_unknown_clause_key_and_a_missing_argument_are_named(self):
        bad = dict(GRW, id="GRW_bad", clauses=[{
            "kind": "passive", "domains": ["meleeAttack"], "cost": 1,
            "when": [{"gm.fact": {"id": "x"}}, {"loadout.weapon": {"colour": "red"}}],
            "effects": [{"add": {"target": "at"}}],
        }])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: unknown clause key 'cost'", problems)
        self.assertIn("GRW_bad: clause 0: gm.fact needs span", problems)
        self.assertIn("GRW_bad: clause 0: loadout.weapon has no argument 'colour'", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: add needs value", problems)

    def test_a_scalar_predicate_takes_its_value_form(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                  "when": [{"hero.fokusRule": "trefferzonen"}, {"loadout.reach": "Kurz"},
                           {"situation.targetZone": ["kopf", "torso"]}],
                  "effects": [{"add": {"target": "at", "value": -2}}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                   "when": [{"loadout.reach": "Weit"}, {"situation.targetZone": ["nase"]}, "hero.fokusRule"],
                   "effects": [{"add": {"target": "at", "value": -2}}]}])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: loadout.reach is 'Weit', expected enum:reach", problems)
        self.assertIn("GRW_bad: clause 0: situation.targetZone is ['nase'], expected list:zone", problems)
        self.assertIn("GRW_bad: clause 0: hero.fokusRule needs an argument", problems)

    def test_modify_rule_must_name_an_implemented_entry_and_do_something(self):
        lonely = dict(GOLGARITEN)   # GRW not in the catalog
        problems = self.validate(lonely)
        self.assertIn("SA_1: clause 0 effect 0: modifyRule names 'GRW_vorteilhaftePosition', which is not an implemented entry", problems)
        idle = dict(GOLGARITEN, clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                    "effects": [{"modifyRule": {"id": "GRW_vorteilhaftePosition", "target": "at"}}]}])
        self.assertIn("SA_1: clause 0 effect 0: modifyRule needs add, set or multiply", self.validate(idle, GRW))

    def test_a_talent_target_carries_its_id(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "passive", "domains": ["talentCheck"],
                  "effects": [{"add": {"target": {"talent": "TAL_8"}, "value": -2}}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["talentCheck"],
                   "effects": [{"add": {"target": "talent", "value": -2}}]}])
        self.assertIn("GRW_bad: clause 0 effect 0: target talent needs an id", self.validate(GRW, bad))

    def test_an_offer_with_a_choice_and_tiers(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "offer", "domains": ["meleeAttack", "meleeParry"], "tiers": "owned",
                  "effects": [{"choice": [{"add": {"target": "at", "value": 1}}, {"add": {"target": "vw", "value": 1}}]}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["meleeAttack"], "tiers": 0,
                   "effects": [{"choice": [{"add": {"target": "at", "value": 1}}]}]}])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: tiers is only for an offer", problems)
        self.assertIn("GRW_bad: clause 0: tiers is 0, expected 'owned' or a positive integer", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: choice needs at least two options", problems)

    def test_implemented_needs_a_non_empty_clause_list(self):
        self.assertIn("GRW_bad: implemented needs a non-empty clauses list",
                      self.validate(GRW, dict(GRW, id="GRW_bad", clauses=[])))
        self.assertIn("GRW_bad: implemented needs a non-empty clauses list",
                      self.validate(GRW, dict(GRW, id="GRW_bad", clauses="yes")))

    def test_the_committed_vocabulary_accepts_the_design_example(self):
        vocab = catalog.load_vocabulary(REPO_ROOT / "specs/data/rule-vocabulary.json")
        problems = catalog.validate([GOLGARITEN, GRW, entry(id="SA_2", name="Zweite")], RULES, self.root, vocabulary=vocab)
        self.assertEqual(problems, [])


class NormalizeTests(unittest.TestCase):
    def test_the_design_example_normalises(self):
        applies, clauses = catalog.entry_json(GOLGARITEN)
        self.assertEqual(json.loads(applies), {"all": [
            {"is": "situation.mounted"},
            {"any": [
                {"is": "loadout.weapon", "technique": "CT_5", "item": "Rabenschnabel"},
                {"is": "loadout.shield", "item": "Großschild"},
            ]},
        ]})
        self.assertEqual(json.loads(clauses), [
            {"kind": "passive", "domains": ["meleeAttack"], "when": {"all": [{"is": "opponent.onFoot"}]},
             "effects": [{"effect": "modifyRule", "id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}]},
            {"kind": "passive", "domains": ["meleeParry"],
             "effects": [{"effect": "add", "target": "pa", "value": 1}]},
        ])

    def test_scalars_choices_talents_and_not(self):
        e = dict(GRW, clauses=[{"kind": "offer", "domains": ["meleeAttack"], "tiers": "owned",
                 "when": {"not": {"hero.fokusRule": "trefferzonen"}},
                 "effects": [{"choice": [{"add": {"target": "at", "value": 1}},
                                         {"add": {"target": {"talent": "TAL_8"}, "value": -2}}]}]}])
        _, clauses = catalog.entry_json(e)
        self.assertEqual(json.loads(clauses), [
            {"kind": "offer", "domains": ["meleeAttack"], "tiers": "owned",
             "when": {"not": {"is": "hero.fokusRule", "value": "trefferzonen"}},
             "effects": [{"effect": "choice", "options": [
                 {"effect": "add", "target": "at", "value": 1},
                 {"effect": "add", "target": "talent", "talentId": "TAL_8", "value": -2},
             ]}]},
        ])

    def test_a_non_implemented_entry_has_no_json(self):
        self.assertEqual(catalog.entry_json(entry()), (None, None))


class ClauseTableTests(unittest.TestCase):
    def test_the_table_carries_name_applies_with_and_clauses(self):
        conn = sqlite3.connect(":memory:")
        catalog.write_catalog_table(conn, [GOLGARITEN, entry(id="SA_2", name="Zweite")])
        rows = conn.execute("SELECT rule_id, name, applies_with IS NOT NULL, clauses IS NOT NULL "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [("SA_1", "Erste", 1, 1), ("SA_2", "Zweite", 0, 0)])
        clauses = json.loads(conn.execute("SELECT clauses FROM catalog WHERE rule_id = 'SA_1'").fetchone()[0])
        self.assertEqual(clauses[1]["effects"], [{"effect": "add", "target": "pa", "value": 1}])
```

Add to the existing `ImportCatalogTests` class:

```python
    def test_the_vocabulary_hash_is_stored(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        conn = self._conn()
        vocab = REPO_ROOT / "specs/data/rule-vocabulary.json"
        catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True, vocabulary_path=vocab)
        stored = conn.execute(
            "SELECT value FROM catalog_meta WHERE key = 'vocabulary_sha256'").fetchone()[0]
        self.assertEqual(stored, catalog.source_hash(vocab))
```

Also change the two existing `import_catalog` call sites in `ImportCatalogTests` to pass `vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json"` (all five calls), and `test_implemented_needs_clauses` in `ValidateTests` to expect the new wording:

```python
    def test_implemented_needs_clauses(self):
        no_clauses = entry(id="SA_2", name="Zweite", status="implemented")
        self.assertEqual(catalog.validate([entry(), no_clauses], RULES, self.root),
                         ["SA_2: implemented needs a non-empty clauses list"])
```

- [ ] **Step 2: Run to see them fail**

Run: `make test-rules-db`
Expected: `AttributeError: module 'catalog' has no attribute 'load_vocabulary'` and the `validate()` keyword error.

- [ ] **Step 3: Implement in `catalog.py`**

Replace the module docstring's second paragraph with "This file is steps 1 and 2 of §7: statuses, pointers, and — for `implemented` — clauses checked against `specs/data/rule-vocabulary.json` and compiled to JSON." Add after `KNOWN_KEYS`:

```python
CLAUSE_KEYS = {"kind", "domains", "when", "effects", "tiers"}
# Entries for core rules that have no Optolith id (design §4). Exempt from the
# rules.db checks; everything else about them is checked like any other entry.
CORE_PREFIX = "GRW_"


def load_vocabulary(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        vocab = json.load(f)
    for key in ("predicates", "effects", "enums", "combinators"):
        if key not in vocab:
            raise CatalogError(f"{path}: vocabulary has no {key!r}")
    return vocab
```

Change `validate`'s signature and the id/name/group/implemented checks:

```python
def validate(entries: list[dict], rules: dict[str, str], repo_root: Path,
             groups: dict[str, str] | None = None, vocabulary: dict | None = None) -> list[str]:
    """Every problem with the catalog, as one line each. Empty means valid.

    `rules` maps every rule id in rules.db to its German name. `groups`, when given,
    maps every rule id to its expected group label; omit it to skip that check.
    `vocabulary`, when given, is what `implemented` clauses are checked against;
    omit it to check statuses and pointers only.
    """
    problems: list[str] = []
    seen: set[str] = set()
    implemented_ids = {e["id"] for e in entries
                       if isinstance(e, dict) and e.get("status") == "implemented" and "id" in e}
    for i, e in enumerate(entries):
        if not isinstance(e, dict):
            problems.append(f"entry {i}: not a mapping")
            continue
        rid = e.get("id", "?")
        missing = [k for k in REQUIRED if k not in e]
        if missing:
            problems.append(f"{rid}: missing {', '.join(missing)}")
            continue
        for k in sorted(e):
            if k not in KNOWN_KEYS:
                problems.append(f"{rid}: unknown key {k!r}")
        if rid in seen:
            problems.append(f"{rid}: listed twice")
        seen.add(rid)
        core = isinstance(rid, str) and rid.startswith(CORE_PREFIX)
        if not core:
            if rid not in rules:
                problems.append(f"{rid}: not in rules.db")
                continue
            if e["name"] != rules[rid]:
                problems.append(f"{rid}: name is {e['name']!r}, rules.db says {rules[rid]!r}")
            if groups is not None and rid in groups and e["group"] != groups[rid]:
                problems.append(f"{rid}: group is {e['group']!r}, rules.db says {groups[rid]!r}")
        status = e["status"]
        if status not in STATUSES:
            problems.append(f"{rid}: status {status!r} is not one of {', '.join(STATUSES)}")
            continue
        if status == "byHand":
            problems.extend(_check_pointer(rid, e.get("pointer"), repo_root))
            if not e.get("note"):
                problems.append(f"{rid}: byHand without note")
        if status == "todo" and not e.get("why"):
            problems.append(f"{rid}: todo without why")
        if status == "noRollEffect" and not e.get("note"):
            problems.append(f"{rid}: noRollEffect without note")
        if status == "implemented":
            clauses = e.get("clauses")
            if not isinstance(clauses, list) or not clauses:
                problems.append(f"{rid}: implemented needs a non-empty clauses list")
            elif vocabulary is not None:
                problems.extend(_check_clauses(rid, e, vocabulary, implemented_ids))
    for rid in rules:
        if rid not in seen:
            problems.append(f"{rid}: no catalog entry")
    return problems
```

Add the clause checks after `_check_pointer`:

```python
def _check_clauses(rid: str, e: dict, vocab: dict, implemented_ids: set[str]) -> list[str]:
    problems: list[str] = []
    if "applies_with" in e:
        problems.extend(_check_predicate(rid, e["applies_with"], vocab, "applies_with"))
    for i, c in enumerate(e["clauses"]):
        where = f"clause {i}"
        if not isinstance(c, dict):
            problems.append(f"{rid}: {where} is not a mapping")
            continue
        for k in sorted(c):
            if k not in CLAUSE_KEYS:
                problems.append(f"{rid}: {where}: unknown clause key {k!r}")
        kinds = vocab["enums"]["kind"]
        if c.get("kind") not in kinds:
            problems.append(f"{rid}: {where}: kind {c.get('kind')!r} is not one of {', '.join(kinds)}")
        domains = c.get("domains")
        if not isinstance(domains, list) or not domains:
            problems.append(f"{rid}: {where}: needs a non-empty domains list")
        else:
            for d in domains:
                if d not in vocab["enums"]["domain"]:
                    problems.append(f"{rid}: {where}: unknown domain {d!r}")
        if "when" in c:
            problems.extend(_check_predicate(rid, c["when"], vocab, where))
        effects = c.get("effects")
        if not isinstance(effects, list) or not effects:
            problems.append(f"{rid}: {where}: needs a non-empty effects list")
        else:
            for j, eff in enumerate(effects):
                problems.extend(_check_effect(rid, eff, vocab, f"{where} effect {j}", implemented_ids))
        if "tiers" in c:
            if c.get("kind") != "offer":
                problems.append(f"{rid}: {where}: tiers is only for an offer")
            t = c["tiers"]
            if not (t == "owned" or (isinstance(t, int) and not isinstance(t, bool) and t > 0)):
                problems.append(f"{rid}: {where}: tiers is {t!r}, expected 'owned' or a positive integer")
    return problems


def _check_predicate(rid: str, p, vocab: dict, where: str) -> list[str]:
    if isinstance(p, list):
        return [x for q in p for x in _check_predicate(rid, q, vocab, where)]
    if isinstance(p, str):
        sig = vocab["predicates"].get(p)
        if sig is None:
            return [f"{rid}: {where}: unknown predicate {p!r}"]
        if sig.get("value") or sig.get("required"):
            return [f"{rid}: {where}: {p} needs an argument"]
        return []
    if isinstance(p, dict) and len(p) == 1:
        name, arg = next(iter(p.items()))
        if name in ("all", "any"):
            if not isinstance(arg, list) or not arg:
                return [f"{rid}: {where}: {name} needs a non-empty list"]
            return [x for q in arg for x in _check_predicate(rid, q, vocab, where)]
        if name == "not":
            return _check_predicate(rid, arg, vocab, where)
        sig = vocab["predicates"].get(name)
        if sig is None:
            return [f"{rid}: {where}: unknown predicate {name!r}"]
        return _check_args(rid, name, arg, sig, vocab, where)
    return [f"{rid}: {where}: a predicate is a name, a {{name: argument}} mapping, or a list"]


def _check_effect(rid: str, eff, vocab: dict, where: str, implemented_ids: set[str]) -> list[str]:
    if not (isinstance(eff, dict) and len(eff) == 1):
        return [f"{rid}: {where}: an effect is a {{name: arguments}} mapping"]
    name, arg = next(iter(eff.items()))
    sig = vocab["effects"].get(name)
    if sig is None:
        return [f"{rid}: {where}: unknown effect {name!r}"]
    if name == "choice":
        if not isinstance(arg, list) or len(arg) < 2:
            return [f"{rid}: {where}: choice needs at least two options"]
        return [x for k, o in enumerate(arg)
                for x in _check_effect(rid, o, vocab, f"{where} option {k}", implemented_ids)]
    if not isinstance(arg, dict):
        return [f"{rid}: {where}: {name} takes a mapping"]
    arg = _with_talent_target(arg)
    problems = _check_args(rid, name, arg, sig, vocab, where)
    if arg.get("target") == "talent" and "talentId" not in arg:
        problems.append(f"{rid}: {where}: target talent needs an id")
    if name == "modifyRule":
        if arg.get("id") not in implemented_ids:
            problems.append(f"{rid}: {where}: modifyRule names {arg.get('id')!r}, which is not an implemented entry")
        if not any(k in arg for k in ("add", "set", "multiply")):
            problems.append(f"{rid}: {where}: modifyRule needs add, set or multiply")
    return problems


def _with_talent_target(arg: dict) -> dict:
    """`target: { talent: TAL_8 }` becomes `target: talent, talentId: TAL_8`."""
    target = arg.get("target")
    if isinstance(target, dict) and list(target) == ["talent"]:
        arg = dict(arg)
        arg["target"] = "talent"
        arg["talentId"] = target["talent"]
    return arg


def _check_args(rid: str, name: str, arg, sig: dict, vocab: dict, where: str) -> list[str]:
    if "value" in sig:
        return _check_type(rid, name, arg, sig["value"], vocab, where)
    if not isinstance(arg, dict):
        return [f"{rid}: {where}: {name} takes a mapping"]
    problems: list[str] = []
    for k in sorted(arg):
        if k not in sig["args"]:
            problems.append(f"{rid}: {where}: {name} has no argument {k!r}")
    for k in sig.get("required", []):
        if k not in arg:
            problems.append(f"{rid}: {where}: {name} needs {k}")
    for k, v in arg.items():
        if k in sig["args"]:
            problems.extend(_check_type(rid, f"{name}.{k}", v, sig["args"][k], vocab, where))
    return problems


def _check_type(rid: str, name: str, v, t: str, vocab: dict, where: str) -> list[str]:
    is_int = isinstance(v, int) and not isinstance(v, bool)
    if t == "string":
        ok = isinstance(v, str) and bool(v)
    elif t == "strings":
        ok = (isinstance(v, str) and bool(v)) or (isinstance(v, list) and bool(v) and all(isinstance(x, str) for x in v))
    elif t == "int":
        ok = is_int
    elif t == "number":
        ok = is_int or isinstance(v, float)
    elif t == "bool":
        ok = isinstance(v, bool)
    elif t.startswith("enum:"):
        ok = v in vocab["enums"].get(t[5:], [])
    elif t.startswith("list:"):
        allowed = vocab["enums"].get(t[5:], [])
        ok = isinstance(v, list) and bool(v) and all(x in allowed for x in v)
    else:
        ok = True
    return [] if ok else [f"{rid}: {where}: {name} is {v!r}, expected {t}"]


# --- Normalisation: the YAML forms become one JSON shape the Swift decoder reads.

def normalize_predicate(p) -> dict:
    if isinstance(p, list):
        return {"all": [normalize_predicate(q) for q in p]}
    if isinstance(p, str):
        return {"is": p}
    name, arg = next(iter(p.items()))
    if name in ("all", "any"):
        return {name: [normalize_predicate(q) for q in arg]}
    if name == "not":
        return {"not": normalize_predicate(arg)}
    if isinstance(arg, dict):
        return {"is": name, **arg}
    return {"is": name, "value": arg}


def normalize_effect(e) -> dict:
    name, arg = next(iter(e.items()))
    if name == "choice":
        return {"effect": "choice", "options": [normalize_effect(o) for o in arg]}
    return {"effect": name, **_with_talent_target(arg)}


def normalize_clause(c: dict) -> dict:
    out = {"kind": c["kind"], "domains": list(c["domains"]),
           "effects": [normalize_effect(e) for e in c["effects"]]}
    if "when" in c:
        out["when"] = normalize_predicate(c["when"])
    if "tiers" in c:
        out["tiers"] = c["tiers"]
    return out


def entry_json(e: dict) -> tuple[str | None, str | None]:
    """(applies_with, clauses) as JSON text, or (None, None) unless implemented."""
    if e.get("status") != "implemented":
        return None, None
    dumps = lambda o: json.dumps(o, ensure_ascii=False, sort_keys=True)
    applies = dumps(normalize_predicate(e["applies_with"])) if "applies_with" in e else None
    return applies, dumps([normalize_clause(c) for c in e["clauses"]])
```

Change `write_catalog_table` — its signature gains the vocabulary hash, written to `catalog_meta` beside the source hash:

```python
def write_catalog_table(conn, entries: list[dict], source_sha256: str | None = None,
                        vocabulary_sha256: str | None = None) -> None:
    ...
    if source_sha256 is not None:
        conn.execute("INSERT INTO catalog_meta VALUES (?, ?)", ("source_sha256", source_sha256))
    if vocabulary_sha256 is not None:
        conn.execute("INSERT INTO catalog_meta VALUES (?, ?)", ("vocabulary_sha256", vocabulary_sha256))
    ...
    conn.execute("""
        CREATE TABLE catalog (
            rule_id        TEXT PRIMARY KEY,
            name           TEXT NOT NULL,
            status         TEXT NOT NULL,
            note           TEXT,
            pointer_file   TEXT,
            pointer_symbol TEXT,
            reviewed_by    TEXT,
            reviewed_on    TEXT,
            applies_with   TEXT,
            clauses        TEXT
        )
    """)
    ...
    for e in entries:
        pointer = e.get("pointer") or {}
        reviewed = e.get("reviewed") or {}
        applies, clauses = entry_json(e)
        conn.execute(
            "INSERT INTO catalog VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                e["id"],
                e["name"],
                e["status"],
                e.get("note") or e.get("why"),
                pointer.get("file"),
                pointer.get("symbol"),
                reviewed.get("by"),
                str(reviewed["date"]) if reviewed.get("date") is not None else None,
                applies,
                clauses,
            ),
        )
```

Fix the existing `TableTests.test_the_table_holds_one_row_per_entry` for the new column order: select `rule_id, name, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on` and expect `("SA_1", "Erste", "todo", "not yet read", None, None, None, None)` and `("SA_2", "Zweite", "byHand", "by hand", "Hero.swift", "x", "sam", "2026-09-14")`.

Change `import_catalog`:

```python
def import_catalog(conn: sqlite3.Connection, catalog_path: Path, snapshot_path: Path,
                    repo_root: Path, update_snapshot: bool, vocabulary_path: Path) -> None:
    entries = load_catalog(catalog_path)
    vocabulary = load_vocabulary(vocabulary_path)
    ...
    problems = validate(entries, rules, repo_root, groups, vocabulary)
    ...
    write_catalog_table(conn, entries, source_hash(catalog_path), source_hash(vocabulary_path))
```

(The `write_catalog_table` call at the end of `import_catalog` gains the vocabulary hash as its fourth argument.)

`build_db.py`: add after `--repo-root`:

```python
    p.add_argument("--vocabulary", required=True, type=Path,
                   help="Path to specs/data/rule-vocabulary.json, the closed clause vocabulary")
```

and pass it: `catalog.import_catalog(conn, args.catalog, args.snapshot, args.repo_root, args.update_snapshot, args.vocabulary)`.

`Makefile` `rules-db` target: add the line `--vocabulary specs/data/rule-vocabulary.json \` after `--repo-root . \`.

- [ ] **Step 4: Run the Python tests and the build**

Run: `make test-rules-db` → `OK` (all tests). Run: `make rules-db` → prints `catalog: implemented 0, byHand 45, noRollEffect 0, todo 2630`; `git diff --stat` shows `Hesindion/Resources/rules.db` only.

- [ ] **Step 5: Commit**

```bash
git add scripts/build_rules_db/catalog.py scripts/build_rules_db/test_catalog.py scripts/build_rules_db/build_db.py Makefile Hesindion/Resources/rules.db
git commit -m "feat(rules): the build checks clauses against the vocabulary and compiles them to JSON"
```

### Task 4: Swift reads the compiled clauses

**Goal:** `RuleCatalog.bundled` holds every `implemented` entry of `rules.db` as typed `CatalogRule`s, decoded from the JSON the build wrote.

**Files:**
- Create: `Hesindion/Engine/RuleCatalog.swift`
- Modify: `Hesindion/Services/RulesDatabase.swift:64-76, 297-365`
- Test: `HesindionTests/RuleCatalogDecodingTests.swift`, `HesindionTests/RulesCatalogTests.swift`

**Acceptance Criteria:**
- [ ] The normalised Golgariten JSON from Task 3 decodes to the `CatalogRule` value in Step 1.
- [ ] An unknown predicate, effect, target, reach, zone or span name throws a `DecodingError` naming it.
- [ ] `RulesDatabase.shared.implementedRules().count == catalogStatusCounts()[.implemented] ?? 0`.
- [ ] `CatalogEntry` carries `name`; `catalogEntries(idPrefix:)` and `allCatalogEntries()` exist.
- [ ] `RulesDatabase.catalogVocabularyHash()` returns `catalog_meta.vocabulary_sha256`, and `RuleVocabularyTests.testTheDatabaseWasBuiltAgainstThisVocabulary` compares it with the SHA-256 of `RuleVocabulary.exportJSON()` — a `RuleVocabulary` edit without `make rules-db` fails there in seconds, not only in the record test.
- [ ] The doc comment on `RuleVocabulary.Signature` says `list:effect` refers to the effects table, the one `list:` token with no entry under `enums`.

**Verify:** `make test-ui` → `RuleCatalogDecodingTests`, `RuleVocabularyTests` and `RulesCatalogTests` pass.

**Steps:**

- [ ] **Step 1: Write the failing tests**

`HesindionTests/RuleCatalogDecodingTests.swift`:

```swift
import XCTest
@testable import Hesindion

/// The JSON the Python build writes into `catalog.clauses` is the contract
/// between the two sides; these are the shapes it takes.
final class RuleCatalogDecodingTests: XCTestCase {

    private func predicate(_ json: String) throws -> RulePredicate {
        try JSONDecoder().decode(RulePredicate.self, from: Data(json.utf8))
    }

    private func clauses(_ json: String) throws -> [RuleClause] {
        try JSONDecoder().decode([RuleClause].self, from: Data(json.utf8))
    }

    /// The design's worked example, as `catalog.entry_json` emits it.
    func testTheDesignExampleDecodes() throws {
        let applies = try predicate("""
        {"all": [{"is": "situation.mounted"},
                 {"any": [{"is": "loadout.weapon", "technique": "CT_5", "item": "Rabenschnabel"},
                          {"is": "loadout.shield", "item": "Großschild"}]}]}
        """)
        XCTAssertEqual(applies, .all([
            .situationMounted,
            .any([.loadoutWeapon(technique: ["CT_5"], item: "Rabenschnabel", consecrated: nil),
                  .loadoutShield(item: "Großschild")]),
        ]))
        let decoded = try clauses("""
        [{"kind": "passive", "domains": ["meleeAttack"], "when": {"all": [{"is": "opponent.onFoot"}]},
          "effects": [{"effect": "modifyRule", "id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}]},
         {"kind": "passive", "domains": ["meleeParry"],
          "effects": [{"effect": "add", "target": "pa", "value": 1}]}]
        """)
        XCTAssertEqual(decoded, [
            RuleClause(kind: .passive, domains: [.meleeAttack], when: .all([.opponentOnFoot]),
                       effects: [.modifyRule(id: "GRW_vorteilhaftePosition", target: .at, add: 2, set: nil, multiply: nil)],
                       tiers: nil),
            RuleClause(kind: .passive, domains: [.meleeParry], when: nil,
                       effects: [.add(target: .pa, value: 1, per: nil)], tiers: nil),
        ])
    }

    func testScalarPredicatesAndLists() throws {
        XCTAssertEqual(try predicate(#"{"is": "hero.fokusRule", "value": "trefferzonen"}"#), .heroFokusRule("trefferzonen"))
        XCTAssertEqual(try predicate(#"{"is": "loadout.reach", "value": "Kurz"}"#), .loadoutReach(.kurz))
        XCTAssertEqual(try predicate(#"{"is": "opponent.reach", "value": "Lang"}"#), .opponentReach(.lang))
        XCTAssertEqual(try predicate(#"{"is": "situation.targetZone", "value": ["kopf", "torso"]}"#), .situationTargetZone([.kopf, .torso]))
        XCTAssertEqual(try predicate(#"{"is": "opponent.state", "value": "liegend"}"#), .opponentState("liegend"))
        XCTAssertEqual(try predicate(#"{"is": "opponent.type", "value": "demon"}"#), .opponentType(.demon))
        XCTAssertEqual(try predicate(#"{"is": "loadout.weapon", "technique": ["CT_1", "CT_4"], "consecrated": true}"#),
                       .loadoutWeapon(technique: ["CT_1", "CT_4"], item: nil, consecrated: true))
        XCTAssertEqual(try predicate(#"{"is": "hero.hasRule", "id": "SA_67"}"#), .heroHasRule(id: "SA_67", minTier: 1))
        XCTAssertEqual(try predicate(#"{"is": "hero.state", "id": "liegend", "minLevel": 2}"#), .heroState(id: "liegend", minLevel: 2))
        XCTAssertEqual(try predicate(#"{"is": "situation.defencesThisRound", "min": 1}"#), .situationDefencesThisRound(min: 1))
        XCTAssertEqual(try predicate(#"{"is": "gm.fact", "id": "opposingDeity", "span": "attack"}"#), .gmFact(id: "opposingDeity", span: .attack))
        XCTAssertEqual(try predicate(#"{"not": {"is": "situation.beengt"}}"#), .not(.situationBeengt))
        XCTAssertEqual(try predicate(#"{"is": "situation.woundEffect"}"#), .situationWoundEffect)
    }

    func testEffectsTargetsTiersAndChoices() throws {
        let decoded = try clauses("""
        [{"kind": "offer", "domains": ["meleeAttack", "damage"], "tiers": "owned",
          "effects": [{"effect": "add", "target": "at", "value": -2, "per": "tier"},
                      {"effect": "multiply", "target": "tp", "factor": 2},
                      {"effect": "opponentAdd", "target": "vw", "value": -2},
                      {"effect": "add", "target": "talent", "talentId": "TAL_8", "value": -2}]},
         {"kind": "offer", "domains": ["meleeParry"], "tiers": 3,
          "effects": [{"effect": "choice", "options": [{"effect": "add", "target": "at", "value": 1},
                                                       {"effect": "add", "target": "vw", "value": 1}]}]}]
        """)
        XCTAssertEqual(decoded[0].tiers, .owned)
        XCTAssertEqual(decoded[0].effects, [
            .add(target: .at, value: -2, per: .tier),
            .multiply(target: .tp, factor: 2),
            .opponentAdd(target: .vw, value: -2),
            .add(target: .talent("TAL_8"), value: -2, per: nil),
        ])
        XCTAssertEqual(decoded[1].tiers, .fixed(3))
        XCTAssertEqual(decoded[1].effects, [.choice([.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)])])
    }

    func testAnUnknownNameIsADecodingError() {
        for bad in [
            #"{"is": "situation.raining"}"#,
            #"{"is": "loadout.reach", "value": "Weit"}"#,
            #"{"is": "situation.targetZone", "value": ["nase"]}"#,
            #"{"is": "gm.fact", "id": "x", "span": "century"}"#,
            #"{"is": "opponent.type", "value": "dragon"}"#,
        ] {
            XCTAssertThrowsError(try predicate(bad), bad) { XCTAssertTrue($0 is DecodingError, "\($0)") }
        }
        XCTAssertThrowsError(try clauses(#"[{"kind": "passive", "domains": ["meleeAttack"], "effects": [{"effect": "sing"}]}]"#))
        XCTAssertThrowsError(try clauses(#"[{"kind": "passive", "domains": ["meleeAttack"], "effects": [{"effect": "add", "target": "luck", "value": 1}]}]"#))
    }

    func testOwnershipIsByPrefix() {
        func rule(_ id: String) -> CatalogRule { CatalogRule(id: id, name: id, reviewed: false, appliesWith: nil, clauses: []) }
        XCTAssertTrue(rule("SA_661").needsOwnership)
        XCTAssertTrue(rule("DISADV_57").needsOwnership)
        XCTAssertFalse(rule("GRW_reichweite").needsOwnership)
        XCTAssertFalse(rule("COND_6").needsOwnership)
        XCTAssertFalse(rule("STATE_10").needsOwnership)
    }

    // MARK: - Against the bundled database

    func testEveryImplementedEntryDecodes() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let expected = RulesDatabase.shared.catalogStatusCounts()[.implemented] ?? 0
        XCTAssertEqual(RulesDatabase.shared.implementedRules().count, expected)
        XCTAssertEqual(RuleCatalog.bundled.implemented.count, expected)
        XCTAssertEqual(RuleCatalog.bundled.statuses.count, RulesDatabase.shared.allCatalogEntries().count)
    }
}
```

Add to `RuleVocabularyTests.swift` (needs `import CryptoKit` at the top):

```swift
    /// `make rules-db` validated the catalog against the exported vocabulary and
    /// wrote its hash; if the enums moved since, the bundled clauses were checked
    /// against a contract the app no longer has.
    func testTheDatabaseWasBuiltAgainstThisVocabulary() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let expected = SHA256.hash(data: Data(RuleVocabulary.exportJSON().utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(RulesDatabase.shared.catalogVocabularyHash(), expected,
                       "rules.db was built against another rule-vocabulary.json; run make test-ui (to re-export) and make rules-db")
    }
```

In `Hesindion/Engine/RuleVocabulary.swift`, extend the `Signature` doc comment: "`list:effect` (used by `choice`) refers to the `effects` table itself, the one `list:` token with no entry under `enums`."

In `RulesCatalogTests.swift`, `testTheCountsAddUpToTheRules` must allow the `GRW_*` entries that are about to arrive:

```swift
    func testTheCountsAddUpToTheRules() throws {
        try requireDatabase()
        let expected = RulesDatabase.shared.ruleCount()
        XCTAssertGreaterThan(expected, 0)
        let core = RulesDatabase.shared.catalogEntries(idPrefix: "GRW_").count
        let counts = RulesDatabase.shared.catalogStatusCounts()
        let total = counts.values.reduce(0, +)
        XCTAssertEqual(total, expected + core, "every rule and every core rule, counted once")
    }
```

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui`
Expected: `cannot find type 'RulePredicate' in scope`.

- [ ] **Step 3: Create `RuleCatalog.swift`**

```swift
import Foundation

/// Where a line lands. `talent(id)` matches exactly one talent check.
enum RuleTarget: Equatable, Hashable {
    case at, pa, aw, vw, fk, tp
    case talent(String)

    /// Whether a line with this target belongs to the domain being evaluated.
    /// An effect on another target is simply not this domain's business: a
    /// Wuchtschlag clause names `at` and `tp`, and each screen takes its own.
    func applies(in domain: RuleDomain, talentId: String?) -> Bool {
        switch self {
        case .at:              domain == .meleeAttack
        case .pa:              domain == .meleeParry
        case .aw:              domain == .meleeDodge
        case .vw:              domain == .meleeParry || domain == .meleeDodge
        case .fk:              domain == .rangedAttack
        case .tp:              domain == .damage
        case .talent(let id):  domain == .talentCheck && talentId == id
        }
    }
}

/// A condition on the hero, the loadout, the round, the opponent, or the GM.
indirect enum RulePredicate: Equatable {
    case all([RulePredicate])
    case any([RulePredicate])
    case not(RulePredicate)
    case heroHasRule(id: String, minTier: Int)
    case heroState(id: String, minLevel: Int)
    case heroFokusRule(String)
    case loadoutWeapon(technique: [String]?, item: String?, consecrated: Bool?)
    case loadoutShield(item: String?)
    case loadoutReach(WeaponReach)
    case situationMounted
    case situationBeengt
    case situationDefencesThisRound(min: Int)
    case situationTargetZone([HitZone])
    case situationWoundEffect
    case opponentReach(WeaponReach)
    case opponentOnFoot
    case opponentState(String)
    case opponentType(RuleVocabulary.OpponentType)
    case gmFact(id: String, span: FactSpan)
}

enum RuleEffect: Equatable {
    case add(target: RuleTarget, value: Int, per: RuleVocabulary.Per?)
    case multiply(target: RuleTarget, factor: Double)
    case opponentAdd(target: RuleTarget, value: Int)
    case modifyRule(id: String, target: RuleTarget, add: Int?, set: Int?, multiply: Double?)
    case choice([RuleEffect])
}

/// How many tiers an offer has: the hero's own tier of the ability, or a number.
enum OfferTiers: Equatable {
    case owned
    case fixed(Int)
}

struct RuleClause: Equatable, Decodable {
    let kind: RuleVocabulary.ClauseKind
    let domains: [RuleDomain]
    let when: RulePredicate?
    let effects: [RuleEffect]
    let tiers: OfferTiers?
}

/// One `implemented` catalog entry, decoded.
struct CatalogRule: Equatable {
    let id: String
    let name: String
    /// `reviewed` in the catalog is non-null: a person checked the clauses
    /// against the text. Unreviewed rules run and are marked "ungeprüft".
    let reviewed: Bool
    let appliesWith: RulePredicate?
    let clauses: [RuleClause]

    /// Sonderfertigkeiten, Vorteile and Nachteile apply only when the hero
    /// carries the id (design decision 6). Core rules, Zustände and Status
    /// apply to everyone; their `when` gates them.
    var needsOwnership: Bool {
        !(id.hasPrefix("GRW_") || id.hasPrefix("COND_") || id.hasPrefix("STATE_"))
    }
}

/// The catalog as the evaluator sees it: the implemented rules, and the
/// status of every entry for the not-applied list.
struct RuleCatalog {
    let rules: [String: CatalogRule]
    let statuses: [String: CatalogEntry]

    init(rules: [CatalogRule], statuses: [CatalogEntry] = []) {
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
        self.statuses = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
    }

    /// Sorted by id, so evaluation order is fixed.
    var implemented: [CatalogRule] { rules.values.sorted { $0.id < $1.id } }

    static let bundled = RuleCatalog(
        rules: RulesDatabase.shared.implementedRules(),
        statuses: RulesDatabase.shared.allCatalogEntries()
    )
}

// MARK: - Decoding

/// Dynamic keys: the JSON names the predicate or effect in `is` / `effect`
/// and puts its arguments beside it.
struct RuleKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension KeyedDecodingContainer where K == RuleKey {
    func string(_ key: String) throws -> String { try decode(String.self, forKey: RuleKey(key)) }
    func stringIfPresent(_ key: String) throws -> String? { try decodeIfPresent(String.self, forKey: RuleKey(key)) }
    func intIfPresent(_ key: String) throws -> Int? { try decodeIfPresent(Int.self, forKey: RuleKey(key)) }
    func doubleIfPresent(_ key: String) throws -> Double? { try decodeIfPresent(Double.self, forKey: RuleKey(key)) }
    /// One string or a list of them.
    func strings(_ key: String) throws -> [String]? {
        if let one = try? decodeIfPresent(String.self, forKey: RuleKey(key)) { return [one] }
        return try decodeIfPresent([String].self, forKey: RuleKey(key))
    }
    func named<T: RawRepresentable>(_ type: T.Type, _ key: String, _ what: String) throws -> T where T.RawValue == String {
        let raw = try string(key)
        guard let value = T(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(forKey: RuleKey(key), in: self, debugDescription: "unknown \(what) \(raw)")
        }
        return value
    }
}

extension RulePredicate: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RuleKey.self)
        if c.contains(RuleKey("all")) { self = .all(try c.decode([RulePredicate].self, forKey: RuleKey("all"))); return }
        if c.contains(RuleKey("any")) { self = .any(try c.decode([RulePredicate].self, forKey: RuleKey("any"))); return }
        if c.contains(RuleKey("not")) { self = .not(try c.decode(RulePredicate.self, forKey: RuleKey("not"))); return }
        switch try c.named(RuleVocabulary.Predicate.self, "is", "predicate") {
        case .heroHasRule:
            self = .heroHasRule(id: try c.string("id"), minTier: try c.intIfPresent("minTier") ?? 1)
        case .heroState:
            self = .heroState(id: try c.string("id"), minLevel: try c.intIfPresent("minLevel") ?? 1)
        case .heroFokusRule:
            self = .heroFokusRule(try c.string("value"))
        case .loadoutWeapon:
            self = .loadoutWeapon(technique: try c.strings("technique"), item: try c.stringIfPresent("item"),
                                  consecrated: try c.decodeIfPresent(Bool.self, forKey: RuleKey("consecrated")))
        case .loadoutShield:
            self = .loadoutShield(item: try c.stringIfPresent("item"))
        case .loadoutReach:
            self = .loadoutReach(try c.named(WeaponReach.self, "value", "reach"))
        case .situationMounted:
            self = .situationMounted
        case .situationBeengt:
            self = .situationBeengt
        case .situationDefencesThisRound:
            self = .situationDefencesThisRound(min: try c.decode(Int.self, forKey: RuleKey("min")))
        case .situationTargetZone:
            let raws = try c.decode([String].self, forKey: RuleKey("value"))
            self = .situationTargetZone(try raws.map { raw in
                guard let zone = HitZone(rawValue: raw) else {
                    throw DecodingError.dataCorruptedError(forKey: RuleKey("value"), in: c, debugDescription: "unknown zone \(raw)")
                }
                return zone
            })
        case .situationWoundEffect:
            self = .situationWoundEffect
        case .opponentReach:
            self = .opponentReach(try c.named(WeaponReach.self, "value", "reach"))
        case .opponentOnFoot:
            self = .opponentOnFoot
        case .opponentState:
            self = .opponentState(try c.string("value"))
        case .opponentType:
            self = .opponentType(try c.named(RuleVocabulary.OpponentType.self, "value", "opponent type"))
        case .gmFact:
            self = .gmFact(id: try c.string("id"), span: try c.named(FactSpan.self, "span", "span"))
        }
    }
}

extension RuleTarget {
    static func decode(from c: KeyedDecodingContainer<RuleKey>) throws -> RuleTarget {
        switch try c.named(RuleVocabulary.Target.self, "target", "target") {
        case .at: .at
        case .pa: .pa
        case .aw: .aw
        case .vw: .vw
        case .fk: .fk
        case .tp: .tp
        case .talent: .talent(try c.string("talentId"))
        }
    }
}

extension RuleEffect: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RuleKey.self)
        switch try c.named(RuleVocabulary.Effect.self, "effect", "effect") {
        case .add:
            self = .add(target: try RuleTarget.decode(from: c), value: try c.decode(Int.self, forKey: RuleKey("value")),
                        per: try c.decodeIfPresent(RuleVocabulary.Per.self, forKey: RuleKey("per")))
        case .multiply:
            self = .multiply(target: try RuleTarget.decode(from: c), factor: try c.decode(Double.self, forKey: RuleKey("factor")))
        case .opponentAdd:
            self = .opponentAdd(target: try RuleTarget.decode(from: c), value: try c.decode(Int.self, forKey: RuleKey("value")))
        case .modifyRule:
            self = .modifyRule(id: try c.string("id"), target: try RuleTarget.decode(from: c),
                               add: try c.intIfPresent("add"), set: try c.intIfPresent("set"),
                               multiply: try c.doubleIfPresent("multiply"))
        case .choice:
            self = .choice(try c.decode([RuleEffect].self, forKey: RuleKey("options")))
        }
    }
}

extension OfferTiers: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Int.self) { self = .fixed(n); return }
        let raw = try c.decode(String.self)
        guard raw == "owned" else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "tiers is \(raw), expected 'owned' or a number")
        }
        self = .owned
    }
}
```

- [ ] **Step 4: `RulesDatabase` reads the new columns**

In `RulesDatabase.swift`, `CatalogEntry` gains a name:

```swift
struct CatalogEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let status: CatalogStatus
    let note: String?
    let pointer: CatalogPointer?
    let reviewedBy: String?
    let reviewedOn: String?
}
```

Change `catalogColumns` and `catalogEntry(from:)`:

```swift
    private static let catalogColumns =
        "rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on, name"

    private func catalogEntry(from stmt: OpaquePointer?) -> CatalogEntry? {
        guard let status = CatalogStatus(rawValue: col_text(stmt, 1)) else { return nil }
        let file = col_text_opt(stmt, 3)
        let symbol = col_text_opt(stmt, 4)
        let pointer: CatalogPointer? = if let file, let symbol { CatalogPointer(file: file, symbol: symbol) } else { nil }
        return CatalogEntry(
            id: col_text(stmt, 0),
            name: col_text(stmt, 7),
            status: status,
            note: col_text_opt(stmt, 2),
            pointer: pointer,
            reviewedBy: col_text_opt(stmt, 5),
            reviewedOn: col_text_opt(stmt, 6)
        )
    }
```

Add after `catalogEntries(status:)`:

```swift
    /// The entries whose id starts with `prefix` — `GRW_` for the core rules
    /// that have no `rules` row.
    func catalogEntries(idPrefix prefix: String) -> [CatalogEntry] {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog WHERE rule_id LIKE ? ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, prefix + "%", -1, SQLITE_TRANSIENT)
        var results: [CatalogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = catalogEntry(from: stmt) { results.append(entry) }
        }
        return results
    }

    func allCatalogEntries() -> [CatalogEntry] {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var results: [CatalogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = catalogEntry(from: stmt) { results.append(entry) }
        }
        return results
    }

    /// The SHA-256 of the vocabulary JSON the bundled database was validated
    /// against, so a test can tell a database that lags behind `RuleVocabulary`.
    func catalogVocabularyHash() -> String? {
        let sql = "SELECT value FROM catalog_meta WHERE key = 'vocabulary_sha256'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }

    /// Every `implemented` entry with its clauses decoded. The build validated
    /// the JSON, so a decode failure here means the Swift vocabulary and the
    /// exported one have drifted; the entry is skipped and the count test
    /// (`RuleCatalogDecodingTests.testEveryImplementedEntryDecodes`) catches it.
    func implementedRules() -> [CatalogRule] {
        let sql = "SELECT rule_id, name, reviewed_by, applies_with, clauses FROM catalog WHERE status = 'implemented' ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let decoder = JSONDecoder()
        var rules: [CatalogRule] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = col_text(stmt, 0)
            do {
                let applies = try col_text_opt(stmt, 3).map { try decoder.decode(RulePredicate.self, from: Data($0.utf8)) }
                let clauses = try decoder.decode([RuleClause].self, from: Data(col_text(stmt, 4).utf8))
                rules.append(CatalogRule(id: id, name: col_text(stmt, 1), reviewed: col_text_opt(stmt, 2) != nil,
                                         appliesWith: applies, clauses: clauses))
            } catch {
                assertionFailure("\(id): clauses do not decode: \(error)")
            }
        }
        return rules
    }
```

- [ ] **Step 5: Run**

Run: `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Engine/RuleCatalog.swift Hesindion/Services/RulesDatabase.swift HesindionTests/RuleCatalogDecodingTests.swift HesindionTests/RulesCatalogTests.swift
git commit -m "feat(rules): the app decodes the catalog's clauses into typed rules"
```

---

### Task 5: `RuleEvaluator`

**Goal:** `RuleEvaluator.evaluate(catalog:situation:)` interprets the clauses and returns an `Evaluation` with lines, multipliers, opponent lines, offers, questions and the not-applied list, in the design's fixed order of application.

**Files:**
- Create: `Hesindion/Engine/RuleEvaluator.swift`
- Modify: `Hesindion/Engine/Situation.swift` (the loadout lookups and the offer bridges)
- Modify: `Hesindion/Engine/CombatSituation.swift` (`chosenOptions`)
- Modify: `Hesindion/Models/Hero.swift:439-452` (`ownedRuleTier`)
- Test: `HesindionTests/RuleEvaluatorTests.swift`

**Acceptance Criteria:**
- [ ] A rule that needs ownership and is not among the hero's traits is absent from every part of the `Evaluation`.
- [ ] Order of application: base adds, then `modifyRule` (per line: `set`, then `multiply`, then `add`), then zero lines are dropped as `netZero`. Multipliers and opponent lines are collected beside. The −5 cap is not applied here. Found in Task 7: a modification acts on the rule's *per-unit* value and the `per` count (`tier`, `defencesThisRound`) multiplies afterwards — `RuleLine.times` remembers the count — so Vinsalt-Stil's `set: -2` sets the step, not the finished line (−2, −4, −6).
- [ ] A predicate nobody can answer (`opponent.onFoot` unset, `gm.fact` missing) produces one `RuleQuestion` and a `questionUnanswered` entry; the rule fires once the answer is `true` and is `conditionFalse` once it is `false`.
- [ ] An offer not taken is listed in `offers` and as `offerNotTaken`; a `choice` offer taken applies only the chosen option; a tiered offer applies `per: tier` with the announced tier, capped at the hero's own.
- [ ] `hero.state` is false under `round.schipIgnoreZustand`; `COND_*` lines are `isZustand`.
- [ ] An owned `byHand`, `noRollEffect` or `todo` entry is listed as not applied with that reason.
- [ ] Decided after review: the Schicksalspunkt suppresses every `hero.state` predicate except the gear-derived `belastung` (`RuleEvaluator.statesTheSchipCannotIgnore`, matching the COND_1 note); a `gm.fact` with span `hero` or `round` is refused by both `catalog.py` and the Swift decoder until those spans have a store; the evaluator computes the hero's owned tiers and the two offer bridges once per evaluation, not per rule; `netZero` and questions are deduplicated; the three tie-breaks (ascending id order, last `set` wins, `multiply` truncates toward zero) are in the evaluator's header comment.

**Verify:** `make test-ui` → `RuleEvaluatorTests` passes (fifteen tests, plus three added after review).

**Steps:**

- [ ] **Step 1: Write the failing tests**

`HesindionTests/RuleEvaluatorTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// The interpreter, one vocabulary item and one rule of application at a
/// time, against catalogs built by hand so no test depends on rules.db.
@MainActor
final class RuleEvaluatorTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Builders

    private func rule(_ id: String, name: String? = nil, reviewed: Bool = false,
                      appliesWith: RulePredicate? = nil, _ clauses: [RuleClause]) -> CatalogRule {
        CatalogRule(id: id, name: name ?? id, reviewed: reviewed, appliesWith: appliesWith, clauses: clauses)
    }

    private func passive(_ domains: [RuleDomain], when: RulePredicate? = nil, _ effects: [RuleEffect]) -> RuleClause {
        RuleClause(kind: .passive, domains: domains, when: when, effects: effects, tiers: nil)
    }

    private func offer(_ domains: [RuleDomain], tiers: OfferTiers? = .owned, when: RulePredicate? = nil, _ effects: [RuleEffect]) -> RuleClause {
        RuleClause(kind: .offer, domains: domains, when: when, effects: effects, tiers: tiers)
    }

    private func own(_ id: String, tier: Int? = nil) {
        hero.combatSpecialAbilities.append(HeroTrait(ruleId: id, name: id, tier: tier, sid: nil))
    }

    private func evaluate(_ rules: [CatalogRule], statuses: [CatalogEntry] = [], _ situation: Situation) -> Evaluation {
        RuleEvaluator.evaluate(catalog: RuleCatalog(rules: rules, statuses: statuses), situation: situation)
    }

    private func line(_ id: String, in e: Evaluation) -> Int? { e.lines.first { $0.ruleId == id }?.value }
    private func reason(_ id: String, in e: Evaluation) -> NotApplied.Reason? { e.notApplied.first { $0.ruleId == id }?.reason }

    private let plusTwoAT = [RuleEffect.add(target: .at, value: 2, per: nil)]

    // MARK: - Ownership and domains

    func testARuleTheHeroDoesNotOwnIsNotEvenListed() {
        let e = evaluate([rule("SA_1", [passive([.meleeAttack], plusTwoAT)])], Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(e, Evaluation())
    }

    func testACoreRuleAppliesToEveryoneAndAnOwnedRuleToItsOwner() {
        own("SA_1")
        let rules = [rule("SA_1", [passive([.meleeAttack], plusTwoAT)]),
                     rule("GRW_x", [passive([.meleeAttack], plusTwoAT)])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(line("SA_1", in: e), 2)
        XCTAssertEqual(line("GRW_x", in: e), 2)
        XCTAssertEqual(e.applied, ["SA_1", "GRW_x"])
    }

    func testAClauseInAnotherDomainIsWrongDomainAndAnUnmetConditionIsConditionFalse() {
        own("SA_1"); own("SA_2")
        let rules = [rule("SA_1", [passive([.meleeParry], plusTwoAT)]),
                     rule("SA_2", [passive([.meleeAttack], when: .situationMounted, plusTwoAT)])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(reason("SA_1", in: e), .wrongDomain)
        XCTAssertEqual(reason("SA_2", in: e), .conditionFalse)
        XCTAssertTrue(e.lines.isEmpty)
    }

    /// An effect on a target the domain does not roll is nobody's line: the
    /// Wuchtschlag clause names AT and TP, the attack takes AT, the damage takes TP.
    func testATargetOutsideTheDomainIsSkipped() {
        own("SA_1")
        let rules = [rule("SA_1", [passive([.meleeAttack, .damage], [.add(target: .at, value: -2, per: nil), .add(target: .tp, value: 2, per: nil)])])]
        let attack = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(attack.lines.map(\.value), [-2])
        let damage = evaluate(rules, Situation(hero: hero, domain: .damage))
        XCTAssertEqual(damage.lines.map(\.value), [2])
        var talent = Situation(hero: hero, domain: .talentCheck)
        talent.talentId = "TAL_8"
        let onTalent = evaluate([rule("GRW_t", [passive([.talentCheck], [.add(target: .talent("TAL_8"), value: -2, per: nil)])])], talent)
        XCTAssertEqual(line("GRW_t", in: onTalent), -2)
        talent.talentId = "TAL_10"
        XCTAssertTrue(evaluate([rule("GRW_t", [passive([.talentCheck], [.add(target: .talent("TAL_8"), value: -2, per: nil)])])], talent).lines.isEmpty)
    }

    // MARK: - Predicates

    func testPerTierUsesTheOwnedTierAndAppliesWithGatesEveryClause() {
        own("SA_1", tier: 3)
        let rules = [rule("SA_1", appliesWith: .situationMounted,
                          [passive([.meleeAttack], [.add(target: .at, value: -2, per: .tier)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertEqual(reason("SA_1", in: evaluate(rules, s)), .conditionFalse)
        s.round.mounted = true
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -6)
    }

    func testAnUnansweredOpponentFactIsAQuestion() {
        let rules = [rule("GRW_x", [passive([.meleeAttack], when: .opponentOnFoot, plusTwoAT)])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        let asked = evaluate(rules, s)
        XCTAssertEqual(asked.questions, [RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "GRW_x")])
        XCTAssertEqual(reason("GRW_x", in: asked), .questionUnanswered)
        s.opponents.current.isOnFoot = false
        XCTAssertEqual(reason("GRW_x", in: evaluate(rules, s)), .conditionFalse)
        s.opponents.current.isOnFoot = true
        XCTAssertEqual(line("GRW_x", in: evaluate(rules, s)), 2)
    }

    func testAGMFactIsReadOffTheOpponentByIdAndSpan() {
        let key = FactKey(id: "opposingDeity", span: .attack)
        let rules = [rule("GRW_x", [passive([.damage], when: .gmFact(id: "opposingDeity", span: .attack), [.multiply(target: .tp, factor: 2)])])]
        var s = Situation(hero: hero, domain: .damage)
        let asked = evaluate(rules, s)
        XCTAssertEqual(asked.questions.map(\.key), [key])
        XCTAssertTrue(asked.multipliers.isEmpty)
        s.opponents.current.facts[key] = true
        let answered = evaluate(rules, s)
        XCTAssertEqual(answered.multipliers.map(\.factor), [2])
        XCTAssertEqual(answered.applied, ["GRW_x"])
    }

    func testAnyNotAndTheLoadoutPredicates() {
        hero.meleeWeapons = [MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_5", damage: "1W6+4", at: 12, pa: 8, reach: "Mittel", weight: 2)]
        hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
        hero.selectedWeaponName = "Rabenschnabel"
        let either: RulePredicate = .any([.loadoutWeapon(technique: ["CT_5"], item: "Rabenschnabel", consecrated: nil),
                                          .loadoutShield(item: "Großschild")])
        let rules = [rule("GRW_x", [passive([.meleeAttack], when: either, plusTwoAT)]),
                     rule("GRW_y", [passive([.meleeAttack], when: .not(.loadoutReach(.mittel)), plusTwoAT)]),
                     rule("GRW_z", [passive([.meleeAttack], when: .loadoutWeapon(technique: nil, item: nil, consecrated: true), plusTwoAT)])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        var e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), 2, "the weapon matches")
        XCTAssertEqual(reason("GRW_y", in: e), .conditionFalse, "the Rabenschnabel is Mittel")
        XCTAssertEqual(reason("GRW_z", in: e), .conditionFalse, "nothing is consecrated")
        hero.selectedShieldName = "Großschild"
        hero.selectedWeaponName = nil
        hero.setConsecrated("Rabenschnabel", true)
        s.loadoutName = "Rabenschnabel"
        e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), 2, "the shield matches too")
        XCTAssertEqual(line("GRW_z", in: e), 2, "the named loadout piece is consecrated")
    }

    func testHeroStateIsOffUnderTheZustandIgnorierenSchipAndCondLinesAreZustaende() {
        hero.setStateLevel("furcht", level: 2)
        let rules = [rule("COND_4", [passive([.talentCheck], when: .heroState(id: "furcht", minLevel: 1), [.add(target: .talent("TAL_8"), value: -2, per: nil)])])]
        var s = Situation(hero: hero, domain: .talentCheck)
        s.talentId = "TAL_8"
        let e = evaluate(rules, s)
        XCTAssertEqual(e.lines.first?.isZustand, true)
        s.round.schipIgnoreZustand = true
        XCTAssertEqual(reason("COND_4", in: evaluate(rules, s)), .conditionFalse)
    }

    // MARK: - Order of application

    func testModifyRuleSetsThenMultipliesThenAddsAndMissesWhenTheRuleIsNotInEffect() {
        own("SA_1"); own("SA_2"); own("SA_3")
        let base = rule("GRW_x", [passive([.meleeAttack], when: .situationTargetZone([.kopf]), [.add(target: .at, value: -10, per: nil)])])
        let rules = [base,
                     rule("SA_1", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: 2, set: nil, multiply: nil)])]),
                     rule("SA_2", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: nil, set: nil, multiply: 0.5)])]),
                     rule("SA_3", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: nil, set: -6, multiply: nil)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.targetHitZone = .kopf
        let e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), -1, "set −6, halved −3, +2")
        XCTAssertEqual(e.applied, ["GRW_x", "SA_1", "SA_2", "SA_3"])
        s.targetHitZone = nil
        let missed = evaluate(rules, s)
        XCTAssertNil(line("GRW_x", in: missed))
        XCTAssertEqual(reason("SA_1", in: missed), .modifiedRuleNotInEffect)
        XCTAssertEqual(reason("GRW_x", in: missed), .conditionFalse)
    }

    func testALineThatComesToZeroIsDroppedAndSaidSo() {
        own("SA_1")
        let rules = [rule("GRW_x", [passive([.meleeAttack], [.add(target: .at, value: -2, per: nil)])]),
                     rule("SA_1", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: 2, set: nil, multiply: nil)])])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertEqual(reason("GRW_x", in: e), .netZero)
        XCTAssertEqual(e.applied, ["SA_1"])
    }

    // MARK: - Offers

    func testAChoiceOfferIsListedUntilTakenAndThenAppliesOnlyTheChosenOption() {
        own("SA_1")
        let options: [RuleEffect] = [.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)]
        let rules = [rule("SA_1", [offer([.meleeAttack, .meleeParry, .meleeDodge], tiers: nil, [.choice(options)])])]
        var s = Situation(hero: hero, domain: .meleeParry)
        let open = evaluate(rules, s)
        XCTAssertEqual(open.offers, [RuleOffer(ruleId: "SA_1", name: "SA_1", shape: .choice(options), reviewed: false)])
        XCTAssertEqual(reason("SA_1", in: open), .offerNotTaken)
        s.choices["SA_1"] = 1
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), 1)
        s.choices["SA_1"] = 0
        XCTAssertTrue(evaluate(rules, s).lines.isEmpty, "AT was chosen; this is a parry")
    }

    func testATieredOfferUsesTheAnnouncedTierCappedAtTheOwnedOne() {
        own("SA_1", tier: 2)
        let rules = [rule("SA_1", [offer([.meleeAttack], [.add(target: .at, value: -2, per: .tier)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        let open = evaluate(rules, s)
        XCTAssertEqual(open.offers.first?.shape, .tiers(2))
        s.announced["SA_1"] = 1
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -2)
        s.announced["SA_1"] = 3
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -4, "the hero only has II")
    }

    // MARK: - The rest of the sheet

    func testOwnedRulesTheCatalogDoesNotImplementAreListedWithTheirStatus() {
        own("SA_9"); own("SA_8"); hero.advantages.append(HeroTrait(ruleId: "ADV_1", name: "x", tier: nil, sid: nil))
        let statuses = [CatalogEntry(id: "SA_9", name: "Neun", status: .byHand, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil),
                        CatalogEntry(id: "SA_8", name: "Acht", status: .todo, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil),
                        CatalogEntry(id: "ADV_1", name: "Eins", status: .noRollEffect, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil)]
        let e = evaluate([], statuses: statuses, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(Set(e.notApplied), [NotApplied(ruleId: "SA_9", name: "Neun", reason: .byHand),
                                           NotApplied(ruleId: "SA_8", name: "Acht", reason: .todo),
                                           NotApplied(ruleId: "ADV_1", name: "Eins", reason: .noRollEffect)])
    }

    func testOpponentLinesAndTheReviewedFlagTravel() {
        let rules = [rule("STATE_x", name: "Liegend", reviewed: true,
                          [passive([.meleeAttack], when: .opponentState("liegend"), [.opponentAdd(target: .vw, value: -2)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.isProne = true
        let e = evaluate(rules, s)
        XCTAssertEqual(e.opponentLines, [RuleLine(ruleId: "STATE_x", name: "Liegend", target: .vw, value: -2, reviewed: true, isZustand: false)])
        XCTAssertTrue(e.lines.isEmpty)
    }
}
```

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui`
Expected: `cannot find 'RuleEvaluator' in scope`.

- [ ] **Step 3: `Hero.ownedRuleTier`**

In `Hesindion/Models/Hero.swift`, after `specialAbilityTier(_:)`:

```swift
    /// The tier of any trait the hero carries — Sonderfertigkeit, Vorteil or
    /// Nachteil — or `nil` when the id is not on the sheet. A trait without a
    /// tier in the export counts as I. This is design decision 6: a rule
    /// applies exactly when its id is among the hero's traits.
    func ownedRuleTier(_ ruleId: String) -> Int? {
        let trait = combatSpecialAbilities.first { $0.ruleId == ruleId }
            ?? generalSpecialAbilities.first { $0.ruleId == ruleId }
            ?? advantages.first { $0.ruleId == ruleId }
            ?? disadvantages.first { $0.ruleId == ruleId }
        guard let trait else { return nil }
        return trait.tier ?? 1
    }

    /// Every trait id on the sheet, for the not-applied list.
    var ownedRuleIds: [String] {
        (combatSpecialAbilities + generalSpecialAbilities + advantages + disadvantages).map(\.ruleId)
    }
```

- [ ] **Step 4: `Situation` learns the loadout and the offers taken**

Add to `Hesindion/Engine/Situation.swift`, inside `Situation` after the magic fields:

```swift
    // MARK: Offers taken

    /// `choice` offers taken, rule id → option index, and tiered offers
    /// announced, rule id → tier. Explicit entries win over the bridge from
    /// the legacy fields (`round.plaenkler…`, `maneuver`) that the views still
    /// set; step 3 writes these directly and the bridge goes.
    var choices: [String: Int] = [:]
    var announced: [String: Int] = [:]

    var effectiveChoices: [String: Int] { round.chosenOptions.merging(choices) { _, explicit in explicit } }
    var effectiveAnnounced: [String: Int] { Self.announced(for: maneuver).merging(announced) { _, explicit in explicit } }

    /// The manoeuvre enum as the catalog names it: rule id → tier.
    static func announced(for maneuver: CombatManeuver) -> [String: Int] {
        switch maneuver {
        case .normal:                  [:]
        case .finte(let tier):         [CombatAbility.finte.rawValue: tier]
        case .wuchtschlag(let tier):   [CombatAbility.wuchtschlag.rawValue: tier]
        case .vorstoss:                [CombatAbility.vorstoss.rawValue: 1]
        case .schildspalter:           [CombatAbility.schildspalter.rawValue: 1]
        case .sturmangriff:            [CombatAbility.berittenerKampf.rawValue: 1]
        }
    }

    // MARK: The loadout piece in the hand

    /// The melee weapon being swung or parried with: the named one, else the
    /// main weapon. `nil` for a shield, a fist, or a name that matches nothing.
    var loadoutWeapon: MeleeWeapon? {
        if let name = loadoutName { return hero.meleeWeapons.first { $0.name == name } }
        return hero.selectedWeapon
    }

    /// Its reach. Bare hands are kurz (GRW, waffenlose Kampftechniken).
    var loadoutReach: WeaponReach {
        if let name = loadoutName { return hero.reach(ofLoadoutNamed: name) }
        if let weapon = hero.selectedWeapon { return WeaponReach(rawValue: weapon.reach) ?? .mittel }
        return .kurz
    }
```

And in `Hesindion/Engine/CombatSituation.swift`, after `pendingMultipleDefensePenalty`:

```swift
    /// The fight-long choices as the catalog names them: rule id → option.
    /// Plänkler-Formation (SA_884) is the only one until step 3 stores choices
    /// by rule id; its option 0 is AT, option 1 the Verteidigungswert.
    var chosenOptions: [String: Int] {
        guard plaenklerActive else { return [:] }
        return [CombatAbility.plaenklerFormation.rawValue: plaenklerBonus == .at ? 0 : 1]
    }
```

- [ ] **Step 5: Create `RuleEvaluator.swift`**

```swift
import Foundation

// MARK: - What comes out

/// A modifier a catalog rule produced. Converts to the `ModifierLine` the
/// breakdown boxes already draw.
struct RuleLine: Equatable, Hashable {
    let ruleId: String
    let name: String
    let target: RuleTarget
    var value: Int
    let reviewed: Bool
    let isZustand: Bool

    var modifierLine: ModifierLine {
        ModifierLine(value: value, source: name, isZustand: isZustand, ruleId: ruleId)
    }
}

struct RuleMultiplier: Equatable {
    let ruleId: String
    let name: String
    let target: RuleTarget
    let factor: Double
    let reviewed: Bool
}

/// Something the hero may do because of a rule.
struct RuleOffer: Equatable {
    enum Shape: Equatable {
        /// A manoeuvre with tiers I…n.
        case tiers(Int)
        /// An either-or; the options are the effects to choose between.
        case choice([RuleEffect])
    }
    let ruleId: String
    let name: String
    let shape: Shape
    let reviewed: Bool
}

/// A fact a rule needs that nobody has stated. Its subject is the current
/// opponent (spans `opponent` and `attack`) or the hero (span `hero`).
struct RuleQuestion: Equatable, Hashable {
    let key: FactKey
    let askedBy: String
}

struct NotApplied: Equatable, Hashable {
    enum Reason: Equatable, Hashable {
        case conditionFalse, questionUnanswered, wrongDomain, offerNotTaken
        case modifiedRuleNotInEffect, netZero
        case byHand, noRollEffect, todo
    }
    let ruleId: String
    let name: String
    let reason: Reason
}

/// Design §3: what the rules say about this roll, in six parts.
struct Evaluation: Equatable {
    var lines: [RuleLine] = []
    var multipliers: [RuleMultiplier] = []
    var opponentLines: [RuleLine] = []
    var offers: [RuleOffer] = []
    var questions: [RuleQuestion] = []
    var notApplied: [NotApplied] = []
    /// Rule ids that changed something: a line, a multiplier, an opponent
    /// line, or a modification that landed on another rule's line.
    var applied: Set<String> = []
}

// MARK: - The evaluator

/// Interprets `implemented` catalog entries against a `Situation`.
///
/// Fixed order (design §3): base adds → rule-on-rule modifications (per
/// line: set, then multiply, then add) → zero lines dropped. Multipliers and
/// opponent lines are collected beside the lines. The −5 Zustand cap is not
/// applied here: `ModifierEngine` applies it once over the union of these
/// lines and the Swift definitions still in migration.
enum RuleEvaluator {

    static func evaluate(catalog: RuleCatalog, situation: Situation) -> Evaluation {
        var out = Evaluation()
        var modifications: [Modification] = []
        for rule in catalog.implemented {
            evaluate(rule, in: situation, into: &out, modifications: &modifications)
        }
        applyModifications(modifications, to: &out)
        dropZeroLines(&out)
        listOwnedRulesTheCatalogDoesNotImplement(catalog, situation, &out)
        out.applied.formUnion(out.lines.map(\.ruleId))
        out.applied.formUnion(out.multipliers.map(\.ruleId))
        out.applied.formUnion(out.opponentLines.map(\.ruleId))
        return out
    }

    // MARK: One rule

    private struct Modification {
        let from: String
        let fromName: String
        let targetRule: String
        let target: RuleTarget
        let add: Int?
        let set: Int?
        let multiply: Double?
    }

    private static func evaluate(_ rule: CatalogRule, in s: Situation, into out: inout Evaluation,
                                 modifications: inout [Modification]) {
        let ownedTier = s.hero.ownedRuleTier(rule.id)
        if rule.needsOwnership && ownedTier == nil { return }
        let tier = ownedTier ?? 1

        if let gate = rule.appliesWith {
            switch test(gate, s) {
            case .no:
                out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .conditionFalse)); return
            case .unknown(let key):
                out.questions.append(RuleQuestion(key: key, askedBy: rule.id))
                out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .questionUnanswered)); return
            case .yes:
                break
            }
        }

        let clauses = rule.clauses.filter { $0.domains.contains(s.domain) }
        guard !clauses.isEmpty else {
            out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .wrongDomain)); return
        }

        var reasons: [NotApplied.Reason] = []
        var landed = false
        for clause in clauses {
            if let when = clause.when {
                switch test(when, s) {
                case .no: reasons.append(.conditionFalse); continue
                case .unknown(let key):
                    out.questions.append(RuleQuestion(key: key, askedBy: rule.id))
                    reasons.append(.questionUnanswered); continue
                case .yes: break
                }
            }
            switch clause.kind {
            case .passive:
                landed = apply(clause.effects, tier: tier, rule, s, &out, &modifications) || landed
            case .offer:
                if case .choice(let options)? = clause.effects.first {
                    if let chosen = s.effectiveChoices[rule.id], options.indices.contains(chosen) {
                        landed = apply([options[chosen]], tier: tier, rule, s, &out, &modifications) || landed
                    } else {
                        out.offers.append(RuleOffer(ruleId: rule.id, name: rule.name, shape: .choice(options), reviewed: rule.reviewed))
                        reasons.append(.offerNotTaken)
                    }
                } else {
                    let maxTier: Int = switch clause.tiers {
                        case .fixed(let n)?: n
                        case .owned?, nil:   tier
                    }
                    if let announced = s.effectiveAnnounced[rule.id] {
                        landed = apply(clause.effects, tier: min(announced, maxTier), rule, s, &out, &modifications) || landed
                    } else {
                        out.offers.append(RuleOffer(ruleId: rule.id, name: rule.name, shape: .tiers(maxTier), reviewed: rule.reviewed))
                        reasons.append(.offerNotTaken)
                    }
                }
            }
        }
        if !landed {
            // No reason recorded means every clause passed its `when` and none
            // had an effect on this domain's target (an offer taken for AT,
            // evaluated on a parry): the same thing as a clause in another domain.
            out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: reasons.first ?? .wrongDomain))
        }
    }

    /// Applies the effects that belong to this domain. Returns whether any did.
    private static func apply(_ effects: [RuleEffect], tier: Int, _ rule: CatalogRule, _ s: Situation,
                              _ out: inout Evaluation, _ modifications: inout [Modification]) -> Bool {
        var landed = false
        let isZustand = rule.id.hasPrefix("COND_")
        for effect in effects {
            switch effect {
            case .add(let target, let value, let per):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                let times: Int = switch per {
                    case .tier?:              tier
                    case .defencesThisRound?: s.defencesThisRound
                    case nil:                 1
                }
                out.lines.append(RuleLine(ruleId: rule.id, name: rule.name, target: target, value: value * times,
                                          reviewed: rule.reviewed, isZustand: isZustand))
                landed = true
            case .multiply(let target, let factor):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                out.multipliers.append(RuleMultiplier(ruleId: rule.id, name: rule.name, target: target, factor: factor, reviewed: rule.reviewed))
                landed = true
            case .opponentAdd(let target, let value):
                out.opponentLines.append(RuleLine(ruleId: rule.id, name: rule.name, target: target, value: value,
                                                  reviewed: rule.reviewed, isZustand: false))
                landed = true
            case .modifyRule(let id, let target, let add, let set, let multiply):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                modifications.append(Modification(from: rule.id, fromName: rule.name, targetRule: id, target: target,
                                                  add: add, set: set, multiply: multiply))
                landed = true
            case .choice:
                continue   // only meaningful inside an offer, handled by the caller
            }
        }
        return landed
    }

    // MARK: Rule on rule

    private static func applyModifications(_ modifications: [Modification], to out: inout Evaluation) {
        var missed: [Modification] = []
        for mod in modifications {
            let hits = out.lines.indices.filter { out.lines[$0].ruleId == mod.targetRule && out.lines[$0].target == mod.target }
            guard !hits.isEmpty else { missed.append(mod); continue }
            out.applied.insert(mod.from)
        }
        // Per line: every set, then every multiply, then every add.
        for index in out.lines.indices {
            let line = out.lines[index]
            let mine = modifications.filter { $0.targetRule == line.ruleId && $0.target == line.target }
            guard !mine.isEmpty else { continue }
            var value = line.value
            if let set = mine.compactMap(\.set).last { value = set }
            for factor in mine.compactMap(\.multiply) {
                value = Int((Double(value) * factor).rounded(.towardZero))
            }
            value += mine.compactMap(\.add).reduce(0, +)
            out.lines[index].value = value
        }
        var reported: Set<String> = []
        for mod in missed where !out.applied.contains(mod.from) && reported.insert(mod.from).inserted {
            out.notApplied.append(NotApplied(ruleId: mod.from, name: mod.fromName, reason: .modifiedRuleNotInEffect))
        }
    }

    private static func dropZeroLines(_ out: inout Evaluation) {
        let zero = out.lines.filter { $0.value == 0 }
        out.lines.removeAll { $0.value == 0 }
        for line in zero where !out.lines.contains(where: { $0.ruleId == line.ruleId }) {
            out.notApplied.append(NotApplied(ruleId: line.ruleId, name: line.name, reason: .netZero))
        }
    }

    // MARK: The rest of the sheet

    private static func listOwnedRulesTheCatalogDoesNotImplement(_ catalog: RuleCatalog, _ s: Situation, _ out: inout Evaluation) {
        for id in s.hero.ownedRuleIds {
            guard let entry = catalog.statuses[id] else { continue }
            let reason: NotApplied.Reason
            switch entry.status {
            case .implemented:   continue
            case .byHand:        reason = .byHand
            case .noRollEffect:  reason = .noRollEffect
            case .todo:          reason = .todo
            }
            out.notApplied.append(NotApplied(ruleId: id, name: entry.name, reason: reason))
        }
    }

    // MARK: Predicates

    enum Answer: Equatable {
        case yes, no
        case unknown(FactKey)
    }

    static func test(_ predicate: RulePredicate, _ s: Situation) -> Answer {
        switch predicate {
        case .all(let parts):
            var pending: FactKey?
            for part in parts {
                switch test(part, s) {
                case .no: return .no
                case .unknown(let key): pending = pending ?? key
                case .yes: break
                }
            }
            return pending.map { .unknown($0) } ?? .yes
        case .any(let parts):
            var pending: FactKey?
            for part in parts {
                switch test(part, s) {
                case .yes: return .yes
                case .unknown(let key): pending = pending ?? key
                case .no: break
                }
            }
            return pending.map { .unknown($0) } ?? .no
        case .not(let part):
            switch test(part, s) {
            case .yes: return .no
            case .no: return .yes
            case .unknown(let key): return .unknown(key)
            }
        case .heroHasRule(let id, let minTier):
            return (s.hero.ownedRuleTier(id) ?? 0) >= minTier ? .yes : .no
        case .heroState(let id, let minLevel):
            // The "Zustand ignorieren" Schicksalspunkt switches every state
            // predicate off, as StateModifiers did.
            return !s.round.schipIgnoreZustand && s.hero.level(of: id) >= minLevel ? .yes : .no
        case .heroFokusRule(let raw):
            return FokusRule(rawValue: raw).map(s.hero.isFokusRuleActive) == true ? .yes : .no
        case .loadoutWeapon(let technique, let item, let consecrated):
            guard let weapon = s.loadoutWeapon else { return .no }
            if let technique, !technique.contains(weapon.combatTechniqueId) { return .no }
            if let item, weapon.name != item { return .no }
            if let consecrated, s.hero.isConsecrated(weapon.name) != consecrated { return .no }
            return .yes
        case .loadoutShield(let item):
            guard let shield = s.hero.selectedShield else { return .no }
            return item == nil || shield.name == item ? .yes : .no
        case .loadoutReach(let reach):
            return s.loadoutReach == reach ? .yes : .no
        case .situationMounted:
            return s.round.mounted ? .yes : .no
        case .situationBeengt:
            return s.round.beengteUmgebung ? .yes : .no
        case .situationDefencesThisRound(let min):
            return s.defencesThisRound >= min ? .yes : .no
        case .situationTargetZone(let zones):
            return s.targetHitZone.map(zones.contains) == true ? .yes : .no
        case .situationWoundEffect:
            return s.isWoundEffectProbe ? .yes : .no
        case .opponentReach(let reach):
            return s.opponent.reach == reach ? .yes : .no
        case .opponentOnFoot:
            switch s.opponent.isOnFoot {
            case true?: return .yes
            case false?: return .no
            case nil: return .unknown(FactKey(id: "onFoot", span: .opponent))
            }
        case .opponentState(let id):
            return s.opponent.states.contains(id) ? .yes : .no
        case .opponentType(.demon):
            return s.opponent.isDaemon ? .yes : .no
        case .gmFact(let id, let span):
            let key = FactKey(id: id, span: span)
            switch s.opponent.facts[key] {
            case true?: return .yes
            case false?: return .no
            case nil: return .unknown(key)
            }
        }
    }
}
```

- [ ] **Step 6: Run**

Run: `make test-ui` → `** TEST SUCCEEDED **`, `RuleEvaluatorTests` 14 passed.

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Engine/RuleEvaluator.swift Hesindion/Engine/Situation.swift Hesindion/Engine/CombatSituation.swift Hesindion/Models/Hero.swift HesindionTests/RuleEvaluatorTests.swift
git commit -m "feat(rules): the evaluator reads the catalog and says what applied and what did not"
```

---

### Task 6: The union — Swift definitions and the evaluator, one engine

**Goal:** `ModifierEngine.evaluate` returns the Swift definitions' lines plus the evaluator's, capped once; each definition names the rule ids it implements; a test holds the two sets disjoint.

**Files:**
- Modify: `Hesindion/Engine/ModifierEngine.swift`
- Modify: every `*Modifiers.swift` under `Hesindion/Engine/` (the `rules:` argument)
- Test: `HesindionTests/ModifierEngineUnionTests.swift`

**Acceptance Criteria:**
- [ ] `ModifierDefinition` has `rules: [String]` and every definition in `ModifierEngine.shared` names the catalog ids it stands for (table in Step 3); `[]` only where the rule has no catalog entry yet.
- [ ] `ModifierEngine.evaluate(context:)` = Swift lines + evaluator lines, then `applyingZustandCap` once over both; `evaluation(_:)` exposes the full `Evaluation`.
- [ ] No `implemented` entry id appears in any definition's `rules`.

**Verify:** `make test-ui` → `ModifierEngineUnionTests` passes; no snapshot changes.

**Steps:**

- [ ] **Step 1: Write the failing tests**

`HesindionTests/ModifierEngineUnionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// While the Swift definitions move to the catalog one at a time, the engine
/// returns both — and a rule must come from exactly one side.
@MainActor
final class ModifierEngineUnionTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    private func catalogRule(_ id: String, value: Int) -> CatalogRule {
        CatalogRule(id: id, name: id, reviewed: false, appliesWith: nil, clauses: [
            RuleClause(kind: .passive, domains: [.meleeAttack], when: nil,
                       effects: [.add(target: .at, value: value, per: nil)], tiers: nil),
        ])
    }

    /// The migration invariant. Every Swift definition names the rules it
    /// implements; once a catalog entry is `implemented`, the definition must
    /// be gone, or the line would be counted twice.
    func testNoRuleIsProducedByBothSides() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let implemented = Set(RuleCatalog.bundled.implemented.map(\.id))
        for definition in ModifierEngine.shared.definitions {
            let both = implemented.intersection(definition.rules)
            XCTAssertTrue(both.isEmpty, "\(definition.id) still implements \(both.sorted()) in Swift")
        }
    }

    func testTheUnionCarriesCatalogLinesWithTheirRuleId() {
        let swift = ModifierDefinition(id: "swift", domains: [.meleeAttack], rules: []) { _ in
            ModifierLine(value: 1, source: "Swift")
        }
        let engine = ModifierEngine(modifiers: [swift], catalog: RuleCatalog(rules: [catalogRule("GRW_x", value: 2)]))
        let lines = engine.evaluate(context: Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(lines.map(\.value), [1, 2])
        XCTAssertEqual(lines.map(\.ruleId), [nil, "GRW_x"])
    }

    func testTheCapIsAppliedOnceOverBothSides() {
        hero.setStateLevel("furcht", level: 4)   // −4 from the Swift state definition
        let engine = ModifierEngine(modifiers: StateModifiers.all,
                                    catalog: RuleCatalog(rules: [catalogRule("COND_x", value: -3)]))
        let lines = engine.evaluate(context: Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(lines.reduce(0) { $0 + $1.value }, -5, "−4 and −3 cap at −5 together")
        XCTAssertEqual(lines.filter { $0.source == L("source.zustandCap") }.count, 1)
    }

    func testTheDamageDomainHasNoSwiftDefinitions() {
        let engine = ModifierEngine(modifiers: MeleeModifiers.all, catalog: RuleCatalog(rules: []))
        XCTAssertTrue(engine.evaluate(context: Situation(hero: hero, domain: .damage)).isEmpty)
    }
}
```

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui`
Expected: `extra argument 'rules' in call`, `'ModifierEngine' has no member 'definitions'`.

- [ ] **Step 3: The definition names its rules; the engine unions**

In `ModifierEngine.swift`:

```swift
// MARK: - ModifierDefinition

struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    /// The catalog ids this definition stands for, so the migration test can
    /// refuse a rule that is implemented on both sides. Empty only for a rule
    /// with no catalog entry yet.
    var rules: [String] = []
    let evaluate: (Situation) -> ModifierLine?
}

// MARK: - ModifierEngine

/// The union of the Swift definitions still in migration and the catalog
/// (design §7 step 2). When the Swift list is empty this becomes a thin
/// wrapper around `RuleEvaluator`.
struct ModifierEngine {
    let definitions: [ModifierDefinition]
    let catalog: RuleCatalog

    init(modifiers: [ModifierDefinition], catalog: RuleCatalog = .bundled) {
        self.definitions = modifiers
        self.catalog = catalog
    }

    /// Everything the catalog says about this roll.
    func evaluation(_ situation: Situation) -> Evaluation {
        RuleEvaluator.evaluate(catalog: catalog, situation: situation)
    }

    /// The lines both sides produce, capped once.
    func evaluate(context situation: Situation) -> [ModifierLine] {
        let swift: [ModifierLine] = situation.checkDomain.map { domain in
            definitions.filter { $0.domains.contains(domain) }.compactMap { $0.evaluate(situation) }
        } ?? []
        let catalogLines = evaluation(situation).lines.map(\.modifierLine)
        return Self.applyingZustandCap(swift + catalogLines)
    }
```

Keep `applyingZustandCap`, `totalModifier` and `shared` unchanged (`shared` picks up `.bundled` by default).

Give every definition its `rules:` argument, between `domains:` and the closure:

| file | definition | `rules:` |
|---|---|---|
| SharedModifiers | encumbrance | `["COND_1"]` |
| StateModifiers | `state.\(def.id)` | `[StateModifiers.ruleIds[def.id]].compactMap { $0 }` |
| StateModifiers | entrueckungDef | `["COND_3"]` |
| MeleeModifiers | vorteilhaftePosition | `["GRW_vorteilhaftePosition"]` |
| MeleeModifiers | golgariten | `["SA_661"]` |
| MeleeModifiers | plaenklerAT | `["SA_884"]` |
| MeleeModifiers | weaponReach | `["GRW_reichweite"]` |
| MeleeModifiers | maneuverAT | `["SA_48", "SA_67", "SA_66"]` |
| MeleeModifiers | dualAttackPenalty | `["SA_42"]` |
| MeleeModifiers | offHandPenalty | `["ADV_5"]` |
| MeleeModifiers | beengteUmgebungAT | `["GRW_beengteUmgebung", "STATE_6"]` |
| DefenseModifiers | multipleDefense | `["GRW_mehrfacheVerteidigung"]` |
| DefenseModifiers | schipDefenseBoost | `[]` |
| DefenseModifiers | golgaritenPA | `["SA_661"]` |
| DefenseModifiers | plaenklerVW | `["SA_884"]` |
| DefenseModifiers | mountedDodgePenalty | `[]` |
| DefenseModifiers | dualAttackDefense | `["SA_42"]` |
| DefenseModifiers | offHandParry | `["ADV_5"]` |
| DefenseModifiers | twoHandedGripPA | `[]` |
| DefenseModifiers | beengteUmgebungPA | `["GRW_beengteUmgebung", "STATE_6"]` |
| RangedModifiers | all eight | `[]` |
| MagicModifiers | all seven | `[]` |
| HitZoneModifiers | zonenaufschlag | `["GRW_zonenaufschlag", "SA_160", "SA_161", "STATE_13"]` |

Add the state map to `StateModifiers`:

```swift
    /// `StateCatalog` id → catalog rule id, for the migration test and the
    /// not-applied list. Every state the catalog knows is here.
    static let ruleIds: [String: String] = [
        "belastung": "COND_1", "betaeubung": "COND_2", "entrueckung": "COND_3", "furcht": "COND_4",
        "paralyse": "COND_5", "schmerz": "COND_6", "verwirrung": "COND_7", "berauscht": "COND_9",
        "bewegungsunfaehig": "STATE_1", "bewusstlos": "STATE_2", "blind": "STATE_3", "brennend": "STATE_5",
        "eingeengt": "STATE_6", "fixiert": "STATE_7", "handlungsunfaehig": "STATE_8", "krank": "STATE_9",
        "liegend": "STATE_10", "stumm": "STATE_11", "taub": "STATE_12", "ueberrascht": "STATE_13",
        "unsichtbar": "STATE_14", "vergiftet": "STATE_15", "uebler_geruch": "STATE_19",
        "versteinert": "STATE_20", "blutend": "STATE_21",
    ]
```

and in `RulesCatalogTests.testEveryCatalogStateIsByHand` add, before the loop, a check that the map and the catalog agree:

```swift
        for definition in StateCatalog.all {
            XCTAssertNotNil(StateModifiers.ruleIds[definition.id], "\(definition.id) has no rule id in StateModifiers.ruleIds")
        }
```

- [ ] **Step 4: Run**

Run: `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Hesindion/Engine/ModifierEngine.swift Hesindion/Engine/SharedModifiers.swift Hesindion/Engine/StateModifiers.swift Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DefenseModifiers.swift Hesindion/Engine/RangedModifiers.swift Hesindion/Engine/MagicModifiers.swift Hesindion/Engine/HitZoneModifiers.swift HesindionTests/ModifierEngineUnionTests.swift HesindionTests/RulesCatalogTests.swift
git commit -m "feat(rules): the engine returns the union of Swift and catalog, and no rule twice"
```

## The fixtures

Every task from here on follows one pattern: delete the Swift definition, add the catalog entry (`reviewed: null` — the entry runs and shows "ungeprüft" until you have read the clauses against the text and put your name and the date on it), rebuild `rules.db` with the new snapshot, keep the definition's test but let it find lines by `ruleId`, and add fixture rows to `HesindionTests/RuleFixtureTests.swift`. The catalog's non-`todo` entries live in the block at the top of `specs/data/rules-catalog.yaml`; an entry that was a one-line `todo` further down is deleted there when its full entry goes in the block.

The per-status counts at the end of each task, for `UPDATE_SNAPSHOT=1 make rules-db`:

| after task | implemented | byHand | noRollEffect | todo | total |
|---|---|---|---|---|---|
| 7 | 2 | 45 | 0 | 2629 | 2676 |
| 8 | 4 | 47 | 0 | 2629 | 2680 |
| 9 | 8 | 44 | 0 | 2629 | 2681 |
| 10 | 10 | 43 | 0 | 2629 | 2682 |
| 11 | 11 | 42 | 0 | 2629 | 2682 |
| 12 | 12 | 41 | 0 | 2629 | 2682 |
| 13 | 13 | 40 | 0 | 2629 | 2682 |
| 14 | 14 | 40 | 0 | 2629 | 2683 |
| 15 | 15 | 40 | 0 | 2628 | 2683 |

The total is 2675 rules plus the `GRW_*` entries added so far. If a build prints other numbers, an entry was lost or duplicated — stop and look.

Two things every fixture task does beside its own steps, added after the Task 6 review: a task that lands a `GRW_*` entry removes that id from `ModifierEngineUnionTests.stillToBeAuthored` (the allow-list of `rules:` ids no catalog entry has yet; the test refuses an id that exists in both); and a task that deletes a Swift definition checks that no `byHand` pointer into a `*Modifiers.swift` file still names it (`testEveryByHandPointerIntoAModifierFileIsClaimedByADefinition`).

---

### Task 7: Mehrfache Verteidigung and Vinsalt-Stil

**Goal:** The −3-per-defence rule is a `GRW_mehrfacheVerteidigung` entry, Vinsalt-Stil (SA_923) sets its step to −2 through `modifyRule … set`, and the first two fixture rows exist.

**Files:**
- Modify: `specs/data/rules-catalog.yaml` (add two entries to the top block; delete the `SA_923` todo line), `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/DefenseModifiers.swift` (delete `multipleDefense`)
- Test: `HesindionTests/RuleFixtureTests.swift` (new), `HesindionTests/CombatSituationTests.swift`

**Acceptance Criteria:**
- [ ] `DefenseModifiers.all` no longer contains `multipleDefense`; the union test passes.
- [ ] A second parry is −3, a third −6, and a dodge after two parries is unpenalised — through `CombatSituation.defenseModifiers`, found by `ruleId == "GRW_mehrfacheVerteidigung"`.
- [ ] With a Fechtwaffe in hand and SA_923, a second parry is −2; with a Schwert it is −3 and SA_923 is `conditionFalse`; with no defence yet SA_923 is `modifiedRuleNotInEffect`.
- [ ] Snapshot: implemented 2, byHand 45, todo 2629.

**Verify:** `make rules-db` prints `catalog: implemented 2, byHand 45, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: The fixture file and its first rows**

`HesindionTests/RuleFixtureTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// Design §6: hero, loadout, Situation, answers → lines, opponent lines,
/// offers, questions, not-applied. Every reviewed exemplar the catalog gains
/// gets a row here. These run against the bundled `rules.db`, so they also
/// hold the compiled clauses to what the YAML says.
@MainActor
final class RuleFixtureTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Helpers

    private func own(_ id: String, _ name: String, tier: Int? = nil, list: WritableKeyPath<Hero, [HeroTrait]> = \.combatSpecialAbilities) {
        hero[keyPath: list].append(HeroTrait(ruleId: id, name: name, tier: tier, sid: nil))
    }

    @discardableResult
    private func arm(_ name: String, technique: String, reach: String, select: Bool = true) -> MeleeWeapon {
        let weapon = MeleeWeapon(name: name, combatTechniqueId: technique, damage: "1W6+3", at: 12, pa: 8, reach: reach, weight: 1.5)
        hero.meleeWeapons.append(weapon)
        if select { hero.selectedWeaponName = name }
        return weapon
    }

    private func lines(_ s: Situation) -> [ModifierLine] { ModifierEngine.shared.evaluate(context: s) }
    private func evaluation(_ s: Situation) -> Evaluation { ModifierEngine.shared.evaluation(s) }
    private func value(_ ruleId: String, in lines: [ModifierLine]) -> Int? { lines.first { $0.ruleId == ruleId }?.value }
    private func reason(_ ruleId: String, in e: Evaluation) -> NotApplied.Reason? { e.notApplied.first { $0.ruleId == ruleId }?.reason }

    private func defence(_ domain: RuleDomain, parries: Int = 0, dodges: Int = 0) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.parriesThisRound = parries
        s.round.dodgesThisRound = dodges
        return s
    }

    // MARK: - Mehrfache Verteidigung (GRW)

    func testMehrfacheVerteidigungIsMinusThreePerDefenceOfTheSameKind() {
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry))))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 3))), -9)
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, parries: 2))), "the first dodge is free however often the hero parried")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, dodges: 1))), -3)
    }

    // MARK: - Vinsalt-Stil (SA_923)

    func testVinsaltStilSetsTheStepToTwoWithAFechtwaffeInHand() {
        own("SA_923", "Vinsalt-Stil")
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -2)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 2))), -4)
        XCTAssertTrue(evaluation(defence(.meleeParry, parries: 1)).applied.contains("SA_923"))
    }

    func testVinsaltStilNeedsItsWeaponAndSomethingToModify() {
        own("SA_923", "Vinsalt-Stil")
        arm("Langschwert", technique: "CT_12", reach: "Lang")
        let sword = evaluation(defence(.meleeParry, parries: 1))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(reason("SA_923", in: sword), .conditionFalse)
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(reason("SA_923", in: evaluation(defence(.meleeParry))), .modifiedRuleNotInEffect, "no second defence yet")
    }
}
```

In `CombatSituationTests.swift`, add a helper and switch the Mehrfache Verteidigung lookups to it:

```swift
    private func value(ofRule ruleId: String, in lines: [ModifierLine]) -> Int? {
        lines.first { $0.ruleId == ruleId }?.value
    }
```

Every `value(of: L("source.multipleDefense"), in: …)` becomes `value(ofRule: "GRW_mehrfacheVerteidigung", in: …)` (seven places: `testFirstDefenceOfTheRoundIsUnpenalised`, `testSecondDefenceIsAtMinusThreeAndItIsCumulative` ×3, `testParriesDoNotMakeTheFirstDodgeHarder` ×2, `testDodgesDoNotMakeTheFirstParryHarder` ×2, `testTheDodgeAccumulatesOnItsOwnCount`, `testAParryKeepsEveryLineWhicheverScreenRollsIt`). The other `value(of:)` lookups stay.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui`
Expected: `RuleFixtureTests` fail (no line with that `ruleId`; SA_923 absent), the seven `CombatSituationTests` fail the same way.

- [ ] **Step 3: The catalog entries**

Insert at the top of the non-todo block in `specs/data/rules-catalog.yaml`, before `- id: SA_40`:

```yaml
# ---------------------------------------------------------------------------
# Core rules without an Optolith id (design §4). GRW_ ids are exempt from the
# rules.db checks; the evaluator applies them to every hero. Fokusregeln that
# have no Optolith id use the same prefix and the group Fokusregel.
# ---------------------------------------------------------------------------
- id: GRW_mehrfacheVerteidigung
  name: "Mehrfache Verteidigung"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 232 }
  note: "−3 per defence already made this round, parries and dodges counted apart (CombatSituation.parriesThisRound / dodgesThisRound). Vinsalt-Stil (SA_923) sets the step to −2. The buttons' preview (CombatSituation.pendingMultipleDefensePenalty) still says −3; step 3 reads it off the evaluation."
  clauses:
    - kind: passive
      domains: [meleeParry, meleeDodge]
      when: [{ situation.defencesThisRound: { min: 1 } }]
      effects: [{ add: { target: vw, value: -3, per: defencesThisRound } }]

# ---------------------------------------------------------------------------
# Implemented through the evaluator (status implemented): the clauses say what
# the app does. reviewed is null until a person has read them against the text.
# ---------------------------------------------------------------------------
- id: SA_923
  name: "Vinsalt-Stil"
  group: "Kampfstile (bewaffnet)"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, src: US25007, page: 138 }
  note: "Mehrfache Verteidigung at −2 per defence instead of −3 (Optolith: 'nicht Erschwernisse von jeweils 3, sondern nur von jeweils 2'), with an Armbrust, a Fechtwaffe or a Zweihandschwert in hand — the style's Kampftechniken."
  cost: 20
  unlocks: [SA_197, SA_204, SA_965]
  applies_with: [{ loadout.weapon: { technique: [CT_1, CT_4, CT_16] } }]
  clauses:
    - kind: passive
      domains: [meleeParry, meleeDodge]
      effects: [{ modifyRule: { id: GRW_mehrfacheVerteidigung, target: vw, set: -2 } }]
```

Delete the line `- { id: SA_923, name: "Vinsalt-Stil", group: "Kampfstile (bewaffnet)", status: todo, why: not yet read }` further down.

- [ ] **Step 4: Delete the Swift definition**

In `DefenseModifiers.swift` remove `multipleDefense` from `all` and delete the definition with its comment. In `CombatSituation.swift` leave `pendingMultipleDefensePenalty` (the buttons) and `defensesSoFar`.

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `catalog: implemented 2, byHand 45, noRollEffect 0, todo 2629`. Then `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/DefenseModifiers.swift HesindionTests/RuleFixtureTests.swift HesindionTests/CombatSituationTests.swift
git commit -m "feat(rules): Mehrfache Verteidigung is a catalog rule, and Vinsalt-Stil rewrites its step"
```

---

### Task 8: Reichweite, Beengte Umgebung, the cap and Passierschlag

**Goal:** The two reach-keyed core rules move to the catalog; the −5 cap and Passierschlag get `byHand` entries so a Sonderfertigkeit can name them and the not-applied list is complete.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/MeleeModifiers.swift` (delete `attackerReach`, `weaponReach`, `beengteUmgebungAT`), `Hesindion/Engine/DefenseModifiers.swift` (delete `beengteUmgebungPA`)
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/WeaponReachTests.swift`, `HesindionTests/StateModifiersTests.swift`

**Acceptance Criteria:**
- [ ] The 3×3 reach matrix through `ModifierEngine.shared` matches `WeaponReach.atPenaltyAgainst`, found by `ruleId == "GRW_reichweite"`.
- [ ] Beengte Umgebung: Lang −8 AT and −8 PA, Mittel −4, Kurz nothing, bare hands nothing — `ruleId == "GRW_beengteUmgebung"`.
- [ ] `GRW_zustandsbegrenzung` and `GRW_passierschlag` are `byHand` with pointers that resolve.
- [ ] Snapshot: implemented 4, byHand 47, todo 2629.

**Verify:** `make rules-db` prints `implemented 4, byHand 47, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows and the moved tests**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Reichweite (GRW)

    func testTheShorterWeaponPaysForReach() {
        arm("Dolch", technique: "CT_3", reach: "Kurz")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Speer", technique: "CT_13", reach: "Lang", select: false)
        let expected: [String: [WeaponReach: Int?]] = [
            "Dolch": [.kurz: nil, .mittel: -2, .lang: -4],
            "Säbel": [.kurz: nil, .mittel: nil, .lang: -2],
            "Speer": [.kurz: nil, .mittel: nil, .lang: nil],
        ]
        for (weapon, row) in expected {
            for (opponent, penalty) in row {
                var s = Situation(hero: hero, domain: .meleeAttack)
                s.loadoutName = weapon
                s.opponents.current.reach = opponent
                XCTAssertEqual(value("GRW_reichweite", in: lines(s)), penalty, "\(weapon) against \(opponent.rawValue)")
            }
        }
    }

    // MARK: - Beengte Umgebung (GRW)

    func testBeengteUmgebungFollowsTheReachOfThePieceInHandOnAttackAndParry() {
        arm("Speer", technique: "CT_13", reach: "Lang")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Dolch", technique: "CT_3", reach: "Kurz", select: false)
        func penalty(_ domain: RuleDomain, _ loadout: String?) -> Int? {
            var s = Situation(hero: hero, domain: domain)
            s.round.beengteUmgebung = true
            s.loadoutName = loadout
            return value("GRW_beengteUmgebung", in: lines(s))
        }
        XCTAssertEqual(penalty(.meleeAttack, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeParry, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeAttack, "Säbel"), -4)
        XCTAssertEqual(penalty(.meleeParry, nil), -8, "nothing named: the main weapon, the Speer")
        XCTAssertNil(penalty(.meleeAttack, "Dolch"))
        XCTAssertNil(penalty(.meleeAttack, "Raufen"), "bare hands are kurz")
        XCTAssertNil(penalty(.meleeDodge, "Speer"), "a dodge is not a parry")
        var calm = Situation(hero: hero, domain: .meleeAttack)
        calm.loadoutName = "Speer"
        XCTAssertNil(value("GRW_beengteUmgebung", in: lines(calm)))
    }
```

`WeaponReachTests.swift`, the three engine tests: the `.filter { $0.source == L("source.reach") }` becomes `.filter { $0.ruleId == "GRW_reichweite" }` and `.filter { $0.source == L("beengteUmgebung") }` becomes `.filter { $0.ruleId == "GRW_beengteUmgebung" }`. Nothing else changes.

`StateModifiersTests.testEingeengtStatusDrivesBeengtePenaltyWithoutDoubleCount`: the hero has no weapon, and bare hands are kurz now, so give it one and look the line up by rule:

```swift
        let hero = makeHero()
        hero.meleeWeapons = [MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12", damage: "1W6+3", at: 12, pa: 8, reach: "Mittel", weight: 1.5)]
        hero.selectedWeaponName = "Säbel"
        hero.setStateLevel("eingeengt", level: 1)
        XCTAssertTrue(hero.hasState("eingeengt"))

        var ctx = Situation(hero: hero, domain: .meleeAttack)
        ctx.round.beengteUmgebung = hero.hasState("eingeengt")   // exactly how the combat views wire it
        let lines = ModifierEngine.shared.evaluate(context: ctx)

        // The Beengte-Umgebung line fires once, from the catalog (Mittel ⇒ −4).
        let beengteLines = lines.filter { $0.ruleId == "GRW_beengteUmgebung" }
        XCTAssertEqual(beengteLines.count, 1, "Beengte Umgebung penalty must fire exactly once")
        XCTAssertEqual(beengteLines.first?.value, -4)
```

Keep the two assertions that follow (`isZustand` count 0, `lines.count == 1`). `makeHero()` in that file must include `MeleeWeapon.self` in its `ModelContainer` schema list.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → the new fixture rows and the three `WeaponReachTests` engine tests fail on `nil`.

- [ ] **Step 3: The catalog entries**

Add to the core-rules block, after `GRW_mehrfacheVerteidigung`:

```yaml
- id: GRW_reichweite
  name: "Reichweite"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 238 }
  note: "The shorter weapon is penalised: Kurz gegen Mittel −2 AT, Kurz gegen Lang −4 AT, Mittel gegen Lang −2 AT; the longer side gets nothing (WeaponReach.atPenaltyAgainst is the same table for the announcement chips). The hero's side is the piece in the hand (Situation.loadoutReach, bare hands kurz); the opponent's reach is asked once per fight (OpponentProfile.reach)."
  clauses:
    - kind: passive
      domains: [meleeAttack]
      when: [{ loadout.reach: Kurz }, { opponent.reach: Mittel }]
      effects: [{ add: { target: at, value: -2 } }]
    - kind: passive
      domains: [meleeAttack]
      when: [{ loadout.reach: Kurz }, { opponent.reach: Lang }]
      effects: [{ add: { target: at, value: -4 } }]
    - kind: passive
      domains: [meleeAttack]
      when: [{ loadout.reach: Mittel }, { opponent.reach: Lang }]
      effects: [{ add: { target: at, value: -2 } }]

- id: GRW_beengteUmgebung
  name: "Beengte Umgebung"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 238 }
  note: "Kurz 0, Mittel −4 AT/PA, Lang −8 AT/PA, by the reach of the piece in the hand. The eingeengt status (STATE_6) is the toggle; CombatSituation.beengteUmgebung carries it into the roll."
  clauses:
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when: [situation.beengt, { loadout.reach: Mittel }]
      effects: [{ add: { target: at, value: -4 } }, { add: { target: pa, value: -4 } }]
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when: [situation.beengt, { loadout.reach: Lang }]
      effects: [{ add: { target: at, value: -8 } }, { add: { target: pa, value: -8 } }]

- id: GRW_zustandsbegrenzung
  name: "Zustände: höchstens −5"
  group: "Grundregel"
  status: byHand
  pointer: { file: Hesindion/Engine/ModifierEngine.swift, symbol: applyingZustandCap }
  note: "The combined Zustand penalty floors at −5. ModifierEngine.applyingZustandCap adds the correction line once, over Swift and catalog lines together (COND_ lines are tagged isZustand). The vocabulary has no cap effect, so this stays code; the evaluator's order puts it after every add and modification."

- id: GRW_passierschlag
  name: "Passierschlag"
  group: "Grundregel"
  status: byHand
  pointer: { file: Hesindion/Views/CombatView.swift, symbol: passierschlag }
  note: "A flow, not a modifier: CombatStep.passierschlag follows a critical parry (AGENTS.md, defence flow), or the Kritische Erfolge table replaces it (ADR-0011)."
```

Update `STATE_6`'s note in the same file: replace `(MeleeModifiers.beengteUmgebungAT)` with `(GRW_beengteUmgebung)`.

- [ ] **Step 4: Delete the Swift definitions**

`MeleeModifiers.swift`: remove `weaponReach` and `beengteUmgebungAT` from `all`; delete `attackerReach(_:)`, `weaponReach` and `beengteUmgebungAT`. `DefenseModifiers.swift`: remove and delete `beengteUmgebungPA`. `CombatAttackViews.heroWeaponReach` stays (the chips read it).

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 4, byHand 47, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DefenseModifiers.swift HesindionTests/RuleFixtureTests.swift HesindionTests/WeaponReachTests.swift HesindionTests/StateModifiersTests.swift
git commit -m "feat(rules): reach and Beengte Umgebung are catalog rules; the cap and Passierschlag have entries"
```

---

### Task 9: Zonenaufschlag, Gezielter Angriff, Gezielter Schuss, Überrascht

**Goal:** The Trefferzonen penalty is a `GRW_zonenaufschlag` entry; SA_160 and SA_161 halve it through `modifyRule … multiply`, an überraschter opponent eases it through `modifyRule … add` on the STATE_13 entry, and the third fixture row exists.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/HitZoneModifiers.swift` (delete `all` and `zonenaufschlag`; keep `penalty(for:hasSonderfertigkeit:targetIsSurprised:)` for `CombatZonePicker`), `Hesindion/Engine/ModifierEngine.swift:120-130` (drop `HitZoneModifiers.all`)
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/HitZoneEngineIntegrationTests.swift`, `HesindionTests/HitZoneModifiersTests.swift:56-70`, `HesindionTests/RulesCatalogTests.swift`

**Acceptance Criteria:**
- [ ] With the Trefferzonen rule on and Kopf announced: −10; with SA_160 in melee −5; überrascht on top −3; Torso with SA_160 and überrascht: no line, `netZero`. Without a zone SA_160 is `modifiedRuleNotInEffect`. SA_161 in melee is `wrongDomain`. With the rule off: nothing.
- [ ] `CombatZonePicker`'s chips still show the same numbers (`HitZoneModifiers.penalty` unchanged; its pure tests pass).
- [ ] `RulesCatalogTests.testEveryCatalogStateIsByHand` accepts an `implemented` state.
- [ ] Snapshot: implemented 8, byHand 44, todo 2629.

**Verify:** `make rules-db` prints `implemented 8, byHand 44, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows and the moved tests**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Zonenaufschlag (Fokusregel), Gezielter Angriff (SA_160), Gezielter Schuss (SA_161), Überrascht (STATE_13)

    private func aimed(_ domain: RuleDomain, at zone: HitZone?, surprised: Bool = false) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.targetHitZone = zone
        s.opponents.current.isSurprised = surprised
        return s
    }

    func testTheZonenaufschlagNeedsTheFokusregelAndAZone() {
        XCTAssertNil(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), "rule off")
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertNil(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: nil))))
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -10)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .torso))), -4)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .beine))), -8)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .schwanz))), -8, "extra limbs take the limb value")
    }

    func testGezielterAngriffHalvesItInMeleeOnlyAndSurpriseEasesItByTwo() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_160", "Gezielter Angriff")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -5)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf, surprised: true))), -3, "halved, then +2")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .kopf))), -10, "the melee ability does not halve a shot")
        let torso = evaluation(aimed(.meleeAttack, at: .torso, surprised: true))
        XCTAssertTrue(torso.lines.isEmpty, "−4, halved −2, +2 = 0")
        XCTAssertEqual(reason("GRW_zonenaufschlag", in: torso), .netZero)
        XCTAssertTrue(torso.applied.isSuperset(of: ["SA_160", "STATE_13"]))
        let unaimed = evaluation(aimed(.meleeAttack, at: nil))
        XCTAssertEqual(reason("SA_160", in: unaimed), .modifiedRuleNotInEffect)
        XCTAssertEqual(reason("STATE_13", in: unaimed), .conditionFalse)
    }

    func testGezielterSchussIsTheRangedHalf() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_161", "Gezielter Schuss")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .kopf))), -5)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -10)
        XCTAssertEqual(reason("SA_161", in: evaluation(aimed(.meleeAttack, at: .kopf))), .wrongDomain)
    }

    /// Every combination the picker can produce is a penalty or nothing: the
    /// evaluator has no clamp, so the arithmetic itself must never go positive.
    func testTheZonenaufschlagIsNeverABonus() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_160", "Gezielter Angriff")
        for zone in HitZone.allCases {
            let v = value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: zone, surprised: true))) ?? 0
            XCTAssertLessThanOrEqual(v, 0, "\(zone)")
        }
    }
```

`HitZoneEngineIntegrationTests.swift`: in `makeHero()` add `hero.setFokusRule(.trefferzonen, active: true)` before `return hero`; in the third test replace `lines.contains { $0.source.contains(L("modifier.trefferzone")) }` with `lines.contains { $0.ruleId == "GRW_zonenaufschlag" }`. Update the class comment: it now proves the catalog entry is bundled, not the Swift registration.

`HitZoneModifiersTests.swift`: keep `testBasePenalties` … `testNeverBecomesABonus` (the pure `penalty(for:)` the picker uses). Replace the last two:

```swift
    func testNoZoneProducesNoLine() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        let lines = ModifierEngine.shared.evaluate(context: Situation(hero: hero, domain: .meleeAttack))
        XCTAssertFalse(lines.contains { $0.ruleId == "GRW_zonenaufschlag" })
    }

    func testMeleeUsesSA160NotSA161() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_161", name: "Gezielter Schuss", tier: nil, sid: nil)]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.targetHitZone = .kopf
        // Ranged SF must not halve a melee attack.
        XCTAssertEqual(ModifierEngine.shared.evaluate(context: s).first { $0.ruleId == "GRW_zonenaufschlag" }?.value, -10)
    }
```

`RulesCatalogTests.testEveryCatalogStateIsByHand`, replace the first loop:

```swift
        for definition in StateCatalog.all where !displayOnlyExceptions.contains(definition.id) {
            let ruleId = try XCTUnwrap(StateModifiers.ruleIds[definition.id], definition.id)
            let entry = try XCTUnwrap(RulesDatabase.shared.lookupCatalogEntry(ruleId: ruleId), ruleId)
            // A state whose clauses moved to the catalog has nothing to point at.
            if entry.status == .implemented { continue }
            let matches = byHandStatePointers.filter { $0.symbol == definition.id }
            XCTAssertEqual(matches.count, 1, definition.id)
        }
```

and rename the test to `testEveryCatalogStateIsByHandOrImplemented`.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → the four fixture rows fail on `nil`; `testEveryCatalogStateIsByHand` still passes (nothing moved yet).

- [ ] **Step 3: The catalog entries**

Add to the core-rules block:

```yaml
- id: GRW_zonenaufschlag
  name: "Zonenaufschlag"
  group: "Fokusregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, id: FR_11, title: "Trefferzonen-Regeln", src: US25003, page: 128 }
  note: "Trefferzonen Fokusregel: an announced zone costs Kopf −10, Torso −4, Gliedmaßen −8 on AT or FK. Gezielter Angriff (SA_160) and Gezielter Schuss (SA_161) halve it, an überraschter opponent (STATE_13) eases it by 2 — halved first, then eased, so Kopf comes to −3. The extra limb zones of non-humanoid plans take the limb value by analogy, as HitZoneModifiers.penalty does for the picker's chips."
  clauses:
    - kind: passive
      domains: [meleeAttack, rangedAttack]
      when: [{ hero.fokusRule: trefferzonen }, { situation.targetZone: [kopf] }]
      effects: [{ add: { target: at, value: -10 } }, { add: { target: fk, value: -10 } }]
    - kind: passive
      domains: [meleeAttack, rangedAttack]
      when: [{ hero.fokusRule: trefferzonen }, { situation.targetZone: [torso, koerper] }]
      effects: [{ add: { target: at, value: -4 } }, { add: { target: fk, value: -4 } }]
    - kind: passive
      domains: [meleeAttack, rangedAttack]
      when: [{ hero.fokusRule: trefferzonen }, { situation.targetZone: [arme, beine, vordereBeine, mittlereGliedmassen, hintereBeine, schwanz, fangarme] }]
      effects: [{ add: { target: at, value: -8 } }, { add: { target: fk, value: -8 } }]
```

Replace the `byHand` entries for `SA_160`, `SA_161` and `STATE_13` in the top block with:

```yaml
- id: SA_160
  name: "Gezielter Angriff"
  group: "Kampf"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, src: US25003 }
  note: "Halves the Zonenaufschlag (GRW_zonenaufschlag) in melee, Trefferzonen Fokusregel."
  clauses:
    - kind: passive
      domains: [meleeAttack]
      effects: [{ modifyRule: { id: GRW_zonenaufschlag, target: at, multiply: 0.5 } }]

- id: SA_161
  name: "Gezielter Schuss"
  group: "Kampf"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, src: US25003 }
  note: "Halves the Zonenaufschlag (GRW_zonenaufschlag) at range, Trefferzonen Fokusregel."
  clauses:
    - kind: passive
      domains: [rangedAttack]
      effects: [{ modifyRule: { id: GRW_zonenaufschlag, target: fk, multiply: 0.5 } }]

- id: STATE_13
  name: "Überrascht"
  group: "Status (binary)"
  status: implemented
  reviewed: null
  note: "The hero überrascht: reminder only (StateCatalog.ueberrascht has no modifier). The opponent überrascht: the Zonenaufschlag is 2 easier (Trefferzonen Fokusregel), stated per attack on the roster entry."
  clauses:
    - kind: passive
      domains: [meleeAttack, rangedAttack]
      when: [{ opponent.state: ueberrascht }]
      effects:
        - { modifyRule: { id: GRW_zonenaufschlag, target: at, add: 2 } }
        - { modifyRule: { id: GRW_zonenaufschlag, target: fk, add: 2 } }
```

- [ ] **Step 4: Delete the Swift definition**

`HitZoneModifiers.swift`: delete `static let all` and `zonenaufschlag`; keep `basePenalty` and `penalty(for:hasSonderfertigkeit:targetIsSurprised:)` and add to the enum's comment: "The evaluator carries the rule (`GRW_zonenaufschlag`); `penalty` is the same table for the zone picker's chips until step 3 reads them off the evaluation." In `ModifierEngine.shared` remove `defs.append(contentsOf: HitZoneModifiers.all)`.

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 8, byHand 44, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/HitZoneModifiers.swift Hesindion/Engine/ModifierEngine.swift HesindionTests/RuleFixtureTests.swift HesindionTests/HitZoneEngineIntegrationTests.swift HesindionTests/HitZoneModifiersTests.swift HesindionTests/RulesCatalogTests.swift
git commit -m "feat(rules): the Zonenaufschlag is a catalog rule that two abilities and a status modify"
```

### Task 10: Vorteilhafte Position and Golgariten-Stil

**Goal:** Vorteilhafte Position is a `GRW_vorteilhaftePosition` entry (+2 AT and +2 PA, from the GM's toggle or from being mounted against a foot fighter); Golgariten-Stil (SA_661) raises its AT half by 2 and adds +1 PA mounted — the design's worked example, and the three divergences of the current code fixed.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/MeleeModifiers.swift` (delete `vorteilhaftePosition`, `golgariten`), `Hesindion/Engine/DefenseModifiers.swift` (delete `golgaritenPA`), `Hesindion/Engine/DamageModifiers.swift:48-54` (delete the Golgariten TP branch), `Hesindion/Models/Hero.swift:472-478` (delete `golgaritenActive`)
- Modify: `Hesindion/Views/CombatAttackViews.swift:370-372, 601, 679-695, 826-834`
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/DamageModifiersTests.swift:76-124`

**Acceptance Criteria:**
- [ ] Mounted Golgarit with Rabenschnabel against a foot fighter: AT lines `GRW_vorteilhaftePosition` +4 and no separate SA_661 AT line; parry lines `GRW_vorteilhaftePosition` +2 and `SA_661` +1. Against a mounted opponent: SA_661 +1 PA only. On foot: SA_661 `conditionFalse`. Opponent unstated: a question `onFoot`. Großschild alone qualifies.
- [ ] The GM toggle alone gives +2 AT and +2 PA on foot.
- [ ] Golgariten-Stil adds no TP.
- [ ] The announcement always shows the Vorteilhafte Position toggle; the manual `+2` insert in `buildModifierLines` is gone.
- [ ] Added after review: nothing in the app set `OpponentProfile.isOnFoot`, so a mounted Golgarit would have lost the +4 AT until step 3 — a visible regression for the sample hero. The announcement's opponent section therefore gains, when mounted, a "Gegner kämpft zu Fuß" toggle (`combat.opponent.onFoot`, off = not stated, so the calculation still says the question is open; the fact lasts the fight) — the first step-3 slice, pulled forward. `HesindionUITests/WeaponStyleFlowTests` flips it and asserts "Vorteilhafte Position" in the AT calculation and "Golgariten-Stil" in the PA one.
- [ ] Snapshot: implemented 10, byHand 43, todo 2629.

**Verify:** `make rules-db` prints `implemented 10, byHand 43, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows and the moved tests**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Vorteilhafte Position (GRW) and Golgariten-Stil (SA_661)

    /// A mounted Golgarit with the style's weapon, and nothing else switched on.
    private func golgarit(weapon: Bool = true, shield: Bool = false) {
        own("SA_661", "Golgariten-Stil")
        if weapon { arm("Rabenschnabel", technique: "CT_5", reach: "Mittel") }
        if shield {
            hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
            hero.selectedShieldName = "Großschild"
        }
    }

    private func mounted(_ domain: RuleDomain, onFoot: Bool?) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.mounted = true
        s.opponents.current.isOnFoot = onFoot
        return s
    }

    func testTheDesignsWorkedExample() {
        golgarit()
        let attack = lines(mounted(.meleeAttack, onFoot: true))
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: attack), 4, "Vorteilhafte Position +2, raised by Golgariten-Stil +2")
        XCTAssertNil(value("SA_661", in: attack), "the style has no AT line of its own")
        XCTAssertTrue(evaluation(mounted(.meleeAttack, onFoot: true)).applied.contains("SA_661"))
        let parry = lines(mounted(.meleeParry, onFoot: true))
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: parry), 2)
        XCTAssertEqual(value("SA_661", in: parry), 1)
    }

    func testAgainstAMountedOpponentOnlyTheParryBonusRemains() {
        golgarit()
        let attack = evaluation(mounted(.meleeAttack, onFoot: false))
        XCTAssertTrue(attack.lines.isEmpty)
        XCTAssertEqual(reason("GRW_vorteilhaftePosition", in: attack), .questionUnanswered, "no toggle, not on foot: the GM has not said")
        XCTAssertEqual(reason("SA_661", in: attack), .conditionFalse)
        XCTAssertEqual(value("SA_661", in: lines(mounted(.meleeParry, onFoot: false))), 1)
    }

    func testOnFootTheStylePaysNothingAndSaysWhy() {
        golgarit()
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.isOnFoot = true
        let e = evaluation(s)
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertEqual(reason("SA_661", in: e), .conditionFalse)
    }

    func testAnUnstatedOpponentIsAQuestion() {
        golgarit()
        let e = evaluation(mounted(.meleeAttack, onFoot: nil))
        XCTAssertTrue(e.questions.contains(RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "GRW_vorteilhaftePosition")))
        XCTAssertTrue(e.questions.contains(RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "SA_661")))
        XCTAssertEqual(reason("SA_661", in: e), .questionUnanswered)
    }

    func testTheGrossschildAloneQualifiesAndALangschwertDoesNot() {
        golgarit(weapon: false, shield: true)
        arm("Langschwert", technique: "CT_12", reach: "Lang")
        XCTAssertEqual(value("SA_661", in: lines(mounted(.meleeParry, onFoot: true))), 1, "Rabenschnabel *oder* Großschild")
        hero.selectedShieldName = nil
        XCTAssertEqual(reason("SA_661", in: evaluation(mounted(.meleeParry, onFoot: true))), .conditionFalse)
    }

    func testTheGMToggleIsVorteilhaftePositionOnFootToo() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.advantageousPosition = true
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: lines(s)), 2)
        var parry = Situation(hero: hero, domain: .meleeParry)
        parry.opponents = s.opponents
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: lines(parry)), 2)
    }
```

`DamageModifiersTests.swift`: replace `testGolgaritenAddsOneTPFromHorseback` and delete `testGolgaritenNeedsItsOwnLoadout`:

```swift
    /// The Regelwiki gives the style +1 PA and nothing on TP; the +1 TP the
    /// app used to add came from Optolith's stale prose (catalog note, SA_661).
    func testGolgaritenAddsNoTP() {
        let golgarit = golgaritenHero()
        XCTAssertTrue(DamageModifiers.lines(hero: golgarit, maneuver: .normal, twoHandedGrip: false, mounted: true).isEmpty)
    }
```

Keep `golgaritenHero()` and `testGolgaritenNeedsTheStyleNotJustAMount`.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → the six fixture rows fail; `testGolgaritenAddsNoTP` fails with one line.

- [ ] **Step 3: The catalog entries**

Add to the core-rules block:

```yaml
- id: GRW_vorteilhaftePosition
  name: "Vorteilhafte Position"
  group: "Grundregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Regelwerk", page: 238 }
    - { kind: book, title: "Regelwerk", page: 240 }
  note: "+2 AT and +2 PA when the hero is better placed. Two ways to be: the GM says so for this attack (the toggle on the announcement, gm.fact advantageousPosition), or the hero is mounted against a foot fighter (Regelwerk 240, Berittener Kampf — the opponent's onFoot is asked once per fight). Golgariten-Stil (SA_661) raises the AT half. The mounted branch comes first so a rider is asked about the opponent before the GM is asked about the position."
  clauses:
    - kind: passive
      domains: [meleeAttack, meleeParry]
      when:
        - any:
            - all: [situation.mounted, opponent.onFoot]
            - { gm.fact: { id: advantageousPosition, span: attack } }
      effects: [{ add: { target: at, value: 2 } }, { add: { target: pa, value: 2 } }]
```

Replace the `byHand` entry for `SA_661` with the design's entry:

```yaml
- id: SA_661
  name: "Golgariten-Stil"
  group: "Kampfstile (bewaffnet)"
  status: implemented
  reviewed: null
  sources:
    - { kind: book, title: "Aventurisches Götterwirken I", page: 229 }
    - { kind: book, title: "Kodex des Schwertes", page: 318 }
  text: |
    Kämpft der Held beritten gegen Fußkämpfer, erhöht sich die aus der vorteilhaften
    Position resultierende Erleichterung auf AT um +2. Außerdem bekommt der Abenteurer
    noch einen Bonus von +1 PA, wenn er sich auf dem Rücken eines Reittiers befindet.
  note: >
    Beritten mit Rabenschnabel oder Großschild: +1 PA. Gegen Fußkämpfer zusätzlich
    +2 AT auf die Vorteilhafte Position, also +4 AT und +3 PA insgesamt. The code
    used to demand Rabenschnabel *and* Großschild, grant the Vorteilhafte Position
    itself, and add +1 TP from Optolith's stale prose; the page says otherwise on all three.
  cost: 10
  prerequisites: { attributes: { MU: 13 } }
  unlocks: [SA_200, SA_207, SA_210]
  applies_with:
    all:
      - situation.mounted
      - any:
          - { loadout.weapon: { technique: CT_5, item: Rabenschnabel } }
          - { loadout.shield: { item: Großschild } }
  clauses:
    - kind: passive
      domains: [meleeAttack]
      when: [opponent.onFoot]
      effects: [{ modifyRule: { id: GRW_vorteilhaftePosition, target: at, add: 2 } }]
    - kind: passive
      domains: [meleeParry]
      effects: [{ add: { target: pa, value: 1 } }]
```

- [ ] **Step 4: Delete the Swift**

`MeleeModifiers.swift`: remove `vorteilhaftePosition` and `golgariten` from `all` and delete both. `DefenseModifiers.swift`: remove and delete `golgaritenPA`. `DamageModifiers.swift`: delete the `// Golgariten-Stil (SA_661)` block (the `if hero.golgaritenActive(mounted: mounted)` lines) and the sentence about Golgariten in the enum's doc comment. `Hero.swift`: delete `golgaritenActive(mounted:)` and its comment; keep `hasGolgaritenStil`.

`CombatAttackViews.swift`: delete `golgaritenForced`; in `opponentSummary` the line becomes `if opponent.advantageousPosition { parts.append("AT/PA +2") }`; the `if golgaritenForced { DSAToggleRowLabel(…) } else { DSAToggleRow(…) }` block becomes the `DSAToggleRow` alone with `detail: "AT/PA +2"` (keep the identifier), and its comment reads "Vorteilhafte Position. A mounted hero against a foot fighter has it without the toggle (GRW_vorteilhaftePosition asks the roster for onFoot)."; `buildModifierLines()` becomes:

```swift
    private func buildModifierLines() -> [ModifierLine] {
        ModifierEngine.shared.evaluate(context: situation(.meleeAttack))
    }
```

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 10, byHand 43, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DefenseModifiers.swift Hesindion/Engine/DamageModifiers.swift Hesindion/Models/Hero.swift Hesindion/Views/CombatAttackViews.swift HesindionTests/RuleFixtureTests.swift HesindionTests/DamageModifiersTests.swift
git commit -m "feat(rules): Golgariten-Stil reads as the page has it, on top of a Vorteilhafte Position the catalog owns"
```

---

### Task 11: Plänkler-Formation, the `choice` offer

**Goal:** SA_884 is an offer with two options; taking one (the setup screen's AT / VW choice, bridged through `CombatSituation.chosenOptions`) applies that option only.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/MeleeModifiers.swift` (delete `plaenklerAT`), `Hesindion/Engine/DefenseModifiers.swift` (delete `plaenklerVW`)
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/CombatSituationTests.swift`

**Acceptance Criteria:**
- [ ] Owning SA_884 with nothing chosen: an offer with shape `.choice` of two `add` effects, and `offerNotTaken`.
- [ ] AT chosen: +1 on `meleeAttack`, nothing on a parry (`wrongDomain`); VW chosen: +1 on `meleeParry` and `meleeDodge`, nothing on an attack.
- [ ] Snapshot: implemented 11, byHand 42, todo 2629.

**Verify:** `make rules-db` prints `implemented 11, byHand 42, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Plänkler-Formation (SA_884)

    private func formation(_ domain: RuleDomain, bonus: PlaenklerBonus?) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.plaenklerActive = bonus != nil
        s.round.plaenklerBonus = bonus ?? .at
        return s
    }

    func testPlaenklerFormationIsAnOfferUntilTheFormationDecides() {
        own("SA_884", "Plänkler-Formation")
        let e = evaluation(formation(.meleeAttack, bonus: nil))
        XCTAssertEqual(e.offers.map(\.ruleId), ["SA_884"])
        guard case .choice(let options)? = e.offers.first?.shape else { return XCTFail("not a choice") }
        XCTAssertEqual(options, [.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)])
        XCTAssertEqual(reason("SA_884", in: e), .offerNotTaken)
    }

    func testTheChosenHalfAppliesAndTheOtherDoesNot() {
        own("SA_884", "Plänkler-Formation")
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeAttack, bonus: .at))), 1)
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeParry, bonus: .at))))
        XCTAssertEqual(reason("SA_884", in: evaluation(formation(.meleeParry, bonus: .at))), .wrongDomain)
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeParry, bonus: .aw))), 1, "VW is parry and dodge")
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeDodge, bonus: .aw))), 1)
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeAttack, bonus: .aw))))
    }

    func testWithoutTheAbilityTheFormationSettingDoesNothing() {
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeAttack, bonus: .at))))
    }
```

In `CombatSituationTests.swift`, any `value(of: L("source.plaenkler"), in: …)` becomes `value(ofRule: "SA_884", in: …)`; a test that builds a `CombatSituation(plaenklerActive: true, …)` for a hero without SA_884 must first give the hero the trait (`hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_884", name: "Plänkler-Formation", tier: nil, sid: nil)]`), because the rule now applies only to its owner.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → the three fixture rows fail.

- [ ] **Step 3: The catalog entry**

Replace the `byHand` entry for `SA_884`:

```yaml
- id: SA_884
  name: "Plänkler-Formation"
  group: "Kampf"
  status: implemented
  reviewed: null
  note: "The formation agrees on +1 AT oder +1 VW for the fight. CombatSetupView asks which; CombatSituation.chosenOptions carries the answer to the evaluator (option 0 AT, option 1 VW) until step 3 stores choices by rule id."
  cost: 10
  clauses:
    - kind: offer
      domains: [meleeAttack, meleeParry, meleeDodge]
      effects:
        - choice:
            - { add: { target: at, value: 1 } }
            - { add: { target: vw, value: 1 } }
```

- [ ] **Step 4: Delete the Swift**

`MeleeModifiers.swift`: remove `plaenklerAT` from `all` and delete it. `DefenseModifiers.swift`: remove `plaenklerVW` from `all` and delete it (with its comment).

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 11, byHand 42, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`. If `CombatViewSnapshotTests.testPreparation` fails, check whether it is the known weapon-order flake before touching a reference.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DefenseModifiers.swift HesindionTests/RuleFixtureTests.swift HesindionTests/CombatSituationTests.swift
git commit -m "feat(rules): Plänkler-Formation is a choice the catalog offers"
```

---

### Task 12: Wuchtschlag, the tiered offer, and the damage domain

**Goal:** SA_67 is an offer with tiers; the announced tier gives AT −2 and TP +2 per tier; `DamageModifiers` becomes the damage domain's union point.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/MeleeModifiers.swift` (`maneuverAT` loses Wuchtschlag), `Hesindion/Engine/DamageModifiers.swift`
- Modify: `Hesindion/Views/CombatAttackViews.swift:838-845`
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/DamageModifiersTests.swift`, `HesindionTests/ModifierEngineUnionTests.swift`

**Acceptance Criteria:**
- [ ] Owning Wuchtschlag II: the attack lists an offer `.tiers(2)`; announcing `.wuchtschlag(tier: 2)` gives AT −4 (`ruleId == "SA_67"`) and TP +4 through `DamageModifiers.lines(situation:)`; tier 3 is capped at 2.
- [ ] `maneuverAT` no longer produces a line for Wuchtschlag; Finte and Vorstoß unchanged.
- [ ] `DamageModifiers.lines(situation:)` = grip + Sturmangriff (Swift) + the evaluator's `damage` lines; `DamageModifiers.rules` is checked by the union test.
- [ ] Snapshot: implemented 12, byHand 41, todo 2629.

**Verify:** `make rules-db` prints `implemented 12, byHand 41, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows and the moved tests**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Wuchtschlag (SA_67)

    private func swing(_ domain: RuleDomain, _ maneuver: CombatManeuver) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.maneuver = maneuver
        return s
    }

    func testWuchtschlagIsOfferedUpToTheOwnedTier() {
        own("SA_67", "Wuchtschlag", tier: 2)
        let e = evaluation(swing(.meleeAttack, .normal))
        XCTAssertEqual(e.offers.map(\.shape), [.tiers(2)])
        XCTAssertEqual(reason("SA_67", in: e), .offerNotTaken)
    }

    func testTheAnnouncedTierCostsATAndPaysTP() {
        own("SA_67", "Wuchtschlag", tier: 2)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 1)))), -2)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 2)))), -4)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 3)))), -4, "the hero has II")
        XCTAssertEqual(value("SA_67", in: DamageModifiers.lines(situation: swing(.damage, .wuchtschlag(tier: 2)))), 4)
        XCTAssertNil(value("SA_67", in: lines(swing(.meleeParry, .wuchtschlag(tier: 2)))))
    }
```

`DamageModifiersTests.swift`: the helper and the Wuchtschlag tests build a `Situation`:

```swift
    private func lines(maneuver: CombatManeuver = .normal, grip: Bool = false, mounted: Bool = false) -> [ModifierLine] {
        var s = Situation(hero: hero, domain: .damage)
        s.maneuver = maneuver
        s.round.twoHandedGrip = grip
        s.round.mounted = mounted
        return DamageModifiers.lines(situation: s)
    }

    private func ownWuchtschlag(tier: Int) {
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_67", name: "Wuchtschlag", tier: tier, sid: nil)]
    }
```

Add `ownWuchtschlag(tier: 3)` as the first line of `testWuchtschlagAddsTwoTPPerTier` and `ownWuchtschlag(tier: 1)` as the first line of `testTheGripStacksWithWuchtschlag`. The three remaining `DamageModifiers.lines(hero:maneuver:twoHandedGrip:mounted:)` calls (`testGolgaritenAddsNoTP`, `testSturmangriffAddsTwoPlusHalfTheMountsSpeed` ×2) become:

```swift
        var s = Situation(hero: golgarit, domain: .damage); s.round.mounted = true
        XCTAssertTrue(DamageModifiers.lines(situation: s).isEmpty)
```

and, for the rider, `var charge = Situation(hero: rider, domain: .damage); charge.maneuver = .sturmangriff; charge.round.mounted = true` / `var walk = Situation(hero: rider, domain: .damage); walk.round.mounted = true`, passed to `DamageModifiers.lines(situation:)`.

`ModifierEngineUnionTests.testNoRuleIsProducedByBothSides`: add after the loop:

```swift
        XCTAssertTrue(implemented.intersection(DamageModifiers.rules).isEmpty, "DamageModifiers still implements \(implemented.intersection(DamageModifiers.rules).sorted()) in Swift")
```

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui` → `extra argument 'situation' in call`.

- [ ] **Step 3: The catalog entry**

Replace the `byHand` entry for `SA_67`:

```yaml
- id: SA_67
  name: "Wuchtschlag"
  group: "Kampf"
  status: implemented
  reviewed: null
  note: "A manoeuvre: AT −2 and TP +2 per tier, every tier up to the hero's own offered (CombatAttackViews.availableManeuvers). The announced tier reaches the evaluator through Situation.maneuver until step 3 announces by rule id. Optolith lists Hiebwaffen, Kettenwaffen, Raufen and Schwerter; not expressed as applies_with because Raufen has no weapon row to match (issue #14) and the app offered it with any weapon before."
  cost: [15, 20, 25]
  clauses:
    - kind: offer
      domains: [meleeAttack, damage]
      tiers: owned
      effects:
        - { add: { target: at, value: -2, per: tier } }
        - { add: { target: tp, value: 2, per: tier } }
```

- [ ] **Step 4: The Swift halves**

`MeleeModifiers.swift`:

```swift
    /// Finte and Vorstoß. Wuchtschlag's AT half is the catalog's (SA_67).
    static let maneuverAT = ModifierDefinition(
        id: "maneuverAT",
        domains: [.meleeAttack],
        rules: ["SA_48", "SA_66"]
    ) { ctx in
        if case .wuchtschlag = ctx.maneuver { return nil }
        guard ctx.maneuver.atModifier != 0 else { return nil }
        return ModifierLine(value: ctx.maneuver.atModifier, source: ctx.maneuver.sourceLabel)
    }
```

`DamageModifiers.swift`, replace `lines(hero:maneuver:twoHandedGrip:mounted:)`:

```swift
    /// The catalog ids the Swift half below still stands for (the union test
    /// holds these apart from the implemented entries). The grip has no rule id.
    static let rules: [String] = [CombatAbility.berittenerKampf.rawValue]

    /// TP bonuses for a melee attack: the two the Swift side still makes, then
    /// what the catalog says for the `damage` domain.
    static func lines(situation: Situation) -> [ModifierLine] {
        precondition(situation.domain == .damage, "damage lines want the damage domain")
        var lines: [ModifierLine] = []

        if situation.round.twoHandedGrip {
            lines.append(ModifierLine(value: 1, source: L("source.twoHandedGrip")))
        }

        // Sturmangriff zu Pferd: +2 and half the mount's GS.
        if situation.maneuver == .sturmangriff, situation.hero.sturmangriffDamageBonus != 0 {
            lines.append(ModifierLine(value: situation.hero.sturmangriffDamageBonus, source: L("source.sturmangriff")))
        }

        lines += ModifierEngine.shared.evaluation(situation).lines.map(\.modifierLine)
        return lines
    }
```

Update the enum's doc comment: the Wuchtschlag sentence goes; "the same call" argument stays. `CombatAttackViews.damageBonusLines` becomes `DamageModifiers.lines(situation: situation(.damage))`.

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 12, byHand 41, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/MeleeModifiers.swift Hesindion/Engine/DamageModifiers.swift Hesindion/Views/CombatAttackViews.swift HesindionTests/RuleFixtureTests.swift HesindionTests/DamageModifiersTests.swift HesindionTests/ModifierEngineUnionTests.swift
git commit -m "feat(rules): Wuchtschlag is a tiered offer, and damage has a domain"
```

### Task 13: Liegend, the hero's and the opponent's

**Goal:** STATE_10 is one entry with both sides: the hero's own −4 AT / −2 VW (the first state to leave `StateModifiers`) and the `opponentAdd` line for a prone opponent.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Models/StateCatalog.swift:16-26, 167-171` (`StateMechanic.catalog`), `Hesindion/Models/OpponentProfile.swift` (`defenseModifiers` loses the prone line)
- Modify: `Hesindion/Views/CombatAttackViews.swift:890-892`
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/StateModifiersTests.swift:56-67`

**Acceptance Criteria:**
- [ ] Hero liegend: AT −4, PA −2, AW −2 with `ruleId == "STATE_10"`, not `isZustand`; a talent check unaffected (`wrongDomain`); under `schipIgnoreZustand` nothing.
- [ ] Opponent prone: one opponent line −2 (`vw`) on `meleeAttack`, and no hero line.
- [ ] `StateCatalog.liegend.mechanic == .catalog`; `StateModifiers.all` has no `state.liegend`.
- [ ] The two existing Liegend tests in `StateModifiersTests` pass unchanged.
- [ ] Snapshot: implemented 13, byHand 40, todo 2629.

**Verify:** `make rules-db` prints `implemented 13, byHand 40, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Liegend (STATE_10)

    func testAProneHeroAttacksAtMinusFourAndDefendsAtMinusTwo() {
        hero.setStateLevel("liegend", level: 1)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeAttack))), -4)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeParry))), -2)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeDodge))), -2)
        XCTAssertEqual(lines(Situation(hero: hero, domain: .meleeAttack)).first { $0.ruleId == "STATE_10" }?.isZustand, false, "a Status, not a Zustand: outside the −5 cap")
        XCTAssertEqual(reason("STATE_10", in: evaluation(Situation(hero: hero, domain: .talentCheck))), .wrongDomain)
        var ignored = Situation(hero: hero, domain: .meleeAttack)
        ignored.round.schipIgnoreZustand = true
        XCTAssertNil(value("STATE_10", in: lines(ignored)))
    }

    func testAProneOpponentIsTheirPenaltyNotTheHerosBonus() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.isProne = true
        let e = evaluation(s)
        XCTAssertEqual(e.opponentLines.map { ($0.ruleId, $0.value) }.map { "\($0.0) \($0.1)" }, ["STATE_10 -2"])
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertTrue(evaluation(Situation(hero: hero, domain: .meleeAttack)).opponentLines.isEmpty)
    }
```

`StateModifiersTests.testLiegendOnlyAffectsCombatDomains` and `testLiegendDefensePenaltyIsMinusTwo` stay exactly as they are: they go through `totalModifier`, which is the union.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → the two fixture rows fail (`STATE_10` absent; the hero line still comes from Swift with `ruleId == nil`).

- [ ] **Step 3: The catalog entry**

Replace the `byHand` entry for `STATE_10`:

```yaml
- id: STATE_10
  name: "Liegend"
  group: "Status (binary)"
  status: implemented
  reviewed: null
  note: "The hero liegend: AT −4, PA and AW −2 (a Status, outside the −5 Zustand cap). The opponent liegend: −2 on *their* defence, printed as an opponent line — the rules give the attacker nothing for it. Stated per attack on the roster entry (OpponentProfile.isProne)."
  clauses:
    - kind: passive
      domains: [meleeAttack]
      when: [{ hero.state: { id: liegend } }]
      effects: [{ add: { target: at, value: -4 } }]
    - kind: passive
      domains: [meleeParry, meleeDodge]
      when: [{ hero.state: { id: liegend } }]
      effects: [{ add: { target: vw, value: -2 } }]
    - kind: passive
      domains: [meleeAttack]
      when: [{ opponent.state: liegend }]
      effects: [{ opponentAdd: { target: vw, value: -2 } }]
```

- [ ] **Step 4: The Swift side**

`StateCatalog.swift`, add a mechanic case:

```swift
    /// The rules catalog carries the numbers (design §7 step 2); `StateModifiers`
    /// emits nothing for it. The chip shows no number, as for every Status.
    case catalog
```

and change `liegend`'s definition to `mechanic: .catalog,` (delete its `.penalty(domains:value:)` argument). `StateModifiers.penaltyDefinitions` already skips anything that is not `.penalty`.

`OpponentProfile.defenseModifiers(maneuver:isCriticalHit:)`: delete the `if isProne { … }` block; the doc comment's last sentence becomes "The Finte line is still made here; every other opponent line is the catalog's (`Evaluation.opponentLines`)." Update the `isProne` property comment to "Status Liegend, stated for this attack. `STATE_10` turns it into the opponent line."

`CombatAttackViews.swift`:

```swift
    private var opponentDefenseLines: [ModifierLine] {
        opponent.defenseModifiers(maneuver: selectedManeuver)
            + ModifierEngine.shared.evaluation(situation(.meleeAttack)).opponentLines.map(\.modifierLine)
    }
```

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 13, byHand 40, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Models/StateCatalog.swift Hesindion/Models/OpponentProfile.swift Hesindion/Views/CombatAttackViews.swift HesindionTests/RuleFixtureTests.swift
git commit -m "feat(rules): Liegend is one catalog entry for both sides of the fight"
```

---

### Task 14: Karmale Objekte, the multiplier and the GM's question

**Goal:** The Fokusregel is a `GRW_karmaleObjekte` entry: a consecrated weapon against a demon of its opposing deity doubles TP; whether the demon is of the opposing deity is a `gm.fact` question with opponent span (it lasts the fight, as it did before).

**Files:**
- Modify: `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Engine/DamageModifiers.swift` (`multiplier(situation:)`), `Hesindion/Models/KarmalWeapon.swift` (delete `damage(consecrated:target:)`)
- Modify: `Hesindion/Views/CombatAttackViews.swift:359-366`
- Test: `HesindionTests/RuleFixtureTests.swift`, `HesindionTests/KarmalWeaponTests.swift:14-49`

**Acceptance Criteria:**
- [ ] Rule on, weapon consecrated, demon, opposing deity stated: `DamageModifiers.multiplier` is `.double`; opposing deity unstated: `.unchanged` and a question `opposingDeity` (span `opponent`); not a demon: `conditionFalse` and no question; rule off or weapon not consecrated: `.unchanged`.
- [ ] `KarmalWeapon.statesSomething` and the consecrated-weapon setting tests are untouched.
- [ ] Snapshot: implemented 14, byHand 40, todo 2629 (total 2683).

**Verify:** `make rules-db` prints `implemented 14, byHand 40, noRollEffect 0, todo 2629`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows and the moved tests**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Karmale Objekte (Fokusregel)

    private func consecratedSwing(daemon: Bool, opposing: Bool?) -> Situation {
        var s = Situation(hero: hero, domain: .damage)
        s.loadoutName = "Rabenschnabel"
        s.opponents.current.isDaemon = daemon
        if let opposing { s.opponents.current.facts[OpponentProfile.opposingDeityKey] = opposing }
        return s
    }

    func testAConsecratedWeaponDoublesAgainstTheOpposingDeitysDemon() {
        hero.setFokusRule(.karmaleObjekte, active: true)
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .double)
        let e = evaluation(consecratedSwing(daemon: true, opposing: true))
        XCTAssertEqual(e.multipliers.map(\.ruleId), ["GRW_karmaleObjekte"])
    }

    func testWhichDeityIsTheGMsQuestionAndOnlyForADemon() {
        hero.setFokusRule(.karmaleObjekte, active: true)
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        let unasked = evaluation(consecratedSwing(daemon: true, opposing: nil))
        XCTAssertEqual(unasked.questions, [RuleQuestion(key: OpponentProfile.opposingDeityKey, askedBy: "GRW_karmaleObjekte")])
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: nil)), .unchanged)
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: evaluation(consecratedSwing(daemon: true, opposing: false))), .conditionFalse)
        let ordinary = evaluation(consecratedSwing(daemon: false, opposing: nil))
        XCTAssertTrue(ordinary.questions.isEmpty, "no demon, nothing to ask")
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: ordinary), .conditionFalse)
    }

    func testTheRuleAndTheWeaponBothHaveToBeOn() {
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .unchanged, "Fokusregel off")
        hero.setFokusRule(.karmaleObjekte, active: true)
        hero.setConsecrated("Rabenschnabel", false)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .unchanged, "an ordinary blade")
    }
```

`KarmalWeaponTests.swift`: delete `testAnOrdinaryTargetIsNeverAffected`, `testTheOpposingDeityDoublesIt` and `testItDoublesTheRolledDamage` (the fixture rows above cover them); `testAConsecratedWeaponDealsRegularDamageToADemon` keeps its `statesSomething` assertion only; `testAnUnconsecratedWeaponNeverDoubles` keeps its `statesSomething` assertion only. The `hero()` helper and the five setting tests stay.

- [ ] **Step 2: Run to see the build fail**

Run: `make test-ui` → `type 'DamageModifiers' has no member 'multiplier'`.

- [ ] **Step 3: The catalog entry**

Add to the core-rules block:

```yaml
- id: GRW_karmaleObjekte
  name: "Karmale Objekte"
  group: "Fokusregel"
  status: implemented
  reviewed: null
  sources:
    - { kind: wiki, url: "https://dsa.ulisses-regelwiki.de/Fokus_Karmale_Objekte.html", fetched: 2026-09-14 }
  text: |
    Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden. Angriffe mit
    geweihten Waffen der Gegengottheit erzeugen doppelte Trefferpunkte.
  note: "Fokusregel karmaleObjekte. Which weapon is geweiht is a hero-span answer under the rule's toggle (Hero.consecratedWeapons; no Optolith export says so). Whether the demon is of the opposing deity is the GM's call, once per fight (gm.fact opposingDeity, span opponent). Regular damage to any other demon is stated on screen, not computed (KarmalWeapon.statesSomething)."
  clauses:
    - kind: passive
      domains: [damage]
      when:
        - { hero.fokusRule: karmaleObjekte }
        - { loadout.weapon: { consecrated: true } }
        - { opponent.type: demon }
        - { gm.fact: { id: opposingDeity, span: opponent } }
      effects: [{ multiply: { target: tp, factor: 2 } }]
```

- [ ] **Step 4: The Swift side**

`DamageModifiers.swift`, add:

```swift
    /// The multiplier the catalog puts on the rolled TP, as the damage screen
    /// already understands it. Karmale Objekte is the only one today.
    static func multiplier(situation: Situation) -> CriticalDamage {
        precondition(situation.domain == .damage, "damage multipliers want the damage domain")
        guard let first = ModifierEngine.shared.evaluation(situation).multipliers.first(where: { $0.target == .tp }) else {
            return .unchanged
        }
        switch first.factor {
        case 1.5: return .oneAndAHalf
        case 2:   return .double
        case 3:   return .triple
        default:  return .unchanged
        }
    }
```

`KarmalWeapon.swift`: delete `damage(consecrated:target:)`; the enum's doc comment says the doubling is `GRW_karmaleObjekte`'s and this type is what the screen *says* about a demon. `CombatAttackViews.karmalDamage` becomes:

```swift
    private var karmalDamage: CriticalDamage {
        DamageModifiers.multiplier(situation: situation(.damage))
    }
```

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 14, byHand 40, noRollEffect 0, todo 2629`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Engine/DamageModifiers.swift Hesindion/Models/KarmalWeapon.swift Hesindion/Views/CombatAttackViews.swift HesindionTests/RuleFixtureTests.swift HesindionTests/KarmalWeaponTests.swift
git commit -m "feat(rules): Karmale Objekte doubles from the catalog and asks the GM which deity"
```

---

### Task 15: Verweichlicht, a talent target in the wound-effect probe

**Goal:** DISADV_57 makes the Selbstbeherrschung check of a Wundeffekt 2 harder — a rule the app owned and never applied.

**Files:**
- Modify: `specs/data/rules-catalog.yaml` (delete the todo line, add the entry), `specs/data/rules-catalog.snapshot.json`, `Hesindion/Resources/rules.db`
- Modify: `Hesindion/Views/TalentProbeModal.swift:5-12, 21-25`, `Hesindion/Views/CombatDamageViews.swift:334-342`
- Test: `HesindionTests/RuleFixtureTests.swift`

**Acceptance Criteria:**
- [ ] Hero with DISADV_57, `talentCheck` on TAL_8 with `isWoundEffectProbe`: −2 (`ruleId == "DISADV_57"`); the same check without the wound effect: `conditionFalse`; a wound-effect probe on another talent: `wrongDomain`.
- [ ] `TalentProbeModal` has `isWoundEffectProbe: Bool = false` and the wound-effect overlay in `CombatDamageViews` passes `true`.
- [ ] Snapshot: implemented 15, byHand 40, todo 2628.

**Verify:** `make rules-db` prints `implemented 15, byHand 40, noRollEffect 0, todo 2628`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Fixture rows**

Append to `RuleFixtureTests`:

```swift
    // MARK: - Verweichlicht (DISADV_57)

    private func probe(_ talentId: String, woundEffect: Bool) -> Situation {
        var s = Situation(hero: hero, domain: .talentCheck)
        s.talentId = talentId
        s.isWoundEffectProbe = woundEffect
        return s
    }

    func testVerweichlichtMakesTheWundeffektProbeTwoHarder() {
        own("DISADV_57", "Verweichlicht", list: \.disadvantages)
        XCTAssertEqual(value("DISADV_57", in: lines(probe(Talent.selbstbeherrschungRuleId, woundEffect: true))), -2)
        XCTAssertEqual(reason("DISADV_57", in: evaluation(probe(Talent.selbstbeherrschungRuleId, woundEffect: false))), .conditionFalse)
        XCTAssertEqual(reason("DISADV_57", in: evaluation(probe(Talent.sinnesschaerfeRuleId, woundEffect: true))), .wrongDomain)
    }

    func testWithoutTheNachteilTheProbeIsUnmodified() {
        XCTAssertNil(value("DISADV_57", in: lines(probe(Talent.selbstbeherrschungRuleId, woundEffect: true))))
    }
```

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui` → `'Situation' has no member 'isWoundEffectProbe'` does *not* appear (Task 1 added it); the first fixture row fails on `nil`.

- [ ] **Step 3: The catalog entry**

Delete the line `- { id: DISADV_57, name: "Verweichlicht", group: "Nachteil", status: todo, why: not yet read }` and add to the implemented block:

```yaml
- id: DISADV_57
  name: "Verweichlicht"
  group: "Nachteil"
  status: implemented
  reviewed: null
  sources:
    - { kind: optolith, src: US25003, page: 133 }
  note: "The Selbstbeherrschung check (TAL_8) a Wundeffekt demands is 2 harder (Optolith: 'Bei der Probe auf Selbstbeherrschung … bei Wundeffekten … eine Erschwernis von 2'). Only that probe — CombatWoundEffectPanel opens TalentProbeModal with isWoundEffectProbe — not every Selbstbeherrschung check."
  clauses:
    - kind: passive
      domains: [talentCheck]
      when: [situation.woundEffect]
      effects: [{ add: { target: { talent: TAL_8 }, value: -2 } }]
```

- [ ] **Step 4: The views say which probe it is**

`TalentProbeModal.swift`: add after `initialModifier`:

```swift
    /// The Selbstbeherrschung check a Wundeffekt demands (`CombatWoundEffectPanel`),
    /// which Verweichlicht (DISADV_57) makes harder. A free-standing check is not.
    var isWoundEffectProbe: Bool = false
```

and in `modifierLines` add `situation.isWoundEffectProbe = isWoundEffectProbe` after `situation.talentId = talent.ruleId`. In `CombatDamageViews.swift`, the `TalentProbeModal(` inside `if showingProbeModal, let talent = probeTalent` (the one with `WoundEffectResolver.probeModifier`) gets `isWoundEffectProbe: true,` after its `initialModifier:` argument. The other two `TalentProbeModal(` calls in that file are not wound-effect probes and stay.

- [ ] **Step 5: Rebuild and run**

Run: `UPDATE_SNAPSHOT=1 make rules-db` → `implemented 15, byHand 40, noRollEffect 0, todo 2628`. `make test-ui` → `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db Hesindion/Views/TalentProbeModal.swift Hesindion/Views/CombatDamageViews.swift HesindionTests/RuleFixtureTests.swift
git commit -m "feat(rules): Verweichlicht is applied where the rule says, on the Wundeffekt probe"
```

---

### Task 16: Reachability, and the record

**Goal:** Every `implemented` clause is proven to fire from a generated hero and Situation, and the docs say where step 2 landed.

**Files:**
- Create: `HesindionTests/RuleReachabilityTests.swift`
- Modify: `AGENTS.md` (the rules-catalog bullet), `CHANGELOG.md`, `docs/plans/2026-09-14-rules-catalog-next-steps.md`

**Acceptance Criteria:**
- [ ] For every `implemented` entry, every clause and every domain it names, a hero and Situation built from its predicates make `evaluation.applied` contain the rule id — including clauses whose only effect is a `modifyRule`, by also satisfying the modified rule.
- [ ] The test fails (not skips) if the bundled catalog has no `implemented` entry.
- [ ] A second test asserts that every `RuleVocabulary.Predicate` and `.Effect` case is used by at least one `implemented` clause — the vocabulary holds exactly what the catalog needs, and an item nobody uses is an item nobody tested.
- [ ] AGENTS.md describes the evaluator, the union, and how a rule moves; CHANGELOG lists the three behaviour changes (Golgariten-Stil, Vinsalt-Stil, Verweichlicht); the next-steps doc says what step 3 and the remaining moves are.

**Verify:** `make test-ui` → `RuleReachabilityTests` passes; `git status` clean after the commit.

**Steps:**

- [ ] **Step 1: The reachability test**

`HesindionTests/RuleReachabilityTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// Design §4, "what fails the build": an `implemented` clause that cannot fire.
/// Because the vocabulary is closed, every predicate has a known satisfying
/// assignment; this builds it and asserts the rule applied.
@MainActor
final class RuleReachabilityTests: XCTestCase {

    func testEveryImplementedClauseCanFire() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let catalog = RuleCatalog.bundled
        XCTAssertFalse(catalog.implemented.isEmpty, "nothing is implemented; the fixtures are gone")
        for rule in catalog.implemented {
            for (index, clause) in rule.clauses.enumerated() {
                for domain in clause.domains {
                    let context = ModelContext(try TestData.makeContainer())
                    let hero = Hero(name: "Reach")
                    context.insert(hero)
                    var situation = Situation(hero: hero, domain: domain)
                    var visited: Set<String> = []
                    satisfy(rule, clause, in: catalog, hero: hero, situation: &situation, visited: &visited)
                    let evaluation = RuleEvaluator.evaluate(catalog: catalog, situation: situation)
                    XCTAssertTrue(
                        evaluation.applied.contains(rule.id),
                        "\(rule.id) clause \(index) in \(domain) did not fire: \(evaluation.notApplied.filter { $0.ruleId == rule.id }.map(\.reason)), questions \(evaluation.questions.map(\.key))"
                    )
                }
            }
        }
    }

    /// The other direction: the vocabulary is scoped to what the fixtures need,
    /// so a predicate or effect no entry uses has no interpreter anyone exercised.
    func testEveryVocabularyItemIsUsedByAnImplementedClause() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        var predicates: Set<RuleVocabulary.Predicate> = []
        var effects: Set<RuleVocabulary.Effect> = []
        for rule in RuleCatalog.bundled.implemented {
            if let gate = rule.appliesWith { collect(gate, into: &predicates) }
            for clause in rule.clauses {
                if let when = clause.when { collect(when, into: &predicates) }
                for effect in clause.effects { collect(effect, into: &effects) }
            }
        }
        XCTAssertEqual(predicates, Set(RuleVocabulary.Predicate.allCases), "unused: \(Set(RuleVocabulary.Predicate.allCases).subtracting(predicates))")
        XCTAssertEqual(effects, Set(RuleVocabulary.Effect.allCases), "unused: \(Set(RuleVocabulary.Effect.allCases).subtracting(effects))")
    }

    private func collect(_ p: RulePredicate, into set: inout Set<RuleVocabulary.Predicate>) {
        switch p {
        case .all(let parts), .any(let parts): parts.forEach { collect($0, into: &set) }
        case .not(let part): collect(part, into: &set)
        case .heroHasRule: set.insert(.heroHasRule)
        case .heroState: set.insert(.heroState)
        case .heroFokusRule: set.insert(.heroFokusRule)
        case .loadoutWeapon: set.insert(.loadoutWeapon)
        case .loadoutShield: set.insert(.loadoutShield)
        case .loadoutReach: set.insert(.loadoutReach)
        case .situationMounted: set.insert(.situationMounted)
        case .situationBeengt: set.insert(.situationBeengt)
        case .situationDefencesThisRound: set.insert(.situationDefencesThisRound)
        case .situationTargetZone: set.insert(.situationTargetZone)
        case .situationWoundEffect: set.insert(.situationWoundEffect)
        case .opponentReach: set.insert(.opponentReach)
        case .opponentOnFoot: set.insert(.opponentOnFoot)
        case .opponentState: set.insert(.opponentState)
        case .opponentType: set.insert(.opponentType)
        case .gmFact: set.insert(.gmFact)
        }
    }

    private func collect(_ e: RuleEffect, into set: inout Set<RuleVocabulary.Effect>) {
        switch e {
        case .add: set.insert(.add)
        case .multiply: set.insert(.multiply)
        case .opponentAdd: set.insert(.opponentAdd)
        case .modifyRule: set.insert(.modifyRule)
        case .choice(let options): set.insert(.choice); options.forEach { collect($0, into: &set) }
        }
    }

    // MARK: - Building a situation that satisfies a clause

    private func satisfy(_ rule: CatalogRule, _ clause: RuleClause, in catalog: RuleCatalog,
                         hero: Hero, situation s: inout Situation, visited: inout Set<String>) {
        guard visited.insert(rule.id).inserted else { return }
        if rule.needsOwnership && hero.ownedRuleTier(rule.id) == nil {
            hero.combatSpecialAbilities.append(HeroTrait(ruleId: rule.id, name: rule.name, tier: 3, sid: nil))
        }
        if let gate = rule.appliesWith { satisfy(gate, hero: hero, situation: &s) }
        if let when = clause.when { satisfy(when, hero: hero, situation: &s) }
        if clause.kind == .offer {
            if case .choice(let options)? = clause.effects.first {
                // Take the option that has something to say in this domain.
                let fitting = options.firstIndex { option in
                    guard let target = target(of: option) else { return false }
                    if case .talent(let id) = target { s.talentId = id }
                    return target.applies(in: s.domain, talentId: s.talentId)
                }
                s.choices[rule.id] = fitting ?? 0
            } else {
                s.announced[rule.id] = 1
            }
        }
        for effect in clause.effects {
            switch effect {
            case .add(let target, _, _), .multiply(let target, _), .opponentAdd(let target, _):
                if case .talent(let id) = target { s.talentId = id }
            case .modifyRule(let id, let target, _, _, _):
                if case .talent(let talentId) = target { s.talentId = talentId }
                guard let modified = catalog.rules[id] else { continue }
                // The modified rule must be in effect on the same target in this domain.
                let base = modified.clauses.first { c in
                    c.domains.contains(s.domain) && c.effects.contains { e in
                        if case .add(let t, _, _) = e { return t == target }
                        return false
                    }
                }
                if let base { satisfy(modified, base, in: catalog, hero: hero, situation: &s, visited: &visited) }
            case .choice:
                break   // the option was chosen above
            }
        }
    }

    private func target(of effect: RuleEffect) -> RuleTarget? {
        switch effect {
        case .add(let t, _, _), .multiply(let t, _), .opponentAdd(let t, _), .modifyRule(_, let t, _, _, _): t
        case .choice: nil
        }
    }

    private func satisfy(_ predicate: RulePredicate, hero: Hero, situation s: inout Situation) {
        switch predicate {
        case .all(let parts):
            parts.forEach { satisfy($0, hero: hero, situation: &s) }
        case .any(let parts):
            if let first = parts.first { satisfy(first, hero: hero, situation: &s) }
        case .not:
            break   // everything the generator does not set is already false
        case .heroHasRule(let id, let minTier):
            hero.combatSpecialAbilities.append(HeroTrait(ruleId: id, name: id, tier: minTier, sid: nil))
        case .heroState(let id, let minLevel):
            hero.setStateLevel(id, level: minLevel)
        case .heroFokusRule(let raw):
            if let rule = FokusRule(rawValue: raw) { hero.setFokusRule(rule, active: true) }
        case .loadoutWeapon(let technique, let item, let consecrated):
            let name = item ?? "Testwaffe"
            let weapon = weapon(named: name, technique: technique?.first ?? "CT_12", hero: hero)
            hero.selectedWeaponName = weapon.name
            s.loadoutName = weapon.name
            if consecrated == true { hero.setConsecrated(weapon.name, true) }
        case .loadoutShield(let item):
            let name = item ?? "Testschild"
            if !hero.shields.contains(where: { $0.name == name }) {
                hero.shields.append(Shield(name: name, damage: "1W6", at: 6, pa: 10, reach: "Kurz", structurePoints: 20, weight: 5))
            }
            hero.selectedShieldName = name
        case .loadoutReach(let reach):
            let name = s.loadoutName ?? hero.selectedWeaponName ?? "Testwaffe"
            let weapon = weapon(named: name, technique: "CT_12", hero: hero)
            weapon.reach = reach.rawValue
            hero.selectedWeaponName = weapon.name
            s.loadoutName = weapon.name
        case .situationMounted:
            s.round.mounted = true
        case .situationBeengt:
            s.round.beengteUmgebung = true
        case .situationDefencesThisRound(let min):
            s.round.parriesThisRound = min
            s.round.dodgesThisRound = min
        case .situationTargetZone(let zones):
            s.targetHitZone = zones.first
        case .situationWoundEffect:
            s.isWoundEffectProbe = true
        case .opponentReach(let reach):
            s.opponents.current.reach = reach
        case .opponentOnFoot:
            s.opponents.current.isOnFoot = true
        case .opponentState(let id):
            s.opponents.current.states.insert(id)
        case .opponentType(.demon):
            s.opponents.current.isDaemon = true
        case .gmFact(let id, let span):
            s.opponents.current.facts[FactKey(id: id, span: span)] = true
        }
    }

    private func weapon(named name: String, technique: String, hero: Hero) -> MeleeWeapon {
        if let existing = hero.meleeWeapons.first(where: { $0.name == name }) { return existing }
        let weapon = MeleeWeapon(name: name, combatTechniqueId: technique, damage: "1W6+3", at: 12, pa: 8, reach: "Mittel", weight: 1.5)
        hero.meleeWeapons.append(weapon)
        return weapon
    }
}
```

- [ ] **Step 2: Run**

Run: `make test-ui` → `RuleReachabilityTests` passes. If a clause fails, the message names it, its reasons and its open questions: fix the entry (or, if the generator cannot satisfy a legitimate predicate, the generator), not the assertion.

- [ ] **Step 3: AGENTS.md**

In the Combat System section, replace the bullet that begins `**The rules catalog says what the app does with every rule.**` with:

```markdown
- **The rules catalog says what the app does with every rule, and for `implemented` ones it *is* what the app does.** `specs/data/rules-catalog.yaml` has one entry per rule id in `rules.db` plus `GRW_*` entries for core rules and Fokusregeln without an Optolith id, each with a status — `implemented` (clauses the evaluator interprets), `byHand` (a pointer to the Swift symbol), `noRollEffect`, `todo` — and `make rules-db` validates it against `specs/data/rule-vocabulary.json` (the closed vocabulary `RuleVocabulary` exports; a test keeps the two identical), compiles it into the `catalog` table (clauses as JSON), and fails on a missing or unknown id, a name or group that differs from the database, a pointer that does not resolve, a clause outside the vocabulary, a `modifyRule` naming an entry that is not implemented, or status counts that drift from `specs/data/rules-catalog.snapshot.json` (`UPDATE_SNAPSHOT=1` rewrites it; commit it with the catalog and `rules.db`). **`RuleEvaluator`** (`Hesindion/Engine/RuleEvaluator.swift`) reads the compiled rules (`RuleCatalog.bundled`) against a **`Situation`** (`Hesindion/Engine/Situation.swift`: the hero, the domain, the round as `CombatSituation`, the other side as an `OpponentRoster` of `OpponentProfile`s with their stated `states` and GM `facts`, and what belongs to this attack or check) and returns an `Evaluation`: lines, multipliers, opponent lines, offers, questions and the not-applied list with a reason for every owned rule that did not fire. Order of application is fixed: base adds → `modifyRule` (set, multiply, add) → zero lines dropped; the −5 Zustand cap is applied once by `ModifierEngine.applyingZustandCap`. **During the migration `ModifierEngine.evaluate` is the union** of the Swift `ModifierDefinition`s still in `Hesindion/Engine/*Modifiers.swift` and the evaluator; every definition names the catalog ids it stands for (`rules:`) and `ModifierEngineUnionTests` refuses a rule implemented on both sides. Moving a rule: delete the definition, write the entry (`reviewed: null` until a person has read the clauses against the text — the app shows "ungeprüft"), rebuild with the new snapshot, keep the definition's test finding its line by `ruleId`, add a row to `RuleFixtureTests`; `RuleReachabilityTests` proves every clause can fire. A rule applies to a hero exactly when its id is among the hero's traits (`Hero.ownedRuleTier`); `GRW_`, `COND_` and `STATE_` entries apply to everyone and their `when` gates them. Growing the vocabulary is a code change in `RuleVocabulary` with an interpreter case, a decoder case, a reachability case and a test. Design: `docs/plans/2026-09-14-rules-catalog-design.md`; issue #27
```

Elsewhere in AGENTS.md: in the Testing section's list of accessibility identifiers add `combat.opponent.onFoot` (the announcement's "fights on foot" toggle, Task 10) and `combat.execution.breakdown` (the execution screen's calculation box, which the UI tests scope their row assertions to). In the Trefferzonen section replace "`HitZoneModifiers` emits the Zonenaufschlag as a `ModifierLine` (`SA_160` halves in melee, `SA_161` at range; `targetIsSurprised` is a GM flag on `ModifierContext`, …)" with "`GRW_zonenaufschlag` in the catalog is the Zonenaufschlag; `SA_160` and `SA_161` halve it and an überraschter opponent (`STATE_13`, stated on the roster entry) eases it by 2; `HitZoneModifiers.penalty` is the same table for the zone picker's chips until step 3 reads them off the evaluation". In the "Weapon reach" bullet replace "passed to the engine as `ModifierContext.attackerReach`" with "`Situation.loadoutName` names it and `GRW_reichweite` reads `Situation.loadoutReach`". In the "Karmale Objekte" bullet replace "(`KarmalWeapon`)" with "(`GRW_karmaleObjekte`; `KarmalWeapon.statesSomething` is what the screen says about a demon)". In the "`CombatSituation`" bullet append "It is the round part of `Situation`." In the "Player States" section replace "active Zustände feed penalties into the `ModifierEngine`" with "active Zustände feed penalties into the `ModifierEngine` from `StateModifiers` (`mechanic: .penalty`) or from the catalog (`mechanic: .catalog`, Liegend so far)".

- [ ] **Step 4: CHANGELOG.md**

Under `[Unreleased]`:

```markdown
### Added
- Rules evaluator (issue #27, step 2): `implemented` catalog entries drive the roll through `RuleEvaluator`; the calculation lists every owned rule that did not apply and why, offers manoeuvres and choices from the catalog, and asks the GM for facts a rule needs (rendered in step 3). Fifteen entries are implemented: Mehrfache Verteidigung, Reichweite, Beengte Umgebung, Vorteilhafte Position, Zonenaufschlag, Karmale Objekte, Gezielter Angriff, Gezielter Schuss, Wuchtschlag, Plänkler-Formation, Golgariten-Stil, Vinsalt-Stil, Verweichlicht, Liegend, Überrascht.
- `specs/data/rule-vocabulary.json`: the closed clause vocabulary, exported from Swift and enforced by `make rules-db`.
- The announcement's opponent section asks, when the hero is mounted, whether the opponent fights on foot; Vorteilhafte Position and Golgariten-Stil read the answer.

### Changed
- `ModifierContext` is `Situation`; the opponent is a roster entry with stated states and GM facts.
- A modifier line from the catalog is labelled with the rule's name and carries its id.

### Fixed
- Golgariten-Stil follows the Regelwiki: Rabenschnabel *or* Großschild, +2 AT only on top of an existing Vorteilhafte Position against a foot fighter, +1 PA mounted, and no TP bonus.
- Vinsalt-Stil: Mehrfache Verteidigung at −2 instead of −3 with a Fechtwaffe, Armbrust or Zweihandschwert in hand (was not applied).
- Verweichlicht: the Wundeffekt's Selbstbeherrschung check is 2 harder (was not applied).
- Vorteilhafte Position gives +2 PA as well as +2 AT, and a mounted hero has it against a foot fighter without the toggle.
- The Zonenaufschlag needs the Trefferzonen Fokusregel to be on, not only a zone.
```

- [ ] **Step 5: The next-steps doc**

In `docs/plans/2026-09-14-rules-catalog-next-steps.md` replace the section `## Next: step 2, the evaluator (design §7 step 2)` with:

```markdown
## Step 2 landed (plan: `docs/plans/2026-09-14-rules-evaluator-plan.md`)

`Situation`, `RuleVocabulary` + `specs/data/rule-vocabulary.json`, the Python clause validator and JSON compile, `RuleCatalog` decoding, `RuleEvaluator`, the union in `ModifierEngine`, eight `GRW_*` entries, the nine fixtures (`RuleFixtureTests`), the reachability test. Snapshot: implemented 15, byHand 40, todo 2628.

## Next: finish the moves, then step 3

Still in Swift, each a delete-the-definition / add-the-entry / keep-the-test move like Tasks 7–15 of the evaluator plan:

- `SharedModifiers.encumbrance` (COND_1) — needs a `hero.belastung` predicate or `hero.state(belastung)` with a per-level value and the mounted −1 forgiveness.
- `StateModifiers` per-level Zustände (COND_2 Betäubung, COND_4 Furcht, COND_5 Paralyse, COND_6 Schmerz, COND_7 Verwirrung, STATE_7 Fixiert) — needs `per: level` on `add`; `entrueckungDef` (COND_3) needs the gottgefällig sign flip.
- `MeleeModifiers.maneuverAT` (SA_48 Finte, SA_66 Vorstoß), `dualAttackPenalty` / `DefenseModifiers.dualAttackDefense` (SA_42), `offHandPenalty` / `offHandParry` (ADV_5) — need `situation.dualAttack`, `situation.offHand`, and Finte's opponent line.
- `DefenseModifiers.schipDefenseBoost`, `mountedDodgePenalty`, `twoHandedGripPA`; `DamageModifiers`' grip and Sturmangriff (SA_43) — `GRW_*` entries and `situation.twoHandedGrip`, `situation.schip…` predicates.
- `RangedModifiers` (eight) and `MagicModifiers` (seven) — `GRW_*` entries with enumerated `gm.fact`s (distance, size, movement, visibility, aiming, distraction) or numeric ones (maintained spells, iron carried): the vocabulary needs non-boolean facts first.

When the Swift list is empty, `ModifierDefinition`, the union and `Situation`'s flat ranged/magic fields go.

Step 3 (views read the Evaluation): the announcement builds manoeuvres from `offers`, opponent questions from `questions` (a boolean fact is a toggle, `onFoot` and `advantageousPosition` first), shows the not-applied list under the breakdown and "ungeprüft" on unreviewed lines; `CombatView` holds the roster with a current target; `CombatSituation.pendingMultipleDefensePenalty` and `CombatZonePicker`'s chips read the evaluation instead of their own arithmetic; `Situation.choices` / `announced` replace the Plänkler and manoeuvre bridges. Then step 4 (the authoring pipeline).
```

Also update the "Small chores" list: remove nothing, add "`reviewed: null` on all fifteen implemented entries: read each against its page and put your name and the date on it."

- [ ] **Step 6: Commit**

```bash
git add HesindionTests/RuleReachabilityTests.swift AGENTS.md CHANGELOG.md docs/plans/2026-09-14-rules-catalog-next-steps.md
git commit -m "test(rules): every implemented clause can fire, and the docs say where step 2 landed"
```

---

## What this plan leaves in Swift

The 31 definitions in `ModifierEngine.shared` after Task 15, all still reached by the union and named in their `rules:`: `encumbrance`; `state.betaeubung`, `state.furcht`, `state.paralyse`, `state.verwirrung`, `state.schmerz`, `state.fixiert`, `state.entrueckung`; `maneuverAT` (Finte, Vorstoß), `dualAttackPenaltyAT`, `offHandPenalty`; `schipDefenseBoost`, `mountedDodgePenalty`, `dualAttackDefense`, `offHandParry`, `twoHandedGripPA`; the eight ranged and the seven magic definitions; plus `DamageModifiers`' grip and Sturmangriff lines and `OpponentProfile.defenseModifiers`' Finte line. Their moves are listed in the next-steps doc (Task 16, Step 5).

## Follow-ups recorded during execution

Found by the per-task reviews, judged not to block the task they were found in, and not to be forgotten:

- **`RuleCatalog.bundled` is a `static let` over queries that return `[]` on a prepared-statement failure.** A transient SQLite failure at first access would leave the app with an empty catalog until relaunch, the silent-empty failure AGENTS.md already records for `allCombatTechniqueIds()`. The readers now log on failure (Task 4 fix round); a reloadable cache that retries after a failed load belongs with the first authoring batch, when the catalog has enough implemented entries for the symptom to matter.
- **`spellCasting` and `liturgyCasting` clauses can be written but never fire**: no `RuleTarget` case applies in those domains yet (the design's `spell`/`liturgy` targets arrive with the magic definitions' move). Until then `catalog.py` could reject a clause none of whose effect targets can apply in any of its domains; the same check would catch a `talent` target in a combat clause.
- **The Golgariten normalised JSON is hand-copied into both `test_catalog.py` and `RuleCatalogDecodingTests`.** A fixture file written by `entry_json()` and decoded by the Swift test would pin the cross-language contract instead of two copies that happen to agree.
- **`combinators` in `rule-vocabulary.json` is required by `load_vocabulary` and read by nobody**; `clauses`/`applies_with` on a non-`implemented` entry are accepted unvalidated and dropped from the database (demoting an entry to `todo` silently stops checking its clauses). Both are Python-side one-liners for the authoring-pipeline plan.
- **The two conditional rules the vocabulary cannot express** — `modifyRule` needs `add`, `set` or `multiply`; a `talent` target needs `talentId` — live in `catalog.py` and in the Swift decoder, not in `rule-vocabulary.json`. The authoring prompt (step 4) must state them.
- **`hero`- and `round`-span GM facts have no store.** `OpponentProfile.facts` holds `opponent` and `attack` spans; the design puts hero-span facts on `Hero` and round-span facts on `CombatSituation`. Until step 3 adds those, `gm.fact` with either span is refused at build and decode time rather than asked forever.
- **The Schicksalspunkt "Zustand ignorieren" and statuses.** The evaluator suppresses every `hero.state` predicate under it (statuses included, as `StateModifiers` did) except `belastung`. Whether a Status such as Liegend should survive the Schip is a rules question for the state batch.
- **Every roll now runs the whole evaluator, per SwiftUI render.** `ModifierEngine.evaluate(context:)` builds a full `Evaluation` (including the not-applied list over every owned trait) and keeps only `lines`; the first touch of `ModifierEngine.shared` loads all 2675 catalog rows into `RuleCatalog.bundled` on the main thread. Cheap today; measure before step 3 adds a second evaluation per screen, and let the views compute the `Evaluation` once and take `.lines` from it.
- **Breakdown line order during the migration.** Swift lines come first, then catalog lines sorted by rule id, so each move shifts a line to the end of the box; fully migrated, the order is `ADV_ < COND_ < GRW_ < SA_ < STATE_` — alphabetical accident. Step 3 gives `RuleLine` a display rank (states and Belastung first, then situational, then abilities) and re-records the affected snapshots once.
- **The Zonenaufschlag line no longer names the zone.** The Swift definition's label was "Trefferzone: Kopf"; the catalog line says "Zonenaufschlag". The zone was the informative half; step 3 re-attaches it when the views read the `Evaluation` (the `Situation` still carries `targetHitZone`).
- **`hero.fokusRule` and `opponent.state` are free strings in the vocabulary.** A typo (`trefferzonnen`, `überrascht`) validates and silently switches the rule off. `FokusRule` and `StateCatalog.all` are enumerable; export them as `enum:fokusRule` / `enum:state` in the next vocabulary change (a `RuleVocabulary` edit, re-export, `make rules-db`).
- **`modifier.trefferzone`** joins the orphaned strings (its `StringsCoverageTests` entry too); sweep with the others in Task 16.
- **The parry knows the opponent since Task 10's last fix round**: `CombatSituation.defenseModifiers(hero:isAusweichen:isOffHand:opponents:)` takes the roster, and both parry paths (the combat root and the weapon list) pass it, so `GRW_vorteilhaftePosition`'s +2 PA reaches a real parry.
- **An off toggle for a `gm.fact` is "not stated", by decision.** `OpponentProfile.advantageousPosition` writes `nil` when switched off, so `GRW_vorteilhaftePosition` reports `questionUnanswered` even when the opponent is stated mounted — the toggle *is* the question, and off means it has not been answered yes. Step 3 renders that reason as "nicht angegeben" next to the control, which is accurate; do not make an off control write `false` (it would have to be cleared per attack and would hide the difference between "asked and denied" and "never shown").
- **An attack-span fact can reach a defence.** `resetPerAttack()` runs when the *next* announcement appears, so a Vorteilhafte Position stated for swing N is still on the roster when a parry is rolled from the root before swing N+1, and the parry (which now sees the roster) takes its +2 PA. The number is arguably right; the span says otherwise. Step 3 decides: either a defence reads fight-span facts only, or `advantageousPosition` is not an attack-span fact (`isProne`/`isSurprised` have the same shape, no parry rule reads them yet).
- `WeaponStyleFlowTests.launchMountedParry()` waits `UITest.probeTimeout` (5 s) on what is now a hard assertion; `UITest.timeout` is the matching constant (fix in the Task 16 sweep).
- **UI-test parry navigation lives twice** (`WeaponStyleFlowTests.launchMountedParry()` and `DefenseModifierFlowTests.parry(_:expectingWeaponList:)`); extract to `UITestSupport.swift` in the Task 16 sweep. Breakdown rows get their own identifiers (`combat.breakdown.row.<ruleId>`) in step 3 so UI assertions stop matching bare values.
- **A parry still reads the main weapon.** `CombatSituation.defenseModifiers` sets no `loadoutName`, so `GRW_beengteUmgebung` on a Großschild or off-hand parry takes the main weapon's reach (as the deleted Swift definition did). The weapon list knows the parrying piece; step 3 passes it through.
- **Orphaned `source.*` strings.** Each move leaves its Swift label unused in `Strings.swift` (`source.multipleDefense`, `source.reach`, `source.vorteilhaft`, `source.golgariten` so far; `Hero.hasGolgaritenStil` is dead too); sweep them once in Task 16 rather than per task.
- **`loadout.weapon` sees melee weapons only.** `SA_923`'s `applies_with` lists CT_1 (Armbrüste) among its techniques, but `Situation.loadoutWeapon` reads `hero.meleeWeapons`, so a crossbow can never satisfy it — inert while the entry has defence clauses only; the ranged batch needs the predicate to see `rangedWeapons` too.
- **A `modifyRule … add` on a `per`-multiplied line eases every unit**, not the total (a future +1 on Wuchtschlag's AT penalty would be +1 per tier). No entry does this yet; pin the intended meaning with a fixture the first time one does.
- **`tiers: <n>` on an offer replaces the ownership cap rather than tightening it** (`maxTier` is `n`, not `min(n, owned)`): a `fixed(4)` offer lets a hero with tier II announce IV. Intended for `GRW_` manoeuvres nobody owns; say so on `OfferTiers` before an SA entry uses a number.
- `RuleCatalog.bundled` is MainActor-isolated by the project default; `RulesDatabase.shared` is reached from background queues. `nonisolated` when the evaluator is first called off the main actor.

## Self-review notes

- Spec coverage: §3 Situation (Task 1), Evaluation with lines / opponent lines / offers / questions / not-applied (Task 5; multipliers added), spans (Task 1, `FactSpan`), order of application (Task 5); §4 `GRW_*` entries (Tasks 7–10, 14), vocabulary as enums + JSON (Task 2), build failures (Task 3; reachability Task 16); §6 all nine fixture rows (Tasks 7–15); §7 step 2's union + disjointness test (Task 6), one definition per move, Zustände start with Liegend (Task 13), the cap as a catalog entry (Task 8, `byHand`). Not covered, by decision: the rest of §4's vocabulary, the remaining Swift definitions, `pendingMultipleDefensePenalty` and the zone chips reading the evaluation (step 3).
- Names used across tasks: `Situation.loadoutName` / `loadoutReach` / `loadoutWeapon` / `choices` / `announced` / `effectiveChoices` / `effectiveAnnounced` / `defencesThisRound` / `isWoundEffectProbe` / `talentId`; `OpponentProfile.states` / `facts` / `isOnFoot` / `advantageousPositionKey` / `opposingDeityKey`; `CombatSituation.chosenOptions`; `Hero.ownedRuleTier` / `ownedRuleIds`; `RuleCatalog.bundled` / `.implemented` / `.rules` / `.statuses`; `RulesDatabase.implementedRules()` / `allCatalogEntries()` / `catalogEntries(idPrefix:)`; `ModifierEngine.evaluation(_:)` / `.definitions` / `.catalog`; `ModifierDefinition.rules`; `DamageModifiers.lines(situation:)` / `multiplier(situation:)` / `rules`; `StateModifiers.ruleIds`; `StateMechanic.catalog`; `Evaluation.applied`; `NotApplied.Reason` cases; `RuleOffer.Shape`; `RuleQuestion(key:askedBy:)`.
