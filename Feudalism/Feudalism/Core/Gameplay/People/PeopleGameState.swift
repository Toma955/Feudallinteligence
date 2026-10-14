//
//  PeopleGameState.swift
//  Feudalism
//
//  Osobe u partiji: na početku seljaci stoje oko vatre ispred dvorca. Kuće dovode nove.
//  Radno mjesto uzima seljaka (postaje radnik), Trening ga s oružjem pretvara u vojnika.
//

import Foundation

extension GameState {
    /// Dvorac bez kuća prima toliko ljudi; na početku partije dolaze jedan po jedan.
    static let baseCapacity = 10
    static let peoplePerHouse = 10
    /// Najviše slobodnih seljaka uz vatru; ostali čekaju dok netko ne ode na posao.
    static let maxAtFire = 24
    /// Razmak između seljaka na krugu oko vatre (metri / ćelije).
    static let firePersonSpacing = 0.95
    /// Najmanji krug – da i prvih par ljudi ima mjesta.
    static let fireMinSlots = 8
    /// Jedan novi seljak svakih 30 poteza. 1 potez = 1 s.
    static let immigrationEveryTicks = 30

    var playerSeat: RealmSeat? {
        realmSeats.seats.first(where: \.isPlayerFaction) ?? realmSeats.seats.first
    }

    /// Živi ljudi frakcije koji su još u dvorcu (bez onih koji odlaze).
    func peopleOf(faction: String) -> [Person] {
        people.people.filter { $0.factionId == faction && $0.healthPercent > 0 && $0.activity != .leaving }
    }

    // MARK: - Mjesta oko vatre i postroj

    func hearthCell(of seat: RealmSeat) -> (row: Double, col: Double) {
        let front = GatheringHearth.frontOffset(footprintMeters: MapScale.meters(ObjectDimensions.castle.cellHeight)) / MapScale.worldUnitsPerMapCell
        return (seat.castleRow - Double(front), seat.castleCol)
    }

    /// Koliko mjesta treba oko vatre: kapacitet, ali ne više od 24 i ne manje od 8.
    func gatheringSlots(of faction: String) -> Int {
        min(Self.maxAtFire, max(Self.fireMinSlots, populationCapacity(of: faction)))
    }

    func gatheringRadius(of faction: String) -> Double {
        let n = gatheringSlots(of: faction)
        return max(1.55, Double(n) * Self.firePersonSpacing / (2 * .pi))
    }

    private func fireSlotPosition(seat: RealmSeat, slot: Int) -> (row: Double, col: Double) {
        let perRing = gatheringSlots(of: seat.id)
        let base = gatheringRadius(of: seat.id)
        let ring = slot / perRing
        let index = slot % perRing
        let radius = base + Double(ring) * 0.85
        let angle = (Double(index) + (ring % 2 == 0 ? 0 : 0.5)) / Double(perRing) * 2 * .pi
        let hearth = hearthCell(of: seat)
        return (hearth.row + sin(angle) * radius, hearth.col + cos(angle) * radius)
    }

    /// Kad se kapacitet promijeni, seljaci se rasporede na novi krug.
    func refreshFireCircle(of seat: RealmSeat) {
        var slot = 0
        for person in peopleOf(faction: seat.id) where person.role == .peasant {
            switch person.activity {
            case .atFire, .returningToFire:
                let pos = fireSlotPosition(seat: seat, slot: slot)
                let index = slot
                let here = hypot(person.row - pos.row, person.col - pos.col)
                let aim = hypot(person.targetRow - pos.row, person.targetCol - pos.col)
                if person.slot != index || here > 0.2 || aim > 0.2 {
                    people.update(id: person.id) {
                        $0.slot = index
                        $0.targetRow = pos.row
                        $0.targetCol = pos.col
                        if $0.activity == .atFire {
                            $0.row = pos.row
                            $0.col = pos.col
                            $0.facing = facingHearth($0, seat: seat)
                        }
                    }
                }
                slot += 1
            default:
                break
            }
        }
    }

    /// Vojnici stoje u postroju sa strane dvorca suprotne od vatre.
    private func rallySlotPosition(seat: RealmSeat, slot: Int) -> (row: Double, col: Double) {
        let front = seat.castleRow - hearthCell(of: seat).row
        return (seat.castleRow + front + 1 + Double(slot / 6), seat.castleCol - 2.5 + Double(slot % 6))
    }

