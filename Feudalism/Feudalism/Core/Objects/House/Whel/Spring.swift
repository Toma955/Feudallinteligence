//
//  Spring.swift
//  Feudalism
//
//  Izvor: 2×2, nizak. Smije se postaviti samo na podzemnu vodu. Privremeni placeholder.
//

import Foundation
import SceneKit
import AppKit

enum Spring: PlaceableSceneKitObject {
    static let objectId = "object_spring"
    static let displayCode = "IZ"

    static var gameObject: GameObject {
        let d = ObjectDimensions.spring
        return GameObject(id: objectId, name: "Izvor", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.spring()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
