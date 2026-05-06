# Modifier Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Replace hardcoded modifier calculation with a composable ModifierEngine, unify the 3d20 skill check UI, add magic casting flow (standalone + combat), and populate rule effects from the web.

**Architecture:** Composable `ModifierDefinition` structs evaluated by a central `ModifierEngine`. Hybrid storage — universal modifiers (pain, encumbrance) in Swift, rule-specific effects from `rules.db`. `SkillCheckModal` extracted from `TalentProbeModal` as shared 3d20 UI.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, SQLite3, Python 3 (scraper)

---

### Task 0: Create Engine directory and core types

**Files:**
- Create: `Hesindion/Engine/ModifierEngine.swift`

**Step 1: Create the Engine directory and core file**

```bash
mkdir -p Hesindion/Engine
```

**Step 2: Write CheckDomain, SpellModification, ModifierContext, ModifierDefinition, and ModifierEngine**

Create `Hesindion/Engine/ModifierEngine.swift` with:

```swift
import Foundation

// MARK: - CheckDomain

enum CheckDomain: String, CaseIterable {
    case meleeAttack
    case meleeParry
    case meleeDodge
    case rangedAttack
    case spellCasting
    case liturgyCasting
    case talentCheck
}

// MARK: - SpellModification

enum SpellModification: Hashable {
    case reduceCastingTime
    case increaseCastingTime
    case increaseRange
    case reduceCost
    case force
    case omitGesture
    case omitFormula
}

// MARK: - ModifierContext

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

// MARK: - ModifierDefinition

struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    let evaluate: (ModifierContext) -> ModifierLine?
}

// MARK: - ModifierEngine

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

**Step 3: Verify it compiles**

```bash
make build
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Hesindion/Engine/ModifierEngine.swift
git commit -m "feat: add ModifierEngine core types"
```

---

### Task 1: Shared modifiers (pain, encumbrance)

**Files:**
- Create: `Hesindion/Engine/SharedModifiers.swift`

**Step 1: Write SharedModifiers**

Create `Hesindion/Engine/SharedModifiers.swift`:

```swift
import Foundation

enum SharedModifiers {
    static let all: [ModifierDefinition] = [encumbrance, pain]

    static let encumbrance = ModifierDefinition(
        id: "encumbrance",
        domains: [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack, .spellCasting, .liturgyCasting]
    ) { ctx in
        let be = ctx.mounted ? max(0, ctx.hero.effectiveBE - 1) : ctx.hero.effectiveBE
        guard be > 0 else { return nil }
        return ModifierLine(value: -be, source: L("source.belastung"))
    }

    static let pain = ModifierDefinition(
        id: "pain",
        domains: Set(CheckDomain.allCases)
    ) { ctx in
        guard !ctx.schipIgnoreZustand, ctx.hero.schmerzPenalty != 0 else { return nil }
        let level = ctx.hero.effectiveSchmerzLevel
        let roman = level > 0 ? " " + String(repeating: "I", count: min(level, 4)) : ""
        return ModifierLine(value: ctx.hero.schmerzPenalty, source: L("source.schmerz") + roman)
    }
}
```

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/SharedModifiers.swift
git commit -m "feat: add shared modifiers (pain, encumbrance)"
```

---

### Task 2: Melee attack modifiers

**Files:**
- Create: `Hesindion/Engine/MeleeModifiers.swift`

**Step 1: Write MeleeModifiers**

Create `Hesindion/Engine/MeleeModifiers.swift`. Extract every modifier from `CombatAnnouncementView.buildModifierLines()` (currently at `Hesindion/Views/CombatAttackViews.swift:565-617`):

```swift
import Foundation

enum MeleeModifiers {
    static let all: [ModifierDefinition] = [
        vorteilhaftePosition, golgariten, plaenklerAT,
        weaponReach, maneuverAT, dualAttackPenalty,
        offHandPenalty, beengteUmgebungAT,
    ]

    static let vorteilhaftePosition = ModifierDefinition(
        id: "vorteilhaftePosition",
        domains: [.meleeAttack]
    ) { ctx in
        let golgaritenForced = ctx.hero.golgaritenActive(mounted: ctx.mounted)
        // The view passes vorteilhaftePosition via the context; golgariten auto-sets it.
        // Since vorteilhaftePosition is a UI toggle, we check golgariten here as the forced case.
        // The actual toggle state is handled by the view — this modifier covers the golgariten-forced case.
        guard golgaritenForced else { return nil }
        return ModifierLine(value: 2, source: L("source.vorteilhaft"))
    }

    static let golgariten = ModifierDefinition(
        id: "golgariten",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted) else { return nil }
        return ModifierLine(value: 2, source: L("source.golgariten"))
    }

    static let plaenklerAT = ModifierDefinition(
        id: "plaenklerAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.plaenklerActive, ctx.plaenklerBonus == .at else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    static let weaponReach = ModifierDefinition(
        id: "weaponReach",
        domains: [.meleeAttack]
    ) { ctx in
        guard let opponentReach = ctx.opponentReach else { return nil }
        let heroReach = WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
        let penalty = heroReach.atPenaltyAgainst(opponentReach)
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.reach"))
    }

    static let maneuverAT = ModifierDefinition(
        id: "maneuverAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.maneuver.atModifier != 0 else { return nil }
        return ModifierLine(value: ctx.maneuver.atModifier, source: ctx.maneuver.sourceLabel)
    }

    static let dualAttackPenalty = ModifierDefinition(
        id: "dualAttackPenaltyAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    static let offHandPenalty = ModifierDefinition(
        id: "offHandPenalty",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.isOffHand, ctx.hero.offHandPenalty != 0 else { return nil }
        return ModifierLine(value: ctx.hero.offHandPenalty, source: L("source.offHand"))
    }

    static let beengteUmgebungAT = ModifierDefinition(
        id: "beengteUmgebungAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.beengteUmgebung else { return nil }
        let heroReach = WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
        let penalty = heroReach.beengteUmgebungPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("beengteUmgebung"))
    }
}
```

