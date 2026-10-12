//
//  Gates.swift
//  Feudalism
//
//  Vrata – placeholder 4×4×5. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Gates: PlaceableSceneKitObject {
    static let objectId = "object_gates"
    static let displayCode = "V"

    static var gameObject: GameObject {
        let d = ObjectDimensions.gates
        return GameObject(id: objectId, name: "Vrata", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.gates()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
