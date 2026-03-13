# Reiterkampf Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Niederreiten and Sturmangriff zu Pferd into the combat flow, moving mount attacks from the combat root view into the attack selection screen with Galopp confirmation and Reiten check prerequisites.

**Architecture:** Extend `CombatAttackChoiceView` to show a "REITTIER-ANGRIFFE" section when mounted. Add a new `CombatStep.mountPreCheck` step for the Galopp confirmation and Reiten check flow. Remove the mount attacks section from `CombatRootView`. Sturmangriff zu Pferd remains a `CombatManeuver` (existing `.sturmangriff` case). Niederreiten flows as a direct mount attack.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

**Design Doc:** `docs/plans/2026-03-13-reiterkampf-design.md`

---

### Task 1: Add localized strings for Reiterkampf flow

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add new string keys**

Add these keys to both the English and German dictionaries in `Strings.swift`:

English (in `en` dictionary):
```swift
"galoppConfirm":        "Is your mount in gallop?",
"reitenCheck":          "Reiten (Kampfmanöver) Check",
"reitenCheckPrompt":    "Did the Reiten check succeed?",
"niederreiten":         "Trample",
"niederreiten.info":    "Trample can only be defended by dodging.",
"sturmangriffPferd":    "Mounted Charge",
"sturmangriffPferd.info": "Mounted Charge cannot be parried with weapons — only shield parry or dodge.",
"mountAttacksGroup":    "MOUNT ATTACKS",
"heroAttacksGroup":     "YOUR ATTACKS",
```

German (in `de` dictionary):
```swift
"galoppConfirm":        "Ist dein Reittier im Galopp?",
"reitenCheck":          "Reiten (Kampfmanöver)-Probe",
"reitenCheckPrompt":    "Wurde die Reiten-Probe bestanden?",
"niederreiten":         "Niederreiten",
"niederreiten.info":    "Niederreiten kann nur durch Ausweichen verteidigt werden.",
"sturmangriffPferd":    "Sturmangriff zu Pferd",
"sturmangriffPferd.info": "Sturmangriff zu Pferd kann nicht mit Waffen pariert werden — nur Schildparade oder Ausweichen.",
"mountAttacksGroup":    "REITTIER-ANGRIFFE",
"heroAttacksGroup":     "EIGENE ANGRIFFE",
```

**Step 2: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add Reiterkampf localized strings"
```

---

### Task 2: Add mountPreCheck CombatStep and Galopp/Reiten check view

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatStep enum, CombatView body)

**Step 1: Extend CombatStep enum**

Add a new case to `CombatStep` (line ~21, before `takeDamage`):

```swift
case mountPreCheck(onSuccess: CombatStep)
```

This step stores the "next step" to navigate to after passing both checks.

**Step 2: Add stepID case**

In the `stepID` computed property (~line 59-73), add:

```swift
case .mountPreCheck: "mountPreCheck"
```

**Step 3: Add case to CombatView body switch**

In the `body` switch statement (~line 77-186), add between `dualAttackSecond` and `takeDamage`:

```swift
case .mountPreCheck(let onSuccess):
    CombatMountPreCheckView(
        hero: hero,
        onSuccess: onSuccess,
        step: $step,
        onDismiss: onDismiss
    )
    .transition(.move(edge: .trailing))
```

**Step 4: Handle drag-back gesture**

In the drag gesture handler (~line 191+), add a case:

```swift
case .mountPreCheck:
    step = .attackChoice
```

**Step 5: Write CombatMountPreCheckView**

Add a new private struct at the end of the file (before the last closing brace). This view has two phases: Galopp confirmation, then Reiten check confirmation.

```swift
// MARK: - CombatMountPreCheckView

