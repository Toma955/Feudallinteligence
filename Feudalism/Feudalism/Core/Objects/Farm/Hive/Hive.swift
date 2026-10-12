//
//  Hive.swift
//  Feudalism
//
//  Košnica: med i vosak. Vosak ide u svijećarnicu.
//

import Foundation
import SceneKit
import AppKit

enum Hive: PlaceableSceneKitObject {
    static let objectId = "object_hive"
    static let displayCode = "K"

    static var gameObject: GameObject {
        let d = ObjectDimensions.hive
        return GameObject(id: objectId, name: "Košnica", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "hive", field: NSColor(red: 0.86, green: 0.68, blue: 0.22, alpha: 1))
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
