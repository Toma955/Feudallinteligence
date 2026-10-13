//
//  Lager.swift
//  Feudalism
//
//  Skladište (lager) – 5×5. Četiri polja 2×2, svako za jedan resurs.
//  Ostale kocke su prolaz.

import Foundation
import SceneKit
import AppKit

/// Tlocrt skladišta: četiri polja 2×2 i križ prolaza od jedne kocke.
enum LagerPlan {
    static let side = 5
    static let passage = 2

    /// Jedno polje za slaganje jednog resursa. Vrh je gornji-lijevi kut 2×2.
    struct Bay: Equatable {
        var row: Int
        var col: Int

        func contains(localRow: Int, localCol: Int) -> Bool {
            localRow >= row && localRow < row + 2 && localCol >= col && localCol < col + 2
        }
    }

    static let bays: [Bay] = [
        Bay(row: 0, col: 0), Bay(row: 0, col: 3),
        Bay(row: 3, col: 0), Bay(row: 3, col: 3)
    ]

    static func isPassage(localRow: Int, localCol: Int) -> Bool {
        guard localRow >= 0, localCol >= 0, localRow < side, localCol < side else { return false }
        return localRow == passage || localCol == passage
    }
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
