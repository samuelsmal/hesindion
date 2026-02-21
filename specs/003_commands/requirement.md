# Commands

## Overview

In DSA one can execute different type of commands, adding AP for example, doing a talent check,
attacking with a weapon, rolling a dice or altering the life energy (lebensenergie) of a hero.
Given that these commands can be deeply nested and sometimes a bit cumbersome to find, provide an
`execute command` flow.

Commands can be reached through two entry points:
- **Pull-to-reveal search** from the top of `HeroDetailView`
- **Long-pressing** on interactive elements in `HeroDetailView` (extends the existing behaviour)

---

## Trigger: Pull-to-Reveal

The command search surface is triggered by a pull-to-reveal gesture at the top of the
`HeroDetailView` `ScrollView`. This is distinct from `.refreshable` and does not show a spinner.

**Mechanism:**
1. Track the `ScrollView` offset using a `PreferenceKey` attached to a zero-height anchor view
   at the very top of the `LazyVStack` content.
2. When the scroll offset exceeds `+60 pt` (the user has pulled down past the natural top),
   the command search bar slides in pinned to the top of the screen and the text field
   becomes the first responder (keyboard appears immediately).
3. Releasing the pull snaps the scroll content back (standard bounce). The search bar
   remains visible until explicitly dismissed.
4. **Dismiss:** tap the backdrop overlay, swipe upward (`translation.height < -50`), or tap
   the ✕ button inside the search bar.

## Search Wireframe

 ┌──────────────────────────────────────────────┐
 │                                              │
 │   ┌──────────────────────────────────────┐   │  ← pinned at top (safe area)
 │   │                                      │   │
 │   │  🔍 Search commands…             ✕  │   │
 │   └──────────────────────────────────────┘   │
 │   ┌──────────────────────────────────────┐   │
 │   │ lebensenergie ändern                 │   │  ← best-match rows, sorted by overlap
 │   │ lebenselixier benutzen               │   │  ╮
 │   │ Match 3                              │   │  ╯ list takes up 1/3 of screen height,
 │   └──────────────────────────────────────┘   │    scrollable if results overflow
 │                                              │
 │                                              │
 │         [hero detail content scrolls]        │
 │                                              │
 └──────────────────────────────────────────────┘

---

## Command Data Structure

Each command is a Swift struct `AppCommand`:

```swift
struct AppCommand: Identifiable {
    let id: UUID
    let name: String           // e.g. "lebensenergie ändern"
    let subparameter: String?  // e.g. talent name; nil when not applicable
    let input: CommandInput?   // what the modal collects; nil = no input
    let execute: (CommandInput.Result?) -> Void  // deferred; called only on confirm
}

enum CommandInput {
    case integerAmount(label: String, min: Int, max: Int?)

    enum Result {
        case integerAmount(Int)
    }
}
```

The **command registry** is a computed property on `Hero` returning `[AppCommand]`. Commands
that depend on optional relationships (e.g. `hero.experience`) are only included when that
relationship is non-nil.

The `execute` closure is captured at construction time and is **never called unless the user
explicitly confirms** the command modal (taps the checkmark button).

---

## Search

### Matching rules
- Input is split on whitespace. **Token[0]** matches command `name` case-insensitively by
  substring. **Token[1]** (if present) matches `subparameter` case-insensitively by substring.
  Additional tokens are ignored.
- Matching is **case-insensitive** and applies **umlaut normalisation** before comparison:
  `ä→ae`, `ö→oe`, `ü→ue`, `ß→ss`.
- When the query is empty, **all commands** are shown sorted alphabetically.
- Results are sorted by **descending match overlap** — the length of the matched substring
  relative to the full command name. Equal-overlap results are sorted alphabetically.

### Result list
- The list occupies **1/3 of screen height**; it is scrollable when results overflow.
- Each row shows the full command string, e.g. `talent check: Selbstbeherrschung`.
- **Empty state:** a single non-interactive row reading `Keine Befehle gefunden`.
- Tapping a row dismisses the keyboard and opens the **Command Modal**.

