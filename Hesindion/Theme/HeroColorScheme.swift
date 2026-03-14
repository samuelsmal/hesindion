import SwiftUI

struct HeroColorScheme: Identifiable {
    let id: String
    let name: String
    /// Exactly 4 colors: gradient dark → light for sections (Personal Data, Talents, Combat, Equipment).
    let sectionColors: [Color]
    /// Text color for section headers.
    let textColor: Color
    /// Sidebar highlight / accent color.
    let accentColor: Color

    /// Safe indexed access into sectionColors (4 entries).
    func groupColor(at index: Int) -> Color {
        guard index >= 0, index < sectionColors.count else { return sectionColors.last ?? .gray }
        return sectionColors[index]
    }
}

// MARK: - Static schemes

extension HeroColorScheme {

    static let defaultGolden = HeroColorScheme(
        id: "defaultGolden",
        name: "Standard (Gold)",
        sectionColors: [
            Color(hex: 0xf5c400),
            Color(hex: 0x1d4ed8),
            Color(hex: 0xdc2626),
            Color(hex: 0x16a34a)
        ],
        textColor: .primary,
        accentColor: Color(hex: 0xf5c400)
    )

    static let boron = HeroColorScheme(
        id: "boron",
        name: "Boron / Golgarit",
        sectionColors: [
            Color(hex: 0x1a0a2e),
            Color(hex: 0x2d1650),
            Color(hex: 0x4a2578),
            Color(hex: 0x6b3fa0)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x4a2578)
    )

    static let praios = HeroColorScheme(
        id: "praios",
        name: "Praios",
        sectionColors: [
            Color(hex: 0x5c3d00),
            Color(hex: 0x8b6914),
            Color(hex: 0xb8942a),
            Color(hex: 0xd4b44a)
        ],
        textColor: .white,
        accentColor: Color(hex: 0xb8942a)
    )

    static let rondra = HeroColorScheme(
        id: "rondra",
        name: "Rondra / Kor",
        sectionColors: [
            Color(hex: 0x4a0e0e),
            Color(hex: 0x6b1a1a),
            Color(hex: 0x8c2f2f),
            Color(hex: 0xa84545)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x8c2f2f)
    )

    static let peraine = HeroColorScheme(
        id: "peraine",
        name: "Peraine",
        sectionColors: [
            Color(hex: 0x0a2e14),
            Color(hex: 0x165028),
            Color(hex: 0x227840),
            Color(hex: 0x2ea058)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x227840)
    )

    static let hesinde = HeroColorScheme(
        id: "hesinde",
        name: "Hesinde",
        sectionColors: [
            Color(hex: 0x0a1a3e),
            Color(hex: 0x142e5c),
            Color(hex: 0x1e4280),
            Color(hex: 0x2856a4)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x1e4280)
    )

    static let phex = HeroColorScheme(
        id: "phex",
        name: "Phex",
        sectionColors: [
            Color(hex: 0x1a1a22),
            Color(hex: 0x2e2e3a),
            Color(hex: 0x444456),
            Color(hex: 0x5a5a70)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x444456)
    )

    static let efferd = HeroColorScheme(
        id: "efferd",
        name: "Efferd",
        sectionColors: [
            Color(hex: 0x0a1e2e),
            Color(hex: 0x143450),
            Color(hex: 0x1e4a78),
            Color(hex: 0x2860a0)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x1e4a78)
    )

    static let firun = HeroColorScheme(
        id: "firun",
        name: "Firun / Ifirn",
        sectionColors: [
            Color(hex: 0x1a2230),
            Color(hex: 0x2e3a4a),
            Color(hex: 0x445264),
            Color(hex: 0x5a6a80)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x445264)
    )

    static let ingerimm = HeroColorScheme(
        id: "ingerimm",
        name: "Ingerimm",
        sectionColors: [
            Color(hex: 0x2e1a0a),
            Color(hex: 0x503014),
            Color(hex: 0x78461e),
            Color(hex: 0xa05c28)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x78461e)
    )

    static let rahja = HeroColorScheme(
        id: "rahja",
        name: "Rahja",
        sectionColors: [
            Color(hex: 0x2e0a1a),
            Color(hex: 0x501430),
            Color(hex: 0x781e46),
            Color(hex: 0xa0285c)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x781e46)
    )

    static let travia = HeroColorScheme(
        id: "travia",
        name: "Travia",
        sectionColors: [
            Color(hex: 0x2e1e0a),
            Color(hex: 0x503414),
            Color(hex: 0x784a1e),
            Color(hex: 0xa06028)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x784a1e)
    )

