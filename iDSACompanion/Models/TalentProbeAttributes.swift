import Foundation
import SwiftData

enum TalentProbeAttributes {
    static let checks: [String: [String]] = [
        "Fliegen": ["MU", "IN", "GE"],
        "Gaukeleien": ["MU", "CH", "FF"],
        "Klettern": ["MU", "GE", "KK"],
        "Körperbeherrschung": ["GE", "GE", "KO"],
        "Kraftakt": ["KO", "KK", "KK"],
        "Reiten": ["CH", "GE", "KK"],
        "Schwimmen": ["GE", "KO", "KK"],
        "Selbstbeherrschung": ["MU", "MU", "KO"],
        "Singen": ["KL", "CH", "KO"],
        "Sinnesschärfe": ["KL", "IN", "IN"],
        "Tanzen": ["KL", "CH", "GE"],
        "Taschendiebstahl": ["MU", "FF", "GE"],
        "Verbergen": ["MU", "IN", "GE"],
        "Zechen": ["KL", "KO", "KK"],
        "Bekehren & Überzeugen": ["MU", "KL", "CH"],
        "Betören": ["MU", "CH", "CH"],
        "Einschüchtern": ["MU", "IN", "CH"],
        "Etikette": ["KL", "IN", "CH"],
        "Gassenwissen": ["KL", "IN", "CH"],
        "Menschenkenntnis": ["KL", "IN", "CH"],
        "Überreden": ["MU", "IN", "CH"],
        "Verkleiden": ["IN", "CH", "GE"],
        "Willenskraft": ["MU", "IN", "CH"],
        "Fährtensuchen": ["MU", "IN", "GE"],
        "Fesseln": ["KL", "FF", "KK"],
        "Fischen & Angeln": ["FF", "GE", "KO"],
        "Orientierung": ["KL", "IN", "IN"],
        "Pflanzenkunde": ["KL", "FF", "KO"],
        "Tierkunde": ["MU", "MU", "CH"],
        "Wildnisleben": ["MU", "GE", "KO"],
        "Brett- & Glücksspiel": ["KL", "KL", "IN"],
        "Geographie": ["KL", "KL", "IN"],
        "Geschichtswissen": ["KL", "KL", "IN"],
        "Götter & Kulte": ["KL", "KL", "IN"],
        "Kriegskunst": ["MU", "KL", "IN"],
        "Magiekunde": ["KL", "KL", "IN"],
        "Mechanik": ["KL", "KL", "FF"],
        "Rechnen": ["KL", "KL", "IN"],
        "Rechtskunde": ["KL", "KL", "IN"],
        "Sagen & Legenden": ["KL", "KL", "IN"],
        "Sphärenkunde": ["KL", "KL", "IN"],
        "Sternkunde": ["KL", "KL", "IN"],
        "Alchimie": ["MU", "KL", "FF"],
        "Boote & Schiffe": ["FF", "GE", "KK"],
        "Fahrzeuge": ["CH", "FF", "KO"],
        "Handel": ["KL", "IN", "CH"],
        "Heilkunde Gift": ["MU", "KL", "IN"],
        "Heilkunde Krankheiten": ["MU", "IN", "KO"],
        "Heilkunde Seele": ["IN", "CH", "KO"],
        "Heilkunde Wunden": ["KL", "FF", "FF"],
        "Holzbearbeitung": ["FF", "GE", "KK"],
        "Lebensmittelbearbeitung": ["IN", "FF", "FF"],
        "Lederbearbeitung": ["FF", "GE", "KO"],
        "Malen & Zeichnen": ["IN", "FF", "FF"],
        "Metallbearbeitung": ["FF", "KO", "KK"],
        "Musizieren": ["CH", "FF", "KO"],
        "Schlösserknacken": ["IN", "FF", "FF"],
        "Steinbearbeitung": ["FF", "FF", "KK"],
        "Stoffbearbeitung": ["KL", "FF", "FF"]
    ]

    static func attributeValue(_ key: String, from attrs: Attributes) -> Int {
        switch key {
        case "MU": return attrs.mu
        case "KL": return attrs.kl
        case "IN": return attrs.inValue
        case "CH": return attrs.ch
        case "FF": return attrs.ff
        case "GE": return attrs.ge
        case "KO": return attrs.ko
        case "KK": return attrs.kk
        default: return 0
        }
    }

    static func lookup(talent: String, attributes: Attributes) -> (keys: [String], values: [Int])? {
        guard let keys = checks[talent] else { return nil }
        let values = keys.map { attributeValue($0, from: attributes) }
        return (keys: keys, values: values)
    }
}
