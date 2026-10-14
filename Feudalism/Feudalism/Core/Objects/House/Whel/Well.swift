//
//  Well.swift
//  Feudalism
//
//  Privremeni placeholder: bunar 1×1, visina 2. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Well: PlaceableSceneKitObject {
    static let objectId = "object_well"
    static let displayCode = "W"

    static var gameObject: GameObject {
        let d = ObjectDimensions.well
        return GameObject(id: objectId, name: "Bunar", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.well()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
