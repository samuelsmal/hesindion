import SwiftUI
import SwiftData

struct MountHealingSheet: View {
    let hero: Hero
    let mount: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var amount: Int = 1

    private var currentLE: Int { mount.currentLifeEnergy }
    private var maxLE: Int { mount.lifeEnergy }
    private var newLE: Int { Swift.min(currentLE + amount, maxLE) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Reittier: Heilung")
                .font(.dsaHeading(.headline))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupEquipment)
                .dsaBox(.flush)

            VStack(spacing: 16) {
                // Mount name
                Text(mount.name)
                    .font(.dsaHeading(.title3))

                // +/- stepper
                HStack(spacing: 0) {
                    Button { if amount > 1 { amount -= 1 } } label: {
                        Text("−")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupEquipment.opacity(0.3))
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)

                    Text("\(amount)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.raised)

                    Button { amount += 1 } label: {
                        Text("+")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupEquipment.opacity(0.3))
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)
                }

                // Preview
                Text("\(currentLE) + \(amount) → \(newLE) / \(maxLE) LP")
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(.secondary)

                // Confirm button
                Button {
                    let clampedLE = Swift.min(currentLE + amount, maxLE)
                    let actualHealing = clampedLE - currentLE
                    mount.currentLifeEnergy = clampedLE
                    let entry = LogEntry.create(
                        kind: "mountLPChange",
                        payload: MountLPChangePayload(petName: mount.name, lpChange: actualHealing),
                        hero: hero
                    )
                    modelContext.insert(entry)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.dsaHeading(.title2))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupEquipment)
                        .dsaBox(.raised)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(16)

            Spacer()
        }
    }
}
