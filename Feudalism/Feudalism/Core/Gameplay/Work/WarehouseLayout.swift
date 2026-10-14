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

    func lagerStores(of faction: String) -> [Placement] {
        mapLogic.allPlacements.map(\.placement).filter {
            $0.objectId == Lager.objectId && !$0.isDestroyed && owner(of: $0) == faction
        }.sorted { buildingBirthRank($0.id) < buildingBirthRank($1.id) }
    }

    /// Zauzeta i slobodna polja 2×2. Puno polje zauzima novo mjesto za isti resurs.
    func lagerRoom(of faction: String) -> (free: Int, total: Int) {
        let total = lagerStores(of: faction).count * LagerPlan.bays.count
        let used = min(total, stockedGoods(of: faction).reduce(0) { sum, good in
            sum + baysNeeded(for: good, faction: faction)
        })
        return (max(0, total - used), total)
    }

    /// Ima li još mjesta za barem jednu jedinicu. Puno polje smije prijeći na sljedeće slobodno.
    func lagerHasRoom(for good: Good, faction: String) -> Bool {
        unitsThatFit(good, adding: 1, faction: faction) > 0
    }

    /// Koliko se jedinica može dodati u odgovarajuće skladište (smočnica, lager, oružarnica…).
    /// Ne mijenja layout (izbjegava "Publishing changes from within view updates").
    func unitsThatFit(_ good: Good, adding: Int, faction: String) -> Int {
        guard adding > 0 else { return 0 }
        if good == .gold { return adding }
        guard let kind = StorageKind.of(good) else { return adding }
        if kind != .warehouse {
            let free = storageCapacity(kind, of: faction) - storageStored(kind, of: faction)
            return min(adding, max(0, free))
        }
        let limit = WarehouseSpotNotebook.limit(for: good)
        guard limit > 0 else { return 0 }
        let stores = lagerStores(of: faction)
        guard !stores.isEmpty else { return 0 }
        let totalBays = stores.count * LagerPlan.bays.count
        let have = goodAmount(good, of: faction)
        let mine = baysNeeded(for: good, faction: faction)
        var usedByOthers = 0
        for other in StorageKind.warehouse.goods where other != good {
            usedByOthers += baysNeeded(for: other, faction: faction)
        }
        let free = max(0, totalBays - mine - usedByOthers)
        let space = mine * limit - have + free * limit
        return min(adding, max(0, space))
    }

    private func baysNeeded(for good: Good, faction: String) -> Int {
        let amount = goodAmount(good, of: faction)
        guard amount > 0 else { return 0 }
        let limit = max(1, WarehouseSpotNotebook.limit(for: good))
        return (amount + limit - 1) / limit
    }

    private func occupiedBays(of faction: String) -> [(store: String, bay: LagerPlan.Bay, good: Good)] {
        var list: [(store: String, bay: LagerPlan.Bay, good: Good)] = []
        for store in lagerStores(of: faction) {
            let slots = warehouseLayouts[store.id]?.slots ?? []
            for bay in LagerPlan.bays {
                guard let slot = slots.first(where: { bay.contains(localRow: $0.localRow, localCol: $0.localCol) }),
                      slot.good != .gold,
                      goodAmount(slot.good, of: faction) > 0 else { continue }
                list.append((store.id, bay, slot.good))
            }
        }
        return list
    }

    private func stockedGoods(of faction: String) -> [Good] {
        Good.allCases.filter { $0 != .gold && goodAmount($0, of: faction) > 0 }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Popuni polja 2×2. Kad jedno polje prijeđe limit, isti resurs zauzme sljedeće slobodno.
    func syncLagerBays(of faction: String) {
        let stores = lagerStores(of: faction)
        var taken: [(store: String, bay: LagerPlan.Bay, good: Good)] = []
        for store in stores {
            let slots = warehouseLayouts[store.id]?.slots ?? []
            for bay in LagerPlan.bays {
                guard let slot = slots.first(where: { bay.contains(localRow: $0.localRow, localCol: $0.localCol) }),
                      slot.good != .gold,
                      goodAmount(slot.good, of: faction) > 0 else { continue }
                taken.append((store.id, bay, slot.good))
            }
        }
        for good in stockedGoods(of: faction) {
            let needed = baysNeeded(for: good, faction: faction)
            var have = taken.filter { $0.good == good }.count
            if have > needed {
                var drop = have - needed
                var kept: [(store: String, bay: LagerPlan.Bay, good: Good)] = []
                for item in taken.reversed() {
                    if item.good == good, drop > 0 {
                        drop -= 1
                        continue
                    }
                    kept.append(item)
                }
                taken = Array(kept.reversed())
                have = needed
            }
            while have < needed {
                guard let spot = freeLagerBay(stores: stores, taken: taken) else { break }
                taken.append((spot.store, spot.bay, good))
                have += 1
            }
        }
        for store in stores {
            var layout = warehouseLayouts[store.id] ?? WarehouseLayout(storeId: store.id, slots: [], routes: [])
            let slots = taken.filter { $0.store == store.id }.map {
                WarehouseSlot(localRow: $0.bay.row, localCol: $0.bay.col, good: $0.good)
            }
            if layout.slots != slots {
                layout.slots = slots
                warehouseLayouts[store.id] = layout
                warehouseRouteVersion += 1
            }
        }
    }

    private func freeLagerBay(stores: [Placement], taken: [(store: String, bay: LagerPlan.Bay, good: Good)]) -> (store: String, bay: LagerPlan.Bay)? {
        for store in stores {
            for bay in LagerPlan.bays where !taken.contains(where: { $0.store == store.id && $0.bay == bay }) {
                return (store.id, bay)
            }
        }
        return nil
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

    func finishFetch(from workplaceId: String, storeId: String, personId: String) {
        guard var state = buildingStates[workplaceId],
              let workplace = locatePlacement(id: workplaceId)?.placement,
              let cycle = workCycle(for: workplace, millGrain: state.millGrain),
              let faction = owner(of: workplace),
              let seat = seat(of: faction),
              people.person(id: personId) != nil else { return }
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
        people.update(id: personId) {
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
