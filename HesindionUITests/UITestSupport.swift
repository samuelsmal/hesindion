import CoreGraphics
import XCTest

/// Launch and query plumbing shared by the UI tests.
///
/// The app is German-first, so labels queried here are German on purpose.
enum UITest {

    /// Enables the debug-only seeded store (see `UITestSeed` in the app target).
    static let seedArgument = "-uitest-seed-hero"

    static let timeout: TimeInterval = 30
    /// Short timeout for "did this branch happen?" probes inside a retry loop.
    static let probeTimeout: TimeInterval = 5

    /// Launches the app on the seeded store with the first hero already selected.
    ///
    /// `path` reuses the app's existing `DebugLaunch` navigation hook — `"combat"`
    /// opens the combat full-screen cover straight away.
    @MainActor
    static func launch(path: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [seedArgument, "debug", "load_default"]
        if let path { app.launchArguments += ["path", path] }
        app.launch()
        return app
    }
}

@MainActor
extension XCUIApplication {

    /// A button whose accessibility label contains `text`. Buttons in this app pair an
    /// SF Symbol with a label, so the accessibility label is not always exactly the text.
    func button(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// The widest scroll view on screen — on iPad the sidebar is a scroll view too, and
    /// the content the tests need to reach is always in the detail pane.
    var widestScrollView: XCUIElement {
        let all = scrollViews.allElementsBoundByIndex.filter(\.exists)
        return all.max(by: { $0.frame.width < $1.frame.width }) ?? scrollViews.firstMatch
    }

    /// Scrolls the detail pane until `element` can be tapped, or gives up.
    @discardableResult
    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 12) -> Bool {
        let scrollView = widestScrollView
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            guard scrollView.exists else { return false }
            scrollView.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Opens the command palette — the only route to the hero settings screen.
    ///
    /// Two routes, because neither is reliable on its own: ⌘K needs the detail pane
    /// to own the responder chain and the simulator to deliver the key event, and the
    /// pull-down over-scroll needs a drag long enough to clear the app's 120pt
    /// threshold. Both are real user gestures.
    @discardableResult
    func openCommandPalette() -> XCUIElement {
        let field = textFields["commandPalette.search"]

        // Nothing responds until the hero detail pane (a scroll view) is on screen.
        _ = scrollViews.firstMatch.waitForExistence(timeout: UITest.timeout)

        for _ in 0..<3 {
            typeKey("k", modifierFlags: .command)
            if field.waitForExistence(timeout: UITest.probeTimeout) { return field }
        }

        for _ in 0..<3 {
            overScrollDetailPane()
            if field.waitForExistence(timeout: UITest.probeTimeout) { return field }
        }
        return field
    }

    /// Slow pull-down on the detail pane, held at the bottom — the app opens the
    /// command palette once the content is dragged more than 120pt past the top.
    private func overScrollDetailPane() {
        let scrollView = widestScrollView
        guard scrollView.exists else { return }
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
    }
}

@MainActor
extension XCTestCase {

    /// Attaches a full-screen screenshot that survives a passing test run, so
    /// `xcresulttool export attachments` can pull it out afterwards.
    func captureScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
