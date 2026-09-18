import SwiftUI
import SwiftData

// MARK: - What the screen has to show

/// One state the fight is ending with.
struct CombatAftermathRow: Identifiable, Equatable {
    let def: StateDefinition
    /// The level the fight ended on. Kept even after the player clears the
    /// state, because this is the row's own subject: it is what the control on
    /// it takes away, and what "Zurücknehmen" puts back.
    let level: Int

    var id: String { def.id }
}

/// Everything the screen after "Kampf beenden" is about, worked out from the
/// hero alone.
///
/// A value rather than three computed properties on the view, so the one
/// question that decides whether the screen appears at all — *is there anything
/// to do here?* — can be asked in a unit test. Ending a fight with nothing to
/// switch off must behave exactly as it did before this screen existed; an empty
/// "after the fight" is a step that asks the player to confirm nothing.
struct CombatAftermath: Equatable {

    /// The states the player can switch off here: every active state
    /// `Hero.setStateLevel` will change. That is the Zustände I–IV and the
    /// Status — `eingeengt` among them, which is what the Beengte-Umgebung
    /// toggle on the preparation screen sets, and which nothing else ever
    /// clears.
    let clearable: [CombatAftermathRow]

    /// Schmerz and Belastung: shown, never offered. Both are derived — one from
    /// the LP total, one from the armour — and `setStateLevel` refuses them
    /// (`StateCatalog.derivedIDs`), so a control here would promise something it
    /// could not do. The row states where the level comes from and what ends it
    /// instead; for Schmerz that is one line per origin, out of
    /// `Hero.schmerzBreakdown`, because the two of them end differently.
    let derived: [CombatAftermathRow]

    /// What a Patzer dented. Not repaired here: that is a scene at a smithy and
    /// it lives on the hero settings screen. It is on this screen because this
    /// is the moment the player takes stock, and a weapon that is still −2 in
    /// the next fight is worth knowing about before the next fight.
    let damagedItems: [String]

    init(hero: Hero) {
        var clearable: [CombatAftermathRow] = []
        var derived: [CombatAftermathRow] = []
        for entry in hero.activeStates {
            let row = CombatAftermathRow(def: entry.def, level: entry.level)
            if StateCatalog.derivedIDs.contains(entry.def.id) {
                derived.append(row)
            } else {
                clearable.append(row)
            }
        }
        self.clearable = clearable
        self.derived = derived
        self.damagedItems = hero.damagedItems
    }

    /// Whether "Kampf beenden" has anything to stop for.
    ///
    /// The derived states alone are not a reason: there is nothing on them to
    /// do, and a screen whose every row is read-only is a screen that only asks
    /// the player to press "Fertig".
    var isEmpty: Bool { clearable.isEmpty && damagedItems.isEmpty }
}

// MARK: - CombatAftermathView

/// The step between "Kampf beenden" and leaving the fight.
///
/// States are set during a fight by half a dozen screens — a failed Sturz check,
/// a Beule, the take-damage screen's Selbstbeherrschung probe, the Beengte-
/// Umgebung toggle — and nothing in the app ever took one off again. The fight
/// ended, the player left, and Liegend went with them into the next scene until
/// somebody remembered to open the hero sheet and swipe it away (owner request).
/// So the way out of a fight now passes the list once.
///
/// Every tap writes at once, and every tap is reversible on this screen: the row
/// remembers the level the fight ended on, so a mistaken "Entfernen" is undone
/// by the button beside it rather than by finding the state in a picker again.
/// "Fertig" then does exactly what the end-combat button used to do — clear the
/// combat session, temporary Patzer clocks and all, and leave.
struct CombatAftermathView: View {
    @Bindable var hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    /// Frozen when the screen opens.
    ///
    /// `CombatAftermath(hero:)` reads `hero.activeStates`, and a state the
    /// player clears leaves that list — so recomputing it per body pass would
    /// make the row vanish under the finger and take the way back with it.
    @State private var rows: [CombatAftermathRow] = []
    @State private var derivedRows: [CombatAftermathRow] = []
    @State private var damaged: [String] = []
    /// Frozen with them, and for the same reason: "Fertig" clears the Patzer's
    /// levels, and the row that says so must still be there to read while the
    /// player is deciding.
    @State private var schmerz = SchmerzBreakdown(
        lebenspunkteLevel: 0, patzerLevel: 0, currentLP: nil, maxLP: nil, hasZaeherHund: false
    )

