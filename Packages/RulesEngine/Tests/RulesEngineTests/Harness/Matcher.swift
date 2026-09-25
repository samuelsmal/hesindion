import Foundation
@testable import RulesEngine

// Matching a compiled situation against the engine (spec §10.2), with the bridge rules of the
// Task 24 extra scope where the engine's output shape and the situations' expectation shape
// differ. What a situation does not mention is never checked; what it states in a shape the
// engine does not model is reported as `unsupportedShape`, never passed silently.

/// One way the engine's answer differs from what a situation expects.
struct Mismatch: Codable, Hashable, CustomStringConvertible {
    enum Kind: String, Codable, CaseIterable {
        // lines
        case missingLine, wrongValue, wrongVia, wrongRuling, wrongWas, wrongKind, wrongSource, wrongTerm
        // a query's numbers and verdict
        case total, result, base, legal
        // notApplied
        case missingNotApplied, wrongReason, wrongBecause, wrongNotApplied
        // the player-facing parts
        case missingOffer, unexpectedOffer, missingQuestion, unexpectedQuestion, missingText, unexpectedText
        /// An expectation the engine's output has no field for (`legal.span`, `term`, prose
        /// reasons, a situation-level `legal`, an offer that is no choice, …).
        case unsupportedShape
    }

    var kind: Kind
    /// The expected query, nil for a situation-level expectation.
    var query: String?
    var detail: String

    init(kind: Kind, query: String? = nil, detail: String) { self.kind = kind; self.query = query; self.detail = detail }

    var description: String { "[\(kind.rawValue)] \(query.map { "\($0): " } ?? "")\(detail)" }
}

enum Matcher {
    /// The mismatches of the situation's query and situation-level expectations (§10.2).
    static func match(_ expected: CompiledSituation, engine: Engine) -> [Mismatch] {
        run(expected, engine: engine).mismatches
    }

    struct Run {
        var mismatches: [Mismatch]
        /// Every open ruling the run met: a `notApplied(openRuling)` or an open-ruling text in
        /// any of its breakdowns (R32).
        var openRulingsHit: Set<String>
    }

    /// Evaluates every expected query, and `Engine.offers(in:)` when offers are expected without
    /// a query, then compares.
    static func run(_ s: CompiledSituation, engine: Engine) -> Run {
        let breakdowns = s.expect.map { engine.evaluate(Query($0.query), in: s.situation) }
        let wantsOffers = s.expectSituation["offered"] != nil || s.expectSituation["notOffered"] != nil
        let offers = s.expect.isEmpty && wantsOffers ? engine.offers(in: s.situation) : []
        return Run(mismatches: compare(s, breakdowns: breakdowns, offers: offers),
                   openRulingsHit: openRulings(in: breakdowns))
    }

