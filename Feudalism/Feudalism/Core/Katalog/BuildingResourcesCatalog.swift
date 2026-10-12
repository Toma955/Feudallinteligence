//
//  BuildingResourcesCatalog.swift
//  Feudalism
//
//  Katalog: popis resursa potrebnih za izgradnju svakog objekta (kamen, drvo, željezo).
//  Izvor istine je PriceList (cjenik); ovdje se zrcale samo kamen, drvo i željezo za stari BuildCost.
//

import Foundation

/// Trošak izgradnje (resursi) – zrcali BuildCost radi kataloga.
struct BuildingResourcesEntry: Equatable {
    var stone: Int
    var wood: Int
    var iron: Int

    static let zero = BuildingResourcesEntry(stone: 0, wood: 0, iron: 0)
}

/// Katalog resursa potrebnih za izgradnju (Building_resources).
enum BuildingResourcesCatalog {
    /// Svi troškovi po objectId. BuildCosts.shared poziva register() pri inicijalizaciji.
    static func register(into buildCosts: BuildCosts) {
        for objectId in ObjectBehaviorRegistry.allObjectIds {
            let items = PriceList.price(for: objectId).items
            buildCosts.set(objectId, cost: BuildCost(stone: items[.stone] ?? 0, wood: items[.wood] ?? 0, iron: items[.iron] ?? 0))
        }
    }
}
