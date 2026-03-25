# Dice Roll Command — Design

## Summary

Add a general-purpose "Würfeln" command to the command palette that lets the user roll any combination of dice (e.g. 3W6, 1W20, 2W10). Results are displayed in a sheet with the existing tumble animation and logged to the action log.

## Data Flow

1. Command palette entry "Würfeln" (no input, sentinel like "Regenerieren"/"Kampf")
2. `HeroDetailView` detects `activeCommand.name == "Würfeln"` and presents `DiceRollSheet`
3. Sheet manages its own state: dice count, sides, roll result
4. On confirm, creates a `LogEntry` with kind `"diceRoll"` and `DiceRollPayload`
5. Dismiss

## UI Layout (DiceRollSheet)

Neo-Brutalist style, matching `RegenerierenSheet`:

1. **Header** — "Würfeln" title, colored background + border
2. **Dice config** — Two stepper rows (locked after rolling):
   - **Anzahl** (count): range 1–10, default 1
   - **Seiten** (sides): cycles through [3, 4, 6, 8, 10, 12, 20], default 6
3. **Dice display** — Tumbling animation pre-roll, individual results post-roll. Tap to roll (with hint text)
4. **Result summary** — Post-roll only: formula like "3W6 = 4 + 2 + 6 = 12"
5. **Confirm button** — Checkmark, logs roll and dismisses

## LogEntry Integration

```swift
struct DiceRollPayload: Codable {
    let count: Int      // e.g. 3
    let sides: Int      // e.g. 6
    let results: [Int]  // e.g. [4, 2, 6]
    let total: Int      // e.g. 12
}
```

Kind: `"diceRoll"`. LogPanelView renders as "3W6: 4 + 2 + 6 = 12".

## Files Changed

| File | Change |
|------|--------|
| `Hero.swift` | Add "Würfeln" AppCommand to commandRegistry |
| `LogEntry.swift` | Add `DiceRollPayload` and `"diceRoll"` kind |
| `LogPanelView.swift` | Render diceRoll log entries |
| `HeroDetailView.swift` | Handle "Würfeln" command → present DiceRollSheet |
| `DiceRollSheet.swift` | **New** — roll sheet UI |
| `Strings.swift` | Add localization keys |

No schema migration needed — LogEntry payload is JSON-encoded.
