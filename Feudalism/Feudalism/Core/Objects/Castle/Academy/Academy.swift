//
//  Academy.swift
//  Feudalism
//
//  Akademija – obuka vojskovođa, diplomata, logističara i špijuna. 5×5×5. Kategorija: dvorac.
//

import Foundation
import SceneKit
import AppKit

enum Academy: PlaceableSceneKitObject {
    static let objectId = "object_academy"
    static let displayCode = "Ak"

    static var gameObject: GameObject {
        let d = ObjectDimensions.academy
        return GameObject(
            id: objectId,
            name: "Akademija",
            category: .dvorac,
            width: d.cellWidth,
            height: d.cellHeight,
            displayCode: displayCode,
            modelAssetName: nil
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.academy()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
