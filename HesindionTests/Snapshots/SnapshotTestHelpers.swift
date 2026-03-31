import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// Standard iPad configurations for snapshot testing.
enum iPadConfig {
    /// iPad Pro 11-inch (M5) — primary test device
    static func pro11(style: UIUserInterfaceStyle = .light) -> ViewImageConfig {
        ViewImageConfig(
            safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            size: CGSize(width: 1024, height: 1366),
            traits: UITraitCollection { traits in
                traits.userInterfaceIdiom = .pad
                traits.displayScale = 2
                traits.horizontalSizeClass = .regular
                traits.verticalSizeClass = .regular
                traits.userInterfaceStyle = style
            }
        )
    }

    /// iPad Pro 13-inch
    static func pro13(style: UIUserInterfaceStyle = .light) -> ViewImageConfig {
        ViewImageConfig(
            safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            size: CGSize(width: 1032, height: 1376),
            traits: UITraitCollection { traits in
                traits.userInterfaceIdiom = .pad
                traits.displayScale = 2
                traits.horizontalSizeClass = .regular
                traits.verticalSizeClass = .regular
                traits.userInterfaceStyle = style
            }
        )
    }
}

/// All variant axes for snapshot testing.
struct SnapshotVariant: CustomStringConvertible {
    let name: String
    let config: ViewImageConfig
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize

    var description: String { name }

    static let all: [SnapshotVariant] = {
        let schemes: [(String, ColorScheme, UIUserInterfaceStyle)] = [
            ("light", .light, .light),
            ("dark", .dark, .dark),
        ]
        let typeSizes: [(String, DynamicTypeSize)] = [
            ("default", .large),
            ("accL", .accessibility1),
            ("accXXXL", .accessibility3),
        ]

        var variants: [SnapshotVariant] = []
        for (schemeName, scheme, style) in schemes {
            for (sizeName, size) in typeSizes {
                variants.append(SnapshotVariant(
                    name: "iPad11_\(schemeName)_\(sizeName)",
                    config: iPadConfig.pro11(style: style),
                    colorScheme: scheme,
                    dynamicTypeSize: size
                ))
                variants.append(SnapshotVariant(
                    name: "iPad13_\(schemeName)_\(sizeName)",
                    config: iPadConfig.pro13(style: style),
                    colorScheme: scheme,
                    dynamicTypeSize: size
                ))
            }
        }
        return variants
    }()
}

extension XCTestCase {
    /// Snapshot a SwiftUI view across all 12 iPad variants.
    @MainActor
    func assertAllVariants<V: View>(
        of view: V,
        named name: String,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        record: SnapshotTestingConfiguration.Record? = nil,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        for variant in SnapshotVariant.all {
            let styledView = view
                .environment(\.colorScheme, variant.colorScheme)
                .dynamicTypeSize(variant.dynamicTypeSize)

            assertSnapshot(
                of: styledView,
                as: .image(
                    precision: precision,
                    perceptualPrecision: perceptualPrecision,
                    layout: .device(config: variant.config)
                ),
                named: "\(name)_\(variant.name)",
                record: record,
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
        }
    }
}
