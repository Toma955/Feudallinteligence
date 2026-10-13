//
//  Bakery.swift
//  Feudalism
//
//  Pekara – 4×4 metra. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum Bakery: PlaceableSceneKitObject {
    static let objectId = "object_bakery"
    static let displayCode = "B"

    static var gameObject: GameObject {
        let d = ObjectDimensions.bakery
        return GameObject(id: objectId, name: "Pekara", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "bakery", craft: .bakery, cells: ObjectDimensions.bakery.cellWidth)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
