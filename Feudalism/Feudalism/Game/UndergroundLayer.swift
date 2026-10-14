//
//  UndergroundLayer.swift
//  Feudalism
//
//  Podzemlje: svaka mapa ima drugu razinu istih dimenzija, 10 m ispod tla.
//  Ulazi: namjenski Ulaz, rudnici i zdenci. Dolje se grade hodnik, smočnica i skladište.
//

import SceneKit
import AppKit

enum Underground {
    /// Metri između tla i poda podzemlja (= potpuno popunjena podzemna visina).
    static let depthMeters: CGFloat = UndergroundTerrain.filledHeight
    /// Prozirnost površine dok se gradi dolje.
    static let surfaceOpacity: CGFloat = 0.15
    /// Metri po jednom ponavljanju teksture stijene.
    static let metersPerRockRepeat: CGFloat = 6

    static let entranceObjectIds: Set<String> = [
        UndergroundEntrance.objectId, Iron.objectId, Stone.objectId, Well.objectId,
        UndergroundLightOpening.objectId
    ]

    static func entranceName(objectId: String) -> String {
        switch objectId {
        case Iron.objectId: return Iron.gameObject.name
        case Stone.objectId: return Stone.gameObject.name
        case Well.objectId: return Well.gameObject.name
        case UndergroundEntrance.objectId: return UndergroundEntrance.gameObject.name
        case UndergroundLightOpening.objectId: return UndergroundLightOpening.gameObject.name
        default: return "Podzemlje"
        }
    }

    /// Pod podzemlja, rub stijene i čvor za ulaze. Skriven dok se ne uđe dolje.
    static func makeLayer(mapWidth: CGFloat, mapLength: CGFloat) -> SCNNode {
        let root = SCNNode()
        root.name = "underground"
        root.categoryBitMask = 1
        root.position = SCNVector3(0, -depthMeters, 0)
        root.isHidden = true
        root.opacity = 0

        let floor = SCNBox(width: mapWidth, height: 0.2, length: mapLength, chamferRadius: 0)
        floor.materials = [undergroundSoilMaterial()]
        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "undergroundFloor"
        floorNode.position = SCNVector3(0, -0.1, 0)
        floorNode.categoryBitMask = 1
        root.addChildNode(floorNode)

        let wallHeight = depthMeters - 0.6
        let thickness: CGFloat = 1.2
        let walls: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (mapWidth + thickness * 2, thickness, 0, -mapLength / 2 - thickness / 2),
            (mapWidth + thickness * 2, thickness, 0, mapLength / 2 + thickness / 2),
            (thickness, mapLength, -mapWidth / 2 - thickness / 2, 0),
            (thickness, mapLength, mapWidth / 2 + thickness / 2, 0)
        ]
        for wall in walls {
            let box = SCNBox(width: wall.0, height: wallHeight, length: wall.1, chamferRadius: 0)
            box.materials = [rockMaterial(width: max(wall.0, wall.1), length: wallHeight, tint: 0.7)]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(wall.2, wallHeight / 2, wall.3)
            node.categoryBitMask = 1
            root.addChildNode(node)
        }

