import SwiftUI

extension PetImportProblem {
    /// "Notizen: „Biss AT 156TP …" – kein Angriff (…)", for a row under the pet's own name.
    var fieldMessage: String {
        "\(field.rawValue): „\(text)\" – \(L("pet.problem.\(reason.rawValue)"))"
    }

    /// The same with the pet's name first, for the import's list of all pets.
    var message: String { "\(pet) · \(fieldMessage)" }
}

/// The import's result when a pet field could not be read in full (issue #49): what the import
/// did, then each problem. Shown instead of the plain result alert.
struct ImportProblemsModal: View {
    let title: String
    let message: String
    let problems: [PetImportProblem]
    let onDismiss: () -> Void

    var body: some View {
        DSAModal(title: title, accent: .groupEquipment, onClose: onDismiss, scrolls: true) {
            Text(message)
                .font(.dsaBody(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L("import.problems.intro"))
                .font(.dsaBody(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(problems.enumerated()), id: \.offset) { _, problem in
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsaBody(.caption))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            DSAModalButton(title: L("ok"), accent: .groupEquipment, identifier: "import.problems.ok") {
                onDismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import.problems.modal")
    }
}

/// One problem of the last import, at the top of a pet on the companion sheet.
struct PetImportProblemRow: View {
    let problem: PetImportProblem
    let identifier: String

    var body: some View {
        Label(problem.fieldMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.dsaBody(.caption2))
            .foregroundStyle(Color.groupEquipment)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .accessibilityIdentifier(identifier)
    }
}
