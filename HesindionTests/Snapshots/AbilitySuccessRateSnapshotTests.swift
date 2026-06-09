import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// Renders the completed ability-success-rate work to images:
///  - talent rows with the theoretical success dot + %, one row expanded to show
///    the recorded rate
///  - the Log panel grouped into play sessions with per-session success headers
final class AbilitySuccessRateSnapshotTests: XCTestCase {

    /// Two play sessions ~2 days apart, with talent checks to populate recorded rates.
    @MainActor
    private func seedLog(for hero: Hero, in context: ModelContext) {
        // session 1 base time, session 2 is +2 days (well past the 8h threshold)
        let s1 = Date(timeIntervalSince1970: 1_700_000_000)
        let s2 = s1.addingTimeInterval(2 * 24 * 3600)
        func add(_ name: String, _ qs: Int, _ ok: Bool, _ date: Date) {
            let entry = LogEntry.create(kind: "talentCheck",
                                        payload: TalentCheckPayload(talentName: name, qualityLevel: qs, succeeded: ok),
                                        hero: hero)
            entry.timestamp = date
            context.insert(entry)
        }
        // Session 1
        add("Verbergen", 1, true,  s1.addingTimeInterval(60))
        add("Verbergen", 2, true,  s1.addingTimeInterval(600))
        add("Verbergen", 0, false, s1.addingTimeInterval(1200))
        add("Klettern",  1, true,  s1.addingTimeInterval(1800))
        add("Klettern",  0, false, s1.addingTimeInterval(2400))
        // Session 2
        add("Verbergen", 0, false, s2.addingTimeInterval(60))
        add("Sinnesschärfe", 3, true, s2.addingTimeInterval(600))
    }

    @MainActor
    func testTalentRowsWithSuccessRates() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let context = ModelContext(container)
        seedLog(for: hero, in: context)

        let checks = hero.logEntries.compactMap { entry -> TalentStatistics.Check? in
            guard entry.kind == "talentCheck",
                  let p = entry.decodePayload(TalentCheckPayload.self) else { return nil }
            return TalentStatistics.Check(name: p.talentName, succeeded: p.succeeded, date: entry.timestamp)
        }

        let talents = hero.talents
            .filter { $0.category == "Körpertalente" }
            .sorted { $0.name < $1.name }

        func rate(_ talent: Talent) -> Double {
            guard let attrs = hero.attributes,
                  let data = TalentProbeAttributes.lookup(talent: talent.name, attributes: attrs) else { return 0 }
            return SkillCheckEngine.successProbability(attributeValues: data.values, skillPoints: talent.value)
        }

        let view = VStack(spacing: 0) {
            Text("KÖRPERTALENTE")
                .font(.system(.subheadline, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.groupTalents.opacity(0.15))
            ForEach(talents, id: \.persistentModelID) { talent in
                TalentSwipeContent(
                    name: talent.name,
                    value: talent.value,
                    probeKeys: TalentProbeAttributes.checks[talent.name],
                    successRate: rate(talent),
                    record: TalentStatistics.record(for: talent.name, checks: checks),
                    isExpanded: talent.name == "Verbergen"   // show the recorded detail
                )
                Divider()
            }
        }
        .frame(width: 540)
        .background(Color(UIColor.systemBackground))
        .environment(\.colorScheme, .light)

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), named: "talent_rows")
    }

    @MainActor
    func testLogPanelWithSessionHeaders() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let context = ModelContext(container)
        seedLog(for: hero, in: context)

        let view = LogPanelView(hero: hero)
            .modelContainer(container)
            .frame(width: 440, height: 720)
            .environment(\.colorScheme, .light)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 440, height: 720)), named: "log_sessions")
    }
}
