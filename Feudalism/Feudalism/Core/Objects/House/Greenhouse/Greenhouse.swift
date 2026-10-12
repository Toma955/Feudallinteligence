//
//  Greenhouse.swift
//  Feudalism
//
//  Staklenik – placeholder 6×6×11. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Greenhouse: PlaceableSceneKitObject {
    static let objectId = "object_greenhouse"
    static let displayCode = "St"

    static var gameObject: GameObject {
        let d = ObjectDimensions.greenhouse
        return GameObject(id: objectId, name: "Staklenik", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.greenhouse()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
