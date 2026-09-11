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
                .font(.dsaHeading(.headline))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupPersonalData)
                .dsaBox(.flush)

            VStack(spacing: 16) {
                // Source text field
                TextField(L("healingSourcePlaceholder"), text: $source)
                    .font(.dsaBody(.body))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)
                    .autocorrectionDisabled()

                // +/- stepper for LP amount
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Button { if amount > 1 { amount -= 1 } } label: {
                            Text("−")
                                .font(.dsaHeading(.title))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.groupPersonalData.opacity(0.3))
                                .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)

                        Text("\(amount)")
                            .font(.dsaHeading(.largeTitle))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .dsaBox(.flush)

                        Button { amount += 1 } label: {
                            Text("+")
                                .font(.dsaHeading(.title))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.groupPersonalData.opacity(0.3))
                                .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)
                    }

                    Text("LP")
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                }

                // Preview
                Text("\(currentLE) + \(amount) → \(newLE) / \(maxLE) LP")
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush)

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
                        .font(.dsaHeading(.title2))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupPersonalData)
                        .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(16)

            Spacer()
        }
    }
}
