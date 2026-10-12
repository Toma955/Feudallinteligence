//
//  ObjectHealthCatalog.swift
//  Feudalism
//
//  Katalog: opis koliko tko ima health (HP) – levels × hpPerLevel po objectId.
//  ObjectHealth.shared učitava podatke odavde. Izvor istine: ObjectBehaviorRegistry.
//

import Foundation

/// Katalog zdravlja (HP) po objectId. ObjectHealth.shared poziva register() pri inicijalizaciji.
enum ObjectHealthCatalog {
    static func register(into objectHealth: ObjectHealth) {
        for objectId in ObjectBehaviorRegistry.allObjectIds {
            let b = ObjectBehaviorRegistry.behavior(for: objectId)
            objectHealth.set(objectId, config: b.healthConfig)
        }
    }
}
