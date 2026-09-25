import Foundation

/// One log entry as a situations-file draft (spec §8, §10.1): the entry's hero, facts and dice as
/// input, what the engine computed as `expect`, the player's note as `appToday`. Correcting the
/// numbers that were wrong turns the table moment into a regression test.
///
/// The draft is in the format rulec accepts (`scripts/rulec/situations.py`):
/// - `hero`: the owned rules by map (`abilities`, `advantages`, `disadvantages`, `conditions`,
///   `states`, by the id's prefix; any other id under `abilities`, since rulec merges the maps),
///   an entry with an option as `{level, sid, sid2}`; the sheet facts `attr.` / `ktw.` / `fw.` as
///   `attributes`, `techniques`, `talents`, the sheet's other facts as `sheet`; the base values as `values`, with the LE and AsP pools
///   as `leCurrent` / `leMax` / `aspCurrent` / `aspMax` (the harness fills the pools from them);
/// - each fact in its owner's section: `choose` (player), `ally` (player, `ally.*`), `gm`,
///   `opponent` (gm, `opponent.*`), `round` (these three without their prefix), `loadout` (without `loadout.` where that name is no loadout fact of its own; an
///   item's state as `item.<instance>.<field>`), and roll facts as the `rolls` mapping when there
///   are no dice;
/// - `rolls`: the dice;
/// - `expect`, keyed by query: `total` (with a derived base, the result: the harness's bridge 2),
///   `result`, and each shown line with a clause as `from`, `value` (after the step for `set`,
///   `levelAs`, `replaced` and a scale step), `via` and `ruling`; the shown lines no clause gave
///   (a sheet base, a modifier typed in) as a comment, `# also shown: …`;
/// - `appToday`: the note.
///
/// What has no section (a derived fact, a roll fact beside dice, a pool
/// other than LE and AsP, a process, the clock, a timed Stufe, a non-scalar value) is left out,
/// and a comment at the top lists it.
public enum SituationDraft {
    /// The draft as a situations file with one situation.
    public static func yaml(from entry: LogEntry, id: String, name: String) -> String {
        Draft(entry).yaml(id: id, name: name)
    }

    /// The object rulec compiles the draft to (one entry of `situations.json`: `id`, `file`,
    /// `name`, `owned`, `facts`, `base`, `rolls`, `sequence`, `expect`, `expectSituation`,
    /// `pending`). `pending` is empty: the open rulings on the path are rulec's to find.
    public static func compiledJSON(from entry: LogEntry, id: String, name: String) -> JSONValue {
        Draft(entry).compiled(id: id, name: name)
    }

    /// The value a situation states for a line (the harness's bridge 3): the value after the
    /// step for `set`, `levelAs`, `replaced` and a scale step (an `add` with `now`); the step
    /// for any other kind.
    public static func stated(_ line: Line) -> Int {
        switch line.kind {
        case .set, .levelAs, .replaced: line.now ?? line.value
        case .add where line.now != nil: line.now ?? line.value
        default: line.value
        }
    }

    // MARK: - YAML scalars

    /// Strings YAML 1.1 reads as a bool or a null.
    static let reserved: Set<String> = ["y", "n", "yes", "no", "on", "off", "true", "false", "null", "~"]

