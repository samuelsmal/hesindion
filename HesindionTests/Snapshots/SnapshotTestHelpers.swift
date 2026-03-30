import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// Standard iPad configurations for snapshot testing.
enum iPadConfig {
    /// iPad Pro 11-inch (M5) — primary test device
    static let pro11 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
        size: CGSize(width: 1024, height: 1366),
        traits: UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
            traits.horizontalSizeClass = .regular
            traits.verticalSizeClass = .regular
        }
    )

    /// iPad Pro 13-inch
    static let pro13 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
        size: CGSize(width: 1032, height: 1376),
        traits: UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
            traits.horizontalSizeClass = .regular
            traits.verticalSizeClass = .regular
        }
    )
}

/// All variant axes for snapshot testing.
struct SnapshotVariant: CustomStringConvertible {
    let name: String
    let config: ViewImageConfig
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize

    var description: String { name }

    static let all: [SnapshotVariant] = {
        let configs: [(String, ViewImageConfig)] = [
            ("iPad11", iPadConfig.pro11),
            ("iPad13", iPadConfig.pro13),
        ]
        let schemes: [(String, ColorScheme)] = [
            ("light", .light),
            ("dark", .dark),
        ]
        let typeSizes: [(String, DynamicTypeSize)] = [
            ("default", .large),
            ("accL", .accessibility1),
            ("accXXXL", .accessibility3),
        ]

        var variants: [SnapshotVariant] = []
        for (configName, config) in configs {
            for (schemeName, scheme) in schemes {
                for (sizeName, size) in typeSizes {
                    variants.append(SnapshotVariant(
                        name: "\(configName)_\(schemeName)_\(sizeName)",
                        config: config,
                        colorScheme: scheme,
                        dynamicTypeSize: size
                    ))
                }
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
                as: .image(layout: .device(config: variant.config)),
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
