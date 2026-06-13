import Foundation

// MARK: - Season

enum AventurianSeason: String, Codable, CaseIterable {
    case sommer, herbst, winter, fruehling
}

// MARK: - Month

enum AventurianMonth: Int, Codable, CaseIterable, Identifiable {
    case praios = 1
    case rondra = 2
    case efferd = 3
    case travia = 4
    case boron = 5
    case hesinde = 6
    case firun = 7
    case tsa = 8
    case phex = 9
    case peraine = 10
    case ingerimm = 11
    case rahja = 12
    case namenloseTage = 13

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .praios: "Praios"
        case .rondra: "Rondra"
        case .efferd: "Efferd"
        case .travia: "Travia"
        case .boron: "Boron"
        case .hesinde: "Hesinde"
        case .firun: "Firun"
        case .tsa: "Tsa"
        case .phex: "Phex"
        case .peraine: "Peraine"
        case .ingerimm: "Ingerimm"
        case .rahja: "Rahja"
        case .namenloseTage: "Namenlose Tage"
        }
    }

    var season: AventurianSeason {
        switch self {
        case .praios, .rondra, .rahja, .namenloseTage: .sommer
        case .efferd, .travia, .boron: .herbst
        case .hesinde, .firun, .tsa: .winter
        case .phex, .peraine, .ingerimm: .fruehling
        }
    }

    var dayCount: Int {
        self == .namenloseTage ? 5 : 30
    }

    var next: AventurianMonth {
        if self == .namenloseTage { return .praios }
        return AventurianMonth(rawValue: rawValue + 1)!
    }
}

// MARK: - Date

struct AventurianDate: Equatable, Codable, Hashable {
    var day: Int
    var month: AventurianMonth
    var year: Int

    var season: AventurianSeason { month.season }

    func next() -> AventurianDate {
        if day < month.dayCount {
            return AventurianDate(day: day + 1, month: month, year: year)
        }
        let nextMonth = month.next
        let nextYear = month == .namenloseTage ? year + 1 : year
        return AventurianDate(day: 1, month: nextMonth, year: nextYear)
    }

    func formatted() -> String {
        if month == .namenloseTage {
            return "\(day). Namenloser Tag \(year) BF"
        }
        return "\(day). \(month.displayName) \(year) BF"
    }
}

extension AventurianDate {
    /// Absolute day index. Year length is fixed at 365 (12×30 + 5 Namenlose Tage).
    func ordinal() -> Int {
        var dayOfYear = day
        var m = AventurianMonth.praios
        while m != month {
            dayOfYear += m.dayCount
            m = m.next
        }
        return year * 365 + dayOfYear
    }

    /// This date plus `days` (clamped at 0), via the canonical `next()` rollover.
    func adding(days: Int) -> AventurianDate {
        var d = self
        for _ in 0..<max(0, days) { d = d.next() }
        return d
    }
}
