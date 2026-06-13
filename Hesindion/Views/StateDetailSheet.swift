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
                .font(.system(.headline, weight: .black))
            Text(L(def.nameKey))
                .font(.system(.headline, weight: .black))
            if isZustand, level > 0 {
                Text(StateCatalog.roman(level))
                    .font(.system(.headline, design: .monospaced, weight: .black))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("close"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, DSALayout.headerVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(accent)
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.primaryBorder))
    }

    // MARK: - Level control (stepper / on-off indicator)

    @ViewBuilder private var levelControl: some View {
        if isReadOnly {
            // Read-only: show the (auto-computed / implied) level as a static badge.
            HStack(spacing: 10) {
                Text(L("states.level").uppercased())
                    .font(.system(.caption, weight: .black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isZustand ? StateCatalog.roman(level) : L("states.active"))
                    .font(.system(.title3, design: .monospaced, weight: .black))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.1))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        } else if isZustand {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("states.level").uppercased())
                    .font(.system(.caption, weight: .black))
                    .foregroundStyle(.secondary)
                // I–IV stepper: tap a number to set that level. Removal is
                // exclusively via the destructive "Entfernen" button below.
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { lvl in
                        Button {
                            hero.setStateLevel(def.id, level: lvl)
                        } label: {
                            Text(StateCatalog.roman(lvl))
                                .font(.system(.body, design: .monospaced, weight: .black))
                                .foregroundStyle(level == lvl ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(level == lvl ? accent : Color(UIColor.secondarySystemBackground))
                                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            // Status: binary on/off indicator.
            HStack(spacing: 10) {
                Image(systemName: level > 0 ? "checkmark.square.fill" : "square")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(level > 0 ? accent : .secondary)
                Text(L("states.active"))
                    .font(.system(.body, weight: .black))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.1))
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
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
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.secondaryBorder))
        }
    }

    private func effectRow(roman: String?, text: String, highlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let roman {
                Text(roman)
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(highlighted ? .white : .secondary)
                    .frame(width: 44, alignment: .leading)
            }
            Text(text)
                .font(.system(.subheadline, weight: highlighted ? .black : .regular))
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
                .font(.system(.subheadline))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Removal callout (prominent, bordered)

    private var removalCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.system(.subheadline, weight: .black))
                Text(L("states.removal.header").uppercased())
                    .font(.system(.caption, weight: .black))
            }
            .foregroundStyle(accent)

            Text(L(def.removalKey))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12))
        .overlay(Rectangle().stroke(accent, lineWidth: DSALayout.primaryBorder))
    }

    // MARK: - Derived note (read-only states)

    private var derivedNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.secondary)
            Text(L(isImpliedOnly && !isDerived ? "states.implied.note" : "states.derived.note"))
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            Rectangle().stroke(
                Color.secondary,
                style: StrokeStyle(lineWidth: DSALayout.secondaryBorder, dash: [4, 3])
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
            .font(.system(.body, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.groupCombat)
            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: DSALayout.primaryBorder))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func blockHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, weight: .black))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}
