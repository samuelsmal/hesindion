import SwiftUI
import UIKit

/// A notice about a change the app wrote by itself, on no screen of its own
/// (ADR-0018 §2) — styled after https://www.neobrutalism.dev/docs/toast: a
/// raised box with a title and its lines, closing by itself after four
/// seconds (the reference's default) or at a tap.
///
/// A new notice replaces the one on screen: each carries its own `id`, and the
/// timer is keyed on it, so a second round within four seconds still gets its
/// full four seconds.
struct DSAToastContent: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let lines: [String]
}

extension View {
    /// Shows `content` at the top edge while it is non-nil, and sets it back
    /// to nil when the toast closes.
    func dsaToast(_ content: Binding<DSAToastContent?>, accent: Color = .groupCombat) -> some View {
        modifier(DSAToastModifier(content: content, accent: accent))
    }
}

private struct DSAToastModifier: ViewModifier {
    @Binding var content: DSAToastContent?
    let accent: Color

    static let duration: Duration = .seconds(4)

    func body(content view: Content) -> some View {
        view.overlay(alignment: .top) {
            if let toast = content {
                DSAToast(content: toast, accent: accent)
                    .padding(.horizontal, DSALayout.horizontalPadding)
                    .padding(.top, 8)
                    .onTapGesture { close(toast) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: Self.duration)
                        close(toast)
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: content?.id)
    }

    /// Closes only the toast that asked: a timer that outlived its toast must
    /// not close the one that replaced it.
    private func close(_ toast: DSAToastContent) {
        if content?.id == toast.id { content = nil }
    }
}

struct DSAToast: View {
    let content: DSAToastContent
    var accent: Color = .groupCombat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.title)
                .font(.dsaHeading(.headline))
                .foregroundStyle(accent)
            ForEach(content.lines, id: \.self) { line in
                Text(line)
                    .font(.dsaMono(.subheadline, emphasis: true))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSALayout.contentPadding)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("toast")
    }
}
