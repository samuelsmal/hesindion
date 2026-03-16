import SwiftUI
import SwiftData

// MARK: - CombatFernkampfSetupView

struct CombatFernkampfSetupView: View {
    let hero: Hero
    @Binding var step: CombatStep
    let mountedActive: Bool
    let beengteUmgebungActive: Bool
    let schipIgnoreZustandThisRound: Bool
    var onDismiss: () -> Void

    @State private var distanz: Int = 1         // 0=nah, 1=mittel, 2=weit
    @State private var groesse: Int = 2         // 0=winzig..4=riesig
    @State private var bewegungZiel: Int = 1    // 0=still..3=haken
    @State private var bewegungSchuetze: Int = 0 // 0=steht..2=rennt
    @State private var sicht: Int = 0           // 0=klar..3=stufe3
    @State private var kampfgetuemmel: Bool = false
    @State private var zielen: Int = 0          // 0/1/2 actions
    @State private var vomPferd: Int = 0        // 0=steht, 1=schritt, 2=galopp

    // MARK: - Modifier computation (non-ViewBuilder helpers)

    private func buildModifierLines() -> [ModifierLine] {
        var lines: [ModifierLine] = []

        let distanzMods = [2, 0, -2]
        if distanzMods[distanz] != 0 {
            lines.append(ModifierLine(value: distanzMods[distanz], source: L("source.distanz")))
        }

        let groesseMods = [-8, -4, 0, 4, 8]
        if groesseMods[groesse] != 0 {
            lines.append(ModifierLine(value: groesseMods[groesse], source: L("source.groesse")))
        }

        let bewegungZielMods = [2, 0, -2, -4]
        if bewegungZielMods[bewegungZiel] != 0 {
            lines.append(ModifierLine(value: bewegungZielMods[bewegungZiel], source: L("source.bewegungZiel")))
        }

        let bewegungSchuetzeMods = [0, -2, -4]
        if bewegungSchuetzeMods[bewegungSchuetze] != 0 {
            lines.append(ModifierLine(value: bewegungSchuetzeMods[bewegungSchuetze], source: L("source.bewegungSchuetze")))
        }

        let sichtMods = [0, -2, -4, -6]
        if sichtMods[sicht] != 0 {
            lines.append(ModifierLine(value: sichtMods[sicht], source: L("source.sicht")))
        }

        if kampfgetuemmel {
            lines.append(ModifierLine(value: -2, source: L("source.kampfgetuemmel")))
        }

        let zielenMods = [0, 2, 4]
        if zielenMods[zielen] != 0 {
            lines.append(ModifierLine(value: zielenMods[zielen], source: L("source.zielen")))
        }

        if mountedActive {
            let pferdMods = [0, -4, -8]
            if pferdMods[vomPferd] != 0 {
                lines.append(ModifierLine(value: pferdMods[vomPferd], source: L("source.vomPferd")))
            }
        }

        // Belastung (mounted heroes get -1 BE)
        let be = mountedActive ? max(0, hero.effectiveBE - 1) : hero.effectiveBE
        if be > 0 {
            lines.append(ModifierLine(value: -be, source: L("source.belastung")))
        }

        // Schmerz
        if !schipIgnoreZustandThisRound && hero.schmerzPenalty != 0 {
            let level = hero.effectiveSchmerzLevel
            lines.append(ModifierLine(value: hero.schmerzPenalty, source: "\(L("source.schmerz")) \(level > 0 ? String(repeating: "I", count: min(level, 4)) : "")"))
        }

        // Note: Beengte Umgebung does NOT apply to ranged combat

        return lines
    }

    private var distanzTP: Int {
        switch distanz {
        case 0: return 1   // nah: +1 TP
        case 2: return -1  // weit: -1 TP
        default: return 0
        }
    }

    private var totalModifier: Int {
        buildModifierLines().reduce(0) { $0 + $1.value }
    }