    static let tsa = HeroColorScheme(
        id: "tsa",
        name: "Tsa",
        sectionColors: [
            Color(hex: 0x0a2e1e),
            Color(hex: 0x145034),
            Color(hex: 0x1e784a),
            Color(hex: 0x28a060)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x1e784a)
    )

    static let swafnir = HeroColorScheme(
        id: "swafnir",
        name: "Swafnir",
        sectionColors: [
            Color(hex: 0x181e24),
            Color(hex: 0x28323c),
            Color(hex: 0x3c4856),
            Color(hex: 0x505e70)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x3c4856)
    )

    static let namenlos = HeroColorScheme(
        id: "namenlos",
        name: "Namenloser",
        sectionColors: [
            Color(hex: 0x0a0a0e),
            Color(hex: 0x16161e),
            Color(hex: 0x222230),
            Color(hex: 0x2e2e42)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x222230)
    )

    static let krieger = HeroColorScheme(
        id: "krieger",
        name: "Krieger / Ritter",
        sectionColors: [
            Color(hex: 0x14181e),
            Color(hex: 0x242c36),
            Color(hex: 0x384050),
            Color(hex: 0x4c586a)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x384050)
    )

    static let magier = HeroColorScheme(
        id: "magier",
        name: "Magier",
        sectionColors: [
            Color(hex: 0x0e0a2e),
            Color(hex: 0x1a1650),
            Color(hex: 0x282278),
            Color(hex: 0x3630a0)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x282278)
    )

    static let hexe = HeroColorScheme(
        id: "hexe",
        name: "Hexe",
        sectionColors: [
            Color(hex: 0x0a1e0a),
            Color(hex: 0x163416),
            Color(hex: 0x224a22),
            Color(hex: 0x2e602e)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x224a22)
    )

    static let mundane = HeroColorScheme(
        id: "mundane",
        name: "Mundan",
        sectionColors: [
            Color(hex: 0x2e1a0a),
            Color(hex: 0x4a2e14),
            Color(hex: 0x66421e),
            Color(hex: 0x825628)
        ],
        textColor: .white,
        accentColor: Color(hex: 0x66421e)
    )

    static let allSchemes: [HeroColorScheme] = [
        .defaultGolden, .boron, .praios, .rondra, .peraine, .hesinde,
        .phex, .efferd, .firun, .ingerimm, .rahja, .travia, .tsa,
        .swafnir, .namenlos, .krieger, .magier, .hexe, .mundane
    ]
}

// MARK: - Profession mapping

extension HeroColorScheme {

    static func schemeForProfession(_ profession: String) -> HeroColorScheme {
        let p = profession.lowercased()

        if p.contains("golgarit") || p.contains("borongeweih") { return .boron }
        if p.contains("praiosgeweih") { return .praios }
        if p.contains("rondrageweih") || p.contains("kor-geweih") { return .rondra }
        if p.contains("perainegeweih") { return .peraine }
        if p.contains("hesindegeweih") { return .hesinde }
        if p.contains("phexgeweih") { return .phex }
        if p.contains("efferdgeweih") { return .efferd }
        if p.contains("firungeweih") || p.contains("ifirn-geweih") { return .firun }
        if p.contains("ingerimmgeweih") { return .ingerimm }
        if p.contains("rahjageweih") { return .rahja }
        if p.contains("travia-geweih") { return .travia }
        if p.contains("tsakgeweih") { return .tsa }
        if p.contains("swafnir-geweih") { return .swafnir }
        if p.contains("namenloser geweih") || p.contains("gravesh") { return .namenlos }

        if p.contains("magier") || p.contains("bannstrahler") || p.contains("borbaradianer") || p.contains("qabalyamagier") { return .magier }
        if p.contains("zauberbarde") || p.contains("zaubertänzer") || p.contains("schelm") || p.contains("durro-dûn") { return .magier }
        if p.contains("fakir") || p.contains("zibilja") || p.contains("sangara") { return .magier }

        if p.contains("hexe") { return .hexe }

        if p.contains("krieger") || p.contains("ritter") || p.contains("söldner") || p.contains("gardist") || p.contains("ordenskrieger") || p.contains("amazone") || p.contains("lanisto") || p.contains("ferkina") { return .krieger }
        if p.contains("stammeskrieger") || p.contains("tierkrieger") { return .krieger }
        if p.contains("scharfschütze") || p.contains("kopfgeldjäger") { return .krieger }

        return .mundane
    }

    static func scheme(for hero: Hero) -> HeroColorScheme {
        if let id = hero.colorSchemeId,
           let scheme = allSchemes.first(where: { $0.id == id }) {
            return scheme
        }
        let profession = hero.personalData?.profession ?? ""
        if profession.isEmpty { return .defaultGolden }
        return schemeForProfession(profession)
    }
}

// MARK: - Color hex initializer (private utility)

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
