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
    /// Faza usjeva na polju (sjetva / rast / berba). Životinje ne koriste.
    var fieldPhase: FieldPhase = .fallow
    /// Mlin: melje pšenicu ili kukuruz u brašno.
    var millGrain: MillGrain = .wheat
    /// Protok izvora (jedinice/potez). Izvor je nepromjenjiv; mijenja se samo protok.
    var springFlow: Double = UndergroundTerrain.defaultSpringFlow

    var hasWorkerInside: Bool { worker == .inside }
    var isOccupied: Bool { worker != .none }

    init() {}

    enum CodingKeys: String, CodingKey {
        case worker, progress, cyclesCompleted, isOnFire, isClosed, waitingForInput, waitingForStorage, waitingForCandle, pendingOutputs, dropOffId, fetchingInputs, fetchedInputs, haulGood, waitingForTree, targetTreeId, chopProgress, sawTicks, fieldPhase, millGrain, springFlow
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
        fieldPhase = try c.decodeIfPresent(FieldPhase.self, forKey: .fieldPhase) ?? .fallow
        millGrain = try c.decodeIfPresent(MillGrain.self, forKey: .millGrain) ?? .wheat
        springFlow = try c.decodeIfPresent(Double.self, forKey: .springFlow) ?? UndergroundTerrain.defaultSpringFlow
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
        try c.encode(fieldPhase, forKey: .fieldPhase)
        try c.encode(millGrain, forKey: .millGrain)
        try c.encode(springFlow, forKey: .springFlow)
    }
}

/// Što mlin melje u brašno.
enum MillGrain: String, Codable, Equatable, CaseIterable {
    case wheat
    case corn

    var input: Good {
        switch self {
        case .wheat: return .wheat
        case .corn: return .corn
        }
    }

    var displayName: String {
        switch self {
        case .wheat: return "Pšenica"
        case .corn: return "Kukuruz"
        }
    }
}

/// Kalendar usjeva na polju (ne za svinju/kravu/ovcu).
enum FieldPhase: String, Codable, Equatable {
    /// Zima / čekanje iduće sjetve.
    case fallow
    /// Proljeće – sije.
    case sowing
    /// Ljeto – usjev raste.
    case growing
    /// Jesen – bere, zatim nosi u skladište.
    case harvesting

