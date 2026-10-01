import SwiftUI

/// One glyph for a piece of the loadout, whether it comes from SF Symbols or
/// from the asset catalogue.
struct WeaponIconView: View {
    let icon: WeaponIcon

    init(_ icon: WeaponIcon) {
        self.icon = icon
    }

    /// Convenience for the common case: a melee weapon knows its technique.
    init(techniqueId: String?) {
        self.icon = WeaponIcon.forTechniqueId(techniqueId)
    }

    var body: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
        case .asset(let name):
            // Sized to the surrounding font the way an SF Symbol is, so the two
            // sit at the same weight in a row that mixes them.
            Image(name)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: DSALayout.weaponIconSize, height: DSALayout.weaponIconSize)
        }
    }
}
