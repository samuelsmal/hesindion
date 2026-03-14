import SwiftUI

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
                .font(.system(.headline, weight: .black))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groupEquipment)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            VStack(spacing: 16) {
                // Mount name
                Text(mount.name)
                    .font(.system(.title3, weight: .bold))

                // +/- stepper
                HStack(spacing: 0) {
                    Button { if amount > 1 { amount -= 1 } } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.groupEquipment.opacity(0.3))
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
                            .background(Color.groupEquipment.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                // Preview
                Text("\(currentLE) + \(amount) → \(newLE) / \(maxLE) LP")
                    .font(.system(.caption, design: .monospaced))
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
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groupEquipment)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Spacer()
        }
    }
}
