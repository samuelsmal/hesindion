import SwiftUI

// MARK: - SidePanel

enum SidePanel: String, CaseIterable {
    case notes
    case logs
    case rules
}

// MARK: - SplitContentLayout

struct SplitContentLayout<Content: View>: View {
    let hero: Hero
    @Binding var activePanel: SidePanel?
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isLandscape: Bool {
        sizeClass == .regular
    }

    var body: some View {
        if isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    // MARK: - Landscape (50/50 split)

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)

            if let panel = activePanel {
                panelView(for: panel)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .trailing) {
            panelToggleButtons
        }
    }

    // MARK: - Portrait (full-screen overlay)

    private var portraitLayout: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity)

            if let panel = activePanel {
                panelView(for: panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .trailing) {
            panelToggleButtons
        }
    }

    // MARK: - Panel Content

    @ViewBuilder
    private func panelView(for panel: SidePanel) -> some View {
        switch panel {
        case .notes:
            NotesPanelView(hero: hero)
        case .logs:
            LogPanelView(hero: hero)
        case .rules:
            RulebookPanelView()
        }
    }

    // MARK: - Toggle Buttons

    private var panelToggleButtons: some View {
        VStack(spacing: 0) {
            panelButton(.notes, icon: "note.text", activeIcon: "note.text.badge.plus")
            panelButton(.logs, icon: "list.bullet.rectangle", activeIcon: "list.bullet.rectangle.fill")
            panelButton(.rules, icon: "book.closed", activeIcon: "book.closed.fill")
        }
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.tertiaryBorder))
        .padding(.trailing, 8)
    }

    private func panelButton(_ panel: SidePanel, icon: String, activeIcon: String) -> some View {
        Button {
            withAnimation(DSAAnimation.standard) {
                if activePanel == panel {
                    activePanel = nil
                } else {
                    activePanel = panel
                }
            }
        } label: {
            Image(systemName: activePanel == panel ? activeIcon : icon)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(activePanel == panel ? Color.groupPersonalData : .primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RulebookPanelView

struct RulebookPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Regelwerk")
                .font(.system(.headline, weight: .black))
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.headerVerticalPadding)

            RulebookView(sidebarSelection: .constant(nil))
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.primaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
    }
}
