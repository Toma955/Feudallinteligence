//
//  HarvestTrees.swift
//  Feudalism
//
//  Stabla koja sječar može posjeći. Broj dasaka i trajanje: tree_yields.json (TreeYieldNotebook).
//

import Foundation
import SceneKit
import AppKit

enum HarvestTrees {
    static let objectIds: Set<String> = [
        Tree.objectId, Oak.objectId, Fir.objectId, Cypress.objectId, Palm.objectId
    ]

    struct Yield: Equatable {
        /// Potezi sječe na stablu.
        var cutTicks: Int
        /// Potezi piljenja u kućici (palme: kratko, bez dasaka).
        var sawTicks: Int
        /// Daske koje idu u skladište.
        var planks: Int
        /// Banane s divlje palme → smočnica.
        var bananas: Int
    }

    static func isPalm(_ objectId: String) -> Bool {
        objectId == Palm.objectId
    }

    static func isTree(_ objectId: String) -> Bool {
        objectIds.contains(objectId)
    }

    /// Po vrsti stabla (bilježnica). Tok: sječa → deblo kući → pila → daske u skladište.
    static func yield(for objectId: String) -> Yield {
        TreeYieldNotebook.yield(for: objectId)
    }

    static func material(_ color: NSColor, roughness: CGFloat = 0.9) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.ambient.contents = color.blended(withFraction: 0.5, of: .black)
        m.specular.contents = NSColor(white: 0.08, alpha: 1)
        m.roughness.contents = roughness
        m.lightingModel = .blinn
        return m
    }
}