        let entrances = SCNNode()
        entrances.name = "undergroundEntrances"
        entrances.categoryBitMask = 1
        root.addChildNode(entrances)
        return root
    }

    /// Svjetlosno okno ispod svakog rudnika i zdenca.
    static func refreshEntrances(in layer: SCNNode?, placements: [Placement], rows: Int, cols: Int) {
        guard let holder = layer?.childNode(withName: "undergroundEntrances", recursively: false) else { return }
        holder.childNodes.forEach { $0.removeFromParentNode() }
        let cell = MapScale.worldUnitsPerMapCell
        let halfW = MapScale.worldWidth(cols: cols) / 2
        let halfH = MapScale.worldHeight(rows: rows) / 2
        for p in placements where entranceObjectIds.contains(p.objectId) {
            let x = (CGFloat(p.col) + CGFloat(p.width) / 2) * cell - halfW
            let z = (CGFloat(p.row) + CGFloat(p.height) / 2) * cell - halfH
            let radius = max(0.6, CGFloat(min(p.width, p.height)) * cell * 0.45)
            let kind: ShaftKind =
                p.objectId == Well.objectId ? .well
                : p.objectId == UndergroundLightOpening.objectId ? .lightOpening
                : .mine
            holder.addChildNode(makeShaft(radius: radius, at: SCNVector3(x, 0, z), kind: kind))
        }
    }

    private enum ShaftKind { case mine, well, lightOpening }

    private static func makeShaft(radius: CGFloat, at position: SCNVector3, kind: ShaftKind) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.categoryBitMask = 1

        let glowColor: NSColor
        switch kind {
        case .well:
            glowColor = NSColor(red: 0.45, green: 0.75, blue: 1, alpha: 1)
        case .lightOpening:
            glowColor = NSColor(red: 1, green: 0.92, blue: 0.62, alpha: 1)
        case .mine:
            glowColor = NSColor(red: 1, green: 0.78, blue: 0.42, alpha: 1)
        }

        let ring = SCNTorus(ringRadius: radius, pipeRadius: 0.08)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = glowColor
        ringMat.emission.contents = glowColor
        ringMat.lightingModel = .constant
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.06, 0)
        ringNode.categoryBitMask = 1
        node.addChildNode(ringNode)

        let beam = SCNCylinder(radius: radius * 0.9, height: depthMeters)
        let beamMat = SCNMaterial()
        beamMat.diffuse.contents = glowColor.withAlphaComponent(0.12)
        beamMat.emission.contents = glowColor.withAlphaComponent(0.18)
        beamMat.lightingModel = .constant
        beamMat.blendMode = .add
        beamMat.isDoubleSided = true
        beamMat.writesToDepthBuffer = false
        beam.materials = [beamMat]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, depthMeters / 2, 0)
        beamNode.categoryBitMask = 1
        node.addChildNode(beamNode)

        let pool = SCNPlane(width: radius * 5, height: radius * 5)
        let poolMat = SCNMaterial()
        poolMat.diffuse.contents = glowImage(color: glowColor)
        poolMat.lightingModel = .constant
        poolMat.blendMode = .add
        poolMat.writesToDepthBuffer = false
        pool.materials = [poolMat]
        let poolNode = SCNNode(geometry: pool)
        poolNode.eulerAngles.x = -.pi / 2
        poolNode.position = SCNVector3(0, 0.03, 0)
        poolNode.categoryBitMask = 1
        node.addChildNode(poolNode)
        return node
    }

    /// Mekani krug svjetla na podu, bez pravog SCNLight-a (previše svjetala ruši Metal validaciju).
    private static func glowImage(color: NSColor) -> NSImage {
        let side: CGFloat = 128
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let gradient = NSGradient(colors: [color.withAlphaComponent(0.55), color.withAlphaComponent(0)])
        gradient?.draw(in: NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: side, height: side)), relativeCenterPosition: .zero)
        image.unlockFocus()
        return image
    }

    private static func undergroundSoilMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = EarthTiles.undergroundFloorImage()
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.mipFilter = .linear
        mat.lightingModel = .blinn
        mat.locksAmbientWithDiffuse = true
        mat.isDoubleSided = true
        return mat
    }

    private static func rockMaterial(width: CGFloat, length: CGFloat, tint: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = rockImage
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.mipFilter = .linear
        mat.diffuse.maxAnisotropy = 16
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(width / metersPerRockRepeat, length / metersPerRockRepeat, 1)
        mat.multiply.contents = NSColor(white: tint, alpha: 1)
        mat.emission.contents = rockImage
        mat.emission.wrapS = .repeat
        mat.emission.wrapT = .repeat
        mat.emission.intensity = 0.35
        mat.emission.contentsTransform = mat.diffuse.contentsTransform
        mat.lightingModel = .blinn
        mat.locksAmbientWithDiffuse = true
        return mat
    }

    private static let rockImage: NSImage = {
        let side = 256
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor(red: 0.2, green: 0.17, blue: 0.14, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        var seed: UInt64 = 0x5EED_CAFE
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
        }
        for _ in 0..<900 {
            let x = next() * CGFloat(side)
            let y = next() * CGFloat(side)
            let r = 2 + next() * 14
            let shade = 0.1 + next() * 0.2
            NSColor(red: shade * 1.15, green: shade, blue: shade * 0.85, alpha: 0.45).setFill()
            for dx in [-CGFloat(side), 0, CGFloat(side)] {
                for dy in [-CGFloat(side), 0, CGFloat(side)] {
                    NSBezierPath(ovalIn: NSRect(x: x + dx - r, y: y + dy - r * 0.7, width: r * 2, height: r * 1.4)).fill()
                }
            }
        }
        image.unlockFocus()
        return image
    }()
}
