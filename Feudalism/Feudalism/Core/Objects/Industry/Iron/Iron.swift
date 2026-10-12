//
//  Iron.swift
//  Feudalism
//
//  Privremeni placeholder: rudnik željeza 2×2, visina 2. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Iron: PlaceableSceneKitObject {
    static let objectId = "object_iron"
    static let displayCode = "I"

    static var gameObject: GameObject {
        let d = ObjectDimensions.iron
        return GameObject(id: objectId, name: "Rudnik željeza", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.ironMine()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
