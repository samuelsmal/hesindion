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

    var items: [Item] {
        var items: [Item] = []
        for w in hero.meleeWeapons {
            let technique = CombatTechniqueID(rawValue: w.combatTechniqueId)
            let isTwoHanded = technique?.isTwoHandedOnly ?? false
            items.append(Item(
                name: w.name,
                detail: "AT \(w.at) / PA \(w.pa)",
                note: (mountedActive && isTwoHanded) ? "(\(L("mounted")))" : nil,
                icon: WeaponIcon.forTechnique(technique),
                isShield: false, isRaufen: false, isTwoHandedOnly: isTwoHanded
            ))
        }
        for s in hero.shields {
            items.append(Item(
                name: s.name,
                detail: "AT \(s.at) / PA \(s.pa)",
                note: s.note.isEmpty ? nil : s.note,
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
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(isSelected ? combatAccent : .secondary)

                // The thing itself, not a hammer standing in for all of them.
                WeaponIconView(item.icon)
                    .font(.dsaBody(.body))
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                        .foregroundStyle(enabled ? .primary : .tertiary)
                    Text(item.detail)
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(enabled ? .secondary : .tertiary)
                    if let note = item.note {
                        Text(note)
                            .font(.dsaBody(.caption2))
                            .foregroundStyle(combatAccent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .dsaBox(.flush, stroke: isSelected ? combatAccent : Color.dsaBorder)
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(isSelected ? combatAccent : .secondary)
                WeaponIconView(techniqueId: weapon.combatTechniqueId)
                    .font(.dsaBody(.body))
                VStack(alignment: .leading, spacing: 2) {
                    Text(weapon.name)
                        .font(isSelected ? .dsaHeading(.body) : .dsaBody(.body))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("FK \(weapon.at)")
                        Text(weapon.damage)
                        Text(weapon.range)
                    }
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? combatAccent.opacity(0.1) : Color(UIColor.systemBackground))
            .dsaBox(.flush, stroke: isSelected ? combatAccent : Color.dsaBorder)
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
