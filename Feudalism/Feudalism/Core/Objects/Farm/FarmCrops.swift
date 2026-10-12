//
//  FarmCrops.swift
//  Feudalism
//
//  Polja: povrće, grožđe, začini, cvijeće, voćnjak jabuka. Placeholder kocke, kasnije modeli.
//

import Foundation
import SceneKit
import AppKit

private func farmFieldNode(name: String, color: NSColor) -> SCNNode {
    FarmYard.makeNode(name: name, field: color)
}

enum Vegetables: PlaceableSceneKitObject {
    static let objectId = "object_vegetables"
    static let displayCode = "PV"
    static var gameObject: GameObject {
        let d = ObjectDimensions.vegetables
        return GameObject(id: objectId, name: "Povrće", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmFieldNode(name: "vegetables", color: NSColor(red: 0.28, green: 0.55, blue: 0.22, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Grapes: PlaceableSceneKitObject {
    static let objectId = "object_grapes"
    static let displayCode = "GR"
    static var gameObject: GameObject {
        let d = ObjectDimensions.grapes
        return GameObject(id: objectId, name: "Vinograd", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmFieldNode(name: "grapes", color: NSColor(red: 0.42, green: 0.18, blue: 0.42, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Spices: PlaceableSceneKitObject {
    static let objectId = "object_spices"
    static let displayCode = "ZČ"
    static var gameObject: GameObject {
        let d = ObjectDimensions.spices
        return GameObject(id: objectId, name: "Začini", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmFieldNode(name: "spices", color: NSColor(red: 0.72, green: 0.42, blue: 0.16, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Flower: PlaceableSceneKitObject {
    static let objectId = "object_flower"
    static let displayCode = "CV"
    static var gameObject: GameObject {
        let d = ObjectDimensions.flower
        return GameObject(id: objectId, name: "Cvijeće", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmFieldNode(name: "flower", color: NSColor(red: 0.78, green: 0.32, blue: 0.48, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum AppleOrchard: PlaceableSceneKitObject {
    static let objectId = "object_apple"
    static let displayCode = "JB"
    static var gameObject: GameObject {
        let d = ObjectDimensions.appleOrchard
        return GameObject(id: objectId, name: "Voćnjak", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "apple", crop: .apple)
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
