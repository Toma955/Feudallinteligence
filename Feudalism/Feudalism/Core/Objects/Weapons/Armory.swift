//
//  Armory.swift
//  Feudalism
//
//  Oružarnica – placeholder 5×5. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Armory: PlaceableSceneKitObject {
    static let objectId = "object_armory"
    static let displayCode = "O"

    static var gameObject: GameObject {
        let d = ObjectDimensions.armory
        return GameObject(id: objectId, name: "Oružarnica", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "armory", craft: .armory)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
