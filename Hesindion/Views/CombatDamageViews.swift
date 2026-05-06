import SwiftUI
import SwiftData

// MARK: - CombatTakeDamageView

struct CombatTakeDamageView: View {
    let hero: Hero
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var tpInput: Int = 0
    @State private var confirmed: Bool = false

    private var rs: Int { hero.totalRS }
    private var effectiveDamage: Int { max(0, tpInput - rs) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L("takeDamage"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)

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

            VStack(spacing: 16) {
                // TP input stepper
                combatSectionLabel(L("tp"))

                HStack(spacing: 0) {
                    Button {
                        if tpInput > 0 { tpInput -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.gray : combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed || tpInput <= 0)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Text("\(tpInput)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(minWidth: 80)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button {
                        tpInput += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(confirmed ? Color.gray : combatAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .fixedSize(horizontal: false, vertical: true)

                // Calculation display
                VStack(spacing: 4) {
                    Text("\(tpInput) \(L("tp")) \u{2212} \(rs) \(L("rs")) = \(effectiveDamage)")
                        .font(.system(.title3, weight: .black))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                    if effectiveDamage == 0 {
                        Text(L("absorbed"))
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(effectiveDamage) \(L("lpLost"))")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dsaDark)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                if !confirmed {
                    // Confirm button
                    Button {
                        if let dv = hero.derivedValues {
                            dv.lebensenergie.current = max(0, dv.lebensenergie.current - effectiveDamage)
                        }
                        let entry = LogEntry.create(
                            kind: "combatAction",
                            payload: CombatActionPayload(
                                combatId: combatId,
                                round: roundNumber,
                                action: .damageTaken,
                                weaponName: nil,
                                rollValue: nil,
                                damageDealt: nil,
                                damageTaken: effectiveDamage,
                                lpChange: -effectiveDamage
                            ),
                            hero: hero
                        )
                        modelContext.insert(entry)
                        confirmed = true
                    } label: {
                        Text(L("confirm"))
                            .font(.system(.title3, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Neue Aktion button
                    Button { step = .root } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L("newAction"))
                        }
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .adaptiveContentWidth()

            Spacer()
        }
    }
}

// MARK: - CombatMountDamageView

struct CombatMountDamageView: View {
    let hero: Hero
    let mount: Pet
    @Binding var step: CombatStep
    var onDismiss: () -> Void
    let combatId: UUID
    let roundNumber: Int

    @Environment(\.modelContext) private var modelContext
    @State private var spAmount: Int = 1
    @State private var damageApplied = false
    @State private var showingProbeModal = false
    @State private var probeSucceeded: Bool? = nil

    private var penalty: Int { spAmount / 5 }

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { step = .root } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("mountTakesDamage"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
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

            Spacer()

            if !damageApplied {
                spInputPhase
            } else {
                reitenCheckPhase
            }

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded },
                    initialModifier: -penalty
                )
            }
        }
    }

    // MARK: - SP Input Phase

    private var spInputPhase: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(combatAccent)

            Text(mount.name)
                .font(.system(.title3, weight: .bold))

            // SP stepper
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Button {
                        if spAmount > 1 { spAmount -= 1 }
                    } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Text("\(spAmount)")
                        .font(.system(.largeTitle, weight: .black))
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))

                    Button {
                        spAmount += 1
                    } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                Text(L("mountDamage.sp"))
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            // Penalty display
            if penalty > 0 {
                Text(String(format: L("mountDamage.penalty"), penalty))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(combatAccent)
            } else {
                Text(L("mountDamage.noPenalty"))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Apply button
            Button {
                // Deduct LP from mount
                mount.currentLifeEnergy = max(0, mount.currentLifeEnergy - spAmount)
                let entry = LogEntry.create(
                    kind: "combatAction",
                    payload: CombatActionPayload(
                        combatId: combatId,
                        round: roundNumber,
                        action: .damageTaken,
                        weaponName: nil,
                        rollValue: nil,
                        damageDealt: nil,
                        damageTaken: spAmount,
                        lpChange: 0
                    ),
                    hero: hero
                )
                modelContext.insert(entry)
                let mountEntry = LogEntry.create(
                    kind: "mountLPChange",
                    payload: MountLPChangePayload(petName: mount.name, lpChange: -spAmount),
                    hero: hero
                )
                modelContext.insert(mountEntry)
                withAnimation(DSAAnimation.standard) {
                    damageApplied = true
                }
            } label: {
                Text(L("mountDamage.apply"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Reiten Check Phase

    private var reitenCheckPhase: some View {
        VStack(spacing: 16) {
            if let talent = reitenTalent {
                if let succeeded = probeSucceeded {
                    // Result
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

                    Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !succeeded {
                        Text(L("mountDamage.sturz"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(Color.groupCombat)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.groupCombat.opacity(0.1))
                            .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
                    }

                    Button {
                        step = .root
                    } label: {
                        Text(L("continue"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(succeeded ? combatAccent : Color.dsaDark)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Prompt to roll
                    Image(systemName: "dice.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(combatAccent)

                    Text(L("reitenCheck"))
                        .font(.system(.title3, weight: .bold))
                        .multilineTextAlignment(.center)

                    if penalty > 0 {
                        Text(String(format: L("mountDamage.penalty"), penalty))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(combatAccent)
                    }

                    Button {
                        showingProbeModal = true
                    } label: {
                        Text(L("rollReitenCheck"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No Reiten talent — manual confirmation
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(combatAccent)

                Text(L("reitenCheckPrompt"))
                    .font(.system(.title3, weight: .bold))
                    .multilineTextAlignment(.center)

                if penalty > 0 {
                    Text(String(format: L("mountDamage.penalty"), penalty))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(combatAccent)
                }

                HStack(spacing: 12) {
                    Button {
                        probeSucceeded = false
                    } label: {
                        Text(L("no"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Button {
                        probeSucceeded = true
                    } label: {
                        Text(L("yes"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - CombatMountPreCheckView

struct CombatMountPreCheckView: View {
    let hero: Hero
    let onSuccess: CombatStep
    @Binding var step: CombatStep
    var onDismiss: () -> Void

    @State private var galoppConfirmed = false
    @State private var probeSucceeded: Bool? = nil
    @State private var showingProbeModal = false

    private var reitenTalent: Talent? {
        hero.talents.first { $0.name == "Reiten" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { step = .attackChoice } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("reitenCheck"))
                    .font(.system(.headline, weight: .black))
                    .foregroundStyle(.white)
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

            Spacer()

            VStack(spacing: 0) {
                galoppNode
                connectorArrow
                reitenNode
            }
            .adaptiveContentWidth()

            Spacer()
        }
        .overlay {
            if showingProbeModal, let talent = reitenTalent {
                TalentProbeModal(
                    talent: talent,
                    hero: hero,
                    onDismiss: { showingProbeModal = false },
                    onRolled: { succeeded in probeSucceeded = succeeded }
                )
            }
        }
    }

    // MARK: - Step 1: Galopp

    private var galoppNode: some View {
        VStack(spacing: 12) {
            if galoppConfirmed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L("galoppConfirm"))
                        .font(.system(.body, weight: .bold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            } else {
                Image(systemName: "figure.equestrian.sports")
                    .font(.system(size: 36))
                    .foregroundStyle(combatAccent)

                Text(L("galoppConfirm"))
                    .font(.system(.body, weight: .bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        step = .attackChoice
                    } label: {
                        Text(L("no"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemBackground))
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(DSAAnimation.standard) {
                            galoppConfirmed = true
                        }
                    } label: {
                        Text(L("yes"))
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(combatAccent)
                            .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(galoppConfirmed ? 0 : 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
    }

    // MARK: - Connector

    private var connectorArrow: some View {
        Image(systemName: "chevron.down.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(galoppConfirmed ? combatAccent : Color.dsaBorder)
            .padding(.vertical, 8)
    }

    // MARK: - Step 2: Reiten

    private var reitenNode: some View {
        VStack(spacing: 12) {
            if let talent = reitenTalent {
                reitenWithTalent(talent)
            } else {
                reitenManual
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
        .opacity(galoppConfirmed ? 1 : 0.4)
        .allowsHitTesting(galoppConfirmed)
    }

    @ViewBuilder
    private func reitenWithTalent(_ talent: Talent) -> some View {
        if let succeeded = probeSucceeded {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(succeeded ? Color.green : Color.groupCombat)

            Text(succeeded ? L("reitenCheckPassed") : L("reitenCheckFailed"))
                .font(.system(.body, weight: .bold))
                .multilineTextAlignment(.center)

            Button {
                if succeeded {
                    step = onSuccess
                } else {
                    step = .attackChoice
                }
            } label: {
                Text(succeeded ? L("continue") : L("back"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(succeeded ? combatAccent : Color.dsaDark)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "dice.fill")
                .font(.system(size: 36))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheck"))
                .font(.system(.body, weight: .bold))
                .multilineTextAlignment(.center)

            Button {
                showingProbeModal = true
            } label: {
                Text(L("rollReitenCheck"))
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(combatAccent)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
    }

    private var reitenManual: some View {
        Group {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(combatAccent)

            Text(L("reitenCheckPrompt"))
                .font(.system(.body, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    step = .attackChoice
                } label: {
                    Text(L("no"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemBackground))
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button {
                    step = onSuccess
                } label: {
                    Text(L("yes"))
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
