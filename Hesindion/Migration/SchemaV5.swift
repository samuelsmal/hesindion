import Foundation
import SwiftData

/// V5 pins its own `Hero` and `DerivedValues`, the way `SchemaV1` pins its own `Hero`.
///
/// Every other schema version names the *live* model classes rather than a frozen
/// snapshot, which is fine as long as nothing about their shape ever needs to be
/// compared against another version's — but `migrateV5toV6` (Task 9, the sheet
/// cut-over) is exactly that comparison: it drops `DerivedValues.ausweichen`,
/// `.initiative` and `.wundschwelle`. Once those three properties are gone from the
/// *live* `DerivedValues`, `SchemaV5.models` and `SchemaV6.models` would both describe
/// the identical, current shape if V5 also named the live class — `SchemaMigrationPlan`
/// then refuses the plan with "Duplicate version checksums detected," since two
/// versions cannot legitimately hash to the same schema. Pinning `V5.DerivedValues` to
/// the shape it actually had keeps V5 a real, distinct version.
///
/// `Hero.derivedValues`'s Swift type is fixed at the call site, so the model that owns
/// a `derivedValues: SchemaV5.DerivedValues?` property cannot be the live `Hero` (whose
/// `derivedValues` names the live `DerivedValues`) — it has to be `V5.Hero`, a second
/// pinned type. **`V5.Hero` carries every plain (non-relationship) stored property the
/// live `Hero` has, but none of its relationships to another `@Model` type** —
/// `personalData`, `talents`, `meleeWeapons`, `activeAdventure`, `logEntries`,
/// `states`, … — because SwiftData resolves a relationship's inverse
/// process-globally, not per `Schema`: two differently-shaped "Hero" entities both
/// relating to the same target type (`PersonalData`, `HeroSpell`, whichever) collide
/// there with "Inverse Relationship does not exist". This is reproducible with
/// `Schema(versionedSchema: SchemaV1.self)` alone, on its own, unrelated to anything
/// Task 9 touched — `SchemaV1.Hero` duplicates the live class's relationships
/// verbatim and has carried this latent bug since before this task; it was simply
/// never exercised, because nothing ever built a `ModelContainer` from
/// `HesindionMigrationPlan` before `SchemaV6MigrationTests`. Fixing `SchemaV1`
/// (and `V2`–`V4`, which share the live `Hero`) is out of scope for the sheet
/// cut-over. The *plain* properties (`advantages`, `notes`, the combat-session
/// fields, …) are safe to copy in full: `HeroTrait` and friends are `Codable`
/// structs, not `@Model` types, so nothing about them is process-global, and
/// without them lightweight migration has no default to synthesize for a *new*,
/// non-optional attribute with none and refuses the migration outright ("Validation
/// error missing attribute values on mandatory destination attribute") rather than
/// adding an empty array.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchemaV5.Hero.self,
            SchemaV5.DerivedValues.self,
        ]
    }

    /// The `ComputedValue` struct backing `ausweichen`/`initiative`/`wundschwelle`
    /// before Task 9 deleted all four together.
    struct LegacyComputedValue: Codable {
        var value: Int
        var bonus: Int
        var max: Int
    }

    /// `DerivedValues` as it was before Task 9 (sheet cut-over) deleted
    /// `ausweichen`, `initiative` and `wundschwelle` — otherwise identical to the
    /// live model, property for property.
    @Model
    final class DerivedValues {
        var lebensenergie: LifeEnergyValue
        var astralenergie: MutableResourceValue?
        var karmaenergie: MutableResourceValue?
        var seelenkraft: ResourceValue
        var zaehigkeit: ResourceValue
        var ausweichen: LegacyComputedValue
        var initiative: LegacyComputedValue
        var geschwindigkeit: ResourceValue
        var wundschwelle: LegacyComputedValue
        var schicksalspunkte: MutableResourceValue
        var speciesLE: Int? = nil

        init(
            lebensenergie: LifeEnergyValue,
            astralenergie: MutableResourceValue?,
            karmaenergie: MutableResourceValue?,
            seelenkraft: ResourceValue,
            zaehigkeit: ResourceValue,
            ausweichen: LegacyComputedValue,
            initiative: LegacyComputedValue,
            geschwindigkeit: ResourceValue,
            wundschwelle: LegacyComputedValue,
            schicksalspunkte: MutableResourceValue
        ) {
            self.lebensenergie = lebensenergie
            self.astralenergie = astralenergie
            self.karmaenergie = karmaenergie
            self.seelenkraft = seelenkraft
            self.zaehigkeit = zaehigkeit
            self.ausweichen = ausweichen
            self.initiative = initiative
            self.geschwindigkeit = geschwindigkeit
            self.wundschwelle = wundschwelle
            self.schicksalspunkte = schicksalspunkte
        }
    }

    /// Deliberately excludes every relationship to a model type the live `Hero` *also*
    /// relates to (`personalData`, `talents`, `meleeWeapons`, `activeAdventure`,
    /// `logEntries`, `states`, …; see the file doc comment) — the one relationship this
    /// type keeps, `derivedValues`, points at `SchemaV5.DerivedValues`, a type nothing
    /// else in the app touches.
    ///
    /// Every plain (non-relationship) stored property `Hero` has **with no default
    /// value** is copied verbatim, though: `advantages`, `disadvantages` and friends are
    /// `[HeroTrait]` (a plain `Codable` struct, not a `@Model`), so copying them here
    /// costs nothing and cannot hit the collision above — and without them, lightweight
    /// migration has no default to synthesize for a *new*, non-optional attribute with
    /// none, and refuses with "Validation error missing attribute values on mandatory
    /// destination attribute" instead of adding an empty array.
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

        @Relationship(deleteRule: .cascade) var derivedValues: SchemaV5.DerivedValues?

        var notes: String = ""
        var colorSchemeId: String?
        var lastImportedAt: Date?
        var fokusRules: [String] = []
        var hitZoneSize: String?
        var consecratedWeapons: [String] = []
        var unconsecratedWeapons: [String] = []
        var damagedItems: [String] = []
        var indestructibleItems: [String] = []

        var selectedWeaponName: String?
        var selectedShieldName: String?
        var selectedOffHandName: String?
        var selectedRangedWeaponName: String?

        var activeCombatId: UUID?
        var activeCombatRound: Int = 0
        var activeCombatInitiative: Int?
        var activeCombatPlaenkler: Bool = false
        var activeCombatPlaenklerBonus: String?
        var activeCombatMounted: Bool = false
        var activeCombatBeengt: Bool = false
        var activeCombatWater: String = ""

        var temporarySchmerzLevels: Int = 0
        var temporarySchmerzLastRound: Int = 0
        var activeCombatStumble: Bool = false
        var activeCombatJamUntilRound: Int = 0
        var activeCombatNoDefense: Bool = false
        var bleedingRoundsLeft: Int? = nil

        init(name: String) {
            self.name = name
            self.advantages = []
            self.disadvantages = []
            self.generalSpecialAbilities = []
            self.combatSpecialAbilities = []
            self.cantrips = []
            self.blessings = []
            self.scripts = []
        }
    }
}