    private func freeSlot(faction: String, soldiers: Bool) -> Int {
        let used = Set(peopleOf(faction: faction).filter { soldiers ? $0.role == .soldier : $0.role == .peasant }.map(\.slot))
        return (0...).first { !used.contains($0) } ?? 0
    }

    private func facingHearth(_ person: Person, seat: RealmSeat) -> Double {
        let hearth = hearthCell(of: seat)
        return atan2(hearth.col - person.col, hearth.row - person.row)
    }

    // MARK: - Stvaranje

    /// Na početku partije nema ljudi; prsten iznad vatre dovodi ih do kapaciteta. Zalihe su iste za sve.
    func spawnStartingPeople() {
        people.reset()
        oxen.reset()
        seedFactionStocks()
        resetHappinessForNewMatch()
        resetRelations()
        populationProgress = [:]
        populationRing.reset()
        presentOpeningPopulationRing()
        bindMatchRuntimes()
        if showsGraphics, !isGamePaused {
            people.startTimer()
            oxen.startTimer()
        }
        refreshPeopleCount()
    }

    /// Poveži hod i volove s mapom. Mora se zvati i nakon učitavanja partije.
    func bindMatchRuntimes() {
        people.onArrive = { [weak self] person in self?.personArrived(person) }
        people.findPath = { [weak self] person, from, to in
            guard let self else { return [to] }
            if let job = person.activity.jobPlacementId,
               let haul = self.buildingStates[job]?.haulGood,
               let storeId = self.buildingStates[job]?.dropOffId,
               let routed = self.warehousePath(workplaceId: job, storeId: storeId, good: haul, from: from, to: to) {
                return routed
            }
            return self.pathFinder.path(
                in: self.mapLogic,
                from: from,
                to: to,
                useUnderground: CandleRules.hasCandles(self, person.factionId)
            )
        }
        oxen.routeOf = { [weak self] depotId in self?.transportLines[depotId]?.corners ?? [] }
        oxen.onUnload = { [weak self] cart in
            guard let self, let faction = self.locatePlacement(id: cart.depotId).flatMap({ self.owner(of: $0.placement) }) else { return true }
            var leftover: [Good: Int] = [:]
            for (good, amount) in cart.cargo {
                if let kind = StorageKind.of(good) {
                    let free = self.storageCapacity(kind, of: faction) - self.storageStored(kind, of: faction)
                    let take = min(amount, max(0, free))
                    if take > 0 { self.addGood(good, take, to: faction) }
                    if amount > take { leftover[good] = amount - take }
                } else {
                    self.addGood(good, amount, to: faction)
                }
            }
            cart.cargo = leftover
            return leftover.isEmpty
        }
    }

    /// Novi seljak dolazi izdaleka i staje uz vatru.
    func immigrate(seat: RealmSeat) {
        let slot = freeSlot(faction: seat.id, soldiers: false)
        let pos = fireSlotPosition(seat: seat, slot: slot)
        let outward = atan2(pos.row - hearthCell(of: seat).row, pos.col - hearthCell(of: seat).col)
        let startRow = min(max(1, pos.row + sin(outward) * 2), Double(gameMap.rows - 2))
        let startCol = min(max(1, pos.col + cos(outward) * 2), Double(gameMap.cols - 2))
        people.add(Person(id: UUID().uuidString, factionId: seat.id, colorHex: seat.colorHex, role: .peasant, activity: .returningToFire,
                          row: startRow, col: startCol, targetRow: pos.row, targetCol: pos.col, slot: slot))
        refreshPeopleCount()
    }

    /// Koliko ljudi jedna kuća dodaje. Broj piše u bilježnici AI lordova.
    var peopleAddedPerHouse: Int {
        let written = AILordProfileStore.shared.notebook.peoplePerHouse
        return written > 0 ? written : Self.peoplePerHouse
    }

    /// Koliko ljudi frakcija može imati: dvorac + zapis iz bilježnice po kući.
    func populationCapacity(of faction: String) -> Int {
        Self.baseCapacity + liveCount(House.objectId, of: faction) * peopleAddedPerHouse
    }

    func peasantsAtFire(of faction: String) -> Int {
        peopleOf(faction: faction).filter { $0.role == .peasant }.count
    }

    var populationCapacity: Int {
        playerSeat.map { populationCapacity(of: $0.id) } ?? Self.baseCapacity
    }

    // MARK: - Posao