**Important:** The `vorteilhaftePosition` modifier above only covers the golgariten-forced case. The manual toggle for vorteilhafte Position needs to remain in the view since it's a UI state toggle, not hero-derived. The view should add this line manually when the toggle is on and golgariten is NOT forced. This matches the current behavior at `CombatAttackViews.swift:576-578`.

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/MeleeModifiers.swift
git commit -m "feat: add melee attack modifiers"
```

---

### Task 3: Defense modifiers

**Files:**
- Create: `Hesindion/Engine/DefenseModifiers.swift`

**Step 1: Write DefenseModifiers**

Create `Hesindion/Engine/DefenseModifiers.swift`. Extract from `CombatRootView.buildDefenseModifiers(isAusweichen:)` at `Hesindion/Views/CombatRootView.swift:26-82`:

```swift
import Foundation

enum DefenseModifiers {
    static let all: [ModifierDefinition] = [
        multipleDefense, schipDefenseBoost, golgaritenPA,
        plaenklerAW, mountedDodgePenalty, dualAttackDefense,
        beengteUmgebungPA,
    ]

    static let multipleDefense = ModifierDefinition(
        id: "multipleDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.defenseCount > 0 else { return nil }
        return ModifierLine(value: -(ctx.defenseCount * 3), source: L("source.multipleDefense"))
    }

    static let schipDefenseBoost = ModifierDefinition(
        id: "schipDefenseBoost",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.schipDefenseBoost else { return nil }
        return ModifierLine(value: 4, source: L("source.schipDefense"))
    }

    static let golgaritenPA = ModifierDefinition(
        id: "golgaritenPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted) else { return nil }
        return ModifierLine(value: 1, source: L("source.golgariten"))
    }

    static let plaenklerAW = ModifierDefinition(
        id: "plaenklerAW",
        domains: [.meleeDodge]
    ) { ctx in
        guard ctx.plaenklerActive, ctx.plaenklerBonus == .aw else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    static let mountedDodgePenalty = ModifierDefinition(
        id: "mountedDodgePenalty",
        domains: [.meleeDodge]
    ) { ctx in
        guard ctx.mounted else { return nil }
        return ModifierLine(value: -2, source: L("source.mounted"))
    }

    static let dualAttackDefense = ModifierDefinition(
        id: "dualAttackDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    static let beengteUmgebungPA = ModifierDefinition(
        id: "beengteUmgebungPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.beengteUmgebung else { return nil }
        let heroReach: WeaponReach
        if let w = ctx.hero.selectedWeapon {
            heroReach = WeaponReach(rawValue: w.reach) ?? .mittel
        } else {
            heroReach = .kurz
        }
        let penalty = heroReach.beengteUmgebungPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("beengteUmgebung"))
    }
}
```

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/DefenseModifiers.swift
git commit -m "feat: add defense modifiers (parry/dodge)"
```

---

### Task 4: Ranged attack modifiers

**Files:**
- Create: `Hesindion/Engine/RangedModifiers.swift`

**Step 1: Write RangedModifiers**

Create `Hesindion/Engine/RangedModifiers.swift`. Extract from `CombatFernkampfSetupView.buildModifierLines()` at `Hesindion/Views/CombatFernkampfViews.swift:25-84`:

```swift
import Foundation

enum RangedModifiers {
    static let all: [ModifierDefinition] = [
        distanz, groesse, bewegungZiel, bewegungSchuetze,
        sicht, kampfgetuemmel, zielen, vomPferd,
    ]

    static let distanz = ModifierDefinition(
        id: "distanz",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [2, 0, -2]
        let val = mods[ctx.distanz]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.distanz"))
    }

    static let groesse = ModifierDefinition(
        id: "groesse",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [-8, -4, 0, 4, 8]
        let val = mods[ctx.groesse]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.groesse"))
    }

    static let bewegungZiel = ModifierDefinition(
        id: "bewegungZiel",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [2, 0, -2, -4]
        let val = mods[ctx.bewegungZiel]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.bewegungZiel"))
    }

    static let bewegungSchuetze = ModifierDefinition(
        id: "bewegungSchuetze",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, -2, -4]
        let val = mods[ctx.bewegungSchuetze]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.bewegungSchuetze"))
    }

    static let sicht = ModifierDefinition(
        id: "sicht",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, -2, -4, -6]
        let val = mods[ctx.sicht]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.sicht"))
    }

    static let kampfgetuemmel = ModifierDefinition(
        id: "kampfgetuemmel",
        domains: [.rangedAttack]
    ) { ctx in
        guard ctx.kampfgetuemmel else { return nil }
        return ModifierLine(value: -2, source: L("source.kampfgetuemmel"))
    }

    static let zielen = ModifierDefinition(
        id: "zielen",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, 2, 4]
        let val = mods[ctx.zielen]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.zielen"))
    }

    static let vomPferd = ModifierDefinition(
        id: "vomPferd",
        domains: [.rangedAttack]
    ) { ctx in
        guard ctx.mounted else { return nil }
        let mods = [0, -4, -8]
        let val = mods[ctx.vomPferd]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.vomPferd"))
    }
}
```

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/RangedModifiers.swift
git commit -m "feat: add ranged attack modifiers"
```

---

### Task 5: Magic modifiers

**Files:**
- Create: `Hesindion/Engine/MagicModifiers.swift`

**Step 1: Write MagicModifiers**

Create `Hesindion/Engine/MagicModifiers.swift`:

```swift
import Foundation

