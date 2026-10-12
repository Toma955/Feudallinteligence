//
//  Chicken.swift
//  Feudalism
//
//  Privremeni placeholder: kokošinjac 1×1, visina 1. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Chicken: PlaceableSceneKitObject {
    static let objectId = "object_chicken"
    static let displayCode = "C"

    static var gameObject: GameObject {
        let d = ObjectDimensions.chicken
        return GameObject(id: objectId, name: "Kokošinjac", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "chicken", field: NSColor(red: 0.9, green: 0.75, blue: 0.4, alpha: 1))
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
