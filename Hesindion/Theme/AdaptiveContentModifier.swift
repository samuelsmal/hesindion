import SwiftUI

struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .frame(maxWidth: DSALayout.iPadMaxContentWidth)
                .frame(maxWidth: .infinity)
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
