//
//  Bow.swift
//  Feudalism
//
//  Luk – radionica 4×4 metra. Kategorija: vojska.
//

import Foundation
import SceneKit
import AppKit

enum Bow: PlaceableSceneKitObject {
    static let objectId = "object_bow"
    static let displayCode = "L"

    static var gameObject: GameObject {
        let d = ObjectDimensions.bow
        return GameObject(id: objectId, name: "Luk", category: .vojska, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        WeaponYard.makeNode(name: "bow", craft: .bow, cells: ObjectDimensions.bow.cellWidth)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
