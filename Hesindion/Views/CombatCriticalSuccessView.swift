import SwiftUI
import SwiftData

/// The optional "Kritische Erfolge" tables (ADR-0011), reached only when the
/// hero's table plays with them.
///
/// `CombatFumbleChoiceView` is the mirror image and the shape this follows: roll
/// 2W6, look the result up, state it. The differences are that a critical success
/// can *change the damage the app is about to compute*, and that the Fokusregel
/// adds a second 1W20 which some bands answer with "nochmal würfeln".
struct CombatCriticalSuccessView: View {
    let hero: Hero
    /// `nil` when the screen has to ask. The app knows the hero defended, not
    /// whether the attack it turned aside was melee or ranged, so a hero playing
    /// with both defensive tables has to say which.
    let requestedTable: CriticalSuccessTableType?
    let action: CombatAction
    let weaponName: String
    let damageFormula: String?
    let modifierLines: [ModifierLine]?
    /// TP bonuses on the way to the damage roll; this screen only adds the
    /// table's own multiplier on top.
    var damageLines: [ModifierLine] = []
    let isRangedAttack: Bool
    let rangedDefensePenalty: Int
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext

    /// Basic rule or table. The optional rule is permissive — "kann auch diese
    /// Tabelle benutzt werden" — so switching it on offers the table, it does not
    /// impose it. The Patzer screen has offered the same choice all along.
    @State private var resolution: Resolution? = nil
    @State private var chosenTable: CriticalSuccessTableType? = nil
    @State private var categoryDice: [Int]? = nil
    @State private var category: CriticalSuccessCategory? = nil
    @State private var detailDie: Int? = nil
    @State private var refinement: CriticalSuccessRefinement? = nil
    @State private var showingCategoryRoll = false
    @State private var showingDetailRoll = false
    @State private var hasLogged = false

    private enum Resolution { case basicRule, table }

    // MARK: - Derived

    private var table: CriticalSuccessTableType? { requestedTable ?? chosenTable }

    private var usesDetail: Bool { hero.isFokusRuleActive(.kritischeErfolgeDetail) }

    /// A refinement that actually answers something. "Nochmal würfeln" is not a
    /// result, so the screen stays open on it.
    private var settledRefinement: CriticalSuccessRefinement? {
        guard usesDetail, let refinement, !refinement.isReroll else { return nil }
        return refinement
    }

    /// The refinement overrides the category where it exists: the Fokusregel
    /// determines the result "genauer", it does not add to it.
    private var resolvedDamage: CriticalDamage {
        if resolution == .basicRule { return table?.basicDamage ?? .unchanged }
        return settledRefinement?.damage ?? category?.damage ?? .unchanged
    }

    private var grantsPassierschlag: Bool {
        if resolution == .basicRule { return table?.basicGrantsPassierschlag ?? false }
        return settledRefinement?.grantsPassierschlag ?? category?.grantsPassierschlag ?? false
    }

    /// Whether the critical has said everything it is going to say. The basic rule
    /// settles the moment it is taken; the table has dice to roll first.
    private var isResolved: Bool {
        if resolution == .basicRule { return true }
        guard category != nil else { return false }
        return !usesDetail || settledRefinement != nil
    }

