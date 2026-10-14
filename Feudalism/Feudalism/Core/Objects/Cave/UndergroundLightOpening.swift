//
//  UndergroundLightOpening.swift
//  Feudalism
//
//  Svjetlosni otvor – 1×1. Na površini pušta svjetlo u podzemlje (okno).
//

import Foundation
import SceneKit
import AppKit

enum UndergroundLightOpening: PlaceableSceneKitObject {
    static let objectId = "object_underground_light_opening"
    static let displayCode = "SO"

    static var gameObject: GameObject {
        let d = ObjectDimensions.undergroundLightOpening
        return GameObject(
            id: objectId,
            name: "Svjetlosni otvor",
            category: .podzemlje,
            width: d.cellWidth,
            height: d.cellHeight,
            displayCode: displayCode,
            modelAssetName: nil
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.undergroundLightOpening()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
