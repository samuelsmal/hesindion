import SwiftUI

// MARK: - DefenseRoute

/// Where a defence goes once its questions are answered. Pure, so the routing
/// the root used to do inline is tested without a view.
enum DefenseRoute {
    /// Whether the hero can parry an attacker of this size at all: a weapon
    /// parry where the Größenkategorie allows one, or else the shield in hand
    /// where it allows that (`SizeCategoryRules`).
    static func parryPossible(hero: Hero, size: CreatureSize) -> Bool {
        let allowed = SizeCategoryRules.allowedDefenses(against: size)
        return allowed.contains(.weaponParry) || (allowed.contains(.shieldParry) && hero.selectedShield != nil)
    }

    /// A parry the attacker's size rules out goes to Ausweichen instead; the
    /// screen disables its button first, so this is the fallback, not the path.
    /// Against a groß attacker the parry is the shield's, picked on the weapon
    /// list, which shows only the shield then.
    static func next(_ action: CombatAction, hero: Hero, size: CreatureSize, lines: [ModifierLine]) -> CombatStep {
        let total = lines.reduce(0) { $0 + $1.value }
        if action == .ausweichen {
            let aw = hero.derivedValues?.ausweichen.value ?? 0
            return .execution(.ausweichen, name: "Ausweichen", attributeValue: aw + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        guard parryPossible(hero: hero, size: size) else { return .defenseSetup(.ausweichen) }
        if hero.isDualWielding || hero.selectedShield != nil { return .weaponSelection(.parieren) }
        if let w = hero.selectedWeapon {
            // The grip's −1 is a modifier line, so the base must not carry it too.
            return .execution(.parieren, name: w.name, attributeValue: w.pa + hero.passiveShieldPABonus + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            return .execution(.parieren, name: "Raufen", attributeValue: (raufen?.pa ?? 0) + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
        return .weaponSelection(.parieren)
    }

    /// The value the defence is rolled against before its lines, or `nil`
    /// when the weapon list decides it per piece (a shield, two weapons, or no
    /// weapon chosen yet) or no parry is possible against this size.
    static func baseValue(_ action: CombatAction, hero: Hero, size: CreatureSize) -> Int? {
        if action == .ausweichen { return hero.derivedValues?.ausweichen.value ?? 0 }
        guard parryPossible(hero: hero, size: size) else { return nil }
        if hero.isDualWielding || hero.selectedShield != nil { return nil }
        if let w = hero.selectedWeapon { return w.pa + hero.passiveShieldPABonus }
        if hero.selectedWeaponName == "Raufen" {
            return hero.combatTechniques.first { $0.name == "Raufen" }?.pa ?? 0
        }
        return nil
    }
}

// MARK: - CombatDefenseSetupView

/// Parieren or Ausweichen, before the roll: who is attacking.
///
/// The attack side had its opponent questions on the announcement; a defence
/// was rolled straight from the root and so could only read whatever the last
/// announcement had stated — which the root clears. A mounted hero defending
/// against a foot soldier, an attack from behind, a better-placed hero: each
/// changes the VW, so each is asked here, and the result is on screen before
/// the dice.
///
/// The answers go onto `CombatView.opponent`, so the weapon list (shield or
/// two weapons) and the roll read the same profile; arriving back at the root
/// clears them.
struct CombatDefenseSetupView: View {
    let hero: Hero
    let action: CombatAction
    let situation: CombatSituation
    let mountedActive: Bool
    @Binding var opponent: OpponentProfile
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var isAusweichen: Bool { action == .ausweichen }

    /// A parry the attacker's size rules out (`SizeCategoryRules`).
    private var blocked: Bool {
        !isAusweichen && !DefenseRoute.parryPossible(hero: hero, size: opponent.size)
    }

    /// What the attacker's size leaves, shown under the size chips.
    private var restriction: String? {
        switch opponent.size {
        case .gross:  L("size.shieldOnly")
        case .riesig: L("size.dodgeOnly")
        case .winzig, .klein, .mittel: nil
        }
    }

    private var lines: [ModifierLine] {
        situation.defenseModifiers(hero: hero, isAusweichen: isAusweichen, opponents: OpponentRoster([opponent]))
    }

    var body: some View {
        VStack(spacing: 0) {
            combatScreenHeader(
                title: L(isAusweichen ? "dodge" : "parry"),
                onBack: { step = .root },
                onDismiss: onDismiss
            )

            ScrollView {
                VStack(spacing: 8) {
                    combatSectionLabel(L("defense.attacker.label"))

                    // Größenkategorie: a groß attacker leaves shield parry or
                    // dodge, a riesig one only dodge.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("opponent.size"))
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(.secondary)
                        CreatureSizeChipRow(
                            size: $opponent.size,
                            identifierPrefix: "combat.defense.size"
                        )
                        // On a blocked parry the button says it instead.
                        if !isAusweichen, !blocked, let restriction {
                            Text(restriction)
                                .font(.dsaBody(.caption2))
                                .foregroundStyle(combatAccent)
                                .accessibilityIdentifier("combat.defense.sizeRestriction")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DSAToggleRow(
                        title: L("advantageousPosition"),
                        isOn: $opponent.advantageousPosition,
                        accent: combatAccent,
                        detail: "VW +2",
                        identifier: "combat.defense.advantageousPosition"
                    )

                    DSAToggleRow(
                        title: L("fromBehind"),
                        isOn: $opponent.fromBehind,
                        accent: combatAccent,
                        detail: L("fromBehind.defenseDetail"),
                        identifier: "combat.defense.fromBehind"
                    )

                    // Only a rider is better placed against someone on foot.
                    // Off is "not stated", as on the announcement.
                    if mountedActive {
                        DSAToggleRow(
                            title: L("defense.onFoot"),
                            isOn: Binding(
                                get: { opponent.isOnFoot == true },
                                set: { opponent.isOnFoot = $0 ? true : nil }
                            ),
                            accent: combatAccent,
                            detail: "VW +2",
                            subtitle: L("advantageousPosition"),
                            identifier: "combat.defense.onFoot"
                        )
                    }

                    breakdown

                    CombatActionButton(
                        title: blocked ? L("size.parryImpossible") : L("defense.roll"),
                        subtitle: blocked ? restriction : nil,
                        identifier: "combat.defense.continue",
                        isEnabled: !blocked
                    ) {
                        step = DefenseRoute.next(action, hero: hero, size: opponent.size, lines: lines)
                    }

                    if blocked {
                        // `.defenseSetup`, not `.root`: the answers above survive.
                        CombatActionButton(
                            title: L("defense.switchToDodge"),
                            fill: Color.dsaDark,
                            identifier: "combat.defense.switchToDodge"
                        ) {
                            step = .defenseSetup(.ausweichen)
                        }
                    }
                }
                .adaptiveContentWidth()
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }

    /// Base, lines, total. With a shield or two weapons the weapon list shows
    /// each piece's own value, so the base here is "—" and the total is what
    /// the lines add to it.
    private var breakdown: some View {
        let label = isAusweichen ? "AW" : "PA"
        let sum = lines.reduce(0) { $0 + $1.value }
        let base = DefenseRoute.baseValue(action, hero: hero, size: opponent.size)
        return CombatBreakdownBox(
            baseValue: base.map { "\($0)" } ?? "—",
            baseSource: L("source.basis"),
            lines: lines,
            totalValue: base.map { "\(label) \($0 + sum)" } ?? "\(label) \(sum > 0 ? "+" : "")\(sum)",
            totalSource: L("source.effective"),
            sectionLabel: L("calculation.label")
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.defense.breakdown")
    }
}

// MARK: - CreatureSizeChipRow

/// The five Größenkategorien as a chip row, each with an optional detail line
/// (the announcement prints what a size costs the hero's attack). Shared by
/// the announcement and the defence screen.
struct CreatureSizeChipRow: View {
    @Binding var size: CreatureSize
    var options: [CreatureSize] = CreatureSize.allCases
    var detail: (CreatureSize) -> String? = { _ in nil }
    let identifierPrefix: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) { chips }
        }
        .fixedSize(horizontal: false, vertical: true)
        .dsaOptionGroup()
    }

    private var chips: some View {
        ForEach(options) { option in
            let selected = option == size
            Button { size = option } label: {
                VStack(spacing: 2) {
                    Text(L(option.nameKey))
                        .font(.dsaHeading(.caption))
                    if let text = detail(option) {
                        Text(text)
                            .font(.dsaMono(.caption2, emphasis: true))
                            .opacity(selected ? 0.85 : 0.6)
                    }
                }
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 22)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(selected ? combatAccent : Color(UIColor.secondarySystemBackground))
                .dsaBox(.flush)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("\(identifierPrefix).\(option.rawValue)")
        }
    }
}
