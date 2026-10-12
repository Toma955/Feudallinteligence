//
//  WarehouseStacks.swift
//  Feudalism
//
//  Naslage na poljima 2×2. Daska, hmelj, kamen i željezo stoje uz prolaz,
//  ostala roba skladišta na vanjskim ćelijama istog polja.
//

import Foundation
import SceneKit
import AppKit

enum WarehouseStacks {
    private static let maxLayers = 8

    static func stockKey(_ gameState: GameState) -> String {
        let stores = gameState.gameMap.placements.filter { $0.objectId == Lager.objectId && !$0.isDestroyed }
        var seen: Set<String> = []
        var parts: [String] = ["v\(gameState.placementsVersion)"]
        for placement in stores.sorted(by: { $0.id < $1.id }) {
            let owner = gameState.owner(of: placement) ?? ""
            if seen.contains(owner) {
                parts.append("\(placement.id):-")
                continue
            }
            seen.insert(owner)
            let bits = LagerPlan.stacks.map { "\($0.good.rawValue):\(gameState.goodAmount($0.good, of: owner))" }.joined(separator: ",")
            parts.append("\(placement.id):\(bits)")
        }
        return parts.joined(separator: "|")
    }

    static func refresh(in root: SCNNode, gameState: GameState) {
        let stores = gameState.gameMap.placements.filter { $0.objectId == Lager.objectId && !$0.isDestroyed }
        var seen: Set<String> = []
        var counts: [String: [Good: Int]] = [:]
        for placement in stores.sorted(by: { $0.id < $1.id }) {
            let owner = gameState.owner(of: placement) ?? ""
            var pile: [Good: Int] = [:]
            if !seen.contains(owner) {
                seen.insert(owner)
                for spot in LagerPlan.stacks {
                    pile[spot.good] = gameState.goodAmount(spot.good, of: owner)
                }
            }
            counts[placement.id] = pile
        }
        root.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("lager_place_") else { return }
            let id = String(name.dropFirst("lager_place_".count))
            let stock = node.childNode(withName: "warehouse_stock", recursively: false) ?? {
                let made = SCNNode()
                made.name = "warehouse_stock"
                node.addChildNode(made)
                return made
            }()
            let pile = counts[id] ?? [:]
            for spot in LagerPlan.stacks {
                updatePile(spot.good, count: pile[spot.good] ?? 0, row: spot.row, col: spot.col, on: stock)
            }
        }
    }

    private static func updatePile(_ good: Good, count: Int, row: Int, col: Int, on stock: SCNNode) {
        let layers = min(max(0, count), maxLayers)
        let name = "pile_\(good.rawValue)"
        let pile: SCNNode
        if let existing = stock.childNode(withName: name, recursively: false) {
            pile = existing
        } else {
            pile = SCNNode()
            pile.name = name
            let step = PlaceholderBox.worldUnitsPerCell
            pile.position = SCNVector3((CGFloat(col) - 2) * step, 0, (CGFloat(row) - 2) * step)
            stock.addChildNode(pile)
        }
        let have = pile.childNodes.count
        if layers < have {
            for child in pile.childNodes.suffix(have - layers) {
                child.removeFromParentNode()
            }
        }
        let step = PlaceholderBox.worldUnitsPerCell
        let padTop = step * 0.21
        guard layers > have else { return }
        for index in have..<layers {
            let piece = makePiece(good, index: index, step: step)
            let height = pieceHeight(good, step: step)
            let place = SCNVector3(pieceJitter(index, step: step).x, padTop + height * (CGFloat(index) + 0.5), pieceJitter(index, step: step).z)
            let finalScale = piece.scale
            piece.position = SCNVector3(place.x, place.y + step * 0.7, place.z)
            piece.scale = SCNVector3(0.05, 0.05, 0.05)
            let wait = SCNAction.wait(duration: Double(index - have) * 0.06)
            let drop = SCNAction.group([
                SCNAction.move(to: place, duration: 0.28),
                SCNAction.scale(to: CGFloat(finalScale.x), duration: 0.28)
            ])
            drop.timingMode = .easeOut
            piece.runAction(SCNAction.sequence([wait, drop]))
            pile.addChildNode(piece)
        }
    }

    private static func pieceJitter(_ index: Int, step: CGFloat) -> (x: CGFloat, z: CGFloat) {
        let x = CGFloat((index % 3) - 1) * step * 0.04
        let z = CGFloat(((index / 3) % 3) - 1) * step * 0.04
        return (x, z)
    }

    private static func pieceHeight(_ good: Good, step: CGFloat) -> CGFloat {
        switch good {
        case .wood: return step * 0.06
        case .stone: return step * 0.22
        case .iron: return step * 0.1
        case .hop: return step * 0.16
        default: return step * 0.2
        }
    }

    private static func makePiece(_ good: Good, index: Int, step: CGFloat) -> SCNNode {
        let box: SCNBox
        let material: SCNMaterial
        switch good {
        case .wood:
            box = SCNBox(width: step * 0.62, height: step * 0.055, length: step * 0.26, chamferRadius: step * 0.008)
            material = woodMaterial
        case .stone:
            box = SCNBox(width: step * 0.4, height: step * 0.2, length: step * 0.34, chamferRadius: step * 0.02)
            material = stoneMaterial
        case .iron:
            box = SCNBox(width: step * 0.46, height: step * 0.09, length: step * 0.2, chamferRadius: step * 0.012)
            material = ironMaterial
        case .hop:
            box = SCNBox(width: step * 0.34, height: step * 0.14, length: step * 0.26, chamferRadius: step * 0.03)
            material = solid(NSColor(red: 0.34, green: 0.48, blue: 0.18, alpha: 1))
        default:
            box = SCNBox(width: step * 0.3, height: step * 0.18, length: step * 0.3, chamferRadius: step * 0.02)
            material = solid(crateColor(good))
        }
        box.materials = Array(repeating: material, count: 6)
        let node = SCNNode(geometry: box)
        node.eulerAngles.y = index.isMultiple(of: 2) ? 0.12 : -0.18
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
        normal: "Wood096_1K-JPG_NormalGL",
        rough: "Wood096_1K-JPG_Roughness",
        metal: nil,
        fallback: NSColor(red: 0.72, green: 0.52, blue: 0.28, alpha: 1)
    )
    private static let stoneMaterial = textured(
        color: "Rock030_1K-JPG_Color",
        normal: "Rock030_1K-JPG_NormalGL",
        rough: "Rock030_1K-JPG_Roughness",
        metal: nil,
        fallback: NSColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
    )
    private static let ironMaterial = textured(
        color: "Metal053C_1K-JPG_Color",
        normal: "Metal053C_1K-JPG_NormalGL",
        rough: "Metal053C_1K-JPG_Roughness",
        metal: "Metal053C_1K-JPG_Metalness",
        fallback: NSColor(red: 0.45, green: 0.47, blue: 0.50, alpha: 1)
    )

    private static func solid(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .physicallyBased
        return mat
    }

    private static func textured(color: String, normal: String, rough: String, metal: String?, fallback: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = image(color) ?? fallback
        mat.lightingModel = .physicallyBased
        if let normalImage = image(normal) {
            mat.normal.contents = normalImage
            mat.normal.intensity = 0.8
        }
        if let roughImage = image(rough) {
            mat.roughness.contents = roughImage
        }
        if let metal, let metalImage = image(metal) {
            mat.metalness.contents = metalImage
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
