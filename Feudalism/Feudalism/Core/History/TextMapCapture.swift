//
//  TextMapCapture.swift
//  Feudalism
//
//  Četiri tekstualne mape iz stanja partije: glavna (teren + resursi + start),
//  podzemlje, građevine, vojska. To je pogled kakav AI ima — bez 3D grafike.
//

import Foundation

enum TextMapCapture {
    static let empty: Character = "."
    static let maxVisionSide = 48

    static func blockSize(rows: Int, cols: Int) -> Int {
        let side = max(rows, cols, 1)
        return max(1, Int(ceil(Double(side) / Double(maxVisionSide))))
    }

    static func captureFrame(from state: GameState, events: [MatchTimelineEvent] = []) -> MatchHistoryFrame {
        let maps = captureMaps(from: state)
        return MatchHistoryFrame(
            id: UUID().uuidString,
            turn: state.currentTurn,
            main: maps.main,
            underground: maps.underground,
            buildings: maps.buildings,
            army: maps.army,
            timeline: timelineText(state: state, events: events),
            heightMap: heightMap(from: state.gameMap)
        )
    }

    /// Visine točaka sjecišta. Nije za trening ni AI, samo za GUI.
    static func heightMap(from map: GameMap) -> String {
        guard map.rows > 0, map.cols > 0 else { return "" }
        var lines: [String] = []
        lines.reserveCapacity(map.rows + 1)
        for row in 0...map.rows {
            var cells: [String] = []
            cells.reserveCapacity(map.cols + 1)
            for col in 0...map.cols {
                cells.append(heightText(map.vertexHeightAt(vertexRow: row, vertexCol: col)))
            }
            lines.append(cells.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    private static func heightText(_ value: CGFloat) -> String {
        let scaled = (Double(value) * 100).rounded() / 100
        if abs(scaled - scaled.rounded()) < 0.001 { return String(Int(scaled.rounded())) }
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), scaled)
    }

    static func timelineText(state: GameState, events: [MatchTimelineEvent]) -> String {
        let second = max(0, state.currentTurn - 1)
        var lines = [
            "\(second)s  potez \(state.currentTurn)",
            resourceLine(gold: state.resources.gold, wood: state.resources.wood, stone: state.resources.stone, iron: state.resources.iron, food: state.food),
            peopleText(state: state)
        ]
        if events.filter({ $0.second <= second }).isEmpty {
            lines.append("Nema poteza do ove sekunde.")
        }
        return lines.joined(separator: "\n")
    }

    static func peopleText(state: GameState) -> String {
        let seats = state.realmSeats.seats
        if seats.isEmpty {
            return "populacija \(state.playerPopulation)  sreća \(Int(state.playerHappiness.rounded()))%"
        }
        return seats.map { seat in
            let pop = state.population(of: seat.id)
            let happy = Int(state.happinessPercent(of: seat.id).rounded())
            return "\(seat.displayName): populacija \(pop)  sreća \(happy)%"
        }.joined(separator: "\n")
    }

    static func resourceLine(gold: Int, wood: Int, stone: Int, iron: Int, food: Int) -> String {
        "zlato \(gold)  drvo \(wood)  kamen \(stone)  željezo \(iron)  hrana \(food)"
    }

    /// Sloj mape koji AI / UI može zatražiti zasebno (svaki ima svoj poziv).
    enum MapLayerKind: String, CaseIterable, Codable {
        /// Teren / resursi / prohodnost (glavna površina).
        case surface
        /// Podzemlje — AI rijetko gleda.
        case underground
        /// Građevine (i resursni objekti na karti).
        case buildings
        /// Ljudi i vojnici.
        case army
    }

    /// Zaseban poziv jednog sloja — AI bira što treba (npr. army + buildings, bez underground).
    static func capture(_ kind: MapLayerKind, from state: GameState) -> String {
        switch kind {
        case .surface: return captureSurface(from: state)
        case .underground: return captureUnderground(from: state)
        case .buildings: return captureBuildings(from: state)
        case .army: return captureArmy(from: state)
        }
    }

    /// Glavna mapa: teren, visina, prohodnost, može li se graditi (resursi u šiframa ćelije).
    static func captureSurface(from state: GameState) -> String {
        mainMatrix(state.gameMap)
    }

    /// Podzemlje — isti format kao površina; prazna matrica ako nema podzemlja.
    static func captureUnderground(from state: GameState) -> String {
        let surface = state.gameMap
        let under = state.undergroundMap
        if under.rows == surface.rows, under.cols == surface.cols, under.rows > 0 {
            return mainMatrix(under)
        }
        return zeroMatrix(rows: surface.rows, cols: surface.cols)
    }

    /// Mapa građevina (blokovi).
    static func captureBuildings(from state: GameState) -> String {
        let surface = state.gameMap
        let under = state.undergroundMap
        let block = blockSize(rows: surface.rows, cols: surface.cols)
        let vRows = max(1, (surface.rows + block - 1) / block)
        let vCols = max(1, (surface.cols + block - 1) / block)
        var buildings = TextGrid(rows: vRows, cols: vCols)
        stampBuildings(surface.placements, block: block, grid: &buildings)
        if under.rows == surface.rows, under.cols == surface.cols {
            stampBuildings(under.placements, block: block, grid: &buildings)
        }
        return buildings.encoded()
    }

    /// Mapa ljudi / vojnika.
    static func captureArmy(from state: GameState) -> String {
        armyMatrix(from: state, surface: state.gameMap)
    }

    static func captureMaps(from state: GameState) -> (main: String, underground: String, buildings: String, army: String) {
        (
            captureSurface(from: state),
            captureUnderground(from: state),
            captureBuildings(from: state),
            captureArmy(from: state)
        )
    }

    /// Prazna matrica pune veličine. Svaka kućica je 0,0,0,0.
    private static func zeroMatrix(rows: Int, cols: Int) -> String {
        guard rows > 0, cols > 0 else { return "" }
        let line = Array(repeating: "0,0,0,0", count: cols).joined(separator: " ")
        return Array(repeating: line, count: rows).joined(separator: "\n")
    }

    /// Puna matrica, jedna ćelija = površina,visina,prohodnost,gradnja.
    /// Prohodnost: 0 ne prolazi, 0.5 sporo, 1 normalno, 1.5 padina ili cesta, 2 padina i cesta.
    private static func mainMatrix(_ surface: GameMap) -> String {
        guard surface.rows > 0, surface.cols > 0 else { return "" }
        let count = surface.rows * surface.cols
        var road = [Bool](repeating: false, count: count)
        var blocked = [Bool](repeating: false, count: count)
        for placement in surface.placements where !placement.isDestroyed {
            let isRoad = roadObject(placement.objectId)
            let r1 = min(surface.rows, placement.row + placement.height)
            let c1 = min(surface.cols, placement.col + placement.width)
            var r = max(0, placement.row)
            while r < r1 {
                var c = max(0, placement.col)
                while c < c1 {
                    let index = r * surface.cols + c
                    if isRoad { road[index] = true }
                    if Passage.blocks(
                        objectId: placement.objectId,
                        row: r,
                        col: c,
                        originRow: placement.row,
                        originCol: placement.col,
                        width: placement.width,
                        height: placement.height
                    ) {
                        blocked[index] = true
                    }
                    c += 1
                }
                r += 1
            }
        }
        var lines: [String] = []
        lines.reserveCapacity(surface.rows)
        for r in 0..<surface.rows {
            var cells: [String] = []
            cells.reserveCapacity(surface.cols)
            for c in 0..<surface.cols {
                let index = r * surface.cols + c
                cells.append(cellToken(surface, row: r, col: c, road: road[index], blocked: blocked[index]))
            }
            lines.append(cells.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    private static func roadObject(_ objectId: String) -> Bool {
        objectId == Road.objectId || objectId == Bridge.objectId || objectId == StoneSlab.objectId || objectId == Tunnel.objectId
            || objectId == Canal.objectId || objectId == River.objectId
    }

    private static func cellToken(_ surface: GameMap, row: Int, col: Int, road: Bool, blocked: Bool) -> String {
        guard let cell = surface.cell(row: row, col: col) else { return "0,0,0,0" }
        let hasRoad = road
        let sloped = surface.surface(row: row, col: col).slope >= 1
        let walk = walkCode(cell: cell, road: hasRoad, sloped: sloped, blocked: blocked)
        let canBuild = !blocked && cell.buildable && cell.povrsina.isBuildable
        return "\(surfaceCode(cell.povrsina, iron: cell.resource == .iron)),\(Int(cell.height.rounded())),\(walk),\(canBuild ? 1 : 0)"
    }

    /// 0 ne prolazi, 0.5 spor teren, 1 ravno, 1.5 padina ili cesta, 2 oboje.
    private static func walkCode(cell: MapCell, road: Bool, sloped: Bool, blocked: Bool) -> String {
        // More uvijek neprohodno; voda (rijeka) isto osim ako je eksplicitno jezero (movementIndex > 0).
        if blocked || !cell.walkable || cell.movementIndex <= 0 || cell.povrsina == .more {
            return "0"
        }
        if sloped && road { return "2" }
        if sloped || road { return "1.5" }
        switch cell.povrsina {
        case .pustinja, .kamen, .obala: return "0.5"
        case .voda: return "1" // jezero (prohodna voda)
        default: return "1"
        }
    }

    /// Šifra terena je sam enum. Željezna naslaga na ćeliji je 2.
    private static func surfaceCode(_ surface: PovrsinaType, iron: Bool) -> Int {
        if iron { return PovrsinaType.zeljezo.rawValue }
        return surface.rawValue
    }

    // MARK: - Slojevi

    private static func stampBuildings(_ placements: [Placement], block: Int, grid: inout TextGrid, force: Character? = nil) {
        for placement in placements where !placement.isDestroyed {
            let ch = force ?? buildingGlyph(placement.objectId)
            let r0 = placement.row / block
            let c0 = placement.col / block
            let r1 = (placement.row + placement.height - 1) / block
            let c1 = (placement.col + placement.width - 1) / block
            for vr in r0...r1 {
                for vc in c0...c1 {
                    guard grid.contains(row: vr, col: vc) else { continue }
                    if force != nil || grid[vr, vc] == empty || buildingRank(ch) >= buildingRank(grid[vr, vc]) {
                        grid[vr, vc] = ch
                    }
                }
            }
        }
    }

    /// Puna matrica vojske: vrsta, broj, okupirano, građevina.
    /// Na ćeliji je najviše jedan vojnik po timu i najviše dva, i to suparnici.
    private static func armyMatrix(from state: GameState, surface: GameMap) -> String {
        guard surface.rows > 0, surface.cols > 0 else { return "" }
        let cols = surface.cols
        let count = surface.rows * cols
        var piles: [[ArmyStamp]] = Array(repeating: [], count: count)
        for person in state.people.people where person.role == .soldier && person.isVisible && person.activity != .leaving && person.layer == .surface {
            let row = Int(person.row.rounded(.down))
            let col = Int(person.col.rounded(.down))
            guard row >= 0, col >= 0, row < surface.rows, col < cols else { continue }
            let type = soldierCode(person.resolvedSoldierType)
            guard type > 0 else { continue }
            piles[row * cols + col].append(ArmyStamp(type: type, faction: person.factionId))
        }
        var building = [Int](repeating: 0, count: count)
        var owned = [Bool](repeating: false, count: count)
        for placement in surface.placements where !placement.isDestroyed {
            let code = buildingCode(placement.objectId)
            let blocks = Passage.blocks(objectId: placement.objectId)
            let r1 = min(surface.rows, placement.row + placement.height)
            let c1 = min(cols, placement.col + placement.width)
            var r = max(0, placement.row)
            while r < r1 {
                var c = max(0, placement.col)
                while c < c1 {
                    let index = r * cols + c
                    if placement.ownerId != nil { owned[index] = true }
                    if code > 0, building[index] == 0 || blocks {
                        building[index] = code
                    }
                    c += 1
                }
                r += 1
            }
        }
        var lines: [String] = []
        lines.reserveCapacity(surface.rows)
        for r in 0..<surface.rows {
            var cells: [String] = []
            cells.reserveCapacity(cols)
            for c in 0..<cols {
                let index = r * cols + c
                cells.append(armyToken(piles[index], occupied: owned[index], building: building[index]))
            }
            lines.append(cells.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    private struct ArmyStamp {
        var type: Int
        var faction: String
    }

    /// Jedna vrsta po ćeliji. Dva vojnika samo ako su iz suprotnih timova.
    private static func armyToken(_ stamps: [ArmyStamp], occupied: Bool, building: Int) -> String {
        var seen = Set<String>()
        var kept: [ArmyStamp] = []
        for stamp in stamps where seen.insert(stamp.faction).inserted {
            kept.append(stamp)
            if kept.count == 2 { break }
        }
        let type = kept.first?.type ?? 0
        let soldiers = kept.count
        let held = occupied || soldiers > 0
        return "\(type),\(soldiers),\(held ? 1 : 0),\(building)"
    }

    private static func soldierCode(_ type: SoldierType?) -> Int {
        switch type {
        case .archer: return 1
        case .armoredArcher: return 2
        case .spearman: return 3
        case .shieldSpearman: return 4
        case .swordsman: return 5
        case .shieldSwordsman: return 6
        case .heavyInfantry: return 7
        case .mountedArcher: return 8
        case .lancer: return 9
        case .knight: return 10
        case nil: return 0
        }
    }

    private static func buildingCode(_ objectId: String) -> Int {
        buildingCodes[objectId] ?? 0
    }

    private static let buildingCodes: [String: Int] = {
        var codes: [String: Int] = [:]
        for (index, type) in PlaceableSceneKitTypes.all.enumerated() {
            codes[type.objectId] = index + 1
        }
        return codes
    }()

    static func buildingGlyph(_ objectId: String) -> Character {
        let id = objectId.lowercased()
        if id.contains("castle") { return "C" }
        if id.contains("wall") { return "Z" }
        if id.contains("gates") || id.contains("steps") || id.contains("tower") { return "C" }
        if HarvestTrees.objectIds.contains(objectId) || id.contains("tree") { return "^" }
        if id.contains("rock") { return "S" }
        if id.contains("farm") || id.contains("hive") || id.contains("pig") || id.contains("cow")
            || id.contains("sheep") || id.contains("chicken") || id.contains("corn") || id.contains("hop")
            || id.contains("vegetable") || id.contains("grape") || id.contains("spice")
            || id.contains("flower") || id.contains("apple") {
            return "A"
        }
        if id.contains("iron") || id.contains("stone") || id.contains("miner") { return "N" }
        if id.contains("house") || id.contains("hotel") || id.contains("church") || id.contains("pharmacy")
            || id.contains("greenhouse") || id.contains("well") || id.contains("spring")
            || id.contains("academy") || id.contains("diplomacy") {
            return "H"
        }
        if id.contains("food") || id.contains("bakery") || id.contains("brewery") || id.contains("windmill")
            || id.contains("tavern") || id.contains("granary") || id.contains("distillery")
            || id.contains("wine") || id.contains("canteen") || id.contains("smocnica") || id.contains("candle") {
            return "K"
        }
        if id.contains("road") || id.contains("bridge") || id.contains("slab") || id.contains("tunnel")
            || id.contains("flag") || id.contains("torch") || id.contains("fountain")
            || id.contains("monument") || id.contains("roof") {
            return "="
        }
        if id.contains("underground") { return "O" }
        if id.contains("wood") || id.contains("lager") || id.contains("carriage") || id.contains("industry") {
            return "L"
        }
        if id.contains("sword") || id.contains("bow") || id.contains("spear") || id.contains("shield")
            || id.contains("armory") || id.contains("training") || id.contains("leather") || id.contains("stable") {
            return "W"
        }
        return "#"
    }

    private static func buildingRank(_ ch: Character) -> Int {
        switch ch {
        case "C": return 90
        case "Z": return 80
        case "N": return 70
        case "H": return 60
        case "A": return 55
        case "K": return 50
        case "W": return 45
        case "L": return 40
        case "O": return 35
        case "=": return 20
        case "^", "S": return 15
        case "#": return 10
        default: return 0
        }
    }

}

private struct TextGrid {
    let rows: Int
    let cols: Int
    private var cells: [Character]

    init(rows: Int, cols: Int, fill: Character = TextMapCapture.empty) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        cells = Array(repeating: fill, count: self.rows * self.cols)
    }

    func contains(row: Int, col: Int) -> Bool {
        row >= 0 && col >= 0 && row < rows && col < cols
    }

    subscript(row: Int, col: Int) -> Character {
        get {
            guard contains(row: row, col: col) else { return TextMapCapture.empty }
            return cells[row * cols + col]
        }
        set {
            guard contains(row: row, col: col) else { return }
            cells[row * cols + col] = newValue
        }
    }

    func encoded() -> String {
        var lines: [String] = []
        lines.reserveCapacity(rows)
        for r in 0..<rows {
            let start = r * cols
            lines.append(String(cells[start..<(start + cols)]))
        }
        return lines.joined(separator: "\n")
    }
}
