//
//  WarehouseLayout.swift
//  Feudalism
//
//  Tlocrt skladišta: skladištar, mjesta robe i rute radnika do tih mjesta.
//

import Foundation

struct WarehouseSlot: Codable, Equatable {
    var localRow: Int
    var localCol: Int
    var good: Good
}

struct WarehouseRoute: Codable, Equatable {
    var workplaceId: String
    var good: Good
    var corners: [TransportPoint]
}

struct WarehouseLayout: Codable, Equatable {
    var storeId: String
    var slots: [WarehouseSlot]
    var routes: [WarehouseRoute]

    func slot(for good: Good) -> WarehouseSlot? {
        slots.first { $0.good == good }
    }

    func route(workplaceId: String, good: Good) -> WarehouseRoute? {
        routes.first { $0.workplaceId == workplaceId && $0.good == good }
    }
}

struct WarehouseRouteEdit: Equatable {
    var storeId: String
    var workplaceId: String
    var good: Good
}

struct WarehouseClient: Identifiable {
    var id: String { placement.id + "-" + good.rawValue + (takes ? "-u" : "-s") }
    let placement: Placement
    let good: Good
    let takes: Bool
}

extension GameState {
    func ensureWarehouseLayout(for placement: Placement) {
        guard StorageKind.of(buildingId: placement.objectId) != nil else { return }
        if warehouseLayouts[placement.id] == nil {
            warehouseLayouts[placement.id] = WarehouseLayout(storeId: placement.id, slots: [], routes: [])
        }
    }

    func storeSlotExists(storeId: String, good: Good) -> Bool {
        warehouseHasKeeper(storeId) && warehouseLayouts[storeId]?.slot(for: good) != nil
    }

    func warehouseHasKeeper(_ storeId: String) -> Bool {
        worker(of: storeId) != nil || (buildingStates[storeId]?.worker ?? .none) != WorkerPresence.none
    }

    func hireWarehouseKeeper(storeId: String) {
        guard let (_, p) = locatePlacement(id: storeId), StorageKind.of(buildingId: p.objectId) != nil else { return }
        if buildingStates[storeId]?.isClosed == true { return }
        ensureWarehouseLayout(for: p)
        if warehouseHasKeeper(storeId) { return }
        guard let person = assignWorker(to: p) else {
            placementError = "Nema slobodnog seljaka za skladištara."
            return
        }
        var state = buildingStates[storeId] ?? BuildingState()
        state.worker = .walking(ticksLeft: ticksUntilArrival(person))
        buildingStates[storeId] = state
        objectWillChange.send()
    }

    func fireWarehouseKeeper(storeId: String) {
        releaseWorker(of: storeId)
        buildingStates[storeId]?.worker = .none
        if editingWarehouseRoute?.storeId == storeId { editingWarehouseRoute = nil }
        objectWillChange.send()
    }

    func setWarehouseSlot(storeId: String, localRow: Int, localCol: Int, good: Good?) {
        guard warehouseHasKeeper(storeId), var layout = warehouseLayouts[storeId] else { return }
        if locatePlacement(id: storeId)?.placement.objectId == Lager.objectId,
           LagerPlan.isPassage(localRow: localRow, localCol: localCol) { return }
        layout.slots.removeAll { $0.localRow == localRow && $0.localCol == localCol }
        if let good {
            layout.slots.removeAll { $0.good == good }
            layout.slots.append(WarehouseSlot(localRow: localRow, localCol: localCol, good: good))
            pinWarehouseRoutes(storeId: storeId, layout: &layout, good: good)
        }
        warehouseLayouts[storeId] = layout
        warehouseRouteVersion += 1
        objectWillChange.send()
    }

    func slotPoint(store: Placement, good: Good) -> TransportPoint? {
        guard warehouseHasKeeper(store.id), let slot = warehouseLayouts[store.id]?.slot(for: good) else { return nil }
        return TransportPoint(row: Double(store.row + slot.localRow), col: Double(store.col + slot.localCol))
    }

    func logisticsPoint(store: Placement, good: Good, seat: RealmSeat) -> TransportPoint {
        slotPoint(store: store, good: good) ?? TransportPoint(row: entrance(of: store, from: hearthCell(of: seat)).row, col: entrance(of: store, from: hearthCell(of: seat)).col)
    }

    func warehouseClients(of store: Placement, faction: String) -> [WarehouseClient] {
        guard let kind = StorageKind.of(buildingId: store.objectId) else { return [] }
        var list: [WarehouseClient] = []
        for (_, p) in mapLogic.allPlacements where !p.isDestroyed && owner(of: p) == faction {
            guard let cycle = WorkCycleCatalog.cycle(for: p.objectId) else { continue }
            for good in cycle.inputs.keys where kind.goods.contains(good) {
                list.append(WarehouseClient(placement: p, good: good, takes: true))
            }
            for good in cycle.outputs.keys where kind.goods.contains(good) {
                list.append(WarehouseClient(placement: p, good: good, takes: false))
            }
        }
        return list.sorted { $0.placement.objectId == $1.placement.objectId ? $0.good.rawValue < $1.good.rawValue : $0.placement.objectId < $1.placement.objectId }
    }

