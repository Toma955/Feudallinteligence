//
//  AppleBasketShapes.swift
//  Feudalism
//
//  Jabuka je model 3DApple001. Košara je pletena (Wicker007A) s nekoliko jabuka.
//  Teksture: Core/Objects/Textures/goods/apple_basket/apple i .../basket.
//

import Foundation
import SceneKit
import AppKit

enum AppleBasketShapes {
    private static var appleTemplate: SCNNode?

    /// Jedna jabuka, dno na y = 0. Na farmi i u košari.
    static func apple() -> SCNNode {
        if appleTemplate == nil {
            let model = loadAppleModel() ?? proceduralApple()
            sitOnGround(model)
            let holder = SCNNode()
            holder.name = "apple"
            holder.addChildNode(model)
            appleTemplate = holder
        }
        return appleTemplate!.clone()
    }

    static func apple(height: CGFloat) -> SCNNode {
        let node = apple()
        fitHeight(node, to: height)
        return node
    }

    private static var filledTemplate: SCNNode?

    /// Košara s nekoliko jabuka. Jedna košara = jedna mjera hrane.
    static func appleBasket() -> SCNNode {
        if filledTemplate == nil {
            filledTemplate = makeFilledBasket()
        }
        return filledTemplate!.clone()
    }

    private static func makeFilledBasket() -> SCNNode {
        let root = basket()
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0.42, 0),
            (0.18, 0.40, 0.06),
            (-0.16, 0.40, 0.1),
            (0.06, 0.40, -0.18),
            (-0.08, 0.40, -0.12),
            (0.2, 0.42, -0.12),
            (-0.2, 0.42, -0.04),
            (0, 0.58, 0.08),
            (0.12, 0.56, -0.06),
            (-0.1, 0.56, 0.02),
            (0.02, 0.72, 0)
        ]
        for spot in spots {
            let fruit = apple(height: 0.22)
            fruit.position = SCNVector3(spot.0, spot.1, spot.2)
            fruit.eulerAngles.y = spot.0 * 5
            root.addChildNode(fruit)
        }
        return root
    }

    /// Ista pletena košara, unutra jaja.
    static func eggBasket() -> SCNNode {
        let root = basket()
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0.28, 0),
            (0.22, 0.26, 0.08),
            (-0.2, 0.26, 0.1),
            (0.08, 0.26, -0.22),
            (-0.1, 0.26, -0.16),
            (0.16, 0.42, -0.06),
            (-0.14, 0.42, 0.02),
            (0, 0.44, 0.14)
        ]
        for spot in spots {
            let egg = SCNSphere(radius: 0.11)
            egg.segmentCount = 16
            egg.materials = [eggShell()]
            let node = SCNNode(geometry: egg)
            node.scale = SCNVector3(0.82, 1.15, 0.82)
            node.position = SCNVector3(spot.0, spot.1, spot.2)
            node.eulerAngles = SCNVector3(0.4, spot.0 * 3, 0.15)
            root.addChildNode(node)
        }
        return root
    }

    private static func eggShell() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.94, green: 0.90, blue: 0.82, alpha: 1)
        mat.roughness.contents = NSNumber(value: 0.45)
        mat.lightingModel = .physicallyBased
        return mat
    }

    static func appleBasket(height: CGFloat) -> SCNNode {
        let node = appleBasket()
        fitHeight(node, to: height)
        return node
    }

    static func stockKey(_ gameState: GameState) -> String {
        let stores = gameState.gameMap.placements.filter { $0.objectId == Smocnica.objectId && !$0.isDestroyed }
        var left: [String: Int] = [:]
        var parts: [String] = ["v\(gameState.placementsVersion)"]
        for placement in stores.sorted(by: { $0.id < $1.id }) {
            let owner = gameState.owner(of: placement) ?? ""
            if left[owner] == nil { left[owner] = foodUnits(of: owner, gameState: gameState) }
            let give = min(PantryGrid.capacity, max(0, left[owner] ?? 0))
            left[owner] = (left[owner] ?? 0) - give
            parts.append("\(placement.id):\(give)")
        }
        return parts.joined(separator: "|")
    }

    static func refreshPantries(in root: SCNNode, gameState: GameState) {
        let stores = gameState.gameMap.placements.filter { $0.objectId == Smocnica.objectId && !$0.isDestroyed }
        var left: [String: Int] = [:]
        var counts: [String: Int] = [:]
        for placement in stores.sorted(by: { $0.id < $1.id }) {
            let owner = gameState.owner(of: placement) ?? ""
            if left[owner] == nil { left[owner] = foodUnits(of: owner, gameState: gameState) }
            let give = min(PantryGrid.capacity, max(0, left[owner] ?? 0))
            left[owner] = (left[owner] ?? 0) - give
            counts[placement.id] = give
        }
        root.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("smocnica_place_") else { return }
            let id = String(name.dropFirst("smocnica_place_".count))
            guard let host = node.childNode(withName: "smocnica", recursively: true) else { return }
            updateStock(on: host, count: counts[id] ?? 0)
        }
    }

    /// Jabuke, sir, kruh i ostala hrana zbrajaju se u istu mjeru. Svaka jedinica je jedna košara.
    private static func foodUnits(of faction: String, gameState: GameState) -> Int {
        var total = gameState.goodAmount(.food, of: faction)
        for good in StorageKind.pantry.goods {
            total += gameState.goodAmount(good, of: faction)
        }
        return total
    }

    private static func updateStock(on host: SCNNode, count: Int) {
        let amount = min(max(0, count), PantryGrid.capacity)
        let stock: SCNNode
        if let existing = host.childNode(withName: "pantry_stock", recursively: false) {
            stock = existing
        } else {
            stock = SCNNode()
            stock.name = "pantry_stock"
            host.addChildNode(stock)
        }
        let have = stock.childNodes.count
        if amount < have {
            let layout = slotLayout()
            let settled = settledScale(slotHeight: layout.slotY)
            for child in stock.childNodes.prefix(have - amount) {
                let start = child.presentation.position
                child.removeAllActions()
                child.removeFromParentNode()
                child.position = start
                host.addChildNode(child)
                let away = SCNAction.group([
                    SCNAction.moveBy(x: 0, y: layout.slotY, z: 0, duration: 0.22),
                    SCNAction.scale(to: 0.04, duration: 0.22)
                ])
                away.timingMode = .easeIn
                child.runAction(SCNAction.sequence([away, .removeFromParentNode()]))
            }
            for (index, child) in stock.childNodes.enumerated() {
                child.removeAllActions()
                child.scale = settled
                let place = slotPosition(index, layout: layout)
                let slide = SCNAction.move(to: place, duration: 0.28)
                slide.timingMode = .easeOut
                child.runAction(slide)
            }
            return
        }
        guard amount > have else { return }
        let layout = slotLayout()
        for index in have..<amount {
            let basket = appleBasket(height: layout.slotY * 0.9)
            let place = slotPosition(index, layout: layout)
            let finalScale = basket.scale
            basket.position = SCNVector3(place.x, place.y + layout.slotY, place.z)
            basket.scale = SCNVector3(0.05, 0.05, 0.05)
            let wait = SCNAction.wait(duration: Double(index - have) * 0.07)
            let drop = SCNAction.group([
                SCNAction.move(to: place, duration: 0.32),
                SCNAction.scale(to: CGFloat(finalScale.x), duration: 0.32)
            ])
            drop.timingMode = .easeOut
            basket.runAction(SCNAction.sequence([wait, drop]))
            stock.addChildNode(basket)
        }
    }

    private static var settledStockScale: SCNVector3?

    private static func settledScale(slotHeight: CGFloat) -> SCNVector3 {
        if let settledStockScale { return settledStockScale }
        let sample = appleBasket(height: slotHeight * 0.9)
        settledStockScale = sample.scale
        return sample.scale
    }

    private struct SlotLayout {
        var slotX: CGFloat
        var slotZ: CGFloat
        var slotY: CGFloat
        var floor: CGFloat
    }

    private static func slotLayout() -> SlotLayout {
        let cell = PlaceholderBox.worldUnitsPerCell
        let inner = 2.5 * cell
        return SlotLayout(
            slotX: inner / CGFloat(PantryGrid.columns),
            slotZ: inner / CGFloat(PantryGrid.rows),
            slotY: (2.15 * cell) / CGFloat(PantryGrid.levels),
            floor: 0.18 * cell
        )
    }

    private static func slotPosition(_ index: Int, layout: SlotLayout) -> SCNVector3 {
        let col = index % PantryGrid.columns
        let row = (index / PantryGrid.columns) % PantryGrid.rows
        let level = index / (PantryGrid.columns * PantryGrid.rows)
        return SCNVector3(
            (CGFloat(col) - 2.5) * layout.slotX,
            layout.floor + CGFloat(level) * layout.slotY,
            (CGFloat(row) - 2.5) * layout.slotZ
        )
    }

    private static func basket() -> SCNNode {
        let root = SCNNode()
        root.name = "apple_basket"
        let maps = loadMaps(prefix: "Wicker007A_1K-JPG")
        let fallback = NSColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1)

        let base = SCNCylinder(radius: 0.58, height: 0.08)
        base.radialSegmentCount = 24
        let baseNode = SCNNode(geometry: base)
        baseNode.position.y = 0.04
        apply(maps, fallback: fallback, to: base)
        root.addChildNode(baseNode)

        let wall = SCNTube(innerRadius: 0.46, outerRadius: 0.56, height: 0.62)
        wall.radialSegmentCount = 28
        wall.heightSegmentCount = 1
        let wallNode = SCNNode(geometry: wall)
        wallNode.position.y = 0.36
        apply(maps, fallback: fallback, to: wall)
        root.addChildNode(wallNode)

        let rim = SCNTorus(ringRadius: 0.52, pipeRadius: 0.045)
        rim.ringSegmentCount = 28
        rim.pipeSegmentCount = 10
        let rimNode = SCNNode(geometry: rim)
        rimNode.position.y = 0.66
        apply(maps, fallback: fallback, to: rim)
        root.addChildNode(rimNode)

        return root
    }

    private static func loadAppleModel() -> SCNNode? {
        let folders: [String?] = [
            nil,
            "Core/Objects/Textures/goods/apple_basket/apple",
            "Objects/Textures/goods/apple_basket/apple",
            "Textures/goods/apple_basket/apple"
        ]
        for folder in folders {
            guard let url = Bundle.main.url(forResource: "3DApple001_HQ-1K-JPG", withExtension: "obj", subdirectory: folder),
                  let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else { continue }
            let root = SCNNode()
            root.name = "apple"
            for child in scene.rootNode.childNodes {
                root.addChildNode(child.clone())
            }
            let maps = loadMaps(prefix: "3DApple001_HQ-1K-JPG")
            let red = NSColor(red: 0.78, green: 0.16, blue: 0.12, alpha: 1)
            root.enumerateHierarchy { node, _ in
                if let geo = node.geometry {
                    apply(maps, fallback: red, to: geo)
                }
            }
            return root
        }
        return nil
    }

    private static func proceduralApple() -> SCNNode {
        let root = SCNNode()
        root.name = "apple"
        let body = SCNSphere(radius: 0.5)
        body.segmentCount = 24
        let node = SCNNode(geometry: body)
        node.scale = SCNVector3(1.05, 0.9, 1.05)
        node.position.y = 0.45
        let maps = loadMaps(prefix: "3DApple001_HQ-1K-JPG")
        apply(maps, fallback: NSColor(red: 0.78, green: 0.16, blue: 0.12, alpha: 1), to: body)
        root.addChildNode(node)
        return root
    }

    private static func sitOnGround(_ node: SCNNode) {
        let (minB, _) = hierarchyBounds(node)
        node.position.y -= minB.y
    }

    private static func fitHeight(_ node: SCNNode, to height: CGFloat) {
        let (minB, maxB) = hierarchyBounds(node)
        let current = max(CGFloat(maxB.y - minB.y), 0.001)
        let scale = height / current
        node.scale = SCNVector3(scale, scale, scale)
    }

    private static func hierarchyBounds(_ node: SCNNode) -> (SCNVector3, SCNVector3) {
        var minB = SCNVector3(10_000, 10_000, 10_000)
        var maxB = SCNVector3(-10_000, -10_000, -10_000)
        var found = false
        node.enumerateHierarchy { child, _ in
            guard let geo = child.geometry else { return }
            let (cmin, cmax) = geo.boundingBox
            for x in [cmin.x, cmax.x] {
                for y in [cmin.y, cmax.y] {
                    for z in [cmin.z, cmax.z] {
                        let world = child.convertPosition(SCNVector3(x, y, z), to: node)
                        minB.x = min(minB.x, world.x)
                        minB.y = min(minB.y, world.y)
                        minB.z = min(minB.z, world.z)
                        maxB.x = max(maxB.x, world.x)
                        maxB.y = max(maxB.y, world.y)
                        maxB.z = max(maxB.z, world.z)
                        found = true
                    }
                }
            }
        }
        return found ? (minB, maxB) : (SCNVector3Zero, SCNVector3(0.2, 0.2, 0.2))
    }

    private struct Maps {
        var color: NSImage?
        var normal: NSImage?
        var roughness: NSImage?
        var occlusion: NSImage?
    }

    private static func apply(_ maps: Maps, fallback: NSColor, to geometry: SCNGeometry) {
        let mat = SCNMaterial()
        mat.diffuse.contents = maps.color ?? fallback
        mat.lightingModel = .blinn
        mat.isDoubleSided = true
        if let normal = maps.normal {
            mat.normal.contents = normal
            mat.normal.intensity = 0.45
        }
        if let roughness = maps.roughness { mat.roughness.contents = roughness }
        if let occlusion = maps.occlusion { mat.ambientOcclusion.contents = occlusion }
        for prop in [mat.diffuse, mat.normal, mat.roughness, mat.ambientOcclusion] {
            prop.wrapS = .repeat
            prop.wrapT = .repeat
        }
        geometry.materials = [mat]
    }

    private static func loadMaps(prefix: String) -> Maps {
        func image(_ suffix: String) -> NSImage? {
            let name = "\(prefix)_\(suffix)"
            let folders: [String?] = [nil, "Core/Objects/Textures/goods/apple_basket/apple", "Core/Objects/Textures/goods/apple_basket/basket"]
            for folder in folders {
                for ext in ["jpg", "jpeg", "png"] {
                    if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: folder),
                       let image = NSImage(contentsOf: url) {
                        return image
                    }
                }
            }
            return nil
        }
        return Maps(
            color: image("Color"),
            normal: image("NormalGL"),
            roughness: image("Roughness"),
            occlusion: image("AmbientOcclusion")
        )
    }
}
