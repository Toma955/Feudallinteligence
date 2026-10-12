import Testing
@testable import Feudalism

@Suite("ResourceAmountPerTick")
struct ResourceAmountPerTickTests {

    @Test("zero has no production or consumption")
    func zero() {
        #expect(ResourceAmountPerTick.zero.hasAny == false)
        #expect(ResourceAmountPerTick.zero.hasConsumption == false)
        #expect(ResourceAmountPerTick.zero.hasProduction == false)
    }

    @Test("hasAny and hasConsumption")
    func hasAnyAndConsumption() {
        let prod = ResourceAmountPerTick(gold: 1)
        #expect(prod.hasAny == true)
        #expect(prod.hasConsumption == false)

        let cons = ResourceAmountPerTick(hop: 1)
        #expect(cons.hasAny == true)
        #expect(cons.hasConsumption == true)
    }

    @Test("equality")
    func equality() {
        let a = ResourceAmountPerTick(stone: 1, wood: 2, iron: 0, hop: 0, beer: 0, gold: 0)
        let b = ResourceAmountPerTick(stone: 1, wood: 2)
        #expect(a == b)
    }
}
