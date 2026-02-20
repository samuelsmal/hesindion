import Foundation
import SwiftData

// MARK: - Value types (Codable, shared with DTO layer)

struct LifeEnergyValue: Codable {
    var base: Int
    var bonus: Int
    var purchased: Int
    var max: Int
    var current: Int
}

struct ResourceValue: Codable {
    var base: Int
    var bonus: Int
    var max: Int
}

struct ComputedValue: Codable {
    var value: Int
    var bonus: Int
    var max: Int
}

// MARK: - Model

@Model
final class DerivedValues {
    var lebensenergie: LifeEnergyValue
    var astralenergie: LifeEnergyValue?
    var karmaenergie: LifeEnergyValue?
    var seelenkraft: ResourceValue
    var zaehigkeit: ResourceValue
    var ausweichen: ComputedValue
    var initiative: ComputedValue
    var geschwindigkeit: ResourceValue
    var wundschwelle: ComputedValue
    var schicksalspunkte: ComputedValue

    init(
        lebensenergie: LifeEnergyValue,
        astralenergie: LifeEnergyValue?,
        karmaenergie: LifeEnergyValue?,
        seelenkraft: ResourceValue,
        zaehigkeit: ResourceValue,
        ausweichen: ComputedValue,
        initiative: ComputedValue,
        geschwindigkeit: ResourceValue,
        wundschwelle: ComputedValue,
        schicksalspunkte: ComputedValue
    ) {
        self.lebensenergie = lebensenergie
        self.astralenergie = astralenergie
        self.karmaenergie = karmaenergie
        self.seelenkraft = seelenkraft
        self.zaehigkeit = zaehigkeit
        self.ausweichen = ausweichen
        self.initiative = initiative
        self.geschwindigkeit = geschwindigkeit
        self.wundschwelle = wundschwelle
        self.schicksalspunkte = schicksalspunkte
    }
}
