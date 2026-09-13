import SwiftUI
import SwiftData

// MARK: - CombatFernkampfSetupView

struct CombatFernkampfSetupView: View {
    let hero: Hero
    @Binding var step: CombatStep
    let mountedActive: Bool
    let beengteUmgebungActive: Bool
    let schipIgnoreZustandThisRound: Bool
    @Binding var announcedZone: HitZone?
    var onDismiss: () -> Void

    @State private var distanz: Int = 1         // 0=nah, 1=mittel, 2=weit
    @State private var groesse: Int = 2         // 0=winzig..4=riesig
    @State private var bewegungZiel: Int = 1    // 0=still..3=haken
    @State private var bewegungSchuetze: Int = 0 // 0=steht..2=rennt
    @State private var sicht: Int = 0           // 0=klar..3=stufe3
    @State private var kampfgetuemmel: Bool = false
    @State private var zielen: Int = 0          // 0/1/2 actions
    @State private var vomPferd: Int = 0        // 0=steht, 1=schritt, 2=galopp
    @State private var targetZone: HitZone? = nil
    @State private var targetIsSurprised = false

    // MARK: - Modifier computation (non-ViewBuilder helpers)

    private func buildModifierLines() -> [ModifierLine] {
        var context = ModifierContext(hero: hero, domain: .rangedAttack)
        context.targetHitZone = targetZone
        context.targetIsSurprised = targetIsSurprised
        context.mounted = mountedActive
        context.schipIgnoreZustand = schipIgnoreZustandThisRound
        context.distanz = distanz
        context.groesse = groesse
        context.bewegungZiel = bewegungZiel
        context.bewegungSchuetze = bewegungSchuetze
        context.sicht = sicht
        context.kampfgetuemmel = kampfgetuemmel
        context.zielen = zielen
        context.vomPferd = vomPferd

        return ModifierEngine.shared.evaluate(context: context)
    }

    private var distanzTP: Int {
        switch distanz {
        case 0: return 1   // nah: +1 TP
        case 2: return -1  // weit: -1 TP
        default: return 0
        }
    }

    private var totalModifier: Int {
        buildModifierLines().reduce(0) { $0 + $1.value }
    }

    private var effectiveFK: Int {
        (hero.selectedRangedWeapon?.at ?? 0) + totalModifier
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    distanzSection
                    groesseSection
                    bewegungZielSection
                    bewegungSchuetzeSection
                    sichtSection
                    kampfgetuemmelSection
                    zielenSection
                    if mountedActive {
                        vomPferdSection
                    }
                    if hero.isFokusRuleActive(.trefferzonen) {
                        trefferzoneSection
                    }
                    modifierSummary

                    continueButton
                        .padding(.top, 8)
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
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

            VStack(spacing: 1) {
                Text(L("fernkampf.setup"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                if let weapon = hero.selectedRangedWeapon {
                    Text(weapon.name)
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white.opacity(0.85))
                }
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

    // MARK: - Distanz Section

    private var distanzSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.distanz"))

            HStack(spacing: 8) {
                let labels = [L("fernkampf.distanz.nah"), L("fernkampf.distanz.mittel"), L("fernkampf.distanz.weit")]
                let mods = ["+2", "\u{00B1}0", "\u{2013}2"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: distanz == i) {
                        distanz = i
                    }
                }
            }

            if distanzTP != 0 {
                tpHint(distanzTP)
            }
        }
    }

    // MARK: - Größe Section

