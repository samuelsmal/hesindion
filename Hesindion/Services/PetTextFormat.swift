import Foundation

/// One part of a pet's Optolith fields that the import could not read (issue #49). The import
/// keeps every other part; the player sees each problem after the import and on the companion
/// sheet (ADR-0018).
struct PetImportProblem: Codable, Hashable {
    /// The Optolith pet editor's label of the field, as the player sees it there.
    enum Field: String, Codable {
        case talente = "Talente"
        case sonderfertigkeiten = "Sonderfertigkeiten"
        case notizen = "Notizen"
        case angriff = "Angriff"
    }

    enum Reason: String, Codable {
        case noLabel, unknownLabel, badAttack, badBE, badTalentValue, attackMismatch, attackOutsideAngriffe
    }

    var pet: String
    var field: Field
    var text: String
    var reason: Reason
}

/// The labelled single-line format of a pet's Optolith text fields
/// (docs/plans/2026-10-03-companion-text-format-design.md §3). Optolith's pet fields are
/// single-line inputs, so `;` separates segments and `,` separates items; neither separates
/// inside parentheses.
enum PetTextFormat {
    struct Result: Equatable {
        var defense: Int?
        var armor: Int?
        var encumbrance: Int?
        var apTotal: Int?
        var apSpent: Int?
        var advantages: [String] = []
        var disadvantages: [String] = []
        var abilities: [String] = []
        var training: [String] = []
        var tricks: [String] = []
        var attacks: [PetAttack] = []
        /// The Notizen segments that are prose, joined with "; ".
        var notes: String = ""
        var problems: [PetImportProblem] = []
    }

    private static let attackPattern =
        /^(.+?)\s+AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)$/.ignoresCase()
    /// Attack-like text in prose: the old `Tritt: AT 15 TP …` lines.
    private static let attackLikePattern = /\bAT\s*\d+.*\bTP\b/.ignoresCase()

    static func parse(_ pet: [String: Any]) -> Result {
        let name = pet["name"] as? String ?? "?"
        var r = Result()
        r.defense = int(pet["pa"])
        r.armor = int(pet["pro"])
        r.apSpent = int(pet["spentAp"])
        r.apTotal = int(pet["totalAp"])

        func problem(_ field: PetImportProblem.Field, _ text: String, _ reason: PetImportProblem.Reason) {
            r.problems.append(PetImportProblem(pet: name, field: field, text: text, reason: reason))
        }

        // Talente: the text stays in `Pet.talents`; only a number that does not parse is reported.
        for item in split(string(pet["talents"]), on: ",") {
            if let last = itemName(item).split(separator: " ").last,
               last.first?.isNumber == true, Int(last) == nil {
                problem(.talente, item, .badTalentValue)
            }
        }

        // Sonderfertigkeiten
        for segment in split(string(pet["skills"]), on: ";") {
            guard let (label, content) = labelled(segment) else {
                problem(.sonderfertigkeiten, segment, .noLabel)
                continue
            }
            let items = split(content, on: ",")
            switch label {
            case "vorteile": r.advantages += items
            case "nachteile": r.disadvantages += items
            case "sonderfertigkeiten": r.abilities += items
            case "ausbildung": r.training += items
            case "tricks": r.tricks += items
            default: problem(.sonderfertigkeiten, segment, .unknownLabel)
            }
        }

        // Notizen
        var prose: [String] = []
        var hasAngriffe = false
        for segment in split(string(pet["notes"]), on: ";") {
            switch labelled(segment)?.label {
            case "angriffe":
                hasAngriffe = true
                for item in split(labelled(segment)!.content, on: ",") {
                    if let attack = attack(item) { r.attacks.append(attack) } else { problem(.notizen, item, .badAttack) }
                }
            case "be":
                if let be = Int(labelled(segment)!.content) { r.encumbrance = be } else { problem(.notizen, segment, .badBE) }
            default:
                prose.append(segment)
                if segment.contains(attackLikePattern) { problem(.notizen, segment, .attackOutsideAngriffe) }
            }
        }
        r.notes = prose.joined(separator: "; ")

        // Optolith's own attack fields
        let attackName = string(pet["attack"])
        let at = int(pet["at"])
        let dp = string(pet["dp"])
        if !hasAngriffe {
            if !attackName.isEmpty, let at {
                r.attacks = [PetAttack(name: attackName, at: at, damage: dp, reach: string(pet["reach"]).lowercased())]
            }
        } else if !attackName.isEmpty,
                  let listed = r.attacks.first(where: { $0.name.caseInsensitiveCompare(attackName) == .orderedSame }),
                  at != listed.at || dp.uppercased() != listed.damage {
            problem(.angriff, "\(attackName) AT \(at.map(String.init) ?? "") TP \(dp)", .attackMismatch)
        }
        return r
    }

    /// The item without a trailing note in parentheses: "Mächtiger Schlag (-4 …)" → "Mächtiger Schlag".
    static func itemName(_ item: String) -> String {
        let trimmed = item.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(")"), let open = trimmed.firstIndex(of: "(") else { return trimmed }
        return trimmed[..<open].trimmingCharacters(in: .whitespaces)
    }

    /// Splits on `separator` outside parentheses, trims each part, drops empty parts. When the
    /// parentheses do not balance, nothing is protected: an unclosed `(` must not swallow the rest.
    static func split(_ text: String, on separator: Character) -> [String] {
        var depth = 0
        for ch in text {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth = max(0, depth - 1) }
        }
        let protected = depth == 0
        var parts: [String] = []
        var current = ""
        depth = 0
        for ch in text {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth = max(0, depth - 1) }
            if ch == separator, depth == 0 || !protected {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "Label: content" with the first `:` outside parentheses; the label lower-cased.
    private static func labelled(_ segment: String) -> (label: String, content: String)? {
        var depth = 0
        for index in segment.indices {
            switch segment[index] {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case ":" where depth == 0:
                let label = segment[..<index].trimmingCharacters(in: .whitespaces).lowercased()
                let content = segment[segment.index(after: index)...].trimmingCharacters(in: .whitespaces)
                return label.isEmpty ? nil : (label, content)
            default: break
            }
        }
        return nil
    }

    private static func attack(_ item: String) -> PetAttack? {
        guard let m = item.wholeMatch(of: attackPattern), let at = Int(m.2) else { return nil }
        return PetAttack(name: String(m.1), at: at, damage: m.3.uppercased(), reach: m.4.lowercased())
    }

    private static func string(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        return Int(string(value))
    }
}
