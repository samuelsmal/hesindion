import SwiftUI

// MARK: - CombatHitZoneRow

/// Zone selection for an incoming hit: tap a chip, or roll 1W20 against the hero's
/// Trefferzonentabelle. The raw roll stays on screen so the table stays auditable.
struct CombatHitZoneRow: View {
    @Binding var zoneHit: HitZoneHit?
    @Binding var lastRoll: Int?
    /// The hero is a humanoid of normal size — the only plan a player character uses.
    var plan: BodyPlan = .humanoid(.mittel)
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CombatZonePicker(
                selection: Binding(
                    get: { zoneHit?.zone },
                    set: { newZone in
                        lastRoll = nil
                        zoneHit = newZone.map { HitZoneHit(zone: $0, side: nil) }
                    }),
                targetIsSurprised: .constant(false),
                zones: [.kopf, .torso, .arme, .beine]
            )
            .disabled(isDisabled)

            Button {
                let roll = DiceRoller.roll(sides: 20)
                lastRoll = roll
                zoneHit = HitZoneTable.lookup(roll, plan: plan)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dice.fill")
                    Text(L("trefferzone.roll"))
                }
                .font(.system(.caption, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isDisabled ? Color.gray : combatAccent)
                .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            if let hit = zoneHit {
                Text(summary(hit))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// "14: Beine (rechts)" after a roll, plain "Beine" after a tap.
    private func summary(_ hit: HitZoneHit) -> String {
        let name = L(hit.zone.nameKey)
        let sided = hit.side.map { "\(name) (\(L($0.nameKey)))" } ?? name
        return lastRoll.map { "\($0): \(sided)" } ?? sided
    }
}

// MARK: - CombatWoundEffectPanel

/// Wundschwelle panel for the hero taking damage: the multiple, the Wundeffekt, and
/// the Selbstbeherrschung probe that can avert it.
///
/// The panel decides nothing itself — `WoundEffectResolver` owns the arithmetic and
/// the parent owns the single LP write.
struct CombatWoundEffectPanel: View {
    let hero: Hero
    let hit: HitZoneHit
    let effectiveDamage: Int
    let wundschwelle: Int
    /// `nil` until the probe is rolled; a hero without the talent never gets one.
    @Binding var probeSucceeded: Bool?
    let effectApplies: Bool
    let extraDamage: Int?
    let confirmed: Bool
    /// Staged intent for the Arme drop-weapon action: the weapon is only actually
    /// cleared on confirm, alongside the LP write and the log entry (see
    /// `CombatTakeDamageView.applyDamage()`), so an abandoned flow cannot disarm
    /// the hero.
    @Binding var dropWeapon: Bool
    var onRollProbe: () -> Void

    private var effect: WoundEffect { WoundEffectCatalog.effect(for: hit.zone) }

    private var multiple: Int {
        WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    private var probeModifier: Int {
        WoundEffectResolver.probeModifier(damage: effectiveDamage, wundschwelle: wundschwelle)
    }

    private var talent: Talent? {
        hero.talents.first { $0.name == "Selbstbeherrschung" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(L("trefferzone.woundEffect"))

            Text(String(format: L("trefferzone.threshold"), effectiveDamage, wundschwelle, multiple))
                .font(.system(.caption, design: .monospaced, weight: .bold))

            Text(L(effect.effectKey))
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(effectApplies ? Color.groupCombat : .primary)

            if talent == nil {
                Text(L("trefferzone.noTalent"))
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            } else if let succeeded = probeSucceeded {
                HStack(spacing: 6) {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(succeeded ? Color.green : Color.groupCombat)
                    Text(succeeded ? L("success") : L("failure"))
                        .font(.system(.caption, weight: .black))
                }
            } else {
                Button(action: onRollProbe) {
                    Text(String(format: L("trefferzone.probe"), L(effect.resistanceKey), probeModifier))
                        .font(.system(.caption, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(confirmed ? Color.gray : combatAccent)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(confirmed)
            }

            if effectApplies, case .reminder = effect.kind, hero.selectedWeaponName != nil {
                Button {
                    dropWeapon.toggle()
                } label: {
                    HStack(spacing: 6) {
                        if dropWeapon {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(L("trefferzone.dropWeapon"))
                    }
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(dropWeapon ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(dropWeapon ? Color.groupCombat : Color(UIColor.systemBackground))
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(confirmed)
            }

            if let extra = extraDamage {
                Text("+\(extra) \(L("lpLost"))")
                    .font(.system(.caption, design: .monospaced, weight: .black))
                    .foregroundStyle(Color.groupCombat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.groupCombat.opacity(0.1))
        .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
    }
}
