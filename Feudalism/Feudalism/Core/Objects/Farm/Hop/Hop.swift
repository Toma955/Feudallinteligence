//
//  Hop.swift
//  Feudalism
//
//  Farma hmelja: proizvodi 1 hmelj po ticku → ide na stockpile; radnik/pivovara uzima odatle.
//

import Foundation
import SceneKit
import AppKit

enum Hop: PlaceableSceneKitObject {
    static let objectId = "object_hop"
    static let displayCode = "H"

    static var gameObject: GameObject {
        let d = ObjectDimensions.hop
        return GameObject(id: objectId, name: "Hmelj", category: .farme, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "hop", field: NSColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1))
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
