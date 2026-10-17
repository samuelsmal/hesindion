import Foundation

/// The version string in the sidebar footer.
///
/// Behind a type with an override because the footer is rendered inside
/// `HeroListViewSnapshotTests`, so every build-number bump invalidated two
/// baselines that had nothing to do with the change under review. Re-recording a
/// baseline for an unrelated reason is how a real regression gets waved through,
/// so the snapshot host pins the string instead.
enum AppVersion {
    /// Set by the snapshot host. Never set in the app.
    static var overrideForTesting: String?

    static var display: String {
        if let overrideForTesting { return overrideForTesting }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}
