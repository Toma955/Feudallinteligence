//
//  Windmill.swift
//  Feudalism
//
//  Privremeni placeholder: mlin 2×2, visina 3. Kasnije zamijeniti stvarnim modelom i animacijom.
//

import Foundation
import SceneKit
import AppKit

enum Windmill: PlaceableSceneKitObject {
    static let objectId = "object_windmill"
    static let displayCode = "M"

    static var gameObject: GameObject {
        let d = ObjectDimensions.windmill
        return GameObject(id: objectId, name: "Mlin", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.windmill()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