    private var isAttackTable: Bool { table == .angriff }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    if let table {
                        switch resolution {
                        case nil:
                            resolutionChoice(table)

                        case .basicRule:
                            resultBox(title: L(table.basicRuleKey), text: L(table.basicEffectKey))
                            if isAttackTable, let label = resolvedDamage.label {
                                damageBox(label)
                            }
                            continueActions

                        case .table:
                            replacesNote(table)

                            if let dice = categoryDice, let category {
                                diceRow(dice)
                                resultBox(title: category.title, text: category.effect)

                                if usesDetail {
                                    detailSection
                                }
                            } else {
                                rollCategoryButton
                            }

                            if isResolved {
                                if isAttackTable, let label = resolvedDamage.label {
                                    damageBox(label)
                                }
                                continueActions
                            }
                        }
                    } else {
                        tableChoice
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                .adaptiveContentWidth()
            }
        }
        .overlay {
            if showingCategoryRoll, let table {
                DSADiceRevealModal(
                    title: L("critical.category"),
                    sides: 6,
                    count: 2,
                    accent: combatAccent,
                    caption: { dice in
                        let sum = dice.reduce(0, +)
                        return "\(sum): \(CriticalSuccessTable.category(sum, table: table).title)"
                    },
                    onConfirm: { dice in
                        categoryDice = dice
                        category = CriticalSuccessTable.category(dice.reduce(0, +), table: table)
                        showingCategoryRoll = false
                        logIfResolved()
                    },
                    onCancel: { showingCategoryRoll = false }
                )
            }
        }
        .overlay {
            if showingDetailRoll, let category {
                DSADiceRevealModal(
                    title: L("critical.detail"),
                    sides: 20,
                    accent: combatAccent,
                    caption: { dice in
                        guard let roll = dice.first,
                              let match = CriticalSuccessTable.refinement(roll, in: category)
                        else { return nil }
                        return match.isReroll ? "\(roll): \(L("critical.rerollPrompt"))" : "\(roll)"
                    },
                    onConfirm: { dice in
                        if let roll = dice.first {
                            detailDie = roll
                            refinement = CriticalSuccessTable.refinement(roll, in: category)
                        }
                        showingDetailRoll = false
                        logIfResolved()
                    },
                    onCancel: { showingDetailRoll = false }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { step = .root } label: {
                Image(systemName: "chevron.left")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)

            Spacer()

            VStack(spacing: 2) {
                Text(L("critical.title"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Text(table.map { L($0.titleKey) } ?? weaponName)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(combatAccent)
        .dsaBox(.raised)
    }

    // MARK: - Which defence was this?

    private var tableChoice: some View {
        VStack(spacing: 12) {
            Text(L("critical.chooseTable"))
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            choiceButton(L("critical.chooseMelee"), identifier: "combat.critical.chooseMelee") {
                chosenTable = .verteidigungNahkampf
            }
            choiceButton(L("critical.chooseRanged"), identifier: "combat.critical.chooseRanged") {
                chosenTable = .verteidigungFernkampf
            }
        }
        .padding(.horizontal, 16)
    }

    private func choiceButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Basic rule or table?

    /// The same shape as `CombatFumbleChoiceView`'s two buttons, and for the same
    /// reason: the optional rule offers a table, it does not remove the rule it
    /// replaces. On a bad night the table is worse than plain doubling — melee
    /// results 2–6 hand out no Passierschlag at all — and that has to stay the
    /// player's call at the moment it happens, not a setting made weeks ago.
    private func resolutionChoice(_ table: CriticalSuccessTableType) -> some View {
        VStack(spacing: 12) {
            Text(L("critical.chooseResolution"))
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            resolutionButton(
                title: L(table.basicRuleKey),
                subtitle: L("critical.basicRule"),
                fill: Color.dsaDark,
                identifier: "combat.critical.takeBasicRule"
            ) {
                resolution = .basicRule
                logIfResolved()
            }

            resolutionButton(
                title: L("critical.rollTable"),
                subtitle: L("critical.optionalRule"),
                fill: combatAccent,
                identifier: "combat.critical.takeTable"
            ) {
                resolution = .table
            }
        }
        .padding(.horizontal, 16)
    }

    private func resolutionButton(
        title: String,
        subtitle: String,
        fill: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.dsaHeading(.title3))
                Text(subtitle)
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Pieces

    /// What the basic rule would have done. Worth stating: on a low roll the
    /// table is *worse* than the outcome it replaced, and the player should be
    /// able to see that rather than wonder where their Passierschlag went.
    private func replacesNote(_ table: CriticalSuccessTableType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.dsaCritical)
            Text(L(table.replacesKey))
                .font(.dsaBody(.caption2))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush, stroke: Color.dsaCritical)
        .padding(.horizontal, 16)
    }

    private var rollCategoryButton: some View {
        Button { showingCategoryRoll = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "die.face.6.fill")
                Text(L("critical.rollCategory"))
            }
            .font(.dsaHeading(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(combatAccent)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.critical.rollCategory")
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var detailSection: some View {
        if let settled = settledRefinement, let die = detailDie, let effect = settled.effect {
            resultBox(title: "\(L("critical.detail")) — \(die)", text: effect)
        } else {
            Button { showingDetailRoll = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "die.face.5.fill")
                    // A band the table answers with "nochmal würfeln" is not a
                    // result, so the button comes back rather than the screen
                    // settling on nothing.
                    Text(refinement?.isReroll == true ? L("critical.rerollPrompt") : L("critical.rollDetail"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.dsaDark)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("combat.critical.rollDetail")
            .padding(.horizontal, 16)
        }
    }

    private func diceRow(_ dice: [Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(dice.enumerated()), id: \.offset) { index, value in
                if index > 0 {
                    Text("+").font(.dsaBody(.body))
                }
                Text("\(value)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
            }
            Text("=").font(.dsaBody(.body))
            Text("\(dice.reduce(0, +))")
                .font(.dsaHeading(.title3))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.dsaDark)
                .foregroundStyle(.white)
                .dsaBox(.flush)
        }
        .padding(.horizontal, 16)
        .accessibilityIdentifier("combat.critical.dice")
    }

    private func resultBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.dsaHeading(.body))
            Text(text)
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsaCritical.opacity(0.12))
        .dsaBox(.flush, stroke: Color.dsaCritical)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("combat.critical.result")
    }

    /// The one part of a table result the app carries forward itself.
    private func damageBox(_ label: String) -> some View {
        HStack {
            Text(label)
                .font(.dsaMono(.body, emphasis: true))
            Spacer()
            Text(L("critical.damageEffect"))
                .font(.dsaBody(.caption2))
                .opacity(0.75)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.dsaDark)
        .dsaBox(.raised)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("combat.critical.damage")
    }

    // MARK: - Continue

    @ViewBuilder
    private var continueActions: some View {
        if isAttackTable {
            actionButton(L("proceedToDefense"), icon: "shield.fill", identifier: "combat.critical.continue") {
                step = .opponentDefense(
                    weaponName: weaponName,
                    damageFormula: damageFormula,
                    isCriticalHit: true,
                    criticalDamage: resolvedDamage,
                    modifierLines: modifierLines,
                    isRangedAttack: isRangedAttack,
                    rangedDefensePenalty: rangedDefensePenalty,
                    damageLines: damageLines
                )
            }
        } else {
            if grantsPassierschlag {
                actionButton(L("passierschlag"), icon: "bolt.fill", identifier: "combat.critical.passierschlag") {
                    step = .passierschlag
                }
            }
            actionButton(L("newAction"), icon: "arrow.counterclockwise", identifier: "combat.critical.newAction") {
                step = .root
            }
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.dsaHeading(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(combatAccent)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, 16)
    }

    // MARK: - Logging

    /// Logged once the table has settled, so a reroll of the detail die does not
    /// leave two entries claiming different results for one critical.
    private func logIfResolved() {
        guard isResolved, !hasLogged, let table else { return }
        hasLogged = true
        let result: String
        if resolution == .basicRule {
            result = L(table.basicRuleKey)
        } else if let category {
            result = settledRefinement != nil && detailDie != nil
                ? "\(category.title) (1W20 \(detailDie!))"
                : category.title
        } else {
            return
        }
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .criticalSuccess,
                weaponName: weaponName,
                rollValue: categoryDice?.reduce(0, +),
                damageDealt: nil,
                damageTaken: nil,
                effectiveValue: nil,
                outcome: L(table.titleKey),
                schipAction: nil,
                fumbleTableResult: nil,
                lpChange: 0,
                criticalTableResult: result
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
}
