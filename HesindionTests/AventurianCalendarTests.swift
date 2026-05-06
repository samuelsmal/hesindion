import Testing
@testable import Hesindion

@MainActor
struct AventurianCalendarTests {

    // MARK: - Month → Season

    @Test func praiosIsSummer() {
        #expect(AventurianMonth.praios.season == .sommer)
    }

    @Test func efferdIsAutumn() {
        #expect(AventurianMonth.efferd.season == .herbst)
    }

    @Test func hesindeIsWinter() {
        #expect(AventurianMonth.hesinde.season == .winter)
    }

    @Test func phexIsSpring() {
        #expect(AventurianMonth.phex.season == .fruehling)
    }

    @Test func namenloseTageIsSummer() {
        #expect(AventurianMonth.namenloseTage.season == .sommer)
    }

    // MARK: - Month ordering

    @Test func monthAfterPraiosIsRondra() {
        #expect(AventurianMonth.praios.next == .rondra)
    }

    @Test func monthAfterRahjaIsNamenloseTage() {
        #expect(AventurianMonth.rahja.next == .namenloseTage)
    }

    @Test func monthAfterNamenloseTageIsPraios() {
        #expect(AventurianMonth.namenloseTage.next == .praios)
    }

    // MARK: - Month day count

    @Test func regularMonthHas30Days() {
        #expect(AventurianMonth.praios.dayCount == 30)
    }

    @Test func namenloseTageHas5Days() {
        #expect(AventurianMonth.namenloseTage.dayCount == 5)
    }

    // MARK: - Date advancement

    @Test func nextDayWithinMonth() {
        let date = AventurianDate(day: 15, month: .praios, year: 1040)
        let next = date.next()
        #expect(next.day == 16)
        #expect(next.month == .praios)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsOverMonth() {
        let date = AventurianDate(day: 30, month: .praios, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .rondra)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsRahjaToNamenloseTage() {
        let date = AventurianDate(day: 30, month: .rahja, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .namenloseTage)
        #expect(next.year == 1040)
    }

    @Test func nextDayRollsOverYear() {
        let date = AventurianDate(day: 5, month: .namenloseTage, year: 1040)
        let next = date.next()
        #expect(next.day == 1)
        #expect(next.month == .praios)
        #expect(next.year == 1041)
    }

    // MARK: - Date formatting

    @Test func formattedRegularDate() {
        let date = AventurianDate(day: 12, month: .praios, year: 1040)
        #expect(date.formatted() == "12. Praios 1040 BF")
    }

    @Test func formattedNamenloseTage() {
        let date = AventurianDate(day: 3, month: .namenloseTage, year: 1040)
        #expect(date.formatted() == "3. Namenloser Tag 1040 BF")
    }
}
