//
//  Person.swift
//  Feudalism
//
//  Osoba – temelj ekonomije i vojske. Tri uloge:
//  - seljak: bez posla, stoji oko vatre ispred dvorca,
//  - radnik: ima posao u građevini (ide prema njoj ili je unutra),
//  - vojnik: obučen s oružjem.
//  Označiti se može samo vojnik.
//

import Foundation

enum PersonRole: String, Codable, CaseIterable {
    case peasant
    case worker
    case soldier

    var displayName: String {
        switch self {
        case .peasant: return "Seljak"
        case .worker: return "Radnik"
        case .soldier: return "Vojnik"
        }
    }
}

enum PersonActivity: Codable, Equatable {
    /// Seljak stoji na svom mjestu oko vatre.
    case atFire
    case returningToFire
    case walkingToWork(placementId: String)
    /// Unutra u građevini – ne vidi se na mapi.
    case working(placementId: String)
    /// Nosi proizvode do skladišta ili prijevoza.
    case delivering(fromId: String, toId: String)
    case fetching(fromId: String, storeId: String)
    case returningToWork(placementId: String)
    /// Sječar ide od kućice do stabla.
    case walkingToTree(hutId: String, treeId: String)
    /// Sječe stablo (stoji uz njega).
    case chopping(hutId: String, treeId: String)
    /// Nosi deblo natrag u kućicu.
    case haulingLog(hutId: String, treeId: String)
    case soldierMoving
    case soldierIdle
    /// Nesretna osoba napušta dvorac; kad stigne do ruba, nestaje.
    case leaving

    var jobPlacementId: String? {
        switch self {
        case .walkingToWork(let id), .working(let id), .returningToWork(let id): return id
        case .delivering(let fromId, _), .fetching(let fromId, _): return fromId
        case .walkingToTree(let hutId, _), .chopping(let hutId, _), .haulingLog(let hutId, _): return hutId
        default: return nil
        }
    }

    var isMoving: Bool {
        switch self {
        case .returningToFire, .walkingToWork, .delivering, .fetching, .returningToWork, .walkingToTree, .haulingLog, .soldierMoving, .leaving: return true
        default: return false
        }
    }
}

struct Person: Codable, Identifiable, Equatable {
    let id: String
    /// Frakcija (RealmSeat.id) kojoj osoba pripada.
    let factionId: String
    let colorHex: String
    var role: PersonRole
    var activity: PersonActivity
    /// Pozicija u koordinatama ćelija (kao kralj).
    var row: Double
    var col: Double
    var targetRow: Double
    var targetCol: Double
    /// Sloj na kojem osoba stoji (nadzemlje / podzemlje).
    var layer: MapLayer = .surface
    var targetLayer: MapLayer = .surface
    var facing: Double = 0
    var walkPhase: Double = 0
    var healthPercent: Double = 100
    /// Mjesto u krugu oko vatre (seljak) ili u postroju (vojnik).
    var slot: Int = 0
    /// Glavno oružje vojnika (mač, koplje, luk).
    var weapon: Good?
    /// Vrsta vojnika (strijelac, kopljanik…); stari zapisi je nemaju pa se izvodi iz oružja.
    var soldierType: SoldierType?
    /// Točke puta do cilja (zaobilazi zidove i vodu); zadnja je cilj.
    var waypoints: [PathPoint]?
    /// Za koji cilj i koju verziju mape je put složen; promjena = novi put.
    var pathTarget: PathPoint?
    var pathVersion: Int?
    /// Do cilja trenutno nema puta – osoba stoji dok se mapa ne promijeni.
    var pathBlocked: Bool?

    var resolvedSoldierType: SoldierType? {
        role == .soldier ? soldierType ?? SoldierType.legacy(weapon: weapon) : nil
    }

    /// Množitelj brzine hoda.
    var speedFactor: Double { resolvedSoldierType?.speedFactor ?? 1 }

    /// Samo vojska. Slobodna osoba kod vatre i radnik se ne označavaju.
    var canBeMarked: Bool { role == .soldier && healthPercent > 0 }
    var isVisible: Bool {
        if case .working = activity { return false }
        return healthPercent > 0
    }

    var displayName: String {
        if let type = resolvedSoldierType { return type.displayName }
        return role.displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, factionId, colorHex, role, activity, row, col, targetRow, targetCol
        case layer, targetLayer, facing, walkPhase, healthPercent, slot, weapon, soldierType
        case waypoints, pathTarget, pathVersion, pathBlocked
    }

