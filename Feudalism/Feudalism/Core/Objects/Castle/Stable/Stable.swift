//
//  Stable.swift
//  Feudalism
//
//  Staja za konje – placeholder 5×4×4. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Stable: PlaceableSceneKitObject {
    static let objectId = "object_stable"
    static let displayCode = "S"

    static var gameObject: GameObject {
        let d = ObjectDimensions.stable
        return GameObject(id: objectId, name: "Staja za konje", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.stable()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
