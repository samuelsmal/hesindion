import SwiftUI

// MARK: - DefenseRoute

/// Where a defence goes once its questions are answered. Pure, so the routing
/// the root used to do inline is tested without a view.
enum DefenseRoute {
    static func next(_ action: CombatAction, hero: Hero, lines: [ModifierLine]) -> CombatStep {
        let total = lines.reduce(0) { $0 + $1.value }
        if action == .ausweichen {
            let aw = hero.derivedValues?.ausweichen.value ?? 0
            return .execution(.ausweichen, name: "Ausweichen", attributeValue: aw + total, damageFormula: nil, note: nil, modifierLines: lines)
        }
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
    /// weapon chosen yet).
    static func baseValue(_ action: CombatAction, hero: Hero) -> Int? {
        if action == .ausweichen { return hero.derivedValues?.ausweichen.value ?? 0 }
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
                        title: L("defense.roll"),
                        identifier: "combat.defense.continue"
                    ) {
                        step = DefenseRoute.next(action, hero: hero, lines: lines)
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
        let base = DefenseRoute.baseValue(action, hero: hero)
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
