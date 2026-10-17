import Foundation
import SwiftUI

enum DebugLaunch {
    static let isDebug = ProcessInfo.processInfo.arguments.contains("debug")
    static let loadDefault = ProcessInfo.processInfo.arguments.contains("load_default")

    static var path: String? {
        value(for: "path")
    }

    /// Pins the colour scheme for screenshot tests; `nil` follows the system.
    ///
    /// The screenshot harness needs this because `XCUIDevice.shared.appearance`
    /// does not take effect on the pinned simulator — set before launch it races
    /// the app's start, and set afterwards it never arrives. Forcing the scheme
    /// in-process is deterministic, and dark mode has to be photographed: it is
    /// the only path where `dsaBorder` and the shadow that follows it invert.
    static var appearance: ColorScheme? {
        switch value(for: "appearance") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    private static func value(for key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: key), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }
}
