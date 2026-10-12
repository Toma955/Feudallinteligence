//
//  Smocnica.swift
//  Feudalism
//
//  Smočnica – placeholder 4×4×4. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Smocnica: PlaceableSceneKitObject {
    static let objectId = "object_smocnica"
    static let displayCode = "Sm"

    static var gameObject: GameObject {
        let d = ObjectDimensions.smocnica
        return GameObject(id: objectId, name: "Smočnica", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.smocnica()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
