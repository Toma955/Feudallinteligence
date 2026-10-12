//
//  Enclosure.swift
//  Feudalism
//
//  Je li dvorac opasan: od vatre ispred dvorca puni se područje u kojem su vrata zatvorena,
//  a zidovi, građevine, voda i more ionako. Ako to područje ne dođe do ruba mape i manje je od
//  pola kopna, dvorac je zatvoren – fizički nitko ne može ući ni izaći osim kroz vrata.
//  Vrata pri tome mogu biti otvorena i ljudi kroz njih prolaze.
//

import Foundation

final class EnclosureCache {
    private var logicId: ObjectIdentifier?
    private var byStart: [Int: Bool] = [:]

    func isEnclosed(in logic: MapLogic, row: Int, col: Int) -> Bool {
        let id = ObjectIdentifier(logic)
        if logicId != id {
            logicId = id
            byStart = [:]
        }
        let key = row * logic.surface.cols + col
        if let known = byStart[key] { return known }
        let result = Self.compute(logic, row: row, col: col)
        byStart[key] = result
        return result
    }

    func reset() {
        logicId = nil
        byStart = [:]
    }

    private static func open(_ layer: MapLogic.Layer, _ i: Int) -> Bool {
        guard layer.movement[i] > 0 else { return false }
        return layer.occupant[i] < 0
    }

    private static func compute(_ logic: MapLogic, row: Int, col: Int) -> Bool {
        let layer = logic.surface
        let rows = layer.rows, cols = layer.cols
        guard rows > 0, cols > 0 else { return false }
        var start: Int?
        search: for d in 0...6 {
            for dr in -d...d {
                for dc in -d...d where max(abs(dr), abs(dc)) == d {
                    guard let i = layer.index(row: row + dr, col: col + dc), open(layer, i) else { continue }
                    start = i
                    break search
                }
            }
        }
        guard let start else { return false }
        let land = layer.movement.indices.reduce(0) { $0 + (open(layer, $1) ? 1 : 0) }
        var seen = [Bool](repeating: false, count: rows * cols)
        var queue = [start]
        seen[start] = true
        var head = 0
        while head < queue.count {
            let i = queue[head]
            head += 1
            let r = i / cols, c = i % cols
            if r == 0 || c == 0 || r == rows - 1 || c == cols - 1 { return false }
            for n in [i - cols, i + cols, i - 1, i + 1] where n >= 0 && n < rows * cols && !seen[n] {
                if (n == i - 1 || n == i + 1), n / cols != r { continue }
                guard open(layer, n) else { continue }
                seen[n] = true
                queue.append(n)
            }
            if queue.count * 2 > land { return false }
        }
        return true
    }
}

extension GameState {
    func isCastleEnclosed(of faction: String) -> Bool {
        guard let seat = seat(of: faction) else { return false }
        let hearth = hearthCell(of: seat)
        return enclosure.isEnclosed(in: mapLogic, row: Int(hearth.row.rounded()), col: Int(hearth.col.rounded()))
    }

    var isPlayerCastleEnclosed: Bool {
        playerSeat.map { castleEnclosed[$0.id] ?? false } ?? false
    }

    /// Svaki potez: osvježi stanje svih dvoraca; igrač dobije poruku kad se njegov zatvori ili otvori.
    func refreshCastleEnclosure() {
        var next: [String: Bool] = [:]
        for seat in realmSeats.seats where seat.kingAlive {
            next[seat.id] = isCastleEnclosed(of: seat.id)
        }
        guard next != castleEnclosed else { return }
        if showsGraphics, let player = playerSeat?.id, (castleEnclosed[player] ?? false) != (next[player] ?? false) {
            placementError = next[player] == true
                ? "Dvorac je zatvoren – nitko ne može ući ni izaći osim kroz vrata."
                : "Dvorac više nije zatvoren – zid ili jarak ima prolaz."
        }
        castleEnclosed = next
    }
}
