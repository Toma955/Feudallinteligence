//
//  PathFinding.swift
//  Feudalism
//
//  Put osobe po logičkoj mapi (A*, 8 smjerova bez rezanja uglova). Zidovi, građevine,
//  voda i more se ne mogu prijeći; vrata i hodnici mogu. Ulaz spaja nadzemlje i podzemlje.
//  Hodnici se koriste samo ako frakcija ima svijeću (`useUnderground`).
//

import Foundation

struct PathPoint: Codable, Equatable {
    var row: Double
    var col: Double
    var layer: MapLayer

    init(row: Double, col: Double, layer: MapLayer = .surface) {
        self.row = row
        self.col = col
        self.layer = layer
    }

    enum CodingKeys: String, CodingKey { case row, col, layer }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        row = try c.decode(Double.self, forKey: .row)
        col = try c.decode(Double.self, forKey: .col)
        layer = try c.decodeIfPresent(MapLayer.self, forKey: .layer) ?? .surface
    }
}

final class PathFinder {
    private var logicId: ObjectIdentifier?
    private var minStepCost: Double = 1

    /// Točke od (iza) početka do cilja; zadnja je točno cilj. nil = cilj nije dostupan.
    func path(in logic: MapLogic, from start: PathPoint, to goal: PathPoint, useUnderground: Bool = true) -> [PathPoint]? {
        prepare(logic)
        if start.layer == goal.layer {
            return pathOnLayer(logic, from: start, to: goal, useUnderground: useUnderground)
        }
        guard useUnderground || goal.layer == .surface || isShaftLanding(logic, row: Int(goal.row.rounded()), col: Int(goal.col.rounded())) else {
            return nil
        }
        var best: [PathPoint]?
        for (r, c) in connectingCells(logic) {
            let gateFrom = PathPoint(row: Double(r), col: Double(c), layer: start.layer)
            let gateTo = PathPoint(row: Double(r), col: Double(c), layer: goal.layer)
            guard let first = pathOnLayer(logic, from: start, to: gateFrom, useUnderground: useUnderground),
                  let second = pathOnLayer(logic, from: gateTo, to: goal, useUnderground: useUnderground) else { continue }
            let merged = first + second
            if best == nil || merged.count < best!.count { best = merged }
        }
        return best
    }

    private func prepare(_ logic: MapLogic) {
        let id = ObjectIdentifier(logic)
        guard logicId != id else { return }
        logicId = id
        let fastest = max(logic.surface.movement.max() ?? 1, logic.underground.movement.max() ?? 1)
        minStepCost = fastest > 0 ? 1 / Double(fastest) : 1
    }

    private func pathOnLayer(_ logic: MapLogic, from start: PathPoint, to goal: PathPoint, useUnderground: Bool) -> [PathPoint]? {
        let layer = start.layer
        let rows = logic.layer(layer).rows, cols = logic.layer(layer).cols
        guard rows > 0, cols > 0,
              let s = nearestWalkable(logic, layer: layer, row: Int(start.row.rounded()), col: Int(start.col.rounded()), radius: 3, useUnderground: useUnderground),
              let g = nearestWalkable(logic, layer: layer, row: Int(goal.row.rounded()), col: Int(goal.col.rounded()), radius: 4, useUnderground: useUnderground) else { return nil }
        if s == g { return [PathPoint(row: goal.row, col: goal.col, layer: layer)] }
        guard let cells = aStar(logic, layer: layer, from: s, to: g, useUnderground: useUnderground) else { return nil }
        var points = smooth(logic, layer: layer, cells.map { PathPoint(row: Double($0 / cols), col: Double($0 % cols), layer: layer) }, from: start, useUnderground: useUnderground)
        if let last = points.last, last.row != goal.row || last.col != goal.col { points.append(PathPoint(row: goal.row, col: goal.col, layer: layer)) }
        return points
    }

    private func cost(_ logic: MapLogic, layer: MapLayer, row: Int, col: Int, useUnderground: Bool) -> Double? {
        if layer == .underground, !useUnderground {
            return isShaftLanding(logic, row: row, col: col) ? 1 : nil
        }
        return logic.movementCost(layer, row: row, col: col)
    }

    private func isShaftLanding(_ logic: MapLogic, row: Int, col: Int) -> Bool {
        guard let p = logic.surface.placement(row: row, col: col) else { return false }
        return Underground.entranceObjectIds.contains(p.objectId)
    }

    private func connectingCells(_ logic: MapLogic) -> [(Int, Int)] {
        var seen = Set<Int>()
        var cells: [(Int, Int)] = []
        func add(_ r: Int, _ c: Int) {
            guard let i = logic.surface.index(row: r, col: c), !seen.contains(i) else { return }
            seen.insert(i)
            cells.append((r, c))
        }
        for p in logic.surface.placements where Underground.entranceObjectIds.contains(p.objectId) {
            for r in p.row..<(p.row + max(1, p.height)) {
                for c in p.col..<(p.col + max(1, p.width)) { add(r, c) }
            }
        }
        for p in logic.underground.placements where p.objectId == UndergroundEntrance.objectId {
            for r in p.row..<(p.row + max(1, p.height)) {
                for c in p.col..<(p.col + max(1, p.width)) { add(r, c) }
            }
        }
        return cells
    }

