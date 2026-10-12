//
//  Tavern.swift
//  Feudalism
//
//  Krčma – placeholder 5×4×4. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Tavern: PlaceableSceneKitObject {
    static let objectId = "object_tavern"
    static let displayCode = "Kr"

    static var gameObject: GameObject {
        let d = ObjectDimensions.tavern
        return GameObject(id: objectId, name: "Krčma", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.tavern()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