enum MagicModifiers {
    static let all: [ModifierDefinition] = [
        maintainedSpells, foreignTradition, omitGesture,
        omitFormula, ironBan, distraction, spellMods,
    ]

    static let maintainedSpells = ModifierDefinition(
        id: "maintainedSpells",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.maintainedSpellCount > 0 else { return nil }
        return ModifierLine(value: -ctx.maintainedSpellCount, source: L("source.maintainedSpells"))
    }

    static let foreignTradition = ModifierDefinition(
        id: "foreignTradition",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.foreignTradition else { return nil }
        return ModifierLine(value: -2, source: L("source.foreignTradition"))
    }

    static let omitGesture = ModifierDefinition(
        id: "omitGesture",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.omitGesture else { return nil }
        return ModifierLine(value: -2, source: L("source.omitGesture"))
    }

    static let omitFormula = ModifierDefinition(
        id: "omitFormula",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.omitFormula else { return nil }
        return ModifierLine(value: -2, source: L("source.omitFormula"))
    }

    static let ironBan = ModifierDefinition(
        id: "ironBan",
        domains: [.spellCasting]
    ) { ctx in
        let penalty = ctx.ironSteinCarried / 2
        guard penalty > 0 else { return nil }
        return ModifierLine(value: -penalty, source: L("source.bannDesEisens"))
    }

    static let distraction = ModifierDefinition(
        id: "distraction",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        // distractionLevel: 0=none, 1=minor(+3), 2=ship(0), 3=freefall(-3)
        let mods = [0, 3, 0, -3]
        guard ctx.distractionLevel > 0 else { return nil }
        let val = mods[ctx.distractionLevel]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.distraction"))
    }

    static let spellMods = ModifierDefinition(
        id: "spellModifications",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard !ctx.spellModifications.isEmpty else { return nil }
        var total = 0
        for mod in ctx.spellModifications {
            switch mod {
            case .reduceCastingTime, .increaseRange, .reduceCost:
                total -= 1
            case .increaseCastingTime, .force:
                total += 1
            case .omitGesture, .omitFormula:
                break // handled by dedicated modifiers above
            }
        }
        guard total != 0 else { return nil }
        return ModifierLine(value: total, source: L("source.spellModifications"))
    }
}
```

**Step 2: Add localization strings**

Add to the `strings` dictionary in `Hesindion/Theme/Strings.swift` (before the closing `]` around line 874):

```swift
// Magic modifier sources
"source.maintainedSpells":  "Aufrechterh. Zauber",
"source.foreignTradition":  "Fremde Tradition",
"source.omitGesture":       "Ohne Geste",
"source.omitFormula":       "Ohne Formel",
"source.bannDesEisens":     "Bann des Eisens",
"source.distraction":       "Ablenkung",
"source.spellModifications":"Modifikationen",
```

**Step 3: Verify it compiles**

```bash
make build
```

**Step 4: Commit**

```bash
git add Hesindion/Engine/MagicModifiers.swift Hesindion/Theme/Strings.swift
git commit -m "feat: add magic modifiers and localization strings"
```

---

### Task 6: Wire up ModifierEngine.shared

**Files:**
- Modify: `Hesindion/Engine/ModifierEngine.swift`

**Step 1: Add the shared factory**

Append to `Hesindion/Engine/ModifierEngine.swift`:

```swift
extension ModifierEngine {
    static let shared: ModifierEngine = {
        var defs: [ModifierDefinition] = []
        defs.append(contentsOf: SharedModifiers.all)
        defs.append(contentsOf: MeleeModifiers.all)
        defs.append(contentsOf: DefenseModifiers.all)
        defs.append(contentsOf: RangedModifiers.all)
        defs.append(contentsOf: MagicModifiers.all)
        return ModifierEngine(modifiers: defs)
    }()
}
```

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/ModifierEngine.swift
git commit -m "feat: wire up ModifierEngine.shared with all modifier groups"
```

---

### Task 7: Migrate melee attack to ModifierEngine

**Files:**
- Modify: `Hesindion/Views/CombatAttackViews.swift:543-617`

**Step 1: Replace buildModifierLines() in CombatAnnouncementView**

