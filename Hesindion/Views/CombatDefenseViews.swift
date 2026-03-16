import SwiftUI
import SwiftData

// MARK: - CombatOpponentDefenseView

struct CombatOpponentDefenseView: View {
    let hero: Hero
    let weaponName: String
    let damageFormula: String?
    let isCriticalHit: Bool
    let isDoubleDamage: Bool
    let modifierLines: [ModifierLine]?
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext

    // Damage rolling state (shown after "Treffer geht durch")
    @State private var showDamage: Bool = false
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil
    @State private var damageSchipUsed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button {
                    step = .root
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(L("opponentDefense"))
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(.white)
                    Text(weaponName)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            // MARK: Body
            VStack(spacing: 8) {
                // Critical hit info boxes
                if isCriticalHit {
                    infoBox(L("opponentDefense.halved"), icon: "exclamationmark.triangle.fill")
                }
                if isDoubleDamage {
                    infoBox(L("opponentDefense.doubleDamage"), icon: "flame.fill")
                }

                // Maneuver reminder notes from the attack phase
                if let lines = modifierLines, !lines.isEmpty {
                    combatSectionLabel(L("announcement.label"))
                    ForEach(lines) { line in
                        HStack {
                            Text(line.value > 0 ? "+\(line.value)" : "\(line.value)")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(line.value > 0
                                    ? Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
                                    : combatAccent)
                            Spacer()
                            Text(line.source)
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                    }
                }

                // Outcome buttons (only while damage section is not shown)
                if !showDamage {
                    // Pariert
                    Button {
                        logOpponentDefense(outcome: "parried")
                        step = .root
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                            Text(L("opponentDefense.parried"))
                        }
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                    }
                    .buttonStyle(.plain)

                    // Ausgewichen
                    Button {
                        logOpponentDefense(outcome: "dodged")
                        step = .root
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text(L("opponentDefense.dodged"))
                        }
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
                    }
                    .buttonStyle(.plain)

                    // Treffer geht durch
                    Button {
                        logOpponentDefense(outcome: "hit")
                        showDamage = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text(L("opponentDefense.hitThrough"))
                        }
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }

                // Damage section
                if showDamage, let formula = damageFormula, let parsed = parseDamage(formula) {
                    damageSection(parsed: parsed)
                } else if showDamage && damageFormula == nil {
                    // No damage formula — skip straight to new action
                    neueAktionButton
                }
            }
            .adaptiveContentWidth()
            .padding(.vertical, 16)

