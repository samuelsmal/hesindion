import SwiftUI

// MARK: - TalentProbeModal

struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil
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

    private var probeData: (keys: [String], values: [Int])? {
        guard let attrs = hero.attributes else { return nil }
        return TalentProbeAttributes.lookup(talent: talent.name, attributes: attrs)
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
        return ModifierEngine.shared.evaluate(context: situation)
    }

    private var hints: [SkillCheckHint] {
        var result: [SkillCheckHint] = []
        // Aufmerksamkeit (SA_40) eases the *Sinnesschärfe* check that avoids being
        // surprised — TAL_10. TAL_8 is Selbstbeherrschung, so the hint was
        // offered on every wound-effect probe in combat, where it does not apply.
        if hero.hasAufmerksamkeit && talent.ruleId == Talent.sinnesschaerfeRuleId {
            result.append(SkillCheckHint(
                icon: "info.circle.fill",
                text: L("aufmerksamkeitHint"),
                color: accent
            ))
        }
        return result
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
                    logKind: "talentCheck"
                ),
                hero: hero,
                onDismiss: onDismiss,
                onResult: { result in onRolled?(result.succeeded) },
                initialModifier: initialModifier,
                hints: hints
            )
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
