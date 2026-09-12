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
            Color.dsaOverlay
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                headerView
                probeContent()
            }
            .background(Color(UIColor.systemBackground))
            // A modal on a scrim is the floating-container case the shadow is
            // reserved for (ADR-0009). This panel was `.flush` while three
            // controls *inside* it were `.raised`, so the only shadows on
            // screen were cast by contents onto their own neighbours — the
            // modifier row printed one across the hint box beneath it — while
            // the panel itself sat flat on the scrim.
            .dsaBox(.raised)
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
                .font(.dsaHeading(.headline))
            Spacer()
            Text(config.name)
                .font(.dsaHeading(.headline))
            Spacer()
            Text("\(config.skillValue)")
                .font(.dsaHeading(.headline))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(config.accentColor)
        .dsaBox(.flush)
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
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(line.value < 0 ? Color.groupCombat : config.accentColor)
                    Text("\(line.source): \(line.value >= 0 ? "+" : "")\(line.value)")
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(line.value < 0 ? Color.groupCombat : config.accentColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((line.value < 0 ? Color.groupCombat : config.accentColor).opacity(0.1))
                .dsaBox(.flush, stroke: line.value < 0 ? Color.groupCombat : config.accentColor)
            }

            // Hints
            ForEach(hints) { hint in
                HStack(spacing: 8) {
                    Image(systemName: hint.icon)
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(hint.color)
                    Text(hint.text)
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(hint.color)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hint.color.opacity(0.1))
                .dsaBox(.flush, stroke: hint.color)
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
                    .accessibilityIdentifier("skillCheck.die.\(i)")
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

            // Schip reroll affordance — only on a regular failure with Schips left.
            if hasResult, isRerollEligible(computeResult(rolls: fr)) {
                Button {
                    reroll()
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
                    .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
                .disabled(rerollSelection.isEmpty)
                .opacity(rerollSelection.isEmpty ? 0.5 : 1)

                Text("\(schipsRemaining) \(L("schip.remaining"))")
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            // Closing the check is an explicit act, not automatic: the result is
            // worth reading, and a Schip reroll is still on the table until it is
            // dismissed. Before this the only ways out were a scrim tap or a drag,
            // which are easy to miss and left the check sitting over the screen
            // that sent you here.
            if hasResult {
                Button(action: onDismiss) {
                    Text(L("confirm"))
                        .font(.dsaHeading(.body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(config.accentColor)
                        .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
                .padding(.top, 4)
                .accessibilityIdentifier("skillCheck.confirm")
            }
        }
        .padding(16)
    }

    // MARK: - Box Helpers

    private func attrBox(key: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(key)
                .font(.dsaBody(.caption))
                .foregroundStyle(Color.attributeForeground(for: key))
            Text("\(value)")
                .font(.dsaHeading(.title3))
                .foregroundStyle(Color.attributeForeground(for: key))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.attributeBackground(for: key))
        .dsaBox(.flush)
    }

    private func modBox(index: Int) -> some View {
        let mod = modifiers[index]
        let locked = finalRolls != nil
        return HStack(spacing: 0) {
            Button { modifiers[index] -= 1 } label: {
                Text("\u{2212}")
                    .font(.dsaBody(.body))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(segmentStyle(locked: locked))
            .disabled(locked)

            Text(mod >= 0 ? "+\(mod)" : "\(mod)")
                .font(.dsaBody(.body))
                .foregroundStyle(locked ? Color.dsaDisabledLabel : Color.primary)
                .frame(minWidth: 28)

            Button { modifiers[index] += 1 } label: {
                Text("+")
                    .font(.dsaBody(.body))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(segmentStyle(locked: locked))
            .disabled(locked)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
    }

    /// Spec 010's colour flip, for segments with no shadow to press into.
    private func segmentStyle(locked: Bool) -> DSASegmentPressStyle {
        DSASegmentPressStyle(
            tint: Color(UIColor.systemBackground),
            foreground: locked ? Color.dsaDisabledLabel : Color.primary
        )
    }

    private func diceBox(value: Int, isAnimating: Bool, selected: Bool) -> some View {
        Text("\(value)")
            .font(.dsaHeading(.title3))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isAnimating ? config.accentColor.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .dsaBox(.flush)
            .dsaBox(.flush, stroke: selected ? Color.dsaSchipGold : Color.clear)
    }

    private func resultBox(value: Int) -> some View {
        Text("\(value)")
            .font(.dsaBody(.body))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.flush)
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
            .font(.dsaBody(.body))
            .foregroundStyle(resultTextColor(result))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(resultBackground(result))
            .dsaBox(.flush)
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
                displayRolls = DiceRoller.roll(count: 3, sides: 20)
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
        let rolls = DiceRoller.roll(count: 3, sides: 20)
        finalRolls = rolls
        emitResult(rolls: rolls, schipReroll: false)
    }

    private func reroll() {
        guard let current = finalRolls, !schipUsed, !rerollSelection.isEmpty else { return }
        guard schipsRemaining > 0 else { return }

        // Spend one Schip and lock out further rerolls this check.
        hero.derivedValues?.schicksalspunkte.current -= 1
        schipUsed = true

        // Reroll only the selected dice; keep the others.
        var newRolls = current
        for i in rerollSelection { newRolls[i] = Int.random(in: 1...20) }
        finalRolls = newRolls

        emitResult(rolls: newRolls, schipReroll: true)
    }

    private func emitResult(rolls: [Int], schipReroll: Bool) {
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

        onResult?(SkillCheckResult(
            rolls: rolls,
            qualityLevel: qs,
            succeeded: succeeded,
            isCriticalSuccess: isCritSuccess,
            isCriticalFailure: isCritFailure,
            remainingSkillPoints: remaining
        ))

        let entry = LogEntry.create(
            kind: config.logKind,
            payload: TalentCheckPayload(
                talentName: config.name,
                qualityLevel: qs,
                succeeded: succeeded,
                schipReroll: schipReroll ? true : nil
            ),
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
