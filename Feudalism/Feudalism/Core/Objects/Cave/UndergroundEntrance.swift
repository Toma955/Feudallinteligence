//
//  UndergroundEntrance.swift
//  Feudalism
//
//  Ulaz u podzemlje – placeholder 2×2×2. Gradi se gore (klikom se silazi) i dolje kao izlaz.
//

import Foundation
import SceneKit
import AppKit

enum UndergroundEntrance: PlaceableSceneKitObject {
    static let objectId = "object_underground_entrance"
    static let displayCode = "U"

    static var gameObject: GameObject {
        let d = ObjectDimensions.undergroundEntrance
        return GameObject(id: objectId, name: "Ulaz", category: .podzemlje, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.undergroundEntrance()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
