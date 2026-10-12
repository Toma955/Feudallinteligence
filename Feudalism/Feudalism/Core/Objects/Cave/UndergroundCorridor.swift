//
//  UndergroundCorridor.swift
//  Feudalism
//
//  Hodnik u podzemlju – placeholder 1×1×3. Kroz njega se prolazi. Gradi se samo dolje.
//

import Foundation
import SceneKit
import AppKit

enum UndergroundCorridor: PlaceableSceneKitObject {
    static let objectId = "object_underground_corridor"
    static let displayCode = "H"

    static var gameObject: GameObject {
        let d = ObjectDimensions.undergroundCorridor
        return GameObject(id: objectId, name: "Hodnik", category: .podzemlje, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.undergroundCorridor()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
