//
//  WarehouseStacks.swift
//  Feudalism
//
//  Jedno polje 2×2 = jedan resurs. Kupnja diže hrpu, prodaja je spušta.
//  Hrpe se crte u "warehouse_stock" unutar modela skladišta (kao košare u smočnici).
//

import Foundation
import SceneKit
import AppKit

enum WarehouseStacks {
    /// Lokalni centri polja 2×2 u modelu lagera (isti raspored kao padovi u BuildingShapes.lager).
    private static let baySpots: [(bay: LagerPlan.Bay, x: CGFloat, z: CGFloat)] = [
        (LagerPlan.Bay(row: 0, col: 0), -1.5, -1.5),
        (LagerPlan.Bay(row: 0, col: 3), 1.5, -1.5),
        (LagerPlan.Bay(row: 3, col: 0), -1.5, 1.5),
        (LagerPlan.Bay(row: 3, col: 3), 1.5, 1.5)
    ]

    /// Visina vrha jastuka u modelu (base + pad).
    private static let padTopY: CGFloat = 0.21

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

    /// Osvježi hrpe u svim skladištima pod `placements` čvorom. Samo main thread.
    static func refresh(in root: SCNNode, gameState: GameState) {
        let stores = gameState.gameMap.placements
            .filter { $0.objectId == Lager.objectId && !$0.isDestroyed }
            .sorted { gameState.buildingBirthRank($0.id) < gameState.buildingBirthRank($1.id) }

        var byOwner: [String: [Placement]] = [:]
        for store in stores {
            let owner = gameState.owner(of: store) ?? gameState.playerSeat?.id ?? ""
            byOwner[owner, default: []].append(store)
        }

        var assignment: [String: [(bay: LagerPlan.Bay, good: Good, amount: Int)]] = [:]
        for (owner, list) in byOwner {
            var free: [(storeId: String, bay: LagerPlan.Bay)] = []
            for store in list {
                for bay in LagerPlan.bays { free.append((store.id, bay)) }
            }
            var cursor = 0
            for good in Good.allCases where good != .gold {
                var left = gameState.goodAmount(good, of: owner)
                guard left > 0 else { continue }
                let limit = max(1, WarehouseSpotNotebook.limit(for: good))
                while left > 0, cursor < free.count {
                    let n = min(limit, left)
                    let spot = free[cursor]
                    assignment[spot.storeId, default: []].append((spot.bay, good, n))
                    left -= n
                    cursor += 1
                }
            }
        }

        root.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("lager_place_") else { return }
            let id = String(name.dropFirst("lager_place_".count))
            guard let host = node.childNode(withName: "lager", recursively: true) else { return }
            let stock: SCNNode
            if let existing = host.childNode(withName: "warehouse_stock", recursively: false) {
                stock = existing
            } else {
                let created = SCNNode()
                created.name = "warehouse_stock"
                host.addChildNode(created)
                stock = created
            }
            fill(stock: stock, piles: assignment[id] ?? [])
        }
    }

    private static func fill(stock: SCNNode, piles: [(bay: LagerPlan.Bay, good: Good, amount: Int)]) {
        let step = BuildingKit.cell
        let sig = piles
            .map { "\($0.bay.row),\($0.bay.col):\($0.good.rawValue):\($0.amount)" }
            .sorted()
            .joined(separator: "|")
        let markName = "wsig"
        if let mark = stock.childNode(withName: markName, recursively: false),
           mark.childNodes.first?.name == sig {
            return
        }
        stock.childNodes.forEach { $0.removeFromParentNode() }
        let mark = SCNNode()
        mark.name = markName
        let tag = SCNNode()
        tag.name = sig.isEmpty ? "-" : sig
        mark.addChildNode(tag)
        stock.addChildNode(mark)

        for pile in piles {
            guard let spot = baySpots.first(where: { $0.bay == pile.bay }) else { continue }
            let marker = makeMarker(pile.good, step: step)
            let limit = max(1, WarehouseSpotNotebook.limit(for: pile.good))
            let fill = max(0.35, min(1, CGFloat(pile.amount) / CGFloat(limit)))
            marker.scale = SCNVector3(1, fill, 1)
            marker.position = SCNVector3(spot.x * step, padTopY * step, spot.z * step)
            marker.name = "pile-\(pile.bay.row)-\(pile.bay.col)"
            marker.categoryBitMask = 0
            marker.renderingOrder = 50
            stock.addChildNode(marker)
        }
    }

    /// Oznaka na polju: daska, kamen, metal ili vreće brašna.
    private static func makeMarker(_ good: Good, step: CGFloat) -> SCNNode {
        let root = SCNNode()
        root.categoryBitMask = 0
        switch good {
        case .wood:
            for i in 0..<6 {
                let plank = box(width: step * 1.55, height: step * 0.09, length: step * 0.78, material: woodMaterial)
                plank.position = SCNVector3(0, step * 0.09 * (CGFloat(i) + 0.5), 0)
                plank.eulerAngles.y = i.isMultiple(of: 2) ? 0.05 : -0.07
                root.addChildNode(plank)
            }
        case .stone:
            let lower = box(width: step * 1.25, height: step * 0.42, length: step * 1.05, material: stoneMaterial)
            lower.position = SCNVector3(0, step * 0.21, 0)
            let upper = box(width: step * 0.85, height: step * 0.32, length: step * 0.7, material: stoneMaterial)
            upper.position = SCNVector3(step * 0.12, step * 0.58, step * -0.08)
            upper.eulerAngles.y = 0.2
            root.addChildNode(lower)
            root.addChildNode(upper)
        case .iron:
            for i in 0..<5 {
                let bar = box(width: step * 1.4, height: step * 0.08, length: step * 0.32, material: ironMaterial)
                bar.position = SCNVector3(0, step * 0.08 * (CGFloat(i) + 0.5), CGFloat(i - 2) * step * 0.015)
                bar.eulerAngles.y = 0.08
                root.addChildNode(bar)
            }
        case .flour:
            let cloth = solid(NSColor(red: 0.93, green: 0.88, blue: 0.74, alpha: 1))
            let tie = solid(NSColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1))
            let spots: [(CGFloat, CGFloat)] = [(-0.28, 0.05), (0.22, -0.12), (0.02, 0.22)]
            for (i, spot) in spots.enumerated() {
                let sack = SCNNode()
                let body = SCNSphere(radius: step * 0.32)
                body.materials = [cloth]
                let bodyNode = SCNNode(geometry: body)
                bodyNode.scale = SCNVector3(1.05, 1.35, 0.82)
                bodyNode.categoryBitMask = 0
                let neck = SCNCylinder(radius: step * 0.07, height: step * 0.14)
                neck.materials = [tie]
                let neckNode = SCNNode(geometry: neck)
                neckNode.position = SCNVector3(0, step * 0.38, 0)
                neckNode.categoryBitMask = 0
                sack.addChildNode(bodyNode)
                sack.addChildNode(neckNode)
                sack.position = SCNVector3(spot.0 * step, step * 0.34, spot.1 * step)
                sack.eulerAngles.z = i == 1 ? 0.18 : -0.08
                root.addChildNode(sack)
            }
        default:
            let crate = box(width: step * 0.9, height: step * 0.55, length: step * 0.9, material: solid(crateColor(good)))
            crate.position = SCNVector3(0, step * 0.28, 0)
            root.addChildNode(crate)
        }
        return root
    }

    private static func box(width: CGFloat, height: CGFloat, length: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: min(width, length) * 0.02)
        geometry.materials = Array(repeating: material, count: 6)
        let node = SCNNode(geometry: geometry)
        node.categoryBitMask = 0
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
