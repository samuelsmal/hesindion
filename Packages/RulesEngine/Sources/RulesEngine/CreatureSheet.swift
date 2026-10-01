import Foundation

/// A creature as the subject of its own evaluation (issue #48, ADR-0020): the mount's
/// `HeroSheet`. Its Zustände are the rules' own — COND_6 runs on it unchanged — and its profile
/// rule (`svellttaler-kaltblut`) gives the Schmerz thresholds the hero's fractions do not.
public struct CreatureSheet: Codable, Hashable, Sendable {
    /// The profile rule and the animal advantages with a rule file (`zaehes-tier`), by rule id.
    public var owned: [String: OwnedRule]
    /// The build's values: the base of `gs`, `leMax`, `vw` and `at(with: <attack>)`.
    public var gs: Int
    public var leMax: Int
    public var leCurrent: Int
    public var vw: Int?
    /// Attack name → AT.
    public var attacks: [String: Int]

    public init(owned: [String: OwnedRule], gs: Int, leMax: Int, leCurrent: Int, vw: Int? = nil,
                attacks: [String: Int] = [:]) {
        self.owned = owned; self.gs = gs; self.leMax = leMax; self.leCurrent = leCurrent
        self.vw = vw; self.attacks = attacks
    }
}

extension Situation {
    /// The creature's situation: `subject: creature`, the build's values as the base, the
    /// current LE as the `le` pool (R39).
    public init(creature c: CreatureSheet) {
        var base = ["gs": c.gs, "leMax": c.leMax]
        if let vw = c.vw { base["vw"] = vw }
        for (name, at) in c.attacks { base["at(with: \(name))"] = at }
        self.init(owned: c.owned,
                  facts: [Fact(name: "subject", value: .string("creature"), owner: .sheet)],
                  base: base,
                  pools: [.le: PoolState(current: c.leCurrent, max: c.leMax)])
    }

    /// This situation with `facts` stated (a stated fact replaces one of the same name).
    public func stating(_ facts: [Fact]) -> Situation {
        var s = self
        for f in facts { s.state(f) }
        return s
    }
}

/// What the mount's evaluation hands the hero's: the three `mount.*` facts, and the breakdowns
/// they come from, for display.
public struct MountFacts: Sendable {
    public let gs: Breakdown
    /// The `level(rule: COND_6)` breakdown. Its result is the Stufe the mount *acts at* (after
    /// Zähes Tier's `levelAs` line); its `base` is the Stufe it *has*.
    public let schmerzBreakdown: Breakdown
    public let handlungsunfaehig: Bool

    /// The Stufe the mount has, before Zähes Tier (ruling ADV_49.zaeher-hund-counts: `useLevel`
    /// changes the Stufe acted at only). 0 without Schmerz.
    public var schmerz: Int { schmerzBreakdown.base?.value ?? 0 }

    public var facts: [Fact] {
        var out: [Fact] = []
        if let v = gs.result { out.append(Fact(name: "mount.gs", value: .int(v), owner: .derived)) }
        out.append(Fact(name: "mount.schmerz", value: .int(schmerz), owner: .derived))
        out.append(Fact(name: "mount.handlungsunfaehig", value: .bool(handlungsunfaehig), owner: .derived))
        return out
    }
}

extension Engine {
    /// The mount's `gs` and Stufe of Schmerz, and whether settling its situation gains
    /// Handlungsunfähig (STATE_8: COND_6.SZ5 at Stufe IV, Zähes Tier or not).
    public func mountFacts(in mount: Situation) -> MountFacts {
        let settled = ActionLayer(engine: self).perform(.settle, in: mount)
        let gained = settled.events.contains { $0.kind == .gained && $0.rule == "STATE_8" }
        return MountFacts(gs: evaluate(Query("gs"), in: mount),
                          schmerzBreakdown: evaluate(Query("level(rule: COND_6)"), in: mount),
                          handlungsunfaehig: gained)
    }
}
