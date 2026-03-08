import SwiftUI

struct RuleDetailView: View {
    let ruleId: String
    @Binding var sidebarSelection: SidebarSelection?
    let previousSelection: SidebarSelection?

    private var rule: RuleDetail? {
        RulesDatabase.shared.lookup(id: ruleId)
    }

    var body: some View {
        if let rule {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let prev = previousSelection {
                        Button {
                            sidebarSelection = prev
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(backLabel(prev))
                            }
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(Color.groupRulebook)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    Text(rule.name)
                        .font(.system(.largeTitle, weight: .black))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.groupRulebook)
                        .foregroundStyle(.white)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            metaBadge(categoryLabel(rule.category))
                            if let cost = rule.cost {
                                metaBadge("AP: \(cost)")
                            }
                            if let levels = rule.levels {
                                metaBadge("Stufen: \(levels)")
                            }
                        }

                        if let spell = rule.spellDetail {
                            spellMetaBlock(spell, isLiturgy: rule.category == "liturgy")
                        }

                        if !rule.description.isEmpty {
                            Text(markdownDescription(rule.description))
                                .font(.body)
                        }

                        if !rule.effects.isEmpty {
                            Text(L("effects"))
                                .font(.system(.subheadline, weight: .black))
                                .padding(.top, 4)

                            ForEach(Array(rule.effects.enumerated()), id: \.offset) { _, effect in
                                effectRow(effect)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        } else {
            ContentUnavailableView(
                L("ruleNotFound"),
                systemImage: "book.closed",
                description: Text(L("ruleLoadError"))
            )
        }
    }

    private func backLabel(_ sel: SidebarSelection) -> String {
        switch sel {
        case .hero: L("backToHero")
        case .rulebook: L("backToRulebook")
        default: L("back")
        }
    }

    private func metaBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.groupRulebook.opacity(0.2))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private func effectRow(_ effect: RuleEffect) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let level = effect.level {
                Text("Stufe \(level)")
                    .font(.system(.caption, weight: .bold))
                    .frame(width: 56, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(effect.type)
                        .font(.system(.caption, weight: .bold))
                    if let attr = effect.attribute {
                        Text(attr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let val = effect.value {
                        Text(val >= 0 ? "+\(Int(val))" : "\(Int(val))")
                            .font(.system(.caption, weight: .bold))
                            .fontDesign(.monospaced)
                    }
                }
                if let desc = effect.description {
                    Text(markdownDescription(desc))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupRulebook.opacity(0.08))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private func spellMetaBlock(_ spell: SpellDetail, isLiturgy: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let c1 = spell.checkAttr1,
               let c2 = spell.checkAttr2,
               let c3 = spell.checkAttr3 {
                spellMetaRow(L("spellCheck"), "\(c1)/\(c2)/\(c3)")
            }
            if let ic = spell.improvementCost {
                spellMetaRow(L("spellIC"), ic)
            }
            if let ct = spell.castingTime {
                spellMetaRow(isLiturgy ? L("liturgyTime") : L("spellCastingTime"), ct)
            }
            if let cost = spell.aeCost {
                spellMetaRow(isLiturgy ? L("liturgyCost") : L("spellAeCost"), cost)
            }
            if let range = spell.range {
                spellMetaRow(L("spellRange"), range)
            }
            if let dur = spell.duration {
                spellMetaRow(L("spellDuration"), dur)
            }
            if let target = spell.target {
                spellMetaRow(L("spellTarget"), target)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupRulebook.opacity(0.08))
        .overlay(Rectangle().stroke(Color.black, lineWidth: DSALayout.tertiaryBorder))
    }

    private func spellMetaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(.caption, weight: .bold))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private func markdownDescription(_ text: String) -> AttributedString {
        let cleaned = text.replacingOccurrences(of: "<br>", with: "\n")
        return (try? AttributedString(markdown: cleaned)) ?? AttributedString(cleaned)
    }

    private func categoryLabel(_ category: String) -> String {
        L("cat.\(category)")
    }
}
