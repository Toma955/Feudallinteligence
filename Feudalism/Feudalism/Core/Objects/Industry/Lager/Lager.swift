//
//  Lager.swift
//  Feudalism
//
//  Skladište (lager) – 5×5. Četiri polja 2×2 i križ prolaza širine 1.
//  Kategorija: industrija.
//
//    daske | hmelj
//    ------+------
//    kamen | željezo
//

import Foundation
import SceneKit
import AppKit

/// Tlocrt skladišta: 2×2, prolaz, 2×2, i tako u krug. Srednji red i stupac su prolaz.
enum LagerPlan {
    static let side = 5
    static let passage = 2

    static func isPassage(localRow: Int, localCol: Int) -> Bool {
        guard localRow >= 0, localCol >= 0, localRow < side, localCol < side else { return false }
        return localRow == passage || localCol == passage
    }

    /// Ćelija skladišta i roba čija naslaga na njoj stoji. Četiri unutarnja kuta su daska, hmelj, kamen i željezo.
    static let stacks: [(good: Good, row: Int, col: Int)] = [
        (.wood, 1, 1), (.hop, 1, 3),
        (.stone, 3, 1), (.iron, 3, 3),
        (.wheat, 0, 0), (.flour, 0, 1), (.beer, 1, 0),
        (.hay, 0, 3), (.wool, 0, 4), (.corn, 1, 4),
        (.grapes, 3, 0), (.wax, 4, 0), (.candle, 4, 1),
        (.wine, 3, 4), (.spirits, 4, 3), (.spices, 4, 4)
    ]
}

enum Lager: PlaceableSceneKitObject {
    static let objectId = "object_lager"
    static let displayCode = "L"

    static var gameObject: GameObject {
        let d = ObjectDimensions.lager
        return GameObject(id: objectId, name: "Skladište", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.lager()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
