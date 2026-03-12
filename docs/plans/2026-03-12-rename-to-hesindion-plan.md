# Rename Hesindion → Hesindion: Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Rename the entire project from "Hesindion" to "Hesindion" — directories, Xcode config, source, docs, and build scripts.

**Architecture:** Global find-and-replace with `git mv` for directory/file renames. Order matters: directories first, then file contents, then individual file renames, then build verification.

**Tech Stack:** git, sed, xcodebuild

---

### Task 0: Rename source directories

**Files:**
- Rename: `Hesindion/` → `Hesindion/`
- Rename: `HesindionTests/` → `HesindionTests/`

**Step 1: Rename main app directory**

```bash
cd /Users/SamuelvonBaussnern/proj/50_priv/Hesindion
git mv Hesindion Hesindion
```

**Step 2: Rename test directory**

```bash
git mv HesindionTests HesindionTests
```

**Step 3: Verify directories exist**

```bash
ls -d Hesindion HesindionTests
```

Expected: both directories listed, no errors.

---

### Task 1: Rename Xcode project directory

**Files:**
- Rename: `Hesindion.xcodeproj/` → `Hesindion.xcodeproj/`

**Step 1: Rename xcodeproj**

```bash
git mv Hesindion.xcodeproj Hesindion.xcodeproj
```

**Step 2: Rename scheme file inside xcodeproj**

```bash
git mv Hesindion.xcodeproj/xcshareddata/xcschemes/Hesindion.xcscheme Hesindion.xcodeproj/xcshareddata/xcschemes/Hesindion.xcscheme
```

**Step 3: Verify**

```bash
ls Hesindion.xcodeproj/xcshareddata/xcschemes/
```

Expected: `Hesindion.xcscheme`

---

### Task 2: Rename Swift source files

**Files:**
- Rename: `Hesindion/HesindionApp.swift` → `Hesindion/HesindionApp.swift`

**Step 1: Rename app entry point file**

```bash
git mv Hesindion/HesindionApp.swift Hesindion/HesindionApp.swift
```

**Step 2: Verify**

```bash
ls Hesindion/HesindionApp.swift
```

Expected: file exists.

---

### Task 3: Update project.pbxproj

**Files:**
- Modify: `Hesindion.xcodeproj/project.pbxproj`

**Step 1: Global replace Hesindion → Hesindion in pbxproj**

```bash
sed -i '' 's/Hesindion/Hesindion/g' Hesindion.xcodeproj/project.pbxproj
```

**Step 2: Verify no old references remain**

```bash
grep -c 'Hesindion' Hesindion.xcodeproj/project.pbxproj
```

Expected: `0`

**Step 3: Spot-check key lines**

```bash
grep -n 'productName\|PRODUCT_BUNDLE_IDENTIFIER\|productReference' Hesindion.xcodeproj/project.pbxproj
```

Expected: all references show `Hesindion`, no `Hesindion`.

---

### Task 4: Update scheme file

**Files:**
- Modify: `Hesindion.xcodeproj/xcshareddata/xcschemes/Hesindion.xcscheme`

**Step 1: Global replace in scheme**

```bash
sed -i '' 's/Hesindion/Hesindion/g' Hesindion.xcodeproj/xcshareddata/xcschemes/Hesindion.xcscheme
```

**Step 2: Verify**

```bash
grep -c 'Hesindion' Hesindion.xcodeproj/xcshareddata/xcschemes/Hesindion.xcscheme
```

Expected: `0`

---

### Task 5: Update Swift source file contents

**Files:**
- Modify: `Hesindion/HesindionApp.swift`
- Modify: `Hesindion/ContentView.swift`
- Modify: `HesindionTests/HeroImportTests.swift`

**Step 1: Replace in app entry point**

Update `Hesindion/HesindionApp.swift`:
- Line 2 comment: `HesindionApp.swift` → `HesindionApp.swift`
- Line 3 comment: `Hesindion` → `Hesindion`
- Line 12 struct: `struct HesindionApp` → `struct HesindionApp`

**Step 2: Replace in ContentView**

Update `Hesindion/ContentView.swift`:
- Header comment: `Hesindion` → `Hesindion`

**Step 3: Replace in test file**

```bash
sed -i '' 's/Hesindion/Hesindion/g' HesindionTests/HeroImportTests.swift
```

**Step 4: Verify no old references in Swift files**

```bash
grep -r 'Hesindion' Hesindion/ HesindionTests/
```

Expected: no matches.

---

### Task 6: Update Makefile

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile variables**

Change these lines:
```makefile
PROJECT = Hesindion.xcodeproj
SCHEME = Hesindion
BUNDLE_ID = org.savoba.Hesindion
```

And update the deploy APP_PATH reference (the `$(SCHEME).app` variable expansion handles this automatically via the SCHEME variable, so only the 3 variables above need changing).

**Step 2: Verify**

```bash
grep 'Hesindion' Makefile
```

Expected: no matches.

---

### Task 7: Update documentation files

**Files:**
- Modify: `README.md`
- Modify: `AGENT.md`
- Modify: `CLAUDE.md`
- Modify: All files in `docs/plans/` containing `Hesindion`
- Modify: All files in `specs/` containing `Hesindion`
- Modify: All files in `.claude/` containing `Hesindion`

**Step 1: Batch replace in all markdown and config files**

```bash
# Find all text files with old name (excluding .xcodeproj, .build, .git)
grep -rl 'Hesindion' --include='*.md' --include='*.json' . | grep -v '.xcodeproj' | grep -v '.build' | grep -v '.git/' | while read f; do
  sed -i '' 's/Hesindion/Hesindion/g' "$f"
done
```

**Step 2: Verify**

```bash
grep -r 'Hesindion' --include='*.md' --include='*.json' . | grep -v '.xcodeproj' | grep -v '.build' | grep -v '.git/'
```

Expected: no matches.

---

### Task 8: Clean build artifacts and verify build

**Files:**
- Delete: `.build/` directory

**Step 1: Clean old build artifacts**

```bash
rm -rf .build
```

**Step 2: Build the project**

```bash
make build
```

Expected: `BUILD SUCCEEDED`

**Step 3: If build fails, check for remaining old references**

```bash
grep -r 'Hesindion' . --include='*.swift' --include='*.pbxproj' --include='*.xcscheme' --include='*.plist' | grep -v '.git/'
```

Fix any remaining references.

---

### Task 9: Commit the rename

**Step 1: Stage all changes**

```bash
git add -A
```

**Step 2: Review staged changes**

```bash
git status
```

**Step 3: Commit**

```bash
git commit -m "feat: rename project from Hesindion to Hesindion

Hesindion — derived from Hesinde, the DSA goddess of wisdom and
knowledge. A brandable, memorable name for the companion app."
```

---

### Task 10: Update CHANGELOG.md

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add rename entry to Unreleased section**

Add under `### Changed`:
```
- Renamed project from Hesindion to Hesindion (after Hesinde, goddess of wisdom)
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add rename to changelog"
```
