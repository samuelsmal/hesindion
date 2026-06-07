import SwiftUI
import SwiftData

// MARK: - SkillCheckConfig

struct SkillCheckConfig {
    let title: String
    let name: String
    let skillValue: Int
    let checkAttributes: [(key: String, value: Int)]
    let accentColor: Color
    let modifierLines: [ModifierLine]
    let logKind: String
}

// MARK: - SkillCheckResult

struct SkillCheckResult {
    let rolls: [Int]
    let qualityLevel: Int
    let succeeded: Bool
    let isCriticalSuccess: Bool
    let isCriticalFailure: Bool
    let remainingSkillPoints: Int
}

// MARK: - SkillCheckModal

struct SkillCheckModal: View {
    let config: SkillCheckConfig
    let hero: Hero
    var onDismiss: () -> Void
    var onResult: ((SkillCheckResult) -> Void)? = nil
    var initialModifier: Int = 0
    var hints: [SkillCheckHint] = []

    @Environment(\.modelContext) private var modelContext
    @State private var modifiers: [Int]
    @State private var displayRolls = [Int](repeating: 1, count: 3)
    @State private var finalRolls: [Int]? = nil
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var schipUsed = false
    @State private var rerollSelection: Set<Int> = [0, 1, 2]  // all dice selected by default

