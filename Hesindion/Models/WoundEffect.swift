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
