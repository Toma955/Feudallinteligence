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

    static func captureFrame(from state: GameState) -> MatchHistoryFrame {
        let maps = captureMaps(from: state)
        return MatchHistoryFrame(
            id: UUID().uuidString,
            turn: state.currentTurn,
            main: maps.main,
            underground: maps.underground,
            buildings: maps.buildings,
            army: maps.army
        )
    }

    static func captureMaps(from state: GameState) -> (main: String, underground: String, buildings: String, army: String) {
        let surface = state.gameMap
        let under = state.undergroundMap
        let rows = surface.rows
        let cols = surface.cols
        let block = blockSize(rows: rows, cols: cols)
        let vRows = max(1, (rows + block - 1) / block)
        let vCols = max(1, (cols + block - 1) / block)

        var main = TextGrid(rows: vRows, cols: vCols)
        var underground = TextGrid(rows: vRows, cols: vCols)
        var buildings = TextGrid(rows: vRows, cols: vCols)
        var army = TextGrid(rows: vRows, cols: vCols)

        fillMain(from: state, surface: surface, block: block, grid: &main)
        fillUnderground(surface: surface, underground: under, block: block, grid: &underground)
        stampBuildings(surface.placements, block: block, grid: &buildings)
        stampBuildings(under.placements, block: block, grid: &buildings)
        stampArmy(from: state, block: block, grid: &army)

        return (main.encoded(), underground.encoded(), buildings.encoded(), army.encoded())
    }

    // MARK: - Slojevi

    private static func fillMain(from state: GameState, surface: GameMap, block: Int, grid: inout TextGrid) {
        for vr in 0..<grid.rows {
            for vc in 0..<grid.cols {
                grid[vr, vc] = sampleMain(surface: surface, block: block, visionRow: vr, visionCol: vc)
            }
        }
        for (slot, start) in surface.lordStarts {
            stampArmyChar(slot == 1 ? "@" : "a", mapRow: Double(start.row), mapCol: Double(start.col), block: block, grid: &grid)
        }
        for seat in state.realmSeats.seats {
            stampArmyChar(seat.isPlayerFaction ? "@" : "a", mapRow: seat.castleRow, mapCol: seat.castleCol, block: block, grid: &grid)
        }
        let castles = surface.placements.filter { $0.objectId.lowercased().contains("castle") && !$0.isDestroyed }
        stampBuildings(castles, block: block, grid: &grid, force: "@")
    }

    private static func sampleMain(surface: GameMap, block: Int, visionRow: Int, visionCol: Int) -> Character {
        let r0 = visionRow * block
        let c0 = visionCol * block
        let r1 = min(surface.rows, r0 + block)
        let c1 = min(surface.cols, c0 + block)
        var best: Character = empty
        var rank = 0
        let step = block <= 8 ? 1 : max(1, block / 3)
        var r = r0
        while r < r1 {
            var c = c0
            while c < c1 {
                if let cell = surface.cell(row: r, col: c) {
                    let (ch, prio) = mainGlyph(cell)
                    if prio > rank {
                        best = ch
                        rank = prio
                    }
                }
                c += step
            }
            r += step
        }
        return best
    }

    /// Veći broj = važnije (rude i voda preko trave).
    private static func mainGlyph(_ cell: MapCell) -> (Character, Int) {
        if cell.resource == .iron { return ("i", 90) }
        if cell.resource == .stone { return ("+", 85) }
        if cell.objectIds.contains(where: { HarvestTrees.objectIds.contains($0) || $0.contains("tree") }) {
            return ("^", 70)
        }
        switch cell.povrsina {
        case .voda: return ("W", 80)
        case .more: return ("M", 80)
        case .put: return ("R", 55)
        case .kamen: return ("S", 50)
        case .mocvara: return ("B", 45)
        case .plodna: return ("F", 30)
        case .trava: return ("T", 25)
        case .pustinja: return ("D", 20)
        case .poluplodna: return ("G", 10)
        }
    }

    private static func fillUnderground(surface: GameMap, underground: GameMap, block: Int, grid: inout TextGrid) {
        let shafts = surface.placements.filter { Underground.entranceObjectIds.contains($0.objectId) && !$0.isDestroyed }
        stampBuildings(shafts, block: block, grid: &grid, force: "O")
        stampBuildings(underground.placements, block: block, grid: &grid)
        let step = max(1, block)
        var r = 0
        while r < underground.rows {
            var c = 0
            while c < underground.cols {
                if let cell = underground.cell(row: r, col: c) {
                    let vr = r / block
                    let vc = c / block
                    if grid[vr, vc] == empty {
                        if cell.povrsina == .voda || cell.povrsina == .more {
                            grid[vr, vc] = "~"
                        }
                    }
                }
                c += step
            }
            r += step
        }
    }

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

    private static func stampArmy(from state: GameState, block: Int, grid: inout TextGrid) {
        for person in state.people.people where person.healthPercent > 0 && person.activity != .leaving {
            let ch = armyGlyph(role: person.role, isPlayer: state.playerRealmId == person.factionId || isPlayerFaction(person.factionId, state: state))
            stampArmyChar(ch, mapRow: person.row, mapCol: person.col, block: block, grid: &grid)
        }
        for seat in state.realmSeats.seats {
            let player = seat.isPlayerFaction
            if seat.kingAlive {
                stampArmyChar(player ? "K" : "k", mapRow: seat.kingRow, mapCol: seat.kingCol, block: block, grid: &grid)
            }
            stampArmyChar(player ? "@" : "a", mapRow: seat.castleRow, mapCol: seat.castleCol, block: block, grid: &grid)
        }
    }

    private static func isPlayerFaction(_ factionId: String, state: GameState) -> Bool {
        if let id = state.playerRealmId, id == factionId { return true }
        return state.realmSeats.seats.first(where: { $0.id == factionId })?.isPlayerFaction == true
    }

    private static func stampArmyChar(_ ch: Character, mapRow: Double, mapCol: Double, block: Int, grid: inout TextGrid) {
        let vr = Int(mapRow.rounded(.down)) / block
        let vc = Int(mapCol.rounded(.down)) / block
        guard grid.contains(row: vr, col: vc) else { return }
        if armyRank(ch) >= armyRank(grid[vr, vc]) {
            grid[vr, vc] = ch
        }
    }

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
            || id.contains("greenhouse") || id.contains("well") || id.contains("spring") {
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

    private static func armyGlyph(role: PersonRole, isPlayer: Bool) -> Character {
        switch role {
        case .soldier: return isPlayer ? "V" : "v"
        case .worker: return isPlayer ? "R" : "r"
        case .peasant: return isPlayer ? "P" : "p"
        }
    }

    private static func armyRank(_ ch: Character) -> Int {
        switch ch {
        case "K", "k": return 90
        case "V", "v": return 80
        case "@", "a": return 70
        case "R", "r": return 40
        case "P", "p": return 20
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
