import XCTest
@testable import RulesEngine

/// Runs every compiled situation (`build/rules/situations.json`) through the engine and matches
/// it (spec §10.2, `Harness/Matcher.swift`). Writes `build/rules/harness-report.json` and prints
/// `harness: P passed, F failed, N pending, C conflict, U unsupported`. Only `failed` fails.
///
/// `RULES_FILES=kampfwerte,lebensenergie` keeps those situations files (Phase C goes one domain
/// at a time); `RULES_FILES=none` skips the harness; unset or `all` runs every file. A name that
/// is no situations file fails the test.
final class SituationsHarnessTests: XCTestCase {
    func testEverySituation() throws {
        let filter = FileFilter(ProcessInfo.processInfo.environment["RULES_FILES"])
        try XCTSkipIf(filter.isNone, "RULES_FILES=none")
        let rulesURL = Repo.url("build/rules/rules.json")
        let situationsURL = Repo.url("build/rules/situations.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: rulesURL.path), "run make rules-json")
        let all = try XCTUnwrap(try CompiledSituations.load(from: situationsURL), "run make rules-json")
        let engine = Engine(book: try RuleBook.load(from: rulesURL))

        if CheckAttributes.all.isEmpty { XCTFail("rules.db missing: run make rules-db") }
        for name in filter.unknown(among: all.situations.map(\.file)) {
            XCTFail("RULES_FILES names \(name), which is no situations file")
        }

        let listed = Self.conflicts(all)
        if listed == nil { XCTFail("MIGRATION.md has no section \"\(Conflicts.section)\"") }
        if listed?.isEmpty == true { XCTFail("MIGRATION.md's conflicts section lists no situation") }
        let conflicts = Set(listed ?? [])
        let missing = Self.expectationMissing(all)

        var report = HarnessReport()
        let known = Set(all.situations.map { ConflictRef(file: $0.file, id: $0.id) })
        report.conflictsUnknown = (listed ?? []).filter { !known.contains($0) }.map(\.description)
        var failures: [(CompiledSituation, [Mismatch])] = []
        for s in all.situations where filter.keeps(s.file) {
            let judged = Self.judge(s, engine: engine, conflicts: conflicts, expectationMissing: missing)
            switch judged.path {
            case .combat: report.combatRun.append(s.id)
            case .state: report.stateRun.append(s.id)
            case .queriesOnly: report.queriesCompared.append(s.id)
            case .unsupported, .check: break
            }
            report.add(s, judged.verdict, judged.mismatches, notes: judged.notes, conflicts: conflicts)
            if judged.verdict == .failed { failures.append((s, judged.mismatches)) }
        }

        report.stateChangeUnsupported = all.situations.filter { filter.keeps($0.file) && !ActionRunner.canRun($0)
            && !CombatRunner.canRun($0, book: engine.book) && !StateRunner.canRun($0, book: engine.book) && !$0.expect.isEmpty
            && Self.expectsStateChange($0) }.map(\.id)
        try report.write(to: Repo.url("build/rules/harness-report.json"))
        print(report.summary)
        report.fileLines.forEach { print($0) }
        for (s, mismatches) in failures {
            XCTFail("situation \(s.id) (\(s.file)):\n" + mismatches.map { "  - \($0)" }.joined(separator: "\n"))
        }
    }

    /// How a situation was run: as a hit or an attack's rolls (Task 27), as a sequence of actions
    /// (Task 28), its queries alone while its action part waits, not at all, or as a check.
    enum Path { case combat, state, queriesOnly, unsupported, check }

    struct Judged {
        var path: Path
        var verdict: Verdict
        var mismatches: [Mismatch]
        var notes: [String]
    }

    /// Runs one situation the way the harness does and gives its verdict (the harness test and
    /// the log round trip, Task 29, both use it).
    static func judge(_ s: CompiledSituation, engine: Engine, conflicts: Set<ConflictRef>,
                      expectationMissing: Set<ConflictRef> = []) -> Judged {
        func verdict(_ mismatches: [Mismatch], _ hits: [OpenHit]) -> Verdict {
            Verdict.of(s, mismatches: mismatches, hits: hits, book: engine.book, conflicts: conflicts,
                       expectationMissing: expectationMissing)
        }
        // Ruling R73: a situation that expects nothing at all (trefferzonen TZ.9–TZ.11: dice, no
        // expect key) is the shape "no expectation", never a pass.
        if s.expect.isEmpty, s.expectSituation.isEmpty, s.sequence.isEmpty {
            let shape = Mismatch.shape("no expectation", "the situation states no expectation")
            return Judged(path: .unsupported, verdict: verdict([shape], []), mismatches: [shape], notes: [])
        }
        // Task 27: a hit on the hero, or the rolls of an attack.
        if CombatRunner.canRun(s, book: engine.book) {
            let combat = CombatRunner.run(s, engine: engine)
            var run = Matcher.run(s, engine: engine, hit: combat.view)
            run.hits = (run.hits + Matcher.openRulings(in: combat.breakdowns)).distinct()
            let mismatches = run.mismatches + combat.mismatches
            return Judged(path: .combat, verdict: verdict(mismatches, run.hits), mismatches: mismatches,
                          notes: run.notes + combat.notes)
        }
        // Task 28: a sequence of actions, or the action a situation expecting events implies.
        if !ActionRunner.canRun(s), StateRunner.canRun(s, book: engine.book) {
            let state = StateRunner.run(s, engine: engine)
            var run = Matcher.run(s, engine: engine, hit: state.view)
            run.hits = (run.hits + Matcher.openRulings(in: state.breakdowns)).distinct()
            let mismatches = run.mismatches + state.mismatches
            return Judged(path: .state, verdict: verdict(mismatches, run.hits), mismatches: mismatches,
                          notes: run.notes + state.notes)
        }
        guard ActionRunner.canRun(s) else {
            // The action part waits (Tasks 27–28); the query expectations run now (Task 26 extra 8).
            let needs = ActionRunner.needs(s).map { "action: \($0.rawValue)" }
            // R50: a situation expecting a state gained or cleared is described after its action.
            if !s.expect.isEmpty && !expectsStateChange(s) {
                let run = Matcher.run(s, engine: engine, onlyQueries: true)
                if run.mismatches.contains(where: { $0.kind != .unsupportedShape }) {
                    return Judged(path: .queriesOnly, verdict: verdict(run.mismatches, run.hits),
                                  mismatches: run.mismatches, notes: run.notes)
                }
                let shapes = run.mismatches.compactMap { $0.shape.map { "shape: \($0)" } }.distinct()
                return Judged(path: .queriesOnly, verdict: .unsupported(needs + shapes), mismatches: run.mismatches,
                              notes: run.notes)
            }
            return Judged(path: .unsupported, verdict: .unsupported(needs), mismatches: [], notes: [])
        }
        let check = ActionRunner.run(s, engine: engine)
        var run = Matcher.run(s, engine: engine, view: check?.view)
        run.hits = (run.hits + Matcher.openRulings(in: check?.breakdowns ?? [])).distinct()
        let mismatches = run.mismatches + (check?.mismatches ?? [])
        return Judged(path: .check, verdict: verdict(mismatches, run.hits), mismatches: mismatches,
                      notes: run.notes + (check?.notes ?? []))
    }

    /// MIGRATION.md's conflicts section, parsed against the situations' order; nil when the
    /// section is missing.
    static func conflicts(_ all: CompiledSituations) -> [ConflictRef]? {
        let order = Dictionary(grouping: all.situations, by: \.file).mapValues { $0.map(\.id) }
        let migration = (try? String(contentsOf: Repo.url("docs/rules-rework/examples/MIGRATION.md"), encoding: .utf8)) ?? ""
        return Conflicts.parse(migration, order: order)
    }

    /// R73: the listed conflicts whose listed reason is that the expectation is missing.
    static func expectationMissing(_ all: CompiledSituations) -> Set<ConflictRef> {
        let order = Dictionary(grouping: all.situations, by: \.file).mapValues { $0.map(\.id) }
        let migration = (try? String(contentsOf: Repo.url("docs/rules-rework/examples/MIGRATION.md"), encoding: .utf8)) ?? ""
        return Conflicts.expectationMissing(migration, order: order)
    }

    /// R50: whether `s` expects a `gained` or `cleared` event, at the top or in a step: its query
    /// expectations then describe the state after that event.
    static func expectsStateChange(_ s: CompiledSituation) -> Bool {
        let events = (s.expectSituation["events"]?.arrayValue ?? [])
            + s.sequence.flatMap { $0.objectValue?["expect"]?.objectValue?["events"]?.arrayValue ?? [] }
        return events.contains { $0.objectValue.map { $0["gained"] != nil || $0["cleared"] != nil } ?? false }
    }
}