    /// One scalar as YAML: a number, a bool, `null`, a plain string when it is an identifier
    /// (`[A-Za-z_][A-Za-z0-9_.-]*`, ASCII) that YAML reads as a string, else a double-quoted
    /// string with JSON's escapes. So `on`, `no`, `null`, `12` and `19.1` are quoted.
    static func scalar(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return d.isFinite ? String(d) : quoted(String(d))
        case .string(let s): return isPlain(s) ? s : quoted(s)
        case .array, .object: return quoted("\(value)")
        }
    }

    static func isPlain(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first, first == "_" || isLetter(first),
              !reserved.contains(s.lowercased()) else { return false }
        return s.unicodeScalars.allSatisfy { isLetter($0) || ("0"..."9").contains($0) || "_.-".unicodeScalars.contains($0) }
    }

    private static func isLetter(_ c: Unicode.Scalar) -> Bool { ("a"..."z").contains(c) || ("A"..."Z").contains(c) }

    static func quoted(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where c.value < 0x20 || c.value == 0x7F: out += String(format: "\\u%04X", c.value)
            default: out.unicodeScalars.append(c)
            }
        }
        return out + "\""
    }

    /// A flow list of scalars: `[a, "no", 3]`.
    static func flow(_ values: [JSONValue]) -> String { "[" + values.map(scalar).joined(separator: ", ") + "]" }

    /// A value the draft can write: a scalar or a list of scalars.
    static func writable(_ value: JSONValue) -> Bool {
        switch value {
        case .object: false
        case .array(let a): a.allSatisfy { if case .array = $0 { false } else if case .object = $0 { false } else { true } }
        default: true
        }
    }

    static func value(_ v: JSONValue) -> String {
        if case .array(let a) = v { return flow(a) }
        return scalar(v)
    }
}

// MARK: - The draft's content

/// What the draft states, from which both the YAML and the compiled object are written.
private struct Draft {
    struct Owned { var map: String; var id: String; var level: Int; var option: JSONValue?; var option2: JSONValue? }
    struct Entry { var key: String; var fact: Fact }
    struct ExpectedLine { var from: String; var value: Int; var via: [String]; var ruling: [String] }
    struct Expected { var query: String; var total: Int; var result: Int?; var lines: [ExpectedLine]; var alsoShown: [String] }

    static let ruleMaps = ["abilities", "advantages", "disadvantages", "conditions", "states"]
    /// Sheet fact prefix → its hero map.
    static let sheetMaps: [(prefix: String, map: String)] = [("attr.", "attributes"), ("ktw.", "techniques"), ("fw.", "talents")]
    /// Section → its owner and the prefix its keys drop, as `situations.py`'s `SECTIONS`. A fact
    /// goes to the first section of its owner whose prefix it has (`ally.has` → `ally: {has}`,
    /// `opponent.size` → `opponent: {size}`), else to the owner's unprefixed section.
    static let sections: [(name: String, owner: Owner, prefix: String)] = [
        ("loadout", .loadout, "loadout."), ("choose", .player, ""), ("ally", .player, "ally."), ("gm", .gm, ""),
        ("opponent", .gm, "opponent."), ("round", .round, "round."),
    ]

    static func section(of name: String, owner: Owner) -> (name: String, owner: Owner, prefix: String)? {
        let own = sections.filter { $0.owner == owner }
        return own.first { !$0.prefix.isEmpty && $0.name != "loadout" && name.hasPrefix($0.prefix) && name.count > $0.prefix.count }
            ?? own.first { $0.prefix.isEmpty || $0.name == "loadout" || $0.name == "round" }
    }

    var entry: LogEntry
    var owned: [Owned] = []
    /// Hero map → name → value (`attributes: {MU: 14}`).
    var sheet: [String: [(String, Int)]] = [:]
    /// The sheet's other facts, written under `hero: { sheet: … }` (`species.le`,
    /// `hero.purchased.le`; Task 30).
    var sheetFacts: [(String, JSONValue)] = []
    var values: [(String, Int)] = []
    var inSections: [String: [Entry]] = [:]
    /// Roll facts written as the `rolls` mapping (no dice).
    var rollFacts: [Entry] = []
    var expect: [Expected] = []
    var leftOut: [String] = []

    init(_ entry: LogEntry) {
        self.entry = entry
        let s = entry.situation
        ownedRules(s)
        facts(s)
        baseValues(s)
        for (id, p) in s.processes.sorted(by: { $0.key < $1.key }) {
            leftOut.append("process \(id) (step \(p.progress) of \(p.steps), from round \(p.startedRound))")
        }
        if s.clock != Clock() { leftOut.append("clock (round \(s.clock.round), minute \(s.clock.minutes))") }
        for t in s.timed { leftOut.append("timed \(t.rule) \(t.levels > 0 ? "+" : "")\(t.levels) for the \(t.span.rawValue)") }
        expectations()
    }

