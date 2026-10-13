//
//  Leather.swift
//  Feudalism
//
//  Koža – radionica 4×4 metra. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Leather: PlaceableSceneKitObject {
    static let objectId = "object_leather"
    static let displayCode = "Kž"

    static var gameObject: GameObject {
        let d = ObjectDimensions.leather
        return GameObject(id: objectId, name: "Koža", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "leather", craft: .leather, cells: ObjectDimensions.leather.cellWidth)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
