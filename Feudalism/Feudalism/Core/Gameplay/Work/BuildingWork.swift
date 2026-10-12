//
//  BuildingWork.swift
//  Feudalism
//
//  Stanje svake građevine u partiji: radnik (nema / ide / unutra), napredak ciklusa i vatra.
//  Zdravlje je u Placement.currentHealth (100 % = puno). Sve radi nad logičkom mapom, bez prikaza.
//

import Foundation

enum WorkerPresence: Codable, Equatable {
    case none
    /// Radnik ide prema građevini; stiže za toliko poteza.
    case walking(ticksLeft: Int)
    case inside
}

struct BuildingState: Codable, Equatable {
    var worker: WorkerPresence = .none
    /// Napredak trenutnog ciklusa u potezima (puna brzina = +1 po potezu).
    var progress: Double = 0
    var cyclesCompleted: Int = 0
    var isOnFire = false
    /// Ručno zatvoreno: radnik ne dolazi.
    var isClosed = false
    /// Zadnji ciklus nije mogao krenuti jer nema ulaza.
    var waitingForInput = false
    /// Ciklus je gotov, ali skladište (oružarnica, smočnica) je puno.
    var waitingForStorage = false
    /// Oružje / podzemlje čeka svijeću (ne troši se; količina kasnije).
    var waitingForCandle = false
    /// Proizvod koji radnik nosi do skladišta / prijevoza.
    var pendingOutputs: [Good: Int] = [:]
    var dropOffId: String?
    var fetchingInputs = false
    var fetchedInputs = false
    var haulGood: Good?
    /// Sječarnica čeka slobodno stablo.
    var waitingForTree = false
    var targetTreeId: String?
    var chopProgress: Double = 0
    /// Potezi piljenja za trenutno deblo (iz stabla).
    var sawTicks: Int?

    var hasWorkerInside: Bool { worker == .inside }
    var isOccupied: Bool { worker != .none }

    init() {}

    enum CodingKeys: String, CodingKey {
        case worker, progress, cyclesCompleted, isOnFire, isClosed, waitingForInput, waitingForStorage, waitingForCandle, pendingOutputs, dropOffId, fetchingInputs, fetchedInputs, haulGood, waitingForTree, targetTreeId, chopProgress, sawTicks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        worker = try c.decodeIfPresent(WorkerPresence.self, forKey: .worker) ?? .none
        progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        cyclesCompleted = try c.decodeIfPresent(Int.self, forKey: .cyclesCompleted) ?? 0
        isOnFire = try c.decodeIfPresent(Bool.self, forKey: .isOnFire) ?? false
        isClosed = try c.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
        waitingForInput = try c.decodeIfPresent(Bool.self, forKey: .waitingForInput) ?? false
        waitingForStorage = try c.decodeIfPresent(Bool.self, forKey: .waitingForStorage) ?? false
        waitingForCandle = try c.decodeIfPresent(Bool.self, forKey: .waitingForCandle) ?? false
        pendingOutputs = try c.decodeIfPresent([Good: Int].self, forKey: .pendingOutputs) ?? [:]
        dropOffId = try c.decodeIfPresent(String.self, forKey: .dropOffId)
        fetchingInputs = try c.decodeIfPresent(Bool.self, forKey: .fetchingInputs) ?? false
        fetchedInputs = try c.decodeIfPresent(Bool.self, forKey: .fetchedInputs) ?? false
        haulGood = try c.decodeIfPresent(Good.self, forKey: .haulGood)
        waitingForTree = try c.decodeIfPresent(Bool.self, forKey: .waitingForTree) ?? false
        targetTreeId = try c.decodeIfPresent(String.self, forKey: .targetTreeId)
        chopProgress = try c.decodeIfPresent(Double.self, forKey: .chopProgress) ?? 0
        sawTicks = try c.decodeIfPresent(Int.self, forKey: .sawTicks)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(worker, forKey: .worker)
        try c.encode(progress, forKey: .progress)
        try c.encode(cyclesCompleted, forKey: .cyclesCompleted)
        try c.encode(isOnFire, forKey: .isOnFire)
        try c.encode(isClosed, forKey: .isClosed)
        try c.encode(waitingForInput, forKey: .waitingForInput)
        try c.encode(waitingForStorage, forKey: .waitingForStorage)
        try c.encode(waitingForCandle, forKey: .waitingForCandle)
        try c.encode(pendingOutputs, forKey: .pendingOutputs)
        try c.encodeIfPresent(dropOffId, forKey: .dropOffId)
        try c.encode(fetchingInputs, forKey: .fetchingInputs)
        try c.encode(fetchedInputs, forKey: .fetchedInputs)
        try c.encodeIfPresent(haulGood, forKey: .haulGood)
        try c.encode(waitingForTree, forKey: .waitingForTree)
        try c.encodeIfPresent(targetTreeId, forKey: .targetTreeId)
        try c.encode(chopProgress, forKey: .chopProgress)
        try c.encodeIfPresent(sawTicks, forKey: .sawTicks)
    }
}

