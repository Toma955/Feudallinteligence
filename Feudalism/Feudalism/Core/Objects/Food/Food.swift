//
//  Food.swift
//  Feudalism
//
//  Hrana: prozirna drvena kocka 4×4×4. Kroz drvo se vidi. Ima vlastiti kapacitet.
//

import Foundation
import SceneKit
import AppKit

enum Food: PlaceableSceneKitObject {
    static let objectId = "object_food"
    static let displayCode = "H"
    /// Koliko mjera hrane stane u jednu ovu građevinu.
    static let capacity = 200

    static let modelAssetName: String? = nil
    static let modelSubdirectory = "Core/Objects/Food"

    static var gameObject: GameObject {
        let d = ObjectDimensions.food
        return GameObject(
            id: objectId,
            name: "Hrana",
            category: .hrana,
            width: d.cellWidth,
            height: d.cellHeight,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.foodHall()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