    private func personArrived(_ person: Person) {
        switch person.activity {
        case .working(let placementId):
            buildingStates[placementId]?.worker = .inside
        case .delivering(let fromId, let toId):
            depositDelivery(from: fromId, to: toId, personId: person.id)
        case .fetching(let fromId, let storeId):
            finishFetch(from: fromId, storeId: storeId, personId: person.id)
        case .returningToWork(let placementId):
            people.update(id: person.id) { $0.activity = .working(placementId: placementId) }
            buildingStates[placementId]?.worker = .inside
        case .workingField(let placementId, _):
            buildingStates[placementId]?.worker = .walking(ticksLeft: 1)
        case .atFire:
            guard let seat = realmSeats.seats.first(where: { $0.id == person.factionId }) else { return }
            people.update(id: person.id) { $0.facing = facingHearth($0, seat: seat) }
        case .leaving:
            people.remove(id: person.id)
            refreshPeopleCount()
        default:
            break
        }
    }

    /// Ulaz u građevinu: rub tlocrta najbliži vatri.
    func entrance(of placement: Placement, from hearth: (row: Double, col: Double)) -> (row: Double, col: Double) {
        let row = min(max(hearth.row, Double(placement.row) - 1), Double(placement.row + placement.height))
        let col = min(max(hearth.col, Double(placement.col) - 0.5), Double(placement.col + placement.width) - 0.5)
        return (row, col)
    }

    /// Najbliži slobodni seljak vlasnika dobiva posao. Od tog trenutka je radnik i ne može se označiti.
    func assignWorker(to placement: Placement) -> Person? {
        guard let faction = owner(of: placement), let seat = seat(of: faction) else { return nil }
        let target = entrance(of: placement, from: hearthCell(of: seat))
        let idle = peopleOf(faction: seat.id).filter { $0.role == .peasant }
        guard let person = idle.min(by: { hypot($0.row - target.row, $0.col - target.col) < hypot($1.row - target.row, $1.col - target.col) }) else { return nil }
        let destLayer = locatePlacement(id: placement.id)?.layer ?? .surface
        people.update(id: person.id) {
            $0.role = .worker
            $0.activity = .walkingToWork(placementId: placement.id)
            $0.targetRow = target.row
            $0.targetCol = target.col
            $0.targetLayer = destLayer
        }
        return people.person(id: person.id)
    }

    /// Radnik napušta posao i vraća se vatri kao seljak.
    func releaseWorker(of placementId: String) {
        for person in people.people where person.activity.jobPlacementId == placementId {
            guard let seat = realmSeats.seats.first(where: { $0.id == person.factionId }) else { continue }
            let slot = freeSlot(faction: seat.id, soldiers: false)
            let pos = fireSlotPosition(seat: seat, slot: slot)
            people.update(id: person.id) {
                $0.role = .peasant
                $0.slot = slot
                $0.activity = .returningToFire
                $0.targetRow = pos.row
                $0.targetCol = pos.col
                $0.targetLayer = .surface
            }
        }
    }

    func worker(of placementId: String) -> Person? {
        workers(of: placementId).first
    }

    /// Svi radnici dodijeljeni toj građevini.
    func workers(of placementId: String) -> [Person] {
        people.people.filter { $0.activity.jobPlacementId == placementId }
    }

    /// Radnik koji je unutra (za dostavu / dohvat).
    func workerInside(of placementId: String) -> Person? {
        workersInside(of: placementId).first
    }

    func workersInside(of placementId: String) -> [Person] {
        workers(of: placementId).filter {
            if case .working = $0.activity { return true }
            return false
        }
    }

    /// Kurir za dohvat/dostavu — ostavlja barem `keepInside` proizvođača u zgradi.
    func pickCourier(of placementId: String, keepInside: Int) -> Person? {
        let inside = workersInside(of: placementId)
        guard inside.count > keepInside else { return nil }
        return inside.last
    }

    /// Koliko radnika treba ova građevina (bilježnica building_workers.json).
    func workersRequired(for objectId: String) -> Int {
        BuildingWorkersNotebook.required(for: objectId)
    }

    /// Koliko mora biti unutra da ciklus proizvodi (kurir ne broji).
    func producersRequired(for objectId: String) -> Int {
        BuildingWorkersNotebook.producersRequired(for: objectId)
    }

    /// Potezi do dolaska radnika.
    func ticksUntilArrival(_ person: Person) -> Int {
        max(1, Int((hypot(person.targetRow - person.row, person.targetCol - person.col) / PeopleRuntime.speedCellsPerSecond).rounded(.up)))
    }

