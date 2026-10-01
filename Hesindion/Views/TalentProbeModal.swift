import SwiftUI

// MARK: - TalentProbeModal

struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil
    /// The full result, for a caller that needs more than the pass/fail
    /// `onRolled` gives (rolls, quality level, criticals, remaining points).
    var onResult: ((SkillCheckResult) -> Void)? = nil
    var initialModifier: Int = 0
    /// The Selbstbeherrschung check a Wundeffekt demands, opened by
    /// `CombatTakeDamageView` (`CombatWoundEffectPanel` only shows its preview
    /// and asks to roll), which Verweichlicht (DISADV_57) makes harder. A
    /// free-standing check is not.
    var isWoundEffectProbe: Bool = false
    /// The colour the modal wears. A Talentprobe raised from the hero sheet is a
    /// personal-data thing; the same probe raised mid-fight is a combat thing,
    /// and arriving in the sheet's gold read as a different app's dialog.
    var accent: Color = .groupPersonalData

    /// "Vor der Probe" (sheet cut-over design §6): holds for this check only, so a modal built
    /// fresh for the next check starts with none of it.
    @State private var belastungChoices = TalentBelastung.Choices()
    @State private var showLoadoutSheet = false

    private var probeData: (keys: [String], values: [Int])? {
        guard let attrs = hero.attributes else { return nil }
        return TalentProbeAttributes.lookup(talent: talent.name, attributes: attrs)
    }

    /// The engine's `COND_1` lines for this talent, with the player's choices applied — `nil` on
    /// the wound-effect path, which stays exactly as it was (design §6 is the talent check).
    private var belastungResult: TalentBelastung.Result? {
        guard !isWoundEffectProbe else { return nil }
        return TalentBelastung.lines(hero: hero, talentId: talent.ruleId, choices: belastungChoices)
    }

    private var showVorDerProbe: Bool {
        !isWoundEffectProbe && TalentBelastung.isRelevant(hero: hero, talentId: talent.ruleId)
    }

    private var modifierLines: [ModifierLine] {
        let situation: Situation
        if isWoundEffectProbe {
            situation = Situation.woundEffectProbe(hero: hero, talentId: talent.ruleId)
        } else {
            var s = Situation(hero: hero, domain: .talentCheck)
            s.talentId = talent.ruleId
            situation = s
        }
        let base = ModifierEngine.shared.evaluate(context: situation)
        guard let belastung = belastungResult else { return base }
        // `TalentBelastung.combinedModifierLines` drops `evaluate`'s own −5 correction line (if
        // any) and reapplies the cap once over the combined list, so COND_1's line is capped with
        // everything else exactly once — see its doc comment and
        // `TalentBelastungTests.testTheCapAppliesOnceOverTheCombinedZustandLines`.
        return TalentBelastung.combinedModifierLines(base: base, belastung: belastung)
    }

    /// The struck `COND_1` lines "Belastung nicht anwenden" turned off: shown, but adding 0.
    private var struckLines: [ModifierLine] {
        guard let belastung = belastungResult, belastung.struck else { return [] }
        return belastung.lines
    }

    /// Aufmerksamkeit (SA_40) eases the *Sinnesschärfe* check that avoids being surprised —
    /// TAL_10, not TAL_8 (Selbstbeherrschung, the wound-effect probe). The GM decides whether a
    /// check is one of those, so the +2 is a switch that starts off (issue #43), not a hint the
    /// player has to add by hand.
    static func gmBonus(hero: Hero, talent: Talent) -> ModifierLine? {
        guard hero.hasAufmerksamkeit, talent.ruleId == Talent.sinnesschaerfeRuleId else { return nil }
        return ModifierLine(
            value: 2,
            source: L("aufmerksamkeit.surprise"),
            ruleId: CombatAbility.aufmerksamkeit.rawValue
        )
    }

    var body: some View {
        if let data = probeData {
            SkillCheckModal(
                config: SkillCheckConfig(
                    title: L("probe"),
                    name: talent.name,
                    skillValue: talent.value,
                    checkAttributes: zip(data.keys, data.values).map { (key: $0, value: $1) },
                    accentColor: accent,
                    modifierLines: modifierLines,
                    logKind: "talentCheck",
                    struckLines: struckLines
                ),
                hero: hero,
                onDismiss: onDismiss,
                onResult: { result in onRolled?(result.succeeded); onResult?(result) },
                initialModifier: initialModifier,
                preRoll: showVorDerProbe ? {
                    AnyView(
                        VorDerProbeRow(
                            hero: hero,
                            talentId: talent.ruleId,
                            choices: $belastungChoices,
                            accent: accent,
                            onOpenLoadout: { showLoadoutSheet = true }
                        )
                    )
                } : nil,
                gmBonus: Self.gmBonus(hero: hero, talent: talent)
            )
            // The app's loadout picker today is a screen inside the combat-preparation flow
            // (`CombatArmorPicker`, in `CombatSetupView`), not a standalone one this floating
            // modal can push to — this system sheet is the closest reuse without restyling it,
            // and it covers armour only; the shield goes through `CombatLoadoutPicker` in combat.
            .sheet(isPresented: $showLoadoutSheet) {
                NavigationStack {
                    ScrollView {
                        CombatArmorPicker(hero: hero)
                            .padding()
                    }
                    .navigationTitle(L("armorSelection.label"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L("close")) { showLoadoutSheet = false }
                        }
                    }
                }
            }
        } else {
            ZStack {
                Color.dsaOverlay
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
                Text(L("unknownTalent"))
                    .padding()
            }
        }
    }
}
