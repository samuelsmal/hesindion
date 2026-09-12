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
    @State private var hasLoggedRoll: Bool = false

    // Damage rolling state
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil

    private var attrLabel: String {
        switch action {
        case .angriff:    "AT"
        case .parieren:   "PA"
        case .ausweichen: "AW"
        case .fernkampf:  "FK"
        }
    }

    private var actionLabel: String {
        switch action {
        case .angriff:    "Angriff"
        case .parieren:   "Parieren"
        case .ausweichen: "Ausweichen"
        case .fernkampf:  "Fernkampf"
        }
    }

    private var effectiveValue: Int { attributeValue + modifier }

    /// Whether the hero's table plays with the optional Kritische-Erfolge table
    /// for *this* action (ADR-0011). An attack reads the Angriff table; a defence
    /// reads one of the two defensive ones, and which of those it is depends on
    /// the incoming attack, which is why the screen after this one may have to ask.
    private var usesCriticalTable: Bool {
        switch action {
        case .angriff, .fernkampf:
            hero.isFokusRuleActive(.kritischeErfolgeAngriff)
        case .parieren, .ausweichen:
            hero.isFokusRuleActive(.kritischeErfolgeNahkampf)
                || hero.isFokusRuleActive(.kritischeErfolgeFernkampf)
        }
    }

    /// `nil` asks. Pre-selected when only one of the two defensive tables is on,
    /// which is the common case — a table either plays with ranged criticals or
    /// does not.
    private var defenseCriticalTable: CriticalSuccessTableType? {
        let melee = hero.isFokusRuleActive(.kritischeErfolgeNahkampf)
        let ranged = hero.isFokusRuleActive(.kritischeErfolgeFernkampf)
        if melee && ranged { return nil }
        return melee ? .verteidigungNahkampf : .verteidigungFernkampf
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    step = action == .ausweichen ? .root : .weaponSelection(action)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)

                Spacer()

                VStack(spacing: 1) {
                    Text(actionLabel)
                        .font(.dsaHeading(.headline))
                        .foregroundStyle(.white)
                    Text(weaponName)
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white.opacity(0.85))
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

            VStack(spacing: 8) {
                // Row 1: modifier breakdown or simple value
                modifierBreakdown

                // Manual modifier stepper (ZUSÄTZLICH)
                modifierBox

                // Row 3: Dice box
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("combat.execution.diceBox")

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
                            hasLoggedRoll = false
                            logSchipUsed(action: "reroll")
                            finalRoll = nil
                            confirmRoll = nil
                            damageFinalRolls = nil
                            startAnimation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text(L("schip.reroll"))
                            }
                            .font(.dsaHeading(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.dsaSchipGold)
                            .dsaBox(.raised)
                        }
                        .buttonStyle(.dsaMotion)
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
        .onChange(of: finalRoll) {
            logRollIfNeeded()
        }
        .onChange(of: confirmRoll) {
            logRollIfNeeded()
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
                // The halving is unconditional; the doubling is not. With the
                // optional table in play it is the table that says what happens
                // to the damage — announcing "doppelter Schaden" here and then
                // rolling a +2 would state the outcome before it was decided.
                if !usesCriticalTable {
                    infoBox(L("opponentDefense.doubleDamage"))
                }
            } else if finalRoll == 1 && confirmRoll != nil {
                // Rolled 1 but confirm failed → still normal hit, but note that defense is halved
                // (1 was rolled — even on failed confirmation the opponent defense is still halved)
                infoBox(L("opponentDefense.halved"))
            }

            // "Weiter zur Verteidigung" button — or, on a confirmed critical with
            // the optional table switched on, the table first: it is what decides
            // what happens to the damage (ADR-0011).
            Button {
                if outcome == .kritischerErfolg, usesCriticalTable {
                    step = .criticalSuccess(
                        table: .angriff,
                        action: action,
                        weaponName: weaponName,
                        damageFormula: damageFormula,
                        modifierLines: modifierLines
                    )
                } else {
                    step = .opponentDefense(
                        weaponName: weaponName,
                        damageFormula: damageFormula,
                        isCriticalHit: finalRoll == 1,
                        criticalDamage: outcome == .kritischerErfolg ? .double : .unchanged,
                        modifierLines: modifierLines
                    )
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                    Text(usesCriticalTable && outcome == .kritischerErfolg
                         ? L("critical.title")
                         : L("proceedToDefense"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)

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
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    // MARK: - Defense outcome actions (PA/AW — flow unchanged)

    @ViewBuilder
    private func defenseOutcomeActions(_ outcome: CombatOutcome) -> some View {
        // A critical defence with the optional table on goes to the table, which
        // *replaces* the Passierschlag — on results 2–6 it hands out a standing
        // advantage instead, so the button must not be offered alongside it. An
        // Ausweichen reaches the table too; only the Passierschlag was ever
        // parry-only (ADR-0011).
        if outcome == .kritischerErfolg, usesCriticalTable {
            Button {
                step = .criticalSuccess(
                    table: defenseCriticalTable,
                    action: action,
                    weaponName: weaponName,
                    damageFormula: damageFormula,
                    modifierLines: modifierLines
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "die.face.6.fill")
                    Text(L("critical.title"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier("combat.execution.criticalTable")
        } else if action == .parieren && outcome == .kritischerErfolg {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text(L("passierschlag") + " " + L("passierschlag.info"))
            }
            .font(.dsaBody(.caption2))
            .foregroundStyle(combatAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(combatAccent.opacity(0.1))
            .dsaBox(.raised, stroke: combatAccent)

            Button { step = .passierschlag } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text(L("passierschlag"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
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
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
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
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        } else if secondAttackStep != nil && computedOutcome == .kritischerPatzer {
            // Fumble — second attack lost
            Text(L("fumbleSecondLost"))
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .dsaBox(.raised)

            Button { step = .root } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L("newAction"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        } else {
            Button { step = .root } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L("newAction"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    // MARK: - Info box helper

    private func infoBox(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.dsaBody(.caption2))
            Text(text)
                .font(.dsaBody(.caption2))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(combatAccent.opacity(0.1))
        .dsaBox(.flush, stroke: combatAccent)
    }

    // MARK: - Box helpers

    private func valueBox(_ text: String, label: String? = nil, dark: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.dsaHeading(.title3))
                .fontDesign(.monospaced)
                .foregroundStyle(dark ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(dark ? Color.dsaDark : Color(UIColor.systemBackground))
                .dsaBox(.flush)
            if let label {
                Text(label)
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var modifierBox: some View {
        let locked = finalRoll != nil
        return VStack(spacing: 0) {
            DSAStepper(
                decrementIcon: "arrow.down",
                incrementIcon: "arrow.up",
                tint: locked ? Color.dsaDisabled : combatAccent,
                decrementDisabled: locked,
                incrementDisabled: locked,
                incrementIdentifier: "combat.execution.increaseModifier",
                onDecrement: { modifier -= 1 },
                onIncrement: { modifier += 1 }
            ) {
                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            Text(L("modifier"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
                // Clear the stepper's shadow, which draws outside its bounds and
                // reserves no layout space — 2pt put "Mod" underneath it.
                .padding(.top, DSALayout.shadowOffset + 4)
        }
    }

    // MARK: - Modifier breakdown

    /// The raw base value (weapon AT/PA/AW) before any situation modifiers are applied.
    /// attributeValue already includes the lines sum, so subtract it back to recover the base.
    private var baseValue: Int {
        let linesSum = modifierLines?.reduce(0) { $0 + $1.value } ?? 0
        return attributeValue - linesSum
    }

    /// One line of the calculation: the contribution on the left, where it comes
    /// from on the right, a divider beneath.
    private func breakdownRow(value: String, source: String, tint: Color) -> some View {
        HStack {
            Text(value)
                .font(.dsaMono(.caption, emphasis: true))
                .foregroundStyle(tint)
            Spacer()
            Text(source)
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .dsaRowDivider()
    }

    @ViewBuilder
    private var modifierBreakdown: some View {
        if let lines = modifierLines, !lines.isEmpty {
            VStack(spacing: 0) {
                combatSectionLabel(L("calculation.label"))

                // One box, dividers within. Each row used to stroke its own
                // rectangle, so every boundary was a doubled 2pt border — and
                // the total was a bare dark bar with no border at all, the only
                // unbordered surface on the screen.
                VStack(spacing: 0) {
                    breakdownRow(
                        value: "\(attrLabel) \(baseValue)",
                        source: L("source.basis"),
                        tint: .primary
                    )

                    ForEach(lines) { line in
                        breakdownRow(
                            value: line.value > 0 ? "+\(line.value)" : "\(line.value)",
                            source: line.source,
                            tint: line.value > 0 ? Color.dsaPositive : Color.groupCombat
                        )
                    }

                    if modifier != 0 {
                        breakdownRow(
                            value: modifier > 0 ? "+\(modifier)" : "\(modifier)",
                            source: L("source.additional"),
                            tint: modifier > 0 ? Color.dsaPositive : Color.groupCombat
                        )
                    }

                    // The sum, inside the same box rather than welded under it.
                    HStack {
                        Text("\(attrLabel) \(effectiveValue)")
                            .font(.dsaMono(.body, emphasis: true))
                        Spacer()
                        Text(L("source.effective"))
                            .font(.dsaBody(.caption2))
                            .opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.dsaDark)
                }
                .dsaBox(.raised, fill: Color(UIColor.systemBackground))
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
                    .font(.dsaHeading(.largeTitle))
                    .fontDesign(.monospaced)
                if isAnimating {
                    Text(L("tapToRoll"))
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .dsaBox(.flush)
            Text("W20")
                .font(.dsaBody(.caption2))
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
                .font(.dsaHeading(.title3))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                .dsaBox(.flush)
            Text(L("confirmation"))
                .font(.dsaBody(.caption2))
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
            .font(.dsaHeading(isCritical ? .title3 : .body))
            .foregroundStyle(outcomeTextColor(outcome))
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCritical ? 14 : 10)
            .background(outcomeBackground(outcome))
            .dsaBox(.flush)
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
        case .kritischerErfolg: return Color.dsaCritical
        case .kritischerPatzer: return .groupCombat
        case .erfolg:           return Color.dsaPositive
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
        // So is a critical that owes the player a table roll: its screen carries
        // its own "Neue Aktion", and leaving early would skip the result.
        guard !(outcome == .kritischerErfolg && usesCriticalTable) else { return false }
        return true
    }

    private func rollDice() {
        guard finalRoll == nil else { return }
        animationTask?.cancel()
        // The settled roll goes through `DiceRoller` so `ScriptedDice` can put a
        // UI test on a chosen branch — a confirmed critical, say. The tumbling
        // `displayRoll` above deliberately does not: it is animation, and feeding
        // it would drain the script before the real roll was taken.
        let rolled = DiceRoller.roll(sides: 20)
        finalRoll = rolled
        if needsConfirm(rolled) { startConfirmAnimation() }
    }

    private func logRollIfNeeded() {
        guard !hasLoggedRoll, let outcome = computedOutcome else { return }
        hasLoggedRoll = true

        let outcomeStr: String = {
            switch outcome {
            case .kritischerErfolg: return "critical"
            case .kritischerPatzer: return "fumble"
            case .erfolg: return "success"
            case .misserfolg: return "failure"
            }
        }()

        let actionType: CombatActionType = {
            switch action {
            case .angriff:    return .attack
            case .parieren:   return .parry
            case .ausweichen: return .dodge
            case .fernkampf:  return .rangedAttack
            }
        }()

        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: actionType,
                weaponName: weaponName,
                rollValue: finalRoll,
                damageDealt: nil,
                damageTaken: nil,
                effectiveValue: effectiveValue,
                outcome: outcomeStr,
                schipAction: nil,
                fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }

    private func logSchipUsed(action schipAction: String) {
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .schipUsed,
                weaponName: weaponName,
                rollValue: nil,
                damageDealt: nil,
                damageTaken: nil,
                effectiveValue: nil,
                outcome: nil,
                schipAction: schipAction,
                fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
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
            confirmRoll = DiceRoller.roll(sides: 20)
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
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isAnimating ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                }
            }

            // Formula + total
            if let finalRolls = damageFinalRolls {
                let diceSum = finalRolls.reduce(0, +)
                let total = max(0, diceSum + parsed.bonus)
                let bonusStr = parsed.bonus > 0 ? "+\(parsed.bonus)" : parsed.bonus < 0 ? "\(parsed.bonus)" : ""

                Text("\(diceSum)\(bonusStr) = \(total) TP")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
                    .padding(.top, 6)
            }

            if isAnimating {
                Text(L("tapToRoll"))
                    .font(.dsaBody(.caption2))
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
        damageFinalRolls = (0..<parsed.count).map { _ in DiceRoller.roll(sides: parsed.sides) }
    }
}
