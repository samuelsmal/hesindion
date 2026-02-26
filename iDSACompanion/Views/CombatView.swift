import SwiftUI

// MARK: - Local types

private enum CombatAction {
    case angriff, parieren, ausweichen
}

private enum CombatStep {
    case root
    case weaponSelection(CombatAction)
    case execution(CombatAction, name: String, attributeValue: Int)
}

private let combatAccent = Color.groupCombat

private func combatSectionLabel(_ title: String) -> some View {
    HStack(spacing: 8) {
        Rectangle()
            .frame(height: 2)
            .foregroundStyle(combatAccent)
        Text(title)
            .font(.system(.caption, weight: .black))
            .foregroundStyle(combatAccent)
            .fixedSize()
        Rectangle()
            .frame(height: 2)
            .foregroundStyle(combatAccent)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}

// MARK: - CombatView (full-screen orchestrator)

struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @State private var step: CombatStep = .root

    private var stepID: String {
        switch step {
        case .root: "root"
        case .weaponSelection: "weaponSelection"
        case .execution: "execution"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .root:
                CombatRootView(hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .leading))
            case .weaponSelection(let action):
                CombatWeaponSelectionView(action: action, hero: hero, step: $step, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing))
            case .execution(let action, let name, let attrValue):
                CombatExecutionView(
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    step: $step,
                    onDismiss: onDismiss
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .gesture(DragGesture().onEnded { v in
            if v.translation.height > 80 {
                if case .root = step { onDismiss() } else { step = .root }
            }
        })
    }
}

// MARK: - CombatRootView

