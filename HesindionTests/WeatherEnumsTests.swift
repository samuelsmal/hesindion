import Testing
@testable import Hesindion

struct WeatherEnumsTests {

    // MARK: - Region base temperatures

    @Test func mittelreichSummerIs15() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .sommer) == 15)
    }

    @Test func mittelreichWinterIs5() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .winter) == 5)
    }

    @Test func mittelreichSpringAutumnIs10() {
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .herbst) == 10)
        #expect(WeatherRegion.mittelreich.baseTemperature(for: .fruehling) == 10)
    }

    @Test func khomSummerIs40() {
        #expect(WeatherRegion.khom.baseTemperature(for: .sommer) == 40)
    }

    @Test func ewigesEisWinterIsMinus40() {
        #expect(WeatherRegion.ewigesEis.baseTemperature(for: .winter) == -40)
    }

    // MARK: - Cloud temperature modifiers

    @Test func cloudModifiers() {
        #expect(CloudCover.none.temperatureModifier == 10)
        #expect(CloudCover.few.temperatureModifier == 5)
        #expect(CloudCover.lots.temperatureModifier == 0)
        #expect(CloudCover.all.temperatureModifier == -5)
    }

    // MARK: - Wind temperature modifiers

    @Test func windModifiers() {
        #expect(WindStrength.none.temperatureModifier == 4)
        #expect(WindStrength.light.temperatureModifier == 2)
        #expect(WindStrength.soft.temperatureModifier == 0)
        #expect(WindStrength.fresh.temperatureModifier == 0)
        #expect(WindStrength.cool.temperatureModifier == -2)
        #expect(WindStrength.strong.temperatureModifier == -4)
        #expect(WindStrength.storm.temperatureModifier == -6)
    }

    // MARK: - Display names exist

    @Test func allRegionsHaveDisplayNames() {
        for region in WeatherRegion.allCases {
            #expect(!region.displayName.isEmpty)
        }
    }

    @Test func allCloudCoverHaveDisplayNames() {
        for cloud in CloudCover.allCases {
            #expect(!cloud.displayName.isEmpty)
        }
    }

    @Test func allWindStrengthsHaveDisplayNames() {
        for wind in WindStrength.allCases {
            #expect(!wind.displayName.isEmpty)
        }
    }

    @Test func allRainLevelsHaveDisplayNames() {
        for rain in RainLevel.allCases {
            #expect(!rain.displayName.isEmpty)
        }
    }

    // MARK: - Two-layer region model

    @Test func everyRegionMapsToArchetypeAndMacro() {
        for r in WeatherRegion.allCases {
            _ = r.archetype          // must compile + not crash
            _ = r.macroRegion
            #expect(!r.displayName.isEmpty)
        }
    }

    @Test func legacyRawValuesResolve() {
        #expect(WeatherRegion.resolve(persisted: "weiden") == .streitendeKoenigreiche)
        #expect(WeatherRegion.resolve(persisted: "horasreichSued") == .ersteSonne)
        #expect(WeatherRegion.resolve(persisted: "tundra") == .nivesenland)
        #expect(WeatherRegion.resolve(persisted: "hoherNorden") == .nivesenland)
        #expect(WeatherRegion.resolve(persisted: "mittelreich") == .mittelreich)   // unchanged
        #expect(WeatherRegion.resolve(persisted: "khom") == .khom)                  // unchanged
        #expect(WeatherRegion.resolve(persisted: "") == .mittelreich)              // fallback
        #expect(WeatherRegion.resolve(persisted: "garbage") == .mittelreich)
    }
}
