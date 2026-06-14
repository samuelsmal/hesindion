import Testing
@testable import Hesindion

struct WeatherEnumsTests {

    // MARK: - Cloud temperature modifiers

    @Test func cloudModifiers() {
        #expect(CloudCover.none.temperatureModifier == 6)
        #expect(CloudCover.few.temperatureModifier == 3)
        #expect(CloudCover.lots.temperatureModifier == -1)
        #expect(CloudCover.all.temperatureModifier == -4)
    }

    @Test func cloudFactors() {
        #expect(CloudCover.none.cloudFactor == 1.0)
        #expect(CloudCover.few.cloudFactor == 0.8)
        #expect(CloudCover.lots.cloudFactor == 0.6)
        #expect(CloudCover.all.cloudFactor == 0.45)
    }

    // MARK: - Wind temperature modifiers

    @Test func windModifiers() {
        #expect(WindStrength.none.temperatureModifier == 2)
        #expect(WindStrength.light.temperatureModifier == 1)
        #expect(WindStrength.soft.temperatureModifier == 0)
        #expect(WindStrength.fresh.temperatureModifier == 0)
        #expect(WindStrength.cool.temperatureModifier == -2)
        #expect(WindStrength.strong.temperatureModifier == -3)
        #expect(WindStrength.storm.temperatureModifier == -4)
    }

    @Test func windNightReductions() {
        #expect(WindStrength.none.nightWindReduction == 0)
        #expect(WindStrength.light.nightWindReduction == 0)
        #expect(WindStrength.soft.nightWindReduction == 2)
        #expect(WindStrength.fresh.nightWindReduction == 2)
        #expect(WindStrength.cool.nightWindReduction == 4)
        #expect(WindStrength.strong.nightWindReduction == 4)
        #expect(WindStrength.storm.nightWindReduction == 5)
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