In `Hesindion/Views/CombatAttackViews.swift`, replace the `buildModifierLines()` method (lines 565-617) with:

```swift
private func buildModifierLines() -> [ModifierLine] {
    var context = ModifierContext(hero: hero, domain: .meleeAttack)
    context.mounted = mountedActive
    context.schipIgnoreZustand = schipIgnoreZustandThisRound
    context.dualAttackActive = dualAttackPenaltyActive
    context.beengteUmgebung = beengteUmgebungActive
    context.opponentReach = selectedOpponentReach
    context.maneuver = selectedManeuver
    context.isOffHand = isOffHand
    context.plaenklerActive = plaenklerActive
    context.plaenklerBonus = plaenklerBonus

    var lines = ModifierEngine.shared.evaluate(context: context)

    // Manual vorteilhafte Position toggle (not golgariten-forced)
    if !golgaritenForced && vorteilhaftePosition {
        lines.insert(ModifierLine(value: 2, source: L("source.vorteilhaft")), at: lines.firstIndex { $0.source == L("source.golgariten") } ?? lines.startIndex)
    }

    return lines
}
```

**Note:** The vorteilhafte Position manual toggle must be handled in the view because it's UI state. When golgariten is forced, the engine handles it. When the user manually toggles it, the view adds the line. This preserves the existing behavior.

**Step 2: Verify it compiles and test manually**

```bash
make build
```

Then test in simulator: start combat, select a weapon, go through announcement, verify modifier lines match previous behavior.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatAttackViews.swift
git commit -m "refactor: migrate melee attack modifiers to ModifierEngine"
```

---

### Task 8: Migrate defense to ModifierEngine

**Files:**
- Modify: `Hesindion/Views/CombatRootView.swift:26-82`

**Step 1: Replace buildDefenseModifiers() in CombatRootView**

Replace the `buildDefenseModifiers(isAusweichen:)` method with:

```swift
private func buildDefenseModifiers(isAusweichen: Bool) -> [ModifierLine] {
    var context = ModifierContext(
        hero: hero,
        domain: isAusweichen ? .meleeDodge : .meleeParry
    )
    context.mounted = mountedActive
    context.schipIgnoreZustand = schipIgnoreZustandThisRound
    context.dualAttackActive = dualAttackPenaltyActive
    context.beengteUmgebung = beengteUmgebungActive
    context.defenseCount = defenseCountThisRound
    context.schipDefenseBoost = schipDefenseBoostActive
    context.plaenklerActive = plaenklerActive
    context.plaenklerBonus = plaenklerBonus

    return ModifierEngine.shared.evaluate(context: context)
}
```

**Step 2: Verify it compiles and test manually**

```bash
make build
```

Test: start combat, parry/dodge, verify modifier lines match.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatRootView.swift
git commit -m "refactor: migrate defense modifiers to ModifierEngine"
```

---

### Task 9: Migrate ranged attack to ModifierEngine

**Files:**
- Modify: `Hesindion/Views/CombatFernkampfViews.swift:25-84`

**Step 1: Replace buildModifierLines() in CombatFernkampfSetupView**

Replace the `buildModifierLines()` method with:

```swift
private func buildModifierLines() -> [ModifierLine] {
    var context = ModifierContext(hero: hero, domain: .rangedAttack)
    context.mounted = mountedActive
    context.schipIgnoreZustand = schipIgnoreZustandThisRound
    context.distanz = distanz
    context.groesse = groesse
    context.bewegungZiel = bewegungZiel
    context.bewegungSchuetze = bewegungSchuetze
    context.sicht = sicht
    context.kampfgetuemmel = kampfgetuemmel
    context.zielen = zielen
    context.vomPferd = vomPferd

    return ModifierEngine.shared.evaluate(context: context)
}
```

**Step 2: Verify it compiles and test manually**

```bash
make build
```

Test: start combat with ranged weapon, go through fernkampf setup, verify modifiers.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatFernkampfViews.swift
git commit -m "refactor: migrate ranged attack modifiers to ModifierEngine"
```

---

### Task 10: Extract SkillCheckModal from TalentProbeModal

**Files:**
- Create: `Hesindion/Views/SkillCheckModal.swift`
- Modify: `Hesindion/Views/TalentProbeModal.swift`

**Step 1: Create SkillCheckConfig and SkillCheckResult types**

Create `Hesindion/Views/SkillCheckModal.swift` with the config, result types, and the generic 3d20 check view. Extract the following from `TalentProbeModal`:
- `probeContent()` → becomes the main body
- `attrBox()`, `modBox()`, `diceBox()`, `resultBox()` → move as-is
- `summaryBar()`, `summaryText()` → move, parameterized by config
- `computeResult()` and `ProbeResult` enum → move, rename to `SkillCheckResult`
- `startAnimation()`, `roll()` → move
- Dice animation state (`displayRolls`, `finalRolls`, `animationTask`)

The key difference: `SkillCheckModal` takes a `SkillCheckConfig` instead of a `Talent`. The config provides `name`, `skillValue`, `checkAttributes`, `accentColor`, `modifierLines`, and `logKind`.

The `modifierLines` from the engine are displayed as a summary above the dice row and their total is applied uniformly to all three attribute checks (same as `schmerzPenalty` currently works in `computeResult`).

```swift
struct SkillCheckConfig {
    let title: String
    let name: String
    let skillValue: Int
    let checkAttributes: [(key: String, value: Int)]
    let accentColor: Color
    let modifierLines: [ModifierLine]
    let logKind: String
}

