//
//  RealmSeat.swift
//  Feudalism
//
//  Jedna frakcija (grupa, ili sam realm) ima dvorac-kocku i kralja koji hoda.
//  Kad kralj umre, ta grupa je gotova.
//

import Foundation

/// Stanje jedne frakcije na karti: kocka dvorca i kralj.
struct RealmSeat: Equatable, Codable {
    let id: String
    let realmIds: [String]
    let displayName: String
    let colorHex: String
    /// Sredina mape u koordinatama ćelija. Može biti .5 da kocka sjedne točno u centar.
    let castleRow: Double
    let castleCol: Double
    var kingRow: Double
    var kingCol: Double
    var destinationRow: Int
    var destinationCol: Int
    var patrolIndex: Int
    /// Sekunde stajanja prije sljedećeg nasumičnog cilja.
    var pauseRemaining: Double
    /// Faza hoda u radijanima. Scena iz nje njiše ruke i noge.
    var walkPhase: Double
    var facing: Double
    /// 100 = puno zdravlje.
    var kingHealthPercent: Double
    var kingAlive: Bool
    /// Igrač može poslati ovog kralja klikom na kartu.
    var isPlayerFaction: Bool
}

/// Što scena crta, bez SwiftUI osvježavanja svaki kadar.
struct KingRenderSnapshot: Equatable {
    let factionId: String
    let colorHex: String
    let castleRow: Double
    let castleCol: Double
    let kingRow: Double
    let kingCol: Double
    let facing: Double
    let alive: Bool
    let healthPercent: Double
    let moving: Bool
    let walkPhase: Double
}

/// Hod kraljeva. Scena čita snapshot; mutacije idu s glavne niti.
final class RealmSeatRuntime {
    private(set) var seats: [RealmSeat] = []
    private var snapshots: [KingRenderSnapshot] = []
    private let lock = NSLock()
    private var timer: Timer?
    private var advancing = false
    private let speedCellsPerSecond = 1.35
    /// Ćelija je zatvorena postavljenim objektom. Vrata vraćaju false.
    var blocksCell: ((Int, Int) -> Bool)?

    func copySnapshots() -> [KingRenderSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        advancing = false
        seats = []
        publish()
    }

    /// Solo: jedna kocka u geometrijskoj sredini, kralj hoda oko nje, zdravlje 100%.
    func spawnSolo(realm: Realm, rows: Int, cols: Int, animate: Bool) {
        stop()
        guard rows >= 1, cols >= 1 else { return }
        let centerRow = (Double(rows) - 1) / 2
        let centerCol = (Double(cols) - 1) / 2
        var seat = RealmSeat(
            id: realm.groupId ?? realm.id,
            realmIds: [realm.id],
            displayName: realm.name,
            colorHex: realm.colorHex,
            castleRow: centerRow,
            castleCol: centerCol,
            kingRow: centerRow,
            kingCol: centerCol,
            destinationRow: 0,
            destinationCol: 0,
            patrolIndex: 0,
            pauseRemaining: 0,
            walkPhase: 0,
            facing: 0,
            kingHealthPercent: 100,
            kingAlive: true,
            isPlayerFaction: true
        )
        let beside = min(cols - 2, Int(centerCol.rounded()) + 6)
        seat.kingRow = centerRow
        seat.kingCol = Double(beside)
        let next = randomWanderTarget(for: seat, rows: rows, cols: cols)
        seat.destinationRow = next.row
        seat.destinationCol = next.col
        seats = [seat]
        publish()
        startWalk(rows: rows, cols: cols, animate: animate)
    }