    private mutating func ownedRules(_ s: Situation) {
        for (id, r) in s.owned.sorted(by: { $0.key < $1.key }) {
            let map = [("SA_", "abilities"), ("ADV_", "advantages"), ("DISADV_", "disadvantages"), ("COND_", "conditions"),
                       ("STATE_", "states")].first { id.hasPrefix($0.0) }?.1 ?? "abilities"
            var o = Owned(map: map, id: id, level: r.level, option: r.option, option2: r.option2)
            if let opt = r.option, !SituationDraft.writable(opt) || opt.isList {
                leftOut.append("\(id) option (not a scalar)")
                o.option = nil; o.option2 = nil
            } else if let opt2 = r.option2, o.option == nil || !SituationDraft.writable(opt2) || opt2.isList {
                leftOut.append("\(id) option2 (\(o.option == nil ? "without an option" : "not a scalar"))")
                o.option2 = nil
            }
            owned.append(o)
        }
    }

    private mutating func facts(_ s: Situation) {
        // An item's state is stated as `item.<instance>.<field>` (owner loadout).
        var all = Array(s.facts.values)
        for (instance, item) in s.items {
            for field in ItemDelta.fields {
                if let v = item[field: field] { all.append(Fact(name: "item.\(instance).\(field)", value: v, owner: .loadout)) }
            }
        }
        for f in all.sorted(by: { $0.name < $1.name }) {
            let who = "\(f.name) (\(f.owner.rawValue))"
            guard SituationDraft.writable(f.value) else { leftOut.append("\(who): not a scalar"); continue }
            if f.owner == .sheet {
                if let m = Self.sheetMaps.first(where: { f.name.hasPrefix($0.prefix) }), let n = f.value.intValue {
                    sheet[m.map, default: []].append((String(f.name.dropFirst(m.prefix.count)), n))
                } else if Vocabulary.owner(ofFact: f.name) == .sheet, !f.value.isList {
                    sheetFacts.append((f.name, f.value))
                } else {
                    leftOut.append(who)
                }
                continue
            }
            // rulec checks each fact against the vocabulary's owner.
            guard Vocabulary.owner(ofFact: f.name) == f.owner else {
                leftOut.append("\(who): the vocabulary's owner is \(Vocabulary.owner(ofFact: f.name)?.rawValue ?? "none")")
                continue
            }
            if f.owner == .roll {
                if entry.rolls.isEmpty { rollFacts.append(Entry(key: f.name, fact: f)) } else { leftOut.append("\(who): beside dice") }
                continue
            }
            guard let section = Self.section(of: f.name, owner: f.owner) else { leftOut.append(who); continue }
            guard let key = Self.key(f.name, section: section.name, prefix: section.prefix) else { leftOut.append(who); continue }
            inSections[section.name, default: []].append(Entry(key: key, fact: f))
        }
    }

    /// The key a fact has in its section, as rulec reads it back (`situations.py`): the section's
    /// prefix is added to a key, except in `loadout` for a key that is a loadout fact itself.
    static func key(_ name: String, section: String, prefix: String) -> String? {
        if section == "loadout" {
            if name.hasPrefix(prefix) {
                let short = String(name.dropFirst(prefix.count))
                return Vocabulary.owner(ofFact: short) == .loadout ? name : short
            }
            return Vocabulary.owner(ofFact: name) == .loadout ? name : nil
        }
        if prefix.isEmpty { return name }
        return name.hasPrefix(prefix) && name.count > prefix.count ? String(name.dropFirst(prefix.count)) : nil
    }

