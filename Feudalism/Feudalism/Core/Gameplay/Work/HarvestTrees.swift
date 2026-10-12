//
//  HarvestTrees.swift
//  Feudalism
//
//  Stabla koja sječar može posjeći. Vrijeme sječe/pile i broj dasaka kasnije podešavamo ovdje.
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
        /// Potezi piljenja u kućici.
        var sawTicks: Int
        /// Daske koje idu u skladište.
        var planks: Int
    }

    static func isTree(_ objectId: String) -> Bool {
        objectIds.contains(objectId)
    }

    static func yield(for objectId: String) -> Yield {
        switch objectId {
        case Oak.objectId: return Yield(cutTicks: 12, sawTicks: 8, planks: 6)
        case Fir.objectId: return Yield(cutTicks: 10, sawTicks: 6, planks: 4)
        case Cypress.objectId: return Yield(cutTicks: 9, sawTicks: 6, planks: 3)
        case Palm.objectId: return Yield(cutTicks: 8, sawTicks: 5, planks: 3)
        default: return Yield(cutTicks: 8, sawTicks: 6, planks: 3)
        }
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
