import Foundation

struct HeroTrait: Codable, Hashable {
    var ruleId: String
    var name: String
    var tier: Int?
    var sid: String?
}
