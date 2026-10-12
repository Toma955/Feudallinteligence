//
//  Stone.swift
//  Feudalism
//
//  Privremeni placeholder: kamenolom 2×2, visina 2. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Stone: PlaceableSceneKitObject {
    static let objectId = "object_stone"
    static let displayCode = "S"

    static var gameObject: GameObject {
        let d = ObjectDimensions.stone
        return GameObject(id: objectId, name: "Kamenolom", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.stoneQuarry()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