    private var effectiveFK: Int {
        (hero.selectedRangedWeapon?.at ?? 0) + totalModifier
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    distanzSection
                    groesseSection
                    bewegungZielSection
                    bewegungSchuetzeSection
                    sichtSection
                    kampfgetuemmelSection
                    zielenSection
                    if mountedActive {
                        vomPferdSection
                    }
                    modifierSummary
                }
                .adaptiveContentWidth()
                .padding(.bottom, 16)
            }

            continueButton
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { step = .root } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(L("fernkampf.setup"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
                if let weapon = hero.selectedRangedWeapon {
                    Text(weapon.name)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

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
    }

    // MARK: - Distanz Section

    private var distanzSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.distanz"))

            HStack(spacing: 8) {
                let labels = [L("fernkampf.distanz.nah"), L("fernkampf.distanz.mittel"), L("fernkampf.distanz.weit")]
                let mods = ["+2", "\u{00B1}0", "\u{2013}2"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: distanz == i) {
                        distanz = i
                    }
                }
            }

            if distanzTP != 0 {
                tpHint(distanzTP)
            }
        }
    }

    // MARK: - Größe Section

    private var groesseSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.groesse"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.groesse.winzig"),
                    L("fernkampf.groesse.klein"),
                    L("fernkampf.groesse.mittel"),
                    L("fernkampf.groesse.gross"),
                    L("fernkampf.groesse.riesig")
                ]
                let mods = ["\u{2013}8", "\u{2013}4", "\u{00B1}0", "+4", "+8"]
                ForEach(0..<5, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: groesse == i) {
                        groesse = i
                    }
                }
            }
        }
    }

    // MARK: - Bewegung Ziel Section

    private var bewegungZielSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.bewegungZiel"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.ziel.still"),
                    L("fernkampf.ziel.leicht"),
                    L("fernkampf.ziel.schnell"),
                    L("fernkampf.ziel.haken")
                ]
                let mods = ["+2", "\u{00B1}0", "\u{2013}2", "\u{2013}4"]
                ForEach(0..<4, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: bewegungZiel == i) {
                        bewegungZiel = i
                    }
                }
            }
        }
    }

    // MARK: - Bewegung Schütze Section

    private var bewegungSchuetzeSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.bewegungSchuetze"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.schuetze.steht"),
                    L("fernkampf.schuetze.geht"),
                    L("fernkampf.schuetze.rennt")
                ]
                let mods = ["\u{00B1}0", "\u{2013}2", "\u{2013}4"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: bewegungSchuetze == i) {
                        bewegungSchuetze = i
                    }
                }
            }
        }
    }

    // MARK: - Sicht Section

    private var sichtSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.sicht"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.sicht.klar"),
                    L("fernkampf.sicht.stufe1"),
                    L("fernkampf.sicht.stufe2"),
                    L("fernkampf.sicht.stufe3")
                ]
                let mods = ["\u{00B1}0", "\u{2013}2", "\u{2013}4", "\u{2013}6"]
                ForEach(0..<4, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: sicht == i) {
                        sicht = i
                    }
                }
            }
        }
    }

    // MARK: - Kampfgetümmel Section

    private var kampfgetuemmelSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.kampfgetuemmel"))

            Button {
                kampfgetuemmel.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: kampfgetuemmel ? "checkmark.square.fill" : "square")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(kampfgetuemmel ? combatAccent : .secondary)
                    Text(L("fernkampf.kampfgetuemmel"))
                        .font(.system(.body, weight: kampfgetuemmel ? .bold : .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\u{2013}2")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(kampfgetuemmel ? combatAccent : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(kampfgetuemmel ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
                .overlay(Rectangle().stroke(kampfgetuemmel ? combatAccent : Color.dsaBorder, lineWidth: kampfgetuemmel ? 3 : 2))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Zielen Section

    private var zielenSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.zielen"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.zielen.0"),
                    L("fernkampf.zielen.1"),
                    L("fernkampf.zielen.2")
                ]
                let mods = ["\u{00B1}0", "+2", "+4"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: zielen == i) {
                        zielen = i
                    }
                }
            }
        }
    }

    // MARK: - Vom Pferd Section

    private var vomPferdSection: some View {
        VStack(spacing: 0) {
            combatSectionLabel(L("fernkampf.vomPferd"))

            HStack(spacing: 8) {
                let labels = [
                    L("fernkampf.pferd.steht"),
                    L("fernkampf.pferd.schritt"),
                    L("fernkampf.pferd.galopp")
                ]
                let mods = ["\u{00B1}0", "\u{2013}4", "\u{2013}8"]
                ForEach(0..<3, id: \.self) { i in
                    segmentButton(label: labels[i], mod: mods[i], isSelected: vomPferd == i) {
                        vomPferd = i
                    }
                }
            }
        }
    }

    // MARK: - Modifier Summary

    private var modifierSummary: some View {
        let lines = buildModifierLines()
        let baseFK = hero.selectedRangedWeapon?.at ?? 0
        return VStack(spacing: 0) {
            if !lines.isEmpty {
                combatSectionLabel(L("calculation.label"))

                VStack(spacing: 0) {
                    // Base FK row
                    modSummaryRow(label: "FK \(L("source.basis"))", value: baseFK, isBase: true)

                    ForEach(lines) { line in
                        modSummaryRow(label: line.source, value: line.value, isBase: false)
                    }

                    Divider()
                        .background(Color.dsaBorder)
                        .padding(.vertical, 4)

                    // Total
                    HStack {
                        Text("FK \(L("fernkampf"))")
                            .font(.system(.body, weight: .black))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(effectiveFK)")
                            .font(.system(.title3, weight: .black))
                            .fontDesign(.monospaced)
                            .foregroundStyle(effectiveFK < baseFK ? .red : (effectiveFK > baseFK ? combatAccent : .primary))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            guard let weapon = hero.selectedRangedWeapon else { return }
            let mods = buildModifierLines()
            let fk = weapon.at + mods.reduce(0) { $0 + $1.value }
            step = .fernkampfExecution(
                weaponName: weapon.name,
                attributeValue: fk,
                damageFormula: weapon.damage,
                distanzTP: distanzTP,
                modifierLines: mods
            )
        } label: {
            Text(L("continue"))
                .font(.system(.title3, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(hero.selectedRangedWeapon != nil ? combatAccent : Color.gray)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .disabled(hero.selectedRangedWeapon == nil)
    }

    // MARK: - Reusable sub-view helpers (non-@ViewBuilder returning some View)

    private func segmentButton(label: String, mod: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, weight: .bold))
                Text(mod)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
    }

    private func modSummaryRow(label: String, value: Int, isBase: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: isBase ? .bold : .regular))
                .foregroundStyle(isBase ? .primary : .secondary)
            Spacer()
            Text(isBase ? "\(value)" : (value >= 0 ? "+\(value)" : "\(value)"))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(value < 0 ? .red : (value > 0 ? combatAccent : .secondary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tpHint(_ tp: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(.caption2, weight: .semibold))
            Text("\(L("tp")) \(tp > 0 ? "+\(tp)" : "\(tp)")")
                .font(.system(.caption, weight: .semibold))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
