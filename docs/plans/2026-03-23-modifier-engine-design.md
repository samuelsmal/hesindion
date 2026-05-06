# Generic Modifier Engine Design

**Date:** 2026-03-23
**Status:** Approved

## Problem

Modifier calculation is hardcoded in views: `buildModifierLines()` in `CombatAnnouncementView` (melee attack), `CombatRootView` (defense), `CombatFernkampfViews` (ranged), and pain handling in `TalentProbeModal`. Adding magic requires yet another copy. Shared modifiers (pain, encumbrance) are duplicated across all flows.

## Goals

1. Unified modifier engine used by melee, ranged, defense, magic, liturgy, and talent checks
2. Magic casting flow — standalone (expandable modal) and integrated into combat (multi-round support)
3. Unified 3d20 skill check UI for talents and spells
4. DB-sourced rule effects populated via web scraper from ulisses-regelwiki.de

## Architecture

### Approach: Composable Modifier Definitions

Modifiers are value types (`ModifierDefinition`) declaring their domain applicability, computation logic, and UI representation. A central `ModifierEngine` collects applicable modifiers for a given domain/context and evaluates them.

**Hybrid storage:** Rule-specific effects (Finte AT modifier, Wuchtschlag damage) live in `rules.db` via the `effects` table. Universal situational modifiers (pain, encumbrance, iron ban) are defined in Swift — their logic depends on complex hero state that doesn't fit in DB rows.

## Core Data Types

### CheckDomain

```swift
enum CheckDomain: String, CaseIterable {
    case meleeAttack
    case meleeParry
    case meleeDodge
    case rangedAttack
    case spellCasting
    case liturgyCasting
    case talentCheck
}
```

Split parry/dodge into separate domains so modifiers like Golgariten (parry-only) and mounted penalty (dodge-only) are expressed cleanly in their domain sets.

### ModifierContext

Carries all inputs the engine needs. Fields irrelevant to the current domain are nil/default.

```swift
struct ModifierContext {
    let hero: Hero
    let domain: CheckDomain

    // Combat shared
    var mounted: Bool = false
    var schipIgnoreZustand: Bool = false
    var dualAttackActive: Bool = false
    var beengteUmgebung: Bool = false

    // Melee specific
    var opponentReach: WeaponReach? = nil
    var maneuver: CombatManeuver = .normal
    var isOffHand: Bool = false
    var twoHandedGrip: Bool = false
    var defenseCount: Int = 0
    var schipDefenseBoost: Bool = false

    // Ranged specific
    var distanz: Int = 1
    var groesse: Int = 2
    var bewegungZiel: Int = 1
    var bewegungSchuetze: Int = 0
    var sicht: Int = 0
    var kampfgetuemmel: Bool = false
    var zielen: Int = 0
    var vomPferd: Int = 0

    // Magic specific
    var maintainedSpellCount: Int = 0
    var foreignTradition: Bool = false
    var omitGesture: Bool = false
    var omitFormula: Bool = false
    var ironSteinCarried: Int = 0
    var distractionLevel: Int = 0
    var spellModifications: [SpellModification] = []

    // Plaenkler
    var plaenklerActive: Bool = false
    var plaenklerBonus: PlaenklerBonus = .at
}
```

### SpellModification

```swift
enum SpellModification: Hashable {
    case reduceCastingTime   // -1 per use
    case increaseCastingTime // +1 per use
    case increaseRange       // -1 per use
    case reduceCost          // -1 per use
    case force               // +1 per use (Erzwingen)
    case omitGesture         // -2
    case omitFormula         // -2
}
```

### ModifierLine (existing, unchanged)

```swift
struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
}
```

## ModifierDefinition & ModifierEngine

### ModifierDefinition

```swift
struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    let evaluate: (ModifierContext) -> ModifierLine?
}
```

Returns `nil` when the modifier doesn't apply.

### ModifierEngine

