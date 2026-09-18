import SwiftUI

/// What the hero has in their hands: up to two of weapon, shield or fist, plus a
/// ranged weapon slung.
///
/// Extracted from `CombatLoadoutEquipmentView` because the preparation screen
/// asks the same question before the fight starts and that screen only ever
/// showed Plänkler, mount and Beengte Umgebung — the loadout came two steps
/// later, after the initiative had already been rolled.
struct CombatLoadoutPicker: View {
    let hero: Hero
    let mountedActive: Bool
    @Binding var selected: Set<String>
    @Binding var selectedRanged: String?

    /// One selectable thing, with everything the rows and the rules need.
    struct Item {
        let name: String
        let detail: String
        let note: String?
        let icon: WeaponIcon
        let isShield: Bool
        let isRaufen: Bool
        let isTwoHandedOnly: Bool
    }

    private var raufen: CombatTechnique? {
        hero.combatTechniques.first(where: { $0.name == "Raufen" })
    }

    /// A Patzer's "beschädigt" badge in front of whatever the row already says.
    /// The picker is where a player chooses what to fight with, so it is where a
    /// dented weapon has to be visible — the −2 otherwise first appears in the
    /// calculation of a roll already committed to.
    private func note(_ existing: String?, damaged name: String) -> String? {
        guard hero.isItemDamaged(name) else { return existing }
        guard let existing, !existing.isEmpty else { return L("fumble.damaged.badge") }
        return "\(L("fumble.damaged.badge")) \u{00B7} \(existing)"
    }

    var items: [Item] {
        var items: [Item] = []
        for w in hero.meleeWeapons {
            let technique = CombatTechniqueID(rawValue: w.combatTechniqueId)
            let isTwoHanded = technique?.isTwoHandedOnly ?? false
            items.append(Item(
                name: w.name,
                detail: "AT \(w.at) / PA \(w.pa)",
                note: note((mountedActive && isTwoHanded) ? "(\(L("mounted")))" : nil, damaged: w.name),
                icon: WeaponIcon.forTechnique(technique),
                isShield: false, isRaufen: false, isTwoHandedOnly: isTwoHanded
            ))
        }
        for s in hero.shields {
            items.append(Item(
                name: s.name,
                detail: "AT \(s.at) / PA \(s.pa)",
                note: note(s.note.isEmpty ? nil : s.note, damaged: s.name),
                icon: .system("shield.fill"),
                isShield: true, isRaufen: false, isTwoHandedOnly: false
            ))
        }
        items.append(Item(
            name: "Raufen",
            detail: "AT \(raufen?.at ?? 0) / PA \(raufen?.pa ?? 0)",
            note: nil,
            icon: WeaponIcon.forTechnique(.raufen),
            isShield: false, isRaufen: true, isTwoHandedOnly: false
        ))
        return items
    }

    private func canSelect(_ item: Item) -> Bool {
        if selected.contains(item.name) { return true } // can always deselect
        if mountedActive && item.isTwoHandedOnly { return false }
        if item.isRaufen { return selected.isEmpty }    // Raufen = both hands free
        if item.isTwoHandedOnly { return selected.isEmpty }
        if selected.count >= 2 { return false }
        if selected.count == 1 {
            let current = items.first { selected.contains($0.name) }
            if current?.isRaufen == true { return false }
            if current?.isTwoHandedOnly == true { return false }
            if item.isShield && current?.isShield == true { return false }
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            let all = items

            if !hero.meleeWeapons.isEmpty {
                combatSectionLabel(L("meleeWeapons.label"))
                ForEach(all.filter { !$0.isShield && !$0.isRaufen }, id: \.name) { row($0) }
            }

            if !hero.shields.isEmpty {
                combatSectionLabel(L("shields.label"))
                ForEach(all.filter(\.isShield), id: \.name) { row($0) }
            }

            combatSectionLabel(L("unarmed.label"))
            ForEach(all.filter(\.isRaufen), id: \.name) { row($0) }

            if !hero.rangedWeapons.isEmpty {
                combatSectionLabel(L("fernkampf.rangedWeapons.label"))
                ForEach(hero.rangedWeapons, id: \.name) { rangedRow($0) }
            }
        }
    }

