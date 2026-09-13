import SwiftUI

/// The published Trefferzonentabelle for a body plan, with the row a roll landed
/// on lit.
///
/// The zone reveal used to report its result as one monospaced line — "7: Torso"
/// — under the die. That says where the hit landed but not *why*, and it is the
/// only place in the app where a rules table is answered without being shown. The
/// table is short enough to print, and printing it makes the roll checkable: the
/// player sees 7 falling inside 6–8 rather than taking the app's word for it.
struct HitZoneTableView: View {
    let plan: BodyPlan
    /// The roll to highlight. `nil` shows the table with nothing lit.
    let roll: Int?
    var accent: Color = .groupCombat

    /// A paired zone is a *pair*: the table says "Arme", the roll says which arm
    /// (odd left, even right). The row that was hit names the side, the rest say
    /// what they cover.
    private func zoneName(_ row: HitZoneTable.Row, isHit: Bool) -> String {
        let name = L(row.zone.nameKey)
        guard row.zone.isPaired else { return name }
        if isHit, let roll {
            let side: BodySide = roll.isMultiple(of: 2) ? .rechts : .links
            return "\(name) (\(L(side.nameKey)))"
        }
        return "\(name) (\(L(BodySide.links.nameKey)) / \(L(BodySide.rechts.nameKey)))"
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(HitZoneTable.rows(for: plan)) { row in
                let isHit = roll.map(row.covers) ?? false
                HStack {
                    Text(row.rangeText)
                        .font(.dsaMono(.caption, emphasis: true))
                        .frame(minWidth: 44, alignment: .leading)
                    Text(zoneName(row, isHit: isHit))
                        .font(.dsaBody(.caption))
                    Spacer()
                    if isHit, let roll {
                        Text("\(roll)")
                            .font(.dsaMono(.caption, emphasis: true))
                    }
                }
                .foregroundStyle(isHit ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isHit ? accent : Color.clear)
                .dsaRowDivider()
            }
        }
        .dsaBox(.flush)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trefferzone.table")
    }
}
