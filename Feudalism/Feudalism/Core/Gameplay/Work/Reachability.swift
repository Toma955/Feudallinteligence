//
//  Reachability.swift
//  Feudalism
//
//  Put do građevine: pješice od vatre ispred dvorca po nadzemnoj logičkoj mapi (4 smjera).
//  Put je dvosmjeran – ako se do građevine može doći, može se i vratiti. Računa se jednom po
//  promjeni logičke mape i početne ćelije, pa vrijedi i u simulatoru bez prikaza.
//

import Foundation

final class ReachabilityCache {
    private var logicId: ObjectIdentifier?
    /// Po početnoj ćeliji (vatra svake frakcije).
    private var reachedByStart: [Int: [Bool]] = [:]

    /// Dostupne ćelije nadzemnog sloja od zadane ćelije.
    func reached(in logic: MapLogic, fromRow row: Int, col: Int) -> [Bool] {
        let id = ObjectIdentifier(logic)
        if logicId != id {
            logicId = id
            reachedByStart = [:]
        }
        let start = Self.nearestWalkable(in: logic, row: row, col: col)
        let key = start ?? -1
        if let known = reachedByStart[key] { return known }
        let fresh = Self.flood(logic, from: start)
        reachedByStart[key] = fresh
        return fresh
    }

    func reset() {
        logicId = nil
        reachedByStart = [:]
    }

    private static func walkable(_ logic: MapLogic, _ row: Int, _ col: Int) -> Bool {
        logic.movementCost(.surface, row: row, col: col) != nil
    }

    /// Vatra može stajati na zauzetoj ćeliji; tada kreće od najbliže prohodne.
    private static func nearestWalkable(in logic: MapLogic, row: Int, col: Int) -> Int? {
        let cols = logic.surface.cols
        for radius in 0...6 {
            for dr in -radius...radius {
                for dc in -radius...radius where max(abs(dr), abs(dc)) == radius {
                    let r = row + dr, c = col + dc
                    if walkable(logic, r, c) { return r * cols + c }
                }
            }
        }
        return nil
    }

    private static func flood(_ logic: MapLogic, from start: Int?) -> [Bool] {
        let rows = logic.surface.rows, cols = logic.surface.cols
        var seen = [Bool](repeating: false, count: max(0, rows * cols))
        guard let start else { return seen }
        var queue = [start]
        seen[start] = true
        var head = 0
        while head < queue.count {
            let i = queue[head]
            head += 1
            let r = i / cols, c = i % cols
            for (nr, nc) in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)] {
                guard nr >= 0, nc >= 0, nr < rows, nc < cols else { continue }
                let n = nr * cols + nc
                if !seen[n], walkable(logic, nr, nc) {
                    seen[n] = true
                    queue.append(n)
                }
            }
        }
        return seen
    }
}

extension GameState {
    /// Može li radnik vlasnika doći do građevine i vratiti se: neka ćelija uz rub tlocrta je dostupna od njegove vatre.
    /// Podzemlje treba svijeću i hodnik od ulaza.
    func hasPath(to placement: Placement, layer: MapLayer) -> Bool {
        guard let faction = owner(of: placement), let seat = seat(of: faction) else { return true }
        let hearth = hearthCell(of: seat)
        if layer == .surface {
            let logic = mapLogic
            let reached = reachability.reached(in: logic, fromRow: Int(hearth.row.rounded()), col: Int(hearth.col.rounded()))
            let rows = logic.surface.rows, cols = logic.surface.cols
            let top = placement.row - 1, bottom = placement.row + max(1, placement.height)
            let left = placement.col - 1, right = placement.col + max(1, placement.width)
            for r in top...bottom {
                for c in left...right where (r == top || r == bottom) != (c == left || c == right) {
                    guard r >= 0, c >= 0, r < rows, c < cols else { continue }
                    if reached[r * cols + c] { return true }
                }
            }
            return false
        }
        let useUnderground = CandleRules.hasCandles(self, faction)
        if !useUnderground { return false }
        let destRow = min(max(hearth.row, Double(placement.row) - 1), Double(placement.row + placement.height))
        let destCol = min(max(hearth.col, Double(placement.col) - 0.5), Double(placement.col + placement.width) - 0.5)
        return pathFinder.path(
            in: mapLogic,
            from: PathPoint(row: hearth.row, col: hearth.col, layer: .surface),
            to: PathPoint(row: destRow, col: destCol, layer: layer),
            useUnderground: useUnderground
        ) != nil
    }
}
