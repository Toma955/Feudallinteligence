//
//  WarehouseStacks.swift
//  Feudalism
//
//  Jedno polje 2×2 = jedan resurs. Kupnja diže hrpu, prodaja je spušta.
//  Hrpe stoje u world koordinatama na čvoru "warehouse" (ne unutar modela
//  koji se briše pri refreshPlacements).
//

import Foundation
import SceneKit
import AppKit

enum WarehouseStacks {
    static func stockKey(_ gameState: GameState) -> String {
        var parts: [String] = [
            "v\(gameState.placementsVersion)",
            "e\(gameState.warehouseGoodsEpoch)"
        ]
        let stores = gameState.gameMap.placements
            .filter { $0.objectId == Lager.objectId && !$0.isDestroyed }
            .sorted { $0.id < $1.id }
        for placement in stores {
            let owner = gameState.owner(of: placement) ?? gameState.playerSeat?.id ?? ""
            let amounts = Good.allCases
                .filter { $0 != .gold }
                .map { "\($0.rawValue):\(gameState.goodAmount($0, of: owner))" }
                .joined(separator: ",")
            parts.append("\(placement.id)@\(owner)=\(amounts)")
        }
        return parts.joined(separator: "|")
    }

    /// Crta hrpe na poljima skladišta. Zvati s main ili renderer niti (kao smočnica).
    static func syncWorld(on root: SCNNode, gameState: GameState, rows: Int, cols: Int) {
        let key = stockKey(gameState)
        let stamp = "k\(key.hashValue)"
        root.name = "warehouse"
        if let mark = root.childNode(withName: "stockMark", recursively: false),
           mark.childNodes.first?.name == stamp {
            return
        }

        root.childNodes.filter {
            let n = $0.name ?? ""
            return n == "stockMark" || n.hasPrefix("pile-")
        }.forEach { $0.removeFromParentNode() }

        let mark = SCNNode()
        mark.name = "stockMark"
        let tag = SCNNode()
        tag.name = stamp
        mark.addChildNode(tag)
        root.addChildNode(mark)

        let cell = MapScale.worldUnitsPerMapCell
        let halfW = MapScale.worldWidth(cols: cols) / 2
        let halfH = MapScale.worldHeight(rows: rows) / 2
        /// Kontinuirane koordinate: 0 = rub mape, centar ćelije N je N+0.5.
        /// Građevina 5×5 stoji na centru (row+2.5, col+2.5); jastuci su na ±1.5 od toga.
        func worldContinuous(row: Double, col: Double, y: CGFloat) -> SCNVector3 {
            SCNVector3(
                CGFloat(col) * cell - halfW,
                y,
                CGFloat(row) * cell - halfH
            )
        }
        /// Isti raspored kao BuildingShapes.lager spots (±1.5, ±1.5).
        func padCenter(store: Placement, bay: LagerPlan.Bay) -> (row: Double, col: Double) {
            let midRow = Double(store.row) + Double(store.height) / 2
            let midCol = Double(store.col) + Double(store.width) / 2
            let spot: (x: Double, z: Double)
            switch (bay.row, bay.col) {
            case (0, 0): spot = (-1.5, -1.5)
            case (0, 3): spot = (1.5, -1.5)
            case (3, 0): spot = (-1.5, 1.5)
            default: spot = (1.5, 1.5)
            }
            return (midRow + spot.z, midCol + spot.x)
        }

        let stores = gameState.gameMap.placements.filter {
            $0.objectId == Lager.objectId && !$0.isDestroyed
        }
        var byOwner: [String: [Placement]] = [:]
        for store in stores {
            let owner = gameState.owner(of: store) ?? gameState.playerSeat?.id ?? ""
            byOwner[owner, default: []].append(store)
        }

        for (owner, list) in byOwner {
            let ordered = list.sorted {
                gameState.buildingBirthRank($0.id) < gameState.buildingBirthRank($1.id)
            }
            var free: [(Placement, LagerPlan.Bay)] = []
            for store in ordered {
                for bay in LagerPlan.bays { free.append((store, bay)) }
            }
            var cursor = 0
            for good in Good.allCases where good != .gold {
                var left = gameState.goodAmount(good, of: owner)
                guard left > 0 else { continue }
                let limit = max(1, WarehouseSpotNotebook.limit(for: good))
                while left > 0, cursor < free.count {
                    let n = min(limit, left)
                    let (store, bay) = free[cursor]
                    let pile = makeMarker(good, step: cell)
                    let fill = max(0.45, min(1, CGFloat(n) / CGFloat(limit)))
                    pile.scale = SCNVector3(1, fill, 1)
                    let pad = padCenter(store: store, bay: bay)
                    let surfaceY = terrainY(gameState: gameState, row: Int(pad.row), col: Int(pad.col))
                    pile.position = worldContinuous(row: pad.row, col: pad.col, y: surfaceY + 0.35)
                    pile.name = "pile-\(store.id)-\(bay.row)-\(bay.col)"
                    pile.categoryBitMask = 1
                    pile.renderingOrder = 120
                    root.addChildNode(pile)
                    left -= n
                    cursor += 1
                }
            }
        }
    }

