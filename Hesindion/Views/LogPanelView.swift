import SwiftUI
import SwiftData

/// What a delete is about, once asked for and before it is confirmed. A combat
/// carries the entries it wrote, gathered when the button is pressed, so the
/// confirmation can say how many go and the delete cannot drift from what was shown.
///
/// It lives outside the panel because the confirmation does: a modal drawn inside
/// the log panel is bounded by it, and in landscape that is a third of the screen
/// — the panel wraps the title over three lines and stacks the buttons in a
/// column. `SplitContentLayout` owns the state and draws the modal over the whole
/// layout, which is where every other modal in the app sits (see `HeroDetailView`).
enum LogDeletion {
    case entry(LogEntry)
    case combat(id: UUID, entries: [LogEntry])

    var entries: [LogEntry] {
        switch self {
        case .entry(let entry): [entry]
        case .combat(_, let entries): entries
        }
    }

    var title: String {
        switch self {
        case .entry:
            "Eintrag löschen?"
        case .combat(_, let entries):
            "Kampf löschen? (\(entries.count) \(entries.count == 1 ? "Eintrag" : "Einträge"))"
        }
    }
}

struct LogPanelView: View {
    @Bindable var hero: Hero
    /// Set by the trash buttons; the confirmation and the delete itself belong to
    /// the layout above, so the modal is not boxed into the panel's width.
    @Binding var pendingDeletion: LogDeletion?

    @State private var collapsedCombats: Set<UUID> = []

    private var sortedEntries: [LogEntry] {
        hero.logEntries.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Protokoll")
                .font(.dsaHeading(.headline))
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, DSALayout.headerVerticalPadding)

