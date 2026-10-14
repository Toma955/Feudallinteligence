//
//  MapCreationRules.swift
//  Feudalism
//
//  Pravila kreacije mape. Preset side = metri po strani (200 → 200×200 m).
//  Svaka ćelija = 1×1 metar (MapScale.worldUnitsPerMapCell).
//

import Foundation

/// Pravila kreacije mape – jedan izvor istine. Side je u metrima.
enum MapCreationRules {
    // MARK: - Minimalna prostorna veličina
    /// Najmanja dozvoljena prostorna veličina za bilo koji element mape (npr. 1×2).
    static let minimumSpatialSize = SpatialSize(width: 1, height: 2)

    // MARK: - Glavna mapa (preseti) – side = broj ćelija za gradnju po strani (200 → 200×200)
    /// Dopuštene veličine glavne mape (kockasta: side×side ćelija).
    static var mainMapPresets: [(label: String, side: Int)] {
        MapDimension.allSides.map { ("\($0)×\($0)", $0) }
    }

    /// Broj redaka ćelija za gradnju za zadani preset. side 200 → 200.
    static func rows(forPresetSide side: Int) -> Int {
        side
    }

    /// Broj stupaca ćelija za gradnju za zadani preset. side 200 → 200.
    static func cols(forPresetSide side: Int) -> Int {
        side
    }

    /// Kreira GameMap prema preset stranici. 200 → 200×200 ćelija za gradnju.
    static func makeGameMap(presetSide side: Int) -> GameMap {
        GameMap(rows: rows(forPresetSide: side), cols: cols(forPresetSide: side))
    }

    // MARK: - Podzemna mapa
    /// Podzemlje je istih dimenzija kao nadzemlje; nova mapa je 100 % popunjena (`UndergroundTerrain.filledHeight`).
    static func makeUndergroundGameMap(matching surface: GameMap) -> GameMap {
        GameMap.makeFilledUnderground(rows: surface.rows, cols: surface.cols)
    }

    static func makeUndergroundGameMap(rows: Int, cols: Int) -> GameMap {
        GameMap.makeFilledUnderground(rows: rows, cols: cols)
    }
}
