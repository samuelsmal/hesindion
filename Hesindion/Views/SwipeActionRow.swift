import SwiftUI

// MARK: - SwipeActionRow

/// A single trailing swipe action revealed by dragging a `SwipeActionRow` left.
struct SwipeAction {
    let icon: String
    let color: Color
    let action: () -> Void
}

/// A full-width row whose trailing action buttons are revealed by a left drag
/// (56pt per button; dragging past 120pt auto-triggers the last action). This is the
/// app's shared drag-to-reveal edit interaction, used across HeroDetailView
/// (advantages/talents/spells/abilities/attributes) and the hero-detail states section.
struct SwipeActionRow<Content: View>: View {
    let actions: [SwipeAction]
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var settled: Bool = false
    @State private var dragDirection: DragDirection = .undecided

    private var revealWidth: CGFloat { CGFloat(actions.count) * 56 }
    private let triggerThreshold: CGFloat = 120

    private enum DragDirection { case undecided, horizontal, vertical }

    /// Convenience initializer for simple label/value rows.
    init(label: String, value: String, actions: [SwipeAction]) where Content == DefaultSwipeContent {
        self.actions = actions
        self.content = DefaultSwipeContent(label: label, value: value)
    }

    /// Generic initializer for arbitrary content.
    init(actions: [SwipeAction], @ViewBuilder content: () -> Content) {
        self.actions = actions
        self.content = content()
    }

    var body: some View {
        if actions.isEmpty {
            foregroundContent
        } else {
            ZStack(alignment: .trailing) {
                // Background action buttons
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        Button {
                            withAnimation(DSAAnimation.standard) { offset = 0 }
                            settled = false
                            action.action()
                        } label: {
                            Image(systemName: action.icon)
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56)
                                .frame(maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .background(action.color)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(actions.last?.color ?? .gray)

                foregroundContent
                    .offset(x: offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 16)
                            .onChanged { value in
                                guard !settled else { return }
                                if dragDirection == .undecided {
                                    let dx = abs(value.translation.width)
                                    let dy = abs(value.translation.height)
                                    if dx > dy * 1.5 && value.translation.width < 0 {
                                        dragDirection = .horizontal
                                    } else if dy > dx {
                                        dragDirection = .vertical
                                    }
                                }
                                if dragDirection == .horizontal {
                                    offset = min(0, value.translation.width)
                                }
                            }
                            .onEnded { value in
                                defer { dragDirection = .undecided }
                                guard !settled, dragDirection == .horizontal else { return }
                                if -offset > triggerThreshold, let last = actions.last {
                                    withAnimation(DSAAnimation.standard) { offset = 0 }
                                    last.action()
                                } else if -offset > revealWidth / 2 {
                                    withAnimation(DSAAnimation.standard) { offset = -revealWidth }
                                    settled = true
                                } else {
                                    withAnimation(DSAAnimation.standard) { offset = 0 }
                                }
                            }
                    )
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if settled {
                    withAnimation(DSAAnimation.standard) { offset = 0 }
                    settled = false
                }
            }
        }
    }

    private var foregroundContent: some View {
        content
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
    }
}

/// Default content for SwipeActionRow label/value variant.
struct DefaultSwipeContent: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(L(label)).font(.body)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(.body, design: .monospaced))
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }
}
