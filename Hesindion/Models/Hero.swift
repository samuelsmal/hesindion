import Foundation
import SwiftData

@Model
final class Hero {
    var name: String
    var avatar: Data?
    var advantages: [HeroTrait]
    var disadvantages: [HeroTrait]
    var generalSpecialAbilities: [HeroTrait]
    var combatSpecialAbilities: [HeroTrait]
    var cantrips: [HeroTrait]
    var blessings: [HeroTrait]
    var scripts: [String]

    @Relationship(deleteRule: .cascade) var personalData: PersonalData?
    @Relationship(deleteRule: .cascade) var experience: Experience?
    @Relationship(deleteRule: .cascade) var attributes: Attributes?
    @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
    @Relationship(deleteRule: .cascade) var talents: [Talent]
    @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
    @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
    @Relationship(deleteRule: .cascade) var rangedWeapons: [RangedWeapon]
    @Relationship(deleteRule: .cascade) var armors: [Armor]
    @Relationship(deleteRule: .cascade) var shields: [Shield]
    @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem]
    @Relationship(deleteRule: .cascade) var money: Money?
    @Relationship(deleteRule: .cascade) var pets: [Pet]
    @Relationship(deleteRule: .cascade) var languages: [Language]
    @Relationship(deleteRule: .cascade) var spells: [HeroSpell]
    @Relationship(deleteRule: .cascade) var liturgies: [HeroSpell]
    @Relationship(deleteRule: .cascade, inverse: \LogEntry.hero) var logEntries: [LogEntry] = []
    @Relationship(deleteRule: .cascade) var states: [HeroStateEntry] = []

    var activeAdventure: Adventure?

    // MARK: - Notes

    var notes: String = ""
    var colorSchemeId: String?

    // MARK: - Fokus-Regeln

    /// Ids of the optional DSA 5 Fokus-Regeln this hero plays with (see `FokusRule`).
    /// Empty by default — with no rule active, the app behaves exactly as it did
    /// before. These are the group's house rules, so they are a per-hero *setting*
    /// (edited on the hero settings screen) and deliberately outlive a combat:
    /// `clearCombatSession()` must not touch them.
    ///
    /// Stored as raw ids rather than one Bool per rule so that adding or retiring a
    /// rule does not change the schema.
    var fokusRules: [String] = []

    /// The hero's Trefferzonen size category, once the player has set it. `nil`
    /// means "not answered": `sizeCategory` then falls back to the species list.
    var hitZoneSize: String?

    /// Names of the weapons the player has marked as consecrated (geweiht or
    /// heilig) although the inventory does not say so — the player's override
    /// in one direction.
    ///
    /// The default comes from Optolith's own inventory: a weapon whose template
    /// note starts "geweiht (…)" — the Rabenschnabel of Boron — is consecrated
    /// (owner decision 2026-09-18). `unconsecratedWeapons` is the override in
    /// the other direction. The default is read by the weapon's *name* across
    /// every template (`consecratedDeity(ofLoadoutNamed:)`): the Regelwiki,
    /// which is the authority, has one Rabenschnabel and it is geweiht, even
    /// though Optolith's duplicate ITEMTPL_796 drops the note. Both lists are set
    /// on the hero settings screen through `setConsecrated`, which keeps a name
    /// in at most one of them and in neither when it matches the default. Names
    /// rather than ids, like the loadout, so a re-import that rebuilds the
    /// weapon rows does not lose the answer.
    var consecratedWeapons: [String] = []

    /// Names of the weapons the inventory marks "geweiht (…)" that the player
    /// has said are not — the other half of the override (see
    /// `consecratedWeapons`).
    var unconsecratedWeapons: [String] = []

    /// Names of the weapons and shields a Patzer has damaged — "Alle Proben auf
    /// AT und PA um –2 erschwert, bis sie repariert wird".
    ///
    /// Deliberately **not** part of the combat-session block: the damage lasts
    /// until somebody repairs the thing, which is a scene at a smithy and not
    /// the end of the fight, so `clearCombatSession()` leaves it alone and the
    /// hero settings screen is where it is cleared. Names rather than ids, like
    /// `consecratedWeapons` and the loadout, so a re-import keeps the answer.
    var damagedItems: [String] = []

    /// Names of the weapons and shields the player has said cannot be destroyed
    /// — a magier's staff, a dwarven runic axe, anything the GM rules unbreakable.
    ///
    /// The Patzertabellen print the rule ("Bei unzerstörbaren Waffen: Waffe
    /// verloren") but nothing in an Optolith export says which weapons it is
    /// about, so the app asks the player the first time it matters and remembers
    /// the answer for this hero. Like `damagedItems` and `consecratedWeapons`:
    /// names rather than ids, **not** part of the combat-session block — a staff
    /// is no more breakable after the fight than during it — and cleared only on
    /// the hero settings screen. A *no* is not remembered: the next Langschwert
    /// may be an ordinary one bought at the next market.
    var indestructibleItems: [String] = []

    // MARK: - Loadout persistence

    var selectedWeaponName: String?
    var selectedShieldName: String?
    var selectedOffHandName: String?
    var selectedRangedWeaponName: String?

    // MARK: - Combat session state

    var activeCombatId: UUID?
    var activeCombatRound: Int = 0
    var activeCombatInitiative: Int?
    var activeCombatPlaenkler: Bool = false
    var activeCombatPlaenklerBonus: String?   // "at" or "aw"
    var activeCombatMounted: Bool = false
    // Deprecated: replaced by the eingeengt status (HeroStateEntry); retained to avoid a SwiftData migration.
    var activeCombatBeengt: Bool = false
    /// `WaterDepth.rawValue`; "" means `.none` (no water). Kampf im Wasser
    /// (Regelwerk 239) is a round situation like Beengte Umgebung.
    var activeCombatWater: String = ""

    // MARK: - Temporary combat effects (Patzertabelle)
    //
    // Plain stored properties with defaults, so SwiftData's lightweight
    // migration adds them the way `activeCombatBeengt` and `consecratedWeapons`
    // were added. All of them belong to the running fight and are cleared by
    // `clearCombatSession()`; `damagedItems` above deliberately is not.

    /// Schmerz levels a Patzer added on top of the LP-derived ones ("1 Stufe
    /// Schmerz für 3 Kampfrunden"). Zero when nothing is running.
    var temporarySchmerzLevels: Int = 0

    /// The last round those levels still count.
    ///
    /// **Convention:** rolled in round *n* → counts through round *n+2*, i.e.
    /// the rest of round *n* and the two rounds after it. Three Kampfrunden are
    /// named on the card and three round numbers see the penalty; "the rest of
    /// this round does not count as one of them" would be a fourth.
    ///
    /// A second such Patzer while one is still running **adds a level and
    /// restarts the clock** — the simplest reading, and the one that does not
    /// need a list of expiry dates on the hero.
    var temporarySchmerzLastRound: Int = 0

    /// Stolpern: the hero's next combat roll of any kind is 2 harder. Consumed
    /// by the roll that pays for it (`FumbleModifiers.stolpern`).
    var activeCombatStumble: Bool = false

    /// Ladehemmung: the last round in which the ranged weapon is still being
    /// cleared. Same convention as the Schmerz clock — rolled in round *n*, the
    /// two complete Kampfrunden it costs are *n+1* and *n+2*, so the weapon is
    /// unusable through round *n+2* and ready again in *n+3*.
    var activeCombatJamUntilRound: Int = 0

    /// Zu konzentriert: no defences until the hero's next own action.
    var activeCombatNoDefense: Bool = false

    /// Status Blutend: rounds still left on the clock, or `nil` when the status
    /// was never rolled with a known duration ("Blutend" applied without a
    /// probe — `setStateLevel` directly — still costs the SP each round, it
    /// just never counts down). A *relative* count, unlike the round-number
    /// clocks above, so `rebaseCombatClocks` leaves it alone.
    var bleedingRoundsLeft: Int? = nil

    init(
        name: String,
        avatar: Data? = nil,
        advantages: [HeroTrait] = [],
        disadvantages: [HeroTrait] = [],
        generalSpecialAbilities: [HeroTrait] = [],
        combatSpecialAbilities: [HeroTrait] = [],
        cantrips: [HeroTrait] = [],
        blessings: [HeroTrait] = [],
        scripts: [String] = []
    ) {
        self.name = name
        self.avatar = avatar
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.generalSpecialAbilities = generalSpecialAbilities
        self.combatSpecialAbilities = combatSpecialAbilities
        self.cantrips = cantrips
        self.blessings = blessings
        self.scripts = scripts
        self.talents = []
        self.combatTechniques = []
        self.meleeWeapons = []
        self.rangedWeapons = []
        self.armors = []
        self.shields = []
        self.equipment = []
        self.pets = []
        self.languages = []
        self.spells = []
        self.liturgies = []

        // Combat session defaults
        self.activeCombatId = nil
        self.activeCombatRound = 0
        self.activeCombatInitiative = nil
        self.activeCombatPlaenkler = false
        self.activeCombatPlaenklerBonus = nil
        self.activeCombatMounted = false
    }

    var totalEquipmentWeight: Double {
        let equipmentWeight = equipment.reduce(0.0) { $0 + $1.weight }
        let weaponWeight    = meleeWeapons.reduce(0.0) { $0 + $1.weight }
        let rangedWeight    = rangedWeapons.reduce(0.0) { $0 + $1.weight }
        let armorWeight     = armors.reduce(0.0) { $0 + $1.weight }
        let shieldWeight    = shields.reduce(0.0) { $0 + $1.weight }
        return equipmentWeight + weaponWeight + rangedWeight + armorWeight + shieldWeight
    }

    /// Derived from KK attribute per DSA rules.
    var carryingCapacity: Int { (attributes?.kk ?? 0) * 2 }

    var totalCarryingCapacity: Int {
        carryingCapacity + pets.reduce(0) { $0 + $1.carryingCapacity }
    }

    var carryingThreshold: Double {
        Double(totalCarryingCapacity)
    }

    var isOverloaded: Bool {
        totalEquipmentWeight > carryingThreshold
    }

    /// +1 if the hero has "Verbesserte Regeneration (Lebensenergie)", +2 if it's level II.
    var verbessertRegenerationLEBonus: Int {
        guard let adv = advantages.first(where: { $0.ruleId == "ADV_44" }) else { return 0 }
        return (adv.tier ?? 1) >= 2 ? 2 : 1
    }

    /// Sum of RS from all equipped armor pieces.
    var totalRS: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.protectionValue }
    }

    /// What the hero is wearing, for the preparation screen to restate.
    var wornArmorNames: [String] {
        armors.filter(\.isEquipped).map(\.name)
    }

    /// Sum of BE from all equipped armor pieces.
    var totalEquippedBE: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.encumbrance }
    }

    /// Level of Belastungsgewöhnung combat SA (SA_41). Each level reduces effective BE by 2.
    var belastungsgewoehnungLevel: Int {
        specialAbility(CombatAbility.belastungsgewoehnung.rawValue)?.tier ?? 0
    }

    /// Effective BE after Belastungsgewöhnung reduction.
    var effectiveBE: Int {
        max(0, totalEquippedBE - 2 * belastungsgewoehnungLevel)
    }

    /// Belastung penalty applied to AT, PA, AW, INI, GS. Equals negative effectiveBE.
    var belastungPenalty: Int {
        -effectiveBE
    }

    /// Sum of direct INI modifiers from equipped armor (independent of BE).
    var armorIniModifier: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.iniModifier }
    }

    /// Sum of direct GS modifiers from equipped armor (independent of BE).
    var armorGsModifier: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.gsModifier }
    }

    /// Total INI penalty: Belastung + direct armor modifiers.
    var totalIniPenalty: Int {
        belastungPenalty + armorIniModifier
    }

    /// Total GS penalty: Belastung + direct armor modifiers.
    var totalGsPenalty: Int {
        belastungPenalty + armorGsModifier
    }

    // MARK: - Loadout computed helpers

    var selectedRangedWeapon: RangedWeapon? {
        guard let name = selectedRangedWeaponName else { return nil }
        return rangedWeapons.first { $0.name == name }
    }

    var selectedWeapon: MeleeWeapon? {
        guard let name = selectedWeaponName else { return nil }
        return meleeWeapons.first { $0.name == name }
    }

    var selectedShield: Shield? {
        if let name = selectedOffHandName, let shield = shields.first(where: { $0.name == name }) {
            return shield
        }
        guard let name = selectedShieldName else { return nil }
        return shields.first { $0.name == name }
    }

    /// The reach of one named piece of the loadout.
    ///
    /// Reach is a property of the thing in the hand, and the hand is not always
    /// holding `selectedWeapon`: an off-hand attack swings the off-hand weapon, a
    /// Schildattacke swings a shield, and Raufen swings a fist. Reading the main
    /// weapon's reach for all of them gave a bare-handed hero the reach of the
    /// sword they are not holding — and with the default `Mittel`, no penalty at
    /// all against a spear.
    ///
    /// Unarmed is `kurz` (GRW, waffenlose Kampftechniken); shields carry their own
    /// reach in the import. A name that matches nothing keeps the old `mittel`
    /// rather than guessing a penalty onto it.
    func reach(ofLoadoutNamed name: String) -> WeaponReach {
        if let weapon = meleeWeapons.first(where: { $0.name == name }) {
            return WeaponReach(rawValue: weapon.reach) ?? .mittel
        }
        if let shield = shields.first(where: { $0.name == name }) {
            return WeaponReach(rawValue: shield.reach) ?? .kurz
        }
        if name == "Raufen" { return .kurz }
        return .mittel
    }

    // MARK: - Karmale Objekte

    /// The inventory template of the hero's weapon or shield called `name`: by
    /// the template id Optolith exported, else — heroes imported before it was
    /// kept, or a name the hero does not carry — by the name.
    func equipmentEntry(forLoadoutNamed name: String) -> EquipmentEntry? {
        let templateId = meleeWeapons.first { $0.name == name }?.templateId
            ?? shields.first { $0.name == name }?.templateId
            ?? rangedWeapons.first { $0.name == name }?.templateId
        if let templateId, let entry = RulesDatabase.shared.equipment(id: templateId) { return entry }
        return RulesDatabase.shared.equipment(named: name)
    }

    /// The deity the rules consecrate this weapon to by default: by its name
    /// across every inventory template (`RulesDatabase.consecratedDeity(forWeaponNamed:)`
    /// — the Regelwiki has one Rabenschnabel, and it is Boron's), else by the
    /// name of the template it was bought from, for a weapon the player renamed.
    func consecratedDeity(ofLoadoutNamed name: String) -> String? {
        let rules = RulesDatabase.shared
        if let deity = rules.consecratedDeity(forWeaponNamed: name) { return deity }
        guard let templateName = equipmentEntry(forLoadoutNamed: name)?.name, templateName != name else { return nil }
        return rules.consecratedDeity(forWeaponNamed: templateName)
    }

    private func isConsecratedByDefault(_ weaponName: String) -> Bool {
        consecratedDeity(ofLoadoutNamed: weaponName) != nil
    }

    func isConsecrated(_ weaponName: String?) -> Bool {
        guard let weaponName else { return false }
        if consecratedWeapons.contains(weaponName) { return true }
        if unconsecratedWeapons.contains(weaponName) { return false }
        return isConsecratedByDefault(weaponName)
    }

    /// Records the player's answer as an override of the inventory's default,
    /// or as no override at all when it matches it.
    func setConsecrated(_ weaponName: String, _ consecrated: Bool) {
        consecratedWeapons.removeAll { $0 == weaponName }
        unconsecratedWeapons.removeAll { $0 == weaponName }
        guard consecrated != isConsecratedByDefault(weaponName) else { return }
        if consecrated { consecratedWeapons.append(weaponName) } else { unconsecratedWeapons.append(weaponName) }
    }

    // MARK: - Beschädigte Ausrüstung

    func isItemDamaged(_ name: String?) -> Bool {
        guard let name else { return false }
        return damagedItems.contains(name)
    }

    func setItemDamaged(_ name: String, _ damaged: Bool) {
        if damaged {
            guard !damagedItems.contains(name) else { return }
            damagedItems.append(name)
        } else {
            damagedItems.removeAll { $0 == name }
        }
    }

    // MARK: - Unzerstörbare Ausrüstung

    func isItemIndestructible(_ name: String?) -> Bool {
        guard let name else { return false }
        return indestructibleItems.contains(name)
    }

    func setItemIndestructible(_ name: String, _ indestructible: Bool) {
        if indestructible {
            guard !indestructibleItems.contains(name) else { return }
            indestructibleItems.append(name)
        } else {
            indestructibleItems.removeAll { $0 == name }
        }
    }

    // MARK: - Temporary combat effects

    /// Whether the Patzer's extra Schmerz is still running. It belongs to a
    /// fight, so a hero with no session has none however the counters stand.
    var temporarySchmerzActive: Bool {
        activeCombatId != nil
            && temporarySchmerzLevels > 0
            && activeCombatRound <= temporarySchmerzLastRound
    }

    /// The levels it currently contributes — zero once the round has passed.
    var temporarySchmerzLevel: Int { temporarySchmerzActive ? temporarySchmerzLevels : 0 }

    /// Adds one level and (re)starts the clock from the round that rolled it.
    func addTemporarySchmerz(rolledInRound round: Int) {
        temporarySchmerzLevels = temporarySchmerzActive ? temporarySchmerzLevels + 1 : 1
        temporarySchmerzLastRound = round + 2
    }

    /// Ladehemmung: whether the ranged weapon is still out of action.
    var isRangedWeaponJammed: Bool {
        activeCombatId != nil && activeCombatRound <= activeCombatJamUntilRound
    }

    func applyRangedJam(rolledInRound round: Int) {
        activeCombatJamUntilRound = round + 2
    }

    /// Stolpern is paid for by the roll that pays for it: called the moment the
    /// W20 is first settled, not when the screen appears. Opening a roll screen
    /// and backing out again rolls nothing, so it must cost nothing — and the
    /// lines the roll was announced with were built by the screen before, so a
    /// Schicksalspunkt reroll of that same roll still carries the −2.
    ///
    /// Guarded on the current value: a reroll calls this again, and writing a
    /// stored property that already holds that value still dirties the model and
    /// redraws the screen mid-roll.
    func consumeStumble() {
        guard activeCombatStumble else { return }
        activeCombatStumble = false
    }

    /// The hero's own next action lifts "Zu konzentriert" — the action, again,
    /// being the roll, not the screen that offers it.
    func beginOwnAction() {
        guard activeCombatNoDefense else { return }
        activeCombatNoDefense = false
    }

    /// A new Kampfrunde lifts it too.
    ///
    /// "Bis zur nächsten Aktion" ends at the hero's next action, and a hero who
    /// takes none still has a next round. Without this an archer who spends two
    /// rounds reloading — or anyone who simply does not act — would be barred
    /// from parrying and dodging for the rest of the fight, which is not a thing
    /// the card says.
    func beginCombatRound() {
        guard activeCombatNoDefense else { return }
        activeCombatNoDefense = false
    }

    /// Re-rolling initiative starts the round count over at 1, and the Patzer
    /// clocks are *absolute* round numbers. A Zerrung rolled in round 6 runs
    /// until round 8; without rebasing it would still say 8 after the reset and
    /// so last eight more rounds instead of the two it had left.
    ///
    /// The shift is what the counter lost, so the remaining rounds are preserved;
    /// a clock that had already run out is cleared rather than dragged into the
    /// new count as a negative.
    func rebaseCombatClocks(fromRound oldRound: Int, toRound newRound: Int) {
        let shift = oldRound - newRound
        if temporarySchmerzLevels > 0 {
            if temporarySchmerzLastRound < oldRound {
                temporarySchmerzLevels = 0
                temporarySchmerzLastRound = 0
            } else {
                temporarySchmerzLastRound -= shift
            }
        }
        if activeCombatJamUntilRound > 0 {
            if activeCombatJamUntilRound < oldRound {
                activeCombatJamUntilRound = 0
            } else {
                activeCombatJamUntilRound -= shift
            }
        }
    }

    /// Whether the named piece of the loadout is the shield in the hero's hand.
    ///
    /// A parry made with the sword while a shield hangs on the other arm is a
    /// *weapon* parry: it reads the Verteidigung-Waffe table, and letting the
    /// shield's presence alone decide sent it to the Schild table, whose item
    /// results then took the shield out of the loadout for a fumble it had no
    /// part in. The weapon list names the piece it rolled with, so that name is
    /// the answer.
    func isShieldInHand(_ name: String?) -> Bool {
        guard let name, let shield = selectedShield else { return false }
        return shield.name == name
    }

    /// The glyph for one named piece of the loadout — the weapon's own combat
    /// technique where it has one, a shield where it is one, a fist otherwise.
    func loadoutIcon(for name: String) -> WeaponIcon {
        if let weapon = meleeWeapons.first(where: { $0.name == name }) {
            return WeaponIcon.forTechniqueId(weapon.combatTechniqueId)
        }
        if let ranged = rangedWeapons.first(where: { $0.name == name }) {
            return WeaponIcon.forTechniqueId(ranged.combatTechniqueId)
        }
        if shields.contains(where: { $0.name == name }) { return .system("shield.fill") }
        return WeaponIcon.forTechnique(.raufen)   // Raufen, and anything unlisted
    }

    /// Which hand (or which slot) is holding the named thing.
    ///
    /// The loadout is four optional names, and a screen that has to take
    /// something *out* of it — a Patzer that destroys, drops or jams the weapon —
    /// only knows the name it was swinging. Guessing `selectedWeaponName` would
    /// disarm the main hand for an off-hand fumble and leave a dropped shield in
    /// the loadout.
    enum LoadoutSlot: String, Equatable {
        case mainHand, offHand, shield, ranged
    }

    func loadoutSlot(ofNamed name: String) -> LoadoutSlot? {
        if selectedWeaponName == name { return .mainHand }
        if selectedOffHandName == name { return .offHand }
        if selectedShieldName == name { return .shield }
        if selectedRangedWeaponName == name { return .ranged }
        return nil
    }

    /// Takes the named thing out of the loadout and returns the slot it left, so
    /// a caller that may have to put it back knows where it belongs. `nil` when
    /// the name is not in the loadout at all — Raufen, or a weapon already gone.
    @discardableResult
    func unequipFromLoadout(named name: String) -> LoadoutSlot? {
        guard let slot = loadoutSlot(ofNamed: name) else { return nil }
        switch slot {
        case .mainHand: selectedWeaponName = nil
        case .offHand:  selectedOffHandName = nil
        case .shield:   selectedShieldName = nil
        case .ranged:   selectedRangedWeaponName = nil
        }
        return slot
    }

    func equipInLoadout(named name: String, slot: LoadoutSlot) {
        switch slot {
        case .mainHand: selectedWeaponName = name
        case .offHand:  selectedOffHandName = name
        case .shield:   selectedShieldName = name
        case .ranged:   selectedRangedWeaponName = name
        }
    }

    /// Passive shield PA bonus applied to main weapon parade.
    var passiveShieldPABonus: Int {
        selectedShield?.paModifier ?? 0
    }

    /// Off-hand weapon (only if off-hand is a melee weapon, not a shield).
    var selectedOffHandWeapon: MeleeWeapon? {
        guard let name = selectedOffHandName else { return nil }
        return meleeWeapons.first { $0.name == name }
    }

    /// True if hero has the Beidhändig advantage (ADV_5), removing the -4 off-hand penalty.
    var hasBeidhaendig: Bool {
        advantages.contains { $0.ruleId == "ADV_5" }
    }

    /// Level of Beidhändiger Kampf (SA_42). Each level reduces the −2 dual-attack penalty by 1.
    var beidhaendigerKampfLevel: Int {
        tier(of: .beidhaendigerKampf)
    }

    /// Dual-attack penalty: base -2, reduced by Beidhändiger Kampf level.
    var dualAttackPenalty: Int {
        max(0, 2 - beidhaendigerKampfLevel) * -1
    }

    /// Off-hand penalty: -4 unless hero has Beidhändig (ADV_5).
    var offHandPenalty: Int {
        hasBeidhaendig ? 0 : -4
    }

    /// True if the current loadout is dual-wielding (two weapons, no shield in off-hand).
    var isDualWielding: Bool {
        selectedWeaponName != nil && selectedOffHandWeapon != nil
    }

    // MARK: - Schmerz (Pain)

    /// Raw Schmerz level from LP thresholds (0–4+), **plus** any levels a Patzer
    /// added for a few rounds (`temporarySchmerzLevel`).
    ///
    /// Schmerz is otherwise derived from LP alone, which is why `setStateLevel`
    /// refuses it: there is nothing to store. "1 Stufe Schmerz für 3
    /// Kampfrunden" is not an LP loss, so it is held beside the LP total and
    /// added here — one place, so the modifier lines, the states strip, the
    /// state detail sheet and the take-damage screen's before/after all follow
    /// without a second reader of the same fact. `effectiveSchmerzLevel` still
    /// caps the total and still applies Zäher Hund.
    var schmerzLevel: Int { lebenspunkteSchmerzLevel + temporarySchmerzLevel }

    /// The half of it the life points alone are worth: the four thresholds
    /// (¾, ½, ¼ of the maximum, and "5 LP or fewer"), and nothing else.
    ///
    /// Split out from `schmerzLevel` so the aftermath screen can say where a
    /// level came from — this one goes when the hero is healed, and there is
    /// nothing to switch off — without a second copy of the thresholds.
    var lebenspunkteSchmerzLevel: Int {
        guard let dv = derivedValues else { return 0 }
        let current = dv.lebensenergie.current
        let maxLP = dv.lebensenergie.max
        guard maxLP > 0 else { return 0 }
        var level = 0
        if current <= (maxLP * 3) / 4 { level = 1 }
        if current <= maxLP / 2 { level = 2 }
        if current <= maxLP / 4 { level = 3 }
        if current <= 5 { level += 1 }
        return level
    }

    /// True if hero has Zäher Hund (ADV_49).
    var hasZaeherHund: Bool {
        advantages.contains { $0.ruleId == "ADV_49" }
    }

    /// Effective Schmerz after Zäher Hund reduction.
    var effectiveSchmerzLevel: Int {
        let raw = schmerzLevel
        if raw >= 4 { return 4 }
        return hasZaeherHund ? max(0, raw - 1) : raw
    }

    /// Where the hero's Schmerz comes from, and what ends each part of it.
    ///
    /// Read by the screen after the fight, which used to print one inert row
    /// ("Schmerz II") and leave the player to work out whether it was something
    /// they were supposed to do anything about (owner report: "Why is this
    /// listed as read-only? This usually goes away — depending on the origin").
    /// It does go away, but by two different routes, and the app knows which:
    /// the LP part ends with healing and the Patzer part ends with this very
    /// fight. Pure, and derived from the same properties every other reader
    /// uses, so the rows cannot drift from the chip.
    var schmerzBreakdown: SchmerzBreakdown {
        SchmerzBreakdown(
            lebenspunkteLevel: lebenspunkteSchmerzLevel,
            patzerLevel: temporarySchmerzLevel,
            currentLP: derivedValues?.lebensenergie.current,
            maxLP: derivedValues?.lebensenergie.max,
            hasZaeherHund: hasZaeherHund
        )
    }

    /// Penalty from Schmerz, applied to all checks.
    var schmerzPenalty: Int { -effectiveSchmerzLevel }

    // MARK: - Player States

    /// Current stored level of a catalog state (0 if absent). Schmerz/Belastung are derived.
    func level(of stateID: String) -> Int {
        if stateID == "schmerz" { return effectiveSchmerzLevel }
        if stateID == "belastung" { return min(effectiveBE, 4) }
        return states.first { $0.stateID == stateID }?.level ?? 0
    }

    func hasState(_ stateID: String) -> Bool { level(of: stateID) > 0 }

    /// Set/clear a manually-tracked state. Clamps Zustände to 1–4, statuses to 1; level 0 removes.
    func setStateLevel(_ stateID: String, level rawLevel: Int) {
        guard !StateCatalog.derivedIDs.contains(stateID) else { return }
        let def = StateCatalog.definition(for: stateID)
        let clamped: Int = {
            if rawLevel <= 0 { return 0 }
            return def?.kind == .status ? 1 : min(rawLevel, 4)
        }()
        let existing = states.first { $0.stateID == stateID }
        if stateID == BleedingRules.stateId && clamped == 0 { bleedingRoundsLeft = nil }
        if clamped == 0 {
            if let e = existing {
                states.removeAll { $0 === e }
                modelContext?.delete(e)
            }
        } else if let e = existing {
            e.level = clamped
        } else {
            states.append(HeroStateEntry(stateID: stateID, level: clamped))
        }
    }

    /// All active states (stored + derived Schmerz/Belastung when > 0), as (definition, level).
    var activeStates: [(def: StateDefinition, level: Int)] {
        var result: [(StateDefinition, Int)] = []
        if let s = StateCatalog.definition(for: "schmerz"), effectiveSchmerzLevel > 0 {
            result.append((s, effectiveSchmerzLevel))
        }
        if let b = StateCatalog.definition(for: "belastung"), effectiveBE > 0 {
            result.append((b, min(effectiveBE, 4)))
        }
        for entry in states {
            if let def = StateCatalog.definition(for: entry.stateID) {
                result.append((def, entry.level))
            }
        }
        return result
    }

    /// True if any active Zustand penalty is suppressible by the "Zustand ignorieren" Schip.
    /// Covers Furcht, Betäubung, Paralyse, Verwirrung, Entrückung, Schmerz, etc. Belastung is
    /// intentionally excluded — `SharedModifiers.encumbrance` does not honour schipIgnoreZustand.
    var hasIgnorableZustand: Bool {
        activeStates.contains { $0.def.kind == .zustand && $0.def.id != "belastung" }
    }

    /// Sum of all Zustand levels (GR: ≥8 ⇒ Handlungsunfähig). Statuses don't count.
    var totalZustandLevels: Int {
        activeStates.filter { $0.def.kind == .zustand }.reduce(0) { $0 + $1.level }
    }

    /// Derived statuses implied by active states (e.g. bewusstlos ⇒ handlungsunfaehig, liegend).
    var impliedStateIDs: Set<String> {
        var out = Set<String>()
        for (def, _) in activeStates { out.formUnion(def.implies) }
        return out
    }

    var isHandlungsunfaehig: Bool {
        if hasState("handlungsunfaehig") || impliedStateIDs.contains("handlungsunfaehig") { return true }
        if totalZustandLevels >= 8 { return true }
        // Any Zustand at its handlungsunfaehig level (most level IV).
        return activeStates.contains { entry in
            entry.def.handlungsunfaehigAtLevel.map { entry.level >= $0 } ?? false
        }
    }

    /// Whether the hero is on the ground — stated outright, or implied by a state
    /// that carries it (Bewusstlos implies Liegend).
    var isLiegend: Bool {
        hasState("liegend") || impliedStateIDs.contains("liegend")
    }

    /// The Geschwindigkeit a move actually happens at.
    ///
    /// A prone hero moves at GS 1 (Status Liegend), which is the third thing that
    /// status does and the only one nothing in the app read: the AT −4 and the
    /// PA/AW −2 are the catalog's `STATE_10`, but the flight screen took
    /// `geschwindigkeit.max` straight off the derived values and offered a hero
    /// lying in the mud their full eight paces.
    var effectiveGeschwindigkeit: Int {
        guard !isLiegend else { return 1 }
        return derivedValues?.geschwindigkeit.max ?? 8
    }

    var isBewegungsunfaehig: Bool {
        if hasState("bewegungsunfaehig") || impliedStateIDs.contains("bewegungsunfaehig") { return true }
        return level(of: "paralyse") >= 4
    }

    // MARK: - Combat Ability Detection

    /// A Sonderfertigkeit by rule id, wherever the importer filed it.
    ///
    /// The importer sorts an SA into `combatSpecialAbilities` or
    /// `generalSpecialAbilities` by its Optolith group (`CombatSpecialAbilityGroup`).
    /// It used to ask the effects table instead, which had rows for nine combat
    /// abilities, so Plänkler-Formation (SA_884), Gezielter Angriff (SA_160) and
    /// Gezielter Schuss (SA_161) all sat in the general list while every lookup
    /// searched the combat one. Heroes imported before that fix still carry the
    /// old split, so the lookup searches both lists and does not care.
    func specialAbility(_ ruleId: String) -> HeroTrait? {
        combatSpecialAbilities.first { $0.ruleId == ruleId }
            ?? generalSpecialAbilities.first { $0.ruleId == ruleId }
    }

    func hasSpecialAbility(_ ruleId: String) -> Bool {
        specialAbility(ruleId) != nil
    }

    /// The tier of a Sonderfertigkeit, or 0 when the hero does not have it. An
    /// owned ability with no tier in the export counts as I.
    func specialAbilityTier(_ ruleId: String) -> Int {
        guard let trait = specialAbility(ruleId) else { return 0 }
        return trait.tier ?? 1
    }

    /// The tier of any trait the hero carries — Sonderfertigkeit, Vorteil or
    /// Nachteil — or `nil` when the id is not on the sheet. A trait without a
    /// tier in the export counts as I. This is design decision 6: a rule
    /// applies exactly when its id is among the hero's traits.
    func ownedRuleTier(_ ruleId: String) -> Int? {
        let trait = combatSpecialAbilities.first { $0.ruleId == ruleId }
            ?? generalSpecialAbilities.first { $0.ruleId == ruleId }
            ?? advantages.first { $0.ruleId == ruleId }
            ?? disadvantages.first { $0.ruleId == ruleId }
        guard let trait else { return nil }
        return trait.tier ?? 1
    }

    /// The same answer for every id at once, in one pass over the four lists.
    /// The evaluator walks the whole catalog on every roll and would otherwise
    /// search the sheet once per rule. First occurrence wins, as in
    /// `ownedRuleTier` — an old import can file one ability in both SA lists.
    var ownedRuleTiers: [String: Int] {
        Dictionary((combatSpecialAbilities + generalSpecialAbilities + advantages + disadvantages)
                       .map { ($0.ruleId, $0.tier ?? 1) },
                   uniquingKeysWith: { first, _ in first })
    }

    /// Every trait id on the sheet, for the not-applied list. Deduplicated,
    /// order preserved: an ability filed in both SA lists is one line.
    var ownedRuleIds: [String] {
        var seen: Set<String> = []
        return (combatSpecialAbilities + generalSpecialAbilities + advantages + disadvantages)
            .map(\.ruleId)
            .filter { seen.insert($0).inserted }
    }

    func has(_ ability: CombatAbility) -> Bool { hasSpecialAbility(ability.rawValue) }

    func tier(of ability: CombatAbility) -> Int { specialAbilityTier(ability.rawValue) }

    var hasAufmerksamkeit: Bool { has(.aufmerksamkeit) }
    var hasBerittenerKampf: Bool { has(.berittenerKampf) }
    var finteTier: Int { tier(of: .finte) }
    var wuchtschlagTier: Int { tier(of: .wuchtschlag) }
    var hasVorstoss: Bool { has(.vorstoss) }
    var hasSchildspalter: Bool { has(.schildspalter) }
    var hasPlaenklerFormation: Bool { has(.plaenklerFormation) }
    /// Gezielter Angriff and Gezielter Schuss — each halves the Zonenaufschlag
    /// for its own kind of attack.
    var hasGezielterAngriff: Bool { has(.gezielterAngriff) }
    var hasGezielterSchuss: Bool { has(.gezielterSchuss) }

    /// Horse GS for Sturmangriff damage.
    var mountGS: Int {
        pets.first?.speed ?? 0
    }

    /// Sturmangriff bonus damage: +2 + (horse GS / 2).
    var sturmangriffDamageBonus: Int {
        2 + (mountGS / 2)
    }

    /// True if hero has a mount (pet with initiative).
    var hasMount: Bool {
        pets.first.map { !$0.initiative.isEmpty } ?? false
    }

    /// Whether combat setup screen is needed.
    /// Whether the preparation screen has anything *situational* to ask about.
    ///
    /// No longer a routing gate — the screen is where the loadout is chosen, so
    /// every hero sees it — but the formation and mount sections still appear
    /// only for a hero who has either.
    var needsCombatSetup: Bool {
        hasPlaenklerFormation || hasMount
    }

    /// Clears persisted combat session so re-entering starts fresh.
    func clearCombatSession() {
        activeCombatId = nil
        activeCombatRound = 0
        activeCombatInitiative = nil
        activeCombatPlaenkler = false
        activeCombatPlaenklerBonus = nil
        activeCombatMounted = false
        activeCombatWater = ""
        // The Patzertabelle's temporary effects last a few rounds of *this*
        // fight, so they go with it. `damagedItems` does not: it lasts until
        // the thing is repaired. Nor does `indestructibleItems`: what a staff
        // is made of does not change when the fight ends.
        temporarySchmerzLevels = 0
        temporarySchmerzLastRound = 0
        activeCombatStumble = false
        activeCombatJamUntilRound = 0
        activeCombatNoDefense = false
        bleedingRoundsLeft = nil
    }

    func isFokusRuleActive(_ rule: FokusRule) -> Bool {
        fokusRules.contains(rule.rawValue)
    }

    func setFokusRule(_ rule: FokusRule, active: Bool) {
        if active {
            guard !isFokusRuleActive(rule) else { return }
            fokusRules.append(rule.rawValue)
        } else {
            fokusRules.removeAll { $0 == rule.rawValue }
        }
    }
}

