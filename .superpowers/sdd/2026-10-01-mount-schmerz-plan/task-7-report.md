# Task 7 report

Implemented: MountValues.statusText(name:) and MountValues.schmerzNote(_:) (COND_6 line, L key mount.at.schmerzNote); strings (4 keys, de+en); root status line (combat.mount.schmerz); mount actions (engine AT, disabled at Schmerz IV, dimmed to 0.45 opacity, reason line combat.mount.blockedReason); Niederreiten AT from engine/own line; Sturmangriff subtitle shows no bonus label when the line is nil; DamageModifiers comment reworded. Roman numeral uses existing StateCatalog.roman.

TDD: RED = "MountValues has no member statusText" (make test-only ONLY=HesindionTests/MountValuesTests). GREEN: MountValuesTests 5 tests 0 failures; DamageModifiersTests 11 tests 0 failures; CombatRootViewSnapshotTests 4 tests 0 failures (after first-run auto-recording; the class has no record switch, SnapshotTesting records missing references).

Snapshots (24 PNGs each) in HesindionTests/Snapshots/__Snapshots__/CombatRootViewSnapshotTests/: testRootWithAMountInPain.mountInPain_* (viewed iPad11 light: Kupperus "Schmerz II · GS 14" under name, LP 60/137); testMountActionsAtSchmerzIV.mountActionsSchmerzIV_* (viewed: hero Einhaendig/Zweihaendig enabled; Tritt, Niederreiten, Sturmangriff greyed; red "Kupperus: Schmerz IV - handlungsunfaehig" line). Re-recorded once after adding a selected weapon to the test hero (otherwise Sturmangriff was not offered).

Files: Hesindion/{Engine/DamageModifiers,RulesEngine/MountValues,Theme/Strings,Views/CombatAttackViews,Views/CombatRootView}.swift; HesindionTests/MountValuesTests.swift, HesindionTests/Snapshots/CombatRootViewSnapshotTests.swift + PNGs.

Concerns: schmerzNote shows the signed engine value ("Schmerz -1"), per ruling; the engine's COND_6 rule id is taken from the brief and not covered by a test. Dimming (opacity) is my addition so disabled is visible.
