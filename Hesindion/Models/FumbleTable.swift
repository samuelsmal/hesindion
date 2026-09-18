import Foundation

enum FumbleTableType: String {
    case nahkampfAttacke
    case verteidigungWaffe
    case verteidigungSchild
    case fernkampf
}

/// What a Patzertabelle result *does*, as a value the app can act on.
///
/// The tables used to be prose only, so a player who rolled "Sturz" was told to
/// make a Körperbeherrschung check and then to remember, unaided, that failing it
/// means the Status Liegend — the one thing on that screen the app could have done
/// for them. Every entry of all four tables carries a case here; nothing is left
/// to a default, and a table without an effect is a compile error rather than a
/// silent "the app does not help with this one".
///
/// Two halves, deliberately:
///
/// - **Automated** — everything that lands on the hero's own sheet: a Status, a
///   Zustand level, the loadout, the hero's own LP by way of the take-damage
///   screen, and the temporary modifiers the combat session now holds
///   (`Hero.temporarySchmerzLevels`, `activeCombatStumble`, `damagedItems`,
///   `activeCombatJamUntilRound`, `activeCombatNoDefense`).
/// - **Stated only** — `friendHit` and `wildShot`. Both are events on the *other*
///   side of the table: a bystander hit, a shop sign shot off its hinges.
///   Opponents and scenery are not modelled (ADR-0005) and nothing about them
///   can be written to the hero, so they render their entry's text and nothing
///   more. `friendHit` does offer its own fallback ("Kein solches Ziel: Selbst
///   verletzt"), which runs the automated self-damage help. See
///   `CombatFumbleEffectPanel`.
enum FumbleEffect: Equatable {

    // MARK: Automated

    /// Sturz: a Körperbeherrschung check, and Liegend on a failure.
    case fall
    /// Beule: one level of Betäubung, at once.
    case stupor
    /// The thing in the hand leaves the loadout. `permanently` is the difference
    /// between "unwiederbringlich zerstört" and a weapon that is on the floor or
    /// at the smith — the app unequips it either way, the text says which.
    case itemLost(permanently: Bool)
    /// Stecken geblieben: the thing leaves the loadout, and a Kraftakt check can
    /// put it back.
    case itemStuck
    /// The hero takes their own weapon's damage, doubled on a 12.
    case selfDamage(doubled: Bool)

    // MARK: Automated — the temporary effects the combat session holds

    /// Stolpern: the next combat roll is 2 harder.
    case stumble
    /// Fuß verdreht / Zerrung: a level of Schmerz for 3 Kampfrunden.
    case pain
    /// The weapon is damaged: AT/PA (or FK) harder until repaired.
    case itemDamaged
    /// Ladehemmung: two full Kampfrunden to make the weapon ready again.
    case jam
    /// Zu konzentriert: no defences until the next action.
    case noDefense

    // MARK: Stated only — the other side of the table

    /// The shot hits a friend or a bystander — the other side of the table.
    /// Its "Kein solches Ziel" fallback is the hero's own damage, and that half
    /// the panel does offer.
    case friendHit
    /// A spectacular miss that hits an object — the GM's scene, not the hero.
    case wildShot

    /// Whether the app writes anything for this result, or only states it.
    ///
    /// Read by the panel to decide between help and prose, and by
    /// `FumbleTableTests` so that moving a case between the two halves has to be
    /// a deliberate edit in both places.
    var isAutomated: Bool {
        switch self {
        case .fall, .stupor, .itemLost, .itemStuck, .selfDamage,
             .stumble, .pain, .itemDamaged, .jam, .noDefense:
            true
        case .friendHit, .wildShot:
            false
        }
    }
}