    // MARK: - Vojska

    func hasTrainingGround(of faction: String) -> Bool {
        liveCount(Training.objectId, of: faction) > 0
    }

    var hasTrainingGround: Bool {
        playerSeat.map { hasTrainingGround(of: $0.id) } ?? false
    }

    /// Trening frakcije najbliži njezinoj vatri.
    func trainingGround(of faction: String) -> Placement? {
        guard let seat = seat(of: faction) else { return nil }
        let hearth = hearthCell(of: seat)
        return mapLogic.allPlacements
            .map(\.placement)
            .filter { $0.objectId == Training.objectId && !$0.isDestroyed && owner(of: $0) == faction }
            .min { hypot(Double($0.row) - hearth.row, Double($0.col) - hearth.col) < hypot(Double($1.row) - hearth.row, Double($1.col) - hearth.col) }
    }

    func freePeasants(of faction: String) -> Int {
        peopleOf(faction: faction).filter { $0.role == .peasant }.count
    }

    /// Što fali za obuku; nil = može se obučiti.
    func trainingProblem(_ type: SoldierType, faction: String) -> String? {
        if trainingGround(of: faction) == nil { return "Treba Trening." }
        let price = PriceList.soldierPrice(type)
        if let lack = missing(for: price, faction: faction) { return "Nedostaje \(lack)." }
        if freePeasants(of: faction) == 0 { return "Nema slobodnog seljaka." }
        return nil
    }

    /// Slobodni seljak + oprema iz oružarnice + zlato → vojnik. Pojavi se ispred Treninga
    /// i ode u postroj. Bez frakcije trenira igrač. Vraća poruku zašto ne, ili nil kad uspije.
    @discardableResult
    func trainSoldier(_ type: SoldierType, faction: String? = nil) -> String? {
        guard let seat = faction.flatMap({ seat(of: $0) }) ?? playerSeat else { return "Nema dvorca." }
        if let problem = trainingProblem(type, faction: seat.id) { return problem }
        guard let ground = trainingGround(of: seat.id),
              let peasant = peopleOf(faction: seat.id).first(where: { $0.role == .peasant && $0.activity == .atFire })
                ?? peopleOf(faction: seat.id).first(where: { $0.role == .peasant }) else {
            return "Nema slobodnog seljaka."
        }
        pay(PriceList.soldierPrice(type), faction: seat.id)
        let slot = freeSlot(faction: seat.id, soldiers: true)
        let pos = rallySlotPosition(seat: seat, slot: slot)
        let exitRow = Double(ground.row + ground.height) + 0.5
        let exitCol = Double(ground.col) + Double(ground.width) / 2 - 0.5 + Double(slot % 3) - 1
        people.update(id: peasant.id) {
            $0.role = .soldier
            $0.soldierType = type
            $0.weapon = type.mainWeapon
            $0.healthPercent = 100
            $0.row = exitRow
            $0.col = exitCol
            $0.slot = slot
            $0.activity = .soldierMoving
            $0.targetRow = pos.row
            $0.targetCol = pos.col
            $0.targetLayer = .surface
        }
        return nil
    }

    /// Rudari / Inženjering najbliži vatri frakcije.
    func specialistBuilding(_ type: SpecialistType, of faction: String) -> Placement? {
        guard let seat = seat(of: faction) else { return nil }
        let hearth = hearthCell(of: seat)
        return mapLogic.allPlacements
            .map(\.placement)
            .filter { $0.objectId == type.buildingObjectId && !$0.isDestroyed && owner(of: $0) == faction }
            .min { hypot(Double($0.row) - hearth.row, Double($0.col) - hearth.col) < hypot(Double($1.row) - hearth.row, Double($1.col) - hearth.col) }
    }

    /// Što fali za obuku specijalista; nil = može se obučiti.
    func specialistTrainingProblem(_ type: SpecialistType, faction: String) -> String? {
        if specialistBuilding(type, of: faction) == nil {
            return type == .miner ? "Treba Rudari." : "Treba Inženjering."
        }
        let price = PriceList.specialistPrice(type)
        if let lack = missing(for: price, faction: faction) { return "Nedostaje \(lack)." }
        if freePeasants(of: faction) == 0 { return "Nema slobodnog seljaka." }
        return nil
    }