    /// `startPositions` = početna mjesta iz map editora; frakcije ih zauzimaju redom, ostale idu u krug.
    func spawn(from realms: [Realm], groups: [RealmGroup], rows: Int, cols: Int, playerRealmId: String?, startPositions: [MapCoordinate] = [], animate: Bool) {
        stop()
        let active = realms.filter { !$0.isDefeated }
        guard rows > 4, cols > 4, !active.isEmpty else { return }
        let grouped = Dictionary(grouping: active) { $0.groupId ?? $0.id }
        let keys = grouped.keys.sorted()
        let centerRow = rows / 2
        let centerCol = cols / 2
        let radius = max(6, min(rows, cols) / 5)
        seats = keys.enumerated().map { index, key in
            let members = grouped[key] ?? []
            let point: (row: Int, col: Int) = index < startPositions.count
                ? (min(max(2, startPositions[index].row), rows - 3), min(max(2, startPositions[index].col), cols - 3))
                : spawnPoint(index: index, count: keys.count, centerRow: centerRow, centerCol: centerCol, radius: radius, rows: rows, cols: cols)
            let name = factionName(id: key, members: members, groups: groups)
            let color = members.first?.colorHex ?? "8B4513"
            let player = members.contains { $0.id == playerRealmId }
            let startCol = min(cols - 2, point.col + 2)
            return RealmSeat(
                id: key,
                realmIds: members.map(\.id),
                displayName: name,
                colorHex: color,
                castleRow: Double(point.row),
                castleCol: Double(point.col),
                kingRow: Double(point.row),
                kingCol: Double(startCol),
                destinationRow: point.row,
                destinationCol: startCol,
                patrolIndex: 0,
                pauseRemaining: 0,
                walkPhase: Double(index),
                facing: 0,
                kingHealthPercent: 100,
                kingAlive: true,
                isPlayerFaction: player
            )
        }
        for i in seats.indices {
            let next = randomWanderTarget(for: seats[i], rows: rows, cols: cols)
            seats[i].destinationRow = next.row
            seats[i].destinationCol = next.col
        }
        publish()
        startWalk(rows: rows, cols: cols, animate: animate)
    }

    func pauseWalking() {
        timer?.invalidate()
        timer = nil
    }

    func resumeWalking(rows: Int, cols: Int) {
        guard timer == nil, !seats.isEmpty else { return }
        startWalk(rows: rows, cols: cols, animate: true)
    }

    func restorePlayerKing(row: Double, col: Double, health: Double, alive: Bool) {
        guard let i = seats.firstIndex(where: { $0.isPlayerFaction }) else { return }
        seats[i].kingRow = row
        seats[i].kingCol = col
        seats[i].kingHealthPercent = health
        seats[i].kingAlive = alive
        seats[i].destinationRow = min(max(0, Int(row.rounded())), Int(row.rounded()))
        seats[i].destinationCol = min(max(0, Int(col.rounded())), Int(col.rounded()))
        seats[i].pauseRemaining = 0
        publish()
    }

    func restoreSeats(_ list: [RealmSeat]) {
        seats = list
        publish()
    }

    var timeScale: Double = 1