    private static func terrainY(gameState: GameState, row: Int, col: Int) -> CGFloat {
        let map = gameState.gameMap
        guard row >= 0, col >= 0, row < map.rows, col < map.cols else { return 0 }
        return CGFloat(map.surface(row: row, col: col).center.height)
    }

    /// Oznaka na polju: daska, kamen, metal ili vreće — dovoljno visoko da se vidi s kamere.
    private static func makeMarker(_ good: Good, step: CGFloat) -> SCNNode {
        let root = SCNNode()
        root.categoryBitMask = 1
        switch good {
        case .wood:
            // Donji red: 5 dasaka jedna uz drugu. Gornji red: 5 poprečno.
            let plankH = step * 0.16
            let plankLong = step * 1.75
            let plankThick = step * 0.30
            let gap = step * 0.34
            for i in 0..<5 {
                let plank = box(width: plankLong, height: plankH, length: plankThick, material: woodMaterial)
                plank.position = SCNVector3(0, plankH * 0.5, CGFloat(i - 2) * gap)
                root.addChildNode(plank)
            }
            for i in 0..<5 {
                let plank = box(width: plankThick, height: plankH, length: plankLong, material: woodMaterial)
                plank.position = SCNVector3(CGFloat(i - 2) * gap, plankH * 1.5, 0)
                root.addChildNode(plank)
            }
        case .stone:
            let lower = box(width: step * 1.7, height: step * 0.75, length: step * 1.55, material: stoneMaterial)
            lower.position = SCNVector3(0, step * 0.38, 0)
            let upper = box(width: step * 1.25, height: step * 0.6, length: step * 1.1, material: stoneMaterial)
            upper.position = SCNVector3(step * 0.1, step * 0.95, step * -0.06)
            upper.eulerAngles.y = 0.18
            root.addChildNode(lower)
            root.addChildNode(upper)
        case .iron:
            for i in 0..<5 {
                let bar = box(width: step * 1.45, height: step * 0.12, length: step * 0.38, material: ironMaterial)
                bar.position = SCNVector3(0, step * 0.12 * (CGFloat(i) + 0.5), CGFloat(i - 2) * step * 0.02)
                bar.eulerAngles.y = 0.08
                root.addChildNode(bar)
            }
        case .flour:
            let cloth = solid(NSColor(red: 0.93, green: 0.88, blue: 0.74, alpha: 1))
            let tie = solid(NSColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1))
            let spots: [(CGFloat, CGFloat)] = [(-0.28, 0.05), (0.22, -0.12), (0.02, 0.22)]
            for (i, spot) in spots.enumerated() {
                let sack = SCNNode()
                let body = SCNSphere(radius: step * 0.38)
                body.materials = [cloth]
                let bodyNode = SCNNode(geometry: body)
                bodyNode.scale = SCNVector3(1.05, 1.35, 0.82)
                bodyNode.categoryBitMask = 1
                let neck = SCNCylinder(radius: step * 0.08, height: step * 0.16)
                neck.materials = [tie]
                let neckNode = SCNNode(geometry: neck)
                neckNode.position = SCNVector3(0, step * 0.45, 0)
                neckNode.categoryBitMask = 1
                sack.addChildNode(bodyNode)
                sack.addChildNode(neckNode)
                sack.position = SCNVector3(spot.0 * step, step * 0.4, spot.1 * step)
                sack.eulerAngles.z = i == 1 ? 0.18 : -0.08
                root.addChildNode(sack)
            }
        default:
            let crate = box(width: step * 1.0, height: step * 0.7, length: step * 1.0, material: solid(crateColor(good)))
            crate.position = SCNVector3(0, step * 0.35, 0)
            root.addChildNode(crate)
        }
        return root
    }

    private static func box(width: CGFloat, height: CGFloat, length: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: min(width, length) * 0.02)
        geometry.materials = Array(repeating: material, count: 6)
        let node = SCNNode(geometry: geometry)
        node.categoryBitMask = 1
        return node
    }

    private static func crateColor(_ good: Good) -> NSColor {
        switch good {
        case .wheat: return NSColor(red: 0.78, green: 0.64, blue: 0.28, alpha: 1)
        case .flour: return NSColor(red: 0.86, green: 0.82, blue: 0.72, alpha: 1)
        case .beer: return NSColor(red: 0.62, green: 0.42, blue: 0.16, alpha: 1)
        case .hay: return NSColor(red: 0.74, green: 0.62, blue: 0.24, alpha: 1)
        case .wool: return NSColor(red: 0.82, green: 0.80, blue: 0.74, alpha: 1)
        case .corn: return NSColor(red: 0.86, green: 0.72, blue: 0.22, alpha: 1)
        case .grapes: return NSColor(red: 0.42, green: 0.18, blue: 0.38, alpha: 1)
        case .honey: return NSColor(red: 0.86, green: 0.62, blue: 0.16, alpha: 1)
        case .wax: return NSColor(red: 0.90, green: 0.78, blue: 0.42, alpha: 1)
        case .candle: return NSColor(red: 0.92, green: 0.86, blue: 0.62, alpha: 1)
        case .wine: return NSColor(red: 0.42, green: 0.10, blue: 0.16, alpha: 1)
        case .spirits: return NSColor(red: 0.72, green: 0.78, blue: 0.74, alpha: 1)
        default: return NSColor(red: 0.55, green: 0.36, blue: 0.18, alpha: 1)
        }
    }

    private static let woodMaterial = textured(
        color: "Wood096_1K-JPG_Color",
        fallback: NSColor(red: 0.72, green: 0.52, blue: 0.28, alpha: 1)
    )
    private static let stoneMaterial = textured(
        color: "Rock030_1K-JPG_Color",
        fallback: NSColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
    )
    private static let ironMaterial = textured(
        color: "Metal053C_1K-JPG_Color",
        fallback: NSColor(red: 0.45, green: 0.47, blue: 0.50, alpha: 1)
    )

    private static func solid(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.ambient.contents = color
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        return mat
    }

    private static func textured(color: String, fallback: NSColor) -> SCNMaterial {
        let mat = solid(fallback)
        if let image = image(color) {
            mat.diffuse.contents = image
        }
        return mat
    }

    private static func image(_ name: String) -> NSImage? {
        let folders: [String?] = [nil, "Core/Objects/Textures/goods/plank", "Core/Objects/Textures/goods/stone", "Core/Objects/Textures/goods/metal"]
        for folder in folders {
            if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: folder) {
                return NSImage(contentsOf: url)
            }
        }
        return nil
    }
}
