import Foundation

/// The Optolith combat-technique ids, written down once.
///
/// They were used as bare strings with the names in comments, and the comments
/// were wrong: the two-handed grip was withheld from `CT_1` and `CT_3`
/// ("Dolche, Fechtwaffen" — they are *Armbrüste* and Dolche), and the
/// "needs both hands, no good on horseback" rule was applied to `CT_7` and
/// `CT_14` ("Zweihandschwerter, Stangenwaffen" — they are *Lanzen* and
/// *Wurfwaffen*), which banned the lance, of all things, from being used
/// mounted.
///
/// The ids are the ones in `rules.db`; `CombatTechniqueIDTests` checks this list
/// against that table so the two cannot drift.
enum CombatTechniqueID: String, CaseIterable {
    case armbrueste        = "CT_1"
    case boegen            = "CT_2"
    case dolche            = "CT_3"
    case fechtwaffen       = "CT_4"
    case hiebwaffen        = "CT_5"
    case kettenwaffen      = "CT_6"
    case lanzen            = "CT_7"
    case peitschen         = "CT_8"
    case raufen            = "CT_9"
    case schilde           = "CT_10"
    case schleudern        = "CT_11"
    case schwerter         = "CT_12"
    case stangenwaffen     = "CT_13"
    case wurfwaffen        = "CT_14"
    case zweihandhiebwaffen = "CT_15"
    case zweihandschwerter = "CT_16"
    case feuerspeien       = "CT_17"
    case blasrohre         = "CT_18"
    case diskusse          = "CT_19"
    case faecher           = "CT_20"
    case spiesswaffen      = "CT_21"

    /// Techniques whose weapons are held in both hands, so nothing else can be:
    /// no shield, no off-hand weapon, and not from the saddle.
    ///
    /// Lanzen are two-handed as well and are deliberately *not* here — a lance
    /// is the mounted weapon, and the rule this set drives would forbid it.
    static let twoHandedOnly: Set<CombatTechniqueID> = [
        .zweihandhiebwaffen, .zweihandschwerter, .stangenwaffen,
    ]

    /// Techniques that cannot be gripped in two hands for the +1 TP / −1 PA
    /// trade: a dagger and a rapier are one-handed weapons by construction.
    static let noTwoHandedGrip: Set<CombatTechniqueID> = [
        .dolche, .fechtwaffen,
    ]

    var isTwoHandedOnly: Bool { Self.twoHandedOnly.contains(self) }
    var allowsTwoHandedGrip: Bool { !Self.noTwoHandedGrip.contains(self) }
}

// MARK: - Iconography

/// SF Symbols has no weapons — Apple does not ship a sword — so the melee
/// glyphs are the app's own, drawn flat and hard-edged like everything else
/// here. `hammer.fill` used to stand in for every weapon in the loadout, which
/// told a hero carrying a Langschwert that they were carrying a hammer.
enum WeaponIcon: Equatable {
    /// An SF Symbol, for the things Apple does ship.
    case system(String)
    /// An image in the asset catalogue, rendered as a template.
    case asset(String)

    static func forTechnique(_ id: CombatTechniqueID?) -> WeaponIcon {
        switch id {
        case .schwerter, .zweihandschwerter, .fechtwaffen: .asset("weapon.sword")
        case .dolche:                                      .asset("weapon.dagger")
        case .hiebwaffen, .zweihandhiebwaffen, .kettenwaffen: .asset("weapon.axe")
        case .stangenwaffen, .lanzen, .spiesswaffen:       .asset("weapon.spear")
        case .boegen:                                      .asset("weapon.bow")
        case .armbrueste:                                  .asset("weapon.crossbow")
        case .schilde:                                     .system("shield.fill")
        case .raufen:                                      .asset("weapon.fist")
        default:                                           .asset("weapon.generic")
        }
    }

    static func forTechniqueId(_ rawId: String?) -> WeaponIcon {
        forTechnique(rawId.flatMap(CombatTechniqueID.init(rawValue:)))
    }
}
