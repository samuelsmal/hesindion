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

struct MutableResourceValue: Codable {
    var current: Int
    var bonus: Int
    var max: Int
}

// MARK: - Model

@Model
final class DerivedValues {
    var lebensenergie: LifeEnergyValue
    var astralenergie: MutableResourceValue?
    var karmaenergie: MutableResourceValue?
    var seelenkraft: ResourceValue
    var zaehigkeit: ResourceValue
    var ausweichen: ComputedValue
    var initiative: ComputedValue
    var geschwindigkeit: ResourceValue
    var wundschwelle: ComputedValue
    var schicksalspunkte: MutableResourceValue

    init(
        lebensenergie: LifeEnergyValue,
        astralenergie: MutableResourceValue?,
        karmaenergie: MutableResourceValue?,
        seelenkraft: ResourceValue,
        zaehigkeit: ResourceValue,
        ausweichen: ComputedValue,
        initiative: ComputedValue,
        geschwindigkeit: ResourceValue,
        wundschwelle: ComputedValue,
        schicksalspunkte: MutableResourceValue
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
