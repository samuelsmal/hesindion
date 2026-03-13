# Combat Maneuvers, Schmerz, and Mounted Combat Design

**Date:** 2026-03-13
**Status:** Approved

## Overview

Extend the combat system with combat maneuvers (Finte, Wuchtschlag, Vorstoß, Schildspalter, Sturmangriff), pain tracking (Schmerz), mounted combat, formation support (Plänkler-Formation), and mount attacks. Add contextual reminders for Aufmerksamkeit when rolling Sinnenschärfe.

## Scope — Boronmir's Abilities

| Ability | ID | Type |
|---------|-----|------|
| Finte I | SA_48 | Combat maneuver |
| Wuchtschlag I | SA_67 | Combat maneuver |
| Vorstoß | SA_66 | Combat maneuver |
| Schildspalter | SA_59 | Combat maneuver |
| Berittener Kampf | SA_43 | Mounted combat |
| Golgariten-Stil | SA_661 | Combat style (passive) |
| Plänkler-Formation | SA_884 | Formation |
| Aufmerksamkeit | SA_40 | Passive |
| Zäher Hund | ADV_49 | Advantage |

## Section 1: Schmerz (Pain) — Hero Model

Computed property on Hero, available globally (combat, talent probes, everywhere).

**Thresholds (from DSA 5 core rules):**
- Stufe I: LP ≤ 75% of max → all checks -1, GS -1
- Stufe II: LP ≤ 50% of max → all checks -2, GS -2
- Stufe III: LP ≤ 25% of max → all checks -3, GS -3
- Extra level: LP ≤ 5 → one additional Stufe
- Stufe IV: incapacitated (all checks -4 if somehow acting)

**Zäher Hund (ADV_49):** Reduces effective pain level by 1. Does NOT help at Stufe IV.

```swift
var schmerzLevel: Int {
    guard let dv = derivedValues else { return 0 }
    let current = dv.lebensenergie.current
    let max = dv.lebensenergie.max
    guard max > 0 else { return 0 }
    var level = 0
    if current <= (max * 3) / 4 { level = 1 }
    if current <= max / 2 { level = 2 }
    if current <= max / 4 { level = 3 }
    if current <= 5 { level += 1 }
    return level
}

var hasZaeherHund: Bool {
    advantages.contains { $0.ruleId == "ADV_49" }
}

var effectiveSchmerzLevel: Int {
    let raw = schmerzLevel
    if raw >= 4 { return 4 }
    return hasZaeherHund ? max(0, raw - 1) : raw
}

var schmerzPenalty: Int { -effectiveSchmerzLevel }
```

**Usage points:**
- Combat execution view: AT/PA/AW modifier breakdown
- TalentProbeModal: auto-applied penalty to all checks
- LP bar in combat: shows current Schmerz level indicator

## Section 2: Combat Setup — Plänkler-Formation & Mounted Toggle

New step between armor selection and initiative roll. Skipped if hero has neither SA_884 nor a mount.

**State persists for entire combat** (reset on new combat, not per round):
```swift
@State private var plaenklerActive: Bool = false
@State private var plaenklerBonus: PlaenklerBonus = .at  // .at or .aw
@State private var mountedActive: Bool = false
```

**Plänkler-Formation (SA_884):** Toggle + radio group for +1 AT or +1 AW. Only shown if hero has SA_884.

**Beritten toggle:** Only shown if hero has a mount (pet with initiative). When active, cascading effects apply (see Section 6).

**Flow:** `armorSelection → combatSetup → initiativeRoll → ...`

## Section 3: Attack Announcement — Maneuver Selection

New step between attack choice (dual-wield/grip) and execution. Always shown for attacks.

Available maneuvers derived from `hero.combatSpecialAbilities`:

| Maneuver | Rule ID | AT Mod | Extra Effect |
|----------|---------|--------|--------------|
| Normal | — | 0 | — |
| Finte I | SA_48 | -1 | Opponent PA -2 (info) |
| Wuchtschlag I | SA_67 | -2 | Damage +2 |
| Vorstoß | SA_66 | +2 | No defense this round |
| Schildspalter | SA_59 | 0 | Damage targets shield STP |
| Sturmangriff | SA_43 | 0 | Damage +2+(GS/2), mounted only |