    init(id: String, factionId: String, colorHex: String, role: PersonRole, activity: PersonActivity,
         row: Double, col: Double, targetRow: Double, targetCol: Double, facing: Double = 0, walkPhase: Double = 0,
         healthPercent: Double = 100, slot: Int = 0, weapon: Good? = nil, soldierType: SoldierType? = nil,
         waypoints: [PathPoint]? = nil, pathTarget: PathPoint? = nil, pathVersion: Int? = nil, pathBlocked: Bool? = nil,
         layer: MapLayer = .surface, targetLayer: MapLayer = .surface) {
        self.id = id
        self.factionId = factionId
        self.colorHex = colorHex
        self.role = role
        self.activity = activity
        self.row = row
        self.col = col
        self.targetRow = targetRow
        self.targetCol = targetCol
        self.layer = layer
        self.targetLayer = targetLayer
        self.facing = facing
        self.walkPhase = walkPhase
        self.healthPercent = healthPercent
        self.slot = slot
        self.weapon = weapon
        self.soldierType = soldierType
        self.waypoints = waypoints
        self.pathTarget = pathTarget
        self.pathVersion = pathVersion
        self.pathBlocked = pathBlocked
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        factionId = try c.decode(String.self, forKey: .factionId)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        role = try c.decode(PersonRole.self, forKey: .role)
        activity = try c.decode(PersonActivity.self, forKey: .activity)
        row = try c.decode(Double.self, forKey: .row)
        col = try c.decode(Double.self, forKey: .col)
        targetRow = try c.decode(Double.self, forKey: .targetRow)
        targetCol = try c.decode(Double.self, forKey: .targetCol)
        layer = try c.decodeIfPresent(MapLayer.self, forKey: .layer) ?? .surface
        targetLayer = try c.decodeIfPresent(MapLayer.self, forKey: .targetLayer) ?? .surface
        facing = try c.decodeIfPresent(Double.self, forKey: .facing) ?? 0
        walkPhase = try c.decodeIfPresent(Double.self, forKey: .walkPhase) ?? 0
        healthPercent = try c.decodeIfPresent(Double.self, forKey: .healthPercent) ?? 100
        slot = try c.decodeIfPresent(Int.self, forKey: .slot) ?? 0
        weapon = try c.decodeIfPresent(Good.self, forKey: .weapon)
        soldierType = try c.decodeIfPresent(SoldierType.self, forKey: .soldierType)
        waypoints = try c.decodeIfPresent([PathPoint].self, forKey: .waypoints)
        pathTarget = try c.decodeIfPresent(PathPoint.self, forKey: .pathTarget)
        pathVersion = try c.decodeIfPresent(Int.self, forKey: .pathVersion)
        pathBlocked = try c.decodeIfPresent(Bool.self, forKey: .pathBlocked)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(factionId, forKey: .factionId)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(role, forKey: .role)
        try c.encode(activity, forKey: .activity)
        try c.encode(row, forKey: .row)
        try c.encode(col, forKey: .col)
        try c.encode(targetRow, forKey: .targetRow)
        try c.encode(targetCol, forKey: .targetCol)
        try c.encode(layer, forKey: .layer)
        try c.encode(targetLayer, forKey: .targetLayer)
        try c.encode(facing, forKey: .facing)
        try c.encode(walkPhase, forKey: .walkPhase)
        try c.encode(healthPercent, forKey: .healthPercent)
        try c.encode(slot, forKey: .slot)
        try c.encodeIfPresent(weapon, forKey: .weapon)
        try c.encodeIfPresent(soldierType, forKey: .soldierType)
        try c.encodeIfPresent(waypoints, forKey: .waypoints)
        try c.encodeIfPresent(pathTarget, forKey: .pathTarget)
        try c.encodeIfPresent(pathVersion, forKey: .pathVersion)
        try c.encodeIfPresent(pathBlocked, forKey: .pathBlocked)
    }
}

/// Što scena crta za jednu osobu (čita se s render niti).
struct PersonRenderSnapshot: Equatable {
    let id: String
    let colorHex: String
    let role: PersonRole
    let soldierType: SoldierType?
    let row: Double
    let col: Double
    let facing: Double
    let moving: Bool
    let walkPhase: Double
    let visible: Bool
    let layer: MapLayer
}
