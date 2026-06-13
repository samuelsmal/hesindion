import Testing
@testable import Hesindion

struct ClimateArchetypeTests {
    @Test func everyArchetypeHasSaneTemps() {
        for a in ClimateArchetype.allCases {
            for s in AventurianSeason.allCases {
                #expect(a.clearSkyRange(for: s) >= 2)
            }
            // monotonic: summer >= spring/autumn >= winter
            #expect(a.clearSkyRange(for: .sommer) >= a.clearSkyRange(for: .fruehling))
            #expect(a.clearSkyRange(for: .fruehling) >= a.clearSkyRange(for: .winter))
            #expect(a.baseDayTemp(for: .sommer) >= a.baseDayTemp(for: .winter))
        }
    }

    @Test func desertSwingsMoreThanTropics() {
        #expect(ClimateArchetype.desert.clearSkyRange(for: .sommer)
              > ClimateArchetype.tropicalSea.clearSkyRange(for: .sommer))
    }

    @Test func humidityAndWindAssigned() {
        #expect(ClimateArchetype.desert.humidity == .dry)
        #expect(ClimateArchetype.tropicalHumid.humidity == .humid)
        #expect(ClimateArchetype.temperate.windiness == .calm)
        #expect(ClimateArchetype.desert.windiness == .windy)
    }
}
