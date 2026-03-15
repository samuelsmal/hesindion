import Foundation

enum DebugLaunch {
    static let isDebug = ProcessInfo.processInfo.arguments.contains("debug")
    static let loadDefault = ProcessInfo.processInfo.arguments.contains("load_default")

    static var path: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "path"), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }
}