struct SkillCheckResult {
    let rolls: [Int]
    let qualityLevel: Int
    let succeeded: Bool
    let isCriticalSuccess: Bool
    let isCriticalFailure: Bool
    let remainingSkillPoints: Int
}
```

**Step 2: Refactor TalentProbeModal to wrap SkillCheckModal**

`TalentProbeModal` becomes a thin wrapper that:
1. Looks up check attributes via `TalentProbeAttributes.lookup()`
2. Builds a `ModifierContext` with `domain: .talentCheck` and gets engine modifier lines
3. Constructs `SkillCheckConfig`
4. Displays any hints (Aufmerksamkeit for TAL_8) above or below
5. Delegates to `SkillCheckModal`

**Step 3: Verify it compiles and test manually**

```bash
make build
```

Test: open a hero, tap a talent, verify the probe modal works exactly as before.

**Step 4: Commit**

```bash
git add Hesindion/Views/SkillCheckModal.swift Hesindion/Views/TalentProbeModal.swift
git commit -m "refactor: extract generic SkillCheckModal from TalentProbeModal"
```

---

### Task 11: Add magic localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add all magic-related strings**

Add to the `strings` dictionary in `Hesindion/Theme/Strings.swift`:

```swift
// Magic flow
"castSpell":                "Zaubern",
"spellProbe":               "Zauberprobe",
"liturgyProbe":             "Liturgieprobe",
"spellSelection":           "Zauber wählen",
"spellSetup":               "Zauber vorbereiten",
"spellCasting.banner":      "Wirkt: %@ (%d/%d)",
"spellCasting.continue":    "Weiter wirken",
"spellCasting.abort":       "Abbrechen",
"spellCasting.interrupted": "Unterbrochen!",
"aeCost":                   "AsP-Kosten",
"aeCost.success":           "AsP: %d",
"aeCost.failure":           "AsP (misslungen): %d",
"modifications":            "Modifikationen",
"modifications.section":    "Modifikationen & Erschwernisse",
"mod.reduceCastingTime":    "Zauberdauer senken",
"mod.increaseCastingTime":  "Zauberdauer erhöhen",
"mod.increaseRange":        "Reichweite erhöhen",
"mod.reduceCost":           "Kosten senken",
"mod.force":                "Erzwingen",
"mod.omitGesture":          "Ohne Geste",
"mod.omitFormula":          "Ohne Formel",
"mod.foreignTradition":     "Fremde Tradition",
"mod.maintainedSpells":     "Aufrechterhaltene Zauber",
"mod.ironCarried":          "Eisen (Stein)",
"mod.distraction":          "Ablenkung",
"mod.distraction.none":     "Keine",
"mod.distraction.minor":    "Leicht (+3)",
"mod.distraction.ship":     "Schiff (±0)",
"mod.distraction.freefall": "Freier Fall (−3)",
"maxModifications":         "Max. Modifikationen: %d",
"concentrationCheck":       "Selbstbeherrschung-Probe nötig",
```

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add magic flow localization strings"
```

---

### Task 12: SpellProbeModal (standalone magic check)

**Files:**
- Create: `Hesindion/Views/SpellProbeModal.swift`

**Step 1: Create SpellProbeModal**

Create `Hesindion/Views/SpellProbeModal.swift`. This is an expandable modal that wraps `SkillCheckModal`:

```swift
import SwiftUI
import SwiftData

struct SpellProbeModal: View {
    let spell: HeroSpell
    let hero: Hero
    let isLiturgy: Bool
    var onDismiss: () -> Void
    var onResult: ((SkillCheckResult) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    // Collapsible section
    @State private var expanded = false

    // Situational modifier toggles
    @State private var maintainedCount = 0
    @State private var omitGesture = false
    @State private var omitFormula = false
    @State private var foreignTradition = false
    @State private var ironStein = 0
    @State private var distractionLevel = 0
    @State private var modifications: [SpellModification] = []

    private var maxModifications: Int {
        spell.value / 4
    }

    private var domain: CheckDomain {
        isLiturgy ? .liturgyCasting : .spellCasting
    }

    private var modifierLines: [ModifierLine] {
        var ctx = ModifierContext(hero: hero, domain: domain)
        ctx.maintainedSpellCount = maintainedCount
        ctx.foreignTradition = foreignTradition
        ctx.omitGesture = omitGesture
        ctx.omitFormula = omitFormula
        ctx.ironSteinCarried = ironStein
        ctx.distractionLevel = distractionLevel
        ctx.spellModifications = modifications
        return ModifierEngine.shared.evaluate(context: ctx)
    }

    private var spellDetail: SpellDetail? {
        RulesDatabase.shared.lookupSpellDetail(ruleId: spell.ruleId)
    }

    private var checkAttributes: [(key: String, value: Int)] {
        guard let detail = spellDetail, let attrs = hero.attributes else { return [] }
        let keys = [detail.checkAttr1, detail.checkAttr2, detail.checkAttr3].compactMap { $0 }
        return keys.map { key in
            (key: key, value: attrs.value(for: key))
        }
    }

    var body: some View {
        // Modal overlay structure matching TalentProbeModal
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Collapsible modifications section
                if expanded {
                    modificationsSection
                }

                // Toggle expand button
                Button { expanded.toggle() } label: {
                    HStack {
                        Text(L("modifications.section"))
                            .font(.system(.caption, weight: .bold))
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Modifier summary
                if !modifierLines.isEmpty {
                    modifierSummary
                }

                // Delegate to SkillCheckModal
                SkillCheckModal(
                    config: SkillCheckConfig(
                        title: isLiturgy ? L("liturgyProbe") : L("spellProbe"),
                        name: spell.name,
                        skillValue: spell.value,
                        checkAttributes: checkAttributes,
                        accentColor: .groupMagic,
                        modifierLines: modifierLines,
                        logKind: isLiturgy ? "liturgyCheck" : "spellCheck"
                    ),
                    hero: hero,
                    onDismiss: onDismiss,
                    onResult: { result in
                        deductAE(result: result)
                        onResult?(result)
                    }
                )
            }
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
            .frame(maxWidth: 400)
            .padding(24)
        }
    }

    // Build the modifications section with toggles, steppers, pickers
    // (implementation details: maintained spell stepper, iron stepper,
    //  gesture/formula toggles, foreign tradition toggle, distraction picker,
    //  spell modification chips)
}
```

