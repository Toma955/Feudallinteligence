//
//  Hotel.swift
//  Feudalism
//
//  Privremeni placeholder: hotel 3×3, visina 3. Kasnije zamijeniti stvarnim modelom.
//

import Foundation
import SceneKit
import AppKit

enum Hotel: PlaceableSceneKitObject {
    static let objectId = "object_hotel"
    static let displayCode = "H"

    static var gameObject: GameObject {
        let d = ObjectDimensions.hotel
        return GameObject(id: objectId, name: "Hotel", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.hotel()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
