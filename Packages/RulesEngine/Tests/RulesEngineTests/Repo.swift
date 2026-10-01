import Foundation

enum Repo {
    /// Tests/RulesEngineTests/Repo.swift → repository root.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func url(_ path: String) -> URL { root.appending(path: path) }
}
