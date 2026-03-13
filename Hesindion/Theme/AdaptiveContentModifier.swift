import SwiftUI

struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(width * DSALayout.iPadProportionalFraction, DSALayout.iPadMaxContentWidth)
                }
        } else {
            content
                .padding(.horizontal, DSALayout.horizontalPadding)
        }
    }
}

extension View {
    func adaptiveContentWidth() -> some View {
        modifier(AdaptiveContentWidth())
    }
}
