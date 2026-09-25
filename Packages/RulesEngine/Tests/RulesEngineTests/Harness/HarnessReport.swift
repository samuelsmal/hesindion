import Foundation
@testable import RulesEngine

// What the harness makes of each situation, the MIGRATION conflicts list, the `RULES_FILES`
// filter, and `build/rules/harness-report.json`.

/// One situation's outcome. Only `failed` fails the test.
enum Verdict: Equatable {
    case passed
    case failed
    /// It mismatched, and these open rulings of its static `pending` list, met by its run, could
    /// explain a mismatch (R41).
    case pending([String])
    /// It mismatched and is listed in MIGRATION's "Expectation conflicts for the owner" (R43).
    case conflict
    /// It needs the action layer (`action: <need>`), or its only mismatches are unsupported
    /// shapes (`shape: <tag>`, R42).
    case unsupported([String])

    var passesTheTest: Bool { self != .failed }

    /// A match passes. Otherwise, in order: a listed conflict (R43); only unsupported shapes
    /// (R42); pending when an open ruling it hit explains a mismatch (R41); else failed.
    static func of(_ s: CompiledSituation, mismatches: [Mismatch], hits: [OpenHit], book: RuleBook?,
                   conflicts: Set<ConflictRef>) -> Verdict {
        guard !mismatches.isEmpty else { return .passed }
        if conflicts.contains(ConflictRef(file: s.file, id: s.id)) { return .conflict }
        let real = mismatches.filter { $0.kind != .unsupportedShape }
        if real.isEmpty { return .unsupported(mismatches.compactMap { $0.shape.map { "shape: \($0)" } }.distinct()) }
        let explaining = Explainer.explaining(hits, real, pending: s.pending, book: book)
        return explaining.isEmpty ? .failed : .pending(explaining)
    }
}

/// A situation named in MIGRATION's conflicts section: its file and id.
struct ConflictRef: Hashable, Encodable, CustomStringConvertible {
    var file: String
    var id: String
    var description: String { "\(file) \(id)" }
}

/// The situations MIGRATION.md's "Expectation conflicts for the owner" lists: every id after a
/// `<file>.yaml` (`situations/boronmir-sf.yaml 14.13`, `kampfsituationen.yaml 17.3, 17.22`),
/// ranges (`15.4–15.8`) expanded in the file's order.
enum Conflicts {
    static let section = "## Expectation conflicts for the owner"

    /// nil when the section is missing.
    static func parse(_ markdown: String, order: [String: [String]]) -> [ConflictRef]? {
        guard let start = markdown.range(of: section) else { return nil }
        let rest = markdown[start.upperBound...]
        let body = rest.range(of: "\n## ").map { rest[..<$0.lowerBound] } ?? rest
        let id = #"(?:[A-Z]+\.?)?\d+(?:\.\d+)*[a-z]?"#
        let list = try! NSRegularExpression(pattern: #"([A-Za-z0-9_-]+\.yaml)((?:\s*,?\s*"# + id + "(?:[–-]" + id + ")?)+)")
        let one = try! NSRegularExpression(pattern: "(" + id + ")(?:[–-](" + id + "))?")
        let text = String(body)
        var out: [ConflictRef] = []
        func add(_ file: String, _ x: String) {
            let ref = ConflictRef(file: file, id: x)
            if !out.contains(ref) { out.append(ref) }
        }
        for m in list.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            let file = String(text[Range(m.range(at: 1), in: text)!])
            let ids = String(text[Range(m.range(at: 2), in: text)!])
            for r in one.matches(in: ids, range: NSRange(ids.startIndex..., in: ids)) {
                let first = String(ids[Range(r.range(at: 1), in: ids)!])
                guard let lastRange = Range(r.range(at: 2), in: ids) else { add(file, first); continue }
                let last = String(ids[lastRange])
                if let ids = order[file], let a = ids.firstIndex(of: first), let b = ids.firstIndex(of: last), a <= b {
                    ids[a...b].forEach { add(file, $0) }
                } else {
                    add(file, first); add(file, last)
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

    /// The names asked for that are no situations file (a typo), sorted.
    func unknown(among files: [String]) -> [String] {
        guard let names, !isNone else { return [] }
        return names.subtracting(files.map(Self.stem)).sorted()
    }

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
        /// The open rulings that explain it (R41).
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

    var summary = HarnessReport.line(0, 0, 0, 0, 0)
    var files: [String: Counts] = [:]
    var passed: [String] = []
    var failed: [Entry] = []
    var pending: [Pending] = []
    var conflict: [Entry] = []
    var unsupported: [String] = []
    /// Why each unsupported situation is: `action: <need>` or `shape: <tag>`.
    var unsupportedWhy: [String: [String]] = [:]
    /// Per situation: what matched with a note (a prose reason, R42).
    var notes: [String: [String]] = [:]
    /// Passing situations with a non-empty static pending list: "passes with ruling open".
    var passesWithRulingOpen: [Open] = []
    /// Listed conflicts that pass.
    var conflictsPassing: [String] = []
    /// Listed conflicts that are no compiled situation (`file id`).
    var conflictsUnknown: [String] = []
    /// How often each mismatch kind is the first of a failed situation, and in all of them.
    var firstMismatchKinds: [String: Int] = [:]
    var mismatchKinds: [String: Int] = [:]

    mutating func add(_ s: CompiledSituation, _ verdict: Verdict, _ mismatches: [Mismatch], notes: [String] = [],
                      conflicts: Set<ConflictRef>) {
        let text = mismatches.map(\.description)
        if !notes.isEmpty { self.notes[s.id] = notes }
        var counts = files[s.file] ?? Counts()
        switch verdict {
        case .passed:
            counts.passed += 1
            passed.append(s.id)
            if !s.pending.isEmpty { passesWithRulingOpen.append(Open(id: s.id, pending: s.pending)) }
            if conflicts.contains(ConflictRef(file: s.file, id: s.id)) { conflictsPassing.append(s.id) }
        case .failed:
            counts.failed += 1
            failed.append(Entry(id: s.id, file: s.file, mismatches: text))
            if let first = mismatches.first(where: { $0.kind != .unsupportedShape }) ?? mismatches.first {
                firstMismatchKinds[first.kind.rawValue, default: 0] += 1
            }
            for m in mismatches { mismatchKinds[m.kind.rawValue, default: 0] += 1 }
        case .pending(let rulings):
            counts.pending += 1
            pending.append(Pending(id: s.id, file: s.file, rulings: rulings, mismatches: text))
        case .conflict:
            counts.conflict += 1
            conflict.append(Entry(id: s.id, file: s.file, mismatches: text))
        case .unsupported(let why):
            counts.unsupported += 1
            unsupported.append(s.id)
            unsupportedWhy[s.id] = why
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
