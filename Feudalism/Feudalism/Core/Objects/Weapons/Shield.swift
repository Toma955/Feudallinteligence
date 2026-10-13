//
//  Shield.swift
//  Feudalism
//
//  Štit – radionica 4×4 metra. Kategorija: vojska.
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
        WeaponYard.makeNode(name: "shield", craft: .shield, cells: ObjectDimensions.shield.cellWidth)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