    var body: some View {
        VStack(spacing: 0) {
            combatScreenHeader(
                title: L("aftermath.title"),
                // Back, not "cancel": the fight is still there until "Fertig"
                // clears the session, so a player who pressed the end button by
                // mistake has a way back to the round they were in.
                onBack: { step = .root },
                onDismiss: finish
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("aftermath.intro"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !rows.isEmpty {
                        section(L("aftermath.states")) {
                            ForEach(rows) { stateRow($0) }
                        }
                    }

                    if !derivedRows.isEmpty {
                        section(L("aftermath.derived")) {
                            ForEach(derivedRows) { derivedRow($0) }
                        }
                    }

                    if !damaged.isEmpty {
                        section(L("aftermath.damaged")) {
                            ForEach(damaged, id: \.self) { damagedRow($0) }
                            Text(L("aftermath.damaged.hint"))
                                .font(.dsaBody(.caption2))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    CombatActionButton(
                        title: L("aftermath.done"),
                        icon: "checkmark",
                        identifier: "combat.aftermath.done",
                        action: finish
                    )
                }
                .adaptiveContentWidth()
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            let aftermath = CombatAftermath(hero: hero)
            rows = aftermath.clearable
            derivedRows = aftermath.derived
            damaged = aftermath.damagedItems
            schmerz = hero.schmerzBreakdown
        }
    }

    /// What the end-combat button did before this screen sat in front of it.
    /// Both ways off the screen take it, because the player has already said the
    /// fight is over and a session left open would resume a fight that ended.
    private func finish() {
        hero.clearCombatSession()
        onDismiss()
    }

    // MARK: - Rows

    @ViewBuilder
    private func stateRow(_ row: CombatAftermathRow) -> some View {
        let current = hero.level(of: row.def.id)
        VStack(alignment: .leading, spacing: 8) {
            rowHeader(row, current: current)

            // How the rules say it ends — the same text the state detail sheet
            // puts in its most prominent box. Most of these end with a rest, a
            // healing check or an action nobody is going to take at the table,
            // which is exactly why the player is being asked.
            Text(L(row.def.removalKey))
                .font(.dsaBody(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if row.def.kind == .zustand {
                levelChips(row, current: current)
            } else {
                statusButton(row, current: current)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.aftermath.row.\(row.def.id)")
    }

    private func rowHeader(_ row: CombatAftermathRow, current: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.def.iconSystemName)
                .font(.dsaBody(.body))
            Text(L(row.def.nameKey))
                .font(.dsaHeading(.body))
            if row.def.kind == .zustand, current > 0 {
                Text(StateCatalog.roman(current))
                    .font(.dsaMono(.body, emphasis: true))
                    .foregroundStyle(combatAccent)
            }
            Spacer()
            if current < row.level {
                Text(L("aftermath.gone"))
                    .font(.dsaMono(.caption2, emphasis: true))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Clear, or step down. Only as far up as the level the fight ended on: this
    /// screen takes things away, and offering a higher level here would make it
    /// a second state editor rather than the way out of a fight.
    private func levelChips(_ row: CombatAftermathRow, current: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0...row.level, id: \.self) { level in
                let isSelected = current == level
                Button {
                    hero.setStateLevel(row.def.id, level: level)
                } label: {
                    Text(level == 0 ? "\u{2014}" : StateCatalog.roman(level))
                        .font(.dsaMono(.body, emphasis: true))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
                        .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityIdentifier("combat.aftermath.level.\(row.def.id).\(level)")
            }
        }
        .dsaOptionGroup()
    }

    /// A Status is on or off, so one button that says which way it goes.
    private func statusButton(_ row: CombatAftermathRow, current: Int) -> some View {
        let isActive = current > 0
        return Button {
            hero.setStateLevel(row.def.id, level: isActive ? 0 : row.level)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "trash.fill" : "arrow.uturn.backward")
                Text(isActive ? L("aftermath.clear") : L("aftermath.restore"))
            }
            .font(.dsaHeading(.caption))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.groupCombat : Color.dsaDark)
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier("combat.aftermath.toggle.\(row.def.id)")
    }

    /// Read-only — and, since this release, read-only *about something*.
    ///
    /// "Why is this listed as read-only? This usually goes away (depending on
    /// the origin)" (owner report). It does, and the app knows by which route.
    /// Belastung's is one sentence: the armour puts it there and taking the
    /// armour off takes it away. Schmerz has two origins that end quite
    /// differently — the life points' own thresholds go with healing, the
    /// Patzertabelle's extra level goes with this very fight — so it gets a line
    /// each, the second of them struck through, because "Fertig" is what ends
    /// it. Zäher Hund and the cap at IV work on the *sum*, so whenever the lines
    /// stop adding up to the level in the header there is a sentence saying why.
    @ViewBuilder
    private func derivedRow(_ row: CombatAftermathRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: row.def.iconSystemName)
                    .font(.dsaBody(.body))
                Text(L(row.def.nameKey))
                    .font(.dsaHeading(.body))
                Text(StateCatalog.levelValueText(for: row.def, level: row.level))
                    .font(.dsaMono(.body, emphasis: true))
                Spacer()
            }

            if row.def.id == "schmerz" {
                ForEach(schmerz.parts, id: \.origin) { originRow($0) }
                if schmerz.zaeherHundApplied { derivedNote(L("aftermath.schmerz.zaeherHund")) }
                if schmerz.cappedAtFour { derivedNote(L("aftermath.schmerz.capped")) }
            } else {
                derivedNote(L(row.def.causeKey))
                derivedNote(L(row.def.removalKey))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            Rectangle().stroke(
                Color.secondary,
                style: StrokeStyle(lineWidth: DSALayout.border, dash: [4, 3])
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.aftermath.derived.\(row.def.id)")
    }

    /// One origin of the Schmerz: what it is worth, where it comes from, and the
    /// sentence about what ends it.
    ///
    /// The Patzer's levels hang off the combat session, and "Fertig" clears the
    /// session — so that line is struck through and badged "endet jetzt" in the
    /// same words the cleared rows above use, rather than promising something
    /// for later.
    private func originRow(_ part: SchmerzOriginPart) -> some View {
        let endsNow = part.origin.endsWithTheFight
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(originLevelText(part))
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(combatAccent)
                Text(originName(part.origin))
                    .font(.dsaBody(.caption))
                    .strikethrough(endsNow)
                Spacer()
                if endsNow {
                    Text(L("aftermath.endsNow"))
                        .font(.dsaMono(.caption2, emphasis: true))
                        .foregroundStyle(.secondary)
                }
            }
            derivedNote(L(part.origin.removalKey))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.aftermath.origin.\(part.origin.rawValue)")
    }

    /// The LP part is a level of its own ("II"); the Patzer's is a level *added*
    /// to it, and reads as one.
    private func originLevelText(_ part: SchmerzOriginPart) -> String {
        part.origin == .patzer ? "+\(part.level)" : StateCatalog.roman(part.level)
    }

    /// With the life points themselves when the app has them, because "II" alone
    /// does not say how close the next threshold is.
    private func originName(_ origin: SchmerzOrigin) -> String {
        guard origin == .lebenspunkte,
              let current = schmerz.currentLP,
              let max = schmerz.maxLP, max > 0
        else { return L(origin.nameKey) }
        return String(format: L("schmerz.origin.lebenspunkte.withLP"), current, max)
    }

    private func derivedNote(_ text: String) -> some View {
        Text(text)
            .font(.dsaBody(.caption))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func damagedRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.dsaBody(.caption))
                .foregroundStyle(combatAccent)
            Text(name)
                .font(.dsaBody(.body))
            Spacer()
            Text(L("fumble.damaged.badge"))
                .font(.dsaMono(.caption2, emphasis: true))
                .foregroundStyle(combatAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.aftermath.damaged.\(name)")
    }

    // MARK: - Layout helper

    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