private struct CombatMountPreCheckView: View {
    let hero: Hero
    let onSuccess: CombatStep
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var galoppConfirmed = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .attackChoice } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("reitenCheck"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))

            Spacer()

            if !galoppConfirmed {
                galoppCheck
            } else {
                reitenCheck
            }

            Spacer()
        }
    }

    private var galoppCheck: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.equestrian.sports")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(L("galoppConfirm"))
                .font(.system(.title3, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
                } label: {
                    Text(L("no"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(DSAAnimation.standard) {
                        galoppConfirmed = true
                    }
                } label: {
                    Text(L("yes"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
    }

    private var reitenCheck: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheckPrompt"))
                .font(.system(.title3, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
                } label: {
                    Text(L("no"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button {
                    step = onSuccess
                } label: {
                    Text(L("yes"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
    }
}
```

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add mount pre-check flow (Galopp + Reiten confirmation)"
```

---

### Task 3: Add mount attacks to CombatAttackChoiceView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatAttackChoiceView, ~line 916-1088)

The `CombatAttackChoiceView` currently shows grip/dual-wield options. When mounted, it must also show a "REITTIER-ANGRIFFE" section with: regular mount attacks, Niederreiten, and Sturmangriff zu Pferd.

**Step 1: Pass mountedActive and hero's mount data**

Add parameters to `CombatAttackChoiceView`:

```swift
let mountedActive: Bool
```

Update the call site in `CombatView.body` (~line 119) to pass:

```swift
CombatAttackChoiceView(
    hero: hero,
    step: $step,
    dualAttackPenaltyActive: $dualAttackPenaltyActive,
    twoHandedGripActive: $twoHandedGripActive,
    mountedActive: mountedActive,
    onDismiss: onDismiss
)
```

**Step 2: Restructure the body to always show weapon options + mount section**

Replace the current `ScrollView` content in the body (~line 963-977). The view should always show the hero's attack options (existing logic), and when mounted, add mount attacks below.

Change the body's ScrollView to:

```swift
ScrollView {
    VStack(spacing: 8) {
        // Hero attack options (existing logic)
        if isDualWield {
            dualWieldOptions
        } else if canUseTwoHanded {
            gripOptions
        } else {
            // Single weapon, no special choice needed — show as direct option
            heroSingleAttackOption
        }

        // Mount attacks (when mounted)
        if mountedActive, let mount = hero.pets.first {
            mountAttackSection(mount: mount)
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 16)
}
```

Remove the `Color.clear.onAppear { proceedSingleAttack() }` in the else branch — instead show a tappable button for the single weapon so the user can also see mount options.

**Step 3: Add heroSingleAttackOption computed property**

```swift
private var heroSingleAttackOption: some View {
    VStack(spacing: 8) {
        combatSectionLabel(L("heroAttacksGroup"))

        if let w = hero.selectedWeapon {
            choiceButton(
                title: w.name,
                subtitle: "AT \(w.at) · TP \(w.damage)",
                icon: "hand.raised.fill"
            ) {
                proceedSingleAttack()
            }
        } else if hero.selectedWeaponName == "Raufen" {
            let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
            choiceButton(
                title: "Raufen",
                subtitle: "AT \(raufen?.at ?? 0) · TP 1W6",
                icon: "hand.raised.fill"
            ) {
                proceedSingleAttack()
            }
        }
    }
}
```

**Step 4: Also add section label to dualWieldOptions and gripOptions**

In `dualWieldOptions` and `gripOptions`, change the section label from `L("attack")` to `L("heroAttacksGroup")` so both groups use the same label when mount attacks are visible.

Only change these labels when `mountedActive` is true. Wrap with a conditional:

```swift
// In dualWieldOptions and gripOptions, replace:
combatSectionLabel(L("attack"))
// with:
combatSectionLabel(mountedActive ? L("heroAttacksGroup") : L("attack"))
```

**Step 5: Add mountAttackSection**

This builds the "REITTIER-ANGRIFFE" section with regular attacks, Niederreiten, and Sturmangriff zu Pferd.

```swift
private func mountAttackSection(mount: Pet) -> some View {
    VStack(spacing: 8) {
        combatSectionLabel(L("mountAttacksGroup"))

        // Regular mount attacks (Hufschlag, Tritt, Biss, etc.)
        ForEach(mount.attacks, id: \.name) { attack in
            let mightyBlowNote: String? = {
                guard mount.specialSkills.contains("Mächtiger Schlag") else { return nil }
                let kk = mount.attributes.kk
                let penalty = (kk - 20) / 2
                if penalty > 0 {
                    return String(format: L("mightyBlow"), penalty)
                } else {
                    return L("mightyBlowNoPenalty")
                }
            }()

            choiceButton(
                title: "\(mount.name): \(attack.name)",
                subtitle: "AT \(attack.at) · TP \(attack.damage)",
                icon: "pawprint.fill"
            ) {
                step = .execution(
                    .angriff,
                    name: "\(mount.name): \(attack.name)",
                    attributeValue: attack.at,
                    damageFormula: attack.damage,
                    note: mightyBlowNote,
                    modifierLines: nil
                )
            }
        }

        // Niederreiten
        let niederreitenAT = mount.attacks.first?.at ?? 0
        let niederreitenAttack = mount.attacks.first { $0.name == "Niederreiten" }
        let niederreitenDamage = niederreitenAttack?.damage ?? mount.damage

        let mightyBlowNote: String? = {
            guard mount.specialSkills.contains("Mächtiger Schlag") else { return nil }
            let kk = mount.attributes.kk
            let penalty = (kk - 20) / 2
            if penalty > 0 {
                return String(format: L("mightyBlow"), penalty)
            } else {
                return L("mightyBlowNoPenalty")
            }
        }()
        let niederreitenNote = [L("niederreiten.info"), mightyBlowNote]
            .compactMap { $0 }
            .joined(separator: "\n")

        choiceButton(
            title: L("niederreiten"),
            subtitle: "AT \(niederreitenAT) · TP \(niederreitenDamage)",
            icon: "figure.equestrian.sports"
        ) {
            let successStep = CombatStep.execution(
                .angriff,
                name: "\(mount.name): \(L("niederreiten"))",
                attributeValue: niederreitenAT,
                damageFormula: niederreitenDamage,
                note: niederreitenNote,
                modifierLines: nil
            )
            step = .mountPreCheck(onSuccess: successStep)
        }

        // Sturmangriff zu Pferd (requires Berittener Kampf)
        if hero.hasBerittenerKampf, let w = hero.selectedWeapon {
            let damageBonus = hero.sturmangriffDamageBonus
            let bonusLabel = damageBonus >= 0 ? "+\(damageBonus)" : "\(damageBonus)"
            choiceButton(
                title: L("sturmangriffPferd"),
                subtitle: "\(w.name) · AT \(w.at) · TP \(w.damage) \(bonusLabel)",
                icon: "bolt.fill"
            ) {
                let successStep = CombatStep.announcement(
                    .angriff,
                    name: w.name,
                    baseAT: w.at,
                    damageFormula: w.damage,
                    isOffHand: false,
                    secondAttack: nil
                )
                step = .mountPreCheck(onSuccess: successStep)
            }
        }

        // Mount special skills note
        if !mount.specialSkills.isEmpty {
            Text("\u{24D8} \(mount.specialSkills)")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(combatAccent)
                .padding(.horizontal, 16)
                .padding(.top, 2)
        }
    }
}
```

**Note on Sturmangriff zu Pferd:** It routes to `.announcement` (not directly to `.execution`) so the maneuver selection step applies the Sturmangriff damage bonus via the existing `adjustedDamage()` logic in `CombatAnnouncementView`. The `.sturmangriff` maneuver should be auto-selected when coming from this path — see Task 4.

**Step 6: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: add mount attacks to attack choice view"
```

---

### Task 4: Auto-select Sturmangriff maneuver for Sturmangriff zu Pferd

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatAnnouncementView)

When Sturmangriff zu Pferd routes through `.mountPreCheck` → `.announcement`, the announcement view should auto-select the `.sturmangriff` maneuver and show its info text. Currently, the user must manually pick it from the maneuver list.

**Step 1: Add flag to announcement step**

Extend the `.announcement` case to include a `forceSturmangriff` flag. This is the cleanest approach but touches many call sites. Alternatively, detect it from context: if `mountedActive && hasBerittenerKampf` and the announcement was reached, the user already chose Sturmangriff zu Pferd.

Simpler approach: In `CombatAnnouncementView`, add an `onAppear` check. If the view appears and the only reason it could appear while mounted with Berittener Kampf is from Sturmangriff zu Pferd (since regular mount attacks skip announcement), auto-set the maneuver:

In `CombatAnnouncementView.body`, add to the outermost VStack:

```swift
.onAppear {
    if mountedActive && hero.hasBerittenerKampf {
        selectedManeuver = .sturmangriff
    }
}
```

Wait — this would also trigger for regular weapon attacks while mounted. We need a way to distinguish. Let's add an `isSturmangriffZuPferd` parameter instead.

**Revised approach:** Add a `Bool` parameter `isMountCharge` to `CombatAnnouncementView` (default `false`). Set it to `true` only from the Sturmangriff zu Pferd path. When `true`, auto-select `.sturmangriff` and hide the maneuver picker (since the maneuver is already decided).

Add parameter:

```swift
let isMountCharge: Bool
```

In the `CombatStep.announcement` case, add a `Bool` field:

```swift
case announcement(CombatAction, name: String, baseAT: Int, damageFormula: String?, isOffHand: Bool, secondAttack: (name: String, at: Int, damage: String?)?, isMountCharge: Bool = false)
```

Update the single call site in Task 3's Sturmangriff zu Pferd to pass `isMountCharge: true`.

In `CombatAnnouncementView`:
- When `isMountCharge`, set `selectedManeuver = .sturmangriff` in `.onAppear`
- Hide the maneuver picker when `isMountCharge`
- Show the `sturmangriffPferd.info` note

Update `CombatView.body` to pass `isMountCharge` through to `CombatAnnouncementView`.

All other existing `.announcement(...)` call sites get `isMountCharge: false` via default parameter.

**Step 2: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: auto-select Sturmangriff maneuver for mounted charge"
```

---

### Task 5: Remove mount attacks from CombatRootView

**Files:**
- Modify: `Hesindion/Views/CombatView.swift` (CombatRootView, ~line 1656-1709)

**Step 1: Delete mount attacks section**

Remove the entire block from line ~1656 to ~1709:

```swift
// Mount attacks
if mountedActive, let mount = hero.pets.first, !mount.attacks.isEmpty {
    // ... entire section including ForEach and specialSkills note
}
```

This section is now rendered in `CombatAttackChoiceView`.

**Step 2: Verify build**

```bash
make build
```

**Step 3: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "refactor: remove mount attacks from combat root view"
```

---

### Task 6: Update CombatAttackChoiceView routing for non-mounted single-weapon

**Files:**
- Modify: `Hesindion/Views/CombatView.swift`

Currently, `CombatAttackChoiceView` is only shown when `isDualWield || canUseTwoHanded` (the `.attackChoice` step is conditionally navigated to). When not dual-wielding and not two-handed eligible, the root view skips straight to `weaponSelection` or `announcement`.

Now that mount attacks live in `CombatAttackChoiceView`, the attack choice screen must ALWAYS be shown when mounted (even for single-weapon, non-two-handed cases), so the user can choose between their weapon and mount attacks.

**Step 1: Find where attackChoice is conditionally entered**

Find the button/logic in `CombatRootView` that navigates to `.attackChoice` vs skipping it. Update the condition:

```swift
// Old: only show attackChoice when dual-wield or two-handed eligible
// New: also show when mountedActive
```

The condition should become: `isDualWield || canUseTwoHanded || mountedActive`.

Pass `mountedActive` to `CombatAttackChoiceView` (already done in Task 3).

**Step 2: Commit**

```bash
git add Hesindion/Views/CombatView.swift
git commit -m "feat: always show attack choice screen when mounted"
```

---

### Task 7: Build, test on simulator, update docs

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Build**

```bash
make build
```

**Step 2: Run on simulator**

```bash
make run
```

Test the following scenarios:
1. Enter combat mounted → attack → see "EIGENE ANGRIFFE" and "REITTIER-ANGRIFFE" groups
2. Select a regular mount attack (Hufschlag) → goes directly to execution
3. Select Niederreiten → Galopp confirmation → Reiten check → execution with info note
4. Select Sturmangriff zu Pferd → Galopp confirmation → Reiten check → announcement with auto-selected Sturmangriff → execution with damage bonus
5. Select hero weapon attack → normal flow (announcement → execution)
6. Verify mount attacks no longer show in combat root view
7. Non-mounted combat still works normally

**Step 3: Update CHANGELOG.md**

Add under `[Unreleased]`:

```markdown
### Added
- Niederreiten and Sturmangriff zu Pferd in attack selection screen
- Galopp confirmation and Reiten (Kampfmanöver) check flow for mounted charges
- Mount attacks grouped in attack choice view alongside hero attacks

### Changed
- Moved mount attacks from combat root view to attack selection screen
```

**Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for Reiterkampf integration"
```
