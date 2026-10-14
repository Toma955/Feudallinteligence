//
//  FieldFarmGameState.swift
//  Feudalism
//
//  Polja (pšenica, sijeno, povrće, jabuke, grožđe, hmelj…): sjetva → rast → berba
//  sinkronizirani s godišnjim dobom. Tek nakon berbe nosi se u skladište.
//  Svinja / krava / ovca / kokoš / košnica ostaju na starom animal ciklusu.
//

import Foundation

extension GameState {
    /// Trajanje faze na polju (potezi pri punoj brzini).
    enum FieldPhaseDuration {
        static func sow(_ cycle: WorkCycle) -> Double { Double(max(12, cycle.durationTicks)) }
        static func grow(_ cycle: WorkCycle) -> Double { Double(Season.turnsPerSeason) }
        static func harvest(_ cycle: WorkCycle) -> Double { Double(max(12, cycle.durationTicks)) }
    }

    func fieldWorkSpots(of farm: Placement) -> [(row: Double, col: Double)] {
        var spots: [(row: Double, col: Double)] = []
        let r0 = farm.row
        let c0 = farm.col
        // Četiri polja 2×2 oko križa (5×5 farmYard).
        let pads: [(Int, Int)] = [(0, 0), (0, 3), (3, 0), (3, 3)]
        for (dr, dc) in pads {
            spots.append((Double(r0 + dr) + 0.75, Double(c0 + dc) + 0.75))
            spots.append((Double(r0 + dr) + 1.25, Double(c0 + dc) + 1.25))
        }
        if spots.isEmpty {
            spots.append((Double(r0) + Double(farm.height) * 0.5, Double(c0) + Double(farm.width) * 0.5))
        }
        return spots
    }

    func sendWorkerToField(farm: Placement, personId: String, task: FieldTask) {
        guard let seat = owner(of: farm).flatMap({ self.seat(of: $0) }) else { return }
        let exit = entrance(of: farm, from: hearthCell(of: seat))
        let spots = fieldWorkSpots(of: farm)
        let target = spots.randomElement() ?? (exit.row, exit.col)
        people.update(id: personId) {
            $0.row = exit.row
            $0.col = exit.col
            $0.layer = .surface
            $0.activity = .walkingToField(placementId: farm.id, task: task)
            $0.targetRow = target.row
            $0.targetCol = target.col
            $0.targetLayer = .surface
            $0.pathTarget = nil
        }
    }

    func nudgeFieldWorker(_ person: Person, farm: Placement, task: FieldTask, dtWalk: Double = 1) {
        let spots = fieldWorkSpots(of: farm)
        guard !spots.isEmpty else { return }
        let current = (person.row, person.col)
        let next = spots.min(by: {
            let d0 = hypot($0.row - current.0, $0.col - current.1)
            let d1 = hypot($1.row - current.0, $1.col - current.1)
            // Preferiraj sljedeću točku koja nije ista.
            return (d0 > 0.4 ? d0 : 99) < (d1 > 0.4 ? d1 : 99)
        }) ?? spots[Int.random(in: 0..<spots.count)]
        people.update(id: person.id) {
            $0.activity = .workingField(placementId: farm.id, task: task)
            let dRow = next.row - $0.row
            let dCol = next.col - $0.col
            let dist = hypot(dRow, dCol)
            let step = min(dist, PeopleRuntime.speedCellsPerSecond * 0.55 * dtWalk)
            if dist > 0.05 {
                $0.row += dRow / dist * step
                $0.col += dCol / dist * step
                $0.facing = atan2(dCol, dRow)
            }
            $0.walkPhase += 0.9
            $0.targetRow = $0.row
            $0.targetCol = $0.col
            $0.pathTarget = nil
        }
    }

    func recallFieldWorkerHome(farm: Placement, personId: String) {
        people.update(id: personId) {
            $0.activity = .working(placementId: farm.id)
        }
    }

