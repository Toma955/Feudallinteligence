//
//  CandleRules.swift
//  Feudalism
//
//  Košnica → med i vosak → svijeća. Hodnici i neke radionice rade samo dok frakcija
//  ima svijeću. Količina po građevini dogovara se kasnije; za sada je dovoljna 1, ne troši se.
//

import Foundation

enum CandleRules {
    /// Koliko svijeća treba na zalihi da hodnici i radionice rade. Kasnije po građevini.
    static let stockNeeded = 1

    static func hasCandles(_ state: GameState, _ faction: String) -> Bool {
        state.goodAmount(.candle, of: faction) >= stockNeeded
    }

    /// Oružje i podzemna radna mjesta trebaju svijeću da ciklus krene.
    static func needsCandle(objectId: String, layer: MapLayer) -> Bool {
        if layer == .underground, WorkCycleCatalog.isWorkplace(objectId) { return true }
        return WorkCycleCatalog.cycle(for: objectId)?.kind == .weapon
    }
}
