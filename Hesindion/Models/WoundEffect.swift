// Hesindion/Models/WoundEffect.swift
import Foundation

/// What a zone does when damage meets the Wundschwelle.
enum WoundEffectKind: Equatable {
    /// Raise a leveled Zustand by one step (Kopf → Betäubung).
    case raiseState(id: String)
    /// Set a binary Status (Beine → Liegend).
    case setStatus(id: String)
    /// Additional dice damage on top of the hit (Torso → 1W3+1 SP).
    case extraDamage(count: Int, sides: Int, flat: Int)
    /// No automatic math — show the text and offer an explicit action.
    case reminder
}

struct WoundEffect: Equatable {
    let zone: HitZone
    let kind: WoundEffectKind
    /// L() key for the effect description.
    let effectKey: String
    /// L() key naming the Selbstbeherrschung Anwendungsgebiet that resists it.
    let resistanceKey: String
}

/// Wundeffekte per zone (DSA 5 Fokus-Trefferzonenregeln).
///
/// The rules table names Kopf, Torso, Arme and Beine only. The extra limb zones on
/// non-humanoid plans reuse the closest analogue — front/rear legs behave as Beine,
/// mid-limbs and Fangarme as Arme (a manipulator, not a leg) — and Schwanz and Körper
/// have no published effect.
enum WoundEffectCatalog {

    static func effect(for zone: HitZone) -> WoundEffect {
        switch zone {
        case .kopf:
            WoundEffect(zone: zone, kind: .raiseState(id: "betaeubung"),
                        effectKey: "woundEffect.kopf.effect",
                        resistanceKey: "woundEffect.resistance.handlungsfaehigkeit")
        case .torso:
            WoundEffect(zone: zone, kind: .extraDamage(count: 1, sides: 3, flat: 1),
                        effectKey: "woundEffect.torso.effect",
                        resistanceKey: "woundEffect.resistance.handlungsfaehigkeit")
        case .arme, .mittlereGliedmassen:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.arme.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .beine, .vordereBeine, .hintereBeine:
            WoundEffect(zone: zone, kind: .setStatus(id: "liegend"),
                        effectKey: "woundEffect.beine.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .schwanz:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.schwanz.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .fangarme:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.arme.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .koerper:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.koerper.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        }
    }
}

// MARK: - WoundEffectResolver

/// Pure decision logic for wound effects, kept out of the view so it is testable.
///
/// Nothing here writes LP: the Torso effect reports its extra damage back to the
/// caller so that taking damage stays a *single* LP write.
enum WoundEffectResolver {

    /// How many times the damage covers the Wundschwelle. `0` means no wound effect.
    static func multiple(damage: Int, wundschwelle: Int) -> Int {
        guard wundschwelle > 0 else { return 0 }
        return max(0, damage) / wundschwelle
    }

    /// The Selbstbeherrschung probe is harder by 1 per multiple of the Wundschwelle.
    /// Rules example: Wundschwelle 6 → −1 at 6 SP, −2 at 12, −3 at 18.
    static func probeModifier(damage: Int, wundschwelle: Int) -> Int {
        -multiple(damage: damage, wundschwelle: wundschwelle)
    }

    /// Extra dice damage (Torso: 1W3+1), injectable for deterministic tests.
    static func rollExtraDamage<G: RandomNumberGenerator>(
        count: Int, sides: Int, flat: Int, using generator: inout G
    ) -> Int {
        DiceRoller.roll(count: count, sides: sides, using: &generator).reduce(0, +) + flat
    }

    /// The one LP figure written on confirm: the hit plus any Torso extra damage.
    static func totalDamage(effective: Int, extra: Int?) -> Int {
        max(0, effective) + max(0, extra ?? 0)
    }

    /// Apply a zone's effect to the hero. `extraDamage` is folded into the caller's
    /// single LP write rather than applied here.
    static func apply(_ zone: HitZone, to hero: Hero, extraDamage: inout Int?) {
        switch WoundEffectCatalog.effect(for: zone).kind {
        case .raiseState(let id):
            hero.setStateLevel(id, level: hero.level(of: id) + 1)
        case .setStatus(let id):
            hero.setStateLevel(id, level: 1)
        case .extraDamage(let count, let sides, let flat):
            var rng = SystemRandomNumberGenerator()
            extraDamage = rollExtraDamage(count: count, sides: sides, flat: flat, using: &rng)
        case .reminder:
            break
        }
    }

    /// Convenience for the success path and for tests.
    static func resolve(zone: HitZone, probeSucceeded: Bool, hero: Hero) {
        guard !probeSucceeded else { return }
        var ignored: Int? = nil
        apply(zone, to: hero, extraDamage: &ignored)
    }

    // MARK: - Confirm-time decision (Task 11 acceptance criterion)

    /// Whether a hit even threatens a wound effect: the rule must be on, a zone must
    /// be known, and the damage must reach at least one multiple of the Wundschwelle.
    static func effectThreatens(zonesActive: Bool, hasZone: Bool, damage: Int, wundschwelle: Int) -> Bool {
        zonesActive && hasZone && multiple(damage: damage, wundschwelle: wundschwelle) >= 1
    }

    /// Whether a threatened effect actually applies: a hero without the talent
    /// cannot resist at all, so that counts as a failure; otherwise it is the
    /// Selbstbeherrschung probe result.
    static func effectApplies(threatens: Bool, hasTalent: Bool, probeSucceeded: Bool?) -> Bool {
        guard threatens else { return false }
        guard hasTalent else { return true }
        return probeSucceeded == false
    }

    /// The whole confirm-time write, in one place: resolve the effect against the
    /// hero if (and only if) it applies to a known zone, and fold any Torso extra
    /// damage into the single LP figure the caller must subtract exactly once.
    ///
    /// Extra damage can never appear without the hit's `effectiveDamage`: it is
    /// additive in `totalDamage`, and it is only rolled at all when `effectApplies`
    /// is true for a real `zoneHit` — never in isolation.
    static func confirmDamage(
        zoneHit: HitZoneHit?, effectApplies: Bool, effectiveDamage: Int, hero: Hero
    ) -> (extraDamage: Int?, totalDamage: Int) {
        var extra: Int? = nil
        if let hit = zoneHit, effectApplies {
            apply(hit.zone, to: hero, extraDamage: &extra)
        }
        return (extra, totalDamage(effective: effectiveDamage, extra: extra))
    }
}
