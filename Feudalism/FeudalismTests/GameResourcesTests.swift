import Testing
@testable import Feudalism

@Suite("GameResources")
struct GameResourcesTests {

    @Test("add increases values, subtract does not go below zero")
    func addAndSubtract() {
        let res = GameResources()
        res.add(stone: 10, wood: 5, iron: 1)
        #expect(res.stone == 10)
        #expect(res.wood == 5)
        #expect(res.iron == 1)

        res.subtract(stone: 3, wood: 2)
        #expect(res.stone == 7)
        #expect(res.wood == 3)
        #expect(res.iron == 1)

        res.subtract(stone: 100)
        #expect(res.stone == 0)
    }

    @Test("canAfford BuildCost")
    func canAffordBuildCost() {
        let res = GameResources()
        res.setStock(stone: 5, wood: 5, iron: 5)
        let cost = BuildCost(stone: 2, wood: 2, iron: 2)
        #expect(res.canAfford(cost) == true)
        res.subtract(cost)
        #expect(res.canAfford(cost) == true)
        res.subtract(cost)
        #expect(res.canAfford(cost) == false)
    }

    @Test("canAfford ResourceAmountPerTick")
    func canAffordConsumption() {
        let res = GameResources()
        res.setStock(stone: 0, wood: 0, iron: 0, hop: 2, beer: 1)
        let need = ResourceAmountPerTick(hop: 1, beer: 0)
        #expect(res.canAfford(consumption: need) == true)
        let need2 = ResourceAmountPerTick(hop: 3, beer: 0)
        #expect(res.canAfford(consumption: need2) == false)
    }

    @Test("reset zeros all")
    func reset() {
        let res = GameResources()
        res.add(stone: 1, wood: 1, iron: 1, hop: 1, beer: 1, gold: 1)
        res.reset()
        #expect(res.stone == 0)
        #expect(res.wood == 0)
        #expect(res.iron == 0)
        #expect(res.hop == 0)
        #expect(res.beer == 0)
        #expect(res.gold == 0)
    }

    @Test("subtractForBuilding with zero cost does not change resources")
    func subtractForBuildingWithZeroCost() {
        let res = GameResources()
        res.setStock(stone: 0, wood: 0, iron: 0)
        let cost = BuildCosts.shared.cost(for: Castle.objectId)
        #expect(cost == BuildCost.zero)
        let ok = res.subtractForBuilding(objectId: Castle.objectId)
        #expect(ok == true)
        #expect(res.stone == 0)
        #expect(res.wood == 0)
        #expect(res.iron == 0)
    }

}
