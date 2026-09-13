import SwiftData
import SwiftUI

struct HeroSettingsView: View {
    @Query(sort: \Adventure.createdAt, order: .reverse) private var adventures: [Adventure]
    @Bindable var hero: Hero
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("colorScheme"))
                        .font(.dsaHeading(.title3))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    schemeRow(
                        scheme: nil,
                        label: L("colorSchemeAutomatic"),
                        isSelected: hero.colorSchemeId == nil
                    )

                    ForEach(HeroColorScheme.allSchemes) { scheme in
                        schemeRow(
                            scheme: scheme,
                            label: scheme.name,
                            isSelected: hero.colorSchemeId == scheme.id
                        )
                    }
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 16) {
                    Text(L("adventures"))
                        .font(.dsaHeading(.title3))
                        .padding(.horizontal, 16)

                    Picker(L("adventures"), selection: $hero.activeAdventure) {
                        Text("—").tag(Adventure?.none)
                        ForEach(adventures, id: \.persistentModelID) { adventure in
                            Text(adventure.name).tag(Adventure?.some(adventure))
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)

                // The optional Fokus-Regeln are the table's house rules, so they are a
                // per-hero setting that outlives any single combat — not a per-fight
                // choice made on the way into a fight.
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("fokus.section"))
                        .font(.dsaHeading(.title3))
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier("heroSettings.fokusRules")

                    ForEach(FokusRule.allCases) { rule in
                        fokusRuleRow(rule)

                        // Switching Trefferzonen on is the moment the size
                        // matters, so that is where the app asks for it — rather
                        // than guessing from the hero's height, which is not what
                        // the rule keys on.
                        if rule == .trefferzonen, hero.isFokusRuleActive(.trefferzonen) {
                            hitZoneSizeRow
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private var header: some View {
        HStack {
            Button(action: dismiss) {
                Text(L("close"))
                    .font(.dsaBody(.body))
            }
            Spacer()
            Text(L("heroSettings"))
                .font(.dsaHeading(.headline))
            Spacer()
            Text(L("close"))
                .font(.dsaBody(.body))
                .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: DSALayout.border)
                .foregroundStyle(Color.dsaBorder)
        }
    }

    /// The hero's own Trefferzonen table. Defaulted from the species where the
    /// rules name one, asked for otherwise — and always overridable, because the
    /// list cannot cover every species a table might use.
    private var hitZoneSizeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("hitZoneSize.title"))
                .font(.dsaHeading(.caption))
            Text(L("hitZoneSize.subtitle"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)

            if hero.needsHitZoneSize {
                Text(L("hitZoneSize.unknown"))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(Color.groupCombat)
            }

            HStack(spacing: 8) {
                ForEach([CreatureSize.klein, .mittel, .gross]) { size in
                    let isSelected = hero.sizeCategory == size
                    Button { hero.hitZoneSize = size.rawValue } label: {
                        Text(L(size.nameKey))
                            .font(.dsaBody(.caption))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.groupCombat : Color(UIColor.secondarySystemBackground))
                            .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)
                    .accessibilityIdentifier("heroSettings.hitZoneSize.\(size.rawValue)")
                }
            }
            .dsaOptionGroup()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("heroSettings.hitZoneSize")
    }

    private func fokusRuleRow(_ rule: FokusRule) -> some View {
        DSAToggleRow(
            title: L(rule.nameKey),
            isOn: Binding(
                get: { hero.isFokusRuleActive(rule) },
                set: { hero.setFokusRule(rule, active: $0) }
            ),
            accent: .groupCombat,
            subtitle: L(rule.subtitleKey)
        )
        .padding(.horizontal, 16)
    }

    private func schemeRow(scheme: HeroColorScheme?, label: String, isSelected: Bool) -> some View {
        Button {
            hero.colorSchemeId = scheme?.id
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    let colors = scheme?.sectionColors ?? HeroColorScheme.schemeForProfession(hero.personalData?.profession ?? "").sectionColors
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(colors[i])
                            .frame(width: 20, height: 32)
                    }
                }
                .dsaBox(.flush)

                Text(label)
                    .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.dsaMotion)
    }
}
