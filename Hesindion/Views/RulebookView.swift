import SwiftUI

struct RulebookView: View {
    @Binding var sidebarSelection: SidebarSelection?
    @State private var searchText = ""

    private let categoryOrder = [
        "advantage", "disadvantage", "special_ability",
        "combat_technique", "skill", "spell", "liturgy",
        "condition", "state"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(pinnedViews: [.sectionHeaders]) {
                headerBanner

                let results = groupedResults
                ForEach(categoryOrder, id: \.self) { category in
                    let rules = results[category] ?? []
                    if !rules.isEmpty {
                        CollapsibleSection(categoryLabel(category)) {
                            ForEach(rules) { rule in
                                Button {
                                    sidebarSelection = .rule(rule.id)
                                } label: {
                                    ruleRow(rule)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .searchable(text: $searchText, prompt: L("searchRules"))
        .environment(\.groupColor, .groupRulebook)
        .environment(\.groupTextColor, .white)
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        Text(L("rulebook"))
            .font(.system(.largeTitle, design: .default, weight: .black))
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupRulebook)
            .foregroundStyle(.white)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    private func ruleRow(_ rule: RuleSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule.name)
                .font(.body)
                .foregroundStyle(Color.primary)
            if !rule.description.isEmpty {
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    private var groupedResults: [String: [RuleSearchResult]] {
        if searchText.count >= 2 {
            let results = RulesDatabase.shared.search(query: searchText, limit: 50)
            return Dictionary(grouping: results, by: \.category)
        } else {
            var grouped: [String: [RuleSearchResult]] = [:]
            for cat in categoryOrder {
                grouped[cat] = RulesDatabase.shared.rulesByCategory(cat)
            }
            return grouped
        }
    }

    // MARK: - Helpers

    private func categoryLabel(_ category: String) -> String {
        L("cats.\(category)")
    }
}

#Preview {
    RulebookView(sidebarSelection: .constant(.rulebook))
}
