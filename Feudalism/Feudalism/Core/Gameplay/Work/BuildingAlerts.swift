//
//  BuildingAlerts.swift
//  Feudalism
//
//  Oznaka iznad radnog mjesta: nema radnika, nema puta ili spava. Računa se u logici svaki potez;
//  renderer samo čita kopiju (kao kod osoba), pa simulator ne troši ništa na prikaz.
//

import Foundation

enum BuildingAlert: String, Codable {
    case noWorker
    case noMoney
    case noResources
    case noPath
    case noRoomWarehouse
    case noRoomPantry
    case noRoomArmory
    case noRoomOther
    case onFire
    case sleeping
    case castleClosed
    case noCandle
    case noTree

    var text: String {
        switch self {
        case .noWorker: return "Nema radnika"
        case .noMoney: return "Nema novaca"
        case .noResources: return "Nema resursa"
        case .noPath: return "Nema puta/prolaza"
        case .noRoomWarehouse: return "Nema mjesta u skladištu"
        case .noRoomPantry: return "Nema mjesta u smočnici"
        case .noRoomArmory: return "Nema mjesta u oružarnici"
        case .noRoomOther: return "Nema mjesta u skladištu"
        case .onFire: return "Pod vatrom"
        case .sleeping: return "Spava"
        case .castleClosed: return "Dvorac zatvoren"
        case .noCandle: return "Nema svijeće"
        case .noTree: return "Nema stabla"
        }
    }

    /// Problemi koje vlasnik vidi na donjem islandu.
    var showsOnBuilding: Bool {
        switch self {
        case .noWorker, .noMoney, .noResources, .noPath, .noRoomWarehouse, .noRoomPantry, .noRoomArmory, .noRoomOther, .onFire, .noCandle:
            return true
        case .sleeping, .castleClosed, .noTree:
            return false
        }
    }
}

struct BuildingAlertSnapshot: Equatable {
    let placementId: String
    let objectId: String
    let row: Int
    let col: Int
    let width: Int
    let height: Int
    let alert: BuildingAlert
    let layer: MapLayer
}

final class BuildingAlertsRuntime {
    private let lock = NSLock()
    private var snapshots: [BuildingAlertSnapshot] = []

    func set(_ list: [BuildingAlertSnapshot]) {
        lock.lock()
        snapshots = list
        lock.unlock()
    }

    func copySnapshots() -> [BuildingAlertSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }

    func reset() { set([]) }
}

extension GameState {
    /// Svi razlozi zbog kojih radno mjesto trenutno ne može raditi.
    func workplaceProblems(for placement: Placement, layer: MapLayer) -> [BuildingAlert] {
        guard WorkCycleCatalog.isWorkplace(placement.objectId), !placement.isDestroyed else {
            let state = buildingStates[placement.id] ?? BuildingState()
            return state.isOnFire ? [.onFire] : []
        }
        let state = buildingStates[placement.id] ?? BuildingState()
        if state.isClosed { return [.sleeping] }
        var problems: [BuildingAlert] = []
        if state.isOnFire { problems.append(.onFire) }
        let faction = owner(of: placement)
        let dark = CandleRules.needsCandle(objectId: placement.objectId, layer: layer)
            && faction.map { !CandleRules.hasCandles(self, $0) } == true
        if dark { problems.append(.noCandle) }
        if !hasPath(to: placement, layer: layer), !dark { problems.append(.noPath) }
        if state.worker == .none, !state.isOnFire { problems.append(.noWorker) }
        guard let cycle = WorkCycleCatalog.cycle(for: placement.objectId), let faction else {
            return problems
        }
        let goldNeed = cycle.inputs[.gold] ?? 0
        if goldNeed > 0, goodAmount(.gold, of: faction) < goldNeed { problems.append(.noMoney) }
        let shortResource = cycle.inputs.contains { good, amount in
            good != .gold && goodAmount(good, of: faction) < amount
        }
        if shortResource || (state.waitingForInput && goldNeed == 0) { problems.append(.noResources) }
        if state.waitingForStorage || storageBlocks(cycle, faction: faction) {
            let kind = missingStorage(for: cycle.outputs, of: faction) ?? fullStorage(for: cycle.outputs, of: faction)
            problems.append(roomAlert(kind))
        }
        if state.waitingForTree { problems.append(.noTree) }
        return problems
    }

    private func storageBlocks(_ cycle: WorkCycle, faction: String) -> Bool {
        guard cycle.outputs.contains(where: { StorageKind.of($0.key) != nil }) else { return false }
        return missingStorage(for: cycle.outputs, of: faction) != nil
            || fullStorage(for: cycle.outputs, of: faction) != nil
    }

    private func roomAlert(_ kind: StorageKind?) -> BuildingAlert {
        switch kind {
        case .warehouse: return .noRoomWarehouse
        case .pantry: return .noRoomPantry
        case .armory: return .noRoomArmory
        default: return .noRoomOther
        }
    }

    /// Najvažniji razlog, za pločicu iznad građevine. Nil = radi ili radnik dolazi.
    func buildingAlert(for placement: Placement, layer: MapLayer) -> BuildingAlert? {
        let problems = workplaceProblems(for: placement, layer: layer)
        return problems.first
    }

    /// Oznake nadzemnih radnih mjesta igrača za 3D prikaz.
    func refreshBuildingAlerts() {
        guard showsGraphics else { return }
        var list = mapLogic.allPlacements.compactMap { item -> BuildingAlertSnapshot? in
            guard isOwnedByPlayer(item.placement), let alert = buildingAlert(for: item.placement, layer: item.layer) else { return nil }
            return BuildingAlertSnapshot(placementId: item.placement.id, objectId: item.placement.objectId,
                                         row: item.placement.row, col: item.placement.col,
                                         width: item.placement.width, height: item.placement.height,
                                         alert: alert, layer: item.layer)
        }
        if let seat = playerSeat, castleEnclosed[seat.id] == true {
            list.append(BuildingAlertSnapshot(placementId: "castle-\(seat.id)", objectId: Castle.objectId,
                                              row: Int(seat.castleRow), col: Int(seat.castleCol), width: 1, height: 1, alert: .castleClosed, layer: .surface))
        }
        buildingAlerts.set(list)
    }
}