/// Skladišta s ograničenjem. Svaka građevina te vrste dodaje svoj kapacitet.
/// Proizvod ide u svoje skladište, a sirovine za preradu uzimaju se iz njega.
/// Roba koja nije ni u jednom (zlato) nema ograničenje.
/// Unutrašnja mreža smočnice: 6×6 mjesta i 11 u visinu.
enum PantryGrid {
    static let columns = 6
    static let rows = 6
    static let levels = 11
    static let capacity = columns * rows * levels
}

enum StorageKind: String, CaseIterable, Codable {
    /// Oružarnica: oružje i oprema.
    case armory
    /// Smočnica: hrana koja se jede.
    case pantry
    /// Građevina Hrana: samo roba „hrana”, vlastiti kapacitet.
    case foodHall
    /// Skladište (lager): sirovine i međuproizvodi.
    case warehouse
    /// Štala: konji za konjanike.
    case stable

    var buildingId: String {
        switch self {
        case .armory: return Armory.objectId
        case .pantry: return Smocnica.objectId
        case .foodHall: return Food.objectId
        case .warehouse: return Lager.objectId
        case .stable: return Stable.objectId
        }
    }

    var capacityPerBuilding: Int {
        ProductionConfig.storageCapacity(self) ?? builtInCapacity
    }

    private var builtInCapacity: Int {
        switch self {
        case .armory: return 60
        case .pantry: return PantryGrid.capacity
        case .foodHall: return Food.capacity
        case .warehouse: return 400
        case .stable: return 5
        }
    }

    var goods: Set<Good> {
        switch self {
        case .armory: return [.sword, .shield, .bow, .spear, .leather]
        case .pantry: return [.bread, .apple, .hop, .eggs, .honey, .vegetables, .meat, .sausages, .milk, .cheese]
        case .foodHall: return [.food]
        case .warehouse: return [.stone, .wood, .iron, .beer, .wheat, .flour, .corn, .spirits, .wine, .wax, .candle, .grapes, .spices, .flowers, .wool, .hay]
        case .stable: return [.horse]
        }
    }

    var displayName: String {
        switch self {
        case .armory: return "Oružarnica"
        case .pantry: return "Smočnica"
        case .foodHall: return "Hrana"
        case .warehouse: return "Skladište"
        case .stable: return "Štala"
        }
    }

    var unit: String {
        switch self {
        case .armory: return "komada oružja"
        case .pantry: return "mjera hrane"
        case .foodHall: return "mjera hrane"
        case .warehouse: return "komada robe"
        case .stable: return "konja"
        }
    }

    var fullText: String {
        switch self {
        case .armory: return "Oružarnica je puna"
        case .pantry: return "Smočnica je puna"
        case .foodHall: return "Hrana je puna"
        case .warehouse: return "Skladište je puno"
        case .stable: return "Štala je puna"
        }
    }

    var missingText: String {
        switch self {
        case .armory: return "Nema oružarnice"
        case .pantry: return "Nema smočnice"
        case .foodHall: return "Nema građevine za hranu"
        case .warehouse: return "Nema skladišta"
        case .stable: return "Nema štale"
        }
    }

    static func of(_ good: Good) -> StorageKind? {
        allCases.first { $0.goods.contains(good) }
    }

    static func of(buildingId: String) -> StorageKind? {
        allCases.first { $0.buildingId == buildingId }
    }
}

