//
//  FlammableCatalog.swift
//  Feudalism
//
//  Katalog: popis objekata koji se mogu zapaliti i koliko vatra oduzima HP (po ticku ili po sekundi).
//

import Foundation

/// Jedna stavka kataloga – objekt se može zapaliti, vatra oduzima N HP po jedinici vremena.
struct FlammableEntry: Equatable {
    /// objectId objekta koji gori (npr. zid, drvena kuća).
    let objectId: String
    /// Koliko HP vatra oduzima po ticku (npr. 1 = 1 HP/tick). Veća vrijednost = brže izgaranje.
    let fireDamagePerTick: Int
}

/// Katalog zapaljivih objekata i oštećenja od vatre.
final class FlammableCatalog {
    static let shared = FlammableCatalog()

    private var entries: [String: FlammableEntry] = [:]

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        for objectId in ObjectBehaviorRegistry.allObjectIds {
            let b = ObjectBehaviorRegistry.behavior(for: objectId)
            if b.isFlammable && b.fireDamagePerTick > 0 {
                set(FlammableEntry(objectId: objectId, fireDamagePerTick: b.fireDamagePerTick))
            }
        }
    }

    func set(_ entry: FlammableEntry) {
        entries[entry.objectId] = entry
    }

    /// Je li objekt zapaljiv?
    func isFlammable(objectId: String) -> Bool {
        entries[objectId] != nil
    }

    /// Koliko HP vatra oduzima po ticku; 0 ako objekt ne gori.
    func fireDamagePerTick(objectId: String) -> Int {
        entries[objectId]?.fireDamagePerTick ?? 0
    }

    /// Svi zapaljivi objectId-evi.
    var flammableObjectIds: [String] {
        Array(entries.keys).sorted()
    }
}
