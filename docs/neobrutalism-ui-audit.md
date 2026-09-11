# UI audit: Hesindion SwiftUI app vs. the neobrutalism design system

**Date:** 2026-09-11
**Branch:** `review/neobrutalism-swiftui-audit` (based on `main` @ 487ce37)
**Target reviewed:** `Hesindion/Views/**` + `Hesindion/Theme/**` — 42 view files,
14,654 lines excluding the `Strings.swift` table (107 Swift files / 21,637 lines overall)
**Reference spec:** `../design-systems/neobrutalism/ds-bundle/` (neobrutalism-components, 235 components)
**Nature of this document:** read-only audit. No code was changed.

---

## 1. Verdict

The app is a committed, internally consistent piece of neobrutalism. It is *more* brutalist than
the reference in one respect — it is almost entirely square-cornered where the spec allows a 5px
radius — and it respects the aesthetic's prohibitions nearly everywhere: zero shadows, zero
gradients, one single blur in 21k lines.

**The problem is not the design. It is that the design is not expressed as code.** The neobrutalist
border — the app's defining visual element — exists as **202 byte-identical copies of a
one-line incantation**:

```swift
.overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))   // 97 identical copies
.overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))   // 95 identical copies
.overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 1))   // 10 identical copies
```

There is exactly **one** custom `ViewModifier` in the entire app (`AdaptiveContentWidth`), and it
governs content width, not style. `DSALayout` defines `primaryBorder`/`secondaryBorder`/
`tertiaryBorder` — and they are used **27 times against 247 hardcoded literals**. The literal
values are *identical* to the token values, so this is not a design disagreement; the tokens are
simply bypassed. Changing `DSALayout.secondaryBorder` today would move 17 of the app's 134 2px
borders and leave 117 behind.

The colour layer, by contrast, is properly adopted: `Color.dsaBorder` is used 263 times and the
group/attribute palette is a real system. So the app has **half a design system** — colour is
tokenised and consumed; geometry and composition are copy-pasted.

| Dimension | Verdict |
|---|---|
| Flat surfaces, no gradients | **Conformant** — 0 `.shadow()`, 0 gradients, 0 `Material` |
| No blur | **One breach** — `.blur(radius: 30)`, on photo content |
| Colour token adoption | **Conformant** — `dsaBorder` 263 uses, palette well-structured |
| Two-tier surfaces | **Conformant** — matches the spec's background / secondary-background split |
| Accessible typography | **Conformant** — Dynamic Type throughout, only 15 fixed sizes |
| Border-width tokens | **Failing** — 247 literals vs 27 token uses |
| Style abstraction layer | **Absent** — 202 duplicated border lines, 1 ViewModifier |
| Corner radius | **Untokenised** — no token exists; 13 undesigned rounded outliers |
| Typography weights | **Weak** — 4 weights, 551 inline declarations, `.black` used 201× |
| "No subtle greys" | **Failing** — ~260 sites via `.secondary`, `.gray`, `opacity()` |
| Press interaction | **Missing** — 192 of 211 buttons have no press feedback |

---

## 2. The reference spec, as normative values

Extracted from `ds-bundle/_ds_bundle.css` (`:root` and `.dark` blocks) and `conventions.md`;
oklch converted to sRGB.

| Token | Light | Dark |
|---|---|---|
| `--border` | `#000000` | `#000000` (**unchanged**) |
| Border weight | `border-2` → **2px, nearly everywhere** | same |
| `--shadow` | `4px 4px 0 0 var(--border)` — **zero blur, zero spread** | same |
| `--radius-base` | **5px** | same |
| `--background` (page) | `#DCEBFE` | `#20294B` |
| `--secondary-background` (cards/inputs) | `#FFFFFF` | `#1F1F1F` |
| `--foreground` | `#000000` | `#E6E6E6` |
| `--main` (accent) | `#5294FF` | same |
| `--overlay` (scrim) | `rgba(0,0,0,0.8)` | same |
| `--ring` (focus) | `#000000` | `#FFFFFF` |
| Font family | `"DM Sans", ui-sans-serif, system-ui` | same |
| Font weights | **exactly two**: 500 body, 700 heading | same |

**The signature press interaction** (`conventions.md`): an interactive element sits on the shadow
and moves into it on press — `translate(+4px, +4px)` while the shadow goes to `none`, so the element
lands flush.

Three explicit prohibitions: **no gradients, no blurred shadows, no subtle greys.**

