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
                        .font(.system(.title3, weight: .black))
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
                        .font(.system(.title3, weight: .black))
                        .padding(.horizontal, 16)

                    Picker(L("adventures"), selection: $hero.activeAdventure) {
                        Text("—").tag(Adventure?.none)
                        ForEach(adventures, id: \.persistentModelID) { adventure in
                            Text(adventure.name).tag(Adventure?.some(adventure))
                        }
                    }
                    .padding(.horizontal, 16)
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
                    .font(.system(.body, weight: .bold))
            }
            Spacer()
            Text(L("heroSettings"))
                .font(.system(.headline, weight: .black))
            Spacer()
            Text(L("close"))
                .font(.system(.body, weight: .bold))
                .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: DSALayout.secondaryBorder)
                .foregroundStyle(Color.dsaBorder)
        }
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
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(label)
                    .font(.system(.body, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
