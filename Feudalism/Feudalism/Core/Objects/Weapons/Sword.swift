//
//  Sword.swift
//  Feudalism
//
//  Mač – radionica 5×5. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Sword: PlaceableSceneKitObject {
    static let objectId = "object_sword"
    static let displayCode = "M"

    static var gameObject: GameObject {
        let d = ObjectDimensions.sword
        return GameObject(id: objectId, name: "Mač", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "sword", craft: .sword)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