```swift
struct ModifierEngine {
    private let modifiers: [ModifierDefinition]

    init(modifiers: [ModifierDefinition]) {
        self.modifiers = modifiers
    }

    func evaluate(context: ModifierContext) -> [ModifierLine] {
        modifiers
            .filter { $0.domains.contains(context.domain) }
            .compactMap { $0.evaluate(context) }
    }

    func totalModifier(context: ModifierContext) -> Int {
        evaluate(context: context).reduce(0) { $0 + $1.value }
    }
}
```

### Registration

```swift
extension ModifierEngine {
    static let shared: ModifierEngine = {
        var defs: [ModifierDefinition] = []
        defs.append(contentsOf: SharedModifiers.all)
        defs.append(contentsOf: MeleeModifiers.all)
        defs.append(contentsOf: RangedModifiers.all)
        defs.append(contentsOf: DefenseModifiers.all)
        defs.append(contentsOf: MagicModifiers.all)
        return ModifierEngine(modifiers: defs)
    }()
}
```

### Modifier Groups

**SharedModifiers** — apply across most/all domains:
- `encumbrance`: domains meleeAttack, meleeParry, meleeDodge, rangedAttack, spellCasting, liturgyCasting
- `pain`: all domains

**MeleeModifiers** — domain meleeAttack:
- `vorteilhaftePosition` (+2)
- `golgariten` (+2, when mounted + Rabenschnabel + Grossschild)
- `plaenklerAT` (+1, when plaenkler active and bonus == .at)
- `weaponReach` (penalty based on reach mismatch)
- `maneuverAT` (from selected maneuver)
- `dualAttackPenalty` (from Beidhandiger Kampf level)
- `offHandPenalty` (-4 unless ADV_5)
- `beengteUmgebungAT` (based on weapon reach)

**DefenseModifiers** — domains meleeParry and/or meleeDodge:
- `multipleDefense`: meleeParry + meleeDodge (-3 per additional defense)
- `schipDefenseBoost`: meleeParry + meleeDodge (+4)
- `golgaritenPA`: meleeParry only (+1)
- `plaenklerAW`: meleeDodge only (+1)
- `mountedDodgePenalty`: meleeDodge only (-2)
- `dualAttackDefense`: meleeParry + meleeDodge
- `beengteUmgebungPA`: meleeParry only

**RangedModifiers** — domain rangedAttack:
- `distanz` (+2/0/-2)
- `groesse` (-8/-4/0/+4/+8)
- `bewegungZiel` (+2/0/-2/-4)
- `bewegungSchuetze` (0/-2/-4)
- `sicht` (0/-2/-4/-6)
- `kampfgetuemmel` (-2)
- `zielen` (0/+2/+4)
- `vomPferd` (0/-4/-8)

**MagicModifiers** — domains spellCasting and/or liturgyCasting:
- `maintainedSpells`: spellCasting + liturgyCasting (-1 per maintained spell)
- `foreignTradition`: spellCasting + liturgyCasting (-2)
- `omitGesture`: spellCasting + liturgyCasting (-2)
- `omitFormula`: spellCasting + liturgyCasting (-2)
- `ironBan`: spellCasting only (-1 per 2 Stein iron)
- `distraction`: spellCasting + liturgyCasting (variable)
- `spellModifications`: spellCasting + liturgyCasting (sum of -1/+1 per modification)

## Magic Flow

### Standalone: SpellProbeModal (expandable modal)

```
SpellProbeModal
+-- Header: spell name, check attrs (KL/IN/CH), skill value
+-- Modifier boxes (same +/- per attribute as TalentProbeModal)
+-- Collapsible "Modifications & Modifiers" section
|   +-- Spell modifications (reduce cast time, increase range, etc.)
|   |   — available if FW >= 4, max count = FW / 4
|   +-- Situational toggles (omit gesture, omit formula, foreign tradition)
|   +-- Maintained spells counter
|   +-- Iron carried stepper (in Stein)
|   +-- Distraction picker
+-- Computed modifier summary line (e.g. "Total: -3")
+-- Pain warning (same as TalentProbeModal)
+-- Dice row (3d20, tap to roll)
+-- Result + QS display
+-- AE cost deduction (full on success, 50% on failure, 50% on crit success)
```

