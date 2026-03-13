import SwiftUI
import SwiftData

// MARK: - TalentProbeModal

struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil

    @State private var modifiers = [0, 0, 0]
    @State private var displayRolls = [Int](repeating: 1, count: 3)
    @State private var finalRolls: [Int]? = nil
    @State private var animationTask: Task<Void, Never>? = nil

    private var probeData: (keys: [String], values: [Int])? {
        guard let attrs = hero.attributes else { return nil }
        return TalentProbeAttributes.lookup(talent: talent.name, attributes: attrs)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                headerView
                if let data = probeData {
                    probeContent(data: data)
                } else {
                    Text(L("unknownTalent"))
                        .padding()
                }
            }
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
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
            Text(L("probe"))
                .font(.system(.headline, weight: .black))
            Spacer()
            Text(talent.name)
                .font(.system(.headline, weight: .black))
            Spacer()
            Text("\(talent.value)")
                .font(.system(.headline, weight: .black))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.groupPersonalData)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }

    // MARK: - Probe Content

    @ViewBuilder
    private func probeContent(data: (keys: [String], values: [Int])) -> some View {
        let rolls = finalRolls ?? displayRolls
        let hasResult = finalRolls != nil
        let fr = finalRolls ?? [0, 0, 0]

        VStack(spacing: 0) {
            // Attribute boxes
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    attrBox(key: data.keys[i], value: data.values[i])
                }
            }

            // Modifier boxes
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    modBox(index: i)
                }
            }

            // Schmerz penalty warning
            if hero.schmerzPenalty != 0 {
                let level = hero.effectiveSchmerzLevel
                let label = level >= 4 ? L("schmerz.IV") : L("schmerz.\(String(repeating: "I", count: level))")
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Color.groupCombat)
                    Text("\(label): \(hero.schmerzPenalty) \(L("source.schmerz"))")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Color.groupCombat)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.groupCombat.opacity(0.1))
                .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
            }

            // Aufmerksamkeit hint for Sinnenschärfe (TAL_8)
            if hero.hasAufmerksamkeit && talent.ruleId == "TAL_8" {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Color.groupPersonalData)
                    Text(L("aufmerksamkeitHint"))
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Color.groupPersonalData)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.groupPersonalData.opacity(0.1))
                .overlay(Rectangle().stroke(Color.groupPersonalData, lineWidth: 2))
            }

            // Dice row (tap to roll)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    diceBox(value: rolls[i], isAnimating: !hasResult)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { roll() }

            // Result boxes — always in layout to keep modal size fixed
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    let excess = fr[i] - (data.values[i] + modifiers[i])
                    resultBox(value: excess > 0 ? -excess : 0)
                }
            }
            .opacity(hasResult ? 1 : 0)

            // Summary bar — always in layout to keep modal size fixed
            let result = computeResult(rolls: fr, attrValues: data.values, mods: modifiers)
            summaryBar(rolls: fr, attrValues: data.values, result: result)
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
                Text("−")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(locked ? .secondary : .primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(locked)

            Text(mod >= 0 ? "+\(mod)" : "\(mod)")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(locked ? Color.secondary : Color.primary)
                .frame(minWidth: 20)

            Button { modifiers[index] += 1 } label: {
                Text("+")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(locked ? .secondary : .primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(locked)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
    }

    private func diceBox(value: Int, isAnimating: Bool) -> some View {
        Text("\(value)")
            .font(.system(.title3, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isAnimating ? Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
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

    private func summaryText(rolls: [Int], attrValues: [Int], result: ProbeResult) -> String {
        let excesses = (0..<3).map { i -> Int in
            let excess = rolls[i] - (attrValues[i] + modifiers[i])
            return excess > 0 ? excess : 0
        }
        let remaining = talent.value - excesses.reduce(0, +)
        switch result {
        case .kritischerPatzer:
            return "Kritischer Patzer!"
        case .kritischerErfolg:
            return "Kritischer Erfolg!"
        case .qs(let qs):
            return "\(talent.value) - \(excesses.map { String($0) }.joined(separator: " - ")) = \(remaining) → QS\(qs)"
        }
    }

    private func summaryBar(rolls: [Int], attrValues: [Int], result: ProbeResult) -> some View {
        Text(summaryText(rolls: rolls, attrValues: attrValues, result: result))
            .font(.system(.body, weight: .bold))
            .foregroundStyle(resultTextColor(result))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(resultBackground(result))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    // MARK: - Result Computation

    private enum ProbeResult {
        case kritischerPatzer
        case kritischerErfolg
        case qs(Int)
    }

    private func computeResult(rolls: [Int], attrValues: [Int], mods: [Int]) -> ProbeResult {
        let ones = rolls.filter { $0 == 1 }.count
        let twenties = rolls.filter { $0 == 20 }.count
        if ones >= 2 { return .kritischerPatzer }
        if twenties >= 2 { return .kritischerErfolg }
        let schmerzMod = hero.schmerzPenalty
        var remaining = talent.value
        for i in 0..<3 {
            let excess = rolls[i] - (attrValues[i] + mods[i] + schmerzMod)
            if excess > 0 { remaining -= excess }
        }
        if remaining <= 0 { return .qs(0) }
        return .qs(min(6, Int(ceil(Double(remaining) / 3.0))))
    }

    // MARK: - Colors

    private func resultBackground(_ result: ProbeResult) -> Color {
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

    private func resultTextColor(_ result: ProbeResult) -> Color {
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
        if let onRolled, let data = probeData {
            let result = computeResult(rolls: rolls, attrValues: data.values, mods: modifiers)
            let succeeded: Bool
            switch result {
            case .kritischerPatzer: succeeded = false
            case .kritischerErfolg: succeeded = true
            case .qs(let n): succeeded = n > 0
            }
            onRolled(succeeded)
        }
    }

}
