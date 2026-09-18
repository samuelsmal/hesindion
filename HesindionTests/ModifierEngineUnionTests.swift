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

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
    }

    /// Core rules the catalog has no entry for yet. Every id here is one a
    /// fixture task of this migration will author: when its entry lands and
    /// the Swift definition goes, its id comes off this list, so the list only
    /// ever shrinks. The second assertion below enforces that — an id that has
    /// an entry is no longer "to be authored" and must not be excused here.
    private let stillToBeAuthored: Set<String> = []

    /// The migration invariant. Every Swift definition names the rules it
    /// implements; once a catalog entry is `implemented`, the definition must
    /// be gone, or the line would be counted twice.
    func testNoRuleIsProducedByBothSides() throws {
        try requireDatabase()
        let implemented = Set(RuleCatalog.bundled.implemented.map(\.id))
        for definition in ModifierEngine.shared.definitions {
            let both = implemented.intersection(definition.rules)
            XCTAssertTrue(both.isEmpty, "\(definition.id) still implements \(both.sorted()) in Swift")
        }
        XCTAssertTrue(implemented.intersection(DamageModifiers.rules).isEmpty, "DamageModifiers still implements \(implemented.intersection(DamageModifiers.rules).sorted()) in Swift")
    }

    /// The invariant above is only as good as the ids it compares. A mistyped
    /// one would never intersect anything and would pass forever, so every id
    /// a definition names must be a real catalog entry — or be on the short
    /// list of core rules this migration has yet to author.
    func testEveryRuleADefinitionNamesExistsInTheCatalogOrIsStillToBeAuthored() throws {
        try requireDatabase()
        let known = RuleCatalog.bundled.statuses
        for definition in ModifierEngine.shared.definitions {
            for id in definition.rules where known[id] == nil {
                XCTAssertTrue(stillToBeAuthored.contains(id),
                              "\(definition.id) names \(id), which is not a catalog entry")
            }
        }
        for id in DamageModifiers.rules where known[id] == nil {
            XCTAssertTrue(stillToBeAuthored.contains(id),
                          "DamageModifiers names \(id), which is not a catalog entry")
        }
        for id in stillToBeAuthored.sorted() {
            XCTAssertNil(known[id], "\(id) has a catalog entry now; take it off stillToBeAuthored")
        }
    }

    /// The other direction. A `byHand` entry pointing into one of the engine's
    /// modifier files says "this rule is that definition"; the definition must
    /// say so too, or the two records of the same fact have drifted.
    func testEveryByHandPointerIntoAModifierFileIsClaimedByADefinition() throws {
        try requireDatabase()
        let claimed = Set(ModifierEngine.shared.definitions.flatMap(\.rules))
        for entry in RulesDatabase.shared.catalogEntries(status: .byHand) {
            guard let pointer = entry.pointer,
                  pointer.file.hasPrefix("Hesindion/Engine/"),
                  pointer.file.hasSuffix("Modifiers.swift") else { continue }
            XCTAssertTrue(claimed.contains(entry.id),
                          "\(entry.id) points at \(pointer.file):\(pointer.symbol), but no definition names it")
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

    /// Every definition the app ships, not one file's worth: `.damage` has no
    /// `CheckDomain`, so nothing in Swift can reach it and TP lines can only
    /// ever come from the catalog.
    func testTheDamageDomainHasNoSwiftDefinitions() {
        let engine = ModifierEngine(modifiers: ModifierEngine.shared.definitions, catalog: RuleCatalog(rules: []))
        XCTAssertTrue(engine.evaluate(context: Situation(hero: hero, domain: .damage)).isEmpty)
    }
}