    /// Slobodni seljak + zlato → rudar / inženjer. Pojavi se ispred građevine i vrati se vatri.
    @discardableResult
    func trainSpecialist(_ type: SpecialistType, faction: String? = nil) -> String? {
        guard let seat = faction.flatMap({ seat(of: $0) }) ?? playerSeat else { return "Nema dvorca." }
        if let problem = specialistTrainingProblem(type, faction: seat.id) { return problem }
        guard let ground = specialistBuilding(type, of: seat.id),
              let peasant = peopleOf(faction: seat.id).first(where: { $0.role == .peasant && $0.activity == .atFire })
                ?? peopleOf(faction: seat.id).first(where: { $0.role == .peasant }) else {
            return "Nema slobodnog seljaka."
        }
        pay(PriceList.specialistPrice(type), faction: seat.id)
        let slot = freeSlot(faction: seat.id, soldiers: false)
        let hearth = hearthCell(of: seat)
        let exitRow = Double(ground.row + ground.height) + 0.5
        let exitCol = Double(ground.col) + Double(ground.width) / 2 - 0.5
        people.update(id: peasant.id) {
            $0.role = .specialist
            $0.specialistType = type
            $0.soldierType = nil
            $0.weapon = nil
            $0.healthPercent = 100
            $0.row = exitRow
            $0.col = exitCol
            $0.slot = slot
            $0.activity = .returningToFire
            $0.targetRow = hearth.row
            $0.targetCol = hearth.col
            $0.targetLayer = .surface
        }
        return nil
    }

    /// Označeni vojnici unutar kvadrata. Seljak kod vatre i radnik se ne hvataju.
    func soldiers(inside mark: GroundMark) -> [MarkedPerson] {
        people(inside: mark, factionId: playerSeat?.id)
    }

    /// Ljudi (vojska / specijalisti / kralj) frakcije unutar oznake.
    func people(inside mark: GroundMark, factionId: String?) -> [MarkedPerson] {
        guard let factionId else { return [] }
        let minRow = Double(min(mark.originRow, mark.farRow)) - 0.5
        let maxRow = Double(max(mark.originRow, mark.farRow)) + 0.5
        let minCol = Double(min(mark.originCol, mark.farCol)) - 0.5
        let maxCol = Double(max(mark.originCol, mark.farCol)) + 0.5
        var marked: [MarkedPerson] = []
        if let seat = seat(of: factionId), seat.kingAlive, king(inside: mark, seat: seat) {
            marked.append(MarkedPerson(id: MarkedPerson.kingId(seat.id), name: "Kralj", colorHex: seat.colorHex))
        }
        let viewLayer: MapLayer = isUndergroundView ? .underground : .surface
        for p in people.people where p.canBeMarked && p.factionId == factionId && p.layer == viewLayer
            && p.row >= minRow && p.row <= maxRow && p.col >= minCol && p.col <= maxCol {
            marked.append(MarkedPerson(id: p.id, name: p.displayName, colorHex: p.colorHex))
        }
        return marked
    }

    // MARK: - Potez

    /// Označeni (kralj / vojska / specijalisti) idu na cilj i stanu oko tog polja.
    func sendMarkedSoldiers(row: Int, col: Int, layer: MapLayer? = nil) {
        let count = markedPeople.count
        sendArmy(markedPeople, factionId: playerSeat?.id, row: row, col: col, layer: layer)
        if !isMapEditorMode, count > 0 {
            LivePartyLog.shared.noteArmy(
                from: self,
                action: "poslao \(count) jedinica",
                row: row,
                col: col
            )
        }
    }

