import XCTest
@testable import Hesindion

final class StateLocalizationTests: XCTestCase {
    /// L(key) returns the raw key string on a miss (DSAStrings.localized: englishFallback[key] ?? key).
    /// So a key "resolves" iff L(key) != key.
    func testEveryCatalogKeyResolves() {
        for def in StateCatalog.all {
            assertResolves(def.nameKey, in: def.id)
            assertResolves(def.causeKey, in: def.id)
            assertResolves(def.removalKey, in: def.id)
            for key in def.levelEffectKeys {
                assertResolves(key, in: def.id)
            }
        }

        // UI / meta keys
        for key in [
            "source.zustandCap",
            "states.section",
            "states.add",
            "states.remove",
            "states.handlungsunfaehig.banner",
            "states.bewegungsunfaehig.banner",
            "states.gottgefaellig",
        ] {
            assertResolves(key, in: "ui")
        }
    }

    private func assertResolves(_ key: String, in context: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(L(key), key,
                          "key \"\(key)\" (\(context)) does not resolve — missing translation",
                          file: file, line: line)
    }
}