extension GameState {
    /// Radnici igrača (za HUD): seljaci (slobodni) i radnici (imaju posao). Vojnici ne rade.
    var totalWorkers: Int {
        guard let seat = playerSeat else { return 0 }
        return peopleOf(faction: seat.id).filter { $0.role != .soldier }.count
    }

    var assignedWorkers: Int {
        guard let seat = playerSeat else { return 0 }
        return peopleOf(faction: seat.id).filter { $0.role == .worker }.count
    }

    var freeWorkers: Int {
        guard let seat = playerSeat else { return 0 }
        return peopleOf(faction: seat.id).filter { $0.role == .peasant }.count
    }

    var currentSeason: Season { Season.at(turn: currentTurn).season }

    // MARK: - Skladišta

    /// Žive građevine te vrste koje posjeduje frakcija.
    func liveCount(_ objectId: String, of faction: String) -> Int {
        mapLogic.allPlacements.filter {
            $0.placement.objectId == objectId && !$0.placement.isDestroyed && owner(of: $0.placement) == faction
        }.count
    }

    func storageCapacity(_ kind: StorageKind, of faction: String) -> Int {
        liveCount(kind.buildingId, of: faction) * kind.capacityPerBuilding
    }

    func storageStored(_ kind: StorageKind, of faction: String) -> Int {
        kind.goods.reduce(0) { $0 + goodAmount($1, of: faction) }
    }

    /// Koliko robe iz ishoda ide u koje skladište.
    static func storageNeeds(_ outputs: [Good: Int]) -> [StorageKind: Int] {
        var needs: [StorageKind: Int] = [:]
        for (good, amount) in outputs {
            if let kind = StorageKind.of(good) { needs[kind, default: 0] += amount }
        }
        return needs
    }

    /// Skladište za ishod ciklusa koje uopće nije izgrađeno; dok ga nema, ciklus ne počinje.
    func missingStorage(for outputs: [Good: Int], of faction: String) -> StorageKind? {
        Self.storageNeeds(outputs).keys.first { storageCapacity($0, of: faction) == 0 }
    }

    /// Skladište koje nema mjesta za ishod ciklusa; nil = ima mjesta svugdje.
    func fullStorage(for outputs: [Good: Int], of faction: String) -> StorageKind? {
        Self.storageNeeds(outputs).first { storageCapacity($0.key, of: faction) - storageStored($0.key, of: faction) < $0.value }?.key
    }

    // MARK: - Zalihe robe

    func goodAmount(_ good: Good) -> Int {
        switch good {
        case .stone: return resources.stone
        case .wood: return resources.wood
        case .iron: return resources.iron
        case .hop: return resources.hop
        case .beer: return resources.beer
        case .gold: return resources.gold
        case .food: return food
        case .hay: return hay
        default: return goods[good] ?? 0
        }
    }

    func addGood(_ good: Good, _ amount: Int, tracksArrival: Bool = true) {
        guard amount != 0 else { return }
        let before = tracksArrival && FoodRules.isStockFood(good) ? goodAmount(good) : 0
        switch good {
        case .stone: amount > 0 ? resources.add(stone: amount) : resources.subtract(stone: -amount)
        case .wood: amount > 0 ? resources.add(wood: amount) : resources.subtract(wood: -amount)
        case .iron: amount > 0 ? resources.add(iron: amount) : resources.subtract(iron: -amount)
        case .hop: amount > 0 ? resources.add(hop: amount) : resources.subtract(hop: -amount)
        case .beer: amount > 0 ? resources.add(beer: amount) : resources.subtract(beer: -amount)
        case .gold: amount > 0 ? resources.add(gold: amount) : resources.subtract(gold: -amount)
        case .food: food = max(0, food + amount)
        case .hay: hay = max(0, hay + amount)
        default: goods[good] = max(0, (goods[good] ?? 0) + amount)
        }
        if tracksArrival, FoodRules.isStockFood(good), let faction = playerSeat?.id {
            recordFoodArrival(good, goodAmount(good) - before, faction: faction)
        }
    }

    // MARK: - Zdravlje i vatra

    /// Zdravlje u postocima (100 = neoštećeno).
    func healthPercent(_ placement: Placement) -> Int {
        let maxHp = max(1, ObjectHealth.shared.maxHealth(for: placement.objectId))
        return Int((Double(placement.currentHealth) / Double(maxHp) * 100).rounded())
    }

