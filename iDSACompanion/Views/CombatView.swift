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

// MARK: - CombatView (full-screen orchestrator)

struct CombatView: View {
    let hero: Hero
    var onDismiss: () -> Void

    @State private var step: CombatStep = .root

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .root:
                CombatRootView(hero: hero, step: $step, onDismiss: onDismiss)
            case .weaponSelection(let action):
                CombatWeaponSelectionView(action: action, hero: hero, step: $step, onDismiss: onDismiss)
            case .execution(let action, let name, let attrValue):
                CombatExecutionView(
                    action: action,
                    weaponName: name,
                    attributeValue: attrValue,
                    step: $step,
                    onDismiss: onDismiss
                )
            }
        }
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

            // Neuer Kampf
            Button { roundNumber = 1 } label: {
                Text("Neuer Kampf")
                    .font(.system(.body, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .overlay(Rectangle().stroke(combatAccent, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // INI + round counter
            HStack(spacing: 0) {
                // INI box
                VStack(spacing: 2) {
                    Text("INI")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(hero.derivedValues?.initiative.value ?? 0)")
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 64)
                .padding(.vertical, 8)
                .background(Color(white: 0.18))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                // Round counter
                Text("Runde \(roundNumber)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                // Next round button
                Button { roundNumber += 1 } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52)
                        .padding(.vertical, 10)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if hero.derivedValues != nil {
                lpBar
            }

            // Action buttons
            VStack(spacing: 0) {
                actionButton("Angriff") {
                    step = .weaponSelection(.angriff)
                }
                actionButton("Parieren") {
                    step = .weaponSelection(.parieren)
                }
                actionButton("Ausweichen") {
                    let aw = hero.derivedValues?.ausweichen.value ?? 0
                    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: aw)
                }
            }
            .padding(16)

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
                        .foregroundStyle(.black)
                        .frame(width: 44)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

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
                        .foregroundStyle(.black)
                        .frame(width: 44)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(Rectangle().stroke(Color.black.opacity(0.15), lineWidth: 1))
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

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.body, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(combatAccent)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
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
                    ForEach(hero.meleeWeapons, id: \.persistentModelID) { w in
                        let val = action == .angriff ? w.at : w.pa
                        weaponRow(name: w.name, statValue: val)
                    }
                    ForEach(hero.shields, id: \.persistentModelID) { s in
                        let val = action == .angriff ? s.at : s.pa
                        weaponRow(name: s.name, statValue: val)
                    }
                    let rauferVal = action == .angriff ? (raufen?.at ?? 0) : (raufen?.pa ?? 0)
                    weaponRow(name: "Raufen", statValue: rauferVal)
                }
                .padding(16)
            }
        }
    }

    private func weaponRow(name: String, statValue: Int) -> some View {
        Button {
            step = .execution(action, name: name, attributeValue: statValue)
        } label: {
            HStack {
                Text(name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                Text("\(statValue)")
                    .font(.system(.body, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
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

            VStack(spacing: 0) {
                valueBox("\(attributeValue)")

                modifierBox

                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                valueBox(finalRoll != nil ? "\(effectiveValue)" : "—")
                    .opacity(finalRoll != nil ? 1 : 0.3)

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
                    Text("Neue Aktion")
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

    private func valueBox(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private var modifierBox: some View {
        HStack(spacing: 0) {
            Button {
                modifier -= 1
            } label: {
                Text("−")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(combatAccent)
            }
            .buttonStyle(.plain)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

            Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                .font(.system(.title3, weight: .black))
                .fontDesign(.monospaced)
                .frame(minWidth: 44)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

            Button {
                modifier += 1
            } label: {
                Text("+")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(combatAccent)
            }
            .buttonStyle(.plain)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private var diceBox: some View {
        let isAnimating = finalRoll == nil
        let display = finalRoll ?? displayRoll
        return Text("\(display)")
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isAnimating ? combatAccent.opacity(0.15) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }

    private var confirmBox: some View {
        let isAnimating = confirmRoll == nil
        let display: String = {
            if let cr = confirmRoll { return "\(cr)" }
            return "\(displayRoll)"
        }()
        return Text(display)
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isAnimating ? combatAccent.opacity(0.15) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
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
        Text(outcomeText(outcome))
            .font(.system(.body, weight: .bold))
            .foregroundStyle(outcomeTextColor(outcome))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(outcomeBackground(outcome))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }

    private func outcomeText(_ outcome: CombatOutcome) -> String {
        switch outcome {
        case .kritischerErfolg: return "Kritischer Erfolg!"
        case .kritischerPatzer: return "Kritischer Patzer!"
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
