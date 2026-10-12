//
//  Miners.swift
//  Feudalism
//
//  Rudari – placeholder 4×6×4. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Miners: PlaceableSceneKitObject {
    static let objectId = "object_miners"
    static let displayCode = "R"

    static var gameObject: GameObject {
        let d = ObjectDimensions.miners
        return GameObject(id: objectId, name: "Rudari", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.miners()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
