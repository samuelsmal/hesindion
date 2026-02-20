# Requirements Document

## Overview

A hero list screen that lets users import DSA heroes from JSON or YAML files and navigate to the detail view (spec 002) for a selected hero.

## Business Requirements

Players need to manage multiple DSA hero sheets on their device. This screen is the entry point: it lists all stored heroes and lets the user import new ones from exported JSON or YAML files. YAML support is important because DSA tooling (e.g. Optolith) exports character sheets in YAML format.

## Functional Requirements

### Core Features

1. **Hero List**
   - Displays a list of all stored heroes
   - Each row shows only the hero's name
   - Hero names are unique — no two stored heroes may share the same name
   - Uses `NavigationSplitView` for iPad-compatible two-pane layout

2. **Hero Selection**
   - Tapping a hero navigates to the hero detail view (spec 002) and displays that hero

3. **Empty State**
   - When no heroes are stored, show an empty screen with a friendly helper message (e.g. "No heroes yet. Import a JSON or YAML file to get started.")
   - No hero selected state also shows the same empty/placeholder screen in the detail pane

4. **Import Hero from JSON or YAML**
   - A button at the bottom of the list opens a file picker filtered to `.json`, `.yaml`, and `.yml` files
   - Both formats encode identical data structures — see `hero.json` and `hero.yaml` in this spec directory
   - The format is detected by the file's extension (`.yaml` / `.yml` → YAML; `.json` → JSON)
   - On successful import:
     - All hero fields are parsed and stored via SwiftData
     - **Exception:** `equipment` and `money` fields are not overwritten if a hero with the same name already exists — the stored values prevail
     - If the hero name does not yet exist, all fields including `equipment` and `money` are imported
   - On duplicate name: update all fields except `equipment` and `money`
   - On error (malformed file, missing required fields, unrecognised format, file read failure): show a helpful inline error message describing the problem; do not modify stored data

5. **Open via System (document handler)**
   - The app registers as a document handler for `.json`, `.yaml`, and `.yml` files
   - When a user taps such a file in the Files app or any share sheet, iOS offers iDSACompanion as an option to open it
   - Opening a file this way triggers the same import logic as the in-app file picker (same upsert behaviour, same error handling)
   - After a successful open-via-system import the app navigates to the hero list (or directly to the newly imported hero if spec 002 is available)

6. **Error Handling**
   - File import errors surface as an alert with a human-readable description
   - Errors must not crash or leave the app in an inconsistent state

### User Stories

- As a player, I want to see all my heroes at a glance so I can quickly switch between characters
- As a player, I want to import a hero from a JSON or YAML file so I don't have to enter data manually
- As a player, I want to import YAML files exported directly from Optolith without converting them first
- As a player, I want to tap a `.json` or `.yaml` hero file in the Files app and have iDSACompanion open and import it directly, without navigating inside the app first
- As a player, I want re-importing an updated hero sheet to preserve my in-game equipment and money
- As a player, I want clear error messages when an import fails so I know what went wrong

## Technical Constraints

