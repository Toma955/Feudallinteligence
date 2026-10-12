//
//  Farm.swift
//  Feudalism
//
//  Farma pšenice. Folder: Core/Objects/Farm/
//  Tlocrt 5×5: četiri polja 2×2, križ za prolaz, mala zgrada na polju 4.
//

import Foundation
import SceneKit
import AppKit

/// Farma pšenice – objekt koji se gradi na karti. Kategorija: farme.
enum Farm: PlaceableSceneKitObject {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_farm"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "F"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Farm"

    private static let color = NSColor(red: 0.86, green: 0.72, blue: 0.32, alpha: 1)

    static var gameObject: GameObject {
        let d = ObjectDimensions.farm
        return GameObject(
            id: objectId,
            name: "Farma pšenice",
            category: .farme,
            width: d.cellWidth,
            height: d.cellHeight,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        FarmYard.makeNode(name: "farm", field: color, crop: .wheat)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
