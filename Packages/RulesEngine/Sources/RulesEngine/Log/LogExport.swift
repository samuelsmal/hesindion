import Foundation

/// The session log as JSON Lines (spec §8): one entry per line, keys sorted, ISO-8601 dates, a
/// newline after each line. Every field name is the Swift property's, lowerCamelCase, in the
/// vocabulary's one language (§3.1). The keys of the data maps are data, not field names: rule
/// ids (`situation.owned`), query strings (`situation.base`), pools, process ids, item instances,
/// fact names (`answers`) and item fields (`events[].change`).
public enum LogExport {
    /// The export: `entries`, one JSON object per line. Empty for no entries.
    public static func jsonLines(_ entries: [LogEntry]) -> String {
        let encoder = Self.encoder
        return entries.map { entry in
            // Encoding plain values fails only on a non-finite number, which the encoder writes
            // as a string; the fallback keeps the line and says why.
            guard let data = try? encoder.encode(entry) else {
                return #"{"exportFailed":true,"id":"\#(entry.id.uuidString)"}"# + "\n"
            }
            return String(decoding: data, as: UTF8.self) + "\n"
        }.joined()
    }

    /// Reads an export back: one entry per non-empty line.
    public static func entries(fromJSONLines text: String) throws -> [LogEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "nan")
        return try text.split(separator: "\n").map { try decoder.decode(LogEntry.self, from: Data($0.utf8)) }
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "nan")
        return encoder
    }
}
