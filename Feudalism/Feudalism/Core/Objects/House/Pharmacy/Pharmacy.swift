//
//  Pharmacy.swift
//  Feudalism
//
//  Ljekarna – placeholder 6×6×11. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Pharmacy: PlaceableSceneKitObject {
    static let objectId = "object_pharmacy"
    static let displayCode = "Lj"

    static var gameObject: GameObject {
        let d = ObjectDimensions.pharmacy
        return GameObject(id: objectId, name: "Ljekarna", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.pharmacy()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