    private func nearestWalkable(_ logic: MapLogic, layer: MapLayer, row: Int, col: Int, radius: Int, useUnderground: Bool) -> Int? {
        let cols = logic.layer(layer).cols
        for d in 0...radius {
            for dr in -d...d {
                for dc in -d...d where max(abs(dr), abs(dc)) == d {
                    if cost(logic, layer: layer, row: row + dr, col: col + dc, useUnderground: useUnderground) != nil {
                        return (row + dr) * cols + col + dc
                    }
                }
            }
        }
        return nil
    }

    private func aStar(_ logic: MapLogic, layer: MapLayer, from start: Int, to goal: Int, useUnderground: Bool) -> [Int]? {
        let rows = logic.layer(layer).rows, cols = logic.layer(layer).cols
        let count = rows * cols
        var g = [Double](repeating: .infinity, count: count)
        var came = [Int32](repeating: -1, count: count)
        var closed = [Bool](repeating: false, count: count)
        var heap = MinHeap()
        let gr = goal / cols, gc = goal % cols
        func h(_ i: Int) -> Double {
            let dr = Double(abs(i / cols - gr)), dc = Double(abs(i % cols - gc))
            return (max(dr, dc) + (2.0.squareRoot() - 1) * min(dr, dc)) * minStepCost
        }
        g[start] = 0
        heap.push(start, h(start))
        let steps: [(Int, Int, Double)] = [(-1, 0, 1), (1, 0, 1), (0, -1, 1), (0, 1, 1),
                                           (-1, -1, 2.0.squareRoot()), (-1, 1, 2.0.squareRoot()), (1, -1, 2.0.squareRoot()), (1, 1, 2.0.squareRoot())]
        while let current = heap.pop() {
            if current == goal { break }
            if closed[current] { continue }
            closed[current] = true
            let r = current / cols, c = current % cols
            for (dr, dc, length) in steps {
                let nr = r + dr, nc = c + dc
                guard let stepCost = cost(logic, layer: layer, row: nr, col: nc, useUnderground: useUnderground) else { continue }
                if dr != 0, dc != 0,
                   cost(logic, layer: layer, row: r + dr, col: c, useUnderground: useUnderground) == nil
                    || cost(logic, layer: layer, row: r, col: c + dc, useUnderground: useUnderground) == nil { continue }
                let n = nr * cols + nc
                let tentative = g[current] + length * stepCost
                if tentative < g[n] {
                    g[n] = tentative
                    came[n] = Int32(current)
                    heap.push(n, tentative + h(n))
                }
            }
        }
        guard g[goal].isFinite else { return nil }
        var cells = [goal]
        var at = goal
        while at != start, came[at] >= 0 {
            at = Int(came[at])
            cells.append(at)
        }
        return cells.reversed()
    }

    private func smooth(_ logic: MapLogic, layer: MapLayer, _ points: [PathPoint], from start: PathPoint, useUnderground: Bool) -> [PathPoint] {
        guard points.count > 1 else { return points }
        var result: [PathPoint] = []
        var anchor = start
        var i = 0
        while i < points.count {
            var j = i
            while j + 1 < points.count, clearLine(logic, layer: layer, anchor, points[j + 1], useUnderground: useUnderground) { j += 1 }
            result.append(points[j])
            anchor = points[j]
            i = j + 1
        }
        return result
    }

    private func clearLine(_ logic: MapLogic, layer: MapLayer, _ a: PathPoint, _ b: PathPoint, useUnderground: Bool) -> Bool {
        let length = hypot(b.row - a.row, b.col - a.col)
        let samples = max(1, Int(length / 0.2))
        for k in 0...samples {
            let t = Double(k) / Double(samples)
            let r = a.row + (b.row - a.row) * t, c = a.col + (b.col - a.col) * t
            for (orow, ocol) in [(-0.3, -0.3), (-0.3, 0.3), (0.3, -0.3), (0.3, 0.3)] {
                if cost(logic, layer: layer, row: Int((r + orow).rounded()), col: Int((c + ocol).rounded()), useUnderground: useUnderground) == nil { return false }
            }
        }
        return true
    }
}

private struct MinHeap {
    private var items: [(index: Int, priority: Double)] = []

    mutating func push(_ index: Int, _ priority: Double) {
        items.append((index, priority))
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard items[child].priority < items[parent].priority else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Int? {
        guard !items.isEmpty else { return nil }
        let top = items[0].index
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var parent = 0
            while true {
                let left = parent * 2 + 1, right = left + 1
                var smallest = parent
                if left < items.count, items[left].priority < items[smallest].priority { smallest = left }
                if right < items.count, items[right].priority < items[smallest].priority { smallest = right }
                if smallest == parent { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
        }
        return top
    }
}
