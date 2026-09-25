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

        let order = Dictionary(grouping: all.situations, by: \.file).mapValues { $0.map(\.id) }
        let migration = (try? String(contentsOf: Repo.url("docs/rules-rework/examples/MIGRATION.md"), encoding: .utf8)) ?? ""
        let listed = Conflicts.parse(migration, order: order)
        if listed == nil { XCTFail("MIGRATION.md has no section \"\(Conflicts.section)\"") }
        if listed?.isEmpty == true { XCTFail("MIGRATION.md's conflicts section lists no situation") }
        let conflicts = Set(listed ?? [])

        var report = HarnessReport()
        let known = Set(all.situations.map { ConflictRef(file: $0.file, id: $0.id) })
        report.conflictsUnknown = (listed ?? []).filter { !known.contains($0) }.map(\.description)
        var failures: [(CompiledSituation, [Mismatch])] = []
        for s in all.situations where filter.keeps(s.file) {
            guard ActionRunner.canRun(s) else {
                // The action part waits (Tasks 27–28); the query expectations run now (Task 26 extra 8).
                let needs = ActionRunner.needs(s).map { "action: \($0.rawValue)" }
                // R50: a situation expecting a state gained or cleared is described after its action.
                if !s.expect.isEmpty && !Self.expectsStateChange(s) {
                    report.queriesCompared.append(s.id)
                    let run = Matcher.run(s, engine: engine, onlyQueries: true)
                    if run.mismatches.contains(where: { $0.kind != .unsupportedShape }) {
                        let verdict = Verdict.of(s, mismatches: run.mismatches, hits: run.hits, book: engine.book, conflicts: conflicts)
                        report.add(s, verdict, run.mismatches, notes: run.notes, conflicts: conflicts)
                        if verdict == .failed { failures.append((s, run.mismatches)) }
                        continue
                    }
                    let shapes = run.mismatches.compactMap { $0.shape.map { "shape: \($0)" } }.distinct()
                    report.add(s, .unsupported(needs + shapes), run.mismatches, notes: run.notes, conflicts: conflicts)
                    continue
                }
                report.add(s, .unsupported(needs), [], conflicts: conflicts)
                continue
            }
            let check = ActionRunner.run(s, engine: engine)
            var run = Matcher.run(s, engine: engine, view: check?.view)
            run.hits = (run.hits + Matcher.openRulings(in: check?.breakdowns ?? [])).distinct()
            let mismatches = run.mismatches + (check?.mismatches ?? [])
            let verdict = Verdict.of(s, mismatches: mismatches, hits: run.hits, book: engine.book, conflicts: conflicts)
            report.add(s, verdict, mismatches, notes: run.notes + (check?.notes ?? []), conflicts: conflicts)
            if verdict == .failed { failures.append((s, mismatches)) }
        }

        report.stateChangeUnsupported = all.situations.filter { filter.keeps($0.file) && !ActionRunner.canRun($0)
            && !$0.expect.isEmpty && Self.expectsStateChange($0) }.map(\.id)
        try report.write(to: Repo.url("build/rules/harness-report.json"))
        print(report.summary)
        report.fileLines.forEach { print($0) }
        for (s, mismatches) in failures {
            XCTFail("situation \(s.id) (\(s.file)):\n" + mismatches.map { "  - \($0)" }.joined(separator: "\n"))
        }
    }

    /// R50: whether `s` expects a `gained` or `cleared` event, at the top or in a step: its query
    /// expectations then describe the state after that event.
    static func expectsStateChange(_ s: CompiledSituation) -> Bool {
        let events = (s.expectSituation["events"]?.arrayValue ?? [])
            + s.sequence.flatMap { $0.objectValue?["expect"]?.objectValue?["events"]?.arrayValue ?? [] }
        return events.contains { $0.objectValue.map { $0["gained"] != nil || $0["cleared"] != nil } ?? false }
    }
}
