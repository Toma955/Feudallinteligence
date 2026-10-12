//
//  Distillery.swift
//  Feudalism
//
//  Destilerija – placeholder 4×4×5. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Distillery: PlaceableSceneKitObject {
    static let objectId = "object_distillery"
    static let displayCode = "D"

    static var gameObject: GameObject {
        let d = ObjectDimensions.distillery
        return GameObject(id: objectId, name: "Destilerija", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.distillery()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
