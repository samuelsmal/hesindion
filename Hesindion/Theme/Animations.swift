import SwiftUI

enum DSAAnimation {
    // MARK: - Dice tumble

    /// Nanoseconds between dice face changes during tumble animation.
    static let diceTumbleInterval: UInt64 = 150_000_000 // 150ms

    // MARK: - UI transitions

    /// Standard animation for collapsible sections, swipe resets, and step transitions.
    static let standard: Animation = .easeOut(duration: 0.2)

    /// The press "move into the shadow" (ADR-0008). Short enough to feel like a
    /// physical press rather than an animation.
    static let press: Animation = .easeOut(duration: 0.07)

    // MARK: - Opacity

    /// Opacity for the "dice tumbling" background tint.
    static let animatingBackgroundOpacity: Double = 0.15
}
