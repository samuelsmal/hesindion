# Requirements Reviewer Memory

## Recurring Requirement Gaps
- Empty state is never specified (confirmed in spec 001)
- Error handling is never specified (confirmed in spec 001)
- Data model granularity (single @Model vs relational) is never addressed
- Sort order for lists is never specified
- Delete/edit capability is left ambiguous
- iPad vs iPhone layout differences are not addressed
- Accessibility (VoiceOver, Dynamic Type) is not mentioned

## DSA Domain Terms
- "Hero" = a DSA player character (Held), NOT an app user
- Core attributes: MU, KL, IN, CH, FF, GE, KO, KK (8 attributes, German abbreviations)
- Derived values use German names: lebensenergie, astralenergie, karmaenergie, seelenkraft, etc.
- Talent categories: korpertalente, gesellschaftstalente, naturtalente, wissenstalente, handwerkstalente
- DSA uses German naming throughout; specs must clarify English vs German for code vs UI

## Architecture Constraints
- No external dependencies policy conflicts with YAML parsing (no built-in iOS YAML parser)
- Existing codebase is Xcode template with Item model -- specs should state whether to replace it
- NavigationSplitView already in ContentView.swift -- new list views replace sidebar content
- Neo-Brutalist design theme exists but specs never reference it for new UI
- HeroDetailView.swift already exists as a placeholder stub -- spec 002 replaces its body only

## Project Structure
- Specs live in `/specs/NNN_feature-name/requirement.md` with optional reference files
- Requirements template exists at `/specs/template/requirements.md` but specs don't use it
- Spec 001 = heroes list (implemented), Spec 002 = hero detail view (dependency chain)
- hero.json (not hero.yaml) is the actual reference file in spec 002 dir (no .yaml file present)
- PDF character sheet is in spec dir but requires poppler to read -- cannot be used by agent directly

## Spec 002 Specific Context
- Hero data model is fully implemented: Hero, PersonalData, Experience, Attributes, DerivedValues,
  Talent (with category string), CombatTechnique (at/pa optional), MeleeWeapon, Armor, Shield,
  EquipmentItem, Money, Mount, Language -- all as separate @Model classes
- DerivedValues embeds value structs: LifeEnergyValue, ResourceValue, ComputedValue (Codable)
- Attributes stored with Swift-safe names: inValue (not in), zaehigkeit (not zähigkeit)
- HeroDetailView receives Hero via let -- no @Query needed in the detail view itself
- Current HeroDetailView.swift has only a placeholder body; full implementation is spec 002's job

## Patterns for Efficient AI Implementation
- Format decision (YAML vs JSON) must be pinned before implementation -- highest leverage item
- Complex data models need explicit model sketches or at minimum flat-vs-relational decision
- List views need: row content, sort order, empty state, selection behavior
- File import needs: source (fileImporter vs other), UTType, error handling, duplicate strategy
- Detail views need: section breakdown, which fields to show/hide if nil, edit vs read-only, scroll behavior
- "Mobile-friendly" and "use PDF as inspiration" are not actionable requirements for an AI agent
- Sticky/pinned header pattern must name the exact SwiftUI mechanism (outside ScrollView vs LazyVStack pinnedViews)
- Section collapse state must specify transient (@State) vs persistent (@AppStorage) -- and default open/closed
- Section header display labels must be provided explicitly; "model file name" is not a UI label
- Interactive value fields must name exact model property path (e.g. schicksalspunkte.value not .current)
- SwiftData mutation path must be stated; agents may use @State (discarded) instead of mutating @Model directly
- Modal dialogs: specify dismiss gesture; agents default to .sheet which does NOT blur background
- Nil optional vs max==0 are two different guard conditions -- both must be addressed when hiding fields
- Duplicate entries in ordered lists (e.g. derivedValues appearing twice) will be interpreted as intentional

## Model Gotchas Confirmed in Spec 002
- meleeWeapons is a [MeleeWeapon] array on Hero, not a single optional -- spec wrote it as singular
- equipment: [EquipmentItem] and carryingCapacity: Int exist on Hero but were omitted from spec
- schicksalspunkte is MutableResourceValue (has .current/.bonus/.max); LifeEnergyValue adds .base/.purchased
- lebensenergie is LifeEnergyValue (non-optional); astralenergie and karmaenergie are MutableResourceValue? (optional)
- PersonalData has no optional fields -- all strings/ints are non-optional, so "don't show if null" rule doesn't apply
- experience section (level, totalAP, availableAP, spentAP) is frequently forgotten in ordered section lists
- CombatTechnique.pa is Int? -- spec never addresses how to render absent PA column
- Shield fields: structure, breakingFactor, atMod, paMod, weight (no DSA-friendly display labels in spec)
- Mount has full sub-model: MountAttributes (8 attrs), [MountAttack], [MountTalent], specialAbilities
- MountAttributes uses Swift-safe names: inValue, kk etc. -- JSON keys are "IN", "KK" etc.
- The JSON sample file path in the spec was wrong (./spec/ instead of specs/) -- always verify paths

## Spec 002 Inter-Spec Conflicts
- Spec 000 says money is mutable; spec 002 says all fields are read-only -- contradiction, needs resolution
- Spec 000 mandates carryingCapacity/totalWeight display and overload alert; spec 002 omits both entirely
