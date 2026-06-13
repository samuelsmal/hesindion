# Player States (Zustände & Status) — Design

**Date:** 2026-06-13
**Status:** Approved
**Branch:** `feat/player-states`

## Goal

Track DSA 5 Zustände (leveled conditions I–IV) and Status (binary statuses) per hero,
surface them prominently as table reminders, and feed their penalties into the existing
ModifierEngine so skill checks and combat rolls stay mathematically correct.

Rules source: https://dsa.ulisses-regelwiki.de/GR_Zustand.html and /GR_Status.html
(core Regelwerk pp. 32–36). Hitze/Kälte (Hitze_und_Kaelte.html) is handled by players
adding the *resulting* states manually — no exposure tracker in this iteration.

## Scope decisions (user-approved)

1. **All core states**: 8 core Zustände + ~17 core-rulebook Status. Supplement /
   creature-transformation statuses (Lykanthrop, Feylamia, …) are out of scope.
2. **Hitze/Kälte**: resulting states only; detail sheets of Paralyse / Betäubung /
   Verwirrung mention hypothermia / overheating among causes.
3. **Full mechanics integration** with first-class removal UX.
4. **Architecture**: static catalog in code + one generic SwiftData entry model
   (not per-state Hero properties).

## Rules model

### Catalog (`StateCatalog.swift`, static Swift data — no rules DB, per data policy)

Each `StateDefinition` carries: `id`, localized name, SF Symbol, kind
(`.zustand` leveled I–IV / `.status` binary), per-level effect summaries,
cause text, **removal/decay rule text**, and mechanical wiring (see below).

**Zustände** (new: Betäubung, Furcht, Paralyse, Verwirrung, Berauscht, Entrückung):

| Zustand | Effect per level | Decay |
|---|---|---|
| Betäubung | alle Proben −Stufe; IV = Handlungsunfähig | 1 Stufe / 3 h Ruhe |
| Furcht | alle Proben −Stufe; IV = katatonisch, Handlungsunfähig | 1 Stufe / 5 min nach Wegfall des Auslösers |
| Paralyse | Bewegungs-/Sprach-Proben −Stufe, GS 75/50/25 %; IV = Bewegungsunfähig | 1 Stufe / 30 min |
| Verwirrung | alle Proben −Stufe; ab III kein Zaubern/Liturgien/Wissenstalente; IV = Handlungsunfähig | 1 Stufe / h (sonst lt. Auslöser) |
| Berauscht | Zechen-Proben −Stufe; IV → +1 Betäubung, −4 Berauscht | 1 Stufe / 2 h ohne Alkohol |
| Entrückung | gottgefällige Proben +(Stufe−1), alle anderen −Stufe | 1 Stufe / h |

**Schmerz** joins the catalog: manually added levels (spells, GM rulings) *add* to the
LP-derived level, total capped at IV; Zäher Hund (ADV_49) reduction still applies to the
effective level. **Belastung** remains armor-derived (no manual entry) but counts as a
Zustand for the cap and the 8-level threshold.

**Status** (binary): Liegend, Blutend, Brennend, Blind, Taub, Stumm, Fixiert, Eingeengt,
Überrascht, Vergiftet, Krank, Bewegungsunfähig, Handlungsunfähig, Bewusstlos, Unsichtbar,
Versteinert, Übler Geruch.

### Engine-enforced semantics

- Zustand penalties stack additively, **capped at −5 total** (GR). When the cap binds,
  an explicit positive adjustment line "Zustände max. −5" keeps displayed math honest.
- **≥ 8 total Zustand levels ⇒ Handlungsunfähig** — derived warning banner.
- Level-IV escalation is **derived, never stored**: Betäubung/Furcht/Verwirrung IV ⇒
  Handlungsunfähig badge; Paralyse IV ⇒ Bewegungsunfähig badge.
- Implication chain derived for display: Bewusstlos ⇒ Handlungsunfähig ⇒ Liegend.

