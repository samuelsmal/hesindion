# iDSACompanion Agent Memory

See topic files for details. Key references:
- patterns.md — API quirks, SwiftUI patterns, project conventions

## Critical: AppCommand is not Equatable
`AppCommand` holds a closure `execute: (CommandInput.Result?) -> Void`, so it cannot conform to `Equatable`.
Never use `.onChange(of: activeCommand)` — use `.onChange(of: activeCommand?.id)` instead (UUID is Equatable).

## Font API on iOS 26
`Font.system(_:weight:design:)` with three named parameters (style + weight + design simultaneously) does NOT compile.
Use two-param overloads and chain: `.font(.system(.title3, weight: .black))` + `.fontDesign(.monospaced)`.

## PBXFileSystemSynchronizedRootGroup
The project uses `PBXFileSystemSynchronizedRootGroup` (not traditional PBXGroup+PBXFileReference).
New Swift files placed in the correct subdirectory of `iDSACompanion/` are automatically picked up.
No pbxproj edits needed for new source files.

## @ViewBuilder limitations
Inside a `@ViewBuilder` function, imperative Swift (e.g. `let x: String; switch { x = ... }`) is NOT valid.
Extract computed values into separate non-ViewBuilder helper functions, then call the helper from the `@ViewBuilder` body.