    func isFlammable(_ placement: Placement) -> Bool {
        FlammableCatalog.shared.isFlammable(objectId: placement.objectId)
    }

    /// Zapali građevinu (samo ako je zapaljiva). Radnik bježi van.
    @discardableResult
    func ignite(placementId: String) -> Bool {
        guard let (_, p) = locatePlacement(id: placementId), !p.isDestroyed, isFlammable(p) else { return false }
        var state = buildingStates[placementId] ?? BuildingState()
        state.isOnFire = true
        state.worker = .none
        buildingStates[placementId] = state
        releaseWorker(of: placementId)
        return true
    }

    func extinguish(placementId: String) {
        buildingStates[placementId]?.isOnFire = false
    }

    /// Spavanje: radnik se vraća vatri kao seljak, a novi ne dolazi dok se građevina ne probudi.
    /// Započeti ciklus ostaje i nastavlja se nakon buđenja. Skladište na buđenju ponovno uzme skladištara.
    func setWorkplaceClosed(placementId: String, closed: Bool) {
        var state = buildingStates[placementId] ?? BuildingState()
        state.isClosed = closed
        if closed {
            state.worker = .none
            releaseWorker(of: placementId)
            if editingWarehouseRoute?.storeId == placementId { editingWarehouseRoute = nil }
        }
        buildingStates[placementId] = state
        if !closed,
           let p = locatePlacement(id: placementId)?.placement,
           StorageKind.of(buildingId: p.objectId) != nil,
           !WorkCycleCatalog.isWorkplace(p.objectId) {
            hireWarehouseKeeper(storeId: placementId)
        }
        refreshBuildingAlerts()
        objectWillChange.send()
    }

    /// Farme, industrija, hrana, oružje i skladišta s radnikom / skladištarom.
    func hasSleepButton(for placement: Placement) -> Bool {
        WorkCycleCatalog.isWorkplace(placement.objectId)
            || StorageKind.of(buildingId: placement.objectId) != nil
            || worker(of: placement.id) != nil
    }

    func locatePlacement(id: String) -> (layer: MapLayer, placement: Placement)? {
        if let p = gameMap.placements.first(where: { $0.id == id }) { return (.surface, p) }
        if let p = undergroundMap.placements.first(where: { $0.id == id }) { return (.underground, p) }
        return nil
    }

    // MARK: - Potez

