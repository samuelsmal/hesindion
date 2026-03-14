# Hero Color Schemes & UI Fixes Design

**Date:** 2026-03-14
**Status:** Approved

## 1. Sidebar Fixes

### Title Centering
Replace system `.navigationTitle("Hesindion")` with a custom centered header to ensure the title is visually centered in the sidebar column.

### Background
Remove any rounded corners from the sidebar background. The background must extend edge-to-edge and full height of the screen. No rounded rectangles — neo-brutalist flat edges only.

### Readability
- **"Held Importieren" button:** Ensure high contrast — white text on the golden background, or darken the background. Current `.foregroundStyle(.primary)` is too low contrast.
- **Selected hero row:** Increase selection highlight opacity from `0.15` to a stronger value (e.g., `0.35`+) so the selected state is clearly visible and text remains readable.

## 2. Attributes Border Removal

Remove the 3pt trailing border overlay from `AttributesColumn` in `HeroDetailComponents.swift`. The vertical attribute sidebar should have no right-edge border.

## 3. Right Panel Buttons

Change panel toggle buttons (notes, logs, rules) so that:
- **All states** have a filled background with their panel color
- **No border stroke** in any state
- **Inactive:** panel color fill, white icon (outline variant)
- **Active:** panel color fill, white icon (filled variant)
- Distinguish active/inactive purely via the SF Symbol icon change (outline vs filled)

## 4. Profession Color Scheme System

### Data Model
- Add `colorSchemeId: String?` property to the `Hero` SwiftData model
- Create `HeroColorScheme` as a pure value type (struct, not SwiftData model):
  - `id: String` — identifier (e.g., "golgarit", "praios", "krieger")
  - `name: String` — display name for the settings UI
  - `sectionColors: [Color]` — 4 colors, gradient from dark to light (one per content group)
  - `textColor: Color` — for text on section headers
  - `accentColor: Color` — for sidebar highlight when this hero is selected

### Profession-to-Scheme Mapping

Static dictionary mapping profession strings to scheme IDs. Unmapped professions use the default golden scheme (current look).

| Category | Professions | Base Hue | Gradient (dark → light) |
|----------|-------------|----------|------------------------|
| Boron/Golgarit | Borongeweihter, Golgarit | Black/violet | `#1a0a2e` → `#2d1650` → `#4a2578` → `#6b3fa0` |
| Praios | Praiosgeweihter | Gold | `#5c3d00` → `#8b6914` → `#b8942a` → `#d4b44a` |
| Rondra | Rondrageweihter, Kor-Geweihter | Red/silver | `#4a0e0e` → `#6b1a1a` → `#8c2f2f` → `#a84545` |
| Peraine | Perainegeweihter | Green | `#0a2e14` → `#165028` → `#227840` → `#2ea058` |
| Hesinde | Hesindegeweihter | Blue/gold | `#0a1a3e` → `#142e5c` → `#1e4280` → `#2856a4` |
| Phex | Phexgeweihter | Gray/silver | `#1a1a22` → `#2e2e3a` → `#444456` → `#5a5a70` |
| Efferd | Efferdgeweihter | Ocean blue | `#0a1e2e` → `#143450` → `#1e4a78` → `#2860a0` |
| Firun | Firungeweihter, Ifirn-Geweihter | Ice white/blue | `#1a2230` → `#2e3a4a` → `#445264` → `#5a6a80` |
| Ingerimm | Ingerimmgeweihter | Fire/forge | `#2e1a0a` → `#503014` → `#78461e` → `#a05c28` |
| Rahja | Rahjageweihter | Rose/wine | `#2e0a1a` → `#501430` → `#781e46` → `#a0285c` |
| Travia | Travia-Geweihter | Warm hearth | `#2e1e0a` → `#503414` → `#784a1e` → `#a06028` |
| Tsa | Tsakgeweihter | Spring green | `#0a2e1e` → `#145034` → `#1e784a` → `#28a060` |
| Swafnir | Swafnir-Geweihter | Storm gray | `#181e24` → `#28323c` → `#3c4856` → `#505e70` |
| Namenlos | Namenloser Geweihter | Void black | `#0a0a0e` → `#16161e` → `#222230` → `#2e2e42` |
| Krieger | Krieger, Ritter, Söldner, Gardist, Ordenskrieger, etc. | Steel | `#14181e` → `#242c36` → `#384050` → `#4c586a` |
| Magier | Akademie-Magier, Gildenloser Magier, Qabalyamagier, etc. | Indigo | `#0e0a2e` → `#1a1650` → `#282278` → `#3630a0` |
| Hexe | Hexe | Forest | `#0a1e0a` → `#163416` → `#224a22` → `#2e602e` |
| Mundane | Händler, Jäger, Fuhrmann, Prospektor, etc. | Earth/amber | `#2e1a0a` → `#4a2e14` → `#66421e` → `#825628` |
| Default | Unmapped professions | Golden (current) | Uses existing group colors unchanged |

### Settings Access
- New command in the command palette: "Einstellungen für <Hero>"
- Opens a `.fullScreenCover` with `HeroSettingsView`
- Contains a color scheme picker: grid of colored swatches with profession/scheme names
- Hero's `colorSchemeId` is persisted via SwiftData

### How Schemes Apply
- `CollapsibleGroup` color parameter derives from the active scheme instead of hardcoded group colors
- Section index determines gradient step: 0=Personal Data (darkest), 1=Talents, 2=Equipment (lightest)
- Sidebar hero row selection highlight uses the scheme's accent color
- `CollapsibleSection` headers inherit from their parent group color

### What Stays Unchanged
- Attribute colors (MU, KL, etc.) — always fixed DSA colors
- Combat mode — always red, never affected by hero scheme
- Panel toggle button colors — always their current warm trio
- Rulebook sidebar section — always purple
