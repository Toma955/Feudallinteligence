import Testing
@testable import Feudalism

@Suite("HUDResourceCatalog")
struct HUDResourceCatalogTests {

    @Test("solo strip has expected resource ids")
    func soloStripIds() {
        let ids = HUDResourceCatalog.solo.map(\.id)
        #expect(ids.contains("gold"))
        #expect(ids.contains("wood"))
        #expect(ids.contains("stone"))
        #expect(ids.contains("iron"))
        #expect(ids.count >= 4)
    }

    @Test("resourcesStrip is stone, wood, iron, gold")
    func resourcesStripOrder() {
        let strip = HUDResourceCatalog.resourcesStrip
        #expect(strip.count == 4)
        #expect(strip[0].id == "stone")
        #expect(strip[1].id == "wood")
        #expect(strip[2].id == "iron")
        #expect(strip[3].id == "gold")
    }

    @Test("weaponsStrip has shield spear sword leather crossbow bow")
    func weaponsStripIds() {
        let ids = HUDResourceCatalog.weaponsStrip.map(\.id)
        #expect(ids.contains("shield"))
        #expect(ids.contains("spear"))
        #expect(ids.contains("sword"))
        #expect(ids.contains("leather"))
        #expect(ids.contains("crossbow"))
        #expect(ids.contains("bow"))
        #expect(ids.count == 6)
    }

    @Test("foodStrip has apple cheese meat sausages vegetables")
    func foodStripIds() {
        let ids = HUDResourceCatalog.foodStrip.map(\.id)
        #expect(ids.contains("apple"))
        #expect(ids.contains("cheese"))
        #expect(ids.contains("meat"))
        #expect(ids.contains("sausages"))
        #expect(ids.contains("vegetables"))
        #expect(ids.count == 5)
    }
}