    /// Compares `s` with the breakdowns of its expected queries (in `s.expect`'s order) and, for
    /// a situation without a query, `Engine.offers(in:)`.
    static func compare(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice]) -> [Mismatch] {
        var out: [Mismatch] = []
        for (q, b) in zip(s.expect, breakdowns) { out += query(q, b) }
        out += situationLevel(s, breakdowns: breakdowns, offers: offers)
        return out
    }

    static func openRulings(in breakdowns: [Breakdown]) -> Set<String> {
        var out: Set<String> = []
        for b in breakdowns {
            for n in b.notApplied where n.reason == .openRuling { out.formUnion(n.rulings) }
            for t in b.texts where t.kind == .openRuling { if let r = t.ruling { out.insert(r) } }
        }
        return out
    }

    // MARK: - One query

    static func query(_ q: QueryExpectation, _ b: Breakdown) -> [Mismatch] {
        var out: [Mismatch] = []
        func add(_ kind: Mismatch.Kind, _ detail: String) { out.append(Mismatch(kind: kind, query: q.query, detail: detail)) }

        if let expected = q.lines { out += lines(expected, b, query: q.query) }
        if let t = q.total {
            // Bridge 2: a derived base counts in the situation's `total` (leMax 37); a sheet base
            // does not (at −5); without a base the total is the lines' sum.
            let derived = b.base.map { $0.owner != .sheet } ?? false
            let actual: Int? = derived ? b.result : b.total
            if actual != t {
                let got = actual.map(String.init) ?? "none"
                let what = derived ? "the result: the base is derived" : "the lines after the base"
                add(.total, "expected total \(t), got \(got) (\(what)) — shown: \(show(b.shownLines))")
            }
        }
        if let r = q.result, b.result != r {
            add(.result, "expected result \(r), got \(b.result.map(String.init) ?? "none (no base)")")
        }
        for e in q.notApplied ?? [] { out += notApplied(e, in: b.notApplied, query: q.query) }
        if let legal = q.legal { out += self.legal(legal, b.legal, query: q.query) }
        if let base = q.base { out += self.base(base, b) .map { Mismatch(kind: $0.kind, query: q.query, detail: $0.detail) } }
        if q.values != nil {
            add(.unsupportedShape, "values (a check's stage values) are not in a breakdown before Task 26")
        }
        return out
    }

    // MARK: Lines

    /// The value a situation states for a line (bridge 3): the value after the step for `set`,
    /// `levelAs`, a scale step (an `add` with `now`) and `replaced`; the step for any other kind.
    static func stated(_ l: Line) -> Int {
        switch l.kind {
        case .set, .levelAs, .replaced: l.now ?? l.value
        case .add where l.now != nil: l.now ?? l.value
        default: l.value
        }
    }

    /// Bridge 5: for each `.multiplied` line that scaled the lines of exactly one clause, that
    /// clause's line as the situation names it: value the lines' sum plus the delta, `was` the
    /// sum, the multiplier in `via`. It matches only an expected line whose `via` names the
    /// multiplier.
    static func scaledLines(_ shown: [Line]) -> [(line: Line, multiplier: ClauseRef)] {
        shown.compactMap { d in
            guard d.kind == .multiplied, let m = d.origin else { return nil }
            let scaled = d.via.filter { v in shown.contains { $0.origin == v && $0.kind != .multiplied } }
            guard scaled.count == 1, let x = scaled.first else { return nil }
            let own = shown.filter { $0.origin == x && $0.kind != .multiplied }
            let sum = own.reduce(0) { $0 + $1.value }
            let line = Line(value: sum + d.value, kind: own[0].kind, origin: x,
                            via: (own.flatMap(\.via) + [m] + d.via.filter { $0 != x }).uniquedRefs(),
                            rulings: (own.flatMap(\.rulings) + d.rulings).uniquedStrings(),
                            facts: own.flatMap(\.facts) + d.facts, owner: own[0].owner, was: sum)
            return (line, m)
        }
    }

    /// Each expected line must match a distinct shown line (§10.2: any order; actual lines the
    /// situation does not mention are not checked).
    static func lines(_ expected: [ExpectedLine], _ b: Breakdown, query: String) -> [Mismatch] {
        let scaled = scaledLines(b.shownLines)
        let shown = b.shownLines + scaled.map(\.line)
        // A scaled line stands for its origin line only where the situation names the multiplier.
        let multiplier = Array(repeating: nil, count: b.shownLines.count) + scaled.map { Optional($0.multiplier) }
        func failures(_ e: ExpectedLine, _ j: Int) -> [Mismatch.Kind] {
            var out = Self.failures(e, shown[j])
            if let m = multiplier[j], !(e.via ?? []).contains(m.description), !out.contains(.wrongVia) { out.append(.wrongVia) }
            return out
        }
        let fits = expected.map { e in shown.indices.filter { failures(e, $0).isEmpty } }
        let assigned = maximumMatching(fits, right: shown.count)
        var out: [Mismatch] = []
        for (i, e) in expected.enumerated() {
            guard let j = assigned[i] else {
                out.append(diagnose(e, shown, failures: { failures(e, $0) }, used: Set(assigned.compactMap { $0 }), query: query))
                continue
            }
            guard let term = e.term else { continue }
            if let actual = shown[j].term {
                if actual != term {
                    out.append(Mismatch(kind: .wrongTerm, query: query, detail: "expected term \"\(term)\", got \"\(actual)\""))
                }
            } else {
                out.append(Mismatch(kind: .unsupportedShape, query: query,
                                    detail: "term \"\(term)\" on \(e.from ?? "a line"): the engine does not name a line's term"))
            }
        }
        return out
    }

    /// The fields of `e` that `a` does not meet, in reporting order.
    static func failures(_ e: ExpectedLine, _ a: Line) -> [Mismatch.Kind] {
        var out: [Mismatch.Kind] = []
        if let from = e.from, a.origin?.description != from { out.append(.missingLine) }
        if let v = e.value, stated(a) != v { out.append(.wrongValue) }
        if let via = e.via, !Set(via).isSubset(of: a.via.map(\.description)) { out.append(.wrongVia) }
        if let r = e.ruling, !Set(r).isSubset(of: a.rulings) { out.append(.wrongRuling) }
        if let was = e.was, a.was != was { out.append(.wrongWas) }
        if let k = e.kind, a.kind.rawValue != k { out.append(.wrongKind) }
        if let s = e.source, a.owner?.rawValue != s { out.append(.wrongSource) }
        return out
    }

    /// Why `e` matched no line: the closest line from its clause (R21: carrying its ruling), the
    /// unused ones first, and its first failing field; `missingLine` when there is none.
    static func diagnose(_ e: ExpectedLine, _ shown: [Line], failures: (Int) -> [Mismatch.Kind], used: Set<Int>,
                         query: String) -> Mismatch {
        let same = shown.indices.filter { j in
            if let from = e.from { return shown[j].origin?.description == from }
            if let r = e.ruling { return Set(r).isSubset(of: shown[j].rulings) }
            return true
        }
        let pool = same.filter { !used.contains($0) }.isEmpty ? same : same.filter { !used.contains($0) }
        let best = pool.min { failures($0).count < failures($1).count }
        let want = describe(e)
        guard let j = best, let kind = failures(j).first else {
            let what = e.from.map { "no line from \($0)" } ?? "no line carrying \(e.ruling ?? [])"
            let extra = same.isEmpty ? "" : " (its \(same.count) line(s) match other expected lines)"
            return Mismatch(kind: .missingLine, query: query, detail: "expected \(want): \(what)\(extra) — shown: \(show(shown))")
        }
        return Mismatch(kind: kind, query: query, detail: "expected \(want), got \(show([shown[j]]))")
    }

    /// Bipartite matching by augmenting paths: `fits[i]` are the right-hand indices left `i` may
    /// take. Returns the right index each left one got, or nil.
    static func maximumMatching(_ fits: [[Int]], right: Int) -> [Int?] {
        var owner = [Int?](repeating: nil, count: right)
        func augment(_ i: Int, _ seen: inout Set<Int>) -> Bool {
            for j in fits[i] where !seen.contains(j) {
                seen.insert(j)
                if owner[j] == nil || augment(owner[j]!, &seen) { owner[j] = i; return true }
            }
            return false
        }
        for i in fits.indices { var seen: Set<Int> = []; _ = augment(i, &seen) }
        var out = [Int?](repeating: nil, count: fits.count)
        for (j, i) in owner.enumerated() { if let i { out[i] = j } }
        return out
    }

    // MARK: notApplied

    enum ReasonForm: Equatable { case code(ReasonCode), ref(String), prose(String) }

    /// A `reason` is a reason code, a `RULE.CLAUSE` ref (read as `because`, bridge 6), or prose.
    static func reasonForm(_ reason: String) -> ReasonForm {
        if let code = ReasonCode(rawValue: reason) { return .code(code) }
        return isRef(reason) ? .ref(reason) : .prose(reason)
    }

    /// `RULE.CLAUSE`: no whitespace, a dot inside.
    static func isRef(_ text: String) -> Bool {
        !text.contains(where: \.isWhitespace) && ClauseRef(text) != nil
    }

    /// Bridge 6: the entry's own `because` text, or a clause ref that is the suppressor or
    /// forbid in the entry's `via` (or its `because`).
    static func because(_ b: String, _ n: NotApplied) -> Bool {
        n.because == b || (isRef(b) && n.via.contains { $0.description == b })
    }

    static func failures(_ e: ExpectedNotApplied, _ n: NotApplied) -> [Mismatch.Kind] {
        var out: [Mismatch.Kind] = []
        switch e.reason.map(reasonForm) {
        case .code(let c)?: if n.reason != c { out.append(.wrongReason) }
        case .ref(let r)?: if !because(r, n) { out.append(.wrongBecause) }
        case .prose?, nil: break
        }
        if let b = e.because, !because(b, n) { out.append(.wrongBecause) }
        if let r = e.ruling, !Set(r).isSubset(of: n.rulings) { out.append(.wrongNotApplied) }
        if let v = e.value, n.value != v { out.append(.wrongNotApplied) }
        return out
    }

    /// `notApplied` matches by rule (and clause, when given) and reason code (§10.2), plus
    /// `because`, `ruling` and `value` when given.
    static func notApplied(_ e: ExpectedNotApplied, in entries: [NotApplied], query: String?) -> [Mismatch] {
        var out: [Mismatch] = []
        let name = e.clause.map { "\(e.rule).\($0)" } ?? e.rule
        if case .prose(let p)? = e.reason.map(reasonForm) {
            out.append(Mismatch(kind: .unsupportedShape, query: query,
                                detail: "notApplied \(name): reason \"\(p)\" is prose, not a reason code"))
        }
        let same = entries.filter { $0.rule == e.rule && (e.clause == nil || $0.clause == e.clause) }
        guard !same.isEmpty else {
            let got = entries.filter { $0.rule == e.rule }.map { "\($0.origin) \($0.reason.rawValue)" }
            out.append(Mismatch(kind: .missingNotApplied, query: query,
                                detail: "no notApplied entry for \(name)" + (got.isEmpty ? "" : " (the rule's: \(got))")))
            return out
        }
        if same.contains(where: { failures(e, $0).isEmpty }) { return out }
        let best = same.min { failures(e, $0).count < failures(e, $1).count }!
        out.append(Mismatch(kind: failures(e, best)[0], query: query,
                            detail: "expected notApplied \(name) \(describe(e)), got \(best.origin) \(best.reason.rawValue)"
                                + " because \(best.because ?? "–") via \(best.via.map(\.description)) rulings \(best.rulings)"
                                + " value \(best.value.map(String.init) ?? "–")"))
        return out
    }

    // MARK: legal, base

    /// Bridge 7: `allowed` compares when given (a bare bool is `allowed`); `because` matches when
    /// any firing forbid or require is it; `ruling` when any of them rests on it; `span` and
    /// `via` are not modelled.
    static func legal(_ expected: JSONValue, _ actual: Legality, query: String?) -> [Mismatch] {
        func mismatch(_ kind: Mismatch.Kind, _ d: String) -> Mismatch { Mismatch(kind: kind, query: query, detail: d) }
        let firing = actual.reasons.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") }
        switch expected {
        case .bool(let allowed):
            return actual.allowed == allowed ? [] : [mismatch(.legal, "expected legal \(allowed), got \(actual.allowed) \(firing)")]
        case .object(let o):
            var out: [Mismatch] = []
            if let allowed = o["allowed"], case .bool(let a) = allowed, actual.allowed != a {
                return [mismatch(.legal, "expected allowed \(a), got \(actual.allowed) \(firing)")]
            }
            if let b = o["because"]?.string,
               !actual.reasons.contains(where: { $0.origin.description == b || $0.because == b }) {
                out.append(mismatch(.legal, "expected a firing \(b), firing: \(firing)"))
            }
            if let r = o["ruling"].map(strings), !r.allSatisfy({ ruling in actual.reasons.contains { rulingMatches(ruling, $0.rulings) } }) {
                out.append(mismatch(.legal, "expected a firing entry resting on \(r), firing: \(firing)"))
            }
            for key in o.keys.sorted() where !["allowed", "because", "ruling"].contains(key) {
                out.append(mismatch(.unsupportedShape, "legal.\(key) is not modelled"))
            }
            return out
        default:
            return [mismatch(.unsupportedShape, "legal \(expected) is not a bool or an object")]
        }
    }

    /// The query key `base`: `from` is the base's clause or one of its parts', `value` the
    /// base's value, `ruling` and `via` are carried by the base or its parts.
    static func base(_ expected: JSONValue, _ b: Breakdown) -> [Mismatch] {
        guard case .object(let o) = expected else { return [Mismatch(kind: .unsupportedShape, detail: "base \(expected)")] }
        var out: [Mismatch] = []
        let lines = b.base.map { [$0] + $0.parts } ?? []
        var wrong: [String] = []
        if let from = o["from"]?.string, !lines.contains(where: { $0.origin?.description == from }) { wrong.append("from \(from)") }
        if let v = o["value"]?.int, b.base?.value != v { wrong.append("value \(v)") }
        if let r = o["ruling"].map(strings), !Set(r).allSatisfy({ x in lines.contains { rulingMatches(x, $0.rulings) } }) {
            wrong.append("ruling \(r)")
        }
        if let via = o["via"].map(strings), !Set(via).isSubset(of: lines.flatMap(\.via).map(\.description)) {
            wrong.append("via \(via)")
        }
        if !wrong.isEmpty {
            out.append(Mismatch(kind: .base, detail: "expected base \(wrong.joined(separator: ", ")), got "
                                + (b.base.map { show([$0] + $0.parts) } ?? "no base")))
        }
        for key in o.keys.sorted() where !["from", "value", "ruling", "via"].contains(key) {
            out.append(Mismatch(kind: .unsupportedShape, detail: "base.\(key) is not modelled"))
        }
        return out
    }

    /// A ruling as a situation writes it outside lines (unqualified or qualified) against
    /// qualified ids.
    static func rulingMatches(_ ruling: String, _ actual: [String]) -> Bool {
        actual.contains { $0 == ruling || $0.hasSuffix("." + ruling) }
    }

    // MARK: - Situation level

    /// The keys the action layer matches (`ActionRunner`).
    static let actionKeys: Set<String> = ["events", "fp", "qs", "spent", "success", "result"]

    static func situationLevel(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice]) -> [Mismatch] {
        var out: [Mismatch] = []
        let es = s.expectSituation
        let noQuery = breakdowns.isEmpty
        func unsupported(_ d: String) { out.append(Mismatch(kind: .unsupportedShape, detail: d)) }
        func needsQuery(_ key: String) -> Bool {
            guard noQuery else { return false }
            unsupported("situation-level \(key) without a query: the engine has no situation-wide breakdown")
            return true
        }

        // Bridge 8: with a query, the breakdowns' offers (a phase-4 suppress acts there);
        // otherwise `Engine.offers(in:)`.
        let pool = noQuery ? offers : breakdowns.flatMap(\.offers)
        for (key, wanted) in [("offered", true), ("notOffered", false)] {
            guard case .array(let entries)? = es[key] else { continue }
            for entry in entries {
                if let m = offer(entry, wanted: wanted, in: pool) { out.append(m) }
            }
        }
        if let raw = es["notApplied"], !needsQuery("notApplied") {
            let all = breakdowns.flatMap(\.notApplied)
            for case let e? in (raw.arrayValue ?? []).map(ExpectedNotApplied.init) {
                out += notApplied(e, in: all, query: nil)
            }
        }
        if let raw = es["questions"], !needsQuery("questions") {
            let asked = breakdowns.flatMap(\.questions)
            let entries = raw.arrayValue ?? []
            if entries.isEmpty, !asked.isEmpty {
                out.append(Mismatch(kind: .unexpectedQuestion, detail: "expected no question, asked: \(asked.map(\.fact).uniquedStrings())"))
            }
            for e in entries {
                guard case .object(let o) = e, let fact = o["fact"]?.string else { unsupported("question \(e)"); continue }
                if !asked.contains(where: { $0.fact == fact }) {
                    out.append(Mismatch(kind: .missingQuestion, detail: "no question for \(fact)"))
                }
            }
        }
        if let raw = es["texts"], !needsQuery("texts") {
            out += texts(raw.arrayValue ?? [], in: breakdowns.flatMap(\.texts))
        }
        if let legal = es["legal"] {
            let keys = legal.objectValue.map { $0.keys.sorted() } ?? []
            unsupported("situation-level legal \(keys.isEmpty ? "\(legal)" : "\(keys)") is not modelled")
        }
        for key in es.keys.sorted() where !["offered", "notOffered", "notApplied", "questions", "texts", "legal"].contains(key)
            && !actionKeys.contains(key) {
            unsupported("situation-level \(key) is not modelled")
        }
        return out
    }

    /// `offered` / `notOffered`: by choice and origin clause (bridge 8). A choice is offered when
    /// an offer of it is legal; `choice.option` is that option of the offer, offered when the
    /// offer lists it and does not refuse it.
    static func offer(_ entry: JSONValue, wanted: Bool, in pool: [OfferedChoice]) -> Mismatch? {
        guard case .object(let o) = entry, let choice = o["choice"]?.string else {
            return Mismatch(kind: .unsupportedShape,
                            detail: "\(wanted ? "offered" : "notOffered") entry without a choice \(entry.objectValue.map { $0.keys.sorted() } ?? []) is the action layer's")
        }
        let from = o["from"]?.string
        func origin(_ c: OfferedChoice) -> Bool { from == nil || c.origin.description == from }
        var offered = pool.contains { $0.choice == choice && origin($0) && $0.legal }
        var seen = pool.filter { $0.choice == choice && origin($0) }
        if !offered, seen.isEmpty, let dot = choice.firstIndex(of: ".") {
            let parent = String(choice[..<dot]), option = String(choice[choice.index(after: dot)...])
            seen = pool.filter { $0.choice == parent && origin($0) }
            offered = seen.contains { c in
                c.legal && (c.options ?? []).contains { text($0) == option } && !c.refused.contains { text($0.option) == option }
            }
        }
        guard offered != wanted else { return nil }
        let got = seen.isEmpty ? "not offered"
            : seen.map { "\($0.origin) legal \($0.legal)" + ($0.because.map { " because \($0)" } ?? "") }.joined(separator: "; ")
        return Mismatch(kind: wanted ? .missingOffer : .unexpectedOffer,
                        detail: "expected \(choice)\(from.map { " from \($0)" } ?? "") \(wanted ? "offered" : "not offered"), got \(got)")
    }

    /// `texts`: an entry matches a text by origin (`from`), open ruling (`ruling`) and, for an
    /// audience key (`player`, `gm`, `opponent`) with a string, that audience and exact text.
    /// `[]` asserts no `tell`. Other keys, or a structured text, are unsupported shapes.
    static func texts(_ entries: [JSONValue], in actual: [TextLine]) -> [Mismatch] {
        var out: [Mismatch] = []
        let tells = actual.filter { $0.kind == .tell }
        if entries.isEmpty, !tells.isEmpty {
            out.append(Mismatch(kind: .unexpectedText, detail: "expected no tell, got \(tells.map { "\($0.origin.map(\.description) ?? "–"): \($0.text)" })"))
        }
        for e in entries {
            guard case .object(let o) = e else { out.append(Mismatch(kind: .unsupportedShape, detail: "text \(e)")); continue }
            let other = o.keys.filter { !["from", "ruling"].contains($0) && Audience(rawValue: $0) == nil }
            let audience = o.keys.compactMap(Audience.init(rawValue:)).first
            if !other.isEmpty || audience.map({ o[$0.rawValue]?.string == nil }) == true {
                out.append(Mismatch(kind: .unsupportedShape, detail: "text \(o.keys.sorted()) \(e): only from, ruling and a plain audience text are matched"))
                continue
            }
            let from = o["from"]?.string, ruling = o["ruling"]?.string
            let hit = actual.contains { t in
                (from == nil || t.origin?.description == from)
                    && (ruling == nil || t.ruling.map { rulingMatches(ruling!, [$0]) } == true)
                    && (audience == nil || (t.audience == audience && t.text == o[audience!.rawValue]?.string))
            }
            if !hit {
                let near = actual.filter { from == nil || $0.origin?.description == from }
                    .map { "\($0.kind.rawValue) \($0.audience.rawValue): \($0.text)" }
                out.append(Mismatch(kind: .missingText, detail: "expected text \(e), got \(near.isEmpty ? "none from there" : "\(near)")"))
            }
        }
        return out
    }

    // MARK: - Showing

    static func show(_ lines: [Line]) -> String {
        "[" + lines.map { l in
            var s = "\(l.origin.map(\.description) ?? (l.owner?.rawValue ?? "?")) \(l.kind.rawValue) \(l.value)"
            if let was = l.was, let now = l.now { s += " (\(was)→\(now))" }
            if !l.via.isEmpty { s += " via \(l.via.map(\.description))" }
            if !l.rulings.isEmpty { s += " rulings \(l.rulings)" }
            return s
        }.joined(separator: ", ") + "]"
    }

    static func describe(_ e: ExpectedLine) -> String {
        var parts: [String] = []
        if let f = e.from { parts.append("from \(f)") }
        if let v = e.value { parts.append("value \(v)") }
        if let k = e.kind { parts.append("kind \(k)") }
        if let w = e.was { parts.append("was \(w)") }
        if let v = e.via { parts.append("via \(v)") }
        if let r = e.ruling { parts.append("ruling \(r)") }
        if let s = e.source { parts.append("source \(s)") }
        return "{" + parts.joined(separator: ", ") + "}"
    }

    static func describe(_ e: ExpectedNotApplied) -> String {
        var parts: [String] = []
        if let r = e.reason { parts.append("reason \(r)") }
        if let b = e.because { parts.append("because \(b)") }
        if let r = e.ruling { parts.append("ruling \(r)") }
        if let v = e.value { parts.append("value \(v)") }
        return "{" + parts.joined(separator: ", ") + "}"
    }

    static func text(_ v: JSONValue) -> String? {
        switch v {
        case .string(let s): s
        case .int(let i): String(i)
        case .bool(let b): String(b)
        default: nil
        }
    }
}

extension JSONValue {
    var arrayValue: [JSONValue]? { if case .array(let a) = self { a } else { nil } }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { o } else { nil } }
}

extension Array where Element == ClauseRef {
    func uniquedRefs() -> [ClauseRef] { var seen: Set<ClauseRef> = []; return filter { seen.insert($0).inserted } }
}

extension Array where Element == String {
    func uniquedStrings() -> [String] { var seen: Set<String> = []; return filter { seen.insert($0).inserted } }
}
