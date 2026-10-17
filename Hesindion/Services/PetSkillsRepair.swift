import Foundation
import SwiftData

/// Reads the Sonderfertigkeiten text of a pet stored before issue #49 again. Such a pet kept that
/// text only in the removed `specialSkills`: its lists are empty, so Mächtiger Schlag and the
/// abilities line were gone without a word (ADR-0018). The repair parses the raw `skills` as a
/// re-import would and writes the five lists and the problems; an unlabelled legacy item becomes
/// a `noLabel` row on the companion sheet. Attacks, notes and numbers were stored correctly before
/// and stay as they are. Runs at launch.
enum PetSkillsRepair {
    /// - Returns: `true` if anything changed. Idempotent: a repaired pet has lists or problems.
    @discardableResult
    static func repair(_ pet: Pet) -> Bool {
        guard pet.abilities.isEmpty, pet.advantages.isEmpty, pet.disadvantages.isEmpty,
              pet.training.isEmpty, pet.tricks.isEmpty, pet.importProblems.isEmpty,
              !pet.skills.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let r = PetTextFormat.parse(["name": pet.name, "skills": pet.skills])
        pet.abilities = r.abilities
        pet.advantages = r.advantages
        pet.disadvantages = r.disadvantages
        pet.training = r.training
        pet.tricks = r.tricks
        pet.importProblems = r.problems
        return !(r.abilities.isEmpty && r.advantages.isEmpty && r.disadvantages.isEmpty
                 && r.training.isEmpty && r.tricks.isEmpty && r.problems.isEmpty)
    }

    static func repairAll(in context: ModelContext) {
        let pets = (try? context.fetch(FetchDescriptor<Pet>())) ?? []
        if pets.map(repair).contains(true) { try? context.save() }
    }
}
