import SwiftUI
import SwiftData

/// Detail / management sheet for a single player state, presented when a `StateChip`
/// is tapped.
///
/// Three variants, driven by the catalog definition:
///   - **Zustand** (leveled): a I–IV stepper writing `hero.setStateLevel`, an effect
///     table with the current level highlighted, cause + a prominent removal callout,
///     and a destructive "Entfernen" button.
///   - **Status** (binary): an on/off indicator, the single effect, cause + removal
///     callout, and "Entfernen".
///   - **Derived** (Schmerz / Belastung — `StateCatalog.derivedIDs`): READ-ONLY. No
///     stepper, no remove button; instead a note that the state changes automatically.
///     Effect table + cause + removal text are still shown.
///
/// Neo-Brutalist styling mirrors `SkillCheckModal` / `StatePickerSheet`: flat
/// `Color.dsaBorder` rectangles, monospaced black numerics, group accent colour.
struct StateDetailSheet: View {
    @Bindable var hero: Hero
    let def: StateDefinition

    @Environment(\.dismiss) private var dismiss

    private var isZustand: Bool { def.kind == .zustand }
    private var isDerived: Bool { StateCatalog.derivedIDs.contains(def.id) }

    /// True when the state is implied by another active state (e.g. Liegend ⇐ Bewusstlos)
    /// but isn't itself stored — there's nothing to remove, so the sheet is read-only.
    private var isImpliedOnly: Bool {
        hero.impliedStateIDs.contains(def.id) && !hero.states.contains { $0.stateID == def.id }
    }

    /// Read-only treatment (no stepper, no Remove button) for derived OR implied-only states.
    private var isReadOnly: Bool { isDerived || isImpliedOnly }

    private var accent: Color { .groupCombat }

    /// Live level read from the hero (derived states report their computed level).
    private var level: Int { hero.level(of: def.id) }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 16) {
                levelControl
                temporarySchmerzNote
                effectTable
                causeBlock
                removalCallout
                if isReadOnly {
                    derivedNote
                } else {
                    removeButton
                }
            }
            .padding(16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Header (icon + name + level + close)

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: def.iconSystemName)
                .font(.dsaHeading(.headline))
            Text(L(def.nameKey))
                .font(.dsaHeading(.headline))
            if isZustand, level > 0 {
                Text(StateCatalog.roman(level))
                    .font(.dsaMono(.headline, emphasis: true))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityLabel(L("close"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(accent)
        .dsaBox(.raised)
    }

    // MARK: - Level control (stepper / on-off indicator)

    @ViewBuilder private var levelControl: some View {
        if isReadOnly {
            // Read-only: show the (auto-computed / implied) level as a static badge.
            HStack(spacing: 10) {
                Text(L("states.level").uppercased())
                    .font(.dsaHeading(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isZustand ? StateCatalog.roman(level) : L("states.active"))
                    .font(.dsaMono(.title3, emphasis: true))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.1))
            .dsaBox(.flush)
        } else if isZustand {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("states.level").uppercased())
                    .font(.dsaHeading(.caption))
                    .foregroundStyle(.secondary)
                // I–IV stepper: tap a number to set that level. Removal is
                // exclusively via the destructive "Entfernen" button below.
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { lvl in
                        Button {
                            hero.setStateLevel(def.id, level: lvl)
                        } label: {
                            Text(StateCatalog.roman(lvl))
                                .font(.dsaMono(.body, emphasis: true))
                                .foregroundStyle(level == lvl ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(level == lvl ? accent : Color(UIColor.secondarySystemBackground))
                                .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)
                    }
                }
            }
        } else {
            // Status: binary on/off indicator.
            HStack(spacing: 10) {
                Image(systemName: level > 0 ? "checkmark.square.fill" : "square")
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(level > 0 ? accent : .secondary)
                Text(L("states.active"))
                    .font(.dsaHeading(.body))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.1))
            .dsaBox(.flush)
        }
    }

    /// Where an extra level came from. Schmerz is derived from LP, so a hero at
    /// full health showing Schmerz I is a contradiction on its face unless the
    /// sheet says a Patzer put it there and when it goes.
    @ViewBuilder private var temporarySchmerzNote: some View {
        if def.id == "schmerz", hero.temporarySchmerzActive {
            Text(String(
                format: L("schmerz.fromFumble"),
                hero.temporarySchmerzLevel,
                hero.temporarySchmerzLastRound))
                .font(.dsaBody(.caption))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("state.schmerz.fromFumble")
        }
    }

    // MARK: - Effect table

    private var effectTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            blockHeader(L("states.effect.header"))
            VStack(spacing: 0) {
                ForEach(Array(def.levelEffectKeys.enumerated()), id: \.offset) { index, key in
                    let rowLevel = index + 1
                    // For Zustände, highlight the row matching the current level.
                    let highlighted = isZustand && rowLevel == level
                    effectRow(
                        roman: isZustand ? StateCatalog.roman(rowLevel) : nil,
                        text: L(key),
                        highlighted: highlighted
                    )
                }
            }
            .dsaBox(.flush)
        }
    }

    private func effectRow(roman: String?, text: String, highlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let roman {
                Text(roman)
                    .font(.dsaMono(.subheadline, emphasis: true))
                    .foregroundStyle(highlighted ? .white : .secondary)
                    .frame(width: 44, alignment: .leading)
            }
            Text(text)
                .font(highlighted ? .dsaHeading(.subheadline) : .dsaBody(.subheadline))
                .foregroundStyle(highlighted ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? accent : Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Cause

    private var causeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            blockHeader(L("states.cause.header"))
            Text(L(def.causeKey))
                .font(.dsaBody(.subheadline))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Removal callout (prominent, bordered)

    private var removalCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.dsaHeading(.subheadline))
                Text(L("states.removal.header").uppercased())
                    .font(.dsaHeading(.caption))
            }
            .foregroundStyle(accent)

            Text(L(def.removalKey))
                .font(.dsaBody(.subheadline))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12))
        .dsaBox(.flush, stroke: accent)
    }

    // MARK: - Derived note (read-only states)

    private var derivedNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.dsaBody(.subheadline))
                .foregroundStyle(.secondary)
            Text(L(isImpliedOnly && !isDerived ? "states.implied.note" : "states.derived.note"))
                .font(.dsaBody(.footnote))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    // MARK: - Remove button (destructive)

    private var removeButton: some View {
        Button {
            hero.setStateLevel(def.id, level: 0)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text(L("states.remove"))
            }
            .font(.dsaHeading(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.groupCombat)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
    }

    // MARK: - Helpers

    private func blockHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.dsaHeading(.caption))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}