    /// Jedan potez svih građevina: vatra, dolazak radnika, ciklusi proizvodnje.
    func tickBuildings() {
        let all = mapLogic.allPlacements
        let liveIds = Set(all.map(\.placement.id))
        var states = buildingStates.filter { liveIds.contains($0.key) }
        var damaged = false

        for (layer, p) in all where states[p.id]?.isOnFire == true {
            let damage = max(1, FlammableCatalog.shared.fireDamagePerTick(objectId: p.objectId))
            (layer == .surface ? gameMap : undergroundMap).applyDamage(placementId: p.id, amount: damage)
            damaged = true
            if p.currentHealth - damage <= 0 {
                states[p.id] = nil
            }
        }

        let season = currentSeason
        /// Slobodno mjesto po frakciji i vrsti skladišta; računa se prvi put kad zatreba.
        var room: [String: [StorageKind: Int]] = [:]
        func freeRoom(_ faction: String) -> [StorageKind: Int] {
            if let known = room[faction] { return known }
            let fresh = Dictionary(uniqueKeysWithValues: StorageKind.allCases.map {
                ($0, storageCapacity($0, of: faction) - storageStored($0, of: faction))
            })
            room[faction] = fresh
            return fresh
        }

        for (layer, p) in all {
            guard let cycle = WorkCycleCatalog.cycle(for: p.objectId) else { continue }
            var state = states[p.id] ?? BuildingState()
            guard !state.isOnFire, !p.isDestroyed, let faction = owner(of: p) else { continue }
            if p.objectId == Wood.objectId {
                tickWoodcutter(placement: p, layer: layer, cycle: cycle, state: &state, season: season, faction: faction, room: &room)
                states[p.id] = state
                continue
            }

            let person = worker(of: p.id)
            if state.worker != .none, person == nil { state.worker = .none }
            if let person {
                switch person.activity {
                case .working: state.worker = .inside
                case .walkingToWork, .delivering, .fetching, .returningToWork:
                    state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                default: break
                }
            }

            switch state.worker {
            case .none:
                if !state.isClosed, hasPath(to: p, layer: layer), let assigned = assignWorker(to: p) {
                    state.worker = .walking(ticksLeft: ticksUntilArrival(assigned))
                }
            case .walking:
                if !hasPath(to: p, layer: layer) {
                    releaseWorker(of: p.id)
                    state.worker = .none
                } else if let person {
                    state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                }
            case .inside:
                if CandleRules.needsCandle(objectId: p.objectId, layer: layer), !CandleRules.hasCandles(self, faction) {
                    state.waitingForCandle = true
                    break
                }
                state.waitingForCandle = false
                if state.progress == 0 {
                    if cycle.outputs.keys.contains(where: { StorageKind.of($0) != nil }) {
                        let dest = deliveryDestination(for: p, outputs: cycle.outputs, faction: faction)
                        state.waitingForStorage = dest == nil || (dest?.objectId != Carriage.objectId && missingStorage(for: cycle.outputs, of: faction) != nil)
                        if state.waitingForStorage { break }
                    }
                }
                let hasInputs = cycle.inputs.allSatisfy { goodAmount($0.key, of: faction) >= $0.value }
                if state.progress == 0, !state.fetchedInputs, !hasInputs {
                    state.waitingForInput = true
                    break
                }
                if state.progress == 0, !state.fetchedInputs, !cycle.inputs.isEmpty,
                   let store = pickupStore(for: p, inputs: cycle.inputs, faction: faction),
                   let good = cycle.inputs.keys.first(where: { storeSlotExists(storeId: store.id, good: $0) }),
                   let person {
                    state.fetchingInputs = true
                    state.haulGood = good
                    state.dropOffId = store.id
                    sendWorkerToFetch(from: p, to: store, personId: person.id, good: good)
                    state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                    break
                }
                if state.progress == 0, !state.fetchedInputs {
                    for (good, amount) in cycle.inputs { addGood(good, -amount, to: faction) }
                    state.fetchedInputs = true
                }
                state.waitingForInput = false
                state.progress += cycle.kind.seasonFactor(season)
                if state.progress >= Double(cycle.durationTicks) {
                    if cycle.outputs.keys.allSatisfy({ StorageKind.of($0) == nil }) {
                        for (good, amount) in cycle.outputs { addGood(good, amount, to: faction) }
                        state.progress = 0
                        state.fetchedInputs = false
                        state.waitingForStorage = false
                        state.cyclesCompleted += 1
                        break
                    }
                    let needs = Self.storageNeeds(cycle.outputs)
                    let free = freeRoom(faction)
                    guard let dest = deliveryDestination(for: p, outputs: cycle.outputs, faction: faction),
                          let person else {
                        state.progress = Double(cycle.durationTicks)
                        state.waitingForStorage = true
                        break
                    }
                    if dest.objectId == Carriage.objectId {
                        let amount = cycle.outputs.values.reduce(0, +)
                        guard (transportLines[dest.id]?.freeRoom ?? 0) >= amount else {
                            state.progress = Double(cycle.durationTicks)
                            state.waitingForStorage = true
                            break
                        }
                    } else {
                        guard needs.allSatisfy({ $0.value <= free[$0.key, default: 0] }) else {
                            state.progress = Double(cycle.durationTicks)
                            state.waitingForStorage = true
                            break
                        }
                        for (kind, amount) in needs { room[faction]?[kind, default: 0] -= amount }
                    }
                    state.pendingOutputs = cycle.outputs
                    state.haulGood = cycle.outputs.keys.sorted { $0.rawValue < $1.rawValue }.first
                    state.dropOffId = dest.id
                    state.progress = 0
                    state.fetchedInputs = false
                    state.waitingForStorage = false
                    state.cyclesCompleted += 1
                    sendWorkerToDeliver(from: p, to: dest, personId: person.id)
                    state.worker = .walking(ticksLeft: ticksUntilArrival(person))
                }
            }
            states[p.id] = state
        }

        buildingStates = states
        if damaged { bumpPlacementsVersion() }
        refreshBuildingAlerts()
    }
}
