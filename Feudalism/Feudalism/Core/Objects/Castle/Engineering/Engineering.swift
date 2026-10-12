//
//  Engineering.swift
//  Feudalism
//
//  Inženjering – placeholder 4×6×4. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Engineering: PlaceableSceneKitObject {
    static let objectId = "object_engineering"
    static let displayCode = "I"

    static var gameObject: GameObject {
        let d = ObjectDimensions.engineering
        return GameObject(id: objectId, name: "Inženjering", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.engineering()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
