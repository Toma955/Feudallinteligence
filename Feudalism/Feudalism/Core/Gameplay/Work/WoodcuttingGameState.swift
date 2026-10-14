//
//  WoodcuttingGameState.swift
//  Feudalism
//
//  Sječar: kućica → stablo (sječa) → deblo kući (pila) → daske u skladište.
//

import Foundation

extension GameState {
    func claimedTreeIds() -> Set<String> {
        Set(buildingStates.values.compactMap(\.targetTreeId))
    }

    func nearestHarvestTree(from hut: Placement, faction: String) -> Placement? {
        let claimed = claimedTreeIds()
        let sr = Double(hut.row), sc = Double(hut.col)
        return gameMap.placements
            .filter { HarvestTrees.isTree($0.objectId) && !$0.isDestroyed && !claimed.contains($0.id) }
            .filter { hasPath(to: $0, layer: .surface) }
            .min { hypot(Double($0.row) - sr, Double($0.col) - sc) < hypot(Double($1.row) - sr, Double($1.col) - sc) }
    }

    func sendWoodcutter(from hut: Placement, to tree: Placement, personId: String) {
        guard let seat = owner(of: hut).flatMap({ self.seat(of: $0) }) else { return }
        let exit = entrance(of: hut, from: hearthCell(of: seat))
        let target = entrance(of: tree, from: exit)
        people.update(id: personId) {
            $0.row = exit.row
            $0.col = exit.col
            $0.layer = .surface
            $0.activity = .walkingToTree(hutId: hut.id, treeId: tree.id)
            $0.targetRow = target.row
            $0.targetCol = target.col
            $0.targetLayer = .surface
            $0.pathTarget = nil
        }
    }

    func sendWoodcutterHome(hut: Placement, tree: Placement, personId: String) {
        guard let seat = owner(of: hut).flatMap({ self.seat(of: $0) }) else { return }
        let back = entrance(of: hut, from: hearthCell(of: seat))
        people.update(id: personId) {
            $0.activity = .haulingLog(hutId: hut.id, treeId: tree.id)
            $0.targetRow = back.row
            $0.targetCol = back.col
            $0.targetLayer = .surface
            $0.pathTarget = nil
        }
    }

    func fellTree(_ tree: Placement) {
        gameMap.removePlacement(id: tree.id)
        bumpPlacementsVersion()
        people.mapVersion += 1
    }

    func tickWoodcutter(
        placement hut: Placement,
        layer: MapLayer,
        cycle: WorkCycle,
        state: inout BuildingState,
        season: Season,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        let person = worker(of: hut.id)
        if state.worker != .none, person == nil { state.worker = .none }

        switch person?.activity {
        case .walkingToTree, .haulingLog, .walkingToWork, .returningToWork, .delivering:
            state.worker = .walking(ticksLeft: person.map(ticksUntilArrival) ?? 1)
            return
        case .chopping(_, let treeId):
            tickChop(hut: hut, treeId: treeId, person: person, state: &state, season: season)
            return
        default:
            break
        }

        switch state.worker {
        case .none:
            if !state.isClosed, hasPath(to: hut, layer: layer), let assigned = assignWorker(to: hut) {
                state.worker = .walking(ticksLeft: ticksUntilArrival(assigned))
            }
        case .walking:
            if !hasPath(to: hut, layer: layer) {
                releaseWorker(of: hut.id)
                state.worker = .none
            } else if let person {
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
            }
        case .inside:
            tickSawOrSendToTree(hut: hut, cycle: cycle, person: person, state: &state, season: season, faction: faction, room: &room)
        }
    }

