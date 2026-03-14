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
        VStack(spacing: 0) {
            ZStack {
                content
                    .frame(maxWidth: .infinity)

                if let panel = activePanel {
                    panelView(for: panel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                        .transition(.move(edge: .bottom))
                }
            }

            portraitTabBar
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

    // MARK: - Landscape Toggle Buttons (vertical, right edge, flush)

    private var panelToggleButtons: some View {
        VStack(spacing: 0) {
            panelButton(.notes, icon: "note.text", activeIcon: "note.text.badge.plus")
            panelButton(.logs, icon: "list.bullet.rectangle", activeIcon: "list.bullet.rectangle.fill")
            panelButton(.rules, icon: "book.closed", activeIcon: "book.closed.fill")
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.secondaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
    }

    // MARK: - Portrait Tab Bar (horizontal, bottom)

    private var portraitTabBar: some View {
        HStack(spacing: 0) {
            panelButton(.notes, icon: "note.text", activeIcon: "note.text.badge.plus")
                .frame(maxWidth: .infinity)
            panelButton(.logs, icon: "list.bullet.rectangle", activeIcon: "list.bullet.rectangle.fill")
                .frame(maxWidth: .infinity)
            panelButton(.rules, icon: "book.closed", activeIcon: "book.closed.fill")
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: DSALayout.tertiaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
    }

    private func panelColor(for panel: SidePanel) -> Color {
        switch panel {
        case .notes: .panelNotes
        case .logs:  .panelLogs
        case .rules: .panelRules
        }
    }

    private func panelButton(_ panel: SidePanel, icon: String, activeIcon: String) -> some View {
        let isActive = activePanel == panel
        return Button {
            withAnimation(DSAAnimation.standard) {
                if activePanel == panel {
                    activePanel = nil
                } else {
                    activePanel = panel
                }
            }
        } label: {
            Image(systemName: isActive ? activeIcon : icon)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(isActive ? .white : panelColor(for: panel))
                .frame(width: 48, height: 48)
                .background(isActive ? panelColor(for: panel) : .clear)
                .overlay(
                    Rectangle()
                        .stroke(panelColor(for: panel), lineWidth: isActive ? 0 : DSALayout.secondaryBorder)
                )
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