            if hero.logEntries.isEmpty {
                Text("Noch keine Einträge...")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DSALayout.contentPadding)
                    .padding(.vertical, DSALayout.headerVerticalPadding)
                Spacer()
            } else {
                logList
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: DSALayout.border)
                .foregroundStyle(Color.dsaBorder)
        }
    }

    // MARK: - Log List

    @ViewBuilder
    private var logList: some View {
        let rows = buildFlatRows()
        List {
            ForEach(rows) { row in
                switch row.content {
                case .sessionHeader(let date, let rate, let talentCount):
                    sessionHeaderRow(date: date, rate: rate, talentCount: talentCount)
                case .combatHeader(let combatId, let totalRounds, let totalLP):
                    combatHeaderRow(combatId: combatId, totalRounds: totalRounds, totalLP: totalLP)
                case .entry(let entry, let indented):
                    entryRow(entry, indented: indented)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                let captured = entry
                                Task { @MainActor in
                                    pendingDeletion = .entry(captured)
                                }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    // MARK: - Session Header Row

    private func sessionHeaderRow(date: Date, rate: Double?, talentCount: Int) -> some View {
        HStack(spacing: 6) {
            Text("SITZUNG")
                .font(.dsaHeading(.caption2))
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.dsaBody(.caption))
            Spacer()
            if let rate {
                Circle()
                    .fill(Color.successRateColor(rate))
                    .frame(width: 8, height: 8)
                Text("\(Int((rate * 100).rounded()))% (\(talentCount))")
                    .font(.dsaMono(.caption, emphasis: true).weight(.bold))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DSALayout.contentPadding)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.dsaBorder.opacity(0.3))
        }
    }

    // MARK: - Combat Header Row

    /// The header carries the delete for the whole combat: its rows can be
    /// collapsed, and a collapsed combat has nothing left to swipe, so deleting a
    /// finished fight had no entry point at all (issue #13). The trash is a plain
    /// visible button rather than a swipe for the same reason.
    private func combatHeaderRow(combatId: UUID, totalRounds: Int, totalLP: Int) -> some View {
        let isCollapsed = collapsedCombats.contains(combatId)
        let lpString = totalLP >= 0 ? "+\(totalLP)" : "\(totalLP)"

        return HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isCollapsed {
                        collapsedCombats.remove(combatId)
                    } else {
                        collapsedCombats.insert(combatId)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.groupCombat)
                    Text("Kampf — \(totalRounds) Runden, \(lpString) LP")
                        .font(.dsaBody(.subheadline))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.dsaMotion)

            Button {
                pendingDeletion = .combat(id: combatId, entries: entries(ofCombat: combatId))
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Color.groupCombat)
                    .padding(.leading, 10)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.dsaMotion)
            .accessibilityLabel("Kampf löschen")
            .accessibilityIdentifier("log.deleteCombat")
        }
        .padding(.horizontal, DSALayout.contentPadding)
        .padding(.vertical, 8)
    }

    private func entries(ofCombat combatId: UUID) -> [LogEntry] {
        LogEntry.entries(ofCombat: combatId, in: sortedEntries)
    }

    // MARK: - Entry Row

    /// The trailing trash is the same affordance the combat header has. The swipe
    /// stays, but it was the only way in, and in a narrow side panel it is easy to
    /// miss and easy to lose to the panel's own drag (issue #13).
    private func entryRow(_ entry: LogEntry, indented: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: entry.kind))
                .foregroundStyle(iconColor(for: entry.kind))
                .frame(width: 20)

            Text(entryDescription(entry))
                .font(.dsaBody(.subheadline))
                .lineLimit(1)

            Spacer()

            Text(entry.timestamp, style: .time)
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)

            Button {
                pendingDeletion = .entry(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.dsaMotion)
            .accessibilityLabel("Eintrag löschen")
            .accessibilityIdentifier("log.deleteEntry")
        }
        .padding(.horizontal, DSALayout.contentPadding)
        .padding(.leading, indented ? 16 : 0)
        .padding(.vertical, 6)
    }

    // MARK: - Icon Mapping

    private func iconName(for kind: String) -> String {
        switch kind {
        case "talentCheck":    "dice.fill"
        case "combatAction":   "bolt.fill"
        case "healing":        "heart.fill"
        case "rest":           "moon.fill"
        case "mountLPChange":  "hare.fill"
        case "woundEffect":    "bandage.fill"
        case "diceRoll":       "dice.fill"
        default:               "questionmark.circle"
        }
    }

    private func iconColor(for kind: String) -> Color {
        switch kind {
        case "talentCheck":    .groupTalents
        case "combatAction":   .groupCombat
        case "healing":        .groupPersonalData
        case "rest":           .groupPersonalData
        case "mountLPChange":  .groupEquipment
        case "woundEffect":    .groupCombat
        case "diceRoll":       .secondary
        default:               .secondary
        }
    }

    // MARK: - Entry Description

    private func entryDescription(_ entry: LogEntry) -> String {
        switch entry.kind {
        case "talentCheck":
            guard let p = entry.decodePayload(TalentCheckPayload.self) else { return "—" }
            let schip = p.schipReroll == true ? " ✦ Schip" : ""
            if p.succeeded {
                return "\(p.talentName) — QS \(p.qualityLevel) ✓\(schip)"
            } else {
                return "\(p.talentName) — misslungen ✗\(schip)"
            }

        case "combatAction":
            guard let p = entry.decodePayload(CombatActionPayload.self) else { return "—" }
            return combatActionDescription(p)

        case "healing":
            guard let p = entry.decodePayload(HealingPayload.self) else { return "—" }
            return "\(p.source) — +\(p.lpRestored) LP"

        case "rest":
            guard let p = entry.decodePayload(RestPayload.self) else { return "—" }
            return "Rast — +\(p.lpRestored) LP"

        case "mountLPChange":
            guard let p = entry.decodePayload(MountLPChangePayload.self) else { return "—" }
            if p.lpChange < 0 {
                return "\(p.petName) — Schaden \(abs(p.lpChange))"
            } else {
                return "\(p.petName) — Heilung +\(p.lpChange) LP"
            }

        case "woundEffect":
            guard let p = entry.decodePayload(WoundEffectPayload.self) else { return "—" }
            let zone = L("hitZone.\(p.zone)")
            let side = p.side.map { " (\(L("bodySide.\($0)")))" } ?? ""
            let head = "\(zone)\(side) — \(p.damage)/\(p.wundschwelle) ×\(p.multiple)"
            guard p.applied else { return "\(head) ✓" }
            let extra = p.extraDamage.map { " +\($0) SP" } ?? ""
            let dropped = p.weaponDropped.map { " · \($0) \(L("trefferzone.dropWeapon"))" } ?? ""
            return "\(head) ✗\(extra)\(dropped)"

        case "diceRoll":
            guard let p = entry.decodePayload(DiceRollPayload.self) else { return "—" }
            let dice = "\(p.count)W\(p.sides)"
            if p.count == 1 {
                return "\(dice) = \(p.total)"
            }
            let parts = p.results.map(String.init).joined(separator: " + ")
            return "\(dice): \(parts) = \(p.total)"

        default:
            return "—"
        }
    }

    private func combatActionDescription(_ p: CombatActionPayload) -> String {
        let weapon = p.weaponName ?? "Angriff"
        switch p.action {
        case .attack:
            if let roll = p.rollValue {
                let outcomeStr = p.outcome == "critical" ? " \u{2605}" : p.outcome == "fumble" ? " \u{2717}\u{2717}" : ""
                return "\(weapon) — Attacke \(roll)\(outcomeStr)"
            }
            return "\(weapon) — Attacke"
        case .rangedAttack:
            if let roll = p.rollValue {
                return "\(weapon) — Fernkampf \(roll)"
            }
            return "\(weapon) — Fernkampf"
        case .parry:
            if let roll = p.rollValue {
                let outcomeStr = p.outcome == "critical" ? " \u{2605}" : ""
                return "\(weapon) — Parade \(roll)\(outcomeStr)"
            }
            return "\(weapon) — Parade"
        case .dodge:
            if let roll = p.rollValue {
                return "Ausweichen — \(roll)"
            }
            return "Ausweichen"
        case .damageDealt:
            let dmg = p.damageDealt ?? 0
            return "\(weapon) — \(dmg) TP"
        case .damageTaken:
            let dmg = p.damageTaken ?? 0
            return "\(dmg) Schaden erhalten"
        case .fumble:
            if let tableResult = p.fumbleTableResult {
                return "Patzer: \(tableResult)"
            }
            let sp = p.damageTaken ?? 0
            return "Patzer — \(sp) SP"
        case .criticalSuccess:
            let result = p.criticalTableResult ?? p.outcome ?? ""
            return result.isEmpty ? "Kritischer Erfolg" : "Kritischer Erfolg: \(result)"
        case .schipUsed:
            let action = p.schipAction ?? ""
            switch action {
            case "reroll": return "Schip: Neuer Wurf"
            case "damageReroll": return "Schip: W6 wiederholt"
            case "defenseBoost": return "Schip: Verteidigung +4"
            case "ignoreZustand": return "Schip: Zustand ignoriert"
            default: return "Schip eingesetzt"
            }
        case .passierschlag:
            if let roll = p.rollValue {
                let hit = p.outcome == "hit" ? "\u{2713}" : "\u{2717}"
                return "Passierschlag — \(roll) \(hit)"
            }
            return "Passierschlag"
        case .flucht:
            let success = p.outcome == "success" ? "gelungen" : "misslungen"
            return "Flucht — \(success)"
        case .opponentDefense:
            switch p.outcome {
            case "parried": return "\(weapon) — Gegner pariert"
            case "dodged": return "\(weapon) — Gegner ausgewichen"
            case "hit": return "\(weapon) — Treffer!"
            default: return "\(weapon) — Verteidigung"
            }
        }
    }

    // MARK: - Flat Row Model

    private struct FlatRow: Identifiable {
        let id: String
        let content: RowContent
    }

    private enum RowContent {
        case sessionHeader(date: Date, rate: Double?, talentCount: Int)
        case combatHeader(combatId: UUID, totalRounds: Int, totalLP: Int)
        case entry(LogEntry, indented: Bool)
    }

    private func buildFlatRows() -> [FlatRow] {
        // Group all entries into play sessions (≥ 8h gaps), newest session first.
        let sessions = SessionGrouper.group(sortedEntries, by: \.timestamp)
        var rows: [FlatRow] = []
        for session in sessions {
            guard let first = session.first else { continue }
            let talentChecks = session.filter { $0.kind == "talentCheck" }
            let successes = talentChecks.filter {
                $0.decodePayload(TalentCheckPayload.self)?.succeeded == true
            }.count
            let rate: Double? = talentChecks.isEmpty ? nil : Double(successes) / Double(talentChecks.count)
            rows.append(FlatRow(
                id: "session-\(first.id.uuidString)",
                content: .sessionHeader(date: first.timestamp, rate: rate, talentCount: talentChecks.count)
            ))
            rows.append(contentsOf: buildEntryRows(for: session))
        }
        return rows
    }

    /// Builds the combat-grouped entry rows for a single session's entries.
    private func buildEntryRows(for sorted: [LogEntry]) -> [FlatRow] {
        var rows: [FlatRow] = []
        var combatBuckets: [UUID: [LogEntry]] = [:]
        var combatInsertionOrder: [UUID] = []

        for entry in sorted {
            if entry.kind == "combatAction",
               let payload = entry.decodePayload(CombatActionPayload.self) {
                let cid = payload.combatId
                if combatBuckets[cid] == nil {
                    combatInsertionOrder.append(cid)
                }
                combatBuckets[cid, default: []].append(entry)
            } else {
                flushCombatGroups(before: entry.timestamp, buckets: &combatBuckets, order: &combatInsertionOrder, into: &rows)
                rows.append(FlatRow(id: entry.id.uuidString, content: .entry(entry, indented: false)))
            }
        }

        // Flush remaining
        for cid in combatInsertionOrder {
            if let entries = combatBuckets.removeValue(forKey: cid) {
                appendCombatRows(combatId: cid, entries: entries, into: &rows)
            }
        }

        return rows
    }

    private func flushCombatGroups(
        before timestamp: Date,
        buckets: inout [UUID: [LogEntry]],
        order: inout [UUID],
        into rows: inout [FlatRow]
    ) {
        var remaining: [UUID] = []
        for cid in order {
            guard let entries = buckets[cid] else { continue }
            if let newest = entries.first, newest.timestamp > timestamp {
                remaining.append(cid)
            } else {
                appendCombatRows(combatId: cid, entries: entries, into: &rows)
                buckets.removeValue(forKey: cid)
            }
        }
        order = remaining
    }

    private func appendCombatRows(combatId: UUID, entries: [LogEntry], into rows: inout [FlatRow]) {
        let totalRounds = entries.compactMap { $0.decodePayload(CombatActionPayload.self)?.round }.max() ?? 0
        let totalLP = entries.compactMap { $0.decodePayload(CombatActionPayload.self)?.lpChange }.reduce(0, +)

        rows.append(FlatRow(
            id: "combat-header-\(combatId.uuidString)",
            content: .combatHeader(combatId: combatId, totalRounds: totalRounds, totalLP: totalLP)
        ))

        if !collapsedCombats.contains(combatId) {
            for entry in entries {
                rows.append(FlatRow(id: entry.id.uuidString, content: .entry(entry, indented: true)))
            }
        }
    }

}