    private func row(_ item: Item) -> some View {
        let isSelected = selected.contains(item.name)
        let enabled = canSelect(item)
        return Button {
            if isSelected {
                selected.remove(item.name)
            } else {
                if item.isRaufen || item.isTwoHandedOnly { selected.removeAll() }
                selected.insert(item.name)
            }
        } label: {
            // In hand is the fill (ADR-0010), like the armour two sections up and
            // every manoeuvre and chip in combat. These rows were the last ring
            // left in the flow, so the preparation screen said "selected" two
            // different ways on one screen.
            HStack(spacing: 12) {
                // The thing itself, not a hammer standing in for all of them.
                WeaponIconView(item.icon)
                    .font(.dsaBody(.body))
                    .foregroundStyle(isSelected ? Color.white : (enabled ? Color.primary : Color.secondary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                        .foregroundStyle(isSelected ? Color.white : (enabled ? Color.primary : Color(UIColor.tertiaryLabel)))
                    Text(item.detail)
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : (enabled ? Color.secondary : Color(UIColor.tertiaryLabel)))
                    if let note = item.note {
                        Text(note)
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : combatAccent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent : Color(UIColor.systemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .disabled(!enabled)
        .accessibilityIdentifier("combat.loadout.\(item.name)")
        .padding(.bottom, 4)
    }

    private func rangedRow(_ weapon: RangedWeapon) -> some View {
        let isSelected = selectedRanged == weapon.name
        return Button {
            selectedRanged = isSelected ? nil : weapon.name
        } label: {
            HStack(spacing: 12) {
                WeaponIconView(techniqueId: weapon.combatTechniqueId)
                    .font(.dsaBody(.body))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(weapon.name)
                        .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                        .foregroundStyle(isSelected ? .white : .primary)
                    HStack(spacing: 8) {
                        Text("FK \(weapon.at)")
                        Text(weapon.damage)
                        Text(weapon.range)
                    }
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                    if hero.isItemDamaged(weapon.name) {
                        // A ranged row pays −4, not the melee −2
                        // (`FumbleModifiers.beschaedigt`), and a badge that names
                        // the wrong number is worse than none: the picker exists
                        // to make the choice before the roll.
                        Text(L("fumble.damaged.badge.ranged"))
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : combatAccent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent : Color(UIColor.systemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.loadout.\(weapon.name)")
        .padding(.bottom, 4)
    }

    // MARK: - Reading and writing the hero's loadout

    static func load(from hero: Hero) -> (selected: Set<String>, ranged: String?) {
        var selected: Set<String> = []
        if let name = hero.selectedWeaponName { selected.insert(name) }
        if let name = hero.selectedOffHandName { selected.insert(name) }
        // Legacy: also check selectedShieldName
        if let name = hero.selectedShieldName { selected.insert(name) }
        return (selected, hero.selectedRangedWeaponName)
    }

    static func apply(selected: Set<String>, ranged: String?, to hero: Hero) {
        let shieldNames = Set(hero.shields.map(\.name))
        let chosen = selected.sorted()

        let main = chosen.first { !shieldNames.contains($0) && $0 != "Raufen" }
            ?? chosen.first { $0 == "Raufen" }
        let offHand = chosen.first { $0 != main }

        hero.selectedWeaponName = main
        hero.selectedOffHandName = offHand
        // Keep selectedShieldName in sync for backwards compat
        hero.selectedShieldName = offHand.map { shieldNames.contains($0) ? $0 : nil } ?? nil
        hero.selectedRangedWeaponName = ranged
    }
}
