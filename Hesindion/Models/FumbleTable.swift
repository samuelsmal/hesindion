import Foundation

enum FumbleTableType: String {
    case nahkampfAttacke
    case verteidigungWaffe
    case verteidigungSchild
    case fernkampf
}

struct FumbleTableEntry {
    let roll: Int
    let title: String
    let description: String
}

enum FumbleTable {
    static func lookup(_ roll: Int, table: FumbleTableType, isUnarmed: Bool) -> FumbleTableEntry {
        let adjustedRoll: Int
        // For unarmed fighters or dodge attempts (Schild table), results below 7 get +5
        if isUnarmed && roll < 7 {
            adjustedRoll = roll + 5
        } else {
            adjustedRoll = roll
        }
        let clamped = min(max(adjustedRoll, 2), 12)
        let entries = allEntries(for: table)
        return entries.first { $0.roll == clamped }
            ?? FumbleTableEntry(roll: clamped, title: "—", description: "—")
    }

    private static func allEntries(for type: FumbleTableType) -> [FumbleTableEntry] {
        switch type {
        case .nahkampfAttacke:    return nahkampfAttackeEntries
        case .verteidigungWaffe:  return verteidigungWaffeEntries
        case .verteidigungSchild: return verteidigungSchildEntries
        case .fernkampf:          return fernkampfEntries
        }
    }

    // MARK: - Nahkampf-Patzertabelle (Kodex des Schwertes p68)
    private static let nahkampfAttackeEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: "Waffe zerstört",        description: "Die Waffe ist unwiederbringlich zerstört. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 3,  title: "Waffe schwer beschädigt", description: "Die Waffe ist nicht mehr verwendbar, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 4,  title: "Waffe beschädigt",      description: "Alle Proben auf AT und PA um –2 erschwert, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 5,  title: "Waffe verloren",        description: "Die Waffe ist zu Boden gefallen."),
        FumbleTableEntry(roll: 6,  title: "Waffe stecken geblieben", description: "Die Waffe steckt fest. 1 Aktion und Kraftakt (Ziehen & Zerren) –1 zum Befreien."),
        FumbleTableEntry(roll: 7,  title: "Sturz",                 description: "Probe auf Körperbeherrschung (Balance) –2, sonst Status Liegend."),
        FumbleTableEntry(roll: 8,  title: "Stolpern",              description: "Nächste Handlung um –2 erschwert."),
        FumbleTableEntry(roll: 9,  title: "Fuß verdreht",          description: "1 Stufe Schmerz für 3 Kampfrunden."),
        FumbleTableEntry(roll: 10, title: "Beule",                 description: "1 Stufe Betäubung für 1 Stunde."),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus)."),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt."),
    ]

    // Verteidigung-Patzertabelle Waffe uses same entries as Nahkampf-Attacke (p70)
    private static let verteidigungWaffeEntries = nahkampfAttackeEntries

    // MARK: - Verteidigung-Patzertabelle Schild (Kodex des Schwertes p84)
    private static let verteidigungSchildEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: "Schild zerstört",        description: "Der Schild ist unwiederbringlich zerstört. Bei unzerstörbaren Schilden: Schild verloren."),
        FumbleTableEntry(roll: 3,  title: "Schild schwer beschädigt", description: "Der Schild ist nicht mehr verwendbar, bis er repariert wird. Bei unzerstörbaren Schilden: Schild verloren."),
        FumbleTableEntry(roll: 4,  title: "Schild beschädigt",      description: "Alle Proben auf AT und PA um –2 erschwert, bis er repariert wird. Bei unzerstörbaren Schilden: Schild verloren."),
        FumbleTableEntry(roll: 5,  title: "Schild verloren",        description: "Der Schild ist zu Boden gefallen."),
        FumbleTableEntry(roll: 6,  title: "Schild stecken geblieben", description: "Der Schild steckt fest. 1 Aktion und Kraftakt (Ziehen & Zerren) –1 zum Befreien."),
        FumbleTableEntry(roll: 7,  title: "Sturz",                 description: "Probe auf Körperbeherrschung (Balance) –2, sonst Status Liegend."),
        FumbleTableEntry(roll: 8,  title: "Stolpern",              description: "Nächste Handlung um –2 erschwert."),
        FumbleTableEntry(roll: 9,  title: "Fuß verdreht",          description: "1 Stufe Schmerz für 3 Kampfrunden."),
        FumbleTableEntry(roll: 10, title: "Beule",                 description: "1 Stufe Betäubung für 1 Stunde."),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus)."),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt."),
    ]

    // MARK: - Fernkampf-Patzertabelle (Kodex des Schwertes p83)
    private static let fernkampfEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: "Waffe zerstört",        description: "Die Waffe ist unwiederbringlich zerstört. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 3,  title: "Waffe schwer beschädigt", description: "Die Waffe ist nicht mehr einsetzbar, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 4,  title: "Waffe beschädigt",      description: "Alle Proben auf FK um –4 erschwert, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren."),
        FumbleTableEntry(roll: 5,  title: "Waffe verloren",        description: "Die Waffe ist zu Boden gefallen."),
        FumbleTableEntry(roll: 6,  title: "Kamerad getroffen",     description: "Das Geschoss trifft einen Freund oder Unbeteiligten. Kein solches Ziel: Selbst verletzt."),
        FumbleTableEntry(roll: 7,  title: "Fehlschuss",            description: "Spektakulärer Fehlschuss trifft ein Objekt (Ladenschild, Glasfenster etc.)."),
        FumbleTableEntry(roll: 8,  title: "Zerrung",               description: "1 Stufe Schmerz für 3 Kampfrunden."),
        FumbleTableEntry(roll: 9,  title: "Ladehemmung",           description: "2 komplette Kampfrunden um die Waffe wieder einsatzbereit zu machen."),
        FumbleTableEntry(roll: 10, title: "Zu konzentriert",       description: "Bis zur nächsten Aktion keine Verteidigungen möglich."),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus)."),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt."),
    ]
}
