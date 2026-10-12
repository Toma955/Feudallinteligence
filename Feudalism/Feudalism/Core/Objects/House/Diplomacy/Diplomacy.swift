//
//  Diplomacy.swift
//  Feudalism
//
//  Diplomacija – placeholder 5×5×6. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Diplomacy: PlaceableSceneKitObject {
    static let objectId = "object_diplomacy"
    static let displayCode = "Di"

    static var gameObject: GameObject {
        let d = ObjectDimensions.diplomacy
        return GameObject(id: objectId, name: "Diplomacija", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.diplomacy()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
