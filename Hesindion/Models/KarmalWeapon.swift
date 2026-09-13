import Foundation

/// What a consecrated weapon does to a demon (Fokusregel *Karmale Objekte*).
///
/// > "Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden.
/// > Angriffe mit geweihten Waffen der Gegengottheit erzeugen doppelte
/// > Trefferpunkte."
///
/// Two facts decide it and the app can know neither: whether the weapon is
/// consecrated (a per-weapon setting the player makes) and whether the thing on
/// the other side is a demon of the god this weapon is sworn against (the GM's
/// to say, at the moment of the attack). So this is a lookup over two answers,
/// not a derivation — see `HitZoneSizes` for the same discipline.
///
/// The doubling lands on the rolled TP before armour, which is where the
/// damage screen applies every other multiplier.
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

    /// The multiplier, or `.unchanged` where the rule adds nothing.
    static func damage(consecrated: Bool, target: Target) -> CriticalDamage {
        guard consecrated, target == .daemonOfOpposingDeity else { return .unchanged }
        return .double
    }

    /// Whether there is anything worth saying on screen — a consecrated weapon
    /// against a demon is worth stating even when it does not double, because
    /// "regulärer Schaden" is itself the exception.
    static func statesSomething(consecrated: Bool, target: Target) -> Bool {
        consecrated && target != .ordinary
    }
}