    var displayName: String {
        switch self {
        case .fallow: return "Ugar"
        case .sowing: return "Sjetva"
        case .growing: return "Rast"
        case .harvesting: return "Berba"
        }
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
        /// Hrana za jelo — kruh, meso, voće, povrće, jaja… (ne hmelj / brašno / kukuruz).
        case .pantry: return [
            .bread, .apple, .banana, .eggs, .honey, .vegetables, .grapes,
            .meat, .chicken, .sausages, .milk, .cheese
        ]
        case .foodHall: return [.food]
        case .warehouse: return [
            .stone, .wood, .iron, .hop, .beer, .wheat, .flour, .corn, .spirits, .wine,
            .wax, .candle, .spices, .flowers, .wool, .hay
        ]
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
    /// Ciklus građevine; mlin bira pšenicu ili kukuruz prema `millGrain`.
    func workCycle(for placement: Placement, millGrain: MillGrain? = nil) -> WorkCycle? {
        guard let base = WorkCycleCatalog.cycle(for: placement.objectId) else { return nil }
        guard placement.objectId == Windmill.objectId else { return base }
        let grain = millGrain ?? buildingStates[placement.id]?.millGrain ?? .wheat
        let amount = base.inputs.values.first ?? 2
        return WorkCycle(kind: base.kind, durationTicks: base.durationTicks, inputs: [grain.input: amount], outputs: base.outputs)
    }

    func setMillGrain(placementId: String, grain: MillGrain) {
        guard locatePlacement(id: placementId)?.placement.objectId == Windmill.objectId else { return }
        var state = buildingStates[placementId] ?? BuildingState()
        guard state.millGrain != grain else { return }
        state.millGrain = grain
        // Sljedeći ciklus uzima novo zrno; tekući (već uzet ulaz) se ne dira.
        if state.progress == 0, !state.fetchedInputs {
            state.fetchingInputs = false
            state.waitingForInput = false
            state.haulGood = nil
        }
        buildingStates[placementId] = state
        refreshBuildingAlerts()
        objectWillChange.send()
    }

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
        if let kind = Self.storageNeeds(outputs).first(where: { storageCapacity($0.key, of: faction) - storageStored($0.key, of: faction) < $0.value })?.key {
            return kind
        }
        for (good, amount) in outputs where amount > 0 && good != .gold && unitsThatFit(good, adding: 1, faction: faction) == 0 {
            return StorageKind.of(good) ?? .warehouse
        }
        return nil
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
        let accepted: Int = {
            guard amount > 0, good != .gold, let faction = playerSeat?.id else { return amount }
            return unitsThatFit(good, adding: amount, faction: faction)
        }()
        guard accepted != 0 else { return }
        let before = tracksArrival && FoodRules.isStockFood(good) ? goodAmount(good) : 0
        switch good {
        case .stone: accepted > 0 ? resources.add(stone: accepted) : resources.subtract(stone: -accepted)
        case .wood: accepted > 0 ? resources.add(wood: accepted) : resources.subtract(wood: -accepted)
        case .iron: accepted > 0 ? resources.add(iron: accepted) : resources.subtract(iron: -accepted)
        case .hop: accepted > 0 ? resources.add(hop: accepted) : resources.subtract(hop: -accepted)
        case .beer: accepted > 0 ? resources.add(beer: accepted) : resources.subtract(beer: -accepted)
        case .gold: accepted > 0 ? resources.add(gold: accepted) : resources.subtract(gold: -accepted)
        case .food: food = max(0, food + accepted)
        case .hay: hay = max(0, hay + accepted)
        default: goods[good] = max(0, (goods[good] ?? 0) + accepted)
        }
        if tracksArrival, FoodRules.isStockFood(good), let faction = playerSeat?.id {
            recordFoodArrival(good, goodAmount(good) - before, faction: faction)
        }
        if good != .gold, let faction = playerSeat?.id {
            warehouseGoodsEpoch &+= 1
            DispatchQueue.main.async { [weak self] in
                self?.syncLagerBays(of: faction)
            }
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
        let already = buildingStates[placementId]?.isOnFire == true
        var state = buildingStates[placementId] ?? BuildingState()
        state.isOnFire = true
        state.worker = .none
        buildingStates[placementId] = state
        releaseWorker(of: placementId)
        syncFireAmbience(playIgnite: !already)
        return true
    }

    func extinguish(placementId: String) {
        buildingStates[placementId]?.isOnFire = false
        syncFireAmbience()
    }

    /// Barem jedna građevina gori → petlja vatre; inače stani.
    func syncFireAmbience(playIgnite: Bool = false) {
        let burning = buildingStates.values.contains(where: \.isOnFire)
        AudioManager.shared.syncFireAmbience(
            burning: burning && !isGamePaused && !isShowingMainMenu,
            volume: effectiveSoundsVolume,
            playIgnite: playIgnite
        )
    }

    /// Spavanje: radnik se vraća vatri kao seljak, a novi ne dolazi dok se građevina ne probudi.
    /// Započeti ciklus ostaje i nastavlja se nakon buđenja. Skladište na buđenju ponovno uzme skladištara.
    func setWorkplaceClosed(placementId: String, closed: Bool) {
        if let p = locatePlacement(id: placementId)?.placement, p.objectId == Lager.objectId { return }
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

    /// Farme, industrija, hrana, oružje i skladišta s radnikom / skladištarom. Skladište (lager) ne spava.
    func hasSleepButton(for placement: Placement) -> Bool {
        if placement.objectId == Lager.objectId { return false }
        return WorkCycleCatalog.isWorkplace(placement.objectId)
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

        ensureBuildingBirth(for: all.map(\.placement.id))
        let byAge = all.sorted { buildingBirthRank($0.placement.id) < buildingBirthRank($1.placement.id) }
        for (layer, p) in byAge {
            var state = states[p.id] ?? BuildingState()
            guard let cycle = workCycle(for: p, millGrain: state.millGrain) ?? WorkCycleCatalog.cycle(for: p.objectId) else { continue }
            guard !state.isOnFire, !p.isDestroyed, let faction = owner(of: p) else { continue }
            if p.objectId == Wood.objectId {
                tickWoodcutter(placement: p, layer: layer, cycle: cycle, state: &state, season: season, faction: faction, room: &room)
                states[p.id] = state
                continue
            }
            if cycle.kind == .field {
                tickFieldFarm(placement: p, layer: layer, cycle: cycle, state: &state, season: season, faction: faction, room: &room)
                states[p.id] = state
                continue
            }

            let needed = workersRequired(for: p.objectId)
            let producersNeeded = producersRequired(for: p.objectId)
            var crew = workers(of: p.id)
            if !state.isClosed, hasPath(to: p, layer: layer) {
                while crew.count < needed, let assigned = assignWorker(to: p) {
                    crew.append(assigned)
                }
            }
            if !hasPath(to: p, layer: layer), !crew.isEmpty {
                releaseWorker(of: p.id)
                crew = []
            }
            let inside = crew.filter {
                if case .working = $0.activity { return true }
                return false
            }
            let enRoute = crew.filter {
                switch $0.activity {
                case .walkingToWork, .delivering, .fetching, .returningToWork,
                     .walkingToTree, .chopping, .haulingLog, .walkingToField, .workingField:
                    return true
                default: return false
                }
            }
            if crew.isEmpty {
                state.worker = .none
            } else if inside.count >= producersNeeded {
                state.worker = .inside
            } else if let walker = enRoute.first {
                state.worker = .walking(ticksLeft: ticksUntilArrival(walker))
            } else if !inside.isEmpty {
                state.worker = .inside
            } else {
                state.worker = .none
            }

            // Proizvodnja ide kad je proizvođač unutra; kurir smije biti na putu.
            guard inside.count >= producersNeeded else {
                states[p.id] = state
                continue
            }
            if CandleRules.needsCandle(objectId: p.objectId, layer: layer), !CandleRules.hasCandles(self, faction) {
                state.waitingForCandle = true
                states[p.id] = state
                continue
            }
            state.waitingForCandle = false
            // Kurir još nije vratio sirovinu — ne troši i ne melje.
            if state.fetchingInputs {
                states[p.id] = state
                continue
            }
            if state.progress == 0, state.pendingOutputs.isEmpty {
                if cycle.outputs.keys.contains(where: { StorageKind.of($0) != nil }) {
                    let dest = deliveryDestination(for: p, outputs: cycle.outputs, faction: faction)
                    state.waitingForStorage = dest == nil || (dest?.objectId != Carriage.objectId && missingStorage(for: cycle.outputs, of: faction) != nil)
                    if state.waitingForStorage {
                        states[p.id] = state
                        continue
                    }
                }
            }
            let hasInputs = cycle.inputs.allSatisfy { goodAmount($0.key, of: faction) >= $0.value }
            if state.progress == 0, !state.fetchedInputs, !hasInputs {
                state.waitingForInput = true
                states[p.id] = state
                continue
            }
            let needsPickup = state.progress == 0 && !state.fetchedInputs && !cycle.inputs.isEmpty
                && pickupStore(for: p, inputs: cycle.inputs, faction: faction) != nil
            if needsPickup,
               let store = pickupStore(for: p, inputs: cycle.inputs, faction: faction),
               let good = cycle.inputs.keys.first(where: { storeSlotExists(storeId: store.id, good: $0) }) {
                guard let courier = pickCourier(of: p.id, keepInside: producersNeeded) else {
                    // Čekaj slobodnog kurira (ne šalji jedinog proizvođača).
                    states[p.id] = state
                    continue
                }
                state.fetchingInputs = true
                state.haulGood = good
                state.dropOffId = store.id
                sendWorkerToFetch(from: p, to: store, personId: courier.id, good: good)
                state.worker = .walking(ticksLeft: ticksUntilArrival(courier))
                states[p.id] = state
                continue
            }
            if state.progress == 0, !state.fetchedInputs {
                for (good, amount) in cycle.inputs { addGood(good, -amount, to: faction) }
                state.fetchedInputs = true
            }
            state.waitingForInput = false
            // Gotov ciklus čeka kurira s prethodnim tovarom — ne kreni novi output preko starog.
            if state.progress >= Double(cycle.durationTicks), !state.pendingOutputs.isEmpty {
                state.progress = Double(cycle.durationTicks)
                states[p.id] = state
                continue
            }
            state.progress += cycle.kind.seasonFactor(season)
            if state.progress >= Double(cycle.durationTicks) {
                if cycle.outputs.keys.allSatisfy({ StorageKind.of($0) == nil }) {
                    for (good, amount) in cycle.outputs { addGood(good, amount, to: faction) }
                    state.progress = 0
                    state.fetchedInputs = false
                    state.waitingForStorage = false
                    state.cyclesCompleted += 1
                } else {
                    let needs = Self.storageNeeds(cycle.outputs)
                    let free = freeRoom(faction)
                    let dest = deliveryDestination(for: p, outputs: cycle.outputs, faction: faction)
                    let courier = pickCourier(of: p.id, keepInside: producersNeeded)
                    if let dest {
                        let canDeliver: Bool
                        if dest.objectId == Carriage.objectId {
                            let amount = cycle.outputs.values.reduce(0, +)
                            canDeliver = (transportLines[dest.id]?.freeRoom ?? 0) >= amount
                        } else {
                            canDeliver = needs.allSatisfy { $0.value <= free[$0.key, default: 0] }
                            if canDeliver {
                                for (kind, amount) in needs { room[faction]?[kind, default: 0] -= amount }
                            }
                        }
                        if canDeliver, let courier {
                            state.pendingOutputs = cycle.outputs
                            state.haulGood = cycle.outputs.keys.sorted { $0.rawValue < $1.rawValue }.first
                            state.dropOffId = dest.id
                            state.progress = 0
                            state.fetchedInputs = false
                            state.waitingForStorage = false
                            state.cyclesCompleted += 1
                            sendWorkerToDeliver(from: p, to: dest, personId: courier.id)
                            state.worker = .walking(ticksLeft: ticksUntilArrival(courier))
                        } else if canDeliver {
                            // Proizvod gotov, kurir još na putu — drži ciklus dok se ne vrati.
                            state.progress = Double(cycle.durationTicks)
                            state.waitingForStorage = false
                        } else {
                            state.progress = Double(cycle.durationTicks)
                            state.waitingForStorage = true
                        }
                    } else {
                        state.progress = Double(cycle.durationTicks)
                        state.waitingForStorage = true
                    }
                }
            }
            states[p.id] = state
        }

        buildingStates = states
        if damaged { bumpPlacementsVersion() }
        refreshBuildingAlerts()
        if damaged { syncFireAmbience() }
    }
}