---

## Command Modal

Upon selecting a command (from search or via long-press), a modal appears as a full-screen
`ZStack` overlay — the same pattern as the existing `EditCurrentModal`.

**Backdrop:** `Color.black.opacity(0.5)`, full-screen, `ignoresSafeArea`.
**Panel:** white system background, `Rectangle().stroke(Color.black, lineWidth: 3)`, `padding(32)`.

## Command Modal Wireframe

     ┌──────────────────────────────┐
     │ ┌──────────────────────────┐ │
     │ │                          │ │
     │ │       Command Name       │ │
     │ └──────────────────────────┘ │
     │ ┌──────────────────────────┐ │
     │ │                          │ │
     │ │                          │ │
     │ │      Variable command    │ │
     │ │      input field         │ │
     │ │      (if any)            │ │
     │ │                          │ │
     │ └──────────────────────────┘ │
     │                              │
     │          ┌──────┐            │
     │          │  ✓   │            │
     │          └──────┘            │
     └──────────────────────────────┘

**Confirm button:** yellow background, `Rectangle().stroke(Color.black, lineWidth: 3)`,
SF Symbol `checkmark` in bold black. Calls `execute` with collected input, then dismisses.

**Dismiss (cancel):** tap backdrop or swipe upward (`translation.height < -50`).
`execute` is **not** called on cancel.

**Default modal (unspecified commands):** shows only the command name, centred. No input field.
The confirm button is still present and calls `execute(nil)`.

---

## Command Registry — v1 Scope

| Command name            | Subparameter | Input type                          | Mutation                                          |
|-------------------------|--------------|-------------------------------------|---------------------------------------------------|
| lebensenergie ändern    | —            | `integerAmount(0…max)`              | `hero.derivedValues?.lebensenergie.current = n`   |
| schicksalspunkte ändern | —            | `integerAmount(0…max)`              | `hero.derivedValues?.schicksalspunkte.current = n`|
| astralenergie ändern    | —            | `integerAmount(0…max)`              | `hero.derivedValues?.astralenergie?.current = n`  |
| karmaenergie ändern     | —            | `integerAmount(0…max)`              | `hero.derivedValues?.karmaenergie?.current = n`   |
| AP hinzufügen           | —            | `integerAmount(label:"AP", min:1, max:nil)` | `hero.experience?.totalAP += n`<br>`hero.experience?.availableAP += n` |
| talent check            | talent name  | none (this iteration)               | show command title only                           |

Commands whose optional relationship is nil (e.g. `astralenergie` when the hero is not a
spellcaster) are **omitted** from the registry and will not appear in search results.

---

## AP Command Modal Detail

The `AP hinzufügen` command collects an integer ≥ 1 with no upper cap.

On confirm: `hero.experience?.totalAP += n` and `hero.experience?.availableAP += n`.
Negative values are not permitted; the minimum is 1.

---

## Long-Press Entry Points

The existing `onLongPressGesture` on `interactiveDerivedRow` is **extended** to open the
Command Modal directly, pre-populated with the matching command, bypassing search.

| UI element               | Pre-populated command    |
|--------------------------|--------------------------|
| lebensenergie row        | lebensenergie ändern     |
| schicksalspunkte row     | schicksalspunkte ändern  |
| astralenergie row        | astralenergie ändern     |
| karmaenergie row         | karmaenergie ändern      |

The existing `EditCurrentModal` / `ActiveEdit` mechanism and the `moneyRow` long-press are
**retained unchanged** for this iteration.

---

## Out of Scope (this iteration)

- Talent check dice rolling and result display (specified separately)
- Attack command
- Roll dice command
- Money command via command palette
- Most-recently-used commands in empty-query state
- Accessibility labels
- iPad-specific presentation differences
