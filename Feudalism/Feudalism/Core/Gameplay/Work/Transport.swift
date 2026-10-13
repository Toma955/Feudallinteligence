//
//  Transport.swift
//  Feudalism
//
//  Prijevoz (kola): mini-skladište u koje određene građevine ostavljaju robu.
//  Kad se napuni, volovi voze po ruti (kutovi + polutočke koje se mogu povući u novi kut).
//

import Foundation

enum TransportRules {
    static let miniCapacity = 20
    static let haulSize = 10
    static let oxSpeedCellsPerSecond = 1.6
}

struct TransportPoint: Codable, Equatable {
    var row: Double
    var col: Double
}

struct TransportLine: Codable, Equatable {
    var depotId: String
    var corners: [TransportPoint]
    var allowedSourceIds: [String]
    var stock: [Good: Int]

    var stored: Int { stock.values.reduce(0, +) }
    var freeRoom: Int { max(0, TransportRules.miniCapacity - stored) }

    func midpoint(after index: Int) -> TransportPoint? {
        guard index >= 0, index + 1 < corners.count else { return nil }
        let a = corners[index], b = corners[index + 1]
        return TransportPoint(row: (a.row + b.row) / 2, col: (a.col + b.col) / 2)
    }

    mutating func pinStart(_ point: TransportPoint) {
        if corners.isEmpty {
            corners = [point, TransportPoint(row: point.row + 6, col: point.col)]
        } else {
            corners[0] = point
        }
    }

    mutating func add(_ goods: [Good: Int]) {
        for (good, amount) in goods where amount > 0 {
            stock[good, default: 0] += amount
        }
    }

    mutating func takeLoad(max amount: Int) -> [Good: Int] {
        var left = amount
        var load: [Good: Int] = [:]
        for good in stock.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard left > 0 else { break }
            let take = min(stock[good] ?? 0, left)
            guard take > 0 else { continue }
            load[good] = take
            stock[good] = (stock[good] ?? 0) - take
            if stock[good] == 0 { stock[good] = nil }
            left -= take
        }
        return load
    }
}

struct OxCart: Identifiable, Equatable, Codable {
    let id: String
    var depotId: String
    var cargo: [Good: Int]
    var row: Double
    var col: Double
    var facing: Double
    var walkPhase: Double
    var waypoint: Int
    var goingOut: Bool
    var waitingToUnload: Bool
    var colorHex: String
}

struct OxRenderSnapshot: Equatable {
    let id: String
    let row: Double
    let col: Double
    let facing: Double
    let walkPhase: Double
    let moving: Bool
    let colorHex: String
}

final class TransportRuntime {
    private(set) var oxen: [OxCart] = []
    private var snapshots: [OxRenderSnapshot] = []
    private let lock = NSLock()
    private var timer: Timer?

    var routeOf: ((String) -> [TransportPoint])?
    var onUnload: ((inout OxCart) -> Bool)?
    var onReturned: ((OxCart) -> Void)?

    func copySnapshots() -> [OxRenderSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }

    func reset() {
        stopTimer()
        oxen = []
        publish()
    }

    func restore(_ list: [OxCart]) {
        oxen = list
        publish()
    }

    func hasOx(for depotId: String) -> Bool {
        oxen.contains { $0.depotId == depotId }
    }

    func send(depotId: String, cargo: [Good: Int], from: TransportPoint, colorHex: String) {
        guard !hasOx(for: depotId), !cargo.isEmpty else { return }
        oxen.append(OxCart(
            id: UUID().uuidString,
            depotId: depotId,
            cargo: cargo,
            row: from.row,
            col: from.col,
            facing: 0,
            walkPhase: 0,
            waypoint: 0,
            goingOut: true,
            waitingToUnload: false,
            colorHex: colorHex
        ))
        publish()
    }

    func remove(depotId: String) {
        oxen.removeAll { $0.depotId == depotId }
        publish()
    }

    var timeScale: Double = 1

    func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.advance(dt: 0.05 * self.timeScale)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func advance(dt: Double) {
        var changed = false
        var returned: [OxCart] = []
        for i in oxen.indices {
            if oxen[i].waitingToUnload {
                if onUnload?(&oxen[i]) == true {
                    oxen[i].waitingToUnload = false
                    oxen[i].goingOut = false
                    changed = true
                }
                continue
            }
            let corners = routeOf?(oxen[i].depotId) ?? []
            guard corners.count >= 2 else { continue }
            let path = oxen[i].goingOut ? corners : corners.reversed()
            let targetIndex = min(oxen[i].waypoint, path.count - 1)
            let goal = path[targetIndex]
            let dRow = goal.row - oxen[i].row
            let dCol = goal.col - oxen[i].col
            let distance = hypot(dRow, dCol)
            let step = TransportRules.oxSpeedCellsPerSecond * dt
            if distance <= step {
                oxen[i].row = goal.row
                oxen[i].col = goal.col
                if targetIndex + 1 < path.count {
                    oxen[i].waypoint = targetIndex + 1
                } else if oxen[i].goingOut {
                    oxen[i].waitingToUnload = true
                    oxen[i].waypoint = 0
                } else {
                    returned.append(oxen[i])
                }
            } else {
                oxen[i].row += dRow / distance * step
                oxen[i].col += dCol / distance * step
                oxen[i].facing = atan2(dCol, dRow)
                oxen[i].walkPhase += dt * 6
            }
            changed = true
        }
        if !returned.isEmpty {
            let ids = Set(returned.map(\.id))
            oxen.removeAll { ids.contains($0.id) }
            returned.forEach { onReturned?($0) }
        }
        if changed || !returned.isEmpty { publish() }
    }

    private func publish() {
        let next = oxen.map {
            OxRenderSnapshot(id: $0.id, row: $0.row, col: $0.col, facing: $0.facing,
                             walkPhase: $0.walkPhase, moving: !$0.waitingToUnload, colorHex: $0.colorHex)
        }
        lock.lock()
        snapshots = next
        lock.unlock()
    }
}
