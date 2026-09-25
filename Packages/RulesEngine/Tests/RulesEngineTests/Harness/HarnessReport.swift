import Foundation
@testable import RulesEngine

// What the harness makes of each situation, the MIGRATION conflicts list, the `RULES_FILES`
// filter, and `build/rules/harness-report.json`.

/// One situation's outcome. Only `failed` fails the test.
enum Verdict: Equatable {
    case passed
    case failed
    /// It mismatched, and its run hit these open rulings of its static `pending` list (R32).
    case pending([String])
    /// It mismatched and is listed in MIGRATION's "Expectation conflicts for the owner".
    case conflict
    /// It needs the action layer (`ActionRunner.canRun` is false).
    case unsupported

    var passesTheTest: Bool { self != .failed }

    /// R32 first (a mismatch is pending only when the run hit an open ruling of the situation's
    /// static list), then the conflicts list, else failed. A match passes.
    static func of(_ s: CompiledSituation, mismatches: [Mismatch], hit: Set<String>, conflicts: Set<String>) -> Verdict {
        guard !mismatches.isEmpty else { return .passed }
        let open = Set(s.pending).intersection(hit)
        if !open.isEmpty { return .pending(open.sorted()) }
        return conflicts.contains(s.id) ? .conflict : .failed
    }
}

/// The situation ids that MIGRATION.md's "Expectation conflicts for the owner" lists: every id
/// after a `<file>.yaml` (`situations/boronmir-sf.yaml 14.13`, `kampfsituationen.yaml 17.3, 17.22`),
/// ranges (`15.4–15.8`) expanded in the file's order.
enum Conflicts {
    static let section = "## Expectation conflicts for the owner"

    static func parse(_ markdown: String, order: [String: [String]]) -> [String] {
        guard let start = markdown.range(of: section) else { return [] }
        let rest = markdown[start.upperBound...]
        let body = rest.range(of: "\n## ").map { rest[..<$0.lowerBound] } ?? rest
        let id = #"(?:[A-Z]+\.?)?\d+(?:\.\d+)*[a-z]?"#
        let list = try! NSRegularExpression(pattern: #"([A-Za-z0-9_-]+\.yaml)((?:\s*,?\s*"# + id + "(?:[–-]" + id + ")?)+)")
        let one = try! NSRegularExpression(pattern: "(" + id + ")(?:[–-](" + id + "))?")
        let text = String(body)
        var out: [String] = []
        func add(_ x: String) { if !out.contains(x) { out.append(x) } }
        for m in list.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            let file = String(text[Range(m.range(at: 1), in: text)!])
            let ids = String(text[Range(m.range(at: 2), in: text)!])
            for r in one.matches(in: ids, range: NSRange(ids.startIndex..., in: ids)) {
                let first = String(ids[Range(r.range(at: 1), in: ids)!])
                guard let lastRange = Range(r.range(at: 2), in: ids) else { add(first); continue }
                let last = String(ids[lastRange])
                if let ids = order[file], let a = ids.firstIndex(of: first), let b = ids.firstIndex(of: last), a <= b {
                    ids[a...b].forEach(add)
                } else {
                    add(first); add(last)
                }
            }
        }
        return out
    }
}

/// `RULES_FILES=kampfwerte,lebensenergie`: the situations files a run keeps. Unset, empty or
/// `all` keeps every file; `none` keeps none.
struct FileFilter {
    /// nil: every file.
    let names: Set<String>?

    init(_ raw: String?) {
        let t = raw?.trimmingCharacters(in: .whitespaces) ?? ""
        names = t.isEmpty || t == "all" ? nil
            : Set(t.split(separator: ",").map { Self.stem(String($0).trimmingCharacters(in: .whitespaces)) })
    }

    var isNone: Bool { names == ["none"] }

    func keeps(_ file: String) -> Bool { names.map { $0.contains(Self.stem(file)) } ?? true }

    static func stem(_ file: String) -> String {
        let last = file.split(separator: "/").last.map(String.init) ?? file
        return last.hasSuffix(".yaml") ? String(last.dropLast(5)) : last
    }
}

/// `build/rules/harness-report.json`.
struct HarnessReport: Encodable {
    struct Entry: Encodable {
        var id: String
        var file: String
        var mismatches: [String]
    }
    struct Pending: Encodable {
        var id: String
        var file: String
        /// The open rulings the run hit (R32).
        var rulings: [String]
        var mismatches: [String]
    }
    struct Open: Encodable {
        var id: String
        /// Its static pending list: it passes with these rulings still open.
        var pending: [String]
    }
    struct Counts: Encodable {
        var passed = 0, failed = 0, pending = 0, conflict = 0, unsupported = 0
    }

    var summary = ""
    var files: [String: Counts] = [:]
    var passed: [String] = []
    var failed: [Entry] = []
    var pending: [Pending] = []
    var conflict: [Entry] = []
    var unsupported: [String] = []
    /// Each unsupported situation's needs of the action layer.
    var unsupportedNeeds: [String: [ActionRunner.Need]] = [:]
    /// Passing situations with a non-empty static pending list: "passes with ruling open".
    var passesWithRulingOpen: [Open] = []
    /// Listed conflicts that pass.
    var conflictsPassing: [String] = []
    /// Listed conflict ids that are no compiled situation.
    var conflictsUnknown: [String] = []
    /// How often each mismatch kind is the first of a failed situation, and in all of them.
    var firstMismatchKinds: [String: Int] = [:]
    var mismatchKinds: [String: Int] = [:]

    mutating func add(_ s: CompiledSituation, _ verdict: Verdict, _ mismatches: [Mismatch], conflicts: Set<String>) {
        let text = mismatches.map(\.description)
        var counts = files[s.file] ?? Counts()
        switch verdict {
        case .passed:
            counts.passed += 1
            passed.append(s.id)
            if !s.pending.isEmpty { passesWithRulingOpen.append(Open(id: s.id, pending: s.pending)) }
            if conflicts.contains(s.id) { conflictsPassing.append(s.id) }
        case .failed:
            counts.failed += 1
            failed.append(Entry(id: s.id, file: s.file, mismatches: text))
            if let first = mismatches.first { firstMismatchKinds[first.kind.rawValue, default: 0] += 1 }
            for m in mismatches { mismatchKinds[m.kind.rawValue, default: 0] += 1 }
        case .pending(let rulings):
            counts.pending += 1
            pending.append(Pending(id: s.id, file: s.file, rulings: rulings, mismatches: text))
        case .conflict:
            counts.conflict += 1
            conflict.append(Entry(id: s.id, file: s.file, mismatches: text))
        case .unsupported:
            counts.unsupported += 1
            unsupported.append(s.id)
            unsupportedNeeds[s.id] = ActionRunner.needs(s)
        }
        files[s.file] = counts
        summary = Self.line(passed.count, failed.count, pending.count, conflict.count, unsupported.count)
    }

    static func line(_ p: Int, _ f: Int, _ n: Int, _ c: Int, _ u: Int) -> String {
        "harness: \(p) passed, \(f) failed, \(n) pending, \(c) conflict, \(u) unsupported"
    }

    /// One line per situations file, in name order.
    var fileLines: [String] {
        files.keys.sorted().map { f in
            let c = files[f]!
            return "  \(f): \(c.passed) passed, \(c.failed) failed, \(c.pending) pending, \(c.conflict) conflict, \(c.unsupported) unsupported"
        }
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url)
    }
}
