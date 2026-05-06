import SwiftUI

// MARK: - TalentProbeModal

struct TalentProbeModal: View {
    let talent: Talent
    let hero: Hero
    var onDismiss: () -> Void
    var onRolled: ((Bool) -> Void)? = nil
    var initialModifier: Int = 0

    private var probeData: (keys: [String], values: [Int])? {
        guard let attrs = hero.attributes else { return nil }
        return TalentProbeAttributes.lookup(talent: talent.name, attributes: attrs)
    }

    private var modifierLines: [ModifierLine] {
        let context = ModifierContext(hero: hero, domain: .talentCheck)
        return ModifierEngine.shared.evaluate(context: context)
    }

    private var hints: [SkillCheckHint] {
        var result: [SkillCheckHint] = []
        if hero.hasAufmerksamkeit && talent.ruleId == "TAL_8" {
            result.append(SkillCheckHint(
                icon: "info.circle.fill",
                text: L("aufmerksamkeitHint"),
                color: .groupPersonalData
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
                    accentColor: .groupPersonalData,
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
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
                Text(L("unknownTalent"))
                    .padding()
            }
        }
    }
}
