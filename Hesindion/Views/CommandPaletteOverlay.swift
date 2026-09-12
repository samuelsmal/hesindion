import SwiftUI
import SwiftData

// MARK: - RegenerierenSheet

struct RegenerierenSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var userModifier: Int = 0
    @State private var animTask: Task<Void, Never>? = nil

    private var baseMod: Int { hero.verbessertRegenerationLEBonus }
    private var totalMod: Int { baseMod + userModifier }
    private var healing: Int { Swift.max(0, (d6Result ?? 0) + totalMod) }
    private var currentLE: Int { hero.derivedValues?.lebensenergie.current ?? 0 }
    private var maxLE: Int { hero.derivedValues?.lebensenergie.max ?? 0 }
    private var newLE: Int { Swift.min(currentLE + healing, maxLE) }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("regeneration"))
                .font(.dsaHeading(.headline))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .dsaBox(.flush)

            VStack(spacing: 8) {
                diceBox
                    .contentShape(Rectangle())
                    .onTapGesture { rollDie() }

                modifierBox

                if d6Result != nil {
                    resultBox
                    confirmButton
                }
            }
            .padding(16)

            Spacer()
        }
        .onAppear { startAnimation() }
        .onDisappear { animTask?.cancel() }
    }

    // MARK: - Subviews

    private var diceBox: some View {
        let isRolled = d6Result != nil
        let display = d6Result ?? d6Display
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(display)")
                    .font(.dsaHeading(.largeTitle))
                    .fontDesign(.monospaced)
                if !isRolled {
                    Text(L("tapToRoll"))
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(!isRolled ? Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .dsaBox(.flush)
            Text("W6")
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var modifierBox: some View {
        let locked = d6Result != nil
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { userModifier -= 1 } label: {
                    Image(systemName: "arrow.down")
                        .font(.dsaBody(.body))
                        .foregroundStyle(locked ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.dsaDisabled : Color.groupPersonalData)
                }
                .buttonStyle(.dsaMotion)
                .disabled(locked)
                .dsaBox(.flush)

                VStack(spacing: 2) {
                    Text(totalMod >= 0 ? "+\(totalMod)" : "\(totalMod)")
                        .font(.dsaHeading(.title3))
                        .fontDesign(.monospaced)
                    if baseMod > 0 {
                        Text("\(L("improvedRegen")) +\(baseMod)")
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 64)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                .dsaBox(.flush)

                Button { userModifier += 1 } label: {
                    Image(systemName: "arrow.up")
                        .font(.dsaBody(.body))
                        .foregroundStyle(locked ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.dsaDisabled : Color.groupPersonalData)
                }
                .buttonStyle(.dsaMotion)
                .disabled(locked)
                .dsaBox(.flush)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            Text(L("modifier"))
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var resultBox: some View {
        let d6 = d6Result ?? 0
        let formulaStr: String
        if totalMod > 0 {
            formulaStr = "W6(\(d6)) + \(totalMod) = \(healing)"
        } else if totalMod < 0 {
            formulaStr = "W6(\(d6)) \(totalMod) = \(healing)"
        } else {
            formulaStr = "W6 = \(d6)"
        }
        return VStack(spacing: 4) {
            Text(formulaStr)
                .font(.dsaHeading(.body))
                .fontDesign(.monospaced)
            Text("\(currentLE) + \(healing) → \(newLE) / \(maxLE) LP")
                .font(.dsaMono(.caption, emphasis: true))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
    }

    private var confirmButton: some View {
        Button {
            let actualHealing = newLE - currentLE
            if actualHealing > 0 {
                let entry = LogEntry.create(
                    kind: "rest",
                    payload: RestPayload(lpRestored: actualHealing, duration: nil),
                    hero: hero
                )
                modelContext.insert(entry)
            }
            hero.derivedValues?.lebensenergie.current = newLE
            dismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.dsaHeading(.title2))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupPersonalData)
                .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
    }

    // MARK: - Animation & Rolling

    private func startAnimation() {
        animTask = Task { @MainActor in
            while !Task.isCancelled && d6Result == nil {
                d6Display = Int.random(in: 1...6)
                do { try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval) } catch { break }
            }
        }
    }

    private func rollDie() {
        guard d6Result == nil else { return }
        animTask?.cancel()
        d6Result = Int.random(in: 1...6)
    }
}

// MARK: - CommandSearchOverlay

struct CommandSearchOverlay: View {
    @Binding var query: String
    @Binding var isVisible: Bool
    @Binding var activeCommand: AppCommand?
    let commands: [AppCommand]
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black)
                TextField(L("searchCommands"), text: $query)
                    .focused(isFocused)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("commandPalette.search")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.groupPersonalData)
            .dsaBox(.flush)

            // Results
            let maxHeight = UIScreen.main.bounds.height / 3
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !commands.isEmpty {
                        ForEach(commands) { cmd in
                            Button {
                                activeCommand = cmd
                                query = ""
                                isVisible = false
                            } label: {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(cmd.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    Divider()
                                }
                            }
                            .buttonStyle(.dsaMotion)
                        }
                    } else if !query.isEmpty {
                        Text(L("noResults"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                }
            }
            .frame(maxHeight: maxHeight)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.flush)
        }
        .padding(.horizontal, 16)
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height < -50 {
                    query = ""
                    isVisible = false
                }
            }
        )
    }

}

// MARK: - CommandModal

struct CommandModal: View {
    let command: AppCommand
    @Binding var activeCommand: AppCommand?
    @State private var amount: Int = 0

