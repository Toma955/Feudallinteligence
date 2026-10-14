//
//  MapLogic.swift
//  Feudalism
//
//  Svaka mapa ima tri mape:
//  1. nadzemnu (`GameState.gameMap`) – 3D prikaz kad se igra s grafikom,
//  2. podzemnu (`GameState.undergroundMap`) – istih dimenzija; visina 10 = 100 % popunjeno (simbioza s nadzemljem na 0),
//  3. logičku (`MapLogic`) – nadzemna i podzemna zajedno kao goli podaci, bez SceneKita i SwiftUI-ja.
//     AI lordovi i simulator rade samo nad njom; grafika je samo sloj iznad.
//

import Foundation

enum MapLayer: String, Codable, CaseIterable {
    case surface
    case underground
}

final class MapLogic {
    /// Jedan sloj u ravnim nizovima (indeks = row * cols + col) – brzo za AI i simulator.
    struct Layer {
        let rows: Int
        let cols: Int
        let placements: [Placement]
        /// -1 = slobodno, inače indeks u `placements`.
        let occupant: [Int32]
        /// Postavljeni objekt (osim vrata) zatvara ćeliju za hod.
        let blocks: [Bool]
        let buildable: [Bool]
        /// 0 = neprohodno, 1 = normalno, 1.5 = put.
        let movement: [Float]

        func index(row: Int, col: Int) -> Int? {
            guard row >= 0, col >= 0, row < rows, col < cols else { return nil }
            return row * cols + col
        }

        func placement(row: Int, col: Int) -> Placement? {
            guard let i = index(row: row, col: col), occupant[i] >= 0 else { return nil }
            return placements[Int(occupant[i])]
        }
    }

    let rows: Int
    let cols: Int
    let surface: Layer
    let underground: Layer
    /// Ključ terena (mapa + verzija uređivanja ćelija); kad je isti, teren se ne čita ponovno.
    let terrainKey: String

    /// `previous` s istim `terrainKey` daje gotov teren – pri promjeni građevina čitaju se samo one.
    init(surface surfaceMap: GameMap, underground undergroundMap: GameMap, terrainKey: String, previous: MapLogic? = nil) {
        let rows = surfaceMap.rows
        let cols = surfaceMap.cols
        self.rows = rows
        self.cols = cols
        self.terrainKey = terrainKey
        let reuse = previous.flatMap { $0.terrainKey == terrainKey && $0.rows == rows && $0.cols == cols ? $0 : nil }
        surface = Self.makeLayer(from: surfaceMap, rows: rows, cols: cols, terrainFromCells: true, terrain: reuse?.surface)
        let shafts = surfaceMap.placements.filter { Underground.entranceObjectIds.contains($0.objectId) && !$0.isDestroyed }
        underground = Self.makeLayer(from: undergroundMap, rows: rows, cols: cols, terrainFromCells: false, terrain: reuse?.underground, shafts: shafts)
    }

    func layer(_ layer: MapLayer) -> Layer {
        layer == .surface ? surface : underground
    }

    func blocksPassage(_ layer: MapLayer, row: Int, col: Int) -> Bool {
        let l = self.layer(layer)
        guard let i = l.index(row: row, col: col) else { return true }
        return l.blocks[i]
    }

    /// Cijena koraka kroz ćeliju; nil = ne može se proći (objekt ili teren).
    func movementCost(_ layer: MapLayer, row: Int, col: Int) -> Double? {
        let l = self.layer(layer)
        guard let i = l.index(row: row, col: col), !l.blocks[i], l.movement[i] > 0 else { return nil }
        return 1 / Double(l.movement[i])
    }

    /// Je li tlocrt slobodan i dozvoljen za gradnju (bez pravila pojedinih objekata).
    func isFree(_ layer: MapLayer, row: Int, col: Int, width: Int, height: Int) -> Bool {
        let l = self.layer(layer)
        for r in row..<(row + max(1, height)) {
            for c in col..<(col + max(1, width)) {
                guard let i = l.index(row: r, col: c), l.occupant[i] < 0, l.buildable[i] else { return false }
            }
        }
        return true
    }

    var allPlacements: [(layer: MapLayer, placement: Placement)] {
        surface.placements.map { (MapLayer.surface, $0) } + underground.placements.map { (MapLayer.underground, $0) }
    }

    private static let undergroundWalkIds: Set<String> = [
        UndergroundCorridor.objectId, UndergroundEntrance.objectId
    ]

    private static func makeLayer(from map: GameMap, rows: Int, cols: Int, terrainFromCells: Bool, terrain: Layer?, shafts: [Placement] = []) -> Layer {
        let count = max(0, rows * cols)
        var occupant = [Int32](repeating: -1, count: count)
        var blocks = [Bool](repeating: false, count: count)
        var buildable = terrain?.buildable ?? [Bool](repeating: true, count: count)
        var movement = terrain?.movement ?? [Float](repeating: 1, count: count)
        let placements = map.rows == rows && map.cols == cols ? map.placements.filter { !$0.isDestroyed } : []

        if terrainFromCells, terrain == nil {
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let cell = map.cell(row: r, col: c) else { continue }
                    let i = r * cols + c
                    buildable[i] = BuildRules.cellAllows(cell, objectId: "")
                    movement[i] = cell.walkable ? Float(cell.movementIndex) : 0
                }
            }
        }
        if !terrainFromCells {
            movement = [Float](repeating: 0, count: count)
            for p in shafts {
                openWalk(&movement, rows: rows, cols: cols, placement: p)
            }
        }
        for (index, p) in placements.enumerated() {
            for r in p.row..<(p.row + max(1, p.height)) where r >= 0 && r < rows {
                for c in p.col..<(p.col + max(1, p.width)) where c >= 0 && c < cols {
                    let i = r * cols + c
                    occupant[i] = Int32(index)
                    if Passage.blocks(objectId: p.objectId, row: r, col: c, originRow: p.row, originCol: p.col, width: p.width, height: p.height) {
                        blocks[i] = true
                    }
                }
            }
            if !terrainFromCells, undergroundWalkIds.contains(p.objectId) {
                openWalk(&movement, rows: rows, cols: cols, placement: p)
                openClear(&blocks, rows: rows, cols: cols, placement: p)
            }
        }
        return Layer(rows: rows, cols: cols, placements: placements, occupant: occupant, blocks: blocks, buildable: buildable, movement: movement)
    }

    private static func openWalk(_ movement: inout [Float], rows: Int, cols: Int, placement p: Placement) {
        for r in p.row..<(p.row + max(1, p.height)) where r >= 0 && r < rows {
            for c in p.col..<(p.col + max(1, p.width)) where c >= 0 && c < cols {
                movement[r * cols + c] = 1
            }
        }
    }

    private static func openClear(_ blocks: inout [Bool], rows: Int, cols: Int, placement p: Placement) {
        for r in p.row..<(p.row + max(1, p.height)) where r >= 0 && r < rows {
            for c in p.col..<(p.col + max(1, p.width)) where c >= 0 && c < cols {
                blocks[r * cols + c] = false
            }
        }
    }
}
