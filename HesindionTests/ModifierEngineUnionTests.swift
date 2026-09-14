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