    func tickFieldFarm(
        placement farm: Placement,
        layer: MapLayer,
        cycle: WorkCycle,
        state: inout BuildingState,
        season: Season,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        let person = worker(of: farm.id)
        if state.worker != .none, person == nil { state.worker = .none }

        switch person?.activity {
        case .walkingToField, .walkingToWork, .returningToWork, .delivering:
            state.worker = .walking(ticksLeft: person.map(ticksUntilArrival) ?? 1)
            return
        case .workingField(_, let task):
            tickFieldWorkOnPlot(farm: farm, cycle: cycle, person: person, task: task, state: &state, season: season, faction: faction, room: &room)
            return
        default:
            break
        }

        switch state.worker {
        case .none:
            if !state.isClosed, hasPath(to: farm, layer: layer), let assigned = assignWorker(to: farm) {
                state.worker = .walking(ticksLeft: ticksUntilArrival(assigned))
            }
        case .walking:
            if !hasPath(to: farm, layer: layer) {
                releaseWorker(of: farm.id)
                state.worker = .none
            } else if let person {
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
            }
        case .inside:
            tickFieldPhaseAtHut(farm: farm, cycle: cycle, person: person, state: &state, season: season, faction: faction, room: &room)
        }
    }

    private func tickFieldWorkOnPlot(
        farm: Placement,
        cycle: WorkCycle,
        person: Person?,
        task: FieldTask,
        state: inout BuildingState,
        season: Season,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        guard let person else {
            state.worker = .none
            return
        }
        nudgeFieldWorker(person, farm: farm, task: task)
        let left: Int
        switch task {
        case .sowing:
            state.fieldPhase = .sowing
            state.progress += 1
            let need = FieldPhaseDuration.sow(cycle)
            left = max(1, Int((need - state.progress).rounded(.up)))
            state.worker = .walking(ticksLeft: left)
            guard state.progress >= need else { return }
            state.progress = 0
            state.fieldPhase = .growing
            recallFieldWorkerHome(farm: farm, personId: person.id)
            state.worker = .inside
        case .tending:
            state.fieldPhase = .growing
            state.progress += 1
            let need = FieldPhaseDuration.grow(cycle)
            left = max(1, Int((need - state.progress).rounded(.up)))
            state.worker = .walking(ticksLeft: left)
            if season == .autumn {
                state.progress = 0
                state.fieldPhase = .harvesting
                people.update(id: person.id) {
                    $0.activity = .workingField(placementId: farm.id, task: .harvesting)
                }
            } else if state.progress >= need {
                recallFieldWorkerHome(farm: farm, personId: person.id)
                state.worker = .inside
            }
        case .harvesting:
            state.fieldPhase = .harvesting
            state.progress += 1
            let need = FieldPhaseDuration.harvest(cycle)
            left = max(1, Int((need - state.progress).rounded(.up)))
            state.worker = .walking(ticksLeft: left)
            guard state.progress >= need else { return }
            // Berba gotova — tek sada spremi proizvod i nosi u skladište.
            state.pendingOutputs = cycle.outputs
            state.haulGood = cycle.outputs.keys.sorted { $0.rawValue < $1.rawValue }.first
            state.progress = 0
            recallFieldWorkerHome(farm: farm, personId: person.id)
            state.worker = .inside
            tryDeliverFieldHarvest(farm: farm, cycle: cycle, person: person, state: &state, faction: faction, room: &room)
        }
    }