            Spacer()
        }
        .onDisappear {
            damageAnimTask?.cancel()
        }
    }

    // MARK: - Damage Section

    private func damageSection(parsed: ParsedDamage) -> some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("damage.label"))

            let isAnimating = damageFinalRolls == nil
            let rolls = damageFinalRolls ?? damageDisplayRolls

            // Individual dice
            HStack(spacing: 6) {
                ForEach(0..<parsed.count, id: \.self) { i in
                    Text(i < rolls.count ? "\(rolls[i])" : "-")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isAnimating
                            ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity)
                            : Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
            }

            // Formula + total (after finalised)
            if let finalRolls = damageFinalRolls {
                let diceSum = finalRolls.reduce(0, +)
                let rawTotal = max(0, diceSum + parsed.bonus)
                let total = isDoubleDamage ? rawTotal * 2 : rawTotal
                let bonusStr = parsed.bonus > 0 ? "+\(parsed.bonus)" : parsed.bonus < 0 ? "\(parsed.bonus)" : ""

                if isDoubleDamage {
                    Text("\(diceSum)\(bonusStr) = \(rawTotal) × 2 = \(total) TP")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        .padding(.top, 6)
                } else {
                    Text("\(diceSum)\(bonusStr) = \(total) TP")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        .padding(.top, 6)
                }
            }

            if isAnimating {
                Text(L("tapToRoll"))
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            // Schip reroll — only shown after dice are finalised, before schip is spent
            if let finalRolls = damageFinalRolls, !damageSchipUsed,
               (hero.derivedValues?.schicksalspunkte.current ?? 0) > 0 {
                Button {
                    hero.derivedValues?.schicksalspunkte.current -= 1
                    damageSchipUsed = true
                    if var rolls = damageFinalRolls,
                       let minIdx = rolls.indices.min(by: { rolls[$0] < rolls[$1] }) {
                        rolls[minIdx] = Int.random(in: 1...parsed.sides)
                        damageFinalRolls = rolls
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(L("schip.damageReroll"))
                    }
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.6, green: 0.5, blue: 0.0))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                // Log damage when first finalised
                .onAppear {
                    let diceSum = finalRolls.reduce(0, +)
                    let rawTotal = max(0, diceSum + parsed.bonus)
                    let total = isDoubleDamage ? rawTotal * 2 : rawTotal
                    logDamageDealt(total)
                }
            }

            // Neue Aktion button — shown once dice are rolled
            if damageFinalRolls != nil {
                neueAktionButton
                    .padding(.top, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { rollDamage(parsed: parsed) }
        .onAppear { startDamageAnimation(parsed: parsed) }
    }

    // MARK: - Neue Aktion

    private var neueAktionButton: some View {
        Button { step = .root } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text(L("newAction"))
            }
            .font(.system(.body, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info box helper

    private func infoBox(_ text: String, icon: String = "info.circle.fill") -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .bold))
            Text(text)
                .font(.system(.caption2, weight: .bold))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(combatAccent.opacity(0.1))
        .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
    }

    // MARK: - Damage formula parsing

    private struct ParsedDamage {
        let count: Int
        let sides: Int
        let bonus: Int
    }

    private func parseDamage(_ formula: String) -> ParsedDamage? {
        let pattern = /(\d+)W(\d+)([+-]\d+)?/
        guard let match = formula.firstMatch(of: pattern) else { return nil }
        return ParsedDamage(
            count: Int(match.1) ?? 1,
            sides: Int(match.2) ?? 6,
            bonus: match.3.flatMap { Int($0) } ?? 0
        )
    }

    // MARK: - Dice animation & rolling

    private func startDamageAnimation(parsed: ParsedDamage) {
        damageAnimTask?.cancel()
        damageAnimTask = Task { @MainActor in
            while !Task.isCancelled {
                damageDisplayRolls = (0..<parsed.count).map { _ in Int.random(in: 1...parsed.sides) }
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { break }
            }
        }
    }

    private func rollDamage(parsed: ParsedDamage) {
        guard damageFinalRolls == nil else { return }
        damageAnimTask?.cancel()
        damageFinalRolls = (0..<parsed.count).map { _ in Int.random(in: 1...parsed.sides) }
    }

    // MARK: - Logging

    private func logOpponentDefense(outcome: String) {
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .opponentDefense,
                weaponName: weaponName,
                rollValue: nil,
                damageDealt: nil,
                damageTaken: nil,
                effectiveValue: nil,
                outcome: outcome,
                schipAction: nil,
                fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }

    private func logDamageDealt(_ tp: Int) {
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .damageDealt,
                weaponName: weaponName,
                rollValue: nil,
                damageDealt: tp,
                damageTaken: nil,
                effectiveValue: nil,
                outcome: nil,
                schipAction: nil,
                fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
}

// MARK: - CombatFumbleChoiceView

struct CombatFumbleChoiceView: View {
    let hero: Hero
    let action: CombatAction
    let weaponName: String
    let isShieldParry: Bool
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext

    @State private var choice: FumbleChoiceKind? = nil
    @State private var simpleDamageRoll: Int? = nil
    @State private var tableRoll: (die1: Int, die2: Int)? = nil
    @State private var tableEntry: FumbleTableEntry? = nil

    private enum FumbleChoiceKind { case simpleDamage, table }

    // MARK: - Computed helpers

