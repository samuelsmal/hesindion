# Overview of spec 011_trefferzonen

Implements the DSA 5 **Fokus-Regeln: Trefferzonen**
(<https://dsa.ulisses-regelwiki.de/Fokus_TrefferzonenRegeln.html>) — optional focus rules that
localise every hit to a body zone and turn heavy damage into concrete impairments.

The app is hero-centric: only the hero has LP, KO and states. No opponent is modelled. The rules
therefore land **asymmetrically**, and this asymmetry is the central design decision of the spec:

| Side | What the app does |
|------|-------------------|
| Hero **attacks** (Nahkampf / Fernkampf) | Zone picker feeds the *Zonenaufschlag* into the `ModifierEngine` as a `ModifierLine`. After a landed hit, a read-only reminder card states that zone's wound effect for the GM. Nothing is applied — there is no opponent to apply it to. |
| Hero **takes damage** (`takeDamage`) | Zone is rolled or tapped, damage is compared against the hero's Wundschwelle, a Selbstbeherrschung probe resists, and on failure the effect is applied for real via `Hero.setStateLevel(_:level:)`. |

Trefferzonen are **optional** rules. Everything in this spec sits behind a per-combat toggle
(see *Activation*) and is off by default; with it off, combat behaves exactly as it does today.


# Rules Model

Three new pure-value files under `Hesindion/Models/`. They contain no SwiftUI and no SwiftData,
which keeps them portable to the Flutter rewrite as a near-mechanical translation. `FumbleTable.swift`
is the pattern to follow: a `static func lookup(...)` over private static table arrays.

## `HitZone.swift`

```swift
enum HitZone: String, CaseIterable, Identifiable {
    case kopf, torso, arme, beine
    case vordereBeine, mittlereGliedmassen, hintereBeine, schwanz
    case fangarme, koerper

    var id: String { rawValue }

    /// L() key for the display name.
    var nameKey: String { "hitZone.\(rawValue)" }

    /// True for zones that exist as a left/right pair.
    var isPaired: Bool {
        switch self {
        case .kopf, .torso, .schwanz: return false
        default: return true
        }
    }
}

enum BodySide: String { case links, rechts }

struct HitZoneHit: Equatable {
    let zone: HitZone
    /// nil for unpaired zones (Kopf, Torso, Schwanz).
    let side: BodySide?
}
```

## `HitZoneTable.swift`

```swift
enum CreatureSize { case klein, mittel, gross, riesig }

enum BodyPlan: Equatable {
    case humanoid(CreatureSize)              // klein, mittel, gross
    case vierbeinig(CreatureSize)            // klein, mittel, gross
    case sechsbeinigMitSchwanz(CreatureSize) // gross, riesig
    case fangarme(CreatureSize)              // mittel bis riesig
    case keineZonen                          // one table, no size variants
}

enum HitZoneTable {
    /// Resolve a 1W20 roll against a body plan.
    /// Odd rolls hit the left side, even rolls the right (unpaired zones report nil).
    static func lookup(_ roll: Int, plan: BodyPlan) -> HitZoneHit
}
```

- `roll` is clamped to `1...20` before lookup, mirroring `FumbleTable.lookup`'s clamping.
- Side rule: `roll.isMultiple(of: 2) ? .rechts : .links`, and `nil` when `!zone.isPaired`.
- Unlisted `BodyPlan` size combinations (e.g. `.sechsbeinigMitSchwanz(.klein)`) fall back to the
  nearest listed size rather than trapping. Document the fallback in the table's doc comment.

### Zone tables (1W20)

**Humanoid**

| Größe | Kopf | Torso | Arme | Beine |
|-------|------|-------|------|-------|
| klein  | 1–6 | 7–10 | 11–18 | 19–20 |
| mittel | 1–2 | 3–12 | 13–16 | 17–20 |
| groß   | 1–2 | 3–6  | 7–16  | 17–20 |

**Vierbeinig**

| Größe | Kopf | Torso | vordere Beine | hintere Beine |
|-------|------|-------|---------------|---------------|
| klein  | 1–4 | 5–12 | 13–16 | 17–20 |
| mittel | 1–4 | 5–10 | 11–16 | 17–20 |
| groß   | 1–5 | 6–11 | 12–16 | 17–20 |

**Sechsbeinig mit Schwanz**

| Größe  | Kopf | Torso | vordere | mittlere | hintere | Schwanz |
|--------|------|-------|---------|----------|---------|---------|
| groß   | 1–4 | 5–12 | 13–14 | 15–16 | 17–18 | 19–20 |
| riesig | 1–2 | 3–10 | 11–14 | 15–16 | 17–18 | 19–20 |

**Fangarme** (mittel bis riesig, z. B. Krakenmolch)

| Kopf | Torso | Fangarme |
|------|-------|----------|
| 3–6  | 1–2   | 7–20     |

**Keine unterschiedlichen Zonen** (z. B. Riesenamöbe) — 1–20 Körper.

The source publishes **ten** tables and all ten are implemented. Two are irregular, and are called
out here so a later "tidy-up" cannot silently normalise them:

- **Fangarme puts Torso (1–2) before Kopf (3–6)** — the only table where that order holds. It is not
  a transcription slip, and a test pins it.
- The rules add *"Der Rest der Zahlen verteilt sich gleichmäßig auf die Fangarme, Überschüsse werden
  auf den Torso aufgeschlagen"*. How 7–20 divides across a creature's tentacles depends on how many
  it has — per-creature GM adjudication — so the whole band resolves to one `.fangarme` zone.
- `keineZonen` has no size variants, so its `BodyPlan` case carries no `CreatureSize`.
- `fangarme` and `koerper` are unpaired: no left/right side.

The hero always uses `.humanoid(.mittel)`. The other plans exist for the *defence-side* zone picker
when the hero is something other than a mid-sized humanoid, and as the reference table the GM reads
off for opponents.

## `WoundEffect.swift`

```swift
/// What a zone does when damage meets the Wundschwelle.
enum WoundEffectKind: Equatable {
    /// Raise a leveled Zustand by one step (Kopf → betaeubung).
    case raiseState(id: String)
    /// Set a binary Status (Beine → liegend).
    case setStatus(id: String)
    /// Additional dice damage on top of the hit (Torso → 1W3+1 SP).
    case extraDamage(count: Int, sides: Int, flat: Int)
    /// No automatic math — the app shows the text and offers an action (Arme → drop item).
    case reminder
}

struct WoundEffect: Equatable {
    let zone: HitZone
    let kind: WoundEffectKind
    /// L() key for the effect description.
    let effectKey: String
    /// L() key naming the Selbstbeherrschung Anwendungsgebiet that resists it.
    let resistanceKey: String
}

enum WoundEffectCatalog {
    static func effect(for zone: HitZone) -> WoundEffect
}
```

### Wundeffekt table

| Zone | Effekt | Probe (Selbstbeherrschung) | `WoundEffectKind` |
|------|--------|---------------------------|-------------------|
| Kopf | Eine Stufe Betäubung | Handlungsfähigkeit bewahren | `.raiseState(id: "betaeubung")` |
| Torso | Zusätzlich 1W3+1 SP | Handlungsfähigkeit bewahren | `.extraDamage(count: 1, sides: 3, flat: 1)` |
| Arme | Einhändig geführte Gegenstände fallen zu Boden | Störungen ignorieren | `.reminder` |
| Beine | Der Getroffene stürzt zu Boden | Störungen ignorieren | `.setStatus(id: "liegend")` |

- `vordereBeine` and `hintereBeine` map to the **Beine** effect (the creature falls).
- `mittlereGliedmassen` maps to the **Arme** effect — a mid-limb is a manipulator, not a leg, so
  dropping what it holds is the closer analogue. The rules define no effect for it; this is an
  explicit extrapolation, and it only ever applies to opponents.
- `schwanz` maps to `.reminder` — the rules define no effect for it either.
- `"betaeubung"` and `"liegend"` are existing `StateCatalog` ids; no catalog changes are needed.


# Activation

Trefferzonen are optional rules and must not change existing combat unless switched on.

Groups play with different subsets of the Fokus-Regeln, so activation is **per rule**, not one
switch for "Fokus-Regeln on". The mechanism is built once here and every later Fokus rule costs one
enum case plus two localized strings.

- Add `Hesindion/Models/FokusRule.swift`:

```swift
/// Optional DSA 5 Fokus-Regeln. Each is independently switchable per combat, because
/// a group may want hit zones without, say, zone armour.
///
/// Adding a rule: one case here, two `L()` keys, and whatever the rule itself needs.
enum FokusRule: String, CaseIterable, Identifiable {
    case trefferzonen

    var id: String { rawValue }
    var nameKey: String { "fokus.\(rawValue).name" }
    var subtitleKey: String { "fokus.\(rawValue).subtitle" }
}
```

- Add `var fokusRules: [String] = []` to `Hero` as a **persistent per-hero setting**, beside `notes`
  and `colorSchemeId` — NOT in the combat-session block, and NOT reset by `clearCombatSession()`.
  These are the table's house rules — which optional rules this group plays with — so they must
  survive a fight ending.

- Add two helpers on `Hero`:

```swift
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
```

  Storing ids rather than a `Bool` per rule means a rule that is later removed leaves a harmless
  unknown string instead of a dead column, and `FokusRule.allCases` drives the UI with no per-rule
  view code.

- Surface the rules in **`HeroSettingsView`** — the general per-hero settings screen, alongside the
  colour scheme and active adventure — as a "Fokus-Regeln" section with one toggle per
  `FokusRule.allCases`. One `ForEach`, no per-rule view code.
- **Not in the combat flow.** Two earlier placements were wrong and both were my error rather than an
  implementation slip. `combatSetup` is reached only when `hero.needsCombatSetup`
  (`hasPlaenklerFormation || hasMount`), so an ordinary hero never saw the toggles and the feature was
  unreachable — every acceptance criterion passed while the screen was never mounted. Moving them to
  the armour-selection step fixed reachability but kept the wrong lifetime: session-scoped state,
  wiped by `clearCombatSession()`, when the setting is a property of the hero.
- Every UI element in this spec is hidden when `hero.isFokusRuleActive(.trefferzonen)` is false.

**Known future rule.** Trefferzonenrüstung (per-zone RS,
<https://dsa.ulisses-regelwiki.de/Fokus_TreffzonenRS.html>) is a separate work package. It will add a
`trefferzonenRuestung` case here and needs a dependency notion (zone armour is meaningless without
zones), which this spec deliberately does **not** build — there is one rule today, and a
`requires:` graph with a single node is speculation. Note only that the extension point exists.


# Offence: Zonenaufschlag

## `Hesindion/Engine/HitZoneModifiers.swift`

A sibling to `MeleeModifiers.swift` / `RangedModifiers.swift`, producing one `ModifierLine` for the
`ModifierEngine`.

```swift
enum HitZoneModifiers {
    /// Zonenaufschlag for a targeted attack.
    /// - Parameters:
    ///   - zone: the announced target zone
    ///   - hasSonderfertigkeit: hero owns SA_160 (melee) or SA_161 (ranged)
    ///   - targetIsSurprised: GM-driven toggle; the opponent is not modelled
    static func penalty(for zone: HitZone,
                        hasSonderfertigkeit: Bool,
                        targetIsSurprised: Bool) -> Int
}
```

### Base values

| Zone | Aufschlag |
|------|-----------|
| Kopf | −10 |
| Torso | −4 |
| Arme (und alle Gliedmaßen-Zonen) | −8 |
| Beine (vordere / hintere) | −8 |
| Schwanz | −8 * |

\* The rules table lists Kopf, Torso, Arme and Beine only. `mittlereGliedmassen` and `schwanz`
reuse the limb value of −8 by analogy — an explicit extrapolation, flagged here so it is not
mistaken for sourced text.

### Order of operations

1. Start from the base value above.
2. If the hero owns the matching Sonderfertigkeit, **halve** it
   (*"Besitzt ein Held die Sonderfertigkeit Gezielter Angriff bzw. Gezielter Schuss, sind die
   Erschwernisse halbiert."*). All base values are even, so no rounding rule is needed — assert this
   in a test so a future table edit that breaks the property fails loudly.
3. If the target is Überrascht, **reduce the penalty by 2**
   (*"ist die Erschwernis in jeder Zone um 2 gesenkt"*), i.e. move it 2 toward zero.
4. Clamp at `0` — the modifier must never become a bonus.

Worked example: Kopf with SA_160 against a surprised target → `-10 → -5 → -3`.

### Sonderfertigkeit detection

```swift
// Nahkampf — Gezielter Angriff
hero.combatSpecialAbilities.contains { $0.ruleId == "SA_160" }
// Fernkampf — Gezielter Schuss
hero.combatSpecialAbilities.contains { $0.ruleId == "SA_161" }
```

Follows the existing `SA_41` lookup at `Hesindion/Models/Hero.swift:143`.

### Überrascht is a toggle, not a state lookup

`StateCatalog` has a `ueberrascht` status, but it describes the **hero**. The Zonenaufschlag
reduction depends on the **opponent's** status, which the app does not model. It is therefore a
plain `@State` toggle beside the zone picker, reset whenever the picker is opened. Do **not** read
`hero` states for this.

## UI — zone picker

Appears in two places, both already modifier-collection screens:

- `announcement` step (`CombatAttackViews.swift`) — Nahkampf
- `fernkampfSetup` step (`CombatFernkampfViews.swift`) — Fernkampf

```
 ┌──────────────────────────┐
 │  Trefferzone             │
 │ ──────────────────────── │
 │ ┌────┐┌─────┐┌────┐┌────┐│
 │ │Kopf││Torso││Arme││Bein││ ◄── single-select chips, neo-brutalist
 │ │ -10││  -4 ││ -8 ││ -8 ││     live value = HitZoneModifiers.penalty(...)
 │ └────┘└─────┘└────┘└────┘│
 │ ┌──────────────────────┐ │
 │ │ Keine Zone           │ │ ◄── default; contributes no ModifierLine
 │ └──────────────────────┘ │
 │  [x] Ziel ist überrascht │
 │  ⓘ Gezielter Angriff     │ ◄── shown only when SA_160/SA_161 is owned
 │    halbiert die Aufschläge│
 └──────────────────────────┘
```

- Default selection is **Keine Zone** — no zone, no `ModifierLine`, identical to today.
- The number on each chip is live: it already reflects the SF halving and the Überrascht toggle, so
  the user sees the real cost before committing.
- Zone chips use `CheckDomain.meleeAttack` / `.rangedAttack`. The `ModifierLine` label is
  `L("modifier.trefferzone")` plus the zone name, so it appears in the existing modifier breakdown
  and in the log line like every other source.

## After a landed hit — reminder card

When an attack resolves to a hit (`opponentDefense` → Treffer → damage) **and** a zone was announced,
the damage screen shows a read-only card:

```
 ┌──────────────────────────────────┐
 │ ⚠ Trefferzone: Kopf              │
 │ ──────────────────────────────── │
 │ Bei Schaden ≥ Wundschwelle:      │
 │ Eine Stufe Betäubung.            │
 │ Probe: Selbstbeherrschung        │
 │ (Handlungsfähigkeit bewahren)    │
 └──────────────────────────────────┘
```

Text comes from `WoundEffectCatalog.effect(for:)`. It is **informational only** — nothing is applied,
because the opponent has no LP, no KO and no states. The card must read as a GM prompt, not as a
pending action; no buttons.


# Defence: Wundschwelle und Wundeffekte

All of this extends `CombatTakeDamageView` (`Hesindion/Views/CombatDamageViews.swift:6`), which today
computes `effectiveDamage = max(0, tpInput - hero.totalRS)` and applies it to LP on confirm.

## Wireframe

```
 ┌──────────────────────────────────┐
 │ ‹        Schaden nehmen        ✕ │
 │ ──────────────────────────────── │
 │  TP                              │
 │      ▼    12    ▲                │
 │  RS  −4                          │
 │  ────────────────────            │
 │  Schaden            8            │
 │ ──────────────────────────────── │
 │  Trefferzone                     │  ◄── only when trefferzonenEnabled
 │ ┌────┐┌─────┐┌────┐┌────┐┌────┐  │
 │ │Kopf││Torso││Arme││Bein││🎲 1W20│ │  ◄── tap a zone, or tap the die
 │ └────┘└─────┘└────┘└────┘└────┘  │
 │  → 13: Arme (links)              │  ◄── roll result + resolved zone
 │ ──────────────────────────────── │
 │ ⚠ Wundeffekt                     │  ◄── only when damage ≥ Wundschwelle
 │  Schaden 8 ≥ Wundschwelle 6 (×1) │
 │  Einhändig geführte Gegenstände  │
 │  fallen zu Boden.                │
 │  ┌────────────────────────────┐  │
 │  │ Probe: Selbstbeherrschung  │  │
 │  │ (Störungen ignorieren) −1  │  │  ◄── −1 = Wundschwellen-Multiplikator
 │  └────────────────────────────┘  │
 │ ──────────────────────────────── │
 │  ┌────────────────────────────┐  │
 │  │        Bestätigen          │  │
 │  └────────────────────────────┘  │
 └──────────────────────────────────┘
```

## Zone determination

Both inputs are available at all times:

- **Tap a zone** — the GM called it, or it followed from a targeted attack.
- **Tap the die** — roll 1W20 via `DiceRoller.roll(sides: 20)`, resolve through
  `HitZoneTable.lookup(roll, plan: bodyPlan)`, and show both the raw roll and the resolved
  `HitZoneHit` (including side) so the table stays auditable.

`bodyPlan` defaults to `.humanoid(.mittel)`. A compact plan selector is available for the mounted /
non-humanoid case; it is collapsed by default and does not clutter the common path.

Rolling uses the same dice animation as `DiceRollSheet`, and goes through `DiceRoller` — never
`Int.random(in:)` inline — so it stays seedable in tests.

## Threshold and multiplier

```swift
let ws = hero.derivedValues?.wundschwelle.max ?? 0
let multiple = ws > 0 ? effectiveDamage / ws : 0        // integer division
let probeModifier = -multiple
```

- `multiple == 0` → no wound effect; the panel stays hidden and the screen behaves as today.
- `multiple >= 1` → the Wundeffekt panel appears, and the Selbstbeherrschung probe is at
  `-multiple` (*"Multiple der Wundschwelle erhöhen die Erschwernis um den Multiplikator"*).
- Guard `ws > 0`: `wundschwelle` is an imported value and `HeroDetailView.swift:548` already treats
  `max == 0` as "not present". A hero without it never triggers a wound effect.
- `.max` is the field to read, because it is the one that carries the Eisern / Gläsern modifier —
  but only after the import bugs in *Data Model Fixes Required* are fixed. That section is a
  **prerequisite**, not a follow-up: today `wundschwelle` truncates instead of rounding up and
  ignores both traits.

**One effect, harder probe.** Exceeding the threshold *n*-fold does not trigger *n* separate
effects — it triggers one effect whose resistance probe is `−n`. The rules give a worked example:

> *"Bei einer KO von 11 und damit einer Wundschwelle von 6 würde ein Abenteurer also bei 6
> Schadenspunkten eine um 1 erschwerte Probe ablegen müssen, bei 12 eine um 2 erschwerte Probe,
> bei 18 eine um 3 erschwerte Probe."*

Encode that example directly as a test case (`ws = 6`; damage `6 → -1`, `12 → -2`, `18 → -3`).

## Resistance probe

Selbstbeherrschung is already in `TalentProbeAttributes.swift:13` as `["MU", "MU", "KO"]`. Route the
probe through the existing skill-check flow rather than reimplementing 3W20:

- Look up `hero.talents.first { $0.name == "Selbstbeherrschung" }`.
- Selbstbeherrschung is a DSA 5 **basic ability** — every hero has it. There is no "lacks the
  talent" rules case. If the row is somehow absent that is a data anomaly, so fall back to a FW 0
  probe (a Talentprobe can always be attempted) rather than auto-applying the effect.
- An unrolled probe means the GM has not adjudicated, so nothing is applied. That holds uniformly,
  which is what stops declining to roll from being better than rolling.
- Present the probe with the Anwendungsgebiet from `WoundEffect.resistanceKey` and the
  `probeModifier` pre-filled. Schicksalspunkt rerolls come for free from the existing flow.

## Applying the effect on a failed probe

| Zone | Action on failure |
|------|-------------------|
| Kopf | `hero.setStateLevel("betaeubung", level: currentBetaeubung + 1)`, clamped to `4` |
| Beine / vordere / hintere | `hero.setStateLevel("liegend", level: 1)` |
| Torso | Roll `1W3+1` via `DiceRoller.roll(count: 1, sides: 3)` and add it to the LP reduction applied on confirm |
| Arme / mittlere Gliedmaßen | Reminder text plus a **"Waffe ablegen"** button that unequips the currently loadout-equipped one-handed weapon |
| Schwanz | Reminder text only |

- A **successful** probe applies nothing; the panel shows the success outcome and confirm proceeds
  with the unmodified damage.
- Arme is not automated because which hand holds what is not reliably modelled — the button is an
  explicit user action, never implicit.
- The Torso extra damage is folded into the single LP write on confirm, so the hero's LP changes
  exactly once. Do not apply it as a separate mutation.
- All state changes go through `Hero.setStateLevel(_:level:)` (`Hesindion/Models/Hero.swift:277`),
  which owns clamping and the implication chain.

## Logging

Write one `LogEntry` per resolved wound effect, with the same `combatId` / `roundNumber` the view
already receives: the zone and side, the roll if one was made, damage vs. Wundschwelle and the
multiplier, the probe result, and what was applied. One entry, after confirm — not one per step.


# Data Model Fixes Required

Before implementing this spec, fix the following bugs in `Hesindion/Services/OptolithImportService.swift`.

Only the first is a blocker: every wound effect in this spec triggers on a comparison against the
Wundschwelle, so a Wundschwelle that is off by one makes the whole defence side wrong — silently, and
in the hero's favour or against them depending on the hero. Ausweichen and Initiative are the same
bug in the same function and share the repair pass, so they are fixed here rather than left behind;
they are not otherwise related to Trefferzonen.

The project convention is **round up** wherever DSA 5 produces a fraction and the rules do not
clearly say otherwise. All three fixes follow from it. The full sweep that found them is in
`docs/plans/2026-09-10-derived-value-rounding-audit.md`.

## Wundschwelle rounding — `ko / 2` truncates

`computeDerivedValues` currently has (`OptolithImportService.swift:888`):

```swift
// WS = KO / 2
let wsValue = ko / 2                       // integer division — truncates
```

DSA 5 rounds the Wundschwelle **up**. The rules' own worked example is unambiguous: *"Bei einer KO
von 11 und damit einer Wundschwelle von 6"* — `11 / 2` in Swift is `5`, so every hero with an odd KO
currently gets a Wundschwelle one point too low. Fix to match the `ceil` treatment the neighbouring
derived values already use:

```swift
let wsBase = Int(ceil(Double(ko) / 2.0))
```

## Ausweichen and Initiative truncate the same way

Same function, same class of bug, and the same convention applies — neither has a rule carving it out:

```swift
let awValue  = ge / 2              // → Int(ceil(Double(ge) / 2.0))
let iniValue = (mu + ge) / 2       // → Int(ceil(Double(mu + ge) / 2.0))
```

Heroes with odd GE gain +1 AW, and odd `MU + GE` gains +1 INI. Both change rolls at the table, so
both belong in the CHANGELOG as `Fixed`, not buried as an internal correction.

Initiative's *"eventuelle Vor-/Nachteile"* term is separately unimplemented. That is a follow-up and
is **not** in scope here; the rounding fix does not depend on it.

## Eisern / Gläsern are not applied

`wundschwelle` is built with a hardcoded `bonus: 0`:

```swift
let wundschwelle = ComputedValue(value: wsValue, bonus: 0, max: wsValue)
```

Two traits modify it, and neither is referenced anywhere in the codebase:

| Rule | Name | Effect |
|------|------|--------|
| `ADV_54` | Eisern | *"Die Wundschwelle des Helden steigt durch den Vorteil um 1."* |
| `DISADV_56` | Gläsern | *"Die Wundschwelle des Helden sinkt durch den Nachteil um 1."* |

Both are `max: 1` and untiered in `rules.db`, so they apply as a flat ±1 and do not stack. Follow the
pattern `seelenkraft` (`ADV_26`) and `zaehigkeit` (`ADV_27`) already use at
`OptolithImportService.swift:861` and `:870`, but without the tier summation:

```swift
let wsBase  = Int(ceil(Double(ko) / 2.0))
let wsBonus = (advantages.contains    { $0.ruleId == "ADV_54"    } ? 1 : 0)
            + (disadvantages.contains { $0.ruleId == "DISADV_56" } ? -1 : 0)
let wundschwelle = ComputedValue(value: wsBase, bonus: wsBonus, max: wsBase + wsBonus)
```

This keeps `max` as the effective value, so `wundschwelle.max` stays the correct field to read —
both for this spec and for the existing display at `HeroDetailView.swift:548`.

## Recompute on launch

`computeDerivedValues` is private and runs only on import (`OptolithImportService.swift:138`, `:186`,
`:249`), so stored — wrong — values do not heal themselves. Fix them at launch.

### Why not a schema migration

`HesindionApp.swift:15` builds its container as `ModelContainer(for: Hero.self, HeroStateEntry.self)`
and never passes `migrationPlan:`. `HesindionMigrationPlan` exists (`Migration/MigrationPlan.swift`)
but is not wired in, so a `SchemaV5` stage would not run. This is also a data *repair*, not a shape
change — the stored properties are unchanged. A launch-time pass is the right tool.

### What can and cannot be recomputed

`computeDerivedValues` needs `raceId` (Optolith `R_1`, `R_2`, …) to look up the species bases for
LP, SK and ZK. It is parsed at import (`OptolithImportService.swift:74`) and used, but only the
*display name* survives — `parsePersonalData` resolves it to `PersonalData.species` ("Menschen") and
the id is dropped. Species-dependent values therefore cannot be recomputed for existing heroes.

That constraint lands well: the values that depend **only** on persisted attributes and traits are
exactly the three that are wrong.

| Value | Inputs | Recomputable today? |
|-------|--------|---------------------|
| Wundschwelle | KO, `ADV_54`, `DISADV_56` | yes |
| Ausweichen | GE | yes |
| Initiative | MU, GE | yes |
| LP / SK / ZK | species base + attributes | no — needs `raceId`, **and none of them is wrong** |

LP has no division at all (`speciesLP + ko * 2`), and SK and ZK already use `Int(ceil(...))`. So the
repair pass needs nothing it cannot reach.

### Persist `raceId` going forward

Independently of the repair, stop throwing the id away:

- Add `var speciesId: String?` to `PersonalData` (`Hesindion/Models/PersonalData.swift:12`, beside
  the existing `species` display name) and populate it in `parsePersonalData`
  (`OptolithImportService.swift:342`), which already receives `raceId` as a parameter.
- Optional with a `nil` default, so it is an additive property change and needs no migration stage.
  Existing heroes report `nil` until re-imported; new and re-imported heroes carry it.
- `DerivedValueRepair` must therefore treat `speciesId == nil` as the normal case, not an error.

This unblocks a future species-aware recompute and makes one latent problem visible: the species
tables cover only `R_1`–`R_4` (Mensch, Elf, Halbelf, Zwerg) and fall back to the **human** values via
`?? 5` / `?? -5` (`OptolithImportService.swift:831`, `:859`, `:868`). A dwarf or elf import works;
anything else is silently treated as human. With the id persisted, that becomes detectable instead of
invisible. Fixing the tables is out of scope here.

### `DerivedValueRepair`

A new `Hesindion/Services/DerivedValueRepair.swift`, run once per launch from `ContentView`'s
`.task`:

```swift
enum DerivedValueRepair {
    /// Recomputes the attribute-only derived values — Wundschwelle, Ausweichen, Initiative —
    /// in place. Idempotent: recomputing an already-correct hero writes nothing.
    static func repair(_ hero: Hero) -> Bool   // true if anything changed
}
```

- Fetch all `Hero`s, call `repair(_:)`, and save **only if** at least one returned `true`, so a
  clean launch performs no writes.
- Idempotency is the property to test: running it twice must produce the same values and report no
  change on the second pass.
- Extract the three formulas into one place shared with `OptolithImportService` so the import path
  and the repair path cannot drift apart. This is the sweet-spot refactor `AGENTS.md` asks for —
  the formulas currently exist only inline inside a 900-line import service.
- **Do not** touch LP, SK or ZK. All three are already correct, all three need the species base that
  cannot be reconstructed for existing heroes, and `lebensenergie.current` is live session state
  besides. The repair writes exactly three fields.
- Log a single summary line naming how many heroes were repaired; no per-hero `LogEntry` — this is
  maintenance, not play.

The broader rounding audit that turned these up is in
`docs/plans/2026-09-10-derived-value-rounding-audit.md`.

## Tests

Add to the import test suite: `ko = 11 → 6` (the rules example), `ko = 12 → 6`, Eisern `→ 7`,
Gläsern `→ 5`, and Eisern + Gläsern together `→ 6`.

Ausweichen and Initiative get the same treatment: odd `ge` rounds up, odd `mu + ge` rounds up, and
the even cases are unchanged — a regression guard proving the fix did not shift already-correct heroes.

For `DerivedValueRepair`: a hero stored with the old truncating values has all three corrected; a
correct hero is left untouched and reports no change; a second run is a no-op; LP, SK and ZK are
never modified; a hero with `speciesId == nil` repairs normally.


# Localization

All user-facing strings go through `L()` with entries in both the English and German maps in
`Hesindion/Theme/Strings.swift`. New key groups:

- `hitZone.*` — zone names (`hitZone.kopf`, `hitZone.arme`, …) and `bodySide.links` / `bodySide.rechts`
- `bodyPlan.*` — plan and size names
- `woundEffect.<zone>.effect` / `woundEffect.<zone>.resistance`
- `fokus.*` — the Fokus-Regeln section header and each rule's name/subtitle
- `trefferzone.*` — screen labels, `trefferzone.noTalent`, `trefferzone.dropWeapon`
- `modifier.trefferzone` — the `ModifierLine` label

German is the display language for rules terms and must match the Regelwiki wording.


# Testing

New test files under `HesindionTests/`.

## `HitZoneTableTests.swift`

- **Total coverage**: for every `BodyPlan` case, rolls `1...20` each resolve to exactly one zone —
  no gaps, no overlaps. Assert by building the set of covered rolls per plan and comparing to
  `Set(1...20)`.
- **Side parity**: odd → `.links`, even → `.rechts` for paired zones; `nil` for Kopf, Torso, Schwanz.
- **Clamping**: `0` and `21` resolve without trapping.
- **Fallback**: unlisted size combinations resolve to the documented nearest size.

## `HitZoneModifiersTests.swift`

- Base values per zone.
- SF halving, including the assertion that every base value is even.
- Überrascht moves the penalty 2 toward zero.
- Combined SF + Überrascht (Kopf → `-3`).
- The clamp at `0` holds — no zone ever yields a bonus.

## `WoundEffectTests.swift`

- `multiple` boundaries: `damage == ws - 1` → no effect; `== ws` → ×1; `== 2 * ws` → ×2 and
  `probeModifier == -2`.
- The rules' own worked example, verbatim as a case: `ws == 6` gives `-1` at 6 damage, `-2` at 12,
  `-3` at 18.
- `ws == 0` never triggers an effect.
- Kopf raises Betäubung by one and clamps at 4.
- Beine sets `liegend`, and the `implies` chain from `StateCatalog` still holds afterwards.
- Torso extra damage with a seeded `RandomNumberGenerator` yields a value in `2...4`, and LP is
  written exactly once.
- A successful probe applies nothing.

## Snapshot test

One variant of `CombatTakeDamageView` with the Wundeffekt panel open, added to the existing UI
snapshot suite.

> Run with a single simulator (`make test-ui`; the Makefile already pins
> `-parallel-testing-enabled NO`). `make test-ui-record` only writes **missing** references — delete
> the reference file first when a layout change should be re-recorded.


# Documentation

- **ADR-0005** (`docs/adr/0005-trefferzonen-offence-defence-asymmetry.md`) recording why wound
  effects are applied on the defence side only: no opponent is modelled, so the offence side can
  only ever hand the GM a reminder.
- **CHANGELOG.md**: the Trefferzonen feature under `[Unreleased] → Added`, and the three rounding
  corrections under `Fixed` — Ausweichen and Initiative change rolls, so they belong where players
  will see them, not buried in an internal note.
- **AGENTS.md** — a Trefferzonen bullet under *Combat System*, and the round-up convention under
  *Code Creation Guidance* so it outlives this spec.
- **ADR-0006** (`docs/adr/0006-derived-value-rounding-and-repair.md`) recording the round-up
  convention, the `DerivedValueRepair` launch pass, and why it is a repair rather than a schema
  migration. This one is not about Trefferzonen and stands on its own.


# Out of Scope

- **Trefferzonenrüstung** — per-zone RS. The linked Fokus page defines no armour-per-zone rules;
  `hero.totalRS` stays a flat sum (`Hesindion/Models/Hero.swift:133`).
- **An opponent model.** Adding opponent KO / LP / states would make wound effects symmetric, and is
  a much larger change than these rules.
- **Automatic disarm / inventory mutation** beyond the explicit "Waffe ablegen" button.
- **The Flutter port.** The rules model is deliberately free of SwiftUI and SwiftData so the port at
  cutover is mechanical, but it is not part of this spec.
- **Zone-aware Patzertabellen** — `FumbleTable` is untouched.


# Notes and Risks

## Rules data in git

`AGENTS.md` states *"No rules data in git"*. The zone tables and Wundeffekt texts in this spec are
rules content, and committing them as static Swift follows the existing
`Hesindion/Models/FumbleTable.swift` precedent, which already carries verbatim Patzertabellen with
page citations, and `StateCatalog.swift`, which carries the Zustände. The policy as written targets
`rules.db`; this spec stays inside the established practice. If that reading is wrong, the tables
move into `rules.db` behind the same `HitZoneTable.lookup` signature and nothing else in the spec
changes.

## Dependencies

Everything this spec builds on already exists on `main`:

| Needed | Where |
|--------|-------|
| `betaeubung`, `liegend` states + `setStateLevel` | `StateCatalog.swift`, `Hero.swift:277` |
| `wundschwelle` derived value | `DerivedValues.swift:44` — **needs fixing first**, see *Data Model Fixes Required* |
| Selbstbeherrschung probe attributes | `TalentProbeAttributes.swift:13` |
| Seedable dice | `Engine/DiceRoller.swift` |
| `ModifierLine` / `CheckDomain` | `Engine/ModifierEngine.swift` |
| Static rules-table pattern | `Models/FumbleTable.swift` |
| SA lookup by `ruleId` | `Hero.swift:143` |

The only schema change is the additive `activeCombatFokusRules` array. It carries a default value,
so it needs no new `SchemaV5` — the same treatment the other `activeCombat*` booleans received.
