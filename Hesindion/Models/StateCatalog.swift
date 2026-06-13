import Foundation

enum StateKind: Equatable {
    case zustand   // leveled I–IV
    case status    // binary
}

/// How a state's penalty wires into the ModifierEngine.
enum StateMechanic: Equatable {
    /// `-level` (or fixed) applied to the given domains, labelled, respects schipIgnoreZustand.
    case penalty(domains: Set<CheckDomain>)
    /// Drives existing Beengte-Umgebung weapon-length penalties instead of a flat line.
    case eingeengt
    /// Geweihten bonus/penalty toggle (gottgefällig).
    case entrueckung
    /// No automatic math — reminder only.
    case reminderOnly
}

struct StateDefinition: Identifiable, Equatable {
    let id: String
    let kind: StateKind
    let nameKey: String          // L() key
    let iconSystemName: String
    let mechanic: StateMechanic
    /// I–IV effect summary keys (4 entries for .zustand; 1 for .status).
    let levelEffectKeys: [String]
    let causeKey: String
    let removalKey: String       // decay / how to remove — shown prominently
    /// Statuses this state implies for display (e.g. bewusstlos ⇒ [handlungsunfaehig]).
    let implies: [String]
    /// Level (per Stufe) at which the state counts as Handlungsunfähig (4 for most Zustände; nil otherwise).
    let handlungsunfaehigAtLevel: Int?

    static func == (a: StateDefinition, b: StateDefinition) -> Bool { a.id == b.id }
}

enum StateCatalog {
    static let all: [StateDefinition] = zustaende + statuses

    static func definition(for id: String) -> StateDefinition? {
        all.first { $0.id == id }
    }

    /// States a user can add by hand (excludes auto-derived Schmerz/Belastung).
    static var manuallyAddable: [StateDefinition] {
        all.filter { $0.id != "schmerz" && $0.id != "belastung" }
    }

