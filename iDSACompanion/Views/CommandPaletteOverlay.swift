import SwiftUI

// MARK: - RegenerierenSheet

struct RegenerierenSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss

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
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

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
                    .font(.system(.largeTitle, weight: .black))
                    .fontDesign(.monospaced)
                if !isRolled {
                    Text(L("tapToRoll"))
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(!isRolled ? Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
            Text("W6")
                .font(.system(.caption2, weight: .bold))
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
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(locked ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                VStack(spacing: 2) {
                    Text(totalMod >= 0 ? "+\(totalMod)" : "\(totalMod)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                    if baseMod > 0 {
                        Text("\(L("improvedRegen")) +\(baseMod)")
                            .font(.system(.caption2))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 64)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))

                Button { userModifier += 1 } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(locked ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(locked ? Color.gray : Color.groupPersonalData)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            Text(L("modifier"))
                .font(.system(.caption2, weight: .bold))
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
                .font(.system(.body, weight: .black))
                .fontDesign(.monospaced)
            Text("\(currentLE) + \(healing) → \(newLE) / \(maxLE) LP")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }

    private var confirmButton: some View {
        Button {
            hero.derivedValues?.lebensenergie.current = newLE
            dismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        }
        .buttonStyle(.plain)
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
    @Binding var sidebarSelection: SidebarSelection?
    @Binding var lookupRuleId: String?
    let commands: [AppCommand]
    var isFocused: FocusState<Bool>.Binding

    private var ruleResults: [RuleSearchResult] {
        guard query.count >= 2 else { return [] }
        return RulesDatabase.shared.search(query: query, limit: 10)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black)
                TextField(L("searchRules"), text: $query)
                    .focused(isFocused)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.groupPersonalData)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            // Results
            let rules = ruleResults
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
                                            .foregroundStyle(Color.black)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    Divider()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !rules.isEmpty {
                        if !commands.isEmpty {
                            sectionHeader(L("rulebook"))
                        }
                        ForEach(rules) { rule in
                            Button {
                                lookupRuleId = rule.id
                                query = ""
                                isVisible = false
                            } label: {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(rule.name)
                                            .font(.body)
                                            .foregroundStyle(Color.black)
                                        Spacer()
                                        Text(ruleCategoryLabel(rule.category))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    Divider()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if commands.isEmpty && rules.isEmpty {
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
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, weight: .black))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.groupPersonalData.opacity(DSAAnimation.animatingBackgroundOpacity))
    }

    private func ruleCategoryLabel(_ category: String) -> String {
        L("cat.\(category)")
    }
}

// MARK: - CommandModal

struct CommandModal: View {
    let command: AppCommand
    @Binding var activeCommand: AppCommand?
    @State private var amount: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { activeCommand = nil }

            VStack(spacing: 20) {
                // Header
                Text(command.displayName)
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.groupPersonalData)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

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
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(amount)")
                                .font(.system(.largeTitle, weight: .black))

                            HStack(spacing: 16) {
                                Button {
                                    amount = Swift.max(min, amount - 1)
                                } label: {
                                    Text("−")
                                        .font(.system(.title, weight: .bold))
                                        .foregroundStyle(Color.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.groupPersonalData)
                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    let cap = max.map { Swift.min($0, amount + 1) } ?? (amount + 1)
                                    amount = cap
                                } label: {
                                    Text("+")
                                        .font(.system(.title, weight: .bold))
                                        .foregroundStyle(Color.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.groupPersonalData)
                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                                }
                                .buttonStyle(.plain)
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
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupPersonalData)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
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