    private var tableType: FumbleTableType {
        switch action {
        case .angriff:    return .nahkampfAttacke
        case .parieren:   return isShieldParry ? .verteidigungSchild : .verteidigungWaffe
        case .ausweichen: return .verteidigungSchild
        }
    }

    private var isUnarmed: Bool {
        weaponName == "Raufen"
    }

    private var isDodge: Bool {
        action == .ausweichen
    }

    private var isResolved: Bool {
        simpleDamageRoll != nil || tableEntry != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            fumbleHeader
            VStack(spacing: 16) {
                if choice == nil {
                    choiceButtons
                } else if choice == .simpleDamage {
                    simpleDamageResult
                } else {
                    tableResult
                }

                if isResolved {
                    newActionButton
                }
            }
            .padding(.top, 16)
            .adaptiveContentWidth()

            Spacer()
        }
    }

    // MARK: - Header

    private var fumbleHeader: some View {
        HStack {
            Button { step = .root } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(L("fumble.title"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Text(weaponName)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(combatAccent)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }

    // MARK: - Choice Buttons

    private var choiceButtons: some View {
        VStack(spacing: 12) {
            Button {
                choice = .simpleDamage
                rollSimpleDamage()
            } label: {
                VStack(spacing: 4) {
                    Text(L("fumble.takeDamage"))
                        .font(.system(.title3, weight: .black))
                    Text(L("fumble.spIgnoresRS"))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)

            Button {
                choice = .table
                rollTable()
            } label: {
                Text(L("fumble.rollTable"))
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Simple Damage Result

    @ViewBuilder
    private var simpleDamageResult: some View {
        if let roll = simpleDamageRoll {
            let total = roll + 2
            Text("\(roll) + 2 = \(total) SP")
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupCombat)
                .foregroundStyle(.white)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

            Text(L("fumble.spIgnoresRS"))
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Table Result

    @ViewBuilder
    private var tableResult: some View {
        if let roll = tableRoll, let entry = tableEntry {
            let total = roll.die1 + roll.die2

            HStack(spacing: 6) {
                Text("\(roll.die1)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                Text("+")
                    .font(.system(.body, weight: .bold))
                Text("\(roll.die2)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                Text("=")
                    .font(.system(.body, weight: .bold))
                Text("\(total)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dsaDark)
                    .foregroundStyle(.white)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(.body, weight: .black))
                Text(entry.description)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupCombat.opacity(0.1))
            .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
        }
    }

    // MARK: - New Action Button

    private var newActionButton: some View {
        Button { step = .root } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text(L("newAction"))
            }
            .font(.system(.body, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Roll Helpers

    private func rollSimpleDamage() {
        let roll = Int.random(in: 1...6)
        simpleDamageRoll = roll
        applySimpleDamage(roll + 2)
    }

    private func rollTable() {
        let d1 = Int.random(in: 1...6)
        let d2 = Int.random(in: 1...6)
        let total = d1 + d2
        tableRoll = (d1, d2)
        let entry = FumbleTable.lookup(total, table: tableType, isUnarmed: isUnarmed || isDodge)
        tableEntry = entry
        logTableResult(entry, roll: total)
    }

    // MARK: - Persistence Helpers

    private func applySimpleDamage(_ sp: Int) {
        if let dv = hero.derivedValues {
            dv.lebensenergie.current = max(0, dv.lebensenergie.current - sp)
        }
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .fumble,
                weaponName: weaponName,
                rollValue: sp,
                damageDealt: nil,
                damageTaken: sp,
                effectiveValue: nil,
                outcome: "1W6+2 SP",
                schipAction: nil,
                fumbleTableResult: nil,
                lpChange: -sp
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }

    private func logTableResult(_ entry: FumbleTableEntry, roll: Int) {
        let logEntry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .fumble,
                weaponName: weaponName,
                rollValue: roll,
                damageDealt: nil,
                damageTaken: nil,
                effectiveValue: nil,
                outcome: "Patzertabelle",
                schipAction: nil,
                fumbleTableResult: entry.title,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(logEntry)
    }
}
