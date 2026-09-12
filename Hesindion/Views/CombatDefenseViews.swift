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
    var isRangedAttack: Bool = false
    var rangedDefensePenalty: Int = 0
    /// Trefferzone announced for this attack, if any. Read-only here — the app has no
    /// opponent model to apply the wound effect to (see `WoundEffectReminderCard`).
    var announcedZone: HitZone? = nil
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
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)

                Spacer()

                VStack(spacing: 1) {
                    Text(L("opponentDefense"))
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

            // MARK: Body
            VStack(spacing: 8) {
                // Critical hit info boxes
                if isCriticalHit {
                    infoBox(L("opponentDefense.halved"), icon: "exclamationmark.triangle.fill")
                }
                if isDoubleDamage {
                    infoBox(L("opponentDefense.doubleDamage"), icon: "flame.fill")
                }

                // Ranged attack info boxes
                if isRangedAttack {
                    infoBox(L("opponentDefense.noWeaponParry"), icon: "xmark.shield.fill")
                    if rangedDefensePenalty != 0 {
                        infoBox(L("opponentDefense.schusswaffe"), icon: "arrow.down.circle.fill")
                    }
                }

                // Maneuver reminder notes from the attack phase
                if let lines = modifierLines, !lines.isEmpty {
                    combatSectionLabel(L("announcement.label"))
                    ForEach(lines) { line in
                        HStack {
                            Text(line.value > 0 ? "+\(line.value)" : "\(line.value)")
                                .font(.dsaMono(.caption, emphasis: true))
                                .foregroundStyle(line.value > 0
                                    ? Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
                                    : combatAccent)
                            Spacer()
                            Text(line.source)
                                .font(.dsaBody(.caption2))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)
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
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.raised, stroke: combatAccent)
                    }
                    .buttonStyle(.dsaMotion)

                    // Ausgewichen
                    Button {
                        logOpponentDefense(outcome: "dodged")
                        step = .root
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text(L("opponentDefense.dodged"))
                        }
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.raised, stroke: combatAccent)
                    }
                    .buttonStyle(.dsaMotion)

                    // Treffer geht durch
                    Button {
                        logOpponentDefense(outcome: "hit")
                        showDamage = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text(L("opponentDefense.hitThrough"))
                        }
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)
                }

                // Damage section
                if showDamage, let formula = damageFormula, let parsed = parseDamage(formula) {
                    damageSection(parsed: parsed)
                } else if showDamage && damageFormula == nil {
                    // No damage formula — skip straight to new action
                    neueAktionButton
                }

                // Wound-effect reminder — read-only GM prompt, nothing is applied (no
                // opponent model to apply it to).
                if showDamage, hero.isFokusRuleActive(.trefferzonen), let zone = announcedZone {
                    WoundEffectReminderCard(zone: zone)
                        .padding(.top, 8)
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
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isAnimating
                            ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity)
                            : Color(UIColor.systemBackground))
                        .dsaBox(.flush)
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
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                        .padding(.top, 6)
                } else {
                    Text("\(diceSum)\(bonusStr) = \(total) TP")
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                        .padding(.top, 6)
                }
            }

            if isAnimating {
                Text(L("tapToRoll"))
                    .font(.dsaBody(.caption2))
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
                    .font(.dsaHeading(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.dsaSchipGold)
                    .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
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
            .font(.dsaHeading(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(combatAccent)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
    }

    // MARK: - Info box helper

    private func infoBox(_ text: String, icon: String = "info.circle.fill") -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.dsaBody(.caption2))
            Text(text)
                .font(.dsaBody(.caption2))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(combatAccent.opacity(0.1))
        .dsaBox(.flush, stroke: combatAccent)
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
        case .fernkampf:  return .fernkampf
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
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)

            Spacer()

            VStack(spacing: 2) {
                Text(L("fumble.title"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Text(weaponName)
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

    // MARK: - Choice Buttons

    private var choiceButtons: some View {
        VStack(spacing: 12) {
            Button {
                choice = .simpleDamage
                rollSimpleDamage()
            } label: {
                VStack(spacing: 4) {
                    Text(L("fumble.takeDamage"))
                        .font(.dsaHeading(.title3))
                    Text(L("fumble.spIgnoresRS"))
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupCombat)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)

            Button {
                choice = .table
                rollTable()
            } label: {
                Text(L("fumble.rollTable"))
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dsaDark)
                    .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    // MARK: - Simple Damage Result

    @ViewBuilder
    private var simpleDamageResult: some View {
        if let roll = simpleDamageRoll {
            let total = roll + 2
            Text("\(roll) + 2 = \(total) SP")
                .font(.dsaHeading(.title3))
                .fontDesign(.monospaced)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupCombat)
                .foregroundStyle(.white)
                .dsaBox(.flush)

            Text(L("fumble.spIgnoresRS"))
                .font(.dsaBody(.caption))
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
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
                Text("+")
                    .font(.dsaBody(.body))
                Text("\(roll.die2)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
                Text("=")
                    .font(.dsaBody(.body))
                Text("\(total)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dsaDark)
                    .foregroundStyle(.white)
                    .dsaBox(.flush)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.dsaHeading(.body))
                Text(entry.description)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupCombat.opacity(0.1))
            .dsaBox(.flush, stroke: Color.groupCombat)
        }
    }

    // MARK: - New Action Button

    private var newActionButton: some View {
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

// MARK: - CombatFluchtView

struct CombatFluchtView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var opponentCount: Int = 1
    @State private var outcome: FluchtOutcome? = nil

    private enum FluchtOutcome { case success, failure }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                Spacer()
                Text(L("flucht"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
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

            VStack(spacing: 16) {
                // Info
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(combatAccent)
                    Text(L("flucht.info"))
                        .font(.dsaBody(.caption))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(combatAccent.opacity(0.1))
                .dsaBox(.flush, stroke: combatAccent)

                if outcome == nil {
                    // Opponent count stepper
                    combatSectionLabel(L("flucht.opponents"))

                    DSAStepper(
                        tint: combatAccent,
                        decrementDisabled: opponentCount <= 1,
                        onDecrement: { if opponentCount > 1 { opponentCount -= 1 } },
                        onIncrement: { opponentCount += 1 }
                    ) {
                        Text("\(opponentCount)")
                            .font(.dsaHeading(.largeTitle))
                            .fontDesign(.monospaced)
                            .padding(.vertical, 14)
                    }

                    Text("Erschwernis: \u{2013}\(opponentCount)")
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(.secondary)

                    // Outcome buttons
                    Button {
                        outcome = .success
                        logFlucht(succeeded: true)
                    } label: {
                        Text(L("flucht.succeeded"))
                            .font(.dsaHeading(.title3))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dsaPositive)
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)

                    Button {
                        outcome = .failure
                        logFlucht(succeeded: false)
                    } label: {
                        Text(L("flucht.failed"))
                            .font(.dsaHeading(.title3))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.groupCombat)
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)
                }

                // Result display
                if let outcome {
                    let gs = hero.derivedValues?.geschwindigkeit.max ?? 8
                    switch outcome {
                    case .success:
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dsaPositive)
                            Text(L("flucht.success"))
                                .font(.dsaBody(.body))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.dsaPositive.opacity(0.1))
                        .dsaBox(.flush, stroke: Color.dsaPositive)

                        Text("GS \(gs) Schritt")
                            .font(.dsaMono(.caption, emphasis: true))
                            .foregroundStyle(.secondary)

                    case .failure:
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.groupCombat)
                            Text(L("flucht.failure"))
                                .font(.dsaBody(.body))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.groupCombat.opacity(0.1))
                        .dsaBox(.flush, stroke: Color.groupCombat)

                        Text("GS/2 = \(gs / 2) Schritt")
                            .font(.dsaMono(.caption, emphasis: true))
                            .foregroundStyle(.secondary)
                    }

                    // Neue Aktion
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
            .adaptiveContentWidth()
            .padding(.vertical, 16)

            Spacer()
        }
    }

    private func logFlucht(succeeded: Bool) {
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId, round: roundNumber,
                action: .flucht, weaponName: nil,
                rollValue: nil,
                damageDealt: nil, damageTaken: nil,
                effectiveValue: nil,
                outcome: succeeded ? "success" : "failure",
                schipAction: nil, fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
}

// MARK: - CombatPassierschlagView

struct CombatPassierschlagView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var displayRoll: Int = 1
    @State private var finalRoll: Int? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil

    // AT -4, using selected weapon
    private var weapon: MeleeWeapon? { hero.selectedWeapon }
    private var weaponName: String { weapon?.name ?? "Raufen" }
    private var baseAT: Int {
        let raw = weapon?.at ?? (hero.combatTechniques.first { $0.name == "Raufen" }?.at ?? 0)
        return raw - 4  // Passierschlag penalty
    }
    private var damageFormula: String { weapon?.damage ?? "1W6" }

    private var isHit: Bool {
        guard let roll = finalRoll else { return false }
        return roll <= baseAT  // No criticals: 1 is just a success, 20 is just a miss
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)

                Spacer()

                VStack(spacing: 1) {
                    Text(L("passierschlag"))
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

            // MARK: Body
            VStack(spacing: 8) {
                // Info bar
                infoBox(L("passierschlag.info"))

                // Effective AT value
                HStack {
                    Text("AT \(baseAT)")
                        .font(.dsaMono(.body, emphasis: true))
                    Spacer()
                    Text(L("source.passierschlag"))
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dsaDark)
                .foregroundStyle(.white)

                // Dice box
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                // Outcome
                if let _ = finalRoll {
                    outcomeBar

                    if isHit {
                        // Damage section
                        if let parsed = parseDamage(damageFormula) {
                            damageSection(parsed: parsed)
                        }

                        if damageFinalRolls != nil {
                            neueAktionButton
                                .padding(.top, 8)
                        }
                    } else {
                        neueAktionButton
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
            damageAnimTask?.cancel()
        }
    }

    // MARK: - Dice box

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

    // MARK: - Outcome bar

    private var outcomeBar: some View {
        let hit = isHit
        return Text(hit ? L("success") : L("failure"))
            .font(.dsaBody(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(hit
                ? Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
                : Color.dsaDark)
            .dsaBox(.flush)
    }

    // MARK: - Info box

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(combatAccent.opacity(0.1))
        .dsaBox(.flush, stroke: combatAccent)
    }

    // MARK: - Neue Aktion

    private var neueAktionButton: some View {
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

    // MARK: - Damage

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

    private func damageSection(parsed: ParsedDamage) -> some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("damage.label"))

            let isAnimating = damageFinalRolls == nil
            let rolls = damageFinalRolls ?? damageDisplayRolls

            HStack(spacing: 6) {
                ForEach(0..<parsed.count, id: \.self) { i in
                    Text(i < rolls.count ? "\(rolls[i])" : "-")
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isAnimating
                            ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity)
                            : Color(UIColor.systemBackground))
                        .dsaBox(.flush)
                }
            }

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

    private func rollDice() {
        guard finalRoll == nil else { return }
        animationTask?.cancel()
        finalRoll = Int.random(in: 1...20)
        logPassierschlag()
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

    // MARK: - Logging

    private func logPassierschlag() {
        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId, round: roundNumber,
                action: .passierschlag, weaponName: weaponName,
                rollValue: finalRoll,
                damageDealt: nil, damageTaken: nil,
                effectiveValue: baseAT,
                outcome: isHit ? "hit" : "miss",
                schipAction: nil, fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
}
