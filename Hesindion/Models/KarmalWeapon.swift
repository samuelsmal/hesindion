import Foundation

/// What a consecrated weapon *says* about a demon (Fokusregel *Karmale
/// Objekte*). The doubling itself is the catalog's — `GRW_karmaleObjekte`,
/// read through `DamageModifiers.multiplier(situation:)` — because it needs
/// nothing this type does not: two facts the app can know neither of, whether
/// the weapon is consecrated (a per-weapon setting the player makes) and
/// whether the thing on the other side is a demon of the god this weapon is
/// sworn against (the GM's to say, at the moment of the attack).
///
/// > "Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden.
/// > Angriffe mit geweihten Waffen der Gegengottheit erzeugen doppelte
/// > Trefferpunkte."
///
/// What is left here is the half the catalog does not say: whether the
/// screen has anything worth stating at all, since "regulärer Schaden" to an
/// ordinary demon is itself the exception worth naming.
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
