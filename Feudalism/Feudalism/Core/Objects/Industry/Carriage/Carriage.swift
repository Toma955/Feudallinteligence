//
//  Carriage.swift
//  Feudalism
//
//  Kola – placeholder 3×2×3. Kategorija: industrija.
//

import Foundation
import SceneKit
import AppKit

enum Carriage: PlaceableSceneKitObject {
    static let objectId = "object_carriage"
    static let displayCode = "K"

    static var gameObject: GameObject {
        let d = ObjectDimensions.carriage
        return GameObject(id: objectId, name: "Prijevoz", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.carriage()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
