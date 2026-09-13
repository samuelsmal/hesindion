import SwiftUI
import SwiftData

// MARK: - CombatOpponentDefenseView

struct CombatOpponentDefenseView: View {
    let hero: Hero
    let weaponName: String
    let damageFormula: String?
    let isCriticalHit: Bool
    /// What the critical did to the damage. `.double` under the basic rule,
    /// whatever the optional table rolled when it is in play (ADR-0011), and
    /// `.unchanged` for an ordinary hit.
    let criticalDamage: CriticalDamage
    let modifierLines: [ModifierLine]?
    /// TP bonuses the announcement worked out — Wuchtschlag, the two-handed
    /// grip, Sturmangriff, Golgariten-Stil. Carried here rather than folded into
    /// `damageFormula` so each can be named in the calculation.
    var damageLines: [ModifierLine] = []
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
    /// Settled in the wound-effect card, folded into the reported total.
    @State private var woundEffectDamage: Int? = nil
    @State private var damageDisplayRolls: [Int] = []
    @State private var damageFinalRolls: [Int]? = nil
    @State private var damageAnimTask: Task<Void, Never>? = nil
    @State private var damageSchipUsed: Bool = false
    /// TP the app cannot know about. The imported weapons carry no Leiteigenschaft
    /// threshold (there is no equipment table in `rules.db` — issue #14), so the
    /// TP/KK bonus, and any ability or GM ruling the app does not model, has to be
    /// enterable or the reported total is simply wrong.
    @State private var extraDamageModifier: Int = 0
    @State private var hasLoggedDamage: Bool = false

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
                if criticalDamage == .double {
                    infoBox(L("opponentDefense.doubleDamage"), icon: "flame.fill")
                } else if let label = criticalDamage.label {
                    // The optional table's own verdict — anything from "+2" to
                    // "×3" — instead of the basic rule's flat doubling.
                    infoBox("\(L("critical.damageEffect")): \(label)", icon: "flame.fill")
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
                                    ? Color.dsaPositive
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

                // The damage, in the order it is settled: roll the dice, add
                // anything by hand, settle the Wundeffekt — and then one
                // calculation with every part in it. There used to be two: the
                // weapon's own total in a dark bar, and a second dark bar below
                // the wound effect restating it with the Wundeffekt added.
                if showDamage, let formula = damageFormula, let parsed = DamageFormula.parse(formula) {
                    damageSection(parsed: parsed)
                    tpModifierBox
                        .padding(.top, 8)
                }

                // Nothing is applied — the opponent has no LP to subtract from
                // (ADR-0005) — but the extra damage is settled here and belongs
                // in the calculation below.
                if showDamage, hero.isFokusRuleActive(.trefferzonen), let zone = announcedZone {
                    WoundEffectReminderCard(zone: zone, extraDamage: $woundEffectDamage)
                        .padding(.top, 8)
                }

                if showDamage,
                   let formula = damageFormula,
                   let parsed = DamageFormula.parse(formula),
                   damageFinalRolls != nil {
                    CombatBreakdownBox(
                        rows: damageRows(parsed: parsed),
                        totalValue: "\(appliedTotal ?? 0) \(L("tp"))",
                        totalSource: L("damage.totalTP"),
                        sectionLabel: L("calculation.label")
                    )
                    .padding(.top, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("combat.dealDamage.breakdown")
                }

                // Last, because it leaves the screen. It used to sit inside the
                // damage section, above the wound effect.
                if showDamage, damageFormula == nil || damageFinalRolls != nil {
                    neueAktionButton
                        .padding(.top, 8)
                }
            }
            .adaptiveContentWidth()
            .padding(.vertical, 16)

            Spacer()
        }
        .onDisappear {
            damageAnimTask?.cancel()
            // The log used to be written inside the Schip reroll button's
            // `onAppear`, so a hero with no Schicksalspunkte dealt damage that
            // was never logged at all. Here it is the settled total — Wundeffekt
            // and manual TP included — written exactly once.
            if let total = appliedTotal, !hasLoggedDamage {
                hasLoggedDamage = true
                logDamageDealt(total)
            }
        }
    }

    // MARK: - Damage Section

    private func damageSection(parsed: DamageFormula) -> some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("damage.label"))

            let isAnimating = damageFinalRolls == nil
            let rolls = damageFinalRolls ?? damageDisplayRolls

            // The dice are the thing to tap while they are still tumbling. Once
            // they settle they are the calculation's first row, so showing them
            // here as well printed the same result twice.
            if isAnimating {
                HStack(spacing: 6) {
                    ForEach(0..<parsed.count, id: \.self) { i in
                        Text(i < rolls.count ? "\(rolls[i])" : "-")
                            .font(.dsaHeading(.title3))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity))
                            .dsaBox(.flush)
                    }
                }

                Text(L("tapToRoll"))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            // Schip reroll — only shown after dice are finalised, before schip is spent
            if damageFinalRolls != nil, !damageSchipUsed,
               (hero.derivedValues?.schicksalspunkte.current ?? 0) > 0 {
                Button {
                    hero.derivedValues?.schicksalspunkte.current -= 1
                    damageSchipUsed = true
                    if var rolls = damageFinalRolls,
                       let minIdx = rolls.indices.min(by: { rolls[$0] < rolls[$1] }) {
                        rolls[minIdx] = DiceRoller.roll(sides: parsed.sides)
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
            }

        }
        .contentShape(Rectangle())
        .onTapGesture { rollDamage(parsed: parsed) }
        .onAppear { startDamageAnimation(parsed: parsed) }
    }

    /// "+4" / "-1" / "" — one signed term of the printed damage formula.
    private static func term(_ value: Int) -> String {
        value > 0 ? "+\(value)" : value < 0 ? "\(value)" : ""
    }

    /// TP the app has no data for: the weapon's Leiteigenschaft bonus above all,
    /// which no Optolith export carries. It sits outside the dice box because
    /// that box is one big tap target for the roll.
    private var tpModifierBox: some View {
        VStack(spacing: 0) {
            DSAStepper(
                decrementIcon: "arrow.down",
                incrementIcon: "arrow.up",
                tint: combatAccent,
                incrementIdentifier: "combat.dealDamage.increaseModifier",
                onDecrement: { extraDamageModifier -= 1 },
                onIncrement: { extraDamageModifier += 1 }
            ) {
                Text(extraDamageModifier >= 0 ? "+\(extraDamageModifier)" : "\(extraDamageModifier)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            Text(L("damage.extraModifier"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                // Clear the stepper's shadow, which draws outside its bounds and
                // reserves no layout space.
                .padding(.top, DSALayout.shadowOffset + 4)
        }
        .accessibilityIdentifier("combat.dealDamage.modifier")
    }

    // MARK: - Reported total

    /// One row per part of the damage, in the order they apply.
    private func damageRows(parsed: DamageFormula) -> [BreakdownRow] {
        var rows: [BreakdownRow] = []
        let dice = damageFinalRolls ?? []
        let diceSum = dice.reduce(0, +)
        // With more than one die the individual results ride along in the source,
        // so folding the dice into the calculation loses nothing: "7  2W6 (4 + 3)".
        let diceSource = dice.count > 1
            ? "\(parsed.count)W\(parsed.sides) (\(dice.map(String.init).joined(separator: " + ")))"
            : "\(parsed.count)W\(parsed.sides)"
        rows.append(BreakdownRow(value: "\(diceSum)", source: diceSource))
        if parsed.bonus != 0 {
            rows.append(.signed(parsed.bonus, L("source.weapon")))
        }
        for line in damageLines {
            rows.append(.line(line))
        }
        if extraDamageModifier != 0 {
            rows.append(.signed(extraDamageModifier, L("source.additional")))
        }
        // A critical multiplies everything above it, so it comes after the parts
        // it multiplies and it is not a signed term.
        if let label = criticalDamage.label {
            rows.append(BreakdownRow(
                value: label,
                source: L("critical.damageEffect"),
                tint: Color.groupCombat
            ))
        }
        // The Wundeffekt is the weapon's damage plus something the zone did, so
        // it lands after the multiplier rather than inside it.
        if let extra = woundEffectDamage, extra > 0 {
            rows.append(.signed(extra, L("trefferzone.woundEffect")))
        }
        return rows
    }

    /// The weapon's damage with every part applied — the Wundeffekt is added
    /// after, in the reported total, because it is not the weapon's doing.
    private func weaponDamageTotal(parsed: DamageFormula) -> Int {
        let diceSum = (damageFinalRolls ?? []).reduce(0, +)
        let bonuses = damageLines.reduce(0) { $0 + $1.value }
        return criticalDamage.apply(to: max(0, diceSum + parsed.bonus + bonuses + extraDamageModifier))
    }

    /// The weapon's damage plus any settled Wundeffekt. `nil` until the dice are
    /// finalised, since there is nothing to total before then.
    private var appliedTotal: Int? {
        guard let formula = damageFormula,
              let parsed = DamageFormula.parse(formula),
              let rolls = damageFinalRolls else { return nil }
        _ = rolls
        return weaponDamageTotal(parsed: parsed) + (woundEffectDamage ?? 0)
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

    // MARK: - Dice animation & rolling

    private func startDamageAnimation(parsed: DamageFormula) {
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

    private func rollDamage(parsed: DamageFormula) {
        guard damageFinalRolls == nil else { return }
        damageAnimTask?.cancel()
        damageFinalRolls = (0..<parsed.count).map { _ in DiceRoller.roll(sides: parsed.sides) }
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

    // Through `DiceRoller`, not `Int.random`, so `ScriptedDice` can drive the
    // fumble branches from a UI test the way it drives every other roll.
    private func rollSimpleDamage() {
        let roll = DiceRoller.roll(sides: 6)
        simpleDamageRoll = roll
        applySimpleDamage(roll + 2)
    }

    private func rollTable() {
        let d1 = DiceRoller.roll(sides: 6)
        let d2 = DiceRoller.roll(sides: 6)
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
                        if let parsed = DamageFormula.parse(damageFormula) {
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
                ? Color.dsaPositive
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

    private func damageSection(parsed: DamageFormula) -> some View {
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
        finalRoll = DiceRoller.roll(sides: 20)
        logPassierschlag()
    }

    private func startDamageAnimation(parsed: DamageFormula) {
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

    private func rollDamage(parsed: DamageFormula) {
        guard damageFinalRolls == nil else { return }
        damageAnimTask?.cancel()
        damageFinalRolls = (0..<parsed.count).map { _ in DiceRoller.roll(sides: parsed.sides) }
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
