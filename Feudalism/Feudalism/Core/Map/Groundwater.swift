//
//  Groundwater.swift
//  Feudalism
//
//  Podzemne vode na površinskoj mapi. Bunar se može staviti svugdje, ali daje vodu
//  samo iznad podzemne vode. Izvor se može staviti samo na podzemnu vodu.
//

import Foundation
import CoreGraphics

final class GroundwaterMap {
    let rows: Int
    let cols: Int
    private let water: [Bool]

    /// Ista mapa (dimenzije i teren) uvijek daje iste podzemne vode.
    init(gameMap: GameMap) {
        rows = gameMap.rows
        cols = gameMap.cols
        var seed = UInt64(truncatingIfNeeded: rows &* 73_856_093) ^ UInt64(truncatingIfNeeded: cols &* 19_349_663)
        var heightSum: CGFloat = 0
        for (_, cell) in gameMap.cells { heightSum += cell.height }
        seed ^= UInt64(truncatingIfNeeded: Int((heightSum * 10).rounded())) &* 0x9E37_79B9_7F4A_7C15
        water = Self.generate(rows: rows, cols: cols, seed: seed)
    }

    func hasWater(row: Int, col: Int) -> Bool {
        guard row >= 0, col >= 0, row < rows, col < cols else { return false }
        return water[row * cols + col]
    }

    /// Ima li barem jedna ćelija tlocrta vodu (bunar daje vodu).
    func touchesWater(row: Int, col: Int, width: Int, height: Int) -> Bool {
        for r in row..<(row + max(1, height)) {
            for c in col..<(col + max(1, width)) where hasWater(row: r, col: c) {
                return true
            }
        }
        return false
    }

    /// Jesu li sve ćelije tlocrta na vodi (izvor se smije postaviti).
    func coversWater(row: Int, col: Int, width: Int, height: Int) -> Bool {
        for r in row..<(row + max(1, height)) {
            for c in col..<(col + max(1, width)) where !hasWater(row: r, col: c) {
                return false
            }
        }
        return true
    }

    /// Vodene žile: dvije oktave value noisea, prag daje oko trećine mape pod vodom.
    private static func generate(rows: Int, cols: Int, seed: UInt64) -> [Bool] {
        guard rows > 0, cols > 0 else { return [] }
        func lattice(_ x: Int, _ y: Int, _ salt: UInt64) -> CGFloat {
            var h = seed ^ salt
            h ^= UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15
            h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
            h ^= h >> 31
            h = h &* 0xBF58_476D_1CE4_E5B9
            h ^= h >> 29
            return CGFloat(h & 0xFFFF) / CGFloat(0xFFFF)
        }
        func noise(_ x: CGFloat, _ y: CGFloat, _ salt: UInt64) -> CGFloat {
            let x0 = Int(floor(x)), y0 = Int(floor(y))
            let fx = x - CGFloat(x0), fy = y - CGFloat(y0)
            let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
            let a = lattice(x0, y0, salt), b = lattice(x0 + 1, y0, salt)
            let c = lattice(x0, y0 + 1, salt), d = lattice(x0 + 1, y0 + 1, salt)
            let top = a + (b - a) * sx
            let bottom = c + (d - c) * sx
            return top + (bottom - top) * sy
        }
        let coarse: CGFloat = 28
        let fine: CGFloat = 9
        var result = [Bool](repeating: false, count: rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                let v = noise(CGFloat(c) / coarse, CGFloat(r) / coarse, 0xA1) * 0.75
                    + noise(CGFloat(c) / fine, CGFloat(r) / fine, 0xB2) * 0.25
                result[r * cols + c] = v > 0.58
            }
        }
        return result
    }
}