**Screen layout:** Vorteilhafte Position toggle at top, then radio group of available maneuvers with AT modifier and effect description.

**Data passed to execution:**
```swift
struct AttackAnnouncement {
    var vorteilhaftePosition: Bool = false
    var maneuver: CombatManeuver = .normal
}

enum CombatManeuver: Equatable {
    case normal
    case finte(tier: Int)
    case wuchtschlag(tier: Int)
    case vorstoss
    case schildspalter
    case sturmangriff
}
```

**Vorstoß side effect:** Disables Parieren and Ausweichen on CombatRootView for remainder of round.
```swift
@State private var vorstossActiveThisRound: Bool = false
```

**Sturmangriff:** Only appears when `mountedActive == true` and hero has SA_43.

## Section 4: Enhanced Execution Screen — Modifier Breakdown

Replaces the single AT value box with a labeled breakdown. Each modifier line shows source.

```
AT 12         Basis
-1            Belastung
-1            Schmerz I
+2            Vorteilh.Pos
-1            Finte I
+1            Plänkler
+2            Golgariten
───────────────────────
AT 14         Effektiv
```

**Modifier data structure:**
```swift
struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
}
```

**Changes from current execution view:**
1. Vorteilhafte Position toggle removed (moved to announcement)
2. Modifier breakdown replaces single AT box
3. Manual modifier stepper stays, labeled "Zusätzlich"
4. Maneuver reminder at bottom for GM-facing info (e.g. "Finte: Gegner PA -2")
5. Wuchtschlag damage bonus shown in damage calculation
6. Defense breakdown uses same pattern (PA basis + shield + belastung + schmerz + golgariten)

## Section 5: Aufmerksamkeit & Talent Probe Integration

**TalentProbeModal changes:**
1. Schmerz penalty auto-applied to all three attribute checks, shown as labeled non-editable line
2. Aufmerksamkeit reminder shown only for Sinnenschärfe (TAL_8) when hero has SA_40 — informational hint box, not a modifier

```swift
var hasAufmerksamkeit: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_40" }
}
```

## Section 6: Golgariten-Stil & Mounted Combat

**Mounted combat baseline** (when `mountedActive == true`):
- Initiative: use horse's INI base (already supported)
- BE: effective BE reduced by 1 (stacks with Belastungsgewöhnung)
- Ausweichen: always -2 penalty
- Two-handed weapons: disabled in loadout
- Shields: only block front + shield-arm side (info reminder)

**Golgariten-Stil (SA_661) conditions:**
1. Hero has SA_661
2. `mountedActive == true`
3. Loadout: Rabenschnabel (weapon) AND Großschild (shield)

**Golgariten bonuses when all conditions met:**
- AT: automatic Vorteilhafte Position +2 (non-toggleable) PLUS additional +2 from Golgariten = +4 AT total
- PA: +1

When Golgariten active, the Vorteilhafte Position toggle in announcement is replaced by a non-editable label — it's automatic.

```swift
var hasGolgaritenStil: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_661" }
}

func golgaritenActive(mounted: Bool) -> Bool {
    guard mounted, hasGolgaritenStil else { return false }
    let hasRabenschnabel = selectedWeapon?.name == "Rabenschnabel"
    let hasGrossschild = selectedShield?.name == "Großschild"
    return hasRabenschnabel && hasGrossschild
}
```

**Berittener Kampf (SA_43):** Enables Sturmangriff maneuver. Damage: +2 + (horse GS / 2).

```swift
var hasBerittenerKampf: Bool {
    combatSpecialAbilities.contains { $0.ruleId == "SA_43" }
}

var mountGS: Int {
    pets.first.flatMap { Int($0.speed) } ?? 0
}

var sturmangriffDamageBonus: Int {
    2 + (mountGS / 2)
}
```

## Section 7: Mount Attacks

When mounted, the hero can use their action for a mount attack. New section on Combat Root screen.

