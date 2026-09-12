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
        captureScreenshot(app, named: "02-hero-detail-light")
    }

    @MainActor
    func testHeroDetailDark() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "dark")
        awaitHeroDetail(app)
        collapseSidebar(app)
        captureScreenshot(app, named: "03-hero-detail-dark")
    }

    // MARK: - Combat root

    @MainActor
    func testCombatRootLight() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", appearance: "light")
        awaitCombatRoot(app)
        captureScreenshot(app, named: "07-combat-root-light")
    }

    // MARK: - Take damage

    /// The TP stepper is a segmented control, so it is the screen that shows
    /// whether the shadow scope reads correctly on joined segments.
    @MainActor
    func testTakeDamage() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", appearance: "light")
        awaitCombatRoot(app)
        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Take-damage action missing")
        takeDamage.tap()
        XCTAssertTrue(
            app.buttons["combat.takeDamage.increaseTP"].waitForExistence(timeout: UITest.timeout),
            "Take-damage screen did not open"
        )
        captureScreenshot(app, named: "11-take-damage-entry")
    }

    @MainActor
    func testCombatRootDark() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", appearance: "dark")
        awaitCombatRoot(app)
        captureScreenshot(app, named: "08-combat-root-dark")
    }

    // MARK: - Sidebar, adventure weather, dice roller

    /// The sidebar itself — the last surface that was still rendering as stock
    /// `List` rows, so it is worth a capture of its own.
    @MainActor
    func testHeroList() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "light")
        awaitHeroDetail(app)
        captureScreenshot(app, named: "01-hero-list")
    }

    /// The weather table, reached through the seeded adventure. Its rows come
    /// from `UITestSeed`'s fixed week rather than from `WeatherGenerator`, which
    /// rolls dice — a generated table would differ on every run and could never
    /// be compared against its predecessor.
    @MainActor
    func testAdventureWeather() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "light")
        awaitHeroDetail(app)

        let asButton = app.button(containing: UITest.adventureName)
        let row = asButton.waitForExistence(timeout: UITest.probeTimeout)
            ? asButton
            : app.staticTexts[UITest.adventureName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "Seeded adventure not in the sidebar")
        row.tap()

        XCTAssertTrue(
            app.staticTexts[UITest.adventureName].waitForExistence(timeout: UITest.timeout),
            "Adventure detail did not open"
        )
        captureScreenshot(app, named: "05-adventure-weather")
    }

    /// The dice roller, whose stepper was the one with unequal thirds before
    /// `DSAStepper`.
    @MainActor
    func testDiceRoller() {
        continueAfterFailure = false
        let app = UITest.launch(appearance: "light")
        let field = app.openCommandPalette()
        XCTAssertTrue(field.waitForExistence(timeout: UITest.timeout), "Command palette did not open")
        field.typeText("Würfeln")

        let command = app.button(containing: "Würfeln")
        XCTAssertTrue(command.waitForExistence(timeout: UITest.timeout), "Dice command not offered")
        command.tap()

        XCTAssertTrue(
            app.staticTexts["W6"].waitForExistence(timeout: UITest.timeout),
            "Dice roll sheet did not open"
        )
        captureScreenshot(app, named: "06-dice-roller")
    }
}
