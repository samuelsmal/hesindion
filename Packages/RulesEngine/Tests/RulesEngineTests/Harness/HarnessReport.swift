import Foundation
@testable import RulesEngine

// What the harness makes of each situation, the MIGRATION conflicts list, the `RULES_FILES`
// filter, and `build/rules/harness-report.json`.

/// One situation's outcome. Only `failed` fails the test.
enum Verdict: Equatable {
    case passed
    case failed
    /// It mismatched, and every mismatch is explained by these open rulings of its static
    /// `pending` list, met by its run, on live effects (R41, R46).
    case pending([String])
    /// It mismatched and is listed in MIGRATION's "Expectation conflicts for the owner" (R43),
    /// and (when a snapshot is checked) every mismatch is one of its recorded fingerprints (R78).
    case conflict
    /// It needs the action layer (`action: <need>`), or its only mismatches are unsupported
    /// shapes (`shape: <tag>`, R42).
    case unsupported([String])

    var passesTheTest: Bool { self != .failed }

    /// A match passes. Otherwise, in order: only unsupported shapes (R42, and R69 for a listed
    /// conflict); a listed conflict (R43); pending when open rulings it hit explain every mismatch (R41, R46); else failed.
    ///
    /// Ruling R78: with a `snapshot`, a listed conflict that has a mismatch outside its recorded
    /// fingerprints is failed (a new mismatch inside a listed situation is a regression, not the
    /// listed conflict). nil checks nothing (record mode, the log round trip).
    static func of(_ s: CompiledSituation, mismatches: [Mismatch], hits: [OpenHit], book: RuleBook?,
                   conflicts: Set<ConflictRef>, expectationMissing: Set<ConflictRef> = [],
                   snapshot: ConflictSnapshot? = nil) -> Verdict {
        guard !mismatches.isEmpty else { return .passed }
        let real = mismatches.filter { $0.kind != .unsupportedShape }
        let ref = ConflictRef(file: s.file, id: s.id)
        let conflict: Verdict = snapshot.map { $0.diff(ref, mismatches).new.isEmpty } == false ? .failed : .conflict
        // Ruling R73: a listed conflict whose listed reason is a missing expectation is a conflict
        // on the shape "no expectation".
        if real.isEmpty, mismatches.allSatisfy({ $0.shape == "no expectation" }), conflicts.contains(ref),
           expectationMissing.contains(ref) { return conflict }
        // Ruling R69: a listed conflict is a conflict when a comparable part mismatches; with
        // unsupported shapes alone it stays unsupported.
        if real.isEmpty { return .unsupported(mismatches.compactMap { $0.shape.map { "shape: \($0)" } }.distinct()) }
        if conflicts.contains(ref) { return conflict }
        let explaining = Explainer.explaining(hits, real, pending: s.pending, book: book, situation: s.engineSituation)
        return explaining.map { .pending($0) } ?? .failed
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

    /// Ruling R73: the situations named by an entry of the section whose reason says that the
    /// expectation is missing (the phrase "expectation missing").
    static func expectationMissing(_ markdown: String, order: [String: [String]]) -> Set<ConflictRef> {
        guard let start = markdown.range(of: section) else { return [] }
        let rest = markdown[start.upperBound...]
        let body = rest.range(of: "\n## ").map { rest[..<$0.lowerBound] } ?? rest
        var out: Set<ConflictRef> = []
        for entry in body.components(separatedBy: "\n- ") where entry.contains("expectation missing") {
            out.formUnion(parse(section + "\n- " + entry, order: order) ?? [])
        }
        return out
    }

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

/// Ruling R78: one mismatch of a listed conflict, reduced to what stays put while the engine
/// does: its query, its step (`step N:` at the head of the detail), its kind and, for an
/// unsupported shape, the shape's tag. No numbers: another value in the same place is the same
/// fingerprint, a mismatch of another kind or in another query is a new one.
struct ConflictFingerprint: Codable, Hashable, Comparable, CustomStringConvertible {
    var query: String?
    var step: Int?
    var kind: String
    var shape: String?

    init(query: String?, step: Int?, kind: String, shape: String? = nil) {
        self.query = query; self.step = step; self.kind = kind; self.shape = shape
    }

    init(_ m: Mismatch) {
        var step: Int?
        if m.detail.hasPrefix("step "), let n = Int(m.detail.dropFirst(5).prefix { $0.isNumber }),
           m.detail.dropFirst(5 + String(n).count).hasPrefix(":") { step = n }
        self.init(query: m.query, step: step, kind: m.kind.rawValue, shape: m.shape)
    }

    var description: String {
        (query.map { "\($0): " } ?? "") + (step.map { "step \($0): " } ?? "") + kind + (shape.map { " \($0)" } ?? "")
    }

    static func < (a: Self, b: Self) -> Bool { a.description < b.description }
}

/// Ruling R78: the committed snapshot of every listed conflict's fingerprints
/// (`docs/rules-rework/examples/conflict-fingerprints.json`, keyed `"<file> <id>"`). The harness
/// checks each listed conflict against it; `RECORD_CONFLICT_FINGERPRINTS=1` rewrites it from the run.
struct ConflictSnapshot: Codable, Equatable {
    static let path = "docs/rules-rework/examples/conflict-fingerprints.json"

    var conflicts: [String: [ConflictFingerprint]] = [:]

    /// A listed conflict's run against its snapshot: fingerprints it has that the snapshot does
    /// not (a failure) and fingerprints the snapshot has that it no longer shows (reported).
    struct Diff: Equatable {
        var new: [ConflictFingerprint]
        var gone: [ConflictFingerprint]
    }

    func diff(_ ref: ConflictRef, _ mismatches: [Mismatch]) -> Diff {
        let recorded = Set(conflicts[ref.description] ?? [])
        let now = Set(mismatches.map(ConflictFingerprint.init))
        return Diff(new: now.subtracting(recorded).sorted(), gone: recorded.subtracting(now).sorted())
    }

    /// Snapshot entries of the run files (`files`; nil: every file) whose situation is no longer listed.
    func unlisted(_ listed: Set<ConflictRef>, files: Set<String>?) -> [String] {
        let names = Set(listed.map(\.description))
        return conflicts.keys.filter { key in
            !names.contains(key) && files.map { $0.contains(String(key.split(separator: " ").first ?? "")) } ?? true
        }.sorted()
    }

    /// Record mode: every run listed conflict's fingerprints (`run`, empty when it passes, which
    /// drops it); entries of the run files that are no longer listed are dropped; other files'
    /// entries are kept (`RULES_FILES`).
    mutating func record(_ run: [ConflictRef: [Mismatch]], listed: Set<ConflictRef>, files: Set<String>?) {
        for key in unlisted(listed, files: files) { conflicts[key] = nil }
        for (ref, mismatches) in run {
            let prints = Set(mismatches.map(ConflictFingerprint.init)).sorted()
            conflicts[ref.description] = prints.isEmpty ? nil : prints
        }
    }

    static func load(from url: URL) throws -> ConflictSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(ConflictSnapshot.self, from: Data(contentsOf: url))
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(0x0A)
        try data.write(to: url)
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
    /// R78: listed conflicts with mismatches outside their snapshot (failed), by `file id`.
    var conflictsGrown: [String: [String]] = [:]
    /// R78: listed conflicts whose snapshot names fingerprints that no longer occur (reported:
    /// re-record the snapshot so it stays honest), by `file id`.
    var conflictsShrunk: [String: [String]] = [:]
    /// R78: snapshot entries of situations that are no longer listed.
    var fingerprintsUnlisted: [String] = []
    /// Situations whose action part cannot run yet but whose query expectations ran and were
    /// compared (Task 26 extra 8): a mismatch there decides the verdict.
    var queriesCompared: [String] = []
    /// Unsupported situations with query expectations left uncompared because they expect a
    /// `gained` / `cleared` event (R50).
    var stateChangeUnsupported: [String] = []
    /// Situations run as a hit on the hero or as the rolls of an attack (Task 27, `CombatRunner`);
    /// their queries follow the before/after rule.
    var combatRun: [String] = []
    /// Situations run as a sequence of actions or with the action they imply (Task 28,
    /// `StateRunner`); their queries follow the before/after rule.
    var stateRun: [String] = []
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

    /// R78: records a listed conflict's diff against the snapshot.
    mutating func fingerprints(_ ref: ConflictRef, _ diff: ConflictSnapshot.Diff) {
        if !diff.new.isEmpty { conflictsGrown[ref.description] = diff.new.map(\.description) }
        if !diff.gone.isEmpty { conflictsShrunk[ref.description] = diff.gone.map(\.description) }
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