// MARK: - AppCommand

struct AppCommand: Identifiable {
    let id: UUID
    let name: String
    let subparameter: String?
    let input: CommandInput?
    let execute: (CommandInput.Result?) -> Void

    var displayName: String {
        subparameter.map { "\(name): \($0)" } ?? name
    }
}

enum CommandInput {
    case integerAmount(label: String, min: Int, max: Int?, initial: Int)

    enum Result {
        case integerAmount(Int)
    }
}

// MARK: - Hero Command Registry

extension Hero {
    var commandRegistry: [AppCommand] {
        var commands: [AppCommand] = []

        if let dv = derivedValues {
            if dv.lebensenergie.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "lebensenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: dv.lebensenergie.max,
                        initial: dv.lebensenergie.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.lebensenergie.current = v
                        }
                    }
                ))
                commands.append(AppCommand(
                    id: UUID(),
                    name: "Regenerieren",
                    subparameter: nil,
                    input: nil,
                    execute: { _ in }
                ))
                commands.append(AppCommand(
                    id: UUID(),
                    name: "Heilung",
                    subparameter: nil,
                    input: nil,
                    execute: { _ in }
                ))
            }

            if dv.schicksalspunkte.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "schicksalspunkte",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: dv.schicksalspunkte.max,
                        initial: dv.schicksalspunkte.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.schicksalspunkte.current = v
                        }
                    }
                ))
            }

            if let ae = dv.astralenergie, ae.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "astralenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: ae.max,
                        initial: ae.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.astralenergie?.current = v
                        }
                    }
                ))
            }

            if let ke = dv.karmaenergie, ke.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "karmaenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: ke.max,
                        initial: ke.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.karmaenergie?.current = v
                        }
                    }
                ))
            }
        }

        if let exp = experience {
            commands.append(AppCommand(
                id: UUID(),
                name: "AP hinzufügen",
                subparameter: nil,
                input: .integerAmount(
                    label: "AP",
                    min: 1,
                    max: nil,
                    initial: 1
                ),
                execute: { result in
                    if case .integerAmount(let v) = result {
                        exp.totalAP += v
                        exp.availableAP += v
                    }
                }
            ))
        }

        for def in StateCatalog.manuallyAddable {
            commands.append(AppCommand(
                id: UUID(),
                name: def.kind == .zustand ? "Zustand" : "Status",
                subparameter: L(def.nameKey),
                input: .integerAmount(
                    label: L("states.level"),
                    min: 0,
                    max: def.kind == .zustand ? 4 : 1,
                    initial: level(of: def.id)
                ),
                execute: { result in
                    if case .integerAmount(let v) = result {
                        self.setStateLevel(def.id, level: v)
                    }
                }
            ))
        }

        for talent in talents {
            commands.append(AppCommand(
                id: UUID(),
                name: "Probe",
                subparameter: talent.name,
                input: nil,
                execute: { _ in }
            ))
        }

        if hasMount {
            commands.append(AppCommand(
                id: UUID(),
                name: "Reittier: Schaden",
                subparameter: nil,
                input: nil,
                execute: { _ in }
            ))
            commands.append(AppCommand(
                id: UUID(),
                name: "Reittier: Heilung",
                subparameter: nil,
                input: nil,
                execute: { _ in }
            ))
        }

        commands.append(AppCommand(
            id: UUID(),
            name: "Würfeln",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        commands.append(AppCommand(
            id: UUID(),
            name: "Kampf",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        commands.append(AppCommand(
            id: UUID(),
            name: "Einstellungen für \(name)",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        return commands
    }
}