### Combat Integration

New `CombatStep` cases:

```swift
case spellSelection
case spellSetup(spell: HeroSpell)
case spellCasting(spell: HeroSpell, startRound: Int, totalRounds: Int, modifierLines: [ModifierLine])
case spellExecution(spell: HeroSpell, modifierLines: [ModifierLine])
```

**Flow:**

```
Combat Root (AKTION section)
  +-- Angriff (existing)
  +-- Fernkampf (existing)
  +-- Zaubern (new — only if hero has AE)
  |     +-- spellSelection (pick spell)
  |           +-- spellSetup (modifications, situational modifiers)
  |                 +-- 1-action spell -> spellExecution (roll immediately)
  |                 +-- multi-action spell -> spellCasting (round tracker)
  |                       +-- each new round: "Continue casting" or "Abort"
  |                             +-- final round -> spellExecution
  +-- Parieren (existing)
  +-- Ausweichen (existing)
```

**Multi-round casting:**
- Shows persistent banner on combat root: "Casting: [Spell] (2/4)"
- Hero's attack action is consumed each round
- Defense actions (Parry/Dodge) remain available but trigger Selbstbeherrschung check
- Interruption (damage or failed concentration): spell fails, full AE cost
- Completion: transitions to spellExecution for 3d20 check

**AE deduction rules:**
- Success: full modified AE cost
- Failure: 50% of modified AE cost
- Critical success: 50% of modified AE cost
- Interruption: full base AE cost

## Unified SkillCheckModal

Extract the shared 3d20 check UI from `TalentProbeModal` into a generic component.

### SkillCheckConfig

```swift
struct SkillCheckConfig {
    let title: String                              // "Probe" / "Zauberprobe"
    let name: String                               // talent or spell name
    let skillValue: Int                            // FW
    let checkAttributes: [(key: String, value: Int)] // 3 attrs
    let accentColor: Color
    let modifierLines: [ModifierLine]              // from ModifierEngine
    let logKind: String                            // "talentCheck" / "spellCheck"
}
```

### SkillCheckResult

```swift
struct SkillCheckResult {
    let rolls: [Int]
    let qualityLevel: Int
    let succeeded: Bool
    let isCriticalSuccess: Bool
    let isCriticalFailure: Bool
    let remainingSkillPoints: Int
}
```

### SkillCheckModal

Contains the dice animation, roll logic, QS computation, and result display. Driven by `SkillCheckConfig`.

### Wrappers

- `TalentProbeModal` becomes a thin wrapper that builds `SkillCheckConfig` from `Talent` + `ModifierEngine` output
- `SpellProbeModal` wraps `SkillCheckModal` with a collapsible modifications/modifiers section above

## DB-Sourced Rule Effects

### Scope-to-domain mapping

```swift
extension RuleEffect {
    var applicableDomains: Set<CheckDomain> {
        switch scope {
        case "meleeAttack":    return [.meleeAttack]
        case "meleeDefense":   return [.meleeParry, .meleeDodge]
        case "combat":         return [.meleeAttack, .meleeParry, .meleeDodge]
        case "ranged":         return [.rangedAttack]
        case "magic":          return [.spellCasting]
        case "liturgy":        return [.liturgyCasting]
        case "all":            return Set(CheckDomain.allCases)
        default:               return []
        }
    }
}
```

### What stays hardcoded vs. DB-sourced

| Source | Examples | Why |
|--------|----------|-----|
| Swift | Pain, encumbrance, weapon reach, iron ban, maintained spells, ranged distance/size/visibility | Complex conditional logic on hero state |
| DB effects | Finte AT modifier, Wuchtschlag AT/damage, Golgariten bonuses, Belastungsgewoehnung BE reduction | Simple value lookups by rule ID + level |
| Hybrid | Maneuver effects (UI drives selection, DB provides values) | |