The `modificationsSection`, `modifierSummary`, and `deductAE()` helper need full implementation during this task. The `deductAE` method should:
- On success: deduct full AE cost (parsed from `spellDetail.aeCostShort`)
- On failure: deduct 50% AE cost
- On critical success: deduct 50% AE cost
- Update `hero.derivedValues.astralenergie.current` (or `karmaenergie` for liturgies)

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Views/SpellProbeModal.swift
git commit -m "feat: add SpellProbeModal with modifications and AE deduction"
```

---

### Task 13: Wire SpellProbeModal into hero spell list

**Files:**
- Modify: the view that displays hero spells (likely in hero detail or a spell list view — find via `HeroSpell` usage in views)

**Step 1: Find where spells are displayed**

```bash
# Find views that reference HeroSpell or hero.spells
grep -rn "HeroSpell\|hero\.spells\|hero\.liturgies" Hesindion/Views/
```

**Step 2: Add tap gesture to open SpellProbeModal**

Add a `.sheet` or modal overlay triggered by tapping a spell row, presenting `SpellProbeModal(spell:hero:isLiturgy:onDismiss:)`.

**Step 3: Verify it compiles and test manually**

```bash
make build
```

Test: open hero with spells, tap a spell, verify modal appears with modifications section.

**Step 4: Commit**

```bash
git add <modified-view-file>
git commit -m "feat: wire SpellProbeModal into hero spell list"
```

---

### Task 14: Combat spell steps — CombatStep + CombatView routing

**Files:**
- Modify: `Hesindion/Views/CombatView.swift:10-57`

**Step 1: Add new CombatStep cases**

Add after `case fernkampfExecution(...)` (line 29):

```swift
case spellSelection
case spellSetup(spell: HeroSpell)
case spellCasting(spell: HeroSpell, startRound: Int, totalRounds: Int, modifierLines: [ModifierLine])
case spellExecution(spell: HeroSpell, modifierLines: [ModifierLine])
```

**Step 2: Update persistenceKey**

Add cases in the `persistenceKey` switch:

```swift
case .spellSelection: "spellSelection"
case .spellSetup: "spellSetup"
case .spellCasting: "spellCasting"
case .spellExecution: "spellExecution"
```

**Step 3: Update CombatView body switch**

Add routing in the main body switch to the new views (created in Tasks 15-16):

```swift
case .spellSelection:
    CombatSpellSelectionView(hero: hero, step: $step, onDismiss: onDismiss)
        .transition(.move(edge: .trailing))
case .spellSetup(let spell):
    CombatSpellSetupView(hero: hero, spell: spell, step: $step, roundNumber: roundNumber, mountedActive: mountedActive, schipIgnoreZustandThisRound: schipIgnoreZustandThisRound, onDismiss: onDismiss)
        .transition(.move(edge: .trailing))
case .spellCasting(let spell, let startRound, let totalRounds, let modifierLines):
    // Handled via banner on combat root — see Task 16
    CombatRootView(/* existing params */)
case .spellExecution(let spell, let modifierLines):
    CombatSpellExecutionView(hero: hero, spell: spell, modifierLines: modifierLines, step: $step, onDismiss: onDismiss)
        .transition(.move(edge: .trailing))
```

**Step 4: Verify it compiles**

```bash
make build
```

Will fail until Tasks 15-16 create the views — that's expected. Commit anyway with stub views if needed.

**Step 5: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add spell combat steps to CombatStep enum"
```

---

### Task 15: CombatSpellSelectionView and CombatSpellSetupView

**Files:**
- Create: `Hesindion/Views/CombatSpellViews.swift`

**Step 1: Create spell selection and setup views**

Create `Hesindion/Views/CombatSpellViews.swift` with:

**CombatSpellSelectionView:** Lists hero's spells. Tapping one transitions to `.spellSetup(spell:)`.