    private func startWalk(rows: Int, cols: Int, animate: Bool) {
        timer?.invalidate()
        timer = nil
        guard animate else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.advance(dt: 0.05 * (self?.timeScale ?? 1), rows: rows, cols: cols)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Klik na praznu kartu šalje kralja igrača na tu ćeliju.
    func movePlayerKing(toRow row: Int, col: Int, rows: Int, cols: Int) {
        guard let seat = seats.first(where: { $0.isPlayerFaction && $0.kingAlive }) else { return }
        moveKing(factionId: seat.id, toRow: row, col: col, rows: rows, cols: cols)
    }

    /// Pošalji kralja bilo koje frakcije na ćeliju (AI ili igrač).
    func moveKing(factionId: String, toRow row: Int, col: Int, rows: Int, cols: Int) {
        guard let i = seats.firstIndex(where: { $0.id == factionId && $0.kingAlive }) else { return }
        let targetRow = min(max(1, row), rows - 2)
        let targetCol = min(max(1, col), cols - 2)
        guard !cellBlocksPassage(targetRow, targetCol) else { return }
        seats[i].pauseRemaining = 0
        seats[i].destinationRow = targetRow
        seats[i].destinationCol = targetCol
    }

    /// Kralj je mrtav. Vraća sjedište koje treba izbaciti, jednom.
    func killKing(factionId: String) -> RealmSeat? {
        guard let i = seats.firstIndex(where: { $0.id == factionId && $0.kingAlive }) else { return nil }
        seats[i].kingHealthPercent = 0
        seats[i].kingAlive = false
        publish()
        return seats[i]
    }

    private func advance(dt: Double, rows: Int, cols: Int) {
        // Lokalna kopija: mutacija `seats[i]` usred petlje ruši COW buffer
        // (_ContiguousArrayStorage deallocated with non-zero retain count).
        guard !advancing else { return }
        advancing = true
        defer { advancing = false }

        var next = seats
        var changed = false
        for i in next.indices {
            guard next[i].kingAlive else { continue }
            var seat = next[i]
            let targetRow = Double(seat.destinationRow)
            let targetCol = Double(seat.destinationCol)
            let dRow = targetRow - seat.kingRow
            let dCol = targetCol - seat.kingCol
            if hypot(dRow, dCol) < 0.12 {
                let wander = randomWanderTarget(for: seat, rows: rows, cols: cols)
                seat.destinationRow = wander.row
                seat.destinationCol = wander.col
                seat.patrolIndex += 1
            }
            let aimRow = Double(seat.destinationRow) - seat.kingRow
            let aimCol = Double(seat.destinationCol) - seat.kingCol
            let aim = hypot(aimRow, aimCol)
            guard aim > 0.001 else {
                next[i] = seat
                continue
            }
            seat.pauseRemaining = 0
            seat.walkPhase += dt * 7.5
            seat.facing = atan2(aimCol, aimRow)
            let step = min(aim, speedCellsPerSecond * dt)
            let nextRow = seat.kingRow + aimRow / aim * step
            let nextCol = seat.kingCol + aimCol / aim * step
            if let slid = slideAroundObjects(fromRow: seat.kingRow, fromCol: seat.kingCol, toRow: nextRow, toCol: nextCol) {
                seat.kingRow = slid.row
                seat.kingCol = slid.col
            } else {
                let wander = randomWanderTarget(for: seat, rows: rows, cols: cols)
                seat.destinationRow = wander.row
                seat.destinationCol = wander.col
            }
            next[i] = seat
            changed = true
        }
        seats = next
        if changed { publish() }
    }

    /// Nova točka oko dvorca, izvan same kocke, dovoljno daleko od trenutnog mjesta.
    private func randomWanderTarget(for seat: RealmSeat, rows: Int, cols: Int) -> (row: Int, col: Int) {
        let baseRow = seat.castleRow
        let baseCol = seat.castleCol
        var row = Int(baseRow.rounded())
        var col = Int(baseCol.rounded())
        for _ in 0..<8 {
            let radius = Double.random(in: 7...18)
            let angle = Double.random(in: 0..<(2 * .pi))
            let candidateRow = Int((baseRow + sin(angle) * radius).rounded())
            let candidateCol = Int((baseCol + cos(angle) * radius).rounded())
            let clampedRow = min(max(1, candidateRow), max(1, rows - 2))
            let clampedCol = min(max(1, candidateCol), max(1, cols - 2))
            let fromKing = hypot(Double(clampedRow) - seat.kingRow, Double(clampedCol) - seat.kingCol)
            if fromKing >= 4, !cellBlocksPassage(clampedRow, clampedCol) {
                return (clampedRow, clampedCol)
            }
            row = clampedRow
            col = clampedCol
        }
        return (row, col)
    }

    private func cellBlocksPassage(_ row: Int, _ col: Int) -> Bool {
        blocksCell?(row, col) ?? false
    }

    /// Korak koji ulazi u objekt se reže. Nil znači da nema slobodnog smjera.
    private func slideAroundObjects(fromRow: Double, fromCol: Double, toRow: Double, toCol: Double) -> (row: Double, col: Double)? {
        let nowR = Int(fromRow.rounded())
        let nowC = Int(fromCol.rounded())
        let nextR = Int(toRow.rounded())
        let nextC = Int(toCol.rounded())
        let entering = (nextR != nowR || nextC != nowC) && cellBlocksPassage(nextR, nextC)
        guard entering else { return (toRow, toCol) }

        let rowOpen = nextR == nowR || !cellBlocksPassage(nextR, nowC)
        let colOpen = nextC == nowC || !cellBlocksPassage(nowR, nextC)
        if rowOpen && !colOpen { return (toRow, fromCol) }
        if colOpen && !rowOpen { return (fromRow, toCol) }
        if rowOpen && colOpen {
            if abs(toRow - fromRow) >= abs(toCol - fromCol) { return (toRow, fromCol) }
            return (fromRow, toCol)
        }
        return nil
    }

    private func spawnPoint(index: Int, count: Int, centerRow: Int, centerCol: Int, radius: Int, rows: Int, cols: Int) -> (row: Int, col: Int) {
        let row: Int
        let col: Int
        if count <= 1 {
            row = centerRow
            col = centerCol
        } else {
            let angle = Double(index) / Double(count) * 2 * Double.pi
            row = centerRow + Int((sin(angle) * Double(radius)).rounded())
            col = centerCol + Int((cos(angle) * Double(radius)).rounded())
        }
        return (min(max(2, row), rows - 3), min(max(2, col), cols - 3))
    }

    private func factionName(id: String, members: [Realm], groups: [RealmGroup]) -> String {
        if let group = groups.first(where: { $0.id == id }) {
            return group.name
        }
        return members.first?.name ?? id
    }

    private func publish() {
        let seatsCopy = seats
        let next = seatsCopy.map { seat in
            KingRenderSnapshot(
                factionId: seat.id,
                colorHex: seat.colorHex,
                castleRow: seat.castleRow,
                castleCol: seat.castleCol,
                kingRow: seat.kingRow,
                kingCol: seat.kingCol,
                facing: seat.facing,
                alive: seat.kingAlive,
                healthPercent: seat.kingHealthPercent,
                moving: seat.kingAlive,
                walkPhase: seat.walkPhase
            )
        }
        lock.lock()
        snapshots = next
        lock.unlock()
    }
}

extension GameState {
    /// Postavi kocku dvorca i kralja za svaku živu frakciju. Jednom po partiji.
    func spawnRealmSeatsIfNeeded(animated: Bool = true) {
        guard !isMapEditorMode, isLevelReady, !isShowingMainMenu, realmSeats.seats.isEmpty else { return }
        realmSeats.blocksCell = { [weak self] row, col in
            self?.mapLogic.blocksPassage(.surface, row: row, col: col) ?? true
        }
        if isSoloMode {
            let realm = realms.first { $0.id == playerRealmId } ?? realms.first ?? Realm(name: "Igrač", colorHex: "2E86AB", lordType: .human)
            realmSeats.spawnSolo(
                realm: realm,
                rows: gameMap.rows,
                cols: gameMap.cols,
                animate: animated && showsGraphics
            )
        } else {
            realmSeats.spawn(
                from: realms,
                groups: realmGroups,
                rows: gameMap.rows,
                cols: gameMap.cols,
                playerRealmId: playerRealmId,
                startPositions: gameMap.orderedLordStarts,
                animate: animated && showsGraphics
            )
        }
        spawnStartingPeople()
        if !isGamePaused, isLevelReady, !isShowingMainMenu {
            beginMatchClock()
        }
    }

