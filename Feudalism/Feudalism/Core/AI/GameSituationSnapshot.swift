//
//  GameSituationSnapshot.swift
//  Feudalism
//
//  Realna situacija u igri – ono što se stvarno dešava. Koristi se da AI:
//  - reagira na trenutno stanje,
//  - predvida budućnost,
//  - ima osnovne postavke (profil) i prema njima se ponaša.
//
//  Igra je isključivo za treniranje i ograđivanje modela. Python koristi isti
//  format (JSON) za treniranje; Swift koristi za inferencu u igri.
//

import Foundation

/// Snapshot realne situacije u igri – serijalizabilan (JSON) za Swift inferencu i Python treniranje.
struct GameSituationSnapshot: Codable {
    /// Potez / vrijeme u igri.
    var turn: Int
    /// Veličina mape (rows × cols).
    var mapRows: Int
    var mapCols: Int
    /// Krajevi – ljudi, vojska, kralj, zalihe po skladištu.
    var realms: [RealmSnapshot]
    /// Postavljeni objekti na karti (koji realm, gdje, što).
    var placements: [PlacementSnapshot]
    /// Ljudi na karti (seljaci, radnici, vojnici, specijalisti) – gdje su i čiji.
    var people: [PersonSnapshot]
    /// Uživo iz igre: tekstualne mape (isti format kao snimanje partije / Python).
    var liveMap: LiveMapSnapshot
    /// Id realm-a koji „gleda” situaciju (AI lord za kojeg donosimo odluku).
    var actingRealmId: String
    /// Opcionalno: kratki digest terena (npr. broj ćelija po tipu) – za manji input u model.
    var terrainSummary: TerrainSummary?

    private enum CodingKeys: String, CodingKey {
        case turn, mapRows, mapCols, realms, placements, people, liveMap, actingRealmId, terrainSummary
    }

    init(
        turn: Int,
        mapRows: Int,
        mapCols: Int,
        realms: [RealmSnapshot],
        placements: [PlacementSnapshot],
        people: [PersonSnapshot],
        liveMap: LiveMapSnapshot,
        actingRealmId: String,
        terrainSummary: TerrainSummary?
    ) {
        self.turn = turn
        self.mapRows = mapRows
        self.mapCols = mapCols
        self.realms = realms
        self.placements = placements
        self.people = people
        self.liveMap = liveMap
        self.actingRealmId = actingRealmId
        self.terrainSummary = terrainSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        turn = try c.decode(Int.self, forKey: .turn)
        mapRows = try c.decode(Int.self, forKey: .mapRows)
        mapCols = try c.decode(Int.self, forKey: .mapCols)
        realms = try c.decode([RealmSnapshot].self, forKey: .realms)
        placements = try c.decode([PlacementSnapshot].self, forKey: .placements)
        people = try c.decodeIfPresent([PersonSnapshot].self, forKey: .people) ?? []
        liveMap = try c.decodeIfPresent(LiveMapSnapshot.self, forKey: .liveMap)
            ?? LiveMapSnapshot(surface: "", underground: "", buildings: "", army: "", blockSize: 1)
        actingRealmId = try c.decode(String.self, forKey: .actingRealmId)
        terrainSummary = try c.decodeIfPresent(TerrainSummary.self, forKey: .terrainSummary)
    }
}

/// Četiri sloja mape kakve AI čita uživo – bez 3D grafike.
struct LiveMapSnapshot: Codable {
    /// Površina: ćelija = površina,visina,prohodnost,gradnja (redovi razmaknuti \n).
    var surface: String
    /// Podzemlje, isti format.
    var underground: String
    /// Građevine (blokovi).
    var buildings: String
    /// Vojska na karti.
    var army: String
    /// Koliko ćelija ulazi u jedan blok na buildings sloju.
    var blockSize: Int
}

struct RealmSnapshot: Codable {
    var id: String
    var name: String
    var isDefeated: Bool
    var lordType: String
    var aiProfileId: String?
    var groupId: String?

    /// Kralj frakcije (sjedište).
    var kingAlive: Bool
    var kingRow: Double
    var kingCol: Double
    var kingHealth: Double
    var castleRow: Double
    var castleCol: Double

