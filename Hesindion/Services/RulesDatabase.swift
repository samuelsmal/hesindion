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
    /// Optolith's group (`groups.id`), nil for categories that have none.
    let groupId: Int?
    let name: String
    let description: String
    /// The per-level texts (`level1`…`level4`), empty for most rules; Zustände have four.
    let levelTexts: [String]
    let cost: String?
    let levels: Int?
    let max: Int?
    let spellDetail: SpellDetail?
    let catalog: CatalogEntry?
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

struct CombatTechniqueDetail {
    let primaryAttr1: String?
    let primaryAttr2: String?
    let hasNoParry: Bool
}

/// What the app does with a rule. The values are the catalog's own strings.
enum CatalogStatus: String, CaseIterable {
    /// Clauses in the catalog drive it through the evaluator (design §3; step 2).
    case implemented
    /// Named in Swift; `pointer` says where.
    case byHand
    /// Read and found to touch no roll the app makes.
    case noRollEffect
    /// Not read yet.
    case todo

    var labelKey: String { "catalog.status.\(rawValue)" }
}

struct CatalogPointer: Equatable {
    let file: String
    let symbol: String
}

struct CatalogEntry: Identifiable, Equatable {
    let id: String
    let status: CatalogStatus
    let note: String?
    let pointer: CatalogPointer?
    let reviewedBy: String?
    let reviewedOn: String?
}

final class RulesDatabase: @unchecked Sendable {
    static let shared = RulesDatabase()

    private nonisolated(unsafe) let db: OpaquePointer?

    private init() {
        guard let path = Bundle.main.path(forResource: "rules", ofType: "db") else {
            fatalError("rules.db not found in bundle")
        }
        var handle: OpaquePointer?
        // FULLMUTEX (serialized) — the shared singleton connection is reached from
        // multiple threads (SwiftUI/SwiftData rendering touches RulesDatabase.shared
        // on background queues while imports query it). NOMUTEX corrupted the
        // read-only connection under that concurrency, intermittently yielding empty
        // query results. Read-only DB, so serialization overhead is negligible.
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
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
            SELECT r.id, r.category, i.name, i.description, r.cost, r.levels, r.max, r.group_id,
                   i.level1, i.level2, i.level3, i.level4
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
        let groupId = col_int_opt(stmt, 7)
        let levelTexts = (8...11).compactMap { col_text_opt(stmt, Int32($0)) }.filter { !$0.isEmpty }

        let spellDetail = (category == "spell" || category == "liturgy")
            ? lookupSpellDetail(ruleId: ruleId)
            : nil

        return RuleDetail(
            id: ruleId, category: category, groupId: groupId, name: name, description: desc,
            levelTexts: levelTexts,
            cost: cost, levels: levels, max: max,
            spellDetail: spellDetail,
            catalog: lookupCatalogEntry(ruleId: ruleId)
        )
    }

    func lookupSelectOption(ruleId: String, sid: Int, locale: String = "de-DE") -> String? {
        let sql = "SELECT name FROM select_options WHERE rule_id = ? AND sid = ? AND locale = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(sid))
        sqlite3_bind_text(stmt, 3, locale, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }

    func lookupCombatTechniqueDetail(ruleId: String) -> CombatTechniqueDetail? {
        let sql = """
            SELECT d.primary_attr_1, d.primary_attr_2, r.has_no_parry
            FROM combat_technique_details d
            JOIN rules r ON r.id = d.rule_id
            WHERE d.rule_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return CombatTechniqueDetail(
            primaryAttr1: col_text_opt(stmt, 0),
            primaryAttr2: col_text_opt(stmt, 1),
            hasNoParry: (sqlite3_column_int(stmt, 2) != 0)
        )
    }

    func allCombatTechniqueIds() -> [String] {
        let sql = "SELECT id FROM rules WHERE category = 'combat_technique' ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(col_text(stmt, 0))
        }
        return ids
    }

    /// The name of an Optolith group, for the tests that hold the group enums to the table.
    func lookupGroupName(_ id: Int) -> String? {
        let sql = "SELECT name FROM groups WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }

    // MARK: - Catalog

    private static let catalogColumns =
        "rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on"

    private func catalogEntry(from stmt: OpaquePointer?) -> CatalogEntry? {
        guard let status = CatalogStatus(rawValue: col_text(stmt, 1)) else { return nil }
        let file = col_text_opt(stmt, 3)
        let symbol = col_text_opt(stmt, 4)
        let pointer: CatalogPointer? = if let file, let symbol { CatalogPointer(file: file, symbol: symbol) } else { nil }
        return CatalogEntry(
            id: col_text(stmt, 0),
            status: status,
            note: col_text_opt(stmt, 2),
            pointer: pointer,
            reviewedBy: col_text_opt(stmt, 5),
            reviewedOn: col_text_opt(stmt, 6)
        )
    }

    func lookupCatalogEntry(ruleId: String) -> CatalogEntry? {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog WHERE rule_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return catalogEntry(from: stmt)
    }

    func catalogEntries(status: CatalogStatus) -> [CatalogEntry] {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog WHERE status = ? ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        var results: [CatalogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = catalogEntry(from: stmt) { results.append(entry) }
        }
        return results
    }

    func catalogStatusCounts() -> [CatalogStatus: Int] {
        let sql = "SELECT status, COUNT(*) FROM catalog GROUP BY status"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        var counts: [CatalogStatus: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let status = CatalogStatus(rawValue: col_text(stmt, 0)) {
                counts[status] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        return counts
    }

    /// Rules the catalog does not mention. The build refuses to produce such a
    /// database; this is the check that the bundled one came from the build.
    func ruleIdsWithoutCatalogEntry() -> [String] {
        let sql = "SELECT id FROM rules WHERE id NOT IN (SELECT rule_id FROM catalog) ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return ["<catalog table missing>"] }
        defer { sqlite3_finalize(stmt) }
        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW { ids.append(col_text(stmt, 0)) }
        return ids
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
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