    var body: some View {
        ZStack {
            Color.dsaOverlay
                .ignoresSafeArea()
                .onTapGesture { activeCommand = nil }

            VStack(spacing: 20) {
                // Header
                Text(command.displayName)
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.groupPersonalData)
                    .dsaBox(.flush)

                // Input
                if let input = command.input, case .integerAmount(let label, let min, let max, _) = input {
                    if command.name == "lebensenergie", let max {
                        LPBarView(current: amount, max: max) {
                            amount = Swift.max(min, amount - 1)
                        } onIncrement: {
                            amount = Swift.min(max, amount + 1)
                        }
                        .accessibilityLabel(label)
                    } else {
                        VStack(spacing: 8) {
                            if let max {
                                Text("/ \(max)")
                                    .font(.dsaBody(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(amount)")
                                .font(.dsaHeading(.largeTitle))

                            HStack(spacing: 16) {
                                Button {
                                    amount = Swift.max(min, amount - 1)
                                } label: {
                                    Text("−")
                                        .font(.dsaHeading(.title))
                                        .foregroundStyle(Color.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.groupPersonalData)
                                        .dsaBox(.raised)
                                }
                                .buttonStyle(.dsaMotion)

                                Button {
                                    let cap = max.map { Swift.min($0, amount + 1) } ?? (amount + 1)
                                    amount = cap
                                } label: {
                                    Text("+")
                                        .font(.dsaHeading(.title))
                                        .foregroundStyle(Color.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.groupPersonalData)
                                        .dsaBox(.raised)
                                }
                                .buttonStyle(.dsaMotion)
                            }
                        }
                        .accessibilityLabel(label)
                    }
                }

                // Confirm
                Button {
                    if command.input != nil {
                        command.execute(.integerAmount(amount))
                    } else {
                        command.execute(nil)
                    }
                    activeCommand = nil
                } label: {
                    Image(systemName: "checkmark")
                        .font(.dsaHeading(.title2))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupPersonalData)
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.flush)
            .padding(32)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < -50 { activeCommand = nil }
                }
            )
        }
        .onAppear {
            if let input = command.input, case .integerAmount(_, _, _, let initial) = input {
                amount = initial
            }
        }
    }
}

// MARK: - MountDamageSheet

struct MountDamageSheet: View {
    let hero: Hero
    let mount: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var spAmount: Int = 1
    @State private var damageApplied = false
    @State private var showingProbeModal = false
    @State private var probeSucceeded: Bool? = nil

    private var penalty: Int { spAmount / 5 }

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("mountTakesDamage"))
                .font(.dsaHeading(.headline))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupCombat)
                .dsaBox(.flush)

            VStack(spacing: 16) {
                if !damageApplied {
                    spInput
                } else {
                    reitenCheckContent
                }
            }
            .padding(16)

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty
                )
            }
        }
    }

    private var spInput: some View {
        VStack(spacing: 12) {
            Text(mount.name)
                .font(.dsaHeading(.title3))

            HStack(spacing: 0) {
                Button { if spAmount > 1 { spAmount -= 1 } } label: {
                    Text("−")
                        .font(.dsaHeading(.title))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat.opacity(0.3))
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)

                Text("\(spAmount)")
                    .font(.dsaHeading(.largeTitle))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)

                Button { spAmount += 1 } label: {
                    Text("+")
                        .font(.dsaHeading(.title))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat.opacity(0.3))
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
            }

            Text(L("mountDamage.sp"))
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.dsaBody(.body))
                    .foregroundStyle(Color.groupCombat)
            } else {
                Text(L("mountDamage.noPenalty"))
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
            }

            Button {
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)
                let entry = LogEntry.create(
                    kind: "mountLPChange",
                    payload: MountLPChangePayload(petName: mount.name, lpChange: -spAmount),
                    hero: hero
                )
                modelContext.insert(entry)
                withAnimation { damageApplied = true }
            } label: {
                Text(L("mountDamage.apply"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.groupCombat)
                    .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    @ViewBuilder
    private var reitenCheckContent: some View {
        if let talent = reitenTalent {
            if let succeeded = probeSucceeded {
                resultView(succeeded: succeeded)
            } else {
                rollPromptView
            }
        } else {
            manualCheckView
        }
    }

    private func resultView(succeeded: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(succeeded ? Color.groupEquipment : Color.groupCombat)

            Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                .font(.dsaHeading(.title3))

            if !succeeded {
                Text(L("mountDamage.sturz"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(Color.groupCombat)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.groupCombat.opacity(0.1))
                    .dsaBox(.flush, stroke: Color.groupCombat)
            }

            Button { dismiss() } label: {
                Image(systemName: "checkmark")
                    .font(.dsaHeading(.title2))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.groupCombat)
                    .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    private var rollPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dice.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.groupCombat)

            Text(L("reitenCheck"))
                .font(.dsaHeading(.title3))

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.dsaBody(.body))
                    .foregroundStyle(Color.groupCombat)
            }

            Button { showingProbeModal = true } label: {
                Text(L("rollReitenCheck"))
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.groupCombat)
                    .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
        }
    }

    private var manualCheckView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.groupCombat)

            Text(L("reitenCheckPrompt"))
                .font(.dsaHeading(.title3))

            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.dsaBody(.body))
                    .foregroundStyle(Color.groupCombat)
            }

            HStack(spacing: 12) {
                Button { probeSucceeded = false } label: {
                    Text(L("no"))
                        .font(.dsaBody(.body))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)

                Button { probeSucceeded = true } label: {
                    Text(L("yes"))
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.groupCombat)
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
            }
        }
    }
}
