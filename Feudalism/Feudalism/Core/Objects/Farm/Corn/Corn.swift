//
//  Corn.swift
//  Feudalism
//
//  Kukuruz – farmYard 5×5 s usjevom klipova.
//

import Foundation
import SceneKit
import AppKit

enum Corn: PlaceableSceneKitObject {
    static let objectId = "object_corn"
    static let displayCode = "K"

    static var gameObject: GameObject {
        let d = ObjectDimensions.corn
        return GameObject(id: objectId, name: "Kukuruz", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "corn", crop: .corn)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