    private func tickChop(hut: Placement, treeId: String, person: Person?, state: inout BuildingState, season: Season) {
        guard let tree = locatePlacement(id: treeId)?.placement, HarvestTrees.isTree(tree.objectId), !tree.isDestroyed else {
            state.targetTreeId = nil
            state.chopProgress = 0
            state.waitingForTree = true
            if let person {
                people.update(id: person.id) { $0.activity = .working(placementId: hut.id) }
            }
            state.worker = .inside
            return
        }
        let yield = HarvestTrees.yield(for: tree.objectId)
        state.chopProgress += WorkKind.resource.seasonFactor(season)
        let left = max(1, Int((Double(yield.cutTicks) - state.chopProgress).rounded(.up)))
        state.worker = .walking(ticksLeft: left)
        guard state.chopProgress >= Double(yield.cutTicks), let person else { return }
        var cargo: [Good: Int] = [:]
        if yield.planks > 0 { cargo[.wood] = yield.planks }
        if yield.bananas > 0 { cargo[.banana] = yield.bananas }
        if cargo.isEmpty { cargo[.wood] = 1 }
        state.pendingOutputs = cargo
        state.sawTicks = yield.bananas > 0 && yield.planks == 0 ? max(0, yield.sawTicks) : yield.sawTicks
        state.haulGood = yield.bananas > 0 && yield.planks == 0 ? .banana : .wood
        fellTree(tree)
        state.targetTreeId = nil
        state.chopProgress = 0
        sendWoodcutterHome(hut: hut, tree: tree, personId: person.id)
        state.worker = .walking(ticksLeft: ticksUntilArrival(person))
    }

    private func tickSawOrSendToTree(
        hut: Placement,
        cycle: WorkCycle,
        person: Person?,
        state: inout BuildingState,
        season: Season,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        let outputs = state.pendingOutputs.isEmpty ? cycle.outputs : state.pendingOutputs
        if !state.pendingOutputs.isEmpty {
            state.waitingForTree = false
            let dest = deliveryDestination(for: hut, outputs: outputs, faction: faction)
            state.waitingForStorage = dest == nil || (dest?.objectId != Carriage.objectId && missingStorage(for: outputs, of: faction) != nil)
            if state.waitingForStorage { return }
            let saw = Double(state.sawTicks ?? cycle.durationTicks)
            // Banane s palme: kratko sortiranje (saw≈0/1), bez piljenja dasaka.
            if saw <= 0 {
                state.progress = 0
            } else {
                state.progress += WorkKind.resource.seasonFactor(season)
                guard state.progress >= saw else { return }
            }
            guard let dest, let person else {
                state.progress = saw
                state.waitingForStorage = true
                return
            }
            if dest.objectId == Carriage.objectId {
                let amount = outputs.values.reduce(0, +)
                guard (transportLines[dest.id]?.freeRoom ?? 0) >= amount else {
                    state.progress = saw
                    state.waitingForStorage = true
                    return
                }
            } else {
                let needs = Self.storageNeeds(outputs)
                let free = room[faction] ?? Dictionary(uniqueKeysWithValues: StorageKind.allCases.map {
                    ($0, storageCapacity($0, of: faction) - storageStored($0, of: faction))
                })
                room[faction] = free
                guard needs.allSatisfy({ $0.value <= free[$0.key, default: 0] }) else {
                    state.progress = saw
                    state.waitingForStorage = true
                    return
                }
                for (kind, amount) in needs { room[faction]?[kind, default: 0] -= amount }
            }
            state.dropOffId = dest.id
            state.progress = 0
            state.sawTicks = nil
            state.waitingForStorage = false
            state.cyclesCompleted += 1
            sendWorkerToDeliver(from: hut, to: dest, personId: person.id)
            state.worker = .walking(ticksLeft: ticksUntilArrival(person))
            return
        }

        guard let person else { return }
        if let tree = nearestHarvestTree(from: hut, faction: faction) {
            state.waitingForTree = false
            state.targetTreeId = tree.id
            state.chopProgress = 0
            sendWoodcutter(from: hut, to: tree, personId: person.id)
            state.worker = .walking(ticksLeft: ticksUntilArrival(person))
        } else {
            state.waitingForTree = true
            state.targetTreeId = nil
        }
    }
}
