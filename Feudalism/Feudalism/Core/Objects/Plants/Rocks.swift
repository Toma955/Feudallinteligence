//
//  Rocks.swift
//  Feudalism
//
//  Kamen mali / srednji / veliki. Kamena boja, kasnije modeli.
//

import Foundation
import SceneKit
import AppKit

enum RockPalette {
    static let light = NSColor(red: 0.62, green: 0.58, blue: 0.52, alpha: 1)
    static let mid = NSColor(red: 0.48, green: 0.45, blue: 0.40, alpha: 1)
    static let dark = NSColor(red: 0.34, green: 0.32, blue: 0.28, alpha: 1)

    static func addBoulders(to container: SCNNode, scale: CGFloat, clumps: [(x: CGFloat, y: CGFloat, z: CGFloat, sx: CGFloat, sy: CGFloat, sz: CGFloat, yaw: CGFloat, color: NSColor)]) {
        for clump in clumps {
            let sphere = SCNSphere(radius: 0.5 * scale)
            sphere.segmentCount = 10
            sphere.materials = [HarvestTrees.material(clump.color, roughness: 0.95)]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(clump.x * scale, clump.y * scale, clump.z * scale)
            node.scale = SCNVector3(clump.sx, clump.sy, clump.sz)
            node.eulerAngles.y = clump.yaw
            container.addChildNode(node)
        }
    }
}

enum SmallRock: PlaceableSceneKitObject {
    static let objectId = "object_rock_small"
    static let displayCode = "KM"

    static var gameObject: GameObject {
        let d = ObjectDimensions.rockSmall
        return GameObject(id: objectId, name: "Mali kamen", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "rock_small"
        let scale = PlaceholderBox.heightCells(ObjectDimensions.rockSmall.heightCells)
        RockPalette.addBoulders(to: container, scale: scale, clumps: [
            (0, 0.42, 0, 1.6, 0.85, 1.3, 0.3, RockPalette.mid),
            (0.35, 0.28, 0.15, 0.9, 0.55, 0.8, 1.1, RockPalette.dark),
            (-0.25, 0.22, -0.2, 0.7, 0.45, 0.7, 2.2, RockPalette.light),
        ])
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum MediumRock: PlaceableSceneKitObject {
    static let objectId = "object_rock_medium"
    static let displayCode = "KS"

    static var gameObject: GameObject {
        let d = ObjectDimensions.rockMedium
        return GameObject(id: objectId, name: "Srednji kamen", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "rock_medium"
        let scale = PlaceholderBox.heightCells(ObjectDimensions.rockMedium.heightCells) / 2
        RockPalette.addBoulders(to: container, scale: scale, clumps: [
            (0, 0.7, 0, 2.4, 1.35, 2.0, 0.2, RockPalette.mid),
            (0.7, 0.45, 0.35, 1.4, 0.85, 1.2, 0.9, RockPalette.dark),
            (-0.65, 0.4, -0.4, 1.3, 0.75, 1.1, 2.4, RockPalette.light),
            (0.15, 1.05, -0.25, 1.1, 0.7, 1.0, 1.6, RockPalette.dark),
            (-0.2, 0.35, 0.7, 1.0, 0.55, 0.9, 0.5, RockPalette.light),
        ])
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum LargeRock: PlaceableSceneKitObject {
    static let objectId = "object_rock_large"
    static let displayCode = "KV"

    static var gameObject: GameObject {
        let d = ObjectDimensions.rockLarge
        return GameObject(id: objectId, name: "Veliki kamen", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "rock_large"
        let scale = PlaceholderBox.heightCells(ObjectDimensions.rockLarge.heightCells) / 4
        RockPalette.addBoulders(to: container, scale: scale, clumps: [
            (0, 1.1, 0, 3.6, 2.1, 3.0, 0.15, RockPalette.mid),
            (1.2, 0.7, 0.6, 2.0, 1.2, 1.8, 0.8, RockPalette.dark),
            (-1.1, 0.65, -0.7, 1.9, 1.1, 1.7, 2.1, RockPalette.light),
            (0.3, 1.85, -0.4, 1.8, 1.15, 1.6, 1.4, RockPalette.dark),
            (-0.5, 0.55, 1.2, 1.6, 0.9, 1.4, 0.4, RockPalette.light),
            (0.9, 1.5, 0.7, 1.4, 0.95, 1.3, 2.6, RockPalette.mid),
            (-0.8, 1.4, 0.3, 1.3, 0.85, 1.2, 3.4, RockPalette.dark),
        ])
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
