//
//  Training.swift
//  Feudalism
//
//  Trening – placeholder 5×5. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Training: PlaceableSceneKitObject {
    static let objectId = "object_training"
    static let displayCode = "T"

    static var gameObject: GameObject {
        let d = ObjectDimensions.training
        return GameObject(id: objectId, name: "Trening", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.training()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