---

## 3. Documented and defensible divergences

Recorded so the delta is explicit, and so nobody "fixes" them by accident.

### D1 — No drop shadows (deliberate, but only loosely documented)

Verified: **0 `.shadow(`** in `Views/` and `Theme/`. `ADR-0002` mandates "bold borders,
high-contrast colors, **flat surfaces** with visible structure", which implies it — but unlike the
Flutter side's ADR-0008 ("structure shown by borders, not shadows"), ADR-0002 never states it
outright, and never mentions that this departs from the upstream neobrutalism reference at all.

This drops the reference system's most recognisable element and, as a knock-on, makes its press
interaction structurally impossible — there is no shadow to move into. That is why **S3** exists.

**Recommendation:** amend ADR-0002 to say so explicitly. Right now a reader cannot tell whether
the absent shadow is a decision or an omission, which is exactly the ambiguity an ADR exists to
remove.

### D2 — Border adapts black/white; the spec keeps it black

`AttributeColors.swift:29` — `dsaBorder = Color(UIColor.label)`, i.e. black in light, white in
dark. The spec keeps `--border: #000000` in both themes.

Correct call. With no shadow (D1) and a near-black dark surface, black strokes would be invisible.
Using `UIColor.label` rather than a hand-rolled dynamic colour is also the right mechanism — it
tracks accessibility settings like Increase Contrast for free.

### D3 — Three border weights instead of one

`Layout.swift:11-15` defines 3 / 2 / 1. Actual distribution across all 283 border declarations:
**2px ×134, 3px ×117, 1px ×23**.

`secondaryBorder: 2` matches the spec exactly, and 2px being the most common weight matches the
spec's intent ("2px is the default; use it nearly everywhere"). Two notes:

- The tier system is load-bearing given D1 — it carries the emphasis the shadow would have.
- The 1px tier (23 uses) is the one that fights the aesthetic: a hairline is precisely the
  "subtle" the spec prohibits. Worth asking whether those 23 sites want a thinner border or none.

### D4 — System font (SF), not DM Sans

No custom font is registered. Correct for a native iOS app, and it is what makes D5 (Dynamic Type)
possible. Listed only for completeness.

### D5 — Square corners rather than the spec's 5px

272 of 282 strokes are on `Rectangle`, not `RoundedRectangle`. The app is deliberately, almost
totally square-cornered — arguably a *stronger* brutalist position than the reference's 5px, and
it reads as intentional because it is so consistent.

The problem is not the choice; it is that the choice is nowhere recorded and 13 outliers contradict
it (see **S4**).

---

## 4. Findings

Ordered by cost of leaving alone. References are `file:line`.

### S1 — No style abstraction layer: the border idiom is copy-pasted 202 times

**Severity: high (root cause).**

| | count |
|---|---|
| `.overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: N))`, byte-identical | **202** |
| `Rectangle().stroke` total | 272 |
| `.overlay(` | 290 |
| `.background(` | 295 |
| custom `ViewModifier` definitions | **1** (`AdaptiveContentWidth`, layout only) |
| `extension View` style helpers | **0** |

The app's single most characteristic visual element has no name. It is re-typed at every site, and
where it varies it varies inline — `CombatSetupViews.swift:125`:

```swift
.overlay(Rectangle().stroke(armor.isEquipped ? combatAccent : Color.dsaBorder,
                            lineWidth: armor.isEquipped ? 3 : 2))
```

…which encodes the entire emphasis rule — selected means accent-coloured *and* one tier heavier —
as an anonymous pair of ternaries in one view, where no other view can reuse it and nothing
prevents the next author choosing differently.

**Consequences that are already visible:** this is *the* reason S2 (247 literal widths) and S4
(untokenised radii) exist, and the reason S3 (no press feedback) cannot be fixed centrally. It is
also why the 1px tier could proliferate to 23 sites without a decision being made anywhere.

**Recommendation.** Add a `Theme/DSABox.swift` with three `View` extensions — `.dsaBox(.primary)`,
`.dsaBox(.secondary)`, `.dsaBox(.tertiary)` — wrapping stroke colour, width, shape and (later)
press state, then migrate call sites file by file. This is a large but purely mechanical change,
and it is the prerequisite that makes S2, S3 and S4 cheap. The 202 identical copies make the first
~70% of the migration a safe find-and-replace.

### S2 — Border-width tokens are bypassed: 247 literals vs 27 token uses

**Severity: high.**

