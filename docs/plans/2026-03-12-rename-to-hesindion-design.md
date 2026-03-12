# Rename: Hesindion → Hesindion

**Date:** 2026-03-12
**Status:** Approved

## Motivation

The name "Hesindion" is generic, dated (i-prefix), too long, and not brandable. "Hesindion" is derived from Hesinde, the DSA goddess of wisdom and knowledge — evoking a keeper of lore at the player's side. It's unique, searchable, and works as a one-word brand.

## Scope

### Directories (git mv)
- `Hesindion/` → `Hesindion/`
- `HesindionTests/` → `HesindionTests/`
- `Hesindion.xcodeproj/` → `Hesindion.xcodeproj/`

### Xcode Config
- `project.pbxproj` — global replace (~20+ refs)
- `Hesindion.xcscheme` → `Hesindion.xcscheme` + update internal refs

### Swift Source
- `HesindionApp.swift` → `HesindionApp.swift` (rename struct + file)
- Header comments in ContentView.swift, HeroImportTests.swift

### Documentation (~18 files)
- README.md, AGENT.md, plan docs, specs, agent memory files

### Settings
- `.claude/settings.local.json` path reference

### Build Artifacts
- Delete `.build/` (regenerated on next build)

## Approach
1. Rename directories with `git mv`
2. Global find-and-replace `Hesindion` → `Hesindion` in all text files
3. Rename individual files
4. Clean build artifacts
5. Verify build
