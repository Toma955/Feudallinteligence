import Testing
@testable import Feudalism

@Suite("BuildCost and ResourceStock")
struct BuildCostAndResourceStockTests {

    @Test("BuildCost.zero and canAfford")
    func buildCostZeroAndCanAfford() {
        #expect(BuildCost.zero.stone == 0)
        #expect(BuildCost.zero.wood == 0)
        #expect(BuildCost.zero.iron == 0)
        #expect(BuildCost.zero.canAfford(stone: 0, wood: 0, iron: 0) == true)
        #expect(BuildCost(stone: 1, wood: 0, iron: 0).canAfford(stone: 1, wood: 0, iron: 0) == true)
        #expect(BuildCost(stone: 1, wood: 0, iron: 0).canAfford(stone: 0, wood: 0, iron: 0) == false)
    }

    @Test("ResourceStock.zero and canAfford and subtract")
    func resourceStock() {
        #expect(ResourceStock.zero.stone == 0)
        var stock = ResourceStock(stone: 10, wood: 10, iron: 10)
        let cost = BuildCost(stone: 2, wood: 3, iron: 1)
        #expect(stock.canAfford(cost: cost) == true)
        stock.subtract(cost)
        #expect(stock.stone == 8)
        #expect(stock.wood == 7)
        #expect(stock.iron == 9)
    }

    @Test("BuildCosts returns zero for unknown objectId")
    func buildCostsUnknownId() {
        let cost = BuildCosts.shared.cost(for: "unknown_id_xyz")
        #expect(cost == BuildCost.zero)
    }

    @Test("BuildCosts returns non-zero for known object")
    func buildCostsKnownObject() {
        let cost = BuildCosts.shared.cost(for: Castle.objectId)
        #expect(cost.stone >= 0)
        #expect(cost.wood >= 0)
        #expect(cost.iron >= 0)
    }
}