## Mechanics integration

Principle: **auto-math only where the rule is a clean additive modifier; structured
reminders everywhere else.** No fake math.

| Wiring | States | Behavior |
|---|---|---|
| Auto modifier lines, all domains | Betäubung, Furcht, Verwirrung, Paralyse¹, Schmerz | `−level`, labeled (e.g. `Furcht II (−2)`), respects `schipIgnoreZustand` |
| Auto, combat domains | Liegend (Angriffe −4, Verteidigung −2), Fixiert (AW −4) | lines in AT / PA / AW evaluation |
| Reuses existing modifier | Eingeengt | drives the existing Beengte-Umgebung weapon-length penalties; the combat toggle becomes a shortcut that reads/writes this status |
| Special toggle | Entrückung | penalty line by default; a "gottgefällig" toggle appears in spell/liturgy check UIs while active and flips to the bonus |
| Structured reminder only | Blind, Überrascht, Unsichtbar, Blutend, Brennend, Berauscht², Taub, Stumm, Vergiftet, Krank, Übler Geruch, Versteinert, Bewusstlos / Handlungsunfähig / Bewegungsunfähig | prominent badge + exact rule text (halved values, natural-1 defenses, 1 SP/KR, …) |

¹ Paralyse penalizes only movement/speech checks — the modifier-line label carries the caveat.
² Berauscht affects only Zechen; reaching IV prompts the +1 Betäubung conversion.

Implementation: one new `StateModifiers` group of `ModifierDefinition`s registered in
`ModifierEngine.shared`, plus the cap aggregation. The existing `SharedModifiers.pain`
definition migrates into this group.

## Persistence

```swift
@Model final class HeroStateEntry {
    var stateID: String   // StateCatalog id
    var level: Int        // 1–4 for Zustände, always 1 for Status
}
// Hero: @Relationship(deleteRule: .cascade) var states: [HeroStateEntry]
```

Additive schema change ⇒ lightweight SwiftData migration. ADR documents the
catalog-in-code + generic-entry decision.

## UX

- **Hero detail** — new "Zustände & Status" section: active states as neo-brutalist
  chips (`Furcht II −2`), "+" opens a picker sheet grouped Zustände / Status with search.
- **State detail sheet** (tap chip): level stepper I–IV, effect table with current level
  highlighted, cause, **removal rule prominently**, Remove button. Long-press chip =
  quick decrement (removal was an explicit user requirement).
- **Combat root** — STATUS section (current Schmerz badge location) shows all active
  chips, the Handlungsunfähig/Bewegungsunfähig warning banner, per-round reminders
  (Blutend: "1 SP am Ende jeder KR"). States addable mid-combat.
- **Checks** — states appear as labeled modifier lines in the existing skill-check and
  combat modals, plus the cap line. No new interaction model.

## Testing

- **Unit**: catalog completeness & invariants; penalty aggregation (stacking, −5 cap,
  8-level threshold, Schmerz auto+manual merge, level-IV derivation, implication chain);
  per-domain modifier lines (Liegend only in combat domains, Paralyse caveat, Entrückung
  toggle).
- **Snapshot**: hero-detail section, picker sheet, detail sheet, combat chips + banner.
- Baseline note: `CombatRootViewSnapshotTests.testMidCombat`,
  `HeroListViewSnapshotTests.testEmptyState/testPopulated` already fail on clean `main`
  (pre-existing); this feature must not grow that list.

## Out of scope / future

- Hitze/Kälte exposure tracker (could build on weather + Aventurian calendar).
- Talent-conditional auto-modifiers (Berauscht→Zechen, Taub→Sinnesschärfe −3,
  Übler Geruch→social −1) once checks expose talent identity to the engine.
- Auto-decay timers tied to game time; bulk "Ruhephase" action.
- Supplement Zustände (Animosität, Begehren, Erregung, Trance, …).
