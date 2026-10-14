import Foundation

struct HUDResourceEntry: Identifiable {
    let id: String
    let iconName: String
    let systemFallback: String
    let helpKey: String?

    init(id: String, iconName: String, systemFallback: String, helpKey: String? = nil) {
        self.id = id
        self.iconName = iconName
        self.systemFallback = systemFallback
        self.helpKey = helpKey
    }
}

enum HUDResourceCatalog {
    static let solo: [HUDResourceEntry] = [
        HUDResourceEntry(id: "gold", iconName: "gold", systemFallback: "dollarsign.circle.fill"),
        HUDResourceEntry(id: "wood", iconName: "wood_resource", systemFallback: "leaf.fill"),
        HUDResourceEntry(id: "stone", iconName: "stone_resource", systemFallback: "mountain.2.fill"),
        HUDResourceEntry(id: "iron", iconName: "iron_resource", systemFallback: "cylinder.fill"),
        HUDResourceEntry(id: "hop", iconName: "hop_resource", systemFallback: "leaf.circle.fill", helpKey: "resource_hop"),
        HUDResourceEntry(id: "beer", iconName: "beer_resource", systemFallback: "mug.fill", helpKey: "resource_beer"),
        HUDResourceEntry(id: "bread", iconName: "bread_resource", systemFallback: "birthday.cake.fill", helpKey: "resource_bread"),
        HUDResourceEntry(id: "food", iconName: "food", systemFallback: "fork.knife", helpKey: "resource_food"),
        HUDResourceEntry(id: "hay", iconName: "hay_resource", systemFallback: "circle.hexagongrid.fill"),
        HUDResourceEntry(id: "honey", iconName: "honey_resource", systemFallback: "drop.fill", helpKey: "resource_honey"),
        HUDResourceEntry(id: "wax", iconName: "wax_resource", systemFallback: "circle.fill", helpKey: "resource_wax"),
        HUDResourceEntry(id: "candle", iconName: "candle_resource", systemFallback: "flame.fill", helpKey: "resource_candle"),
    ]

    static let resourcesStrip: [HUDResourceEntry] = [
        HUDResourceEntry(id: "wood", iconName: "wood_resource", systemFallback: "leaf.fill"),
        HUDResourceEntry(id: "stone", iconName: "stone_resource", systemFallback: "mountain.2.fill"),
        HUDResourceEntry(id: "iron", iconName: "iron_resource", systemFallback: "cylinder.fill"),
    ]

    static let weaponsStrip: [HUDResourceEntry] = [
        HUDResourceEntry(id: "shield", iconName: "shield_resource", systemFallback: "shield.fill"),
        HUDResourceEntry(id: "spear", iconName: "spear_resource", systemFallback: "line.diagonal"),
        HUDResourceEntry(id: "sword", iconName: "sword_resource", systemFallback: "line.diagonal"),
        HUDResourceEntry(id: "leather", iconName: "leather_resources", systemFallback: "square.fill"),
        HUDResourceEntry(id: "crossbow", iconName: "crosbow_resource", systemFallback: "scope"),
        HUDResourceEntry(id: "bow", iconName: "bow_and_sparrow_resouce", systemFallback: "arrow.up"),
    ]

    static let foodStrip: [HUDResourceEntry] = [
        HUDResourceEntry(id: "bread", iconName: "bread_resource", systemFallback: "birthday.cake.fill", helpKey: "resource_bread"),
        HUDResourceEntry(id: "food", iconName: "food", systemFallback: "fork.knife", helpKey: "resource_food"),
        HUDResourceEntry(id: "apple", iconName: "apple_resource", systemFallback: "apple.logo"),
        HUDResourceEntry(id: "banana", iconName: "banana_resource", systemFallback: "leaf.fill"),
        HUDResourceEntry(id: "grapes", iconName: "grapes_resource", systemFallback: "leaf.circle.fill"),
        HUDResourceEntry(id: "vegetables", iconName: "vegetables_resource", systemFallback: "carrot.fill"),
        HUDResourceEntry(id: "corn", iconName: "corn_resource", systemFallback: "leaf.fill"),
        HUDResourceEntry(id: "eggs", iconName: "eggs_resouce", systemFallback: "circle.fill"),
        HUDResourceEntry(id: "chicken", iconName: "chicken_resource", systemFallback: "bird.fill"),
        HUDResourceEntry(id: "meat", iconName: "meat_resouce", systemFallback: "fork.knife"),
        HUDResourceEntry(id: "sausages", iconName: "sosages_resouce", systemFallback: "fork.knife"),
        HUDResourceEntry(id: "cheese", iconName: "cheese_resource", systemFallback: "square.fill"),
        HUDResourceEntry(id: "milk", iconName: "milk_resource", systemFallback: "drop.fill"),
        HUDResourceEntry(id: "honey", iconName: "honey_resource", systemFallback: "seal.fill", helpKey: "resource_honey"),
        HUDResourceEntry(id: "beer", iconName: "beer_resource", systemFallback: "mug.fill", helpKey: "resource_beer"),
        HUDResourceEntry(id: "wine", iconName: "vine_resources", systemFallback: "wineglass.fill"),
        HUDResourceEntry(id: "hop", iconName: "hop_resource", systemFallback: "leaf.circle.fill", helpKey: "resource_hop"),
        HUDResourceEntry(id: "hay", iconName: "hay_resource", systemFallback: "circle.hexagongrid.fill"),
        HUDResourceEntry(id: "wax", iconName: "wax_resource", systemFallback: "circle.fill", helpKey: "resource_wax"),
        HUDResourceEntry(id: "candle", iconName: "candle_resource", systemFallback: "flame.fill", helpKey: "resource_candle"),
    ]
}
