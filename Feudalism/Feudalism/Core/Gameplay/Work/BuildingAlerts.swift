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
    case noPath
    case sleeping
    case castleClosed
    case noCandle
    case noTree

    var text: String {
        switch self {
        case .noWorker: return "Nema radnika"
        case .noPath: return "Nema puta"
        case .sleeping: return "Spava"
        case .castleClosed: return "Dvorac zatvoren"
        case .noCandle: return "Nema svijeće"
        case .noTree: return "Nema stabla"
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
    /// Što ne valja s radnim mjestom igrača; nil = radi ili radnik dolazi.
    func buildingAlert(for placement: Placement, layer: MapLayer) -> BuildingAlert? {
        let workplace = WorkCycleCatalog.isWorkplace(placement.objectId)
        let storage = StorageKind.of(buildingId: placement.objectId) != nil
        guard workplace || storage, !placement.isDestroyed else { return nil }
        let state = buildingStates[placement.id] ?? BuildingState()
        if state.isClosed { return .sleeping }
        guard workplace else { return nil }
        if state.isOnFire { return nil }
        if state.waitingForCandle { return .noCandle }
        if state.waitingForTree { return .noTree }
        if let faction = owner(of: placement), CandleRules.needsCandle(objectId: placement.objectId, layer: layer),
           !CandleRules.hasCandles(self, faction) {
            return .noCandle
        }
        if !hasPath(to: placement, layer: layer) { return .noPath }
        return state.worker == .none ? .noWorker : nil
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
