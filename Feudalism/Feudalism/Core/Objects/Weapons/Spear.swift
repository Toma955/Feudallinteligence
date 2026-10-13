//
//  Spear.swift
//  Feudalism
//
//  Koplje – radionica 4×4 metra. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Spear: PlaceableSceneKitObject {
    static let objectId = "object_spear"
    static let displayCode = "K"

    static var gameObject: GameObject {
        let d = ObjectDimensions.spear
        return GameObject(id: objectId, name: "Koplje", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "spear", craft: .spear, cells: ObjectDimensions.spear.cellWidth)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