    static let zustaende: [StateDefinition] = [
        StateDefinition(
            id: "betaeubung", kind: .zustand, nameKey: "state.betaeubung.name",
            iconSystemName: "bolt.horizontal.circle",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.betaeubung.I", "state.betaeubung.II",
                              "state.betaeubung.III", "state.betaeubung.IV"],
            causeKey: "state.betaeubung.cause", removalKey: "state.betaeubung.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "furcht", kind: .zustand, nameKey: "state.furcht.name",
            iconSystemName: "exclamationmark.shield",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.furcht.I", "state.furcht.II",
                              "state.furcht.III", "state.furcht.IV"],
            causeKey: "state.furcht.cause", removalKey: "state.furcht.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "paralyse", kind: .zustand, nameKey: "state.paralyse.name",
            iconSystemName: "figure.stand",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.paralyse.I", "state.paralyse.II",
                              "state.paralyse.III", "state.paralyse.IV"],
            causeKey: "state.paralyse.cause", removalKey: "state.paralyse.removal",
            implies: [], handlungsunfaehigAtLevel: nil),   // IV ⇒ Bewegungsunfähig, handled in Hero
        StateDefinition(
            id: "verwirrung", kind: .zustand, nameKey: "state.verwirrung.name",
            iconSystemName: "questionmark.circle",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.verwirrung.I", "state.verwirrung.II",
                              "state.verwirrung.III", "state.verwirrung.IV"],
            causeKey: "state.verwirrung.cause", removalKey: "state.verwirrung.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "berauscht", kind: .zustand, nameKey: "state.berauscht.name",
            iconSystemName: "wineglass",
            mechanic: .reminderOnly,    // only Zechen checks; app can't see talent identity yet
            levelEffectKeys: ["state.berauscht.I", "state.berauscht.II",
                              "state.berauscht.III", "state.berauscht.IV"],
            causeKey: "state.berauscht.cause", removalKey: "state.berauscht.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(
            id: "entrueckung", kind: .zustand, nameKey: "state.entrueckung.name",
            iconSystemName: "sparkles",
            mechanic: .entrueckung,
            levelEffectKeys: ["state.entrueckung.I", "state.entrueckung.II",
                              "state.entrueckung.III", "state.entrueckung.IV"],
            causeKey: "state.entrueckung.cause", removalKey: "state.entrueckung.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
        // Auto-derived; present in catalog for display, excluded from manuallyAddable.
        StateDefinition(
            id: "schmerz", kind: .zustand, nameKey: "source.schmerz",
            iconSystemName: "exclamationmark.triangle.fill",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.schmerz.I", "state.schmerz.II",
                              "state.schmerz.III", "state.schmerz.IV"],
            causeKey: "state.schmerz.cause", removalKey: "state.schmerz.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "belastung", kind: .zustand, nameKey: "source.belastung",
            iconSystemName: "shippingbox",
            mechanic: .reminderOnly,    // encumbrance modifier already exists separately
            levelEffectKeys: ["state.belastung.I", "state.belastung.II",
                              "state.belastung.III", "state.belastung.IV"],
            causeKey: "state.belastung.cause", removalKey: "state.belastung.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
    ]

    static let statuses: [StateDefinition] = [
        StateDefinition(id: "liegend", kind: .status, nameKey: "state.liegend.name",
            iconSystemName: "figure.fall", mechanic: .penalty(domains: [.meleeAttack, .meleeParry, .meleeDodge]),
            levelEffectKeys: ["state.liegend.effect"], causeKey: "state.liegend.cause",
            removalKey: "state.liegend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "fixiert", kind: .status, nameKey: "state.fixiert.name",
            iconSystemName: "pin", mechanic: .penalty(domains: [.meleeDodge]),
            levelEffectKeys: ["state.fixiert.effect"], causeKey: "state.fixiert.cause",
            removalKey: "state.fixiert.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "eingeengt", kind: .status, nameKey: "beengteUmgebung",
            iconSystemName: "arrow.down.right.and.arrow.up.left", mechanic: .eingeengt,
            levelEffectKeys: ["state.eingeengt.effect"], causeKey: "state.eingeengt.cause",
            removalKey: "state.eingeengt.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "blutend", kind: .status, nameKey: "state.blutend.name",
            iconSystemName: "drop.fill", mechanic: .reminderOnly,
            levelEffectKeys: ["state.blutend.effect"], causeKey: "state.blutend.cause",
            removalKey: "state.blutend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "brennend", kind: .status, nameKey: "state.brennend.name",
            iconSystemName: "flame.fill", mechanic: .reminderOnly,
            levelEffectKeys: ["state.brennend.effect"], causeKey: "state.brennend.cause",
            removalKey: "state.brennend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "blind", kind: .status, nameKey: "state.blind.name",
            iconSystemName: "eye.slash", mechanic: .reminderOnly,
            levelEffectKeys: ["state.blind.effect"], causeKey: "state.blind.cause",
            removalKey: "state.blind.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "taub", kind: .status, nameKey: "state.taub.name",
            iconSystemName: "ear.badge.checkmark", mechanic: .reminderOnly,
            levelEffectKeys: ["state.taub.effect"], causeKey: "state.taub.cause",
            removalKey: "state.taub.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "stumm", kind: .status, nameKey: "state.stumm.name",
            iconSystemName: "mouth", mechanic: .reminderOnly,
            levelEffectKeys: ["state.stumm.effect"], causeKey: "state.stumm.cause",
            removalKey: "state.stumm.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "ueberrascht", kind: .status, nameKey: "state.ueberrascht.name",
            iconSystemName: "exclamationmark.2", mechanic: .reminderOnly,
            levelEffectKeys: ["state.ueberrascht.effect"], causeKey: "state.ueberrascht.cause",
            removalKey: "state.ueberrascht.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "unsichtbar", kind: .status, nameKey: "state.unsichtbar.name",
            iconSystemName: "eye.trianglebadge.exclamationmark", mechanic: .reminderOnly,
            levelEffectKeys: ["state.unsichtbar.effect"], causeKey: "state.unsichtbar.cause",
            removalKey: "state.unsichtbar.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "vergiftet", kind: .status, nameKey: "state.vergiftet.name",
            iconSystemName: "cross.vial", mechanic: .reminderOnly,
            levelEffectKeys: ["state.vergiftet.effect"], causeKey: "state.vergiftet.cause",
            removalKey: "state.vergiftet.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "krank", kind: .status, nameKey: "state.krank.name",
            iconSystemName: "thermometer.medium", mechanic: .reminderOnly,
            levelEffectKeys: ["state.krank.effect"], causeKey: "state.krank.cause",
            removalKey: "state.krank.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "uebler_geruch", kind: .status, nameKey: "state.uebler_geruch.name",
            iconSystemName: "wind", mechanic: .reminderOnly,
            levelEffectKeys: ["state.uebler_geruch.effect"], causeKey: "state.uebler_geruch.cause",
            removalKey: "state.uebler_geruch.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "bewegungsunfaehig", kind: .status, nameKey: "state.bewegungsunfaehig.name",
            iconSystemName: "figure.stand", mechanic: .reminderOnly,
            levelEffectKeys: ["state.bewegungsunfaehig.effect"], causeKey: "state.bewegungsunfaehig.cause",
            removalKey: "state.bewegungsunfaehig.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "handlungsunfaehig", kind: .status, nameKey: "state.handlungsunfaehig.name",
            iconSystemName: "hand.raised.slash", mechanic: .reminderOnly,
            levelEffectKeys: ["state.handlungsunfaehig.effect"], causeKey: "state.handlungsunfaehig.cause",
            removalKey: "state.handlungsunfaehig.removal", implies: ["liegend"], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "bewusstlos", kind: .status, nameKey: "state.bewusstlos.name",
            iconSystemName: "zzz", mechanic: .reminderOnly,
            levelEffectKeys: ["state.bewusstlos.effect"], causeKey: "state.bewusstlos.cause",
            removalKey: "state.bewusstlos.removal", implies: ["handlungsunfaehig", "liegend"],
            handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "versteinert", kind: .status, nameKey: "state.versteinert.name",
            iconSystemName: "cube", mechanic: .reminderOnly,
            levelEffectKeys: ["state.versteinert.effect"], causeKey: "state.versteinert.cause",
            removalKey: "state.versteinert.removal", implies: ["handlungsunfaehig", "bewegungsunfaehig"],
            handlungsunfaehigAtLevel: nil),
    ]
}
