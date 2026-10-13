//
//  CandleRules.swift
//  Feudalism
//
//  Košnica → med i vosak → svijeća. Samo podzemlje treba svijeću da bi radilo.
//  Na površini svijeća nije uvjet. Količina je za sada 1 i ne troši se.
//

import Foundation

enum CandleRules {
    /// Koliko svijeća treba na zalihi da podzemlje radi.
    static let stockNeeded = 1

    static func hasCandles(_ state: GameState, _ faction: String) -> Bool {
        state.goodAmount(.candle, of: faction) >= stockNeeded
    }

    /// Svijeća je uvjet samo pod zemljom, za radna mjesta.
    static func needsCandle(objectId: String, layer: MapLayer) -> Bool {
        layer == .underground && WorkCycleCatalog.isWorkplace(objectId)
    }
}
