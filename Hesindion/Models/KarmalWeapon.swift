import Foundation

/// Fokusregel *Karmale Objekte*.
///
/// > "Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden.
/// > Angriffe mit geweihten Waffen der Gegengottheit erzeugen doppelte
/// > Trefferpunkte."
///
/// The doubling is the catalog's — `GRW_karmaleObjekte`, read through
/// `DamageModifiers.multiplier(situation:)` — and needs nothing this type
/// does not already say: two facts the app can know neither of, whether the
/// weapon is consecrated (a per-weapon setting the player makes) and whether
/// the thing on the other side is a demon of the god this weapon is sworn
/// against (the GM's to say, at the moment of the attack).
///
/// What the announcement screen says about an ordinary demon — "regulärer
/// Schaden" is itself the exception worth naming — is a fixed subtitle on the
/// toggle (`L("daemon.target.subtitle")`, `CombatAttackViews.swift`), not
/// this type: `Target` and `statesSomething` below have no caller today
/// outside their own tests.
enum KarmalWeapon {

    /// What the target is, as far as this rule cares.
    enum Target: Equatable {
        /// Not a demon, or a demon this weapon has no special claim on.
        case ordinary
        /// A demon. A consecrated weapon reaches it at all; an ordinary one is
        /// the GM's problem, and the app says nothing about it.
        case daemon
        /// A demon of the deity this weapon is consecrated against.
        case daemonOfOpposingDeity
    }

    /// Whether there is anything worth saying on screen — a consecrated weapon
    /// against a demon is worth stating even when it does not double, because
    /// "regulärer Schaden" is itself the exception.
    static func statesSomething(consecrated: Bool, target: Target) -> Bool {
        consecrated && target != .ordinary
    }
}
