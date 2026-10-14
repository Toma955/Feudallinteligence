//
//  AILordStateEncoder.swift
//  Feudalism
//
//  Stanje partije → 64 float značajke za state_in (iz tekstualnih mapa ili uživo).
//

import Foundation

enum AILordStateEncoder {
    static let size = AILordWeights.stateFeatures

    /// Uživo: zasebni pozivi mapa (routine).
    static func encode(from state: GameState) -> [Float] {
        encode(
            surface: TextMapCapture.captureSurface(from: state),
            buildings: TextMapCapture.captureBuildings(from: state),
            army: TextMapCapture.captureArmy(from: state),
            turn: state.currentTurn,
            rows: state.gameMap.rows,
            cols: state.gameMap.cols
        )
    }

    /// Iz okvira snimke.
    static func encode(frame: MatchHistoryFrame, rows: Int, cols: Int) -> [Float] {
        encode(
            surface: frame.main,
            buildings: frame.buildings,
            army: frame.army,
            turn: frame.turn,
            rows: rows,
            cols: cols
        )
    }

    static func encode(
        surface: String,
        buildings: String,
        army: String,
        turn: Int,
        rows: Int,
        cols: Int
    ) -> [Float] {
        var f = [Float](repeating: 0, count: size)
        f[0] = Float(min(turn, 10_000)) / 10_000
        f[1] = Float(min(rows, 400)) / 400
        f[2] = Float(min(cols, 400)) / 400

        // Građevine (glifovi u buildings mapi).
        let marks: [(Character, Int)] = [
            ("H", 3), ("A", 4), ("K", 5), ("L", 6), ("W", 7), ("Z", 8),
            ("C", 9), ("T", 10), ("M", 11), ("B", 12), ("S", 13), ("F", 14)
        ]
        let buildingCount = max(1, buildings.count)
        for (ch, idx) in marks {
            f[idx] = Float(buildings.filter { $0 == ch }.count) / Float(buildingCount) * 40
        }

        // Vojska: numerička matrica "tip,broj,..."
        var typeHist = [Float](repeating: 0, count: 12)
        var soldierCells = 0
        for token in army.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            let parts = token.split(separator: ",")
            guard parts.count >= 2, let type = Int(parts[0]), let n = Int(parts[1]), type > 0, n > 0 else { continue }
            soldierCells += 1
            let bucket = min(11, max(0, type - 1))
            typeHist[bucket] += Float(n)
        }
        let soldierNorm = max(1, soldierCells)
        for i in 0..<12 {
            f[15 + i] = typeHist[i] / Float(soldierNorm)
        }
        f[27] = Float(soldierCells) / 200

        // Teren: broj ćelija koje počinju određenom šifrom.
        var terrain = [Float](repeating: 0, count: 16)
        for token in surface.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            let code = token.split(separator: ",").first.flatMap { Int($0) } ?? 0
            terrain[min(15, max(0, code))] += 1
        }
        let cellNorm = max(1, surface.split(whereSeparator: { $0 == " " || $0 == "\n" }).count)
        for i in 0..<16 {
            f[28 + i] = terrain[i] / Float(cellNorm)
        }

        // Hash ostatak teksta u preostale značajke (stabilno).
        let blob = buildings + "\n" + army.prefix(2000)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in blob.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
            let slot = 44 + Int(hash % 20)
            if slot < size {
                f[slot] = Float(hash % 1000) / 1000
            }
        }
        return f
    }
}
