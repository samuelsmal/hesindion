import Testing
@testable import Hesindion

struct StretchGenerationTests {
    @Test func gapDetectedWhenStartBeyondNext() {
        let last = AventurianDate(day: 10, month: .praios, year: 1040)
        let contiguous = AventurianDate(day: 11, month: .praios, year: 1040)
        let jumped = AventurianDate(day: 20, month: .praios, year: 1040)
        #expect(StretchPlanner.isGap(start: contiguous, after: last) == false)
        #expect(StretchPlanner.isGap(start: jumped, after: last) == true)
        #expect(StretchPlanner.isGap(start: contiguous, after: nil) == false)
    }
}
