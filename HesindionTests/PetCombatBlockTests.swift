import Testing
@testable import Hesindion

/// The companion sheet's Kampf block lists every pet's attacks, not only the mount's (issue #49):
/// `notes` no longer carries the `Angriffe:` text, so these rows are the only place they show.
@MainActor
struct PetCombatBlockTests {

    private func pet(attacks: [PetAttack]) -> Pet {
        Pet(petId: "PET_2", name: "Rabe", size: 0.3, type: "Rabe",
            attributes: PetAttributes(mu: 10, kl: 10, inValue: 12, ch: 10, ff: 10, ge: 14, ko: 8, kk: 6),
            lifeEnergy: 8, spirit: 0, toughness: 0, initiative: "12+1W6", speed: 2,
            attack: "Schnabel", damage: "1W3", reach: "kurz", actions: 1,
            talents: "", skills: "", notes: "", attacks: attacks)
    }

    @Test func aPetWithoutEngineValuesListsItsAttacks() {
        let attacks = [PetAttack(name: "Schnabel", at: 12, damage: "1W3", reach: "kurz"),
                       PetAttack(name: "Krallen", at: 10, damage: "1W2", reach: "kurz")]
        #expect(HeroDetailView.attackRows(of: pet(attacks: attacks)) == attacks)
    }

    @Test func aPetWithNoAttacksKeepsTheGeneralPair() {
        #expect(HeroDetailView.attackRows(of: pet(attacks: [])).isEmpty)
    }
}
