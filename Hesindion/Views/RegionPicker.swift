import SwiftUI

/// Region selection grouped by macro-region. Reused in creation, add-stretch, and day-edit.
struct RegionPicker: View {
    @Binding var selection: WeatherRegion
    var label: String = L("adventureRegion")

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(MacroRegion.allCases) { macro in
                Section(macro.displayName) {
                    ForEach(WeatherRegion.inMacro(macro)) { region in
                        Text(region.displayName).tag(region)
                    }
                }
            }
        }
    }
}