private struct CombatRootView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var roundNumber: Int = 1
    @State private var rolledInitiative: Int? = nil
    @State private var showInitiativeSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kampf")
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text(hero.name)
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
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
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            // INITIATIVE section
            combatSectionLabel("INITIATIVE")

            // INI + round counter + Neu button
            HStack(spacing: 0) {
                // INI box
                VStack(spacing: 2) {
                    Text("INI")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(rolledInitiative ?? hero.derivedValues?.initiative.value ?? 0)")
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .frame(width: 64)
                .background(Color(white: 0.18))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                // Round counter
                Text("Runde \(roundNumber)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                // Next round button
                Button { roundNumber += 1 } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52)
                        .frame(maxHeight: .infinity)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                }
                .buttonStyle(.plain)

                // Neuer Kampf compact button
                Button { showInitiativeSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                            .font(.system(.caption, weight: .bold))
                        Text("Neu")
                            .font(.system(.caption, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .sheet(isPresented: $showInitiativeSheet) {
                CombatInitiativeSheet(
                    heroBaseINI: hero.derivedValues?.initiative.value ?? 0,
                    mountBaseINI: hero.mount.map { $0.initiative },
                    mountName: hero.mount?.name
                ) { result in
                    rolledInitiative = result
                    roundNumber = 1
                    showInitiativeSheet = false
                }
                .presentationCornerRadius(0)
            }

            if hero.derivedValues != nil {
                // LEBENSPUNKTE section
                combatSectionLabel("LEBENSPUNKTE")
                lpBar
            }

            // AKTION section
            combatSectionLabel("AKTION")

            VStack(spacing: 8) {
                // Angriff — primary (filled)
                Button {
                    step = .weaponSelection(.angriff)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("Angriff")
                    }
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    // Parieren — secondary (outline)
                    Button {
                        step = .weaponSelection(.parieren)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                            Text("Parieren")
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    // Ausweichen — tertiary (outline)
                    Button {
                        let aw = hero.derivedValues?.ausweichen.value ?? 0
                        step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text("Ausweichen")
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    @ViewBuilder
    private var lpBar: some View {
        if let dv = hero.derivedValues {
            let current = dv.lebensenergie.current
            let max = dv.lebensenergie.max
            HStack(spacing: 0) {
                Button {
                    guard dv.lebensenergie.current > 0 else { return }
                    dv.lebensenergie.current -= 1
                } label: {
                    Text("▼")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 48)
                        .background(combatAccent)
                }
                .buttonStyle(.plain)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white)

                        let fraction = max > 0 ? CGFloat(current) / CGFloat(max) : 0
                        Rectangle()
                            .fill(lpBarColor(current: current, max: max))
                            .frame(width: geo.size.width * fraction)

                        Text("LP   \(current) / \(max)")
                            .font(.system(.body, weight: .black))
                            .foregroundStyle(lpTextColor(current: current, max: max))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 48)

                Button {
                    guard dv.lebensenergie.current < dv.lebensenergie.max else { return }
                    dv.lebensenergie.current += 1
                } label: {
                    Text("▲")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 48)
                        .background(combatAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    private func lpBarColor(current: Int, max: Int) -> Color {
        if current == 0 { return Color(red: 0, green: 0, blue: 0) }
        if current <= 5 { return Color(red: 0x8B / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0) }
        if max > 0 && current < max / 4 { return Color(red: 0xCC / 255.0, green: 0x22 / 255.0, blue: 0x00 / 255.0) }
        if max > 0 && current < max / 2 { return Color(red: 0xE0 / 255.0, green: 0x70 / 255.0, blue: 0x00 / 255.0) }
        if max > 0 && current < max * 3 / 4 { return Color(red: 0xD4 / 255.0, green: 0xC0 / 255.0, blue: 0x00 / 255.0) }
        return Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
    }

    private func lpTextColor(current: Int, max: Int) -> Color {
        if max > 0 && current >= max * 3 / 4 { return .white }
        return .black
    }

}

// MARK: - CombatWeaponSelectionView

private struct CombatWeaponSelectionView: View {
    let action: CombatAction
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    private var headerLabel: String {
        action == .angriff ? "Angriff" : "Parieren"
    }

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(headerLabel)
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)

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
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            ScrollView {
                VStack(spacing: 0) {
                    let statLabel = action == .angriff ? "AT" : "PA"

                    if !hero.meleeWeapons.isEmpty {
                        combatSectionLabel("NAHKAMPFWAFFEN (\(statLabel))")
                        ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                            let val = action == .angriff ? w.at : w.pa
                            weaponRow(name: w.name, statLabel: statLabel, statValue: val)
                        }
                    }

                    if !hero.shields.isEmpty {
                        combatSectionLabel("SCHILDE (\(statLabel))")
                        ForEach(hero.shields, id: \.persistentModelID) { s in
                            let val = action == .angriff ? s.at : s.pa
                            weaponRow(name: s.name, statLabel: statLabel, statValue: val)
                        }
                    }

                    combatSectionLabel("WAFFENLOS")
                    let rauferVal = action == .angriff ? (raufen?.at ?? 0) : (raufen?.pa ?? 0)
                    weaponRow(name: "Raufen", statLabel: statLabel, statValue: rauferVal)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func weaponRow(name: String, statLabel: String, statValue: Int) -> some View {
        Button {
            step = .execution(action, name: name, attributeValue: statValue)
        } label: {
            HStack {
                Text(name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(statLabel) \(statValue)")
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.18))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}

// MARK: - CombatExecutionView

private struct CombatExecutionView: View {
    let action: CombatAction
    let weaponName: String
    let attributeValue: Int
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var modifier: Int = 0
    @State private var displayRoll: Int = 1
    @State private var finalRoll: Int? = nil
    @State private var confirmRoll: Int? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var confirmAnimTask: Task<Void, Never>? = nil

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
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            VStack(spacing: 8) {
                // Row 1: AT/PA/AW value + Modifier side by side
                HStack(spacing: 8) {
                    valueBox("\(attributeValue)", label: attrLabel)
                    modifierBox
                }

                // Row 2: Dice box
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                // Row 3: Effective value
                valueBox(
                    finalRoll != nil ? "\(effectiveValue)" : "—",
                    label: "Effektiv",
                    dark: finalRoll != nil
                )
                .opacity(finalRoll != nil ? 1 : 0.3)

                // Row 4: Confirm (only for 1/20 rolls)
                if let fr = finalRoll, needsConfirm(fr) {
                    confirmBox
                }

                if let outcome = computedOutcome {
                    outcomeBar(outcome)
                }
            }
            .padding(16)

            if computedOutcome != nil {
                Button { step = .root } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Neue Aktion")
                    }
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear {
            animationTask?.cancel()
            confirmAnimTask?.cancel()
        }
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
                .background(dark ? Color(white: 0.18) : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
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
                    Text("−")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(minWidth: 44)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                Button {
                    modifier += 1
                } label: {
                    Text("+")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(locked ? Color.gray : combatAccent)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
            }
            .frame(maxWidth: .infinity)
            Text("Mod")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
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
                    Text("Antippen zum Würfeln")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isAnimating ? combatAccent.opacity(0.12) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
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
                .background(isAnimating ? combatAccent.opacity(0.12) : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
            Text("Bestätigung")
                .font(.system(.caption2, weight: .bold))
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
            .font(.system(isCritical ? .title3 : .body, weight: .bold))
            .foregroundStyle(outcomeTextColor(outcome))
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCritical ? 14 : 10)
            .background(outcomeBackground(outcome))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }

    private func outcomeText(_ outcome: CombatOutcome) -> String {
        switch outcome {
        case .kritischerErfolg: return "!!! Kritischer Erfolg!"
        case .kritischerPatzer: return "!!! Kritischer Patzer!"
        case .erfolg:           return "Erfolg"
        case .misserfolg:       return "Misserfolg"
        }
    }

    private func outcomeBackground(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return Color(red: 0x00 / 255.0, green: 0xc8 / 255.0, blue: 0x53 / 255.0)
        case .kritischerPatzer: return .groupCombat
        case .erfolg:           return Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0)
        case .misserfolg:       return .black
        }
    }

    private func outcomeTextColor(_ outcome: CombatOutcome) -> Color {
        switch outcome {
        case .kritischerErfolg: return .black
        default:                return .white
        }
    }

    // MARK: - Animation & rolling

    private func startAnimation() {
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                displayRoll = Int.random(in: 1...20)
                do {
                    try await Task.sleep(nanoseconds: 200_000_000)
                } catch { break }
            }
        }
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
                    try await Task.sleep(nanoseconds: 150_000_000)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            confirmRoll = Int.random(in: 1...20)
        }
    }
}

// MARK: - CombatInitiativeSheet

private struct CombatInitiativeSheet: View {
    let heroBaseINI: Int
    let mountBaseINI: Int?
    let mountName: String?
    var onConfirm: (Int) -> Void

    @State private var selectedBase: Int? = nil
    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var animTask: Task<Void, Never>? = nil

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return base + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Neue Initiative")
                .font(.system(.headline, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(combatAccent)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            VStack(spacing: 0) {
                // Base selector
                combatSectionLabel("BASIS")

                HStack(spacing: 8) {
                    baseButton(label: "Held", value: heroBaseINI)
                    if let mountINI = mountBaseINI {
                        baseButton(label: mountName ?? "Reittier", value: mountINI)
                    }
                }
                .padding(.horizontal, 16)

                // Dice + result
                if let base = selectedBase {
                    VStack(spacing: 8) {
                        // D6 box
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.system(.largeTitle, weight: .black))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text("Würfeln...")
                                        .font(.system(.caption2, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(0.12) : Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                            Text("W6")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // Calculation box
                        Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                            .font(.system(.title3, weight: .black))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                            .opacity(d6Result == nil ? 0.4 : 1)

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                onConfirm(t)
                            } label: {
                                Text("Bestätigen  →  INI \(t)")
                                    .font(.system(.body, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(label: String, value: Int) -> some View {
        let isSelected = selectedBase == value
        return Button {
            selectedBase = value
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, weight: .bold))
                Text("\(value)")
                    .font(.system(.title3, weight: .black))
            }
            .foregroundStyle(isSelected ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private func startD6Animation() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            var count = 0
            while !Task.isCancelled && count < 12 {
                d6Display = Int.random(in: 1...6)
                do {
                    try await Task.sleep(nanoseconds: 120_000_000)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            d6Result = Int.random(in: 1...6)
        }
    }
}