    func clearRealmSeats() {
        realmSeats.stop()
        people.reset()
        buildingAlerts.reset()
        reachability.reset()
        populationRing.reset()
        enclosure.reset()
        campaignResult = nil
        factionDefeatNotice = nil
        peopleCount = 0
        AudioManager.shared.stopFireLoop()
    }

    func movePlayerKing(toRow row: Int, col: Int) {
        guard !isGamePaused, !isMapEditorMode, isLevelReady else { return }
        realmSeats.movePlayerKing(toRow: row, col: col, rows: gameMap.rows, cols: gameMap.cols)
    }

    func moveKing(factionId: String, toRow row: Int, col: Int) {
        guard !isGamePaused, !isMapEditorMode, isLevelReady else { return }
        realmSeats.moveKing(
            factionId: factionId,
            toRow: row,
            col: col,
            rows: gameMap.rows,
            cols: gameMap.cols
        )
    }

    /// Kralj je mrtav: njegova grupa (ili sam realm) ispada iz igre.
    func killKing(factionId: String) {
        guard let seat = realmSeats.killKing(factionId: factionId) else { return }
        for realmId in seat.realmIds {
            defeatRealm(id: realmId)
        }
        let dead = LocalizedStrings.string(for: "faction_king_dead", language: appLanguage)
        factionDefeatNotice = "\(seat.displayName). \(dead)"
        refreshPeopleCount()
    }

    /// Seljaci, radnici i vojnici. Kralj se ne broji. Na početku je 0.
    func refreshPeopleCount() {
        peopleCount = people.people.filter { $0.healthPercent > 0 && $0.activity != .leaving }.count
    }
}