`DSALayout.primaryBorder` / `secondaryBorder` / `tertiaryBorder` are referenced **7 / 17 / 3**
times — 27 total. Raw literals: **`lineWidth: 2` ×117, `lineWidth: 3` ×110, `lineWidth: 1` ×20** —
247 total. So **90% of the app's borders hardcode their width.**

The literals match the token values exactly, which is what makes this unambiguous: there is no
design intent being expressed, the tokens are just not reached for. `Layout.swift` is
documentation that the codebase does not consult.

Worth noting for context: the Flutter port on `feat/flutter-cross-platform` scores **150 token
uses and zero literals** on this same measure. The tokens work; adopting them is the open task.

**Recommendation.** Fold into S1 — if the width lives inside `.dsaBox(.primary)`, no call site can
hardcode it. A follow-up guard (a `grep` in CI, or SwiftLint's `custom_rules`) banning bare
`lineWidth:` outside `Theme/` keeps it from regressing.

### S3 — 192 of 211 buttons have no press feedback; spec 010 is unimplemented

**Severity: high.**

`specs/010_button-feedback/requirement.md` requires: "Upon a button press give a visual feedback to
the user by flipping the background and text colour quickly back and forth… This shall apply to
**all** buttons and pressable visual items."

Current state:

- **0** custom `ButtonStyle` implementations, **0** uses of `configuration.isPressed`.
- **192** `.buttonStyle(.plain)` against **211** `Button`s — and `.plain` removes SwiftUI's default
  press treatment.
- **0** shadows to press into (D1).

So roughly 91% of the app's buttons are visually inert on touch, by three independent mechanisms
at once. The 21 `.onTapGesture` sites have no feedback either, and being plain gestures they also
miss the accessibility affordances a `Button` provides.

**Recommendation.** Implement the colour-flip as a `ButtonStyle` — this is exactly what the
protocol is for, `configuration.isPressed` gives the state directly, and a single
`.buttonStyle(DSAPressStyle())` replaces all 192 `.plain`s. `DSAAnimation` already has
`standard = .easeOut(duration: 0.2)` and `diceTumbleInterval = 150ms`, so a ~120–160ms
flip-and-return fits the existing vocabulary.

Note this is a genuine adaptation, not a shortfall: the reference's translate-into-shadow press is
unavailable to a shadowless UI, so the colour-flip is the right substitute. It is also the one
finding here that is a *product* gap, not just an internal-quality one — it is the difference
between the app feeling responsive and feeling dead.

### S4 — No corner-radius token; 13 rounded outliers contradict the square-corner design

**Severity: medium.**

`DSALayout` has **no** corner-radius constant at all — the one geometry token the Flutter port
added (`cornerRadius = 4`) and this codebase lacks. Consequently all 10 radii are literals, and
they disagree:

- `cornerRadius: 6` ×6
- `cornerRadius: 8` ×4 — including `HeroDetailComponents.swift:23,25`
- `Capsule()` — `WeatherDayRow.swift:38`. A full pill; the most off-brand geometry in the app,
  and neobrutalism has no pill shapes. (The Flutter port carried this over as
  `BorderRadius.circular(999)`, so it will need fixing twice.)
- `Circle()` ×2 — `AdventureDetailView.swift:93,100`

Against 272 square strokes, these 13 read as accidents rather than as a deliberate accent.

**Recommendation.** The app has effectively already decided: square. Record that (a
`DSALayout.cornerRadius = 0`, or a comment in `Layout.swift` stating the app is square-cornered by
design), then bring the 13 outliers into line — or, if some genuinely want rounding, define one
token and use it for all of them. Either way the Capsule should go.

### S5 — Typography: 4 weights, 551 inline declarations, `.black` used 201 times

**Severity: medium.**

The spec allows exactly two weights (500 body, 700 heading). Actual usage, all via
`.font(.system(<textStyle>, weight:))`:

| Weight | Uses | vs spec |
|---|---|---|
| `.bold` (700) | 273 | on-spec (heading) |
| `.black` (900) | 201 | **heavier than the spec's maximum** |
| `.semibold` (600) | 52 | off-spec |
| `.medium` (500) | 25 | on-spec (body) |

Three observations:

1. **`.black` is the second-most-used weight.** 900 exceeds anything the reference sanctions, and
   because it is applied to `.body` 37 times and `.title3` 59 times, body-level text is frequently
   heavier than the headings above it.
2. **Only 25 uses of the spec's body weight.** The de-facto body weight is `.bold` — the app runs
   roughly one step heavier than the reference throughout. That is a legitimate brand choice, but
   it is an undeclared one.
3. **551 inline declarations, zero named styles.** There is no `DSAType.heading` / `.body`. The
   top three patterns alone — `.font(.system(.body, weight: .bold))` ×118,
   `.font(.system(.title3, weight: .black))` ×59, `.font(.system(.caption, weight: .bold))` ×48 —
   are 225 repetitions of three strings, the same copy-paste shape as S1.

**Recommendation.** Define named font tokens in `Theme/` (heading / body / caption / mono,
preserving the Dynamic Type base — see §5), collapse `.semibold` into its neighbours, and decide
deliberately whether the heading weight is 700 or 900 rather than having both.

### S6 — "No subtle greys" is violated at roughly 260 sites

**Severity: medium.**

The spec prohibits subtle greys outright. Sources, all of which produce exactly that:

- **`.secondary` ×133** — SwiftUI's secondary label is translucent black/white, i.e. a soft grey.
  It is the single most-used colour in the view layer.
- **`.gray` ×19** — flat off-brand grey.
- **`opacity()` ×109 across 13 distinct values** — 0.1 (×35), 0.3 (×18), 0.7 (×8), 0.85 (×6),
  0.5 (×6), 0.8 (×4), 0.35, 0.2, 0.08, 0.75, 0.25, 0.15, 0.12. None tokenised.

A token colour at 10% over a white surface *is* a pale grey, however it was spelled.
`DSAAnimation.animatingBackgroundOpacity = 0.15` shows the right instinct — an opacity that earned
a name — applied once out of 109 opportunities.

Not all of these should change; `.secondary` on genuinely secondary text is reasonable and
accessible. But the *fills* should be solid, and the recurring values (0.1 for tinted backgrounds,
0.3 for scrims) should become two or three named tokens so the set stops growing.

### S7 — Modal scrim: two values, both far lighter than the spec

**Severity: medium.**

The spec has one token, `--overlay: rgba(0,0,0,0.8)`. The app has 8 sites, two values, no token:

- `Color.black.opacity(0.5)` — `TalentProbeModal.swift:54`, `SkillCheckModal.swift:66`,
  `EditCurrentModal.swift:25`, `SpellProbeModal.swift:112,125`, `CommandPaletteOverlay.swift:292`
- `Color.black.opacity(0.3)` — `HeroDetailView.swift:90`, `HeroDetailComponents.swift:18`

With no shadow and no elevation, the scrim is the *only* cue that a modal floats above the content,
so under-weighting it costs more here than it would in a system that has other depth signals.

**Recommendation.** One `Color.dsaOverlay` token; raise it toward 0.8.

### S8 — `.background(.white)` breaks dark mode

**Severity: medium (concrete defect).**

`CombatRootView.swift:300` — a hardcoded, non-adaptive white behind `Color.groupMagic` text. Every
other surface in the app adapts via `UIColor.systemBackground` / `secondarySystemBackground` /
`UIColor.label`. This is the **only** hardcoded surface colour, so in dark mode it renders as a
bright white patch in an otherwise dark UI.

**Recommendation.** `Color(UIColor.systemBackground)`, or `secondarySystemBackground` if the intent
was a raised chip. One-line fix.

### S9 — System colours used where palette tokens already exist

**Severity: low.**

- `.green` ×6 and `.red` ×5 in `Views/`, although `Color.groupEquipment` (`#16A34A`) and
  `Color.groupCombat` (`#DC2626`) are the palette's exact equivalents and are used precisely this
  way by `successRateColor` (`AttributeColors.swift:66-72`).
- `AttributeColors.swift:53` — `attributeBackground(for:)` falls back to system `.yellow` rather
  than `Color.groupPersonalData` (`#F5C400`), the palette's own yellow. The Flutter port fixed this
  (it returns `groupPersonalData`), so the two apps disagree on an unknown attribute's colour.

**Recommendation.** Swap all twelve for the tokens. Mechanical, and it removes the last
non-palette hues from the view layer.

### S10 — The only blur in the app

**Severity: low.**

`HeroDetailComponents.swift:16` — `.blur(radius: 30)` on a scaled copy of the hero image, as the
backdrop of `AvatarFullscreenView`, under a `Color.black.opacity(0.3)` overlay.

This is the single breach of the "no blur" prohibition in 21k lines. In mitigation it is applied to
*photographic content* in a fullscreen viewer, not to UI chrome — the standard iOS photo-viewer
idiom. It is still the one place the app stops looking like itself.

**Recommendation.** A solid scrim (`Color.black`, or `dsaBorder` at full strength) would be
on-brand and cheaper to render. Low priority, but it is a two-line change. Note the same view also
carries two `cornerRadius: 8` literals and a `lineWidth: 3` literal (S2/S4).

### S11 — `adaptedForDarkBackground()` manufactures soft colours at runtime

**Severity: low.**

`AttributeColors.swift:76-84` desaturates (`min(s, 0.8)`) and brightens (`max(b, 0.55)`) a colour
via HSB to keep dark section colours legible on dark backgrounds. Used twice.

The readability goal is sound, but the mechanism generates *derived, softened* colours outside the
palette — against the "flat blocks of colour" principle, and unverifiable for contrast because the
output depends on the input. Two uses make this low-priority, but it is the kind of helper that
spreads.

**Recommendation.** Prefer explicit light/dark pairs in the palette (as `panelNotes`/`panelLogs`/
`panelRules` already do correctly at `AttributeColors.swift:15-26`) over runtime derivation.

### S12 — Spacing is ~3% tokenised

**Severity: low.**

560 literal `.padding(…)` calls with numeric values against **20** uses of `DSALayout`'s
`horizontalPadding` / `contentPadding` / `headerVerticalPadding`. The same pattern as S2, at a
larger scale but with lower visual stakes — inconsistent spacing reads as looseness rather than as
the wrong style.

---

## 5. What is genuinely good

These should not regress:

- **Consistent flatness.** 0 `.shadow()`, 0 gradients, 0 `Material`/`ultraThinMaterial` in 21k
  lines. For a SwiftUI app — where every stock control wants to add a soft background — that takes
  real discipline.
- **Dynamic Type throughout.** Fonts are declared as `.system(.body, weight:)`,
  `.system(.caption, weight:)` etc., so text scales with the user's accessibility settings. Only
  **15** fixed `.system(size:)` sizes exist in the whole app. This is a meaningful accessibility
  win, and notably *better* than the Flutter port, which uses raw `fontSize:` pixel values.
- **Correct monospace.** 121 uses of `design: .monospaced` — the real API, with no font-resolution
  risk. (The Flutter port regressed here to a raw `fontFamily: 'monospace'` string.)
- **A real two-tier surface system.** `UIColor.systemBackground` (97 uses) for the page and
  `secondarySystemBackground` (15 uses) for raised/unselected cells maps cleanly onto the spec's
  `--background` / `--secondary-background` split — something the Flutter port dropped by
  collapsing to a single surface.
- **Colour tokens are genuinely adopted.** `Color.dsaBorder` 263 uses; the group and attribute
  palettes are documented, deliberate, and honest about which accents adapt to dark mode
  (`AttributeColors.swift:15-26`) and which are fixed.
- **Adaptive semantics via system colours.** `UIColor.label` and `systemBackground` mean Increase
  Contrast, Smart Invert and dark mode work without bespoke handling.

---

## 6. Recommended order of work

| # | Action | Findings | Cost |
|---|---|---|---|
| 1 | Fix `.background(.white)` → `systemBackground` | S8 | XS |
| 2 | Swap `.green`/`.red`/`.yellow` for palette tokens | S9 | S |
| 3 | Add `Color.dsaOverlay` (≈0.8); apply to all 8 scrims | S7 | S |
| 4 | Decide + record square corners; fix the Capsule and the 10 literal radii | S4, D5 | S |
| 5 | Add `Theme/DSABox.swift` (`.dsaBox(.primary/.secondary/.tertiary)`); migrate the 202 copies | **S1, S2** | **L** |
| 6 | Implement the spec-010 colour flip as a `ButtonStyle`; replace the 192 `.plain` | S3 | M |
| 7 | Add named font tokens; collapse `.semibold`; settle 700-vs-900 for headings | S5 | M |
| 8 | Tokenise the recurring opacities; make tinted *fills* solid | S6 | M |
| 9 | Amend ADR-0002 to state the no-shadow choice and its departure from the reference | D1 | XS |
| 10 | CI guard banning bare `lineWidth:` / `opacity(` outside `Theme/` | S2, S6 | S |

Items 1–4 and 9 are independent and can land immediately; item 1 is a one-line bug fix. Item 5 is
the one large piece of work and it is what makes 6, 7 and 10 cheap — the 202 identical copies make
most of it a safe mechanical replacement.

Two decisions are yours before item 5 starts: whether headings are **700 or 900** (S5), and whether
the **1px border tier survives at all** (D3).

### A note on the Flutter port

Since both were measured against the same spec, the two codebases fail in opposite directions, and
neither should be ported wholesale:

| | SwiftUI (`main`) | Flutter (`feat/flutter-cross-platform`) |
|---|---|---|
| Border-width tokens | 27 token / **247 literal** | **150 token / 0 literal** |
| Corner-radius token | **none exists** | `cornerRadius = 4` exists |
| Font sizing | **Dynamic Type**, 15 fixed sizes | raw `fontSize:` pixels |
| Monospace | **`design: .monospaced`** | raw `'monospace'` string |
| Surface tiers | **two** | one |
| Style abstraction | none (202 copies) | none (99 hand-rolled boxes) |
| Spec 010 press feedback | missing | missing |

The port fixed the token discipline and added the radius token; it regressed on accessibility
(Dynamic Type) and on monospace. Worth reconciling in both directions during Phase 5 cutover
rather than treating either as the reference.

---

## Appendix: how the counts were produced

All figures from `main` @ 487ce37, run from the repository root. Representative commands, so any
number here can be re-checked:

```bash
# the headline: duplicated border idiom
grep -rhoE "\.overlay\(Rectangle\(\)\.stroke\(Color\.dsaBorder, lineWidth: [0-9]+\)\)" \
  Hesindion/Views | sort | uniq -c | sort -rn        # 97 / 95 / 10

# border tokens vs literals
for t in primaryBorder secondaryBorder tertiaryBorder; do
  printf "%s: " "$t"; grep -ro "DSALayout.$t" Hesindion | wc -l; done   # 7 / 17 / 3
grep -rhoE "lineWidth: [0-9.]+" Hesindion | sort | uniq -c | sort -rn   # 117x2, 110x3, 20x1

# abstraction layer
grep -rn "ViewModifier" Hesindion                     # 1 hit (AdaptiveContentWidth)
grep -rn "^extension View" Hesindion                  # 1 hit (same file)
grep -ro "\.overlay(" Hesindion | wc -l               # 290
grep -ro "\.background(" Hesindion | wc -l            # 295

# press feedback
grep -ro "buttonStyle(.plain)" Hesindion | wc -l      # 192
grep -roE "\bButton\(|\bButton \{" Hesindion/Views | wc -l   # 211
grep -ro "ButtonStyle\|isPressed" Hesindion | wc -l   # 0 custom

# typography
grep -rhoE "weight: \.[a-z]+" Hesindion/Views Hesindion/Theme | sort | uniq -c | sort -rn
grep -ro "\.system(size:" Hesindion/Views Hesindion/Theme | wc -l   # 15
grep -ro "monospaced" Hesindion/Views Hesindion/Theme | wc -l       # 121

# radius and shape
grep -rhoE "cornerRadius: [0-9.]+" Hesindion | sort | uniq -c       # 6x6, 4x8
grep -rn "Capsule()\|\.clipShape(Circle" Hesindion                  # 3 hits
grep -ro "Rectangle().stroke" Hesindion/Views | wc -l               # 272

# greys and prohibitions
grep -rhoE "\.(secondary|gray|primary)\b" Hesindion/Views | sort | uniq -c | sort -rn
grep -rhoE "opacity\(([0-9.]+)\)" Hesindion/Views Hesindion/Theme | sort | uniq -c | sort -rn
grep -rn "shadow(" Hesindion/Views Hesindion/Theme                  # none
grep -rn "Gradient\|\.blur(\|Material" Hesindion/Views Hesindion/Theme   # 1 hit (.blur)

# surfaces and spacing
grep -ro "UIColor.systemBackground" Hesindion | wc -l               # 97
grep -ro "secondarySystemBackground" Hesindion | wc -l              # 15
grep -roE "\.padding\((\.[a-z]+, )?[0-9]+\)" Hesindion/Views | wc -l        # 560
grep -roE "DSALayout\.(horizontalPadding|contentPadding|headerVerticalPadding)" Hesindion | wc -l  # 20
```

Spec values were read from `ds-bundle/_ds_bundle.css` and `ds-bundle/README.md` /
`.design-sync/conventions.md`; oklch was converted to sRGB for the table in §2.
