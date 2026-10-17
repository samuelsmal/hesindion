# ADR-0021: Companion Data Lives in Optolith's Pet Fields

## Status

Accepted, 2026-10-03 (issue #49). Supersedes ADR-0016.

## Context

ADR-0016 put a companion's data into a `hesindion` block that `make companions` wrote into the
Optolith export from a hand-written build file. Optolith does not know the block, so a pet edited
in Optolith and exported again lost it, and every change took four steps. Optolith's pet text
fields are single-line inputs, so a pasted line break is lost.

## Decision

The player edits the companion in Optolith's pet editor only. PA is VW, RS is RS, and the
Sonderfertigkeiten and Notizen fields hold labelled segments (`Vorteile: …; Tricks: …`,
`Angriffe: …; BE: 0`) on one line. `PetTextFormat` parses them at import. A part that does not
parse is not imported; the import lists it in a modal and the companion sheet keeps the list
until a clean re-import. The purchase list and the AP check against Kat C are dropped; the app
shows Optolith's own AP. The format is `docs/companion-format.md`; the design is
`docs/plans/2026-10-03-companion-text-format-design.md`.

## Considered Alternatives

- **Keep the build file as an optional audit tool** that writes into Optolith's fields. Rejected:
  two sources again, and the player's Optolith edits would be overwritten on the next run.
- **One `Hesindion:` block in Notizen.** Rejected: one long single-line field to edit, and PA/RS
  typed twice.
- **A kind prefix per item** (`Vorteil Geduldig, Trick Aus`). Rejected: more typing per item.
- **Read the old formats as a fallback.** Rejected: three data paths in the code and in every
  test, for one player's exports that are converted in the same change.

## Consequences

- No step between Optolith and the app. An Optolith round trip keeps the data (verified
  2026-10-03).
- A typo no longer drops data silently: the player sees the field, the text and the reason.
- An export with a `hesindion` block imports, but the block is ignored.
- `make companions`, `make test-companions`, the build file and the re-import question are gone.