### Incremental migration

1. Keep hardcoded modifiers as primary source
2. Add `RuleEffectModifiers` loader that creates `ModifierDefinition` entries from DB effects
3. As more effects populate the DB, remove hardcoded equivalents one by one

## Effects Scraper

New Python script `scripts/scrape_effects/scrape_effects.py` that:

1. Crawls ulisses-regelwiki.de for special abilities, advantages, disadvantages
2. Extracts mechanical effects (modifier type, attribute, value, scope, conditions)
3. Outputs structured YAML matching the existing `effects` table schema
4. Feeds into `build_db.py` via the `--effects` flag

Target pages:
- Combat special abilities (Finte, Wuchtschlag, Vorstoss, etc.)
- General special abilities affecting checks
- Advantages/disadvantages with mechanical effects
- Magic-related special abilities

## Refactoring Existing Combat

Each hardcoded `buildModifierLines()` is replaced by a single `ModifierEngine.shared.evaluate(context:)` call.

### Migration mapping

| Old code location | New domain | Approx. modifier count |
|--------------------|------------|----------------------|
| `CombatAnnouncementView.buildModifierLines()` | `.meleeAttack` | ~10 |
| `CombatRootView.buildDefenseModifiers(false)` | `.meleeParry` | ~8 |
| `CombatRootView.buildDefenseModifiers(true)` | `.meleeDodge` | ~7 |
| `CombatFernkampfSetupView.buildModifierLines()` | `.rangedAttack` | ~10 |
| `TalentProbeModal` (pain only) | `.talentCheck` | ~2 |
| **New:** SpellProbeModal | `.spellCasting` | ~8 |
| **New:** LiturgyProbeModal | `.liturgyCasting` | ~5 |

## Magic Modifier Reference (from DSA 5 rules)

| Modifier | Value | Domains |
|----------|-------|---------|
| Pain (Schmerz) | -1 to -4 per level | All |
| Encumbrance (Belastung) | -BE | All except talentCheck |
| Maintained spells | -1 per active spell | spellCasting, liturgyCasting |
| Foreign tradition | -2 | spellCasting, liturgyCasting |
| Omit gesture | -2 | spellCasting, liturgyCasting |
| Omit formula | -2 | spellCasting, liturgyCasting |
| Iron ban (Bann des Eisens) | -1 per 2 Stein | spellCasting only |
| Distraction: tap on shoulder | +3 | spellCasting, liturgyCasting |
| Distraction: swaying ship | 0 | spellCasting, liturgyCasting |
| Distraction: freefall | -3 | spellCasting, liturgyCasting |
| Distraction: taking damage | -(dmg/3, min 1) | spellCasting, liturgyCasting |
| Reduce casting time | -1 each | spellCasting, liturgyCasting |
| Increase casting time | +1 each | spellCasting, liturgyCasting |
| Increase range | -1 each | spellCasting, liturgyCasting |
| Reduce cost | -1 each | spellCasting, liturgyCasting |
| Force (Erzwingen) | +1 each | spellCasting, liturgyCasting |

## File Structure

```
Hesindion/
  Engine/
    ModifierEngine.swift          — ModifierEngine, ModifierDefinition, ModifierContext, CheckDomain
    SharedModifiers.swift         — pain, encumbrance
    MeleeModifiers.swift          — melee attack modifiers
    DefenseModifiers.swift        — parry/dodge modifiers
    RangedModifiers.swift         — ranged attack modifiers
    MagicModifiers.swift          — spell/liturgy casting modifiers
    RuleEffectModifiers.swift     — DB-sourced effect loader
  Views/
    SkillCheckModal.swift         — generic 3d20 check UI (extracted from TalentProbeModal)
    SpellProbeModal.swift         — spell-specific wrapper with modifications section
    CombatSpellViews.swift        — spell selection, setup, casting, execution combat steps
scripts/
  scrape_effects/
    scrape_effects.py             — web scraper for rule effects
    requirements.txt
```