    private var groesseSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.groesse"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.groesse.winzig"),
                    L("fernkampf.groesse.klein"),
                    L("fernkampf.groesse.mittel"),
                    L("fernkampf.groesse.gross"),
                    L("fernkampf.groesse.riesig")
                ]
                let mods = ["\u{2013}8", "\u{2013}4", "\u{00B1}0", "+4", "+8"]
                ForEach(0..<5, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: groesse == i) {
                        groesse = i
                    }
                }
            }
        }
    }

    // MARK: - Bewegung Ziel Section

    private var bewegungZielSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.bewegungZiel"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.ziel.still"),
                    L("fernkampf.ziel.leicht"),
                    L("fernkampf.ziel.schnell"),
                    L("fernkampf.ziel.haken")
                ]
                let mods = ["+2", "\u{00B1}0", "\u{2013}2", "\u{2013}4"]
                ForEach(0..<4, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: bewegungZiel == i) {
                        bewegungZiel = i
                    }
                }
            }
        }
    }

    // MARK: - Bewegung Schütze Section

    private var bewegungSchuetzeSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.bewegungSchuetze"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.schuetze.steht"),
                    L("fernkampf.schuetze.geht"),
                    L("fernkampf.schuetze.rennt")
                ]
                let mods = ["\u{00B1}0", "\u{2013}2", "\u{2013}4"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: bewegungSchuetze == i) {
                        bewegungSchuetze = i
                    }
                }
            }
        }
    }

    // MARK: - Sicht Section

    private var sichtSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.sicht"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.sicht.klar"),
                    L("fernkampf.sicht.stufe1"),
                    L("fernkampf.sicht.stufe2"),
                    L("fernkampf.sicht.stufe3")
                ]
                let mods = ["\u{00B1}0", "\u{2013}2", "\u{2013}4", "\u{2013}6"]
                ForEach(0..<4, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: sicht == i) {
                        sicht = i
                    }
                }
            }
        }
    }

    // MARK: - Kampfgetümmel Section

    private var kampfgetuemmelSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.kampfgetuemmel"))

            DSAToggleRow(
                title: L("fernkampf.kampfgetuemmel"),
                isOn: $kampfgetuemmel,
                accent: combatAccent,
                detail: "\u{2013}2"
            )
        }
    }

    // MARK: - Zielen Section

    private var zielenSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.zielen"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.zielen.0"),
                    L("fernkampf.zielen.1"),
                    L("fernkampf.zielen.2")
                ]
                let mods = ["\u{00B1}0", "+2", "+4"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: zielen == i) {
                        zielen = i
                    }
                }
            }
        }
    }

    // MARK: - Vom Pferd Section

    private var vomPferdSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.vomPferd"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.pferd.steht"),
                    L("fernkampf.pferd.schritt"),
                    L("fernkampf.pferd.galopp")
                ]
                let mods = ["\u{00B1}0", "\u{2013}4", "\u{2013}8"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: vomPferd == i) {
                        vomPferd = i
                    }
                }
            }
        }
    }

    // MARK: - Trefferzone Section

    private var trefferzoneSection: some View {
        CombatZonePicker(
            selection: $targetZone,
            targetIsSurprised: $targetIsSurprised,
            showsPenalty: true,
            showsSurprisedToggle: true,
            hasSonderfertigkeit: hero.combatSpecialAbilities.contains { $0.ruleId == "SA_161" },
            sfHalvesKey: "trefferzone.sfHalves.ranged"
        )
    }

    // MARK: - Modifier Summary

    private var modifierSummary: some View {
        let lines = buildModifierLines()
        let baseFK = hero.selectedRangedWeapon?.at ?? 0
        return VStack(spacing: 0) {
            if !lines.isEmpty {
                combatSectionLabel(L("calculation.label"))

                VStack(spacing: 0) {
                    // Base FK row
                    modSummaryRow(label: "FK \(L("source.basis"))", value: baseFK, isBase: true)

                    ForEach(lines) { line in
                        modSummaryRow(label: line.source, value: line.value, isBase: false)
                    }

                    Divider()
                        .background(Color.dsaBorder)
                        .padding(.vertical, 4)

                    // Total
                    HStack {
                        Text("FK \(L("fernkampf"))")
                            .font(.dsaHeading(.body))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(effectiveFK)")
                            .font(.dsaHeading(.title3))
                            .fontDesign(.monospaced)
                            .foregroundStyle(effectiveFK < baseFK ? .red : (effectiveFK > baseFK ? combatAccent : .primary))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
                }
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        CombatActionButton(
            title: L("continue"),
            identifier: "combat.fernkampf.continue",
            isEnabled: hero.selectedRangedWeapon != nil
        ) {
            guard let weapon = hero.selectedRangedWeapon else { return }
            announcedZone = hero.isFokusRuleActive(.trefferzonen) ? targetZone : nil
            let mods = buildModifierLines()
            let fk = weapon.at + mods.reduce(0) { $0 + $1.value }
            step = .fernkampfExecution(
                weaponName: weapon.name,
                attributeValue: fk,
                damageFormula: weapon.damage,
                distanzTP: distanzTP,
                modifierLines: mods
            )
        }
    }

    // MARK: - Reusable sub-view helpers (non-@ViewBuilder returning some View)

    private func segmentButton(label: String, mod: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.dsaBody(.caption))
                Text(mod)
                    .font(.dsaMono(.caption2, emphasis: false))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
    }

    private func modSummaryRow(label: String, value: Int, isBase: Bool) -> some View {
        HStack {
            Text(label)
                .font(isBase ? .dsaHeading(.caption) : .dsaBody(.caption))
                .foregroundStyle(isBase ? .primary : .secondary)
            Spacer()
            Text(isBase ? "\(value)" : (value >= 0 ? "+\(value)" : "\(value)"))
                .font(.dsaMono(.caption, emphasis: false))
                .foregroundStyle(value < 0 ? .red : (value > 0 ? combatAccent : .secondary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tpHint(_ tp: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.dsaBody(.caption2))
            Text("\(L("tp")) \(tp > 0 ? "+\(tp)" : "\(tp)")")
                .font(.dsaBody(.caption))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - CombatFernkampfExecutionView

struct CombatFernkampfExecutionView: View {
    let hero: Hero
    let weaponName: String
    let attributeValue: Int   // effective FK after all modifiers
    let damageFormula: String
    let distanzTP: Int         // +1 nah, 0 mittel, -1 weit
    let modifierLines: [ModifierLine]
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext

    @State private var modifier: Int = 0
    @State private var displayRoll: Int = 1
    @State private var finalRoll: Int? = nil
    @State private var confirmRoll: Int? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var confirmAnimTask: Task<Void, Never>? = nil
    @State private var schipUsed: Bool = false
    @State private var hasLoggedRoll: Bool = false

    // MARK: - Computed

    private var effectiveValue: Int { attributeValue + modifier }

    /// Base FK before situational modifiers (they are already baked into attributeValue).
    private var baseFK: Int {
        attributeValue - modifierLines.reduce(0) { $0 + $1.value }
    }

    /// The distance TP as a named part rather than a number folded into the
    /// formula, so the damage screen can print where it came from.
    private var damageLines: [ModifierLine] {
        guard distanzTP != 0 else { return [] }
        return [ModifierLine(value: distanzTP, source: L("fernkampf.distanz"))]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 8) {
                modifierBreakdown
                modifierBox
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                if let fr = finalRoll, needsConfirm(fr) {
                    confirmBox
                }

                if let outcome = computedOutcome {
                    outcomeBar(outcome)

                    // Schip reroll — available on normal misserfolg (not fumble)
                    if outcome == .misserfolg && !schipUsed && (hero.derivedValues?.schicksalspunkte.current ?? 0) > 0 {
                        Button {
                            hero.derivedValues?.schicksalspunkte.current -= 1
                            schipUsed = true
                            hasLoggedRoll = false
                            logSchipUsed()
                            finalRoll = nil
                            confirmRoll = nil
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

                    outcomeActions(outcome)
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
        }
        .onChange(of: finalRoll) { logRollIfNeeded() }
        .onChange(of: confirmRoll) { logRollIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { step = .fernkampfSetup } label: {
                Image(systemName: "chevron.left")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)

            Spacer()

            VStack(spacing: 1) {
                Text(L("rangedAttack"))
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
    }

    // MARK: - Modifier breakdown

    @ViewBuilder
    /// The same calculation box the melee rolls use — this screen had its own
    /// copy, one bordered row per line, from before there was a shared one. The
    /// hardcoded "Effektiv" went with it.
    private var modifierBreakdown: some View {
        CombatBreakdownBox(
            baseValue: "\(baseFK)",
            baseSource: L("source.basis"),
            lines: modifier == 0
                ? modifierLines
                : modifierLines + [ModifierLine(value: modifier, source: L("source.additional"))],
            totalValue: "FK \(effectiveValue)",
            totalSource: L("source.effective"),
            sectionLabel: L("calculation.label")
        )
    }

    // MARK: - Manual modifier stepper

    private var modifierBox: some View {
        let locked = finalRoll != nil
        return VStack(spacing: 0) {
            DSAStepper(
                decrementIcon: "arrow.down",
                incrementIcon: "arrow.up",
                tint: locked ? Color.dsaDisabled : combatAccent,
                decrementDisabled: locked,
                incrementDisabled: locked,
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
                .padding(.top, 2)
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

    // MARK: - Confirm box

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

    private enum CombatOutcome {
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

    // MARK: - Outcome actions

    @ViewBuilder
    private func outcomeActions(_ outcome: CombatOutcome) -> some View {
        switch outcome {
        case .erfolg, .kritischerErfolg:
            if outcome == .kritischerErfolg {
                infoBox(L("opponentDefense.halved"))
                // See `CombatExecutionView`: with the optional table on, what
                // happens to the damage is the table's to say, not this screen's.
                if !hero.isFokusRuleActive(.kritischeErfolgeAngriff) {
                    infoBox(L("opponentDefense.doubleDamage"))
                }
            } else if finalRoll == 1 && confirmRoll != nil {
                infoBox(L("opponentDefense.halved"))
            }

            Button {
                // The Angriff table covers "AT oder FK" in its own wording, so a
                // critical shot reads the same table a critical swing does.
                if outcome == .kritischerErfolg, hero.isFokusRuleActive(.kritischeErfolgeAngriff) {
                    step = .criticalSuccess(
                        table: .angriff,
                        action: .fernkampf,
                        weaponName: weaponName,
                        damageFormula: damageFormula,
                        modifierLines: nil,
                        isRangedAttack: true,
                        rangedDefensePenalty: -4,
                        damageLines: damageLines
                    )
                } else {
                    step = .opponentDefense(
                        weaponName: weaponName,
                        damageFormula: damageFormula,
                        isCriticalHit: finalRoll == 1,
                        criticalDamage: outcome == .kritischerErfolg ? .double : .unchanged,
                        modifierLines: nil,
                        isRangedAttack: true,
                        rangedDefensePenalty: -4,
                        damageLines: damageLines
                    )
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                    Text(outcome == .kritischerErfolg && hero.isFokusRuleActive(.kritischeErfolgeAngriff)
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
            CombatActionButton(
                title: L("newAction"),
                icon: "arrow.counterclockwise",
                identifier: "combat.fernkampf.newAction"
            ) { step = .root }

        case .kritischerPatzer:
            Button {
                step = .fumbleChoice(action: .fernkampf, weaponName: weaponName, isShieldParry: false)
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

    private func rollDice() {
        guard finalRoll == nil else { return }
        animationTask?.cancel()
        let rolled = DiceRoller.roll(sides: 20)
        finalRoll = rolled
        if needsConfirm(rolled) { startConfirmAnimation() }
    }

    // MARK: - Logging

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

        let entry = LogEntry.create(
            kind: "combatAction",
            payload: CombatActionPayload(
                combatId: combatId,
                round: roundNumber,
                action: .rangedAttack,
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

    private func logSchipUsed() {
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
                schipAction: "reroll",
                fumbleTableResult: nil,
                lpChange: 0
            ),
            hero: hero
        )
        modelContext.insert(entry)
    }
}
