//
//  FarmAnimals.swift
//  Feudalism
//
//  Stoka: svinje, krave, ovce. Placeholder kocke, kasnije modeli.
//

import Foundation
import SceneKit
import AppKit

private func farmPenNode(name: String, color: NSColor) -> SCNNode {
    FarmYard.makeNode(name: name, field: color)
}

enum Pig: PlaceableSceneKitObject {
    static let objectId = "object_pig"
    static let displayCode = "SV"
    static var gameObject: GameObject {
        let d = ObjectDimensions.pig
        return GameObject(id: objectId, name: "Svinjac", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmPenNode(name: "pig", color: NSColor(red: 0.78, green: 0.48, blue: 0.42, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Cow: PlaceableSceneKitObject {
    static let objectId = "object_cow"
    static let displayCode = "KR"
    static var gameObject: GameObject {
        let d = ObjectDimensions.cow
        return GameObject(id: objectId, name: "Štala krava", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmPenNode(name: "cow", color: NSColor(red: 0.55, green: 0.38, blue: 0.28, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Sheep: PlaceableSceneKitObject {
    static let objectId = "object_sheep"
    static let displayCode = "OV"
    static var gameObject: GameObject {
        let d = ObjectDimensions.sheep
        return GameObject(id: objectId, name: "Tor", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        farmPenNode(name: "sheep", color: NSColor(red: 0.82, green: 0.80, blue: 0.72, alpha: 1))
    }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
