import Foundation

/// Any JSON value. The model uses it only where the vocabulary says `data` or `list` (a
/// `provide`'s value, an `offer`'s default and options, a comparison's operand), for rule
/// metadata (`provides`, `source`, `manoeuvre`) and for a selector id that is a property match.
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case null, bool(Bool), int(Int), double(Double), string(String), array([JSONValue]), object([String: JSONValue])

    /// Tries null, bool, int, double, string, array, object, in that order.
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "not a JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public var string: String? { if case .string(let s) = self { s } else { nil } }
    /// An int, or a double that is a whole number.
    public var int: Int? {
        switch self {
        case .int(let i): i
        case .double(let d) where d.rounded() == d: Int(exactly: d)
        default: nil
        }
    }
    public var double: Double? {
        switch self {
        case .int(let i): Double(i)
        case .double(let d): d
        default: nil
        }
    }
}

/// A coding key for any string: objects whose keys are data (a target's contexts, a condition's
/// fact and comparison).
struct AnyKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where K == AnyKey {
    /// The container's one key, or a decoding error naming what was expected.
    func onlyKey(_ what: String) throws -> String {
        guard allKeys.count == 1, let k = allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath,
                debugDescription: "\(what) has exactly one key, found \(allKeys.map(\.stringValue).sorted())"))
        }
        return k.stringValue
    }
}
