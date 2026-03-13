import SwiftUI
import SwiftData

struct NotesPanelView: View {
    @Bindable var hero: Hero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notizen")
                .font(.system(.headline, weight: .black))
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.headerVerticalPadding)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $hero.notes)
                    .scrollContentBackground(.hidden)
                    .padding(4)

                if hero.notes.isEmpty {
                    Text("Notizen hier eingeben...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.primaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
    }
}