**CombatSpellSetupView:** Similar to `SpellProbeModal`'s modifications section but inline (not modal). Shows:
- Spell name, check attrs, FW
- Modification toggles
- Situational modifier toggles
- "Continue" button that:
  - For 1-action spells: transitions to `.spellExecution(spell:, modifierLines:)`
  - For multi-action spells: transitions to `.spellCasting(spell:, startRound:, totalRounds:, modifierLines:)`

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatSpellViews.swift
git commit -m "feat: add combat spell selection and setup views"
```

---

### Task 16: Multi-round casting banner and CombatSpellExecutionView

**Files:**
- Modify: `Hesindion/Views/CombatRootView.swift`
- Create: (append to) `Hesindion/Views/CombatSpellViews.swift`

**Step 1: Add casting banner to CombatRootView**

In the combat root body, add a persistent banner when the current step is `.spellCasting`:

```swift
// Above the AKTION section
if case .spellCasting(let spell, let startRound, let totalRounds, let modifierLines) = step {
    let currentCastRound = roundNumber - startRound + 1
    CombatCastingBanner(
        spellName: spell.name,
        currentRound: currentCastRound,
        totalRounds: totalRounds,
        onContinue: {
            if currentCastRound >= totalRounds {
                step = .spellExecution(spell: spell, modifierLines: modifierLines)
            }
            // Otherwise round advances normally via round tracker
        },
        onAbort: {
            // Deduct full AE cost, return to root
            step = .root
        }
    )
}
```

Disable the Attack button when casting is in progress.

**Step 2: Create CombatSpellExecutionView**

Append to `Hesindion/Views/CombatSpellViews.swift`:

This view shows the 3d20 spell check using `SkillCheckModal` (embedded, not as a separate modal). After the check:
- Deducts AE based on result
- Shows result
- Returns to `.root`

**Step 3: Verify it compiles**

```bash
make build
```

**Step 4: Commit**

```bash
git add Hesindion/Views/CombatRootView.swift Hesindion/Views/CombatSpellViews.swift
git commit -m "feat: add multi-round casting banner and spell execution view"
```

---

### Task 17: Add "Zaubern" button to combat root

**Files:**
- Modify: `Hesindion/Views/CombatRootView.swift:298-356`

**Step 1: Add Zaubern button after Fernkampf**

In the AKTION section (around line 340), after the Fernkampf button, add:

```swift
// Zaubern (only if hero has AE)
if let ae = hero.derivedValues?.astralenergie, ae.max > 0 {
    Button {
        step = .spellSelection
    } label: {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
            Text(L("castSpell"))
        }
        .font(.system(.title3, weight: .black))
        .foregroundStyle(combatAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(combatAccent, lineWidth: 3))
    }
    .buttonStyle(.plain)
    .disabled(isCurrentlyCasting) // disable during multi-round casting
}
```

Add a computed property:
```swift
private var isCurrentlyCasting: Bool {
    if case .spellCasting = step { return true }
    return false
}
```

**Step 2: Verify it compiles and test**

```bash
make build
```

Test: start combat with a hero that has AE, verify "Zaubern" button appears.

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatRootView.swift
git commit -m "feat: add Zaubern button to combat root"
```

---

### Task 18: Effects scraper script

**Files:**
- Create: `scripts/scrape_effects/scrape_effects.py`
- Create: `scripts/scrape_effects/requirements.txt`

**Step 1: Create the scraper**

Create `scripts/scrape_effects/scrape_effects.py`. This script:

1. Fetches special ability pages from `dsa.ulisses-regelwiki.de`
2. Parses HTML to extract mechanical effects (modifier type, attribute, value, scope)
3. Outputs YAML matching the `effects` table schema:

```yaml
# Output format
- rule_id: SA_48
  effects:
    - level: 1
      type: modifier
      attribute: at
      value: -1
      scope: meleeAttack
    - level: 2
      type: modifier
      attribute: at
      value: -2
      scope: meleeAttack
```

Target categories to scrape:
- Combat special abilities (Kampfsonderfertigkeiten)
- General special abilities with mechanical effects
- Advantages/disadvantages with combat/magic modifiers

Use `requests` + `beautifulsoup4` for scraping.

**Step 2: Create requirements.txt**

```
requests>=2.31
beautifulsoup4>=4.12
pyyaml>=6.0
```

**Step 3: Test the scraper**

```bash
cd scripts/scrape_effects
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 scrape_effects.py --output effects.yaml
```

Verify output YAML has correctly structured effects.

**Step 4: Commit**

```bash
git add scripts/scrape_effects/scrape_effects.py scripts/scrape_effects/requirements.txt
git commit -m "feat: add effects scraper for ulisses-regelwiki.de"
```

---

### Task 19: Integrate scraped effects into build_db.py

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Update import_effects() to read scraped YAML**

The `--effects` flag already exists. Ensure `import_effects()` correctly reads the YAML output from the scraper and inserts into the `effects` table with proper `scope` values that map to `CheckDomain`.

**Step 2: Rebuild rules.db**

```bash
cd scripts/build_rules_db
source venv/bin/activate
python3 build_db.py --source /path/to/dsa_companion_data/Data/ --effects ../scrape_effects/effects.yaml --output ../../Hesindion/Resources/rules.db
```

