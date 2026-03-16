import SwiftUI
import SwiftData

// MARK: - CombatExecutionView

struct CombatExecutionView: View {
    let hero: Hero
    let action: CombatAction
    let weaponName: String
    let attributeValue: Int
    let damageFormula: String?
    let note: String?
    let modifierLines: [ModifierLine]?
    let secondAttackStep: CombatStep?
    let combatId: UUID
    let roundNumber: Int
    let beengteUmgebungActive: Bool
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var modifier: Int = 0
    @State private var displayRoll: Int = 1
    @State private var finalRoll: Int? = nil
    @State private var confirmRoll: Int? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var confirmAnimTask: Task<Void, Never>? = nil
    @State private var schipUsed: Bool = false

    // Damage rolling state
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil

    private var attrLabel: String {
        switch action {
        case .angriff:   "AT"
        case .parieren:  "PA"
        case .ausweichen: "AW"
        }
    }

    private var actionLabel: String {
        switch action {
        case .angriff:   "Angriff"
        case .parieren:  "Parieren"
        case .ausweichen: "Ausweichen"
        }
    }

    private var effectiveValue: Int { attributeValue + modifier }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = action == .ausweichen ? .root : .weaponSelection(action)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(actionLabel)
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

            VStack(spacing: 8) {
                // Row 1: modifier breakdown or simple value
                modifierBreakdown

                // Manual modifier stepper (ZUSÄTZLICH)
                modifierBox

                // Row 3: Dice box
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                // Confirm box (only for 1/20 rolls)
                if let fr = finalRoll, needsConfirm(fr) {
                    confirmBox
                }

                if let outcome = computedOutcome {
                    outcomeBar(outcome)

                    // Maneuver note — shown AFTER outcome bar, only once roll is locked in
                    if let note, !note.isEmpty {
                        infoBox(note)
                    }

                    // Schip reroll button — only for normal misserfolg (not fumble)
                    if outcome == .misserfolg && !schipUsed && (hero.derivedValues?.schicksalspunkte.current ?? 0) > 0 {
                        Button {
                            hero.derivedValues?.schicksalspunkte.current -= 1
                            schipUsed = true
                            finalRoll = nil
                            confirmRoll = nil
                            damageFinalRolls = nil
                            startAnimation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text(L("schip.reroll"))
                            }
                            .font(.system(.body, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.6, green: 0.5, blue: 0.0))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }

                    // Attack-specific post-outcome flow
                    if action == .angriff {
                        attackOutcomeActions(outcome)
                    } else {
                        defenseOutcomeActions(outcome)
                    }
                }
            }
            .adaptiveContentWidth()
            .padding(.vertical, 16)

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear {
            animationTask?.cancel()
            confirmAnimTask?.cancel()
            damageAnimTask?.cancel()
        }
    }

    // MARK: - Attack outcome actions

    @ViewBuilder
    private func attackOutcomeActions(_ outcome: CombatOutcome) -> some View {
        switch outcome {
        case .erfolg, .kritischerErfolg:
            // Critical hit info boxes
            if outcome == .kritischerErfolg {
                infoBox(L("opponentDefense.halved"))
                infoBox(L("opponentDefense.doubleDamage"))
            } else if finalRoll == 1 && confirmRoll != nil {
                // Rolled 1 but confirm failed → still normal hit, but note that defense is halved
                // (1 was rolled — even on failed confirmation the opponent defense is still halved)
                infoBox(L("opponentDefense.halved"))
            }

            // "Weiter zur Verteidigung" button
            Button {
                step = .opponentDefense(
                    weaponName: weaponName,
                    damageFormula: damageFormula,
                    isCriticalHit: finalRoll == 1,
                    isDoubleDamage: outcome == .kritischerErfolg,
                    modifierLines: modifierLines
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                    Text(L("proceedToDefense"))
                }
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)

        case .misserfolg:
            // showNeueAktion controls this — rendered in the unified block below
            neueAktionBlock()

        case .kritischerPatzer:
            // Fumble confirmed → transition to fumble choice
            Button {
                step = .fumbleChoice(action: action, weaponName: weaponName, isShieldParry: false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(L("fumble.title"))
                }
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Defense outcome actions (PA/AW — flow unchanged)

    @ViewBuilder
    private func defenseOutcomeActions(_ outcome: CombatOutcome) -> some View {
        // Critical parry success → Passierschlag info
        if action == .parieren && outcome == .kritischerErfolg {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text(L("passierschlag") + " " + L("passierschlag.info"))
            }
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(combatAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(combatAccent.opacity(0.1))
            .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
        }

        if outcome == .kritischerPatzer {
            // Confirmed fumble on defense → fumble choice
            let isShieldParry = action == .parieren && (hero.selectedShield != nil)
            Button {
                step = .fumbleChoice(action: action, weaponName: weaponName, isShieldParry: isShieldParry)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(L("fumble.title"))
                }
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        } else if showNeueAktion {
            neueAktionBlock()
        }
    }

    // MARK: - Neue Aktion / dual-wield block

    @ViewBuilder
    private func neueAktionBlock() -> some View {
        if let secondStep = secondAttackStep, computedOutcome != .kritischerPatzer {
            // Second dual-wield attack
            Button { step = secondStep } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text(L("dualAttack") + " 2")
                }
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            }
            .buttonStyle(.plain)
        } else if secondAttackStep != nil && computedOutcome == .kritischerPatzer {
            // Fumble — second attack lost
            Text(L("fumbleSecondLost"))
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

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
        } else {
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
    }

    // MARK: - Info box helper

    private func infoBox(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(.caption2, weight: .bold))
            Text(text)
                .font(.system(.caption2, weight: .bold))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(combatAccent.opacity(0.1))
        .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
    }

    // MARK: - Box helpers

    private func valueBox(_ text: String, label: String? = nil, dark: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .foregroundStyle(dark ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(dark ? Color.dsaDark : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            if let label {
                Text(label)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var modifierBox: some View {
        let locked = finalRoll != nil
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    modifier -= 1
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(minWidth: 64)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Button {
                    modifier += 1
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            Text(L("modifier"))
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Modifier breakdown

    /// The raw base value (weapon AT/PA/AW) before any situation modifiers are applied.
    /// attributeValue already includes the lines sum, so subtract it back to recover the base.
    private var baseValue: Int {
        let linesSum = modifierLines?.reduce(0) { $0 + $1.value } ?? 0
        return attributeValue - linesSum
    }

    @ViewBuilder
    private var modifierBreakdown: some View {
        if let lines = modifierLines, !lines.isEmpty {
            VStack(spacing: 0) {
                combatSectionLabel(L("calculation.label"))

                // Base value row
                HStack {
                    Text("\(attrLabel) \(baseValue)")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                    Spacer()
                    Text(L("source.basis"))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))

                // Modifier lines
                ForEach(lines) { line in
                    HStack {
                        Text(line.value > 0 ? "+\(line.value)" : "\(line.value)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(line.value > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : Color.groupCombat)
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

                // Manual modifier row (only when non-zero)
                if modifier != 0 {
                    HStack {
                        Text(modifier > 0 ? "+\(modifier)" : "\(modifier)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(modifier > 0 ? Color(red: 0x2E/255, green: 0x7D/255, blue: 0x32/255) : Color.groupCombat)
                        Spacer()
                        Text(L("source.additional"))
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }

                // Effective total row
                HStack {
                    Text("\(attrLabel) \(effectiveValue)")
                        .font(.system(.body, design: .monospaced, weight: .black))
                    Spacer()
                    Text("Effektiv")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dsaDark)
                .foregroundStyle(.white)
            }
        } else {
            // Fallback: simple display (for defense/dodge without full breakdown)
            valueBox("\(attributeValue)", label: attrLabel)
        }
    }

    private var diceBox: some View {
        let isAnimating = finalRoll == nil
        let display = finalRoll ?? displayRoll
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(display)")
                    .font(.system(.largeTitle, weight: .black))
                    .fontDesign(.monospaced)
                if isAnimating {
                    Text(L("tapToRoll"))
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            Text("W20")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var confirmBox: some View {
        let isAnimating = confirmRoll == nil
        let display: String = {
            if let cr = confirmRoll { return "\(cr)" }
            return "\(displayRoll)"
        }()
        return VStack(spacing: 0) {
            Text(display)
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            Text(L("confirmation"))
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Outcome

    enum CombatOutcome {
        case kritischerErfolg, kritischerPatzer, erfolg, misserfolg
    }

    private var computedOutcome: CombatOutcome? {
        guard let fr = finalRoll else { return nil }
        if needsConfirm(fr) {
            guard let cr = confirmRoll else { return nil }
            if fr == 1 {
                return cr <= effectiveValue ? .kritischerErfolg : .erfolg
            } else {
                return cr > effectiveValue ? .kritischerPatzer : .misserfolg
            }
        }
        return fr <= effectiveValue ? .erfolg : .misserfolg
    }

    private func needsConfirm(_ roll: Int) -> Bool { roll == 1 || roll == 20 }

    private func outcomeBar(_ outcome: CombatOutcome) -> some View {
        let isCritical = outcome == .kritischerErfolg || outcome == .kritischerPatzer
        return Text(outcomeText(outcome))
            .font(.system(isCritical ? .title3 : .body, weight: .bold))
            .foregroundStyle(outcomeTextColor(outcome))
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCritical ? 14 : 10)
            .background(outcomeBackground(outcome))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    private func outcomeText(_ outcome: CombatOutcome) -> String {
        switch outcome {
        case .kritischerErfolg: return L("criticalSuccess")
        case .kritischerPatzer: return L("criticalFumble")
        case .erfolg:           return L("success")
        case .misserfolg:       return L("failure")
        }
    }

    private func outcomeBackground(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return Color(red: 0x00 / 255.0, green: 0xc8 / 255.0, blue: 0x53 / 255.0)
        case .kritischerPatzer: return .groupCombat
        case .erfolg:           return Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
        case .misserfolg:       return .dsaDark
        }
    }

    private func outcomeTextColor(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return .primary
        default:                return .white
        }
    }

    // MARK: - Animation & rolling

    private func startAnimation() {
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                displayRoll = Int.random(in: 1...20)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { break }
            }
        }
    }

    /// For defense actions: show "Neue Aktion" once outcome is determined (and damage if hit+rolled).
    /// For attack actions: controlled entirely by attackOutcomeActions — this is only used by defense.
    private var showNeueAktion: Bool {
        guard let outcome = computedOutcome else { return false }
        guard action != .angriff else { return false }
        // Fumble handled separately
        guard outcome != .kritischerPatzer else { return false }
        return true
    }

    private func rollDice() {
        guard finalRoll == nil else { return }
        animationTask?.cancel()
        let rolled = Int.random(in: 1...20)
        finalRoll = rolled
        if needsConfirm(rolled) { startConfirmAnimation() }
    }

    private func startConfirmAnimation() {
        confirmAnimTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
            var count = 0
            while !Task.isCancelled && count < 10 {
                displayRoll = Int.random(in: 1...20)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            confirmRoll = Int.random(in: 1...20)
        }
    }

    // MARK: - Damage

    private struct ParsedDamage {
        let count: Int
        let sides: Int
        let bonus: Int
    }

    private func parseDamage(_ formula: String) -> ParsedDamage? {
        // Matches formats like "1W6", "2W6+4", "1W6-1"
        let pattern = /(\d+)W(\d+)([+-]\d+)?/
        guard let match = formula.firstMatch(of: pattern) else { return nil }
        let count = Int(match.1) ?? 1
        let sides = Int(match.2) ?? 6
        let bonus = match.3.flatMap { Int($0) } ?? 0
        return ParsedDamage(count: count, sides: sides, bonus: bonus)
    }

    private func isHit(_ outcome: CombatOutcome) -> Bool {
        outcome == .erfolg || outcome == .kritischerErfolg
    }

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
                        .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
            }

            // Formula + total
            if let finalRolls = damageFinalRolls {
                let diceSum = finalRolls.reduce(0, +)
                let total = max(0, diceSum + parsed.bonus)
                let bonusStr = parsed.bonus > 0 ? "+\(parsed.bonus)" : parsed.bonus < 0 ? "\(parsed.bonus)" : ""

                Text("\(diceSum)\(bonusStr) = \(total) TP")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    .padding(.top, 6)
            }

            if isAnimating {
                Text(L("tapToRoll"))
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { rollDamage(parsed: parsed) }
        .onAppear { startDamageAnimation(parsed: parsed) }
    }

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
}
