import SwiftUI

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
                TextField("Befehl suchen…", text: $query)
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
            .background(Color.yellow)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

            // Results
            let maxHeight = UIScreen.main.bounds.height / 3
            ScrollView {
                LazyVStack(spacing: 0) {
                    if commands.isEmpty {
                        Text("Keine Befehle gefunden")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    } else {
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
                    .background(Color.yellow)
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
                                        .background(Color.yellow)
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
                                        .background(Color.yellow)
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
                        .background(Color.yellow)
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