    /// The base values, with the LE and AsP pools as the values the harness fills them from
    /// (`CompiledSituation.engineSituation`: the max from `leMax`, else the current value).
    private mutating func baseValues(_ s: Situation) {
        var base = s.base
        for pool in Pool.allCases {
            guard let p = s.pools[pool] else { continue }
            guard let current = pool.currentTarget else {
                leftOut.append("pool \(pool.rawValue) (\(p.current) of \(p.max))")
                continue
            }
            let maxKey = current.replacingOccurrences(of: "Current", with: "Max")
            base[current] = p.current
            if (base[maxKey] ?? p.current) != p.max { base[maxKey] = p.max }
        }
        values = base.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private mutating func expectations() {
        var seen: Set<String> = []
        for b in entry.breakdowns {
            let query = b.query.description
            guard seen.insert(query).inserted else { leftOut.append("a second breakdown of \(query)"); continue }
            // Bridge 2: a derived base counts in the total; a sheet base does not.
            let derived = b.base.map { $0.owner != .sheet } ?? false
            let lines = b.shownLines.compactMap { l in
                l.origin.map { o in
                    ExpectedLine(from: o.description, value: SituationDraft.stated(l), via: l.via.map(\.description).uniqued(),
                                 ruling: l.rulings.uniqued())
                }
            }
            // The shown lines no clause gave (a sheet base, a modifier typed in) have no `from`: a comment.
            let alsoShown = b.shownLines.filter { $0.origin == nil }.map { l in
                "\(l.value) \(l.kind.rawValue)" + (l.owner.map { " (\($0.rawValue))" } ?? "")
            }
            expect.append(Expected(query: query, total: derived ? (b.result ?? b.total) : b.total, result: b.result, lines: lines,
                                   alsoShown: alsoShown))
        }
    }

    // MARK: YAML

    func yaml(id: String, name: String) -> String {
        var out: [String] = []
        func line(_ indent: Int, _ text: String) { out.append(String(repeating: " ", count: indent) + text) }
        func key(_ k: String) -> String { SituationDraft.scalar(.string(k)) + ":" }

        for c in header { out.append("# " + c.replacingOccurrences(of: "\n", with: " ")) }
        line(0, "situations:")
        line(2, "- id: " + SituationDraft.scalar(.string(id)))
        line(4, "name: " + SituationDraft.scalar(.string(name)))

        let heroMaps = Self.ruleMaps.filter { m in owned.contains { $0.map == m } }
        let sheetMaps = Self.sheetMaps.map(\.map).filter { sheet[$0] != nil }
        if !heroMaps.isEmpty || !sheetMaps.isEmpty || !sheetFacts.isEmpty || !values.isEmpty {
            line(4, "hero:")
            for m in heroMaps {
                line(6, m + ":")
                for o in owned where o.map == m {
                    guard let option = o.option else { line(8, key(o.id) + " \(o.level)"); continue }
                    line(8, key(o.id))
                    line(10, "level: \(o.level)")
                    line(10, "sid: " + SituationDraft.scalar(option))
                    if let option2 = o.option2 { line(10, "sid2: " + SituationDraft.scalar(option2)) }
                }
            }
            for m in sheetMaps {
                line(6, m + ":")
                for (k, v) in sheet[m] ?? [] { line(8, key(k) + " \(v)") }
            }
            if !sheetFacts.isEmpty {
                line(6, "sheet:")
                for (k, v) in sheetFacts { line(8, key(k) + " " + SituationDraft.scalar(v)) }
            }
            if !values.isEmpty {
                line(6, "values:")
                for (k, v) in values { line(8, key(k) + " \(v)") }
            }
        }
        for section in Self.sections.map(\.name) {
            guard let entries = inSections[section], !entries.isEmpty else { continue }
            line(4, section + ":")
            for e in entries { line(6, key(e.key) + " " + SituationDraft.value(e.fact.value)) }
        }
        if !entry.rolls.isEmpty {
            line(4, "rolls: " + SituationDraft.flow(entry.rolls.map(JSONValue.int)))
        } else if !rollFacts.isEmpty {
            line(4, "rolls:")
            for e in rollFacts { line(6, key(e.key) + " " + SituationDraft.value(e.fact.value)) }
        }
        if !expect.isEmpty {
            line(4, "expect:")
            for q in expect {
                line(6, key(q.query))
                if !q.alsoShown.isEmpty { line(8, "# also shown: " + q.alsoShown.joined(separator: "; ")) }
                line(8, "total: \(q.total)")
                if let r = q.result { line(8, "result: \(r)") }
                guard !q.lines.isEmpty else { continue }
                line(8, "lines:")
                for l in q.lines {
                    line(10, "- from: " + SituationDraft.scalar(.string(l.from)))
                    line(12, "value: \(l.value)")
                    if !l.via.isEmpty { line(12, "via: " + SituationDraft.flow(l.via.map(JSONValue.string))) }
                    if !l.ruling.isEmpty { line(12, "ruling: " + SituationDraft.flow(l.ruling.map(JSONValue.string))) }
                }
            }
        }
        if let note = entry.note { line(4, "appToday: " + SituationDraft.quoted(note)) }
        return out.joined(separator: "\n") + "\n"
    }

    /// The comment at the top: where the entry comes from, and what the draft leaves out.
    var header: [String] {
        let what: String
        switch entry.kind {
        case .query: what = "query " + (entry.query?.description ?? "none")
        case .action:
            let json = entry.action.flatMap { try? LogExport.encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }
            what = "action " + (json ?? "none")
        }
        var out = [
            "Drafted from a log entry (spec §8): the engine's result as `expect`. Correct what was wrong, give it a new id,",
            "then move it into a situations file.",
            "entry \(entry.id.uuidString), \(ISO8601DateFormatter().string(from: entry.date)), \(what)",
            // No rules sha256 (R59): the draft changes only when what it states changes.
            "app \(entry.appVersion), vocabulary \(entry.vocabularyVersion), hero \(entry.heroId ?? "none")",
        ]
        if entry.flagged { out.append("flagged: this looks wrong") }
        if !leftOut.isEmpty {
            out.append("left out (no section in the situation format):")
            out += leftOut.map { "  - " + $0 }
        }
        return out
    }

    // MARK: Compiled

    func compiled(id: String, name: String) -> JSONValue {
        var facts: [String: JSONValue] = [:]
        func fact(_ name: String, _ value: JSONValue, _ owner: Owner) {
            facts[name] = .object(["name": .string(name), "value": value, "owner": .string(owner.rawValue)])
        }
        for m in Self.sheetMaps {
            for (k, v) in sheet[m.map] ?? [] { fact(m.prefix + k, .int(v), .sheet) }
        }
        for (k, v) in sheetFacts { fact(k, v, .sheet) }
        for section in Self.sections {
            for e in inSections[section.name] ?? [] { fact(e.fact.name, e.fact.value, e.fact.owner) }
        }
        if entry.rolls.isEmpty { for e in rollFacts { fact(e.fact.name, e.fact.value, .roll) } }
        var ownedJSON: [String: JSONValue] = [:]
        for o in owned {
            var entry: [String: JSONValue] = ["level": .int(o.level)]
            if let option = o.option { entry["option"] = option }
            if let option2 = o.option2 { entry["option2"] = option2 }
            ownedJSON[o.id] = .object(entry)
        }
        let expectJSON: [JSONValue] = expect.map { q in
            var o: [String: JSONValue] = ["query": .string(q.query), "total": .int(q.total)]
            if let r = q.result { o["result"] = .int(r) }
            if !q.lines.isEmpty {
                o["lines"] = .array(q.lines.map { l in
                    var line: [String: JSONValue] = ["from": .string(l.from), "value": .int(l.value)]
                    if !l.via.isEmpty { line["via"] = .array(l.via.map(JSONValue.string)) }
                    if !l.ruling.isEmpty { line["ruling"] = .array(l.ruling.map(JSONValue.string)) }
                    return .object(line)
                })
            }
            return .object(o)
        }
        return .object([
            "id": .string(id), "file": .string("draft.yaml"), "name": .string(name),
            "owned": .object(ownedJSON),
            "facts": .array(facts.keys.sorted().compactMap { facts[$0] }),
            "base": .object(Dictionary(uniqueKeysWithValues: values.map { ($0.0, JSONValue.int($0.1)) })),
            "rolls": .array(entry.rolls.map(JSONValue.int)),
            "sequence": .array([]), "expect": .array(expectJSON), "expectSituation": .object([:]), "pending": .array([]),
        ])
    }
}

private extension JSONValue {
    var isList: Bool { if case .array = self { true } else { false } }
    /// An int, or a whole double (rulec requires a sheet value to be an int).
    var intValue: Int? { if case .int(let i) = self { i } else { nil } }
}
