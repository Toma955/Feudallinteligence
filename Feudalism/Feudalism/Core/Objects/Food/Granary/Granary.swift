//
//  Granary.swift
//  Feudalism
//
//  Privremeni placeholder: žitnica 2×2, visina 2. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Granary: PlaceableSceneKitObject {
    static let objectId = "object_granary"
    static let displayCode = "G"

    static var gameObject: GameObject {
        let d = ObjectDimensions.granary
        return GameObject(id: objectId, name: "Žitnica", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.granary()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
