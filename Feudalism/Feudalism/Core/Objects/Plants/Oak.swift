//
//  Oak.swift
//  Feudalism
//
//  Veliki hrast: debelo deblo i široka krošnja. 4×4, ~12 m. Može se posjeći.
//

import Foundation
import SceneKit
import AppKit

enum Oak: PlaceableSceneKitObject {
    static let objectId = "object_oak"
    static let displayCode = "HR"

    static var gameObject: GameObject {
        let d = ObjectDimensions.oak
        return GameObject(id: objectId, name: "Hrast", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "oak"
        let height = PlaceholderBox.heightCells(ObjectDimensions.oak.heightCells)
        let unit = height / 12

        let bark = HarvestTrees.material(NSColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1))
        let dark = HarvestTrees.material(NSColor(red: 0.12, green: 0.30, blue: 0.10, alpha: 1))
        let mid = HarvestTrees.material(NSColor(red: 0.20, green: 0.42, blue: 0.14, alpha: 1))
        let light = HarvestTrees.material(NSColor(red: 0.32, green: 0.52, blue: 0.18, alpha: 1))

        let flare = SCNCone(topRadius: 0.42 * unit, bottomRadius: 0.72 * unit, height: 0.45 * unit)
        flare.radialSegmentCount = 10
        flare.materials = [bark]
        let flareNode = SCNNode(geometry: flare)
        flareNode.position = SCNVector3(0, 0.22 * unit, 0)
        container.addChildNode(flareNode)

        let trunkHeight = 5.4 * unit
        let trunk = SCNCone(topRadius: 0.28 * unit, bottomRadius: 0.55 * unit, height: trunkHeight)
        trunk.radialSegmentCount = 10
        trunk.materials = [bark]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 0.4 * unit + trunkHeight / 2, 0)
        trunkNode.eulerAngles.z = 0.03
        container.addChildNode(trunkNode)

        let branches: [(y: CGFloat, yaw: CGFloat, tilt: CGFloat, length: CGFloat)] = [
            (4.2, 0.2, 0.95, 2.4),
            (4.8, 1.8, 0.85, 2.1),
            (5.4, 3.4, 0.8, 1.9),
            (6.0, 5.0, 0.7, 1.6),
        ]
        for branch in branches {
            let geo = SCNCylinder(radius: 0.12 * unit, height: branch.length * unit)
            geo.radialSegmentCount = 6
            geo.materials = [bark]
            let node = SCNNode(geometry: geo)
            node.pivot = SCNMatrix4MakeTranslation(0, -branch.length * unit / 2, 0)
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, branch.y * unit, 0)
            pivot.eulerAngles.y = branch.yaw
            node.eulerAngles.z = branch.tilt
            pivot.addChildNode(node)
            container.addChildNode(pivot)
        }

        let clumps: [(x: CGFloat, y: CGFloat, z: CGFloat, r: CGFloat, mat: SCNMaterial)] = [
            (0, 8.2, 0, 2.4, mid),
            (1.6, 7.4, 0.6, 1.7, dark),
            (-1.5, 7.6, -0.7, 1.8, dark),
            (0.4, 7.2, -1.7, 1.5, mid),
            (-0.5, 7.3, 1.6, 1.6, mid),
            (1.2, 9.4, 0.3, 1.4, light),
            (-1.1, 9.1, -0.5, 1.3, light),
            (0, 10.2, 0, 1.2, light),
        ]
        for clump in clumps {
            let sphere = SCNSphere(radius: clump.r * unit)
            sphere.segmentCount = 12
            sphere.materials = [clump.mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(clump.x * unit, clump.y * unit, clump.z * unit)
            node.scale = SCNVector3(1, 0.78, 1)
            container.addChildNode(node)
        }
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
