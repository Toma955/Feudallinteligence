//
//  Canteen.swift
//  Feudalism
//
//  Zalogajnica – placeholder 4×4×3. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Canteen: PlaceableSceneKitObject {
    static let objectId = "object_canteen"
    static let displayCode = "Z"

    static var gameObject: GameObject {
        let d = ObjectDimensions.canteen
        return GameObject(id: objectId, name: "Zalogajnica", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.canteen()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