    func beginWarehouseRoute(storeId: String, workplaceId: String, good: Good) {
        guard warehouseHasKeeper(storeId),
              let store = locatePlacement(id: storeId)?.placement,
              let work = locatePlacement(id: workplaceId)?.placement,
              let seat = owner(of: store).flatMap({ self.seat(of: $0) }) else { return }
        ensureWarehouseLayout(for: store)
        var layout = warehouseLayouts[storeId] ?? WarehouseLayout(storeId: storeId, slots: [], routes: [])
        if layout.route(workplaceId: workplaceId, good: good) == nil {
            let start = entrance(of: work, from: hearthCell(of: seat))
            let end = logisticsPoint(store: store, good: good, seat: seat)
            layout.routes.append(WarehouseRoute(
                workplaceId: workplaceId,
                good: good,
                corners: [TransportPoint(row: start.row, col: start.col), end]
            ))
            warehouseLayouts[storeId] = layout
        }
        editingTransportId = nil
        editingWarehouseRoute = WarehouseRouteEdit(storeId: storeId, workplaceId: workplaceId, good: good)
        warehouseRouteVersion += 1
        objectWillChange.send()
    }

    func moveWarehouseRouteCorner(index: Int, row: Double, col: Double) {
        guard let edit = editingWarehouseRoute, var layout = warehouseLayouts[edit.storeId],
              let i = layout.routes.firstIndex(where: { $0.workplaceId == edit.workplaceId && $0.good == edit.good }),
              index > 0, index < layout.routes[i].corners.count else { return }
        layout.routes[i].corners[index] = TransportPoint(
            row: min(max(0.5, row), Double(gameMap.rows) - 1.5),
            col: min(max(0.5, col), Double(gameMap.cols) - 1.5)
        )
        warehouseLayouts[edit.storeId] = layout
        warehouseRouteVersion += 1
    }

    func promoteWarehouseRouteMid(after index: Int, row: Double, col: Double) {
        guard var layout = warehouseLayouts[editingWarehouseRoute?.storeId ?? ""],
              let edit = editingWarehouseRoute,
              let i = layout.routes.firstIndex(where: { $0.workplaceId == edit.workplaceId && $0.good == edit.good }),
              index >= 0, index + 1 < layout.routes[i].corners.count else { return }
        layout.routes[i].corners.insert(TransportPoint(
            row: min(max(0.5, row), Double(gameMap.rows) - 1.5),
            col: min(max(0.5, col), Double(gameMap.cols) - 1.5)
        ), at: index + 1)
        warehouseLayouts[edit.storeId] = layout
        warehouseRouteVersion += 1
    }

    func warehousePath(workplaceId: String, storeId: String, good: Good, from: PathPoint, to: PathPoint) -> [PathPoint]? {
        guard let route = warehouseLayouts[storeId]?.route(workplaceId: workplaceId, good: good), route.corners.count >= 2 else { return nil }
        var points = route.corners.map { PathPoint(row: $0.row, col: $0.col, layer: from.layer) }
        if points.first.map({ hypot($0.row - from.row, $0.col - from.col) }) ?? 1 > 0.4 {
            points.insert(from, at: 0)
        }
        if let last = points.last, hypot(last.row - to.row, last.col - to.col) > 0.4 {
            points.append(to)
        }
        return points
    }

    func pickupStore(for source: Placement, inputs: [Good: Int], faction: String) -> Placement? {
        let kinds = Set(inputs.keys.compactMap { StorageKind.of($0) })
        let stores = mapLogic.allPlacements
            .map(\.placement)
            .filter { p in
                guard !p.isDestroyed, owner(of: p) == faction, warehouseHasKeeper(p.id),
                      let kind = StorageKind.of(buildingId: p.objectId) else { return false }
                return kinds.contains(kind)
            }
        return stores.min {
            hypot(Double($0.row) - Double(source.row), Double($0.col) - Double(source.col))
                < hypot(Double($1.row) - Double(source.row), Double($1.col) - Double(source.col))
        }
    }

    func sendWorkerToFetch(from workplace: Placement, to store: Placement, personId: String, good: Good) {
        guard let seat = owner(of: workplace).flatMap({ self.seat(of: $0) }) else { return }
        let fromLayer = locatePlacement(id: workplace.id)?.layer ?? .surface
        let destLayer = locatePlacement(id: store.id)?.layer ?? .surface
        let exit = entrance(of: workplace, from: hearthCell(of: seat))
        let target = logisticsPoint(store: store, good: good, seat: seat)
        people.update(id: personId) {
            $0.row = exit.row
            $0.col = exit.col
            $0.layer = fromLayer
            $0.activity = .fetching(fromId: workplace.id, storeId: store.id)
            $0.targetRow = target.row
            $0.targetCol = target.col
            $0.targetLayer = destLayer
            $0.pathTarget = nil
        }
    }

    func finishFetch(from workplaceId: String, storeId: String) {
        guard var state = buildingStates[workplaceId],
              let workplace = locatePlacement(id: workplaceId)?.placement,
              let cycle = WorkCycleCatalog.cycle(for: workplace.objectId),
              let faction = owner(of: workplace),
              let seat = seat(of: faction),
              let person = worker(of: workplaceId) else { return }
        let hasInputs = cycle.inputs.allSatisfy { goodAmount($0.key, of: faction) >= $0.value }
        if hasInputs {
            for (good, amount) in cycle.inputs { addGood(good, -amount, to: faction) }
            state.fetchedInputs = true
            state.waitingForInput = false
        } else {
            state.waitingForInput = true
        }
        state.fetchingInputs = false
        buildingStates[workplaceId] = state
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

    private func pinWarehouseRoutes(storeId: String, layout: inout WarehouseLayout, good: Good) {
        guard let store = locatePlacement(id: storeId)?.placement,
              let seat = owner(of: store).flatMap({ self.seat(of: $0) }),
              let end = slotPoint(store: store, good: good) else { return }
        for i in layout.routes.indices where layout.routes[i].good == good {
            if !layout.routes[i].corners.isEmpty {
                layout.routes[i].corners[layout.routes[i].corners.count - 1] = end
            }
        }
    }
}
