//
//  Corn.swift
//  Feudalism
//
//  Privremeni placeholder: kukuruz 2×2, visina 1. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Corn: PlaceableSceneKitObject {
    static let objectId = "object_corn"
    static let displayCode = "K"

    static var gameObject: GameObject {
        let d = ObjectDimensions.corn
        return GameObject(id: objectId, name: "Kukuruz", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "corn", field: NSColor(red: 0.85, green: 0.75, blue: 0.2, alpha: 1))
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
