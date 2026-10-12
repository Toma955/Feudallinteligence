//
//  Roof.swift
//  Feudalism
//
//  Krov 1×1: stavlja se ručno, oblik bira sam prema susjednim zidovima.
//

import Foundation
import SceneKit
import AppKit

enum Roof: PlaceableSceneKitObject {
    static let objectId = "object_roof"
    static let displayCode = "KR"

    static var gameObject: GameObject {
        let d = ObjectDimensions.roof
        return GameObject(id: objectId, name: "Krov", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let root = SCNNode()
        root.name = "roof"
        let s = BuildingKit.cell
        BuildingKit.adaptiveRoof(
            to: root,
            width: 1.05 * s,
            length: 1.05 * s,
            height: 0.55 * s,
            color: BuildingKit.roofTile,
            y: 2.2 * s,
            thatch: false
        )
        BuildingKit.box(to: root, 0.12 * s, 2.2 * s, 0.12 * s, BuildingKit.timber, at: SCNVector3(-0.38 * s, 1.1 * s, -0.38 * s))
        BuildingKit.box(to: root, 0.12 * s, 2.2 * s, 0.12 * s, BuildingKit.timber, at: SCNVector3(0.38 * s, 1.1 * s, -0.38 * s))
        BuildingKit.box(to: root, 0.12 * s, 2.2 * s, 0.12 * s, BuildingKit.timber, at: SCNVector3(-0.38 * s, 1.1 * s, 0.38 * s))
        BuildingKit.box(to: root, 0.12 * s, 2.2 * s, 0.12 * s, BuildingKit.timber, at: SCNVector3(0.38 * s, 1.1 * s, 0.38 * s))
        return root
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
