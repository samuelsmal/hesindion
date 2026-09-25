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
                report.add(s, .unsupported(ActionRunner.needs(s).map { "action: \($0.rawValue)" }), [], conflicts: conflicts)
                continue
            }
            let run = Matcher.run(s, engine: engine)
            let mismatches = run.mismatches + ActionRunner.mismatches(s, engine: engine)
            let verdict = Verdict.of(s, mismatches: mismatches, hits: run.hits, book: engine.book, conflicts: conflicts)
            report.add(s, verdict, mismatches, notes: run.notes, conflicts: conflicts)
            if verdict == .failed { failures.append((s, mismatches)) }
        }

        try report.write(to: Repo.url("build/rules/harness-report.json"))
        print(report.summary)
        report.fileLines.forEach { print($0) }
        for (s, mismatches) in failures {
            XCTFail("situation \(s.id) (\(s.file)):\n" + mismatches.map { "  - \($0)" }.joined(separator: "\n"))
        }
    }
}
