//
//  CandleShop.swift
//  Feudalism
//
//  Svijećarnica: vosak → svijeća. Svijeća pali hodnike i radionice.
//

import Foundation
import SceneKit
import AppKit

enum CandleShop: PlaceableSceneKitObject {
    static let objectId = "object_candle_shop"
    static let displayCode = "S"

    static var gameObject: GameObject {
        let d = ObjectDimensions.candleShop
        return GameObject(id: objectId, name: "Svijećarnica", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.candleShop()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
