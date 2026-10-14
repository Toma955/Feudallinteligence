//
//  MapCell.swift
//  Feudalism
//
//  Jedna ćelija mape (1×1 m): vlastiti id, teren (površina), visina (-5 … +100 m),
//  srednja točka ploče, indeks kretanja i naslaga resursa (kamen, željezo) koja dopušta vađenje.
//  Kutovi ploče su u GameMap.vertexHeights / vertexOffsets jer ih dijele susjedi.
//

import Foundation

struct MapCell: Identifiable, Codable {
    /// Vlastiti id ćelije ("red_stupac"), jedinstven na mapi.
    var id: String { coordinate.cellId }
    let coordinate: MapCoordinate
    /// ID teksture (jedna po polju).
    var textureId: String = "grass"
    /// ID objekata na polju (više: npr. žbunje, stabla, voda).
    var objectIds: [String] = []
    var terrain: TerrainType
    /// Visina ćelije u metrima, -5 … +100.
    var height: CGFloat = 0 {
        didSet { height = TerrainHeight.clamp(height) }
    }
    /// Naslaga na ćeliji (kamen, željezo). Omogućuje gradnju rudnika/kamenoloma na tom području.
    var resource: ResourceType? = nil
    /// Može li se hodati.
    var walkable: Bool = true
    /// Može li se graditi.
    var buildable: Bool = true
    /// Može li se pošumljavati.
    var canAfforest: Bool = false
    /// Može li se kopati kanal (kupanje kanala).
    var canDigChannels: Bool = false
    /// Teren: pustinja, poluplodna, plodna, trava, voda, more, put, kamen, močvara.
    var povrsina: PovrsinaType = .default
    /// Dubina mora u metrima (samo za `.more`). nil = zadanih 5 m.
    var seaDepth: CGFloat? = nil
    /// Indeks kretanja: 1 = normalno, 0 = neprohodno. Zadano iz terena, može se ručno promijeniti.
    var movementIndex: Double = PovrsinaType.default.defaultMovementIndex
    /// Srednja točka ploče. nil = sredina ćelije, visina je prosjek kutova.
    var center: CellCenterPoint? = nil

    /// Efektivna dubina mora (metri).
    var effectiveSeaDepth: CGFloat {
        guard povrsina == .more else { return 0 }
        return UndergroundTerrain.clampSeaDepth(seaDepth ?? UndergroundTerrain.defaultSeaDepth)
    }

    /// Kutovi ćelije u mreži (0 gornji lijevi, 1 gornji desni, 2 donji lijevi, 3 donji desni).
    var points: [MapCellPoint] {
        let r = Double(coordinate.row)
        let c = Double(coordinate.col)
        return [
            MapCellPoint(row: r, col: c, index: 0),
            MapCellPoint(row: r, col: c + 1, index: 1),
            MapCellPoint(row: r + 1, col: c, index: 2),
            MapCellPoint(row: r + 1, col: c + 1, index: 3)
        ]
    }

    init(coordinate: MapCoordinate, textureId: String = "grass", objectIds: [String] = [], terrain: TerrainType = .grass, height: CGFloat = 0, resource: ResourceType? = nil, walkable: Bool? = nil, buildable: Bool? = nil, canAfforest: Bool = false, canDigChannels: Bool = false, povrsina: PovrsinaType = .default, movementIndex: Double? = nil, center: CellCenterPoint? = nil) {
        self.coordinate = coordinate
        self.textureId = textureId
        self.objectIds = objectIds
        self.terrain = terrain
        self.height = TerrainHeight.clamp(height)
        self.resource = resource
        self.walkable = walkable ?? (terrain.defaultWalkable && povrsina.isWalkable)
        self.buildable = buildable ?? (terrain.defaultBuildable && povrsina.isBuildable)
        self.canAfforest = canAfforest
        self.canDigChannels = canDigChannels
        self.povrsina = povrsina
        self.movementIndex = movementIndex ?? povrsina.defaultMovementIndex
        self.center = center
    }

    /// Promijeni teren i postavi zadane vrijednosti kretanja i gradnje za njega.
    mutating func applySurface(_ surface: PovrsinaType) {
        povrsina = surface
        movementIndex = surface.defaultMovementIndex
        walkable = surface.isWalkable
        buildable = surface.isBuildable
        if surface != .more { seaDepth = nil }
    }

    enum CodingKeys: String, CodingKey {
        case coordinate, textureId, objectIds, terrain, height, resource, walkable, buildable, canAfforest, canDigChannels, povrsina, seaDepth, movementIndex, center
        case prohodnost
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coordinate = try c.decode(MapCoordinate.self, forKey: .coordinate)
        textureId = try c.decodeIfPresent(String.self, forKey: .textureId) ?? "grass"
        objectIds = try c.decodeIfPresent([String].self, forKey: .objectIds) ?? []
        terrain = try c.decode(TerrainType.self, forKey: .terrain)
        let h = try c.decodeIfPresent(Double.self, forKey: .height) ?? 0
        height = TerrainHeight.clamp(CGFloat(h))
        resource = try c.decodeIfPresent(ResourceType.self, forKey: .resource)
        walkable = try c.decodeIfPresent(Bool.self, forKey: .walkable) ?? terrain.defaultWalkable
        buildable = try c.decodeIfPresent(Bool.self, forKey: .buildable) ?? terrain.defaultBuildable
        canAfforest = try c.decodeIfPresent(Bool.self, forKey: .canAfforest) ?? false
        canDigChannels = try c.decodeIfPresent(Bool.self, forKey: .canDigChannels) ?? false
        povrsina = try c.decodeIfPresent(PovrsinaType.self, forKey: .povrsina) ?? .default
        if let d = try c.decodeIfPresent(Double.self, forKey: .seaDepth) {
            seaDepth = UndergroundTerrain.clampSeaDepth(CGFloat(d))
        } else {
            seaDepth = nil
        }
        if let index = try c.decodeIfPresent(Double.self, forKey: .movementIndex) {
            movementIndex = index
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .prohodnost) {
            movementIndex = Self.legacyMovementIndex(legacy)
        } else {
            movementIndex = povrsina.defaultMovementIndex
        }
        center = try c.decodeIfPresent(CellCenterPoint.self, forKey: .center)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coordinate, forKey: .coordinate)
        try c.encode(textureId, forKey: .textureId)
        try c.encode(objectIds, forKey: .objectIds)
        try c.encode(terrain, forKey: .terrain)
        try c.encode(Double(height), forKey: .height)
        try c.encodeIfPresent(resource, forKey: .resource)
        try c.encode(walkable, forKey: .walkable)
        try c.encode(buildable, forKey: .buildable)
        try c.encode(canAfforest, forKey: .canAfforest)
        try c.encode(canDigChannels, forKey: .canDigChannels)
        try c.encode(povrsina, forKey: .povrsina)
        if let seaDepth {
            try c.encode(Double(seaDepth), forKey: .seaDepth)
        }
        try c.encode(movementIndex, forKey: .movementIndex)
        try c.encodeIfPresent(center, forKey: .center)
    }

    /// Stare mape: N neprohodno, V vrlo sporo, S sporo, G normalno, B brzo.
    private static func legacyMovementIndex(_ letter: String) -> Double {
        switch letter {
        case "N": return 0
        case "V": return 0.25
        case "S": return 0.5
        case "B": return 1.5
        default: return 1
        }
    }
}
