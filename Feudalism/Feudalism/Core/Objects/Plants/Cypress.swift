//
//  Cypress.swift
//  Feudalism
//
//  Čempres: visok i uzak. 2×2, ~10 m. Može se posjeći.
//

import Foundation
import SceneKit
import AppKit

enum Cypress: PlaceableSceneKitObject {
    static let objectId = "object_cypress"
    static let displayCode = "ČE"

    static var gameObject: GameObject {
        let d = ObjectDimensions.cypress
        return GameObject(id: objectId, name: "Čempres", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "cypress"
        let height = PlaceholderBox.heightCells(ObjectDimensions.cypress.heightCells)
        let unit = height / 10

        let bark = HarvestTrees.material(NSColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1))
        let dark = HarvestTrees.material(NSColor(red: 0.14, green: 0.28, blue: 0.14, alpha: 1))
        let mid = HarvestTrees.material(NSColor(red: 0.20, green: 0.36, blue: 0.16, alpha: 1))
        let light = HarvestTrees.material(NSColor(red: 0.28, green: 0.44, blue: 0.18, alpha: 1))

        let trunk = SCNCylinder(radius: 0.12 * unit, height: 2.0 * unit)
        trunk.radialSegmentCount = 8
        trunk.materials = [bark]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 1.0 * unit, 0)
        container.addChildNode(trunkNode)

        let layers: [(y: CGFloat, r: CGFloat, sy: CGFloat, mat: SCNMaterial)] = [
            (3.2, 0.72, 1.8, dark),
            (5.0, 0.62, 1.7, mid),
            (6.8, 0.50, 1.5, mid),
            (8.3, 0.34, 1.3, light),
            (9.4, 0.18, 0.9, light),
        ]
        for layer in layers {
            let sphere = SCNSphere(radius: layer.r * unit)
            sphere.segmentCount = 12
            sphere.materials = [layer.mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(0, layer.y * unit, 0)
            node.scale = SCNVector3(0.55, layer.sy, 0.55)
            container.addChildNode(node)
        }
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
