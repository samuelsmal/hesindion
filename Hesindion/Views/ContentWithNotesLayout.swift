import SwiftUI

struct ContentWithNotesLayout<Content: View>: View {
    let hero: Hero
    @Binding var showNotes: Bool
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular && showNotes {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity)

                NotesPanelView(hero: hero)
                    .containerRelativeFrame(.horizontal) { width, _ in
                        min(width * 0.38, 400)
                    }
            }
            .transition(.move(edge: .trailing))
        } else {
            content
        }
    }
}
