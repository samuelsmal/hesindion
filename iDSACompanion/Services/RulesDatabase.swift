import Foundation
import SQLite3

struct RuleSearchResult: Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String
}

struct RuleDetail: Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String
    let cost: String?
    let levels: Int?
    let max: Int?
    let effects: [RuleEffect]
    let spellDetail: SpellDetail?
}

struct RuleEffect {
    let level: Int?
    let type: String
    let attribute: String?
    let value: Double?
    let scope: String?
    let description: String?
}

struct SpellDetail {
    let checkAttr1: String?
    let checkAttr2: String?
    let checkAttr3: String?
    let improvementCost: String?
    let castingTime: String?
    let castingTimeShort: String?
    let aeCost: String?
    let aeCostShort: String?
    let range: String?
    let rangeShort: String?
    let duration: String?
    let durationShort: String?
    let target: String?
}

final class RulesDatabase: @unchecked Sendable {
    static let shared = RulesDatabase()

    private nonisolated(unsafe) let db: OpaquePointer?

    private init() {
        guard let path = Bundle.main.path(forResource: "rules", ofType: "db") else {
            fatalError("rules.db not found in bundle")
        }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            fatalError("Cannot open rules.db")
        }
        db = handle
    }

    deinit {
        sqlite3_close(db)
    }

    func search(query: String, locale: String = "de-DE", limit: Int = 20) -> [RuleSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let sql = """
            SELECT f.rule_id, r.category, f.name, f.description
            FROM rules_fts f
            JOIN rules r ON r.id = f.rule_id
            WHERE rules_fts MATCH ?
            LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let ftsQuery = trimmed.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
        sqlite3_bind_text(stmt, 1, ftsQuery, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [RuleSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RuleSearchResult(
                id: col_text(stmt, 0),
                category: col_text(stmt, 1),
                name: col_text(stmt, 2),
                description: col_text_opt(stmt, 3) ?? ""
            ))
        }
        return results
    }

    func categories() -> [String] {
        let sql = "SELECT DISTINCT category FROM rules ORDER BY category"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(col_text(stmt, 0))
        }
        return results
    }

    func rulesByCategory(_ category: String, locale: String = "de-DE") -> [RuleSearchResult] {
        let sql = """
            SELECT r.id, r.category, i.name, i.description
            FROM rules r
            JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
            WHERE r.category = ?
            ORDER BY i.name
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, locale, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, category, -1, SQLITE_TRANSIENT)

        var results: [RuleSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RuleSearchResult(
                id: col_text(stmt, 0),
                category: col_text(stmt, 1),
                name: col_text(stmt, 2),
                description: col_text_opt(stmt, 3) ?? ""
            ))
        }
        return results
    }

    func lookupByName(_ name: String, locale: String = "de-DE") -> RuleDetail? {
        let sql = """
            SELECT r.id
            FROM rules r
            JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
            WHERE i.name = ?
            LIMIT 1
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, locale, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let ruleId = col_text(stmt, 0)
        return lookup(id: ruleId, locale: locale)
    }

    func lookup(id: String, locale: String = "de-DE") -> RuleDetail? {
        let sql = """
            SELECT r.id, r.category, i.name, i.description, r.cost, r.levels, r.max
            FROM rules r
            JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
            WHERE r.id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, locale, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let ruleId = col_text(stmt, 0)
        let category = col_text(stmt, 1)
        let name = col_text(stmt, 2)
        let desc = col_text_opt(stmt, 3) ?? ""
        let cost = col_text_opt(stmt, 4)
        let levels = col_int_opt(stmt, 5)
        let max = col_int_opt(stmt, 6)

        let effects = lookupEffects(ruleId: ruleId)
        let spellDetail = (category == "spell" || category == "liturgy")
            ? lookupSpellDetail(ruleId: ruleId)
            : nil

        return RuleDetail(
            id: ruleId, category: category, name: name, description: desc,
            cost: cost, levels: levels, max: max, effects: effects,
            spellDetail: spellDetail
        )
    }

    private func lookupSpellDetail(ruleId: String) -> SpellDetail? {
        let sql = """
            SELECT check_attr_1, check_attr_2, check_attr_3,
                   improvement_cost, casting_time, casting_time_short,
                   ae_cost, ae_cost_short, range, range_short,
                   duration, duration_short, target
            FROM spell_details WHERE rule_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return SpellDetail(
            checkAttr1: col_text_opt(stmt, 0),
            checkAttr2: col_text_opt(stmt, 1),
            checkAttr3: col_text_opt(stmt, 2),
            improvementCost: col_text_opt(stmt, 3),
            castingTime: col_text_opt(stmt, 4),
            castingTimeShort: col_text_opt(stmt, 5),
            aeCost: col_text_opt(stmt, 6),
            aeCostShort: col_text_opt(stmt, 7),
            range: col_text_opt(stmt, 8),
            rangeShort: col_text_opt(stmt, 9),
            duration: col_text_opt(stmt, 10),
            durationShort: col_text_opt(stmt, 11),
            target: col_text_opt(stmt, 12)
        )
    }

    private func lookupEffects(ruleId: String) -> [RuleEffect] {
        let sql = "SELECT level, type, attribute, value, scope, description FROM effects WHERE rule_id = ? ORDER BY level"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)

        var results: [RuleEffect] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RuleEffect(
                level: col_int_opt(stmt, 0),
                type: col_text(stmt, 1),
                attribute: col_text_opt(stmt, 2),
                value: col_double_opt(stmt, 3),
                scope: col_text_opt(stmt, 4),
                description: col_text_opt(stmt, 5)
            ))
        }
        return results
    }

    // MARK: - SQLite helpers

    private func col_text(_ stmt: OpaquePointer?, _ idx: Int32) -> String {
        String(cString: sqlite3_column_text(stmt, idx))
    }

    private func col_text_opt(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(stmt, idx))
    }

    private func col_int_opt(_ stmt: OpaquePointer?, _ idx: Int32) -> Int? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(stmt, idx))
    }

    private func col_double_opt(_ stmt: OpaquePointer?, _ idx: Int32) -> Double? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, idx)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
