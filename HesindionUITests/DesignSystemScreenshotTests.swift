import XCTest

/// Screenshots of the core surfaces in both appearances, so a design-system
/// change can be reviewed as a before/after diff of `docs/screenshots/`.
///
/// Dark mode earns its own captures because two tokens invert there and nothing
/// else exercises them: `dsaBorder` is white on dark, and so is the hard offset
/// shadow that follows it (ADR-0008). A light-only capture would show neither.
///
/// Appearance and sidebar state come from the app's `DebugLaunch` hooks rather
/// than from `XCUIDevice`/gestures — see `UITest.launch`.
///
/// Filenames match the ones already tracked in `docs/screenshots/`, so each
/// capture replaces its predecessor and GitHub renders the pair 2-up.
final class DesignSystemScreenshotTests: XCTestCase {

    @MainActor
    private func awaitHeroDetail(_ app: XCUIApplication) {
        XCTAssertTrue(
            app.scrollViews.firstMatch.waitForExistence(timeout: UITest.timeout),
            "Hero detail did not appear"
        )
    }

    /// On the pinned 11-inch iPad in portrait the split view lays the sidebar
    /// over the detail pane, covering the attribute column.
    ///
    /// Collapsing it is best-effort and deliberately test-side only: the
    /// alternative — starting the split view at `.detailOnly` via a launch
    /// argument — changes how `NavigationSplitView` is constructed for every
    /// user and broke two `HeroListViewSnapshotTests`. Better framing is not
    /// worth a production rendering change, so if the toggle is not reachable
    /// the capture simply includes the sidebar.
    @MainActor
    private func collapseSidebar(_ app: XCUIApplication) {
        let toggle = app.buttons["ToggleSidebar"]
        guard toggle.waitForExistence(timeout: UITest.probeTimeout), toggle.isHittable else { return }
        toggle.tap()
        Thread.sleep(forTimeInterval: 0.8)
    }

    @MainActor
    private func awaitCombatRoot(_ app: XCUIApplication) {
        XCTAssertTrue(
            app.button(containing: "Angriff").waitForExistence(timeout: UITest.timeout),
            "Combat root did not appear"
        )
    }

    // MARK: - Hero detail

    @MainActor
    func testHeroDetailLight() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "light")
        awaitHeroDetail(app)
        collapseSidebar(app)
        captureScreenshot(app, named: "hero-detail-light")
    }

    @MainActor
    func testHeroDetailDark() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "dark")
        awaitHeroDetail(app)
        collapseSidebar(app)
        captureScreenshot(app, named: "hero-detail-dark")
    }

    // MARK: - Combat root

    @MainActor
    func testCombatRootLight() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", appearance: "light")
        awaitCombatRoot(app)
        captureScreenshot(app, named: "combat-root")
    }

    @MainActor
    func testCombatRootDark() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", appearance: "dark")
        awaitCombatRoot(app)
        captureScreenshot(app, named: "combat-root-dark")
    }
}
