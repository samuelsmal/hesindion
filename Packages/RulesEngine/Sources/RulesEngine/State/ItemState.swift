import Foundation

// Item state (spec §7): loaded, strung, a shield's current Strukturpunkte, damaged, destroyed.
// Keyed by item **instance**, never by name: two identical daggers are two items. A situation
// states it as the facts `item.<instance>.<field>`, which `Situation` keeps here; the rules read
// the item in a slot as `loadout.<slot>.<field>`, resolved through `loadout.<slot>.instance`.

/// One item instance's state: the vocabulary's `itemFields`. A field nobody stated is nil
/// (unknown), never false.
public struct ItemState: Codable, Hashable, Sendable {
    public var loaded: Bool?
    public var strung: Bool?
    /// The current Strukturpunkte (a shield's StP after the hits it took).
    public var structurePoints: Int?
    public var damaged: Bool?
    public var destroyed: Bool?
    public var ridden: Bool?
    public var held: Bool?

    public init(loaded: Bool? = nil, strung: Bool? = nil, structurePoints: Int? = nil, damaged: Bool? = nil,
                destroyed: Bool? = nil, ridden: Bool? = nil, held: Bool? = nil) {
        self.loaded = loaded; self.strung = strung; self.structurePoints = structurePoints; self.damaged = damaged
        self.destroyed = destroyed; self.ridden = ridden; self.held = held
    }

    /// The field `name` (one of `ItemDelta.fields`) as a fact value; nil when unknown.
    public subscript(field name: String) -> JSONValue? {
        switch name {
        case "loaded": loaded.map(JSONValue.bool)
        case "strung": strung.map(JSONValue.bool)
        case "structurePoints": structurePoints.map(JSONValue.int)
        case "damaged": damaged.map(JSONValue.bool)
        case "destroyed": destroyed.map(JSONValue.bool)
        case "ridden": ridden.map(JSONValue.bool)
        case "held": held.map(JSONValue.bool)
        default: nil
        }
    }

    /// Sets `name` from a fact value. False when `name` is no item field or `value` has the
    /// wrong type (the fact then stays a plain fact).
    @discardableResult
    public mutating func set(_ name: String, _ value: JSONValue) -> Bool {
        switch (name, value) {
        case ("loaded", .bool(let b)): loaded = b
        case ("strung", .bool(let b)): strung = b
        case ("damaged", .bool(let b)): damaged = b
        case ("destroyed", .bool(let b)): destroyed = b
        case ("ridden", .bool(let b)): ridden = b
        case ("held", .bool(let b)): held = b
        case ("structurePoints", _):
            guard let n = value.double.flatMap({ Values.int($0) }), Double(n) == value.double else { return false }
            structurePoints = n
        default: return false
        }
        return true
    }

    /// Makes `name` unknown again.
    public mutating func clear(_ name: String) {
        switch name {
        case "loaded": loaded = nil
        case "strung": strung = nil
        case "structurePoints": structurePoints = nil
        case "damaged": damaged = nil
        case "destroyed": destroyed = nil
        case "ridden": ridden = nil
        case "held": held = nil
        default: break
        }
    }

    public var isEmpty: Bool { self == ItemState() }
}

extension Situation {
    /// `item.<instance>.<field>` split into its instance and field, when the field is an item field.
    static func itemFact(_ name: String) -> (instance: String, field: String)? {
        let prefix = "item."
        guard name.hasPrefix(prefix), let dot = name.lastIndex(of: "."), dot > name.index(name.startIndex, offsetBy: prefix.count) else {
            return nil
        }
        let field = String(name[name.index(after: dot)...])
        guard ItemDelta.fields.contains(field) else { return nil }
        return (String(name[name.index(name.startIndex, offsetBy: prefix.count)..<dot]), field)
    }

    /// `loadout.<slot>.<field>` split into its slot and field, when the field is an item field.
    static func slotFact(_ name: String) -> (slot: String, field: String)? {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == "loadout", ItemDelta.fields.contains(parts[2]) else { return nil }
        return (parts[1], parts[2])
    }

    /// The instance in `slot` (`weapon`, `shield`, …): the fact `loadout.<slot>.instance`.
    public func instance(in slot: String) -> String? {
        facts["loadout.\(slot).instance"]?.value.string
    }

    /// The state of the item in `slot`, through its instance.
    public func item(in slot: String) -> ItemState? {
        instance(in: slot).flatMap { items[$0] }
    }

    /// States `fact`: an item field of an instance (`item.<instance>.<field>`) goes to `items`,
    /// anything else to `facts`. The one way the harness and the app state a fact.
    public mutating func state(_ fact: Fact) {
        if let (instance, field) = Self.itemFact(fact.name) {
            var item = items[instance] ?? ItemState()
            if item.set(field, fact.value) {
                items[instance] = item
                facts[fact.name] = nil
                return
            }
        }
        facts[fact.name] = fact
    }
}
