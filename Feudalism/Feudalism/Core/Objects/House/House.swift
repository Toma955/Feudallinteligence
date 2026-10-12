//
//  House.swift
//  Feudalism
//
//  Kuća – placeholder 4×4×4. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

/// Kuća – objekt koji se gradi na karti. Kategorija: dvorac.
enum House: PlaceableSceneKitObject {
    static let objectId = "object_house"
    static let displayCode = "H"
    static let modelAssetName: String? = nil
    static let modelSubdirectory = "Core/Objects/House"

    static var gameObject: GameObject {
        let d = ObjectDimensions.house
        return GameObject(id: objectId, name: "Kuća", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: modelAssetName)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.house()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
