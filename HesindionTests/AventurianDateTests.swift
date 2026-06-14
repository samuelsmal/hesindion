import Testing
@testable import Hesindion

struct AventurianDateTests {
    @Test func ordinalOrders() {
        let a = AventurianDate(day: 30, month: .praios, year: 1040)
        let b = AventurianDate(day: 1, month: .rondra, year: 1040)
        #expect(b.ordinal() == a.ordinal() + 1)
    }
    @Test func yearIs365Days() {
        let a = AventurianDate(day: 1, month: .praios, year: 1040)
        let b = AventurianDate(day: 1, month: .praios, year: 1041)
        #expect(b.ordinal() - a.ordinal() == 365)
    }
    @Test func addingMatchesNext() {
        var d = AventurianDate(day: 28, month: .praios, year: 1040)
        let added = d.adding(days: 5)
        for _ in 0..<5 { d = d.next() }
        #expect(added == d)
        #expect(AventurianDate(day: 3, month: .tsa, year: 7).adding(days: 0)
                == AventurianDate(day: 3, month: .tsa, year: 7))
    }
}
