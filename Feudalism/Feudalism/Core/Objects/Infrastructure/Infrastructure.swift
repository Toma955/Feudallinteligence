//
//  Infrastructure.swift
//  Feudalism
//
//  Infrastruktura: cesta, podloga, most, tunel, kanal, rijeka;
//  ukras: zastava, baklja, spomenik, svijeća, ukrasno stablo, fontana.
//

import Foundation
import SceneKit
import AppKit

enum Road: PlaceableSceneKitObject {
    static let objectId = "object_road"
    static let displayCode = "CE"
    static var gameObject: GameObject {
        let d = ObjectDimensions.road
        return GameObject(id: objectId, name: "Cesta", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.road() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum StoneSlab: PlaceableSceneKitObject {
    static let objectId = "object_stone_slab"
    static let displayCode = "PL"
    static var gameObject: GameObject {
        let d = ObjectDimensions.stoneSlab
        return GameObject(id: objectId, name: "Podloga", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.stoneSlab() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Bridge: PlaceableSceneKitObject {
    static let objectId = "object_bridge"
    static let displayCode = "MO"
    static var gameObject: GameObject {
        let d = ObjectDimensions.bridge
        return GameObject(id: objectId, name: "Most", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.bridge() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Tunnel: PlaceableSceneKitObject {
    static let objectId = "object_tunnel"
    static let displayCode = "TU"
    static var gameObject: GameObject {
        let d = ObjectDimensions.tunnel
        return GameObject(id: objectId, name: "Tunel", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.tunnel() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Canal: PlaceableSceneKitObject {
    static let objectId = "object_canal"
    static let displayCode = "KA"
    static var gameObject: GameObject {
        let d = ObjectDimensions.canal
        return GameObject(id: objectId, name: "Kanal", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.canal() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum River: PlaceableSceneKitObject {
    static let objectId = "object_river"
    static let displayCode = "RI"
    static var gameObject: GameObject {
        let d = ObjectDimensions.river
        return GameObject(id: objectId, name: "Rijeka", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.river() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Flag: PlaceableSceneKitObject {
    static let objectId = "object_flag"
    static let displayCode = "ZA"
    static var gameObject: GameObject {
        let d = ObjectDimensions.flag
        return GameObject(id: objectId, name: "Zastava", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.flag() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Torch: PlaceableSceneKitObject {
    static let objectId = "object_torch"
    static let displayCode = "BA"
    static var gameObject: GameObject {
        let d = ObjectDimensions.torch
        return GameObject(id: objectId, name: "Baklja", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.torch() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Monument: PlaceableSceneKitObject {
    static let objectId = "object_monument"
    static let displayCode = "SP"
    static var gameObject: GameObject {
        let d = ObjectDimensions.monument
        return GameObject(id: objectId, name: "Spomenik", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.monument() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Candle: PlaceableSceneKitObject {
    static let objectId = "object_candle"
    static let displayCode = "SĆ"
    static var gameObject: GameObject {
        let d = ObjectDimensions.candle
        return GameObject(id: objectId, name: "Svijeća", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.candle() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum OrnamentalTree: PlaceableSceneKitObject {
    static let objectId = "object_ornamental_tree"
    static let displayCode = "US"
    static var gameObject: GameObject {
        let d = ObjectDimensions.ornamentalTree
        return GameObject(id: objectId, name: "Ukrasno stablo", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.ornamentalTree() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Fountain: PlaceableSceneKitObject {
    static let objectId = "object_fountain"
    static let displayCode = "FO"
    static var gameObject: GameObject {
        let d = ObjectDimensions.fountain
        return GameObject(id: objectId, name: "Fontana", category: .infrastruktura, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { InfrastructureShapes.fountain() }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
