//
//  Wood.swift
//  Feudalism
//
//  Spremište za granu – 4×4×4 metra. Kategorija: industrija.
//

import Foundation
import SceneKit
import AppKit

enum Wood: PlaceableSceneKitObject {
    static let objectId = "object_wood"
    static let displayCode = "D"

    static var gameObject: GameObject {
        let d = ObjectDimensions.wood
        return GameObject(id: objectId, name: "Sječarnica", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.woodcutter()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
