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
    /// The per-level texts with their level number, empty for most rules; Zustände have four.
    /// Trimmed, because the source rows end in a newline.
    let levelTexts: [(level: Int, text: String)]
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
    let name: String
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
        let levelTexts: [(level: Int, text: String)] = (1...4).compactMap { level in
            guard let raw = col_text_opt(stmt, Int32(7 + level)) else { return nil }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : (level, text)
        }

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

    // MARK: - Equipment (Optolith's weapon inventory)

    /// Entries never change at runtime, so each lookup is asked of SQLite once.
    /// Guarded because the singleton is reached from several threads.
    private let equipmentLock = NSLock()
    private nonisolated(unsafe) var equipmentById: [String: EquipmentEntry?] = [:]
    private nonisolated(unsafe) var equipmentByName: [String: EquipmentEntry?] = [:]
    private nonisolated(unsafe) var consecratedDeityByName: [String: String?] = [:]

    private static let equipmentColumns =
        "id, name, combat_technique, damage, at, pa, reach, note, advantage, disadvantage"

    /// The inventory template with this Optolith id ("ITEMTPL_19").
    func equipment(id: String) -> EquipmentEntry? {
        equipmentLock.lock()
        defer { equipmentLock.unlock() }
        if let cached = equipmentById[id] { return cached }
        let entry = queryEquipment(where: "id = ?", bind: id)
        equipmentById[id] = entry
        return entry
    }

    /// The inventory template called `name`. Names are not unique in Optolith
    /// — the Rabenschnabel is ITEMTPL_19 and ITEMTPL_796 — so of several the
    /// lowest template number wins: the core-rules one, which Optolith lists
    /// first. Prefer `equipment(id:)` whenever the hero's weapon carries its
    /// template id; for consecration use `consecratedDeity(forWeaponNamed:)`.
    func equipment(named name: String) -> EquipmentEntry? {
        equipmentLock.lock()
        defer { equipmentLock.unlock() }
        if let cached = equipmentByName[name] { return cached }
        let entry = queryEquipment(
            where: "name = ? ORDER BY CAST(substr(id, length('ITEMTPL_') + 1) AS INTEGER) LIMIT 1",
            bind: name)
        equipmentByName[name] = entry
        return entry
    }

    /// The deity a weapon of this name is consecrated to by default, if any
    /// `equipment` row of that name carries a "geweiht (X)" note.
    ///
    /// Read by name across all templates, not off one template: the Ulisses
    /// Regelwiki is the authority for weapons (owner ruling 2026-09-18) and has
    /// one Rabenschnabel page, "geweiht (Boron)". Optolith's duplicate
    /// templates may drop the note — its ITEMTPL_796 Rabenschnabel has the
    /// same stats and texts but none — and that is not a second, ordinary
    /// weapon as far as the app is concerned.
    func consecratedDeity(forWeaponNamed name: String) -> String? {
        equipmentLock.lock()
        defer { equipmentLock.unlock() }
        if let cached = consecratedDeityByName[name] { return cached }
        let sql = """
            SELECT note FROM equipment WHERE name = ? AND substr(note, 1, 9) = 'geweiht ('
            ORDER BY CAST(substr(id, length('ITEMTPL_') + 1) AS INTEGER) LIMIT 1
            """
        var deity: String?
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                deity = EquipmentEntry.consecratedDeity(inNote: col_text_opt(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        consecratedDeityByName[name] = deity
        return deity
    }

    private func queryEquipment(where clause: String, bind: String) -> EquipmentEntry? {
        let sql = "SELECT \(Self.equipmentColumns) FROM equipment WHERE \(clause)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, bind, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return EquipmentEntry(
            id: col_text(stmt, 0),
            name: col_text(stmt, 1),
            combatTechniqueId: col_text_opt(stmt, 2),
            damage: col_text_opt(stmt, 3),
            at: col_int_opt(stmt, 4),
            pa: col_int_opt(stmt, 5),
            reach: col_int_opt(stmt, 6),
            note: nonEmpty(col_text_opt(stmt, 7)),
            advantage: nonEmpty(col_text_opt(stmt, 8)),
            disadvantage: nonEmpty(col_text_opt(stmt, 9))
        )
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    // MARK: - Catalog

    private static let catalogColumns =
        "rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on, name"

    private func catalogEntry(from stmt: OpaquePointer?) -> CatalogEntry? {
        guard let status = CatalogStatus(rawValue: col_text(stmt, 1)) else { return nil }
        let file = col_text_opt(stmt, 3)
        let symbol = col_text_opt(stmt, 4)
        let pointer: CatalogPointer? = if let file, let symbol { CatalogPointer(file: file, symbol: symbol) } else { nil }
        return CatalogEntry(
            id: col_text(stmt, 0),
            name: col_text(stmt, 7),
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

    /// The one loop behind every list of catalog entries: prepare, bind the
    /// optional text at index 1, read. A statement that will not prepare says
    /// so — an empty list is otherwise indistinguishable from an empty table,
    /// which is the same silence that hides the `allCombatTechniqueIds()` flake.
    private func catalogEntries(sql: String, bind: String? = nil) -> [CatalogEntry] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("RulesDatabase: \(sql) failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        if let bind { sqlite3_bind_text(stmt, 1, bind, -1, SQLITE_TRANSIENT) }
        var results: [CatalogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = catalogEntry(from: stmt) { results.append(entry) }
        }
        return results
    }

    func catalogEntries(status: CatalogStatus) -> [CatalogEntry] {
        catalogEntries(sql: "SELECT \(Self.catalogColumns) FROM catalog WHERE status = ? ORDER BY rule_id",
                       bind: status.rawValue)
    }

    /// The entries whose id starts with `prefix` — `GRW_` for the core rules
    /// that have no `rules` row. Compared by `substr`, not `LIKE`: in a `LIKE`
    /// pattern the `_` in `GRW_` is a single-character wildcard.
    func catalogEntries(idPrefix prefix: String) -> [CatalogEntry] {
        catalogEntries(sql: "SELECT \(Self.catalogColumns) FROM catalog WHERE substr(rule_id, 1, length(?1)) = ?1 ORDER BY rule_id",
                       bind: prefix)
    }

    /// Every entry, for the not-applied list.
    func allCatalogEntries() -> [CatalogEntry] {
        catalogEntries(sql: "SELECT \(Self.catalogColumns) FROM catalog ORDER BY rule_id")
    }

    /// The SHA-256 of the vocabulary JSON the bundled database was validated
    /// against, so a test can tell a database that lags behind `RuleVocabulary`.
    func catalogVocabularyHash() -> String? {
        let sql = "SELECT value FROM catalog_meta WHERE key = 'vocabulary_sha256'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }

    /// Every `implemented` entry with its clauses decoded. The build validated
    /// the JSON, so a decode failure here means the Swift vocabulary and the
    /// exported one have drifted; the entry is skipped and the count test
    /// (`RuleCatalogDecodingTests.testEveryImplementedEntryDecodes`) catches it.
    /// A skipped rule is printed as well as asserted, so a Release build that
    /// quietly drops one still leaves a trace of which one and why.
    func implementedRules() -> [CatalogRule] {
        let sql = "SELECT rule_id, name, reviewed_by, applies_with, clauses FROM catalog WHERE status = 'implemented' ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("RulesDatabase: \(sql) failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        let decoder = JSONDecoder()
        var rules: [CatalogRule] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = col_text(stmt, 0)
            do {
                let applies = try col_text_opt(stmt, 3).map { try decoder.decode(RulePredicate.self, from: Data($0.utf8)) }
                let clauses = try decoder.decode([RuleClause].self, from: Data(col_text(stmt, 4).utf8))
                rules.append(CatalogRule(id: id, name: col_text(stmt, 1), reviewed: col_text_opt(stmt, 2) != nil,
                                         appliesWith: applies, clauses: clauses))
            } catch {
                print("RulesDatabase: \(id): clauses do not decode: \(error)")
                assertionFailure("\(id): clauses do not decode: \(error)")
            }
        }
        return rules
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

    /// The SHA-256 of the catalog YAML the bundled database was built from, so a
    /// test can tell a database that lags behind `specs/data/rules-catalog.yaml`.
    func catalogSourceHash() -> String? {
        let sql = "SELECT value FROM catalog_meta WHERE key = 'source_sha256'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }

    /// The number of rules in `rules`, for tests that hold a count to the database
    /// rather than to a number typed in the test. -1 means the query itself could
    /// not be prepared (a malformed database), which no rule count would ever be.
    func ruleCount() -> Int {
        let sql = "SELECT COUNT(*) FROM rules"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return -1 }
        return Int(sqlite3_column_int(stmt, 0))
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
