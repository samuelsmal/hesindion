import SwiftUI
import SwiftData

struct DiceRollSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let allowedSides = [3, 4, 6, 8, 10, 12, 20]

    @State private var diceCount: Int = 1
    @State private var sidesIndex: Int = 2 // default W6
    @State private var rollResults: [Int]? = nil
    @State private var displayValues: [Int] = [1]
    @State private var animTask: Task<Void, Never>? = nil

    private var sides: Int { Self.allowedSides[sidesIndex] }
    private var total: Int { rollResults?.reduce(0, +) ?? 0 }
    private var isRolled: Bool { rollResults != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L("diceRoll"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 8) {
                configSection
                diceDisplay
                    .contentShape(Rectangle())
                    .onTapGesture { rollDice() }

                if isRolled {
                    resultSummary
                    confirmButton
                }
            }
            .padding(16)

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear { animTask?.cancel() }
    }

    // MARK: - Config Section

    private var configSection: some View {
        HStack(spacing: 12) {
            stepperRow(
                label: L("diceCount"),
                value: diceCount,
                onDecrement: { if diceCount > 1 { diceCount -= 1; syncDisplayValues() } },
                onIncrement: { if diceCount < 10 { diceCount += 1; syncDisplayValues() } }
            )
            stepperRow(
                label: L("diceSides"),
                displayValue: "W\(sides)",
                onDecrement: { if sidesIndex > 0 { sidesIndex -= 1 } },
                onIncrement: { if sidesIndex < Self.allowedSides.count - 1 { sidesIndex += 1 } }
            )
        }
        .disabled(isRolled)
        .opacity(isRolled ? 0.5 : 1)
    }

    private func stepperRow(
        label: String,
        value: Int? = nil,
        displayValue: String? = nil,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onDecrement) {
                    Image(systemName: "arrow.down")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(isRolled ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isRolled ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Text(displayValue ?? "\(value ?? 0)")
                    .font(.system(.title3, weight: .black))
                    .fontDesign(.monospaced)
                    .frame(minWidth: 48)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                Button(action: onIncrement) {
                    Image(systemName: "arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(isRolled ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isRolled ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .fixedSize(horizontal: false, vertical: true)

            Text(label)
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Dice Display

    private var diceDisplay: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                ForEach(Array((rollResults ?? displayValues).enumerated()), id: \.offset) { _, value in
                    Text("\(value)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                }
            }
            if !isRolled {
                Text(L("tapToRoll"))
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(!isRolled ? Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }

    // MARK: - Result Summary

    private var resultSummary: some View {
        let results = rollResults ?? []
        let dice = "\(diceCount)W\(sides)"
        let formulaStr: String
        if results.count == 1 {
            formulaStr = "\(dice) = \(total)"
        } else {
            let parts = results.map(String.init).joined(separator: " + ")
            formulaStr = "\(dice) = \(parts) = \(total)"
        }

        return Text(formulaStr)
            .font(.system(.body, weight: .black))
            .fontDesign(.monospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            if let results = rollResults {
                let payload = DiceRollPayload(
                    count: diceCount,
                    sides: sides,
                    results: results,
                    total: total
                )
                let entry = LogEntry.create(kind: "diceRoll", payload: payload, hero: hero)
                modelContext.insert(entry)
            }
            dismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animation & Rolling

    private func syncDisplayValues() {
        displayValues = DiceRoller.roll(count: diceCount, sides: sides)
    }

    private func startAnimation() {
        syncDisplayValues()
        animTask = Task { @MainActor in
            while !Task.isCancelled && rollResults == nil {
                syncDisplayValues()
                do { try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval) } catch { break }
            }
        }
    }

    private func rollDice() {
        guard rollResults == nil else { return }
        animTask?.cancel()
        rollResults = DiceRoller.roll(count: diceCount, sides: sides)
    }
}