    /// Pošalji danu skupinu jedinica frakcije na (row, col).
    func sendArmy(
        _ marked: [MarkedPerson],
        factionId: String?,
        row: Int,
        col: Int,
        layer: MapLayer? = nil
    ) {
        let destLayer = layer ?? {
            if isUndergroundView { return .underground }
            if undergroundEntrance(row: row, col: col) != nil { return .underground }
            return .surface
        }()

        enum Mover {
            case king(String)
            case person(String)
        }
        var movers: [Mover] = []
        for person in marked {
            if person.isKing {
                movers.append(.king(factionId ?? playerSeat?.id ?? ""))
            } else if people.person(id: person.id)?.canBeMarked == true {
                movers.append(.person(person.id))
            }
        }
        guard !movers.isEmpty else { return }

        if destLayer == .underground, let faction = factionId ?? playerSeat?.id, !CandleRules.hasCandles(self, faction) {
            placementError = "Hodnici rade samo sa svijećom (košnica → vosak → svijeća)."
        }

        if factionId == nil || factionId == playerSeat?.id {
            moveOrderMarker = MoveOrderMarker(row: row, col: col, layer: destLayer)
        }

        let slots = gatherFormationSlots(count: movers.count, centerRow: row, centerCol: col)
        for (index, mover) in movers.enumerated() {
            let slot = slots[min(index, slots.count - 1)]
            switch mover {
            case .king(let fid):
                let targetRow = Int(slot.row.rounded())
                let targetCol = Int(slot.col.rounded())
                if fid.isEmpty || fid == playerSeat?.id {
                    movePlayerKing(toRow: targetRow, col: targetCol)
                } else {
                    moveKing(factionId: fid, toRow: targetRow, col: targetCol)
                }
            case .person(let id):
                people.update(id: id) {
                    $0.activity = .soldierMoving
                    $0.targetRow = slot.row
                    $0.targetCol = slot.col
                    $0.targetLayer = destLayer
                    $0.pathTarget = nil
                }
            }
        }
    }

    /// Makni ciljnu točku kad nitko više ne ide prema njoj.
    func clearMoveOrderMarkerIfSettled() {
        guard moveOrderMarker != nil else { return }
        let someoneMoving = markedPeople.contains { marked in
            if marked.isKing {
                guard let seat = playerSeat else { return false }
                return abs(seat.kingRow - Double(seat.destinationRow)) > 0.15
                    || abs(seat.kingCol - Double(seat.destinationCol)) > 0.15
            }
            guard let person = people.person(id: marked.id) else { return false }
            if case .soldierMoving = person.activity { return true }
            return false
        }
        if !someoneMoving {
            moveOrderMarker = nil
        }
    }

    /// Raspored oko ciljnog polja: prvo središte, zatim prstenovi (1 po ćeliji).
    private func gatherFormationSlots(count: Int, centerRow: Int, centerCol: Int) -> [(row: Double, col: Double)] {
        guard count > 0 else { return [] }
        var slots: [(row: Double, col: Double)] = []
        var radius = 0
        while slots.count < count, radius <= 24 {
            if radius == 0 {
                if isGatherCellFree(row: centerRow, col: centerCol) {
                    slots.append((Double(centerRow), Double(centerCol)))
                }
            } else {
                for dr in -radius...radius {
                    for dc in -radius...radius {
                        guard max(abs(dr), abs(dc)) == radius else { continue }
                        let r = centerRow + dr
                        let c = centerCol + dc
                        guard isGatherCellFree(row: r, col: c) else { continue }
                        slots.append((Double(r), Double(c)))
                        if slots.count >= count { break }
                    }
                    if slots.count >= count { break }
                }
            }
            radius += 1
        }
        // Fallback: ako je sve blokirano, svi na cilj.
        while slots.count < count {
            slots.append((Double(centerRow), Double(centerCol)))
        }
        return slots
    }

    private func isGatherCellFree(row: Int, col: Int) -> Bool {
        guard gameMap.isValid(MapCoordinate(row: row, col: col)),
              let cell = gameMap.cell(row: row, col: col) else { return false }
        switch cell.povrsina {
        case .more, .voda, .mocvara: return false
        default: break
        }
        if let placement = activeMap.placement(at: MapCoordinate(row: row, col: col)),
           Passage.blocks(objectId: placement.objectId) {
            return false
        }
        return true
    }

    func tickPeople() {
        var candleKey = 0
        for seat in realmSeats.seats {
            candleKey = candleKey &* 31 &+ (CandleRules.hasCandles(self, seat.id) ? 1 : 0)
        }
        let version = ObjectIdentifier(mapLogic).hashValue &+ candleKey
        if people.mapVersion != version { people.mapVersion = version }
        if !showsGraphics {
            people.advance(dt: 1)
            oxen.advance(dt: 1)
        }
        let live = Set(mapLogic.allPlacements.map(\.placement.id))
        for person in people.people {
            guard let job = person.activity.jobPlacementId else { continue }
            let state = buildingStates[job]
            if !live.contains(job) || state?.isClosed == true || state?.isOnFire == true {
                releaseWorker(of: job)
                buildingStates[job]?.worker = .none
            }
        }
        tickPopulationFlow()
        refreshCastleEnclosure()
        clearMoveOrderMarkerIfSettled()
    }
}