**Mount attacks parsed from Pet `notes` field** at import time. Pattern: `Name: AT \d+ TP \d+W\d+[+-]\d+ RW (kurz|mittel|lang)`.

```swift
struct PetAttack: Codable, Hashable {
    var name: String      // "Tritt", "Biss", "Niederreiten"
    var at: Int           // 15, 12, 15
    var damage: String    // "1W6+7", "1W6+2", "2W6+6"
    var reach: String     // "mittel", "kurz"
}
```

New fields on Pet:
```swift
var attacks: [PetAttack]   // parsed from notes during import
var specialSkills: String  // "Mächtiger Schlag" — kept as info text
```

Mount attack selection goes directly to execution (no announcement step). Rolls against mount's AT with mount's damage formula. Mächtiger Schlag shown as info reminder.

**Kupperus attacks:**
- Tritt: AT 15, TP 1W6+7, RW mittel
- Biss: AT 12, TP 1W6+2, RW kurz
- Niederreiten: AT 15, TP 2W6+6, RW mittel

## Section 8: Complete Flow & Modifier Tables

**Combat flow:**
```
1. Armor Selection          (existing)
2. Combat Setup             (NEW — Plänkler, Beritten toggles)
3. Initiative Roll          (existing, auto-selects mount INI if beritten)
4. Loadout                  (existing, two-handed greyed out if mounted)
5. Combat Root              (enhanced — mount attacks, Vorstoß defense lock)
6. Attack Choice            (existing — dual-wield/grip, skipped if N/A)
7. Announcement             (NEW — Vorteilhafte Position + maneuver)
8. Execution                (enhanced — modifier breakdown with sources)
```

**AT modifier sources:**

| Source | Value | Condition |
|--------|-------|-----------|
| Basis | weapon AT | always |
| Belastung | -effectiveBE (+1 if mounted) | if BE > 0 |
| Schmerz | -1 to -4 | LP below thresholds |
| Vorteilhafte Position | +2 | toggled or auto (Golgariten mounted) |
| Golgariten-Stil | +2 | mounted + Rabenschnabel + Großschild |
| Plänkler-Formation | +1 | active + AT chosen |
| Finte I | -1 | maneuver |
| Wuchtschlag I | -2 | maneuver |
| Vorstoß | +2 | maneuver |
| Sturmangriff | 0 | maneuver (damage only) |
| Beidhand. Angriff | -2 (reduced by SA) | dual attack |
| Nebenhand | -4 (0 if Beidhändig) | off-hand weapon |
| Zusätzlich | manual | player stepper |

**PA/AW modifier sources:**

| Source | Value | Condition |
|--------|-------|-----------|
| Basis | weapon PA or AW | always |
| Großschild | +3 PA | shield equipped |
| Belastung | -effectiveBE (+1 if mounted) | if BE > 0 |
| Schmerz | -1 to -4 | LP below thresholds |
| Golgariten-Stil | +1 PA | mounted + Rabenschnabel + Großschild |
| Plänkler-Formation | +1 AW | active + AW chosen |
| Beritten (AW) | -2 | mounted, Ausweichen only |
| Vorstoß | disabled | declared this round |
| Beidhand. Angriff | -2 (reduced by SA) | dual attack |
| Zusätzlich | manual | player stepper |

**Damage modifiers:**

| Source | Value | Condition |
|--------|-------|-----------|
| Weapon formula | e.g. 1W6+4 | always |
| Wuchtschlag I | +2 | maneuver |
| Sturmangriff | +2+(GS/2) | mounted maneuver |
| Two-handed grip | +1 | grip choice |

**New/modified files:**
- `Hero.swift` — Schmerz properties, maneuver helpers, Golgariten logic
- `Pet.swift` — `PetAttack` struct, `attacks` array
- `CombatView.swift` — combat setup step, announcement step, enhanced execution, mount attacks, Vorstoß defense lock
- `TalentProbeModal.swift` — Schmerz penalty, Aufmerksamkeit reminder
- `OptolithImportService.swift` — parse pet attacks from notes
- `Localizable.strings` — maneuver names, labels, reminders