    /// Broj ljudi po ulozi.
    var peasants: Int
    var workers: Int
    var soldiers: Int
    var specialists: Int
    var peopleTotal: Int
    /// Vojnici po tipu (npr. "archer": 3).
    var soldiersByType: [String: Int]
    /// Specijalisti po tipu (npr. "miner": 1).
    var specialistsByType: [String: Int]

    /// Sve zalihe frakcije (good id → količina), uključujući zlato.
    var stocks: [String: Int]
    /// Zalihe po vrsti skladišta: warehouse / pantry / armory / foodHall / stable.
    var stocksByStorage: [String: [String: Int]]
    /// Broj živih skladišnih građevina.
    var storageBuildings: [String: Int]

    var happiness: Double
    var taxLevel: Int
}

struct PlacementSnapshot: Codable {
    var id: String
    var objectId: String
    var row: Int
    var col: Int
    var width: Int
    var height: Int
    /// Frakcija koja posjeduje građevinu (RealmSeat.id).
    var realmId: String?
    /// Sloj logičke mape: "surface" ili "underground".
    var layer: String?
    var isClosed: Bool?
    var isOnFire: Bool?
}

struct PersonSnapshot: Codable {
    var id: String
    var factionId: String
    var role: String
    var row: Double
    var col: Double
    var layer: String
    var health: Double
    var soldierType: String?
    var specialistType: String?
}

struct TerrainSummary: Codable {
    var grass: Int
    var water: Int
    var forest: Int
    var mountain: Int
}

// MARK: - Iz živog GameState / GameMap

extension GameSituationSnapshot {
    /// Napravi snapshot realne situacije iz trenutnog stanja igre – za AI reakciju i predikciju.
    static func from(gameState: GameState, actingRealmId: String) -> GameSituationSnapshot {
        let realms = gameState.realmSeats.seats.map { seat in
            realmSnapshot(seat: seat, gameState: gameState)
        }
        // Realmi bez sjedišta (defeated bez seata) – zadrži osnovni zapis.
        let seatIds = Set(gameState.realmSeats.seats.map(\.id))
        let extraRealms = gameState.realms.compactMap { r -> RealmSnapshot? in
            let linked = gameState.realmSeats.seats.contains { $0.id == r.id || $0.realmIds.contains(r.id) }
            guard !linked, !seatIds.contains(r.id) else { return nil }
            return RealmSnapshot(
                id: r.id,
                name: r.name,
                isDefeated: r.isDefeated,
                lordType: r.lordType.rawValue,
                aiProfileId: r.aiProfileId,
                groupId: r.groupId,
                kingAlive: false,
                kingRow: 0,
                kingCol: 0,
                kingHealth: 0,
                castleRow: 0,
                castleCol: 0,
                peasants: 0,
                workers: 0,
                soldiers: 0,
                specialists: 0,
                peopleTotal: 0,
                soldiersByType: [:],
                specialistsByType: [:],
                stocks: [:],
                stocksByStorage: [:],
                storageBuildings: [:],
                happiness: 0,
                taxLevel: 0
            )
        }

        let placements = gameState.mapLogic.allPlacements.map { layer, p in
            let state = gameState.buildingStates[p.id]
            return PlacementSnapshot(
                id: p.id,
                objectId: p.objectId,
                row: p.row,
                col: p.col,
                width: p.width,
                height: p.height,
                realmId: gameState.owner(of: p),
                layer: layer.rawValue,
                isClosed: state?.isClosed,
                isOnFire: state?.isOnFire
            )
        }

        let people = gameState.people.people.map { p in
            PersonSnapshot(
                id: p.id,
                factionId: p.factionId,
                role: p.role.rawValue,
                row: p.row,
                col: p.col,
                layer: p.layer.rawValue,
                health: p.healthPercent,
                soldierType: p.resolvedSoldierType?.id,
                specialistType: p.specialistType?.id
            )
        }

        var terrainSummary: TerrainSummary?
        let cells = gameState.gameMap.cells
        if !cells.isEmpty {
            var g = 0, w = 0, f = 0, m = 0
            for (_, cell) in cells {
                switch cell.terrain {
                case .grass: g += 1
                case .water: w += 1
                case .forest: f += 1
                case .mountain: m += 1
                }
            }
            terrainSummary = TerrainSummary(grass: g, water: w, forest: f, mountain: m)
        }

        let maps = TextMapCapture.captureMaps(from: gameState)
        let liveMap = LiveMapSnapshot(
            surface: maps.main,
            underground: maps.underground,
            buildings: maps.buildings,
            army: maps.army,
            blockSize: TextMapCapture.blockSize(
                rows: gameState.gameMap.rows,
                cols: gameState.gameMap.cols
            )
        )

        return GameSituationSnapshot(
            turn: gameState.currentTurn,
            mapRows: gameState.gameMap.rows,
            mapCols: gameState.gameMap.cols,
            realms: realms + extraRealms,
            placements: placements,
            people: people,
            liveMap: liveMap,
            actingRealmId: actingRealmId,
            terrainSummary: terrainSummary
        )
    }

