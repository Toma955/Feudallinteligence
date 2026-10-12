//
//  Shield.swift
//  Feudalism
//
//  Štit – placeholder 5×5. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Shield: PlaceableSceneKitObject {
    static let objectId = "object_shield"
    static let displayCode = "Š"

    static var gameObject: GameObject {
        let d = ObjectDimensions.shield
        return GameObject(id: objectId, name: "Štit", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "shield", craft: .shield)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
