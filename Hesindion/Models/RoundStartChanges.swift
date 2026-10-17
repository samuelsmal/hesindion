import Foundation

/// What the step to the next Kampfrunde can change on the hero by itself,
/// read at one round number. Two of them — before the step and after it — are
/// all `RoundStartChange.between` needs, so the toast reports what actually
/// happened rather than a second copy of each rule's clock (issue #35,
/// ADR-0018: a change with no screen of its own is announced with its amount
/// and its cause).
///
/// The round is a parameter, not `hero.activeCombatRound`: `CombatView`
/// persists the new round only at the end of the step, and the Patzer clocks
/// are absolute round numbers compared against it.
struct RoundStartSnapshot: Equatable {
    let lep: Int
    let bleeding: Bool
    let noDefense: Bool
    let lebenspunkteSchmerz: Int
    /// Levels of the Patzer's Schmerz (Fuß verdreht / Zerrung) still running.
    let temporarySchmerz: Int
    let jammed: Bool

    init(hero: Hero, round: Int) {
        let inCombat = hero.activeCombatId != nil
        lep = hero.derivedValues?.lebensenergie.current ?? 0
        bleeding = hero.hasState(BleedingRules.stateId)
        noDefense = hero.activeCombatNoDefense
        lebenspunkteSchmerz = hero.lebenspunkteSchmerzLevel
        temporarySchmerz = inCombat && hero.temporarySchmerzLevels > 0
            && round <= hero.temporarySchmerzLastRound ? hero.temporarySchmerzLevels : 0
        jammed = inCombat && round <= hero.activeCombatJamUntilRound
    }
}

/// One line of the round-start toast.
enum RoundStartChange: Equatable {
    /// Blutend's 1 SP, as the LeP actually lost — at 0 LeP there is none.
    case bleedingLoss(lep: Int)
    /// The LeP loss crossed a Schmerz threshold; the loss is the cause.
    case lebenspunkteSchmerz(levels: Int)
    case bleedingEnded
    case temporarySchmerzEnded(levels: Int)
    case jamEnded
    case noDefenseEnded

    /// Every change between the two readings, in the order the step causes
    /// them: the damage, what the damage brings, then what ran out.
    static func between(_ before: RoundStartSnapshot, _ after: RoundStartSnapshot) -> [RoundStartChange] {
        var changes: [RoundStartChange] = []
        let lost = before.lep - after.lep
        if before.bleeding && lost > 0 { changes.append(.bleedingLoss(lep: lost)) }
        let schmerz = after.lebenspunkteSchmerz - before.lebenspunkteSchmerz
        if schmerz > 0 { changes.append(.lebenspunkteSchmerz(levels: schmerz)) }
        if before.bleeding && !after.bleeding { changes.append(.bleedingEnded) }
        if before.temporarySchmerz > 0 && after.temporarySchmerz == 0 {
            changes.append(.temporarySchmerzEnded(levels: before.temporarySchmerz))
        }
        if before.jammed && !after.jammed { changes.append(.jamEnded) }
        if before.noDefense && !after.noDefense { changes.append(.noDefenseEnded) }
        return changes
    }

    var text: String {
        switch self {
        case .bleedingLoss(let lep):              String(format: L("roundStart.bleedingLoss"), lep)
        case .lebenspunkteSchmerz(let levels):    String(format: L("roundStart.lebenspunkteSchmerz"), levels)
        case .bleedingEnded:                      L("roundStart.bleedingEnded")
        case .temporarySchmerzEnded(let levels):  String(format: L("roundStart.temporarySchmerzEnded"), levels)
        case .jamEnded:                           L("roundStart.jamEnded")
        case .noDefenseEnded:                     L("roundStart.noDefenseEnded")
        }
    }
}
