//
//  Church.swift
//  Feudalism
//
//  Crkva – placeholder 4×4×6. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Church: PlaceableSceneKitObject {
    static let objectId = "object_church"
    static let displayCode = "Cr"

    static var gameObject: GameObject {
        let d = ObjectDimensions.church
        return GameObject(id: objectId, name: "Crkva", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.church()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