    init(
        config: SkillCheckConfig,
        hero: Hero,
        onDismiss: @escaping () -> Void,
        onResult: ((SkillCheckResult) -> Void)? = nil,
        previewFinalRolls: [Int]? = nil,
        initialModifier: Int = 0,
        hints: [SkillCheckHint] = []
    ) {
        self.config = config
        self.hero = hero
        self.onDismiss = onDismiss
        self.onResult = onResult
        self.initialModifier = initialModifier
        self.hints = hints
        _modifiers = State(initialValue: [initialModifier, initialModifier, initialModifier])
        _finalRolls = State(initialValue: previewFinalRolls)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                headerView
                probeContent()
            }
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            .frame(maxWidth: 400)
            .padding(24)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < -50 { onDismiss() }
                }
            )
        }
        .onAppear { startAnimation() }
        .onDisappear { animationTask?.cancel() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(config.title)
                .font(.system(.headline, weight: .black))
            Spacer()
            Text(config.name)
                .font(.system(.headline, weight: .black))
            Spacer()
            Text("\(config.skillValue)")
                .font(.system(.headline, weight: .black))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(config.accentColor)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }

    // MARK: - Probe Content

    @ViewBuilder
    private func probeContent() -> some View {
        let rolls = finalRolls ?? displayRolls
        let hasResult = finalRolls != nil
        let fr = finalRolls ?? [0, 0, 0]
        let engineMod = config.modifierLines.reduce(0) { $0 + $1.value }

        VStack(spacing: 0) {
            // Attribute boxes
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    attrBox(key: config.checkAttributes[i].key, value: config.checkAttributes[i].value)
                }
            }

            // Modifier boxes
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    modBox(index: i)
                }
            }

            // Modifier lines from engine
            ForEach(config.modifierLines) { line in
                HStack(spacing: 8) {
                    Image(systemName: line.value < 0 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(line.value < 0 ? Color.groupCombat : config.accentColor)
                    Text("\(line.source): \(line.value >= 0 ? "+" : "")\(line.value)")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(line.value < 0 ? Color.groupCombat : config.accentColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((line.value < 0 ? Color.groupCombat : config.accentColor).opacity(0.1))
                .overlay(Rectangle().stroke(line.value < 0 ? Color.groupCombat : config.accentColor, lineWidth: 2))
            }

            // Hints
            ForEach(hints) { hint in
                HStack(spacing: 8) {
                    Image(systemName: hint.icon)
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(hint.color)
                    Text(hint.text)
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(hint.color)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hint.color.opacity(0.1))
                .overlay(Rectangle().stroke(hint.color, lineWidth: 2))
            }

            // Dice row — tap to roll; once failed with Schips available, tap to
            // toggle which dice the Schip reroll will replace.
            let rerollEligible = hasResult && isRerollEligible(computeResult(rolls: fr))
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    diceBox(
                        value: rolls[i],
                        isAnimating: !hasResult,
                        selected: rerollEligible && rerollSelection.contains(i)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !hasResult {
                            roll()
                        } else if rerollEligible {
                            if rerollSelection.contains(i) {
                                rerollSelection.remove(i)
                            } else {
                                rerollSelection.insert(i)
                            }
                        }
                    }
                }
            }

            // Result boxes
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    let excess = fr[i] - (config.checkAttributes[i].value + modifiers[i] + engineMod)
                    resultBox(value: excess > 0 ? -excess : 0)
                }
            }
            .opacity(hasResult ? 1 : 0)

            // Summary bar
            let result = computeResult(rolls: fr)
            summaryBar(rolls: fr, result: result)
                .opacity(hasResult ? 1 : 0)
        }
        .padding(16)
    }

    // MARK: - Box Helpers

    private func attrBox(key: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(key)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(Color.attributeForeground(for: key))
            Text("\(value)")
                .font(.system(.title3, weight: .black))
                .foregroundStyle(Color.attributeForeground(for: key))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.attributeBackground(for: key))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
    }

    private func modBox(index: Int) -> some View {
        let mod = modifiers[index]
        let locked = finalRolls != nil
        return HStack(spacing: 0) {
            Button { modifiers[index] -= 1 } label: {
                Text("\u{2212}")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(locked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)

            Text(mod >= 0 ? "+\(mod)" : "\(mod)")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(locked ? Color.secondary : Color.primary)
                .frame(minWidth: 28)

            Button { modifiers[index] += 1 } label: {
                Text("+")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(locked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
    }

    private func diceBox(value: Int, isAnimating: Bool, selected: Bool) -> some View {
        Text("\(value)")
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isAnimating ? config.accentColor.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
            .overlay(
                Rectangle().stroke(
                    selected ? Color(red: 0.6, green: 0.5, blue: 0.0) : Color.clear,
                    lineWidth: 3
                )
            )
    }

    private func resultBox(value: Int) -> some View {
        Text("\(value)")
            .font(.system(.body, weight: .bold))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
    }

    // MARK: - Summary Bar

    private func summaryText(rolls: [Int], result: CheckResult) -> String {
        let engineMod = config.modifierLines.reduce(0) { $0 + $1.value }
        let excesses = (0..<3).map { i -> Int in
            let excess = rolls[i] - (config.checkAttributes[i].value + modifiers[i] + engineMod)
            return excess > 0 ? excess : 0
        }
        let remaining = config.skillValue - excesses.reduce(0, +)
        switch result {
        case .kritischerPatzer:
            return "Kritischer Patzer!"
        case .kritischerErfolg:
            return "Kritischer Erfolg!"
        case .qs(let qs) where qs == 0:
            return "\(config.skillValue) - \(excesses.map { String($0) }.joined(separator: " - ")) = \(remaining) \u{2192} Nicht bestanden"
        case .qs(let qs):
            return "\(config.skillValue) - \(excesses.map { String($0) }.joined(separator: " - ")) = \(remaining) \u{2192} QS\(qs)"
        }
    }

    private func summaryBar(rolls: [Int], result: CheckResult) -> some View {
        Text(summaryText(rolls: rolls, result: result))
            .font(.system(.body, weight: .bold))
            .foregroundStyle(resultTextColor(result))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(resultBackground(result))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    // MARK: - Result Computation

    private enum CheckResult {
        case kritischerPatzer
        case kritischerErfolg
        case qs(Int)
    }

    private var schipsRemaining: Int {
        hero.derivedValues?.schicksalspunkte.current ?? 0
    }

    /// Schip reroll is offered only on a regular failure (QS 0) — not on a
    /// critical botch and not on any success. Mirrors the combat decision.
    private func isRerollEligible(_ result: CheckResult) -> Bool {
        guard case .qs(0) = result else { return false }
        return !schipUsed && schipsRemaining > 0
    }

    private func computeResult(rolls: [Int]) -> CheckResult {
        let engineMod = config.modifierLines.reduce(0) { $0 + $1.value }
        let attrValues = (0..<3).map { config.checkAttributes[$0].value + modifiers[$0] + engineMod }
        let outcome = SkillCheckEngine.evaluate(
            rolls: rolls,
            attributeValues: attrValues,
            skillPoints: config.skillValue
        )
        switch outcome {
        case .criticalFailure: return .kritischerPatzer
        case .criticalSuccess: return .kritischerErfolg
        case .regular(let qs, _): return .qs(qs)
        }
    }

    // MARK: - Colors

    private func resultBackground(_ result: CheckResult) -> Color {
        switch result {
        case .kritischerPatzer: return .groupCombat
        case .kritischerErfolg: return Color(red: 0x00 / 255.0, green: 0xc8 / 255.0, blue: 0x53 / 255.0)
        case .qs(let n) where n == 0: return .dsaDark
        case .qs(let n) where n == 1: return Color(red: 0x1a / 255.0, green: 0x5c / 255.0, blue: 0x2e / 255.0)
        case .qs(let n) where n == 2: return Color(red: 0x1e / 255.0, green: 0x7a / 255.0, blue: 0x3c / 255.0)
        case .qs(let n) where n == 3: return Color(red: 0x22 / 255.0, green: 0x91 / 255.0, blue: 0x3c / 255.0)
        case .qs(let n) where n == 4: return Color(red: 0x28 / 255.0, green: 0xa7 / 255.0, blue: 0x45 / 255.0)
        case .qs(let n) where n == 5: return Color(red: 0x4c / 255.0, green: 0xaf / 255.0, blue: 0x50 / 255.0)
        case .qs(let n) where n == 6: return Color(red: 0x8b / 255.0, green: 0xc3 / 255.0, blue: 0x4a / 255.0)
        default: return .dsaDark
        }
    }

    private func resultTextColor(_ result: CheckResult) -> Color {
        switch result {
        case .qs(let n) where n >= 4: return .primary
        default: return .white
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                displayRolls = (0..<3).map { _ in Int.random(in: 1...20) }
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch {
                    break
                }
            }
        }
    }

    private func roll() {
        guard finalRolls == nil else { return }
        animationTask?.cancel()
        let rolls = (0..<3).map { _ in Int.random(in: 1...20) }
        finalRolls = rolls

        let result = computeResult(rolls: rolls)
        let qs: Int
        let succeeded: Bool
        let isCritSuccess: Bool
        let isCritFailure: Bool
        switch result {
        case .kritischerPatzer: qs = 0; succeeded = false; isCritSuccess = false; isCritFailure = true
        case .kritischerErfolg: qs = 6; succeeded = true; isCritSuccess = true; isCritFailure = false
        case .qs(let n): qs = n; succeeded = n > 0; isCritSuccess = false; isCritFailure = false
        }

        let engineMod = config.modifierLines.reduce(0) { $0 + $1.value }
        let excesses = (0..<3).map { i -> Int in
            let excess = rolls[i] - (config.checkAttributes[i].value + modifiers[i] + engineMod)
            return excess > 0 ? excess : 0
        }
        let remaining = config.skillValue - excesses.reduce(0, +)

        let skillCheckResult = SkillCheckResult(
            rolls: rolls,
            qualityLevel: qs,
            succeeded: succeeded,
            isCriticalSuccess: isCritSuccess,
            isCriticalFailure: isCritFailure,
            remainingSkillPoints: remaining
        )
        onResult?(skillCheckResult)

        let entry = LogEntry.create(
            kind: config.logKind,
            payload: TalentCheckPayload(talentName: config.name, qualityLevel: qs, succeeded: succeeded),
            hero: hero
        )
        modelContext.insert(entry)
    }
}

// MARK: - SkillCheckHint

struct SkillCheckHint: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
}
