//
//  PeopleRuntime.swift
//  Feudalism
//
//  Kretanje osoba u vremenu igre (1 s = 1 potez). Grafika ih pomiče glatko 20× u sekundi,
//  simulator jednom po potezu – logika je ista, scena samo čita snapshot.
//

import Foundation

final class PeopleRuntime {
    private(set) var people: [Person] = []
    private var snapshots: [PersonRenderSnapshot] = []
    private let lock = NSLock()
    private var timer: Timer?
    /// Ćelija po sekundi igre.
    static let speedCellsPerSecond = 1.2
    /// Javlja kad osoba stigne na cilj (npr. radnik uđe u građevinu).
    var onArrive: ((Person) -> Void)?
    /// Put od-do po mapi; nil = ravno (bez mape).
    var findPath: ((Person, PathPoint, PathPoint) -> [PathPoint]?)?
    /// Raste kad se mapa promijeni; tada se putevi ponovno slažu.
    var mapVersion = 0

    func copySnapshots() -> [PersonRenderSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }

    func reset() {
        stopTimer()
        people = []
        publish()
    }

    func restore(_ list: [Person]) {
        people = list
        publish()
    }

    func add(_ person: Person) {
        people.append(person)
        publish()
    }

    func update(id: String, _ change: (inout Person) -> Void) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        change(&people[i])
        publish()
    }

    func remove(id: String) {
        people.removeAll { $0.id == id }
        publish()
    }

    func person(id: String) -> Person? {
        people.first { $0.id == id }
    }

    // MARK: - Vrijeme

    func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.advance(dt: 0.05)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Pomakni sve osobe za `dt` sekundi igre.
    func advance(dt: Double) {
        var arrived: [Person] = []
        var changed = false
        for i in people.indices where people[i].activity.isMoving && people[i].healthPercent > 0 {
            let target = PathPoint(row: people[i].targetRow, col: people[i].targetCol, layer: people[i].targetLayer)
            if people[i].pathTarget != target || people[i].pathVersion != mapVersion {
                let start = PathPoint(row: people[i].row, col: people[i].col, layer: people[i].layer)
                let path = findPath.map { $0(people[i], start, target) } ?? [target]
                people[i].waypoints = path
                people[i].pathBlocked = path == nil
                people[i].pathTarget = target
                people[i].pathVersion = mapVersion
            }
            if people[i].pathBlocked == true { continue }
            let next = people[i].waypoints?.first ?? target
            let dRow = next.row - people[i].row
            let dCol = next.col - people[i].col
            let distance = hypot(dRow, dCol)
            let step = Self.speedCellsPerSecond * people[i].speedFactor * dt
            if people[i].layer != next.layer, distance <= 0.05 || distance <= step {
                people[i].layer = next.layer
                people[i].row = next.row
                people[i].col = next.col
                if (people[i].waypoints?.count ?? 0) > 1 {
                    people[i].waypoints?.removeFirst()
                    changed = true
                    continue
                }
            }
            if distance <= step, (people[i].waypoints?.count ?? 0) > 1 {
                people[i].row = next.row
                people[i].col = next.col
                people[i].layer = next.layer
                people[i].waypoints?.removeFirst()
                changed = true
                continue
            }
            if distance <= step {
                people[i].waypoints = nil
                people[i].row = people[i].targetRow
                people[i].col = people[i].targetCol
                people[i].layer = people[i].targetLayer
                switch people[i].activity {
                case .walkingToWork(let id): people[i].activity = .working(placementId: id)
                case .returningToFire: people[i].activity = .atFire
                case .returningToWork(let id): people[i].activity = .working(placementId: id)
                case .walkingToTree(let hut, let tree): people[i].activity = .chopping(hutId: hut, treeId: tree)
                case .haulingLog(let hut, _): people[i].activity = .working(placementId: hut)
                case .soldierMoving: people[i].activity = .soldierIdle
                default: break
                }
                arrived.append(people[i])
            } else {
                people[i].row += dRow / distance * step
                people[i].col += dCol / distance * step
                people[i].facing = atan2(dCol, dRow)
                people[i].walkPhase += dt * 7.5
            }
            changed = true
        }
        if changed { publish() }
        for person in arrived { onArrive?(person) }
    }

    private func publish() {
        let next = people.map { p in
            PersonRenderSnapshot(
                id: p.id,
                colorHex: p.colorHex,
                role: p.role,
                soldierType: p.resolvedSoldierType,
                row: p.row,
                col: p.col,
                facing: p.facing,
                moving: p.activity.isMoving,
                walkPhase: p.walkPhase,
                visible: p.isVisible,
                layer: p.layer
            )
        }
        lock.lock()
        snapshots = next
        lock.unlock()
    }
}
