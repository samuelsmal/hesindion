import Foundation
import SwiftData

@Model
final class PersonalData {
    var name: String
    var family: String
    var birthplace: String
    var birthdate: String
    var age: Int
    var gender: String
    var species: String
    var height: Int
    var weight: Int
    var hairColor: String
    var eyeColor: String
    var culture: String
    var socialStatus: String
    var profession: String
    var title: String
    var characteristics: String

    init(
        name: String,
        family: String,
        birthplace: String,
        birthdate: String,
        age: Int,
        gender: String,
        species: String,
        height: Int,
        weight: Int,
        hairColor: String,
        eyeColor: String,
        culture: String,
        socialStatus: String,
        profession: String,
        title: String,
        characteristics: String
    ) {
        self.name = name
        self.family = family
        self.birthplace = birthplace
        self.birthdate = birthdate
        self.age = age
        self.gender = gender
        self.species = species
        self.height = height
        self.weight = weight
        self.hairColor = hairColor
        self.eyeColor = eyeColor
        self.culture = culture
        self.socialStatus = socialStatus
        self.profession = profession
        self.title = title
        self.characteristics = characteristics
    }
}
