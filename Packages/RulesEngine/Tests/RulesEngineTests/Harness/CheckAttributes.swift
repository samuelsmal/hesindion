import Foundation
import SQLite3

/// The three attributes of every talent's and spell's Probe, as the app reads them: rules.db
/// `skill_details` / `spell_details`, `check_attr_1–3` (fertigkeitsproben.FP1, TAL_7.probe). The
/// engine reads no database; the harness, like the app, is the check procedure's caller and hands
/// them in (`CheckRequest.attributes`).
enum CheckAttributes {
    /// Optolith's attribute ids → the sheet's names, as rulec's hero import maps them
    /// (`scripts/rulec/hero.py` `ATTR`): the facts `attr.<name>`.
    static let names = ["ATTR_1": "MU", "ATTR_2": "KL", "ATTR_3": "IN", "ATTR_4": "CH",
                        "ATTR_5": "FF", "ATTR_6": "GE", "ATTR_7": "KO", "ATTR_8": "KK"]

    /// Talent or spell id → its three attributes. Empty when rules.db is missing.
    static let all: [String: [String]] = load(Repo.url("Hesindion/Resources/rules.db"))

    static func load(_ url: URL) -> [String: [String]] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }
        var out: [String: [String]] = [:]
        for table in ["skill_details", "spell_details"] {
            var statement: OpaquePointer?
            let sql = "SELECT rule_id, check_attr_1, check_attr_2, check_attr_3 FROM \(table)"
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                let columns = (0..<4).map { i in sqlite3_column_text(statement, Int32(i)).map { String(cString: $0) } }
                guard let id = columns[0] else { continue }
                let attributes = columns.dropFirst().compactMap { $0.flatMap { names[$0] } }
                if attributes.count == 3 { out[id] = attributes }
            }
        }
        return out
    }
}
