//
//  ProductionConsumptionCatalog.swift
//  Feudalism
//
//  Katalog proizvodnje i potrošnje: tko proizvodi što, tko šta primka, koji resurs pretvara i tko, tko šta konzumira.
//  Jedan izvor istine za sve što se tiče resursa (kamen, drvo, željezo; kasnije hrana). Čita iz ObjectBehaviorRegistry.
//

import Foundation

/// Jedna stavka kataloga: objekt s proizvodnjom i/ili potrošnjom resursa.
struct ProductionConsumptionEntry: Equatable {
    /// Id objekta (npr. object_iron, object_bakery).
    let objectId: String
    /// Ime objekta za prikaz (iz ObjectCatalog).
    let displayName: String
    /// Što proizvodi po ticku (output).
    let production: ResourceAmountPerTick
    /// Što primka/konzumira po ticku (input).
    let consumption: ResourceAmountPerTick
    /// Pretvara li resurse (nešto primka i nešto proizvodi)?
    let transformsResources: Bool

    var producesSomething: Bool { production.hasAny }
    var consumesSomething: Bool { consumption.hasConsumption }
}

/// Katalog proizvodnje i potrošnje – tko proizvodi što, tko šta primka, tko šta pretvara, tko šta konzumira.
enum ProductionConsumptionCatalog {
    /// Sve stavke: svaki objekt iz registra s njegovom proizvodnjom i potrošnjom.
    static var allEntries: [ProductionConsumptionEntry] {
        ObjectBehaviorRegistry.allObjectIds.map { objectId in
            let behavior = ObjectBehaviorRegistry.behavior(for: objectId)
            let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
            return ProductionConsumptionEntry(
                objectId: objectId,
                displayName: name,
                production: behavior.productionPerTick,
                consumption: behavior.consumptionPerTick,
                transformsResources: behavior.transformsResources
            )
        }
    }

    /// Samo objekti koji nešto proizvode (npr. rudnik, kamenolom, drvo).
    static var producers: [ProductionConsumptionEntry] {
        allEntries.filter { $0.producesSomething }
    }

    /// Samo objekti koji nešto konzumiraju/primaju (input po ticku).
    static var consumers: [ProductionConsumptionEntry] {
        allEntries.filter { $0.consumesSomething }
    }

    /// Objekti koji pretvaraju (primka X, proizvodi Y) – npr. pekara brašno → kruh.
    static var transformers: [ProductionConsumptionEntry] {
        allEntries.filter { $0.transformsResources }
    }

    /// Stavka za jedan objectId.
    static func entry(for objectId: String) -> ProductionConsumptionEntry? {
        guard ObjectBehaviorRegistry.allObjectIds.contains(objectId) else { return nil }
        let behavior = ObjectBehaviorRegistry.behavior(for: objectId)
        let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
        return ProductionConsumptionEntry(
            objectId: objectId,
            displayName: name,
            production: behavior.productionPerTick,
            consumption: behavior.consumptionPerTick,
            transformsResources: behavior.transformsResources
        )
    }
}