**Step 3: Verify effects are populated**

```bash
sqlite3 Hesindion/Resources/rules.db "SELECT COUNT(*) FROM effects WHERE scope IS NOT NULL"
```

Should return a non-zero count.

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: integrate scraped effects into rules.db build"
```

---

### Task 20: RuleEffectModifiers loader

**Files:**
- Create: `Hesindion/Engine/RuleEffectModifiers.swift`

**Step 1: Create the DB effect loader**

Create `Hesindion/Engine/RuleEffectModifiers.swift`:

```swift
import Foundation

enum RuleEffectModifiers {
    /// Load ModifierDefinitions from the effects table in rules.db.
    /// Only loads effects with a non-nil scope that maps to a CheckDomain.
    static func load(for hero: Hero) -> [ModifierDefinition] {
        var defs: [ModifierDefinition] = []

        // Collect all rule IDs from hero's special abilities, advantages, disadvantages
        let ruleIds = hero.combatSpecialAbilities.map(\.ruleId)
            + hero.generalSpecialAbilities.map(\.ruleId)
            + hero.advantages.map(\.ruleId)
            + hero.disadvantages.map(\.ruleId)

        for ruleId in ruleIds {
            let effects = RulesDatabase.shared.lookupEffects(ruleId: ruleId)
            for effect in effects where effect.scope != nil {
                guard let domains = domainsForScope(effect.scope!) else { continue }
                guard let value = effect.value.flatMap({ Int($0) }) else { continue }

                let def = ModifierDefinition(
                    id: "\(ruleId)_\(effect.type)_\(effect.attribute ?? "none")",
                    domains: domains
                ) { ctx in
                    // Check if this effect's level matches the hero's tier
                    let heroTier = hero.tierForRule(ruleId)
                    if let effectLevel = effect.level, effectLevel != heroTier { return nil }

                    return ModifierLine(
                        value: value,
                        source: RulesDatabase.shared.lookupByName(ruleId)?.name ?? ruleId
                    )
                }
                defs.append(def)
            }
        }

        return defs
    }

    private static func domainsForScope(_ scope: String) -> Set<CheckDomain>? {
        switch scope {
        case "meleeAttack":    return [.meleeAttack]
        case "meleeDefense":   return [.meleeParry, .meleeDodge]
        case "combat":         return [.meleeAttack, .meleeParry, .meleeDodge]
        case "ranged":         return [.rangedAttack]
        case "magic":          return [.spellCasting]
        case "liturgy":        return [.liturgyCasting]
        case "all":            return Set(CheckDomain.allCases)
        default:               return nil
        }
    }
}
```

**Note:** `hero.tierForRule()` may need to be added as a helper on `Hero` that looks up the tier for a given ruleId across advantages, disadvantages, and special abilities.

**Step 2: Verify it compiles**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Engine/RuleEffectModifiers.swift
git commit -m "feat: add RuleEffectModifiers loader for DB-sourced effects"
```

---

### Task 21: Update CHANGELOG.md and architecture docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `AGENTS.md` (if architecture section exists)

**Step 1: Update CHANGELOG.md**

Add under `[Unreleased]`:

```markdown
### Added
- Generic ModifierEngine for unified modifier calculation across all domains
- Magic casting flow — standalone SpellProbeModal and combat integration
- Multi-round spell casting with round tracking in combat
- "Zaubern" action in combat for heroes with Astralenergie
- SkillCheckModal — unified 3d20 skill check UI for talents and spells
- Magic-specific modifiers: maintained spells, foreign tradition, gestures, iron ban, distraction
- Effects scraper for populating rule effects from ulisses-regelwiki.de
- DB-sourced rule effect modifiers (RuleEffectModifiers)

### Changed
- Melee attack, defense, and ranged modifiers now use ModifierEngine instead of hardcoded logic
- TalentProbeModal refactored to use generic SkillCheckModal
- CheckDomain split: meleeParry and meleeDodge replace single meleeDefense
```

**Step 2: Commit**

```bash
git add CHANGELOG.md AGENTS.md
git commit -m "docs: update changelog and architecture for modifier engine"
```

---

## Task Dependencies

```
Task 0 (core types)
  └── Task 1 (shared modifiers)
  └── Task 5 (magic modifiers)
        └── Task 6 (wire shared)
              ├── Task 7 (migrate melee)
              ├── Task 8 (migrate defense)
              ├── Task 9 (migrate ranged)
              └── Task 12 (SpellProbeModal)
                    └── Task 13 (wire into spell list)
  └── Task 2 (melee modifiers)  → Task 6
  └── Task 3 (defense modifiers) → Task 6
  └── Task 4 (ranged modifiers)  → Task 6
  └── Task 10 (SkillCheckModal) → Task 12
  └── Task 11 (magic strings)   → Task 12
  └── Task 14 (combat steps)
        └── Task 15 (spell selection/setup views)
              └── Task 16 (casting banner + execution)
                    └── Task 17 (Zaubern button)
  └── Task 18 (scraper) → Task 19 (integrate into build_db)
        └── Task 20 (RuleEffectModifiers loader)
  └── Task 21 (docs) — after all others
```
