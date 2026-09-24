# ADR-0016: Companion Data Rides in the Optolith Export

## Status

Accepted, 2026-09-24.

## Context

An animal companion in Optolith is a name, a handful of numbers and a free-text `notes` field.
Writing down Kupperus's 336-AP build (Boronmir's Svellttaler Kaltblut) showed what that costs in
practice: nothing checks the build against its AP total, an attack lives in `notes` prose that a
regex parses (`OptolithImportService.parsePetAttacks`) and a typo — `Biss: AT 156TP 1W6+3` —
drops the attack with no error, and VW, RS, BE, advantages, training and tricks have nowhere to
go at all. Re-importing the same hero is also destructive: `applyImport` deletes and recreates
`hero.pets`, so anything the app itself tracked about a companion but Optolith does not export is
lost on the next import.

The design is `docs/plans/2026-09-24-companion-data-design.md`. This ADR records the decision it
made and the alternatives it rejected, for a change that is otherwise easy to read as "just
another importer feature" rather than a choice about where authored data lives.

## Decision

**A companion's build is a hand-written YAML file next to the export**
(`<export>.companions.yaml`), one entry per pet, holding the breed, the base stat block, every
purchase with its AP and the final values the app should use.

**A local Python tool (`scripts/companions/`, `make companions HERO=<export>`) checks that file
against the Optolith export and, once every check passes, writes a `hesindion` block into the
export** under a top-level key Optolith does not use. The tool checks; it does not compute. Final
values are hand-authored in the YAML, and rule effects that would change them (Kampftier's
+20 % LeP, Heldenwuchs) are the player's and GM's call, not something the tool derives. What the
tool does check: every purchase's AP against the Kat C column, the purchases summing to the
stated total, every attack's shape, and the export's own fields (attributes, `lp`, `ini`, `mov`,
`pa`/`pro`, the `notes` attack lines) against `values`. `--fix` rewrites those export fields from
`values`; plain `make companions` only checks and injects the block.

**Hesindion reads the `hesindion` block when present** — VW, RS, BE, advantages, abilities,
training, tricks, purchases and AP — and falls back to today's regex-and-free-text parsing when
it is absent, so a hero imported before this feature, or a pet with no authored build, still
imports.

**A re-import that would drop companion data asks first.** `OptolithImportService` exposes
`companionConflicts(in: Data, context:) -> [String]`, which lists (in `petsInOrder` order) every
stored pet that has companion data whose name-matched pet in the new file has no `hesindion`
block — empty for a new hero, a malformed file, or a pet missing from the new file entirely — and
`importHero(from:context:keepingCompanionDataFor: Set<String> = [])`, which copies the listed
fields from the old pet onto the new one before the old one is deleted. `HeroListView` calls
`companionConflicts` first and, if it is non-empty, shows one `DSAModal` per pet before calling
`importHero` with the kept names.

## Considered Alternatives

- **Edit companion data in the app.** Rejected for this feature. The build is authored once from
  a printed stat block and a purchase list; an in-app editor would duplicate the YAML file's job
  with none of its review trail (a purchase list is a diff a person can check against the AP
  total by hand) and would still need the same checks re-implemented in Swift. Out of scope per
  the design's §10, not ruled out forever.
- **A separate sidecar file the app imports directly**, instead of injecting into the Optolith
  export. Rejected: it would give the app two import sources to reconcile per hero, and the
  re-import question this ADR solves — "the last import had companion data, this one doesn't" —
  would become "which of two files is current" instead, with no single export to diff against.
  Injecting into the export keeps one file as the hero's state at any point in time.
- **Optolith's own free-text fields** (`notes`, `skills`) for VW, RS, advantages, training and
  tricks. Rejected: this is the status quo the design's §1 describes, and it is what silently
  drops an attack on a typo today. A structured block that the tool validates before it is
  written is the only source in Hesindion that fails loudly rather than parsing what happens to
  be there.

## Consequences

- A companion's build is reviewable as a diff (`<export>.companions.yaml`), checked by `make
  companions` and `make test-companions` before it ever reaches the app — `make test-companions`
  is the repo's Python test target, the way the rest of `scripts/` is exercised (`make test-only
  ONLY=<Target/Class>` is the xcodebuild one, for a single Swift test class or method).
- A pet's attacks no longer depend on `notes` prose once the block is present: the typo class of
  bug in the design's §1 (`AT 156TP`) cannot silently drop an attack, because the tool would have
  rejected the export before it was written.
- The app carries a second, optional data path per pet (`hesindion.pets[<key>]` present or
  absent), and every reader (`parsePets`, `CombatAttackViews`'s Mächtiger Schlag check) has to
  handle both. A block that fails to decode is treated as absent rather than as an import error,
  which is the same "degrade to today's behaviour" rule the missing-block case already uses.
- Re-import is no longer purely "replace `hero.pets` with what the file says": it can now pause
  on an unsaved import to ask a question, per pet, before anything is written. `importHero` keeps
  a no-question overload (`keepingCompanionDataFor` defaults to `[]`) so existing callers and the
  UI-test seed are unaffected.
- Computing final values from purchases, using VW/RS in combat, and checking that a purchase is
  legal for a breed are still out of scope (design §10) — the tool checks arithmetic and shape,
  not game rules.

## Related

- `docs/plans/2026-09-24-companion-data-design.md` — the full design this ADR summarises.
- `docs/plans/2026-09-24-companion-data-plan.md` — the implementation plan (Tasks 1–8).
