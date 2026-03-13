import SwiftUI

struct ContentWithNotesLayout<Content: View>: View {
    let hero: Hero
    @Binding var showNotes: Bool
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isVisible: Bool {
        sizeClass == .regular && showNotes
    }

    var body: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)

            if sizeClass == .regular {
                NotesPanelView(hero: hero)
                    .frame(width: isVisible ? nil : 0)
                    .frame(maxWidth: isVisible ? 400 : 0)
                    .clipped()
            }
        }
    }
}
