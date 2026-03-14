import SwiftUI
import MarkdownUI

struct ChangelogView: View {
    private let markdownContent: String

    init() {
        if let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
           let content = try? String(contentsOf: url) {
            self.markdownContent = content
        } else {
            self.markdownContent = "Changelog nicht verfügbar."
        }
    }

    var body: some View {
        ScrollView {
            Markdown(markdownContent)
                .padding()
        }
        .navigationTitle("Changelog")
        .navigationBarTitleDisplayMode(.inline)
    }
}
