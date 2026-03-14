import SwiftUI
import SwiftData

struct HeilungSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var source: String = ""
    @State private var amount: Int = 1

    private var currentLE: Int { hero.derivedValues?.lebensenergie.current ?? 0 }
    private var maxLE: Int { hero.derivedValues?.lebensenergie.max ?? 0 }
    private var newLE: Int { Swift.min(currentLE + amount, maxLE) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L("healing"))
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 16) {
                // Source text field
                TextField(L("healingSourcePlaceholder"), text: $source)
                    .font(.system(.body, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    .autocorrectionDisabled()

                // +/- stepper for LP amount
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Button { if amount > 1 { amount -= 1 } } label: {
                            Text("−")
                                .font(.system(.title, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.groupPersonalData.opacity(0.3))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        }
                        .buttonStyle(.plain)

                        Text("\(amount)")
                            .font(.system(.largeTitle, weight: .black))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                        Button { amount += 1 } label: {
                            Text("+")
                                .font(.system(.title, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.groupPersonalData.opacity(0.3))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("LP")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                // Preview
                Text("\(currentLE) + \(amount) → \(newLE) / \(maxLE) LP")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                // Confirm
                Button {
                    let actualHealing = newLE - currentLE
                    if actualHealing > 0 {
                        let entry = LogEntry.create(
                            kind: "healing",
                            payload: HealingPayload(
                                source: source.isEmpty ? "?" : source,
                                lpRestored: actualHealing
                            ),
                            hero: hero
                        )
                        modelContext.insert(entry)
                    }
                    hero.derivedValues?.lebensenergie.current = newLE
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
            .padding(16)

            Spacer()
        }
    }
}
