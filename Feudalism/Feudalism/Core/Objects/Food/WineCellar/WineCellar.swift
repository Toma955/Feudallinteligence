//
//  WineCellar.swift
//  Feudalism
//
//  Vinski podrum – 4×4 metra. Kategorija: hrana.
//

import Foundation
import SceneKit
import AppKit

enum WineCellar: PlaceableSceneKitObject {
    static let objectId = "object_wine_cellar"
    static let displayCode = "Vp"

    static var gameObject: GameObject {
        let d = ObjectDimensions.wineCellar
        return GameObject(id: objectId, name: "Vinski podrum", category: .hrana, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.wineCellar()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
