//
//  Brewery.swift
//  Feudalism
//
//  Pivovara – placeholder 5×5×4. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Brewery: PlaceableSceneKitObject {
    static let objectId = "object_brewery"
    static let displayCode = "P"

    static var gameObject: GameObject {
        let d = ObjectDimensions.brewery
        return GameObject(id: objectId, name: "Pivovara", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.brewery()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
