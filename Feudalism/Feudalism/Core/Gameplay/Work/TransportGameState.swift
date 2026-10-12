//
//  TransportGameState.swift
//  Feudalism
//
//  Mini-skladište, tko smije ostavljati, volovi i uređivanje rute.
//

import Foundation

extension GameState {
    func placementCenter(_ p: Placement) -> TransportPoint {
        TransportPoint(row: Double(p.row) + Double(p.height) / 2 - 0.5, col: Double(p.col) + Double(p.width) / 2 - 0.5)
    }

    func ensureTransportLine(for placement: Placement) {
        guard placement.objectId == Carriage.objectId else { return }
        var line = transportLines[placement.id] ?? TransportLine(
            depotId: placement.id,
            corners: [],
            allowedSourceIds: [],
            stock: [:]
        )
        line.pinStart(placementCenter(placement))
        if line.corners.count < 2, let seat = owner(of: placement).flatMap({ seat(of: $0) }) {
            line.corners = [line.corners[0], TransportPoint(row: seat.castleRow, col: seat.castleCol)]
        }
        transportLines[placement.id] = line
    }

    func removeTransportLine(depotId: String) {
        transportLines[depotId] = nil
        oxen.remove(depotId: depotId)
        if editingTransportId == depotId { editingTransportId = nil }
    }

    func setTransportSource(depotId: String, sourceId: String, allowed: Bool) {
        guard var line = transportLines[depotId] else { return }
        if allowed {
            if !line.allowedSourceIds.contains(sourceId) { line.allowedSourceIds.append(sourceId) }
        } else {
            line.allowedSourceIds.removeAll { $0 == sourceId }
        }
        transportLines[depotId] = line
        objectWillChange.send()
    }

    func moveTransportCorner(depotId: String, index: Int, row: Double, col: Double) {
        guard var line = transportLines[depotId], index > 0, index < line.corners.count else { return }
        let r = min(max(0.5, row), Double(gameMap.rows) - 1.5)
        let c = min(max(0.5, col), Double(gameMap.cols) - 1.5)
        line.corners[index] = TransportPoint(row: r, col: c)
        transportLines[depotId] = line
        transportRouteVersion += 1
    }

    /// Polutočka postaje kut: jedna ravnina postaje dva kraća segmenta.
    func promoteTransportMid(depotId: String, after index: Int, row: Double, col: Double) {
        guard var line = transportLines[depotId], index >= 0, index + 1 < line.corners.count else { return }
        let r = min(max(0.5, row), Double(gameMap.rows) - 1.5)
        let c = min(max(0.5, col), Double(gameMap.cols) - 1.5)
        line.corners.insert(TransportPoint(row: r, col: c), at: index + 1)
        transportLines[depotId] = line
        transportRouteVersion += 1
    }

    func workplacesForTransport(faction: String) -> [Placement] {
        mapLogic.allPlacements
            .map(\.placement)
            .filter { WorkCycleCatalog.isWorkplace($0.objectId) && !$0.isDestroyed && owner(of: $0) == faction }
            .sorted { $0.objectId < $1.objectId }
    }

    func deliveryDestination(for source: Placement, outputs: [Good: Int], faction: String) -> Placement? {
        let amount = outputs.values.reduce(0, +)
        let depots = transportLines.values.compactMap { line -> Placement? in
            guard line.allowedSourceIds.contains(source.id),
                  let depot = locatePlacement(id: line.depotId)?.placement,
                  !depot.isDestroyed, owner(of: depot) == faction,
                  line.freeRoom >= amount else { return nil }
            return depot
        }
        if let nearest = nearestPlacement(depots, to: source) { return nearest }
        let kinds = Set(outputs.keys.compactMap { StorageKind.of($0) })
        let stores = mapLogic.allPlacements
            .map(\.placement)
            .filter { p in
                guard !p.isDestroyed, owner(of: p) == faction, let kind = StorageKind.of(buildingId: p.objectId) else { return false }
                return kinds.contains(kind)
            }
        return nearestPlacement(stores, to: source)
    }

    private func nearestPlacement(_ list: [Placement], to source: Placement) -> Placement? {
        let sr = Double(source.row), sc = Double(source.col)
        return list.min { hypot(Double($0.row) - sr, Double($0.col) - sc) < hypot(Double($1.row) - sr, Double($1.col) - sc) }
    }

    func sendWorkerToDeliver(from workplace: Placement, to dest: Placement, personId: String) {
        guard let seat = owner(of: workplace).flatMap({ self.seat(of: $0) }) else { return }
        let fromLayer = locatePlacement(id: workplace.id)?.layer ?? .surface
        let destLayer = locatePlacement(id: dest.id)?.layer ?? .surface
        let exit = entrance(of: workplace, from: hearthCell(of: seat))
        let good = buildingStates[workplace.id]?.haulGood
            ?? buildingStates[workplace.id]?.pendingOutputs.keys.sorted { $0.rawValue < $1.rawValue }.first
        let target: (row: Double, col: Double)
        if dest.objectId != Carriage.objectId, let good {
            let point = logisticsPoint(store: dest, good: good, seat: seat)
            target = (point.row, point.col)
        } else {
            target = entrance(of: dest, from: hearthCell(of: seat))
        }
        people.update(id: personId) {
            $0.row = exit.row
            $0.col = exit.col
            $0.layer = fromLayer
            $0.activity = .delivering(fromId: workplace.id, toId: dest.id)
            $0.targetRow = target.row
            $0.targetCol = target.col
            $0.targetLayer = destLayer
            $0.pathTarget = nil
        }
    }

    func depositDelivery(from workplaceId: String, to destId: String) {
        guard var state = buildingStates[workplaceId], let dest = locatePlacement(id: destId)?.placement else { return }
        let cargo = state.pendingOutputs
        if dest.objectId == Carriage.objectId {
            transportLines[dest.id]?.add(cargo)
        } else if let faction = owner(of: dest) {
            for (good, amount) in cargo { addGood(good, amount, to: faction) }
        }
        state.pendingOutputs = [:]
        state.dropOffId = nil
        buildingStates[workplaceId] = state
        guard let workplace = locatePlacement(id: workplaceId)?.placement,
              let seat = owner(of: workplace).flatMap({ self.seat(of: $0) }),
              let person = worker(of: workplaceId) else { return }
        let back = entrance(of: workplace, from: hearthCell(of: seat))
        let layer = locatePlacement(id: workplaceId)?.layer ?? .surface
        people.update(id: person.id) {
            $0.activity = .returningToWork(placementId: workplaceId)
            $0.targetRow = back.row
            $0.targetCol = back.col
            $0.targetLayer = layer
            $0.pathTarget = nil
        }
    }

    func tickTransport() {
        for (_, p) in mapLogic.allPlacements where p.objectId == Carriage.objectId && !p.isDestroyed {
            ensureTransportLine(for: p)
            guard var line = transportLines[p.id], let faction = owner(of: p) else { continue }
            line.pinStart(placementCenter(p))
            transportLines[p.id] = line
            guard line.stored >= TransportRules.haulSize, !oxen.hasOx(for: p.id) else { continue }
            var next = line
            let load = next.takeLoad(max: TransportRules.haulSize)
            transportLines[p.id] = next
            let color = seat(of: faction)?.colorHex ?? "#8B5A2B"
            oxen.send(depotId: p.id, cargo: load, from: next.corners[0], colorHex: color)
        }
    }
}
