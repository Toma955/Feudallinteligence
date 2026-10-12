//
//  Fir.swift
//  Feudalism
//
//  Jela: slojevi čunjeva. 2×2, ~9 m. Može se posjeći.
//

import Foundation
import SceneKit
import AppKit

enum Fir: PlaceableSceneKitObject {
    static let objectId = "object_fir"
    static let displayCode = "JE"

    static var gameObject: GameObject {
        let d = ObjectDimensions.fir
        return GameObject(id: objectId, name: "Jela", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "fir"
        let height = PlaceholderBox.heightCells(ObjectDimensions.fir.heightCells)
        let unit = height / 9

        let bark = HarvestTrees.material(NSColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1))
        let dark = HarvestTrees.material(NSColor(red: 0.10, green: 0.28, blue: 0.14, alpha: 1))
        let mid = HarvestTrees.material(NSColor(red: 0.16, green: 0.38, blue: 0.18, alpha: 1))
        let light = HarvestTrees.material(NSColor(red: 0.22, green: 0.46, blue: 0.22, alpha: 1))

        let trunk = SCNCylinder(radius: 0.16 * unit, height: 2.4 * unit)
        trunk.radialSegmentCount = 8
        trunk.materials = [bark]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 1.2 * unit, 0)
        container.addChildNode(trunkNode)

        let layers: [(y: CGFloat, bottom: CGFloat, top: CGFloat, h: CGFloat, mat: SCNMaterial)] = [
            (2.6, 1.55, 0.55, 2.0, dark),
            (4.2, 1.25, 0.40, 2.0, mid),
            (5.8, 0.95, 0.28, 1.8, mid),
            (7.2, 0.62, 0.08, 1.7, light),
        ]
        for layer in layers {
            let cone = SCNCone(topRadius: layer.top * unit, bottomRadius: layer.bottom * unit, height: layer.h * unit)
            cone.radialSegmentCount = 10
            cone.materials = [layer.mat]
            let node = SCNNode(geometry: cone)
            node.position = SCNVector3(0, layer.y * unit, 0)
            container.addChildNode(node)
        }
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