    private static func realmSnapshot(seat: RealmSeat, gameState: GameState) -> RealmSnapshot {
        let faction = seat.id
        let folks = gameState.peopleOf(faction: faction)
        var soldiersByType: [String: Int] = [:]
        var specialistsByType: [String: Int] = [:]
        var peasants = 0, workers = 0, soldiers = 0, specialists = 0
        for person in folks where person.healthPercent > 0 {
            switch person.role {
            case .peasant:
                peasants += 1
            case .worker:
                workers += 1
            case .soldier:
                soldiers += 1
                let key = person.resolvedSoldierType?.id ?? "soldier"
                soldiersByType[key, default: 0] += 1
            case .specialist:
                specialists += 1
                let key = person.specialistType?.id ?? "specialist"
                specialistsByType[key, default: 0] += 1
            }
        }

        var stocks: [String: Int] = [:]
        var stocksByStorage: [String: [String: Int]] = [:]
        for good in Good.allCases {
            let amount = gameState.goodAmount(good, of: faction)
            guard amount > 0 || good == .gold else { continue }
            stocks[good.rawValue] = amount
            if let kind = StorageKind.of(good) {
                stocksByStorage[kind.rawValue, default: [:]][good.rawValue] = amount
            }
        }
        // Zlato nije u skladištu – ostaje u stocks.

        var storageBuildings: [String: Int] = [:]
        for kind in StorageKind.allCases {
            let count = gameState.mapLogic.allPlacements
                .map(\.placement)
                .filter {
                    $0.objectId == kind.buildingId
                        && !$0.isDestroyed
                        && gameState.owner(of: $0) == faction
                }
                .count
            if count > 0 { storageBuildings[kind.rawValue] = count }
        }

        let realm = gameState.realms.first { seat.realmIds.contains($0.id) || $0.id == seat.id }
        return RealmSnapshot(
            id: seat.id,
            name: seat.displayName,
            isDefeated: realm?.isDefeated ?? !seat.kingAlive,
            lordType: realm?.lordType.rawValue ?? (seat.isPlayerFaction ? "human" : "computer"),
            aiProfileId: realm?.aiProfileId,
            groupId: realm?.groupId,
            kingAlive: seat.kingAlive,
            kingRow: seat.kingRow,
            kingCol: seat.kingCol,
            kingHealth: seat.kingHealthPercent,
            castleRow: seat.castleRow,
            castleCol: seat.castleCol,
            peasants: peasants,
            workers: workers,
            soldiers: soldiers,
            specialists: specialists,
            peopleTotal: peasants + workers + soldiers + specialists,
            soldiersByType: soldiersByType,
            specialistsByType: specialistsByType,
            stocks: stocks,
            stocksByStorage: stocksByStorage,
            storageBuildings: storageBuildings,
            happiness: gameState.happinessPercent(of: faction),
            taxLevel: gameState.taxLevel(of: faction)
        )
    }

    /// JSON za Python (treniranje) ili log – isti format kao u igri.
    func toJSONData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