struct FumbleTableEntry {
    let roll: Int
    let title: String
    let description: String
    let effect: FumbleEffect
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
            ?? FumbleTableEntry(roll: clamped, title: "—", description: "—", effect: .wildShot)
    }

    /// Every entry of one table, for the coverage test and for anything that has
    /// to reason about the table rather than about one roll.
    static func entries(for type: FumbleTableType) -> [FumbleTableEntry] {
        allEntries(for: type)
    }

    static let allTypes: [FumbleTableType] = [
        .nahkampfAttacke, .verteidigungWaffe, .verteidigungSchild, .fernkampf,
    ]

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
        FumbleTableEntry(roll: 2,  title: "Waffe zerstört",        description: "Die Waffe ist unwiederbringlich zerstört. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemLost(permanently: true)),
        FumbleTableEntry(roll: 3,  title: "Waffe schwer beschädigt", description: "Die Waffe ist nicht mehr verwendbar, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 4,  title: "Waffe beschädigt",      description: "Alle Proben auf AT und PA um –2 erschwert, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemDamaged),
        FumbleTableEntry(roll: 5,  title: "Waffe verloren",        description: "Die Waffe ist zu Boden gefallen.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 6,  title: "Waffe stecken geblieben", description: "Die Waffe steckt fest. 1 Aktion und Kraftakt (Ziehen & Zerren) –1 zum Befreien.", effect: .itemStuck),
        FumbleTableEntry(roll: 7,  title: "Sturz",                 description: "Probe auf Körperbeherrschung (Balance) –2, sonst Status Liegend.", effect: .fall),
        FumbleTableEntry(roll: 8,  title: "Stolpern",              description: "Nächste Handlung um –2 erschwert.", effect: .stumble),
        FumbleTableEntry(roll: 9,  title: "Fuß verdreht",          description: "1 Stufe Schmerz für 3 Kampfrunden.", effect: .pain),
        FumbleTableEntry(roll: 10, title: "Beule",                 description: "1 Stufe Betäubung für 1 Stunde.", effect: .stupor),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus).", effect: .selfDamage(doubled: false)),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt.", effect: .selfDamage(doubled: true)),
    ]

    // Verteidigung-Patzertabelle Waffe uses same entries as Nahkampf-Attacke (p70)
    private static let verteidigungWaffeEntries = nahkampfAttackeEntries

    // MARK: - Verteidigung-Patzertabelle Schild (Kodex des Schwertes p84)
    private static let verteidigungSchildEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: "Schild zerstört",        description: "Der Schild ist unwiederbringlich zerstört. Bei unzerstörbaren Schilden: Schild verloren.", effect: .itemLost(permanently: true)),
        FumbleTableEntry(roll: 3,  title: "Schild schwer beschädigt", description: "Der Schild ist nicht mehr verwendbar, bis er repariert wird. Bei unzerstörbaren Schilden: Schild verloren.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 4,  title: "Schild beschädigt",      description: "Alle Proben auf AT und PA um –2 erschwert, bis er repariert wird. Bei unzerstörbaren Schilden: Schild verloren.", effect: .itemDamaged),
        FumbleTableEntry(roll: 5,  title: "Schild verloren",        description: "Der Schild ist zu Boden gefallen.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 6,  title: "Schild stecken geblieben", description: "Der Schild steckt fest. 1 Aktion und Kraftakt (Ziehen & Zerren) –1 zum Befreien.", effect: .itemStuck),
        FumbleTableEntry(roll: 7,  title: "Sturz",                 description: "Probe auf Körperbeherrschung (Balance) –2, sonst Status Liegend.", effect: .fall),
        FumbleTableEntry(roll: 8,  title: "Stolpern",              description: "Nächste Handlung um –2 erschwert.", effect: .stumble),
        FumbleTableEntry(roll: 9,  title: "Fuß verdreht",          description: "1 Stufe Schmerz für 3 Kampfrunden.", effect: .pain),
        FumbleTableEntry(roll: 10, title: "Beule",                 description: "1 Stufe Betäubung für 1 Stunde.", effect: .stupor),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus).", effect: .selfDamage(doubled: false)),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt.", effect: .selfDamage(doubled: true)),
    ]

    // MARK: - Fernkampf-Patzertabelle (Kodex des Schwertes p83)
    private static let fernkampfEntries: [FumbleTableEntry] = [
        FumbleTableEntry(roll: 2,  title: "Waffe zerstört",        description: "Die Waffe ist unwiederbringlich zerstört. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemLost(permanently: true)),
        FumbleTableEntry(roll: 3,  title: "Waffe schwer beschädigt", description: "Die Waffe ist nicht mehr einsetzbar, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 4,  title: "Waffe beschädigt",      description: "Alle Proben auf FK um –4 erschwert, bis sie repariert wird. Bei unzerstörbaren Waffen: Waffe verloren.", effect: .itemDamaged),
        FumbleTableEntry(roll: 5,  title: "Waffe verloren",        description: "Die Waffe ist zu Boden gefallen.", effect: .itemLost(permanently: false)),
        FumbleTableEntry(roll: 6,  title: "Kamerad getroffen",     description: "Das Geschoss trifft einen Freund oder Unbeteiligten. Kein solches Ziel: Selbst verletzt.", effect: .friendHit),
        FumbleTableEntry(roll: 7,  title: "Fehlschuss",            description: "Spektakulärer Fehlschuss trifft ein Objekt (Ladenschild, Glasfenster etc.).", effect: .wildShot),
        FumbleTableEntry(roll: 8,  title: "Zerrung",               description: "1 Stufe Schmerz für 3 Kampfrunden.", effect: .pain),
        FumbleTableEntry(roll: 9,  title: "Ladehemmung",           description: "2 komplette Kampfrunden um die Waffe wieder einsatzbereit zu machen.", effect: .jam),
        FumbleTableEntry(roll: 10, title: "Zu konzentriert",       description: "Bis zur nächsten Aktion keine Verteidigungen möglich.", effect: .noDefense),
        FumbleTableEntry(roll: 11, title: "Selbst verletzt",       description: "Eigener Waffenschaden (mit Schadensbonus).", effect: .selfDamage(doubled: false)),
        FumbleTableEntry(roll: 12, title: "Selbst schwer verletzt", description: "Eigener Waffenschaden (mit Schadensbonus), verdoppelt.", effect: .selfDamage(doubled: true)),
    ]
}