    private func tickFieldPhaseAtHut(
        farm: Placement,
        cycle: WorkCycle,
        person: Person?,
        state: inout BuildingState,
        season: Season,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        // Još nije odneseno nakon berbe.
        if !state.pendingOutputs.isEmpty {
            tryDeliverFieldHarvest(farm: farm, cycle: cycle, person: person, state: &state, faction: faction, room: &room)
            return
        }

        switch season {
        case .winter:
            if state.fieldPhase == .harvesting, let person {
                sendWorkerToField(farm: farm, personId: person.id, task: .harvesting)
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                return
            }
            if state.fieldPhase != .fallow {
                state.fieldPhase = .fallow
                state.progress = 0
            }
            state.waitingForStorage = false
            return

        case .spring:
            if state.fieldPhase == .fallow || state.fieldPhase == .sowing {
                guard let person else { return }
                state.fieldPhase = .sowing
                if state.progress > FieldPhaseDuration.sow(cycle) { state.progress = 0 }
                sendWorkerToField(farm: farm, personId: person.id, task: .sowing)
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
            } else if state.fieldPhase == .growing {
                growAtHut(farm: farm, cycle: cycle, person: person, state: &state, season: season)
            }
            return

        case .summer:
            if state.fieldPhase == .sowing {
                guard let person else { return }
                sendWorkerToField(farm: farm, personId: person.id, task: .sowing)
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                return
            }
            if state.fieldPhase == .fallow {
                guard let person else { return }
                state.fieldPhase = .sowing
                state.progress = 0
                sendWorkerToField(farm: farm, personId: person.id, task: .sowing)
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                return
            }
            if state.fieldPhase == .harvesting {
                // Ne beremo ljeti.
                state.fieldPhase = .growing
            }
            growAtHut(farm: farm, cycle: cycle, person: person, state: &state, season: season)
            return

        case .autumn:
            if state.fieldPhase == .sowing {
                guard let person else { return }
                sendWorkerToField(farm: farm, personId: person.id, task: .sowing)
                state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                return
            }
            if state.fieldPhase == .fallow {
                return
            }
            guard let person else { return }
            state.fieldPhase = .harvesting
            if state.progress > FieldPhaseDuration.harvest(cycle) { state.progress = 0 }
            sendWorkerToField(farm: farm, personId: person.id, task: .harvesting)
            state.worker = .walking(ticksLeft: ticksUntilArrival(person))
        }
    }

    private func growAtHut(
        farm: Placement,
        cycle: WorkCycle,
        person: Person?,
        state: inout BuildingState,
        season: Season
    ) {
        state.fieldPhase = .growing
        let need = FieldPhaseDuration.grow(cycle)
        if state.progress >= need {
            // Usjev zreo — čeka jesen u kućici.
            return
        }
        // Pošalji na polje da njeuje (vidljiva animacija); napredak raste na polju.
        if let person {
            sendWorkerToField(farm: farm, personId: person.id, task: .tending)
            state.worker = .walking(ticksLeft: ticksUntilArrival(person))
            return
        }
        state.progress += 1
        if season == .autumn {
            state.progress = min(state.progress, need)
        }
    }

    private func tryDeliverFieldHarvest(
        farm: Placement,
        cycle: WorkCycle,
        person: Person?,
        state: inout BuildingState,
        faction: String,
        room: inout [String: [StorageKind: Int]]
    ) {
        let outputs = state.pendingOutputs.isEmpty ? cycle.outputs : state.pendingOutputs
        guard !outputs.isEmpty else { return }
        let dest = deliveryDestination(for: farm, outputs: outputs, faction: faction)
        state.waitingForStorage = dest == nil || (dest?.objectId != Carriage.objectId && missingStorage(for: outputs, of: faction) != nil)
        guard let dest, let person, !state.waitingForStorage else { return }

        if dest.objectId == Carriage.objectId {
            let amount = outputs.values.reduce(0, +)
            guard (transportLines[dest.id]?.freeRoom ?? 0) >= amount else {
                state.waitingForStorage = true
                return
            }
        } else {
            let needs = Self.storageNeeds(outputs)
            var free = room[faction] ?? Dictionary(uniqueKeysWithValues: StorageKind.allCases.map {
                ($0, storageCapacity($0, of: faction) - storageStored($0, of: faction))
            })
            room[faction] = free
            guard needs.allSatisfy({ $0.value <= free[$0.key, default: 0] }) else {
                state.waitingForStorage = true
                return
            }
            for (kind, amount) in needs { room[faction]?[kind, default: 0] -= amount }
        }

        state.pendingOutputs = outputs
        state.haulGood = outputs.keys.sorted { $0.rawValue < $1.rawValue }.first
        state.dropOffId = dest.id
        state.waitingForStorage = false
        state.cyclesCompleted += 1
        state.fieldPhase = .fallow
        state.progress = 0
        sendWorkerToDeliver(from: farm, to: dest, personId: person.id)
        state.worker = .walking(ticksLeft: ticksUntilArrival(person))
    }
}
