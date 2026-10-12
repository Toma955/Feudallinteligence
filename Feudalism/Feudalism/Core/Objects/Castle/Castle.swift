//
//  Castle.swift
//  Feudalism
//
//  Objekt Dvorac (Castle). Folder: Core/Objects/Castle/
//  Za sada placeholder kocka; kasnije .obj / .usdz model i tekstura.
//

import Foundation
import SceneKit
import AppKit

/// Dvorac – objekt koji se gradi na karti. Kategorija: dvorac.
enum Castle: PlaceableSceneKitObject {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_castle"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "C"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = placeholder.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Castle"

    /// Jedan GameObject za Dvorac – za katalog i placement na mapi. 8×8 ćelija.
    static var gameObject: GameObject {
        let d = ObjectDimensions.castle
        return GameObject(
            id: objectId,
            name: "Dvorac",
            category: .dvorac,
            width: d.cellWidth,
            height: d.cellHeight,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.castle()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
