//
//  Market.swift
//  Feudalism
//
//  Privremeni placeholder: tržnica 5×5, visina 4 — obična siva kutija.
//

import Foundation
import SceneKit
import AppKit

enum Market: PlaceableSceneKitObject {
    static let objectId = "object_market"
    static let displayCode = "M"

    static var gameObject: GameObject {
        let d = ObjectDimensions.market
        return GameObject(id: objectId, name: "Tržnica", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.market()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
