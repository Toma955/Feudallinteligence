//
//  Palm.swift
//  Feudalism
//
//  Palma: vitko deblo i kruna od perja. 2×2, ~8 m. Može se posjeći.
//

import Foundation
import SceneKit
import AppKit

enum Palm: PlaceableSceneKitObject {
    static let objectId = "object_palm"
    static let displayCode = "PA"

    static var gameObject: GameObject {
        let d = ObjectDimensions.palm
        return GameObject(id: objectId, name: "Palma", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "palm"
        let height = PlaceholderBox.heightCells(ObjectDimensions.palm.heightCells)
        let unit = height / 8

        let bark = HarvestTrees.material(NSColor(red: 0.48, green: 0.32, blue: 0.16, alpha: 1))
        let dark = HarvestTrees.material(NSColor(red: 0.16, green: 0.42, blue: 0.16, alpha: 1))
        let mid = HarvestTrees.material(NSColor(red: 0.26, green: 0.54, blue: 0.20, alpha: 1))
        let light = HarvestTrees.material(NSColor(red: 0.40, green: 0.66, blue: 0.24, alpha: 1))

        let trunk = SCNCone(topRadius: 0.10 * unit, bottomRadius: 0.22 * unit, height: 5.6 * unit)
        trunk.radialSegmentCount = 8
        trunk.materials = [bark]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 2.8 * unit, 0)
        trunkNode.eulerAngles.z = 0.06
        container.addChildNode(trunkNode)

        let crown = SCNSphere(radius: 0.28 * unit)
        crown.segmentCount = 10
        crown.materials = [mid]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, 5.7 * unit, 0)
        container.addChildNode(crownNode)

        for i in 0..<7 {
            let yaw = CGFloat(i) * (.pi * 2 / 7)
            let frond = SCNCone(topRadius: 0.02 * unit, bottomRadius: 0.28 * unit, height: 2.1 * unit)
            frond.radialSegmentCount = 6
            frond.materials = [i % 2 == 0 ? dark : light]
            let node = SCNNode(geometry: frond)
            node.pivot = SCNMatrix4MakeTranslation(0, -1.05 * unit, 0)
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, 5.75 * unit, 0)
            pivot.eulerAngles.y = yaw
            node.eulerAngles.z = 1.15
            pivot.addChildNode(node)
            container.addChildNode(pivot)
        }
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