- Platform: iOS 26.0+, SwiftUI + SwiftData
- JSON parsing: native `JSONDecoder` / `Codable` — no extra dependency needed
- YAML parsing: **[Yams](https://github.com/jpsim/Yams)** via Swift Package Manager — this is the sole approved external dependency. Yams decodes YAML into a Swift value tree; the implementation should convert it to JSON `Data` first (using `JSONSerialization`) and then feed the result through the existing `JSONDecoder` + `HeroDTO` pipeline, keeping a single decoding path
- SwiftData model: **full relational model graph** — each logical entity (talents, weapons, armor, equipment, etc.) is a separate `@Model` class, not a blob
- File import (in-app): use SwiftUI's `.fileImporter` modifier with `[UTType.json, UTType.yaml]`
- File format detection: inspect the lowercased file extension — `.yaml` / `.yml` → YAML path; `.json` → JSON path; anything else → unsupported format error
- Hero name uniqueness must be enforced at the SwiftData layer (check before insert)
- The following Info.plist keys must be set to `YES` (via `INFOPLIST_KEY_*` build settings in `project.pbxproj`):
  - `UIFileSharingEnabled` — exposes the app's `Documents/` directory in the Files app under **On My iPhone → iDSACompanion**
  - `LSSupportsOpeningDocumentsInPlace` — allows the file picker to open files directly from their location without copying them first
- **Document type declarations** must be added via a supplementary `Info.plist` file (because `CFBundleDocumentTypes` is a complex nested array that cannot be expressed via `INFOPLIST_KEY_*` build settings). Set `INFOPLIST_FILE = iDSACompanion/Info.plist` in the target build settings while **keeping `GENERATE_INFOPLIST_FILE = YES`** — Xcode merges the supplementary file with the auto-generated content at build time, so all existing `INFOPLIST_KEY_*` settings continue to work and the supplementary file only needs to contain the two new top-level keys below. The required entries are:
  - **`CFBundleDocumentTypes`** — two entries, one for JSON (`public.json`, extensions `json`) and one for YAML (`public.yaml`, extensions `yaml yml`). Both with `CFBundleTypeRole = Viewer` and `LSHandlerRank = Alternate` (the app is not the primary system handler, but offers itself as an option)
  - **`UTImportedTypeDeclarations`** — one entry declaring `public.yaml` (conforming to `public.data`, extensions `yaml yml`, MIME type `application/yaml`) so that the type is known to the system on devices where it is not yet built-in
- **External file handling** in SwiftUI: attach `.onOpenURL { url in … }` to the root `WindowGroup` scene. When the system delivers a file URL, read the file data (with security-scoped resource access), run it through `HeroImportService`, and show a result alert — same logic as the in-app picker

## Data Model Notes

The JSON/YAML schema (see `hero.json` and `hero.yaml`) maps to these top-level entities as separate `@Model` classes:
- `Hero` (root, owns all relationships)
- `PersonalData`
- `Experience`
- `Attributes`
- `DerivedValues` (with nested value structs as `Codable` — these are small enough to embed)
- `Talent` (with a category tag)
- `CombatTechnique`
- `MeleeWeapon`
- `Armor`
- `Shield`
- `EquipmentItem` ← preserved on re-import
- `Money` ← preserved on re-import
- `Mount` (with nested attacks and talents as `Codable`)
- `Language` and `Script` (scripts stored as `[String]` on the Hero)

## Acceptance Criteria

1. An empty list shows a friendly placeholder message, no crash
2. Importing `hero.json` creates a new hero named "Boronmir Siebenfeld von Ferdok" with all fields persisted
3. Importing `hero.yaml` (same data) creates the same hero correctly, or updates an existing one
4. Re-importing the same file with different equipment/money leaves the stored equipment and money unchanged
5. Re-importing the same file with updated attributes updates those attributes
6. Importing a malformed JSON or YAML file shows an error message and leaves the hero list unchanged
7. Importing a file with an unrecognised extension shows an appropriate error message
8. Tapping a `.json` hero file in Files app presents iDSACompanion as an option; selecting it imports the hero
9. Tapping a `.yaml` / `.yml` hero file in Files app presents iDSACompanion as an option; selecting it imports the hero
10. Tapping a hero row navigates to the detail view (spec 002) showing that hero
11. Hero names are unique — importing a hero with a new name creates a new record

## Out of Scope

- Manual hero creation or editing within the app
- Exporting heroes to JSON or YAML
- Deleting heroes (future feature)
- Ranged weapons (not present in the sample schemas yet)

## Dependencies

- Spec 002 (hero detail view) — navigation target on hero selection
- **Yams** SPM package — required for YAML parsing

## Risks and Assumptions

### Risks

- File schema may evolve; nullable fields should be handled gracefully with optional decoding
- ~~Switching from `GENERATE_INFOPLIST_FILE = YES` to a hand-authored `Info.plist`~~ — **mitigated**: the supplementary `INFOPLIST_FILE` approach keeps `GENERATE_INFOPLIST_FILE = YES` active, so all auto-generated keys remain in place and only the two custom entries need to be in the file
- `UTImportedTypeDeclarations` for `public.yaml` may conflict if Apple ships a built-in definition in a future iOS version; use `conformsTo = ["public.data"]` to stay compatible

### Assumptions

- All files are UTF-8 encoded
- The YAML schema is structurally identical to the JSON schema (same field names and nesting)
- All fields except `equipment`, `money`, `astralenergie`, and `karmaenergie` are required
- `astralenergie` and `karmaenergie` are nullable (non-mage/non-priest heroes have none)
- `shield` and `mount` are optional top-level fields (not all heroes have them)
