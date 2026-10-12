//
//  Passage.swift
//  Feudalism
//
//  Postavljeni objekt zatvara svoje ćelije. Kroz vrata se prolazi.
//

import Foundation

enum Passage {
    /// Vrata su prolaz. Ostali postavljeni objekti se ne mogu prijeći.
    static let doorObjectIds: Set<String> = [
        Gates.objectId,
        UndergroundEntrance.objectId,
        UndergroundCorridor.objectId
    ]

    /// Cesta, ploča, most i sitni ukras ne zatvaraju hod.
    static let passableObjectIds: Set<String> = doorObjectIds.union([
        Road.objectId, StoneSlab.objectId, Bridge.objectId, Tunnel.objectId,
        Flag.objectId, Torch.objectId, Candle.objectId, OrnamentalTree.objectId, Roof.objectId
    ])

    static func blocks(objectId: String) -> Bool {
        !passableObjectIds.contains(objectId)
    }

    /// Farma i skladište zatvaraju polja 2×2, a križ širine 1 ostaje prolaz sa svake strane.
    static func blocks(objectId: String, row: Int, col: Int, originRow: Int, originCol: Int, width: Int, height: Int) -> Bool {
        if passableObjectIds.contains(objectId) { return false }
        if BuildRules.isFarm(objectId), width == FarmYard.side, height == FarmYard.side {
            return !FarmYard.isPassage(localRow: row - originRow, localCol: col - originCol)
        }
        if objectId == Lager.objectId, width == LagerPlan.side, height == LagerPlan.side {
            return !LagerPlan.isPassage(localRow: row - originRow, localCol: col - originCol)
        }
        return true
    }
}
