//
//  InfrastructureShapes.swift
//  Feudalism
//
//  Grubi 3D oblik za infrastrukturu i ukras dvorca.
//

import Foundation
import SceneKit
import AppKit

enum InfrastructureShapes {
    private static var k: BuildingKit.Type { BuildingKit.self }
    private static var s: CGFloat { BuildingKit.cell }

    static func road() -> SCNNode {
        let root = named("road")
        k.box(to: root, 1.0 * s, 0.14 * s, 1.0 * s, k.stoneDark, at: SCNVector3(0, 0.07 * s, 0))
        k.box(to: root, 0.12 * s, 0.03 * s, 0.92 * s, k.stone, at: SCNVector3(0, 0.15 * s, 0))
        k.box(to: root, 0.92 * s, 0.02 * s, 0.08 * s, k.stone, at: SCNVector3(0, 0.145 * s, 0))
        return root
    }

    static func stoneSlab() -> SCNNode {
        let root = named("stone_slab")
        k.box(to: root, 1.0 * s, 0.14 * s, 1.0 * s, k.stone, at: SCNVector3(0, 0.07 * s, 0))
        let tile: CGFloat = 0.44
        let gap: CGFloat = 0.52
        for x in [-gap / 2, gap / 2] {
            for z in [-gap / 2, gap / 2] {
                k.box(to: root, tile * s, 0.04 * s, tile * s, k.stoneDark, at: SCNVector3(x * s, 0.15 * s, z * s))
            }
        }
        return root
    }

    static func bridge() -> SCNNode {
        let root = named("bridge")
        k.box(to: root, 3.0 * s, 0.16 * s, 0.92 * s, k.timber, at: SCNVector3(0, 0.62 * s, 0))
        k.box(to: root, 2.7 * s, 0.08 * s, 0.72 * s, k.timberDark, at: SCNVector3(0, 0.72 * s, 0))
        for x in [-1.3, 0, 1.3] {
            k.box(to: root, 0.16 * s, 0.70 * s, 0.16 * s, k.timberDark, at: SCNVector3(x * s, 0.35 * s, 0.38 * s))
            k.box(to: root, 0.16 * s, 0.70 * s, 0.16 * s, k.timberDark, at: SCNVector3(x * s, 0.35 * s, -0.38 * s))
            k.box(to: root, 0.10 * s, 0.38 * s, 0.10 * s, k.timber, at: SCNVector3(x * s, 0.90 * s, 0.42 * s))
            k.box(to: root, 0.10 * s, 0.38 * s, 0.10 * s, k.timber, at: SCNVector3(x * s, 0.90 * s, -0.42 * s))
        }
        k.box(to: root, 2.8 * s, 0.08 * s, 0.08 * s, k.timber, at: SCNVector3(0, 1.10 * s, 0.42 * s))
        k.box(to: root, 2.8 * s, 0.08 * s, 0.08 * s, k.timber, at: SCNVector3(0, 1.10 * s, -0.42 * s))
        return root
    }

    static func tunnel() -> SCNNode {
        let root = named("tunnel")
        k.box(to: root, 2.0 * s, 0.14 * s, 2.0 * s, k.stoneDark, at: SCNVector3(0, 0.07 * s, 0))
        k.box(to: root, 0.45 * s, 2.4 * s, 1.6 * s, k.stone, at: SCNVector3(-0.78 * s, 1.25 * s, 0))
        k.box(to: root, 0.45 * s, 2.4 * s, 1.6 * s, k.stone, at: SCNVector3(0.78 * s, 1.25 * s, 0))
        k.box(to: root, 2.0 * s, 0.45 * s, 1.7 * s, k.stoneDark, at: SCNVector3(0, 2.55 * s, 0))
        k.box(to: root, 1.05 * s, 1.55 * s, 0.12 * s, NSColor.black.withAlphaComponent(0.88), at: SCNVector3(0, 0.95 * s, 0.82 * s))
        k.box(to: root, 0.18 * s, 1.7 * s, 0.18 * s, k.timber, at: SCNVector3(-0.48 * s, 1.0 * s, 0.88 * s))
        k.box(to: root, 0.18 * s, 1.7 * s, 0.18 * s, k.timber, at: SCNVector3(0.48 * s, 1.0 * s, 0.88 * s))
        return root
    }

    static func flag() -> SCNNode {
        let root = named("flag")
        k.cylinder(to: root, radius: 0.05 * s, height: 3.4 * s, color: k.timberDark, at: SCNVector3(0, 1.7 * s, 0), segments: 6)
        k.sphere(to: root, radius: 0.08 * s, color: k.iron, at: SCNVector3(0, 3.42 * s, 0), segments: 6)
        let cloth = NSColor(red: 0.72, green: 0.12, blue: 0.14, alpha: 1)
        k.box(to: root, 0.95 * s, 0.62 * s, 0.04 * s, cloth, at: SCNVector3(0.52 * s, 2.85 * s, 0))
        k.box(to: root, 0.22 * s, 0.22 * s, 0.05 * s, NSColor(red: 0.88, green: 0.72, blue: 0.22, alpha: 1), at: SCNVector3(0.28 * s, 2.95 * s, 0.01 * s))
        return root
    }

    static func torch() -> SCNNode {
        let root = named("torch")
        k.cylinder(to: root, radius: 0.06 * s, height: 1.45 * s, color: k.timberDark, at: SCNVector3(0, 0.72 * s, 0), segments: 6)
        k.cone(to: root, top: 0.14 * s, bottom: 0.08 * s, height: 0.22 * s, color: k.iron, at: SCNVector3(0, 1.52 * s, 0))
        let flame = k.cone(to: root, top: 0, bottom: 0.10 * s, height: 0.32 * s, color: NSColor(red: 1, green: 0.55, blue: 0.12, alpha: 1), at: SCNVector3(0, 1.78 * s, 0))
        flame.geometry?.firstMaterial?.emission.contents = NSColor(red: 1, green: 0.45, blue: 0.08, alpha: 1)
        flame.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.scale(to: 1.12, duration: 0.35),
            SCNAction.scale(to: 0.9, duration: 0.35)
        ])))
        return root
    }

    static func monument() -> SCNNode {
        let root = named("monument")
        k.box(to: root, 1.6 * s, 0.28 * s, 1.6 * s, k.stoneDark, at: SCNVector3(0, 0.14 * s, 0))
        k.box(to: root, 1.15 * s, 0.22 * s, 1.15 * s, k.stone, at: SCNVector3(0, 0.39 * s, 0))
        k.box(to: root, 0.55 * s, 2.2 * s, 0.55 * s, k.stone, at: SCNVector3(0, 1.60 * s, 0))
        k.cone(to: root, top: 0, bottom: 0.42 * s, height: 0.7 * s, color: k.stoneDark, at: SCNVector3(0, 3.05 * s, 0))
        return root
    }

    static func candle() -> SCNNode {
        let root = named("candle")
        k.cylinder(to: root, radius: 0.16 * s, height: 0.12 * s, color: k.ironDark, at: SCNVector3(0, 0.06 * s, 0), segments: 8)
        k.cylinder(to: root, radius: 0.07 * s, height: 0.42 * s, color: NSColor(red: 0.95, green: 0.90, blue: 0.74, alpha: 1), at: SCNVector3(0, 0.33 * s, 0), segments: 8)
        let flame = k.cone(to: root, top: 0, bottom: 0.045 * s, height: 0.14 * s, color: NSColor(red: 1, green: 0.62, blue: 0.18, alpha: 1), at: SCNVector3(0, 0.61 * s, 0))
        flame.geometry?.firstMaterial?.emission.contents = NSColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)
        return root
    }

    static func ornamentalTree() -> SCNNode {
        let root = named("ornamental_tree")
        k.cylinder(to: root, radius: 0.10 * s, height: 1.35 * s, color: k.timberDark, at: SCNVector3(0, 0.68 * s, 0), segments: 6)
        let blossom = NSColor(red: 0.78, green: 0.32, blue: 0.48, alpha: 1)
        let leaf = NSColor(red: 0.22, green: 0.48, blue: 0.22, alpha: 1)
        k.sphere(to: root, radius: 0.62 * s, color: leaf, at: SCNVector3(0, 1.85 * s, 0), segments: 8)
        k.sphere(to: root, radius: 0.42 * s, color: leaf, at: SCNVector3(-0.38 * s, 1.65 * s, 0.18 * s), segments: 7)
        k.sphere(to: root, radius: 0.38 * s, color: leaf, at: SCNVector3(0.36 * s, 1.70 * s, -0.16 * s), segments: 7)
        for p in [(-0.28, 1.95, 0.22), (0.24, 2.05, -0.18), (0.08, 2.18, 0.12), (-0.12, 1.72, -0.28)] {
            k.sphere(to: root, radius: 0.08 * s, color: blossom, at: SCNVector3(p.0 * s, p.1 * s, p.2 * s), segments: 5)
        }
        return root
    }

    static func fountain() -> SCNNode {
        let root = named("fountain")
        k.cylinder(to: root, radius: 0.92 * s, height: 0.28 * s, color: k.stone, at: SCNVector3(0, 0.14 * s, 0), segments: 12)
        k.cylinder(to: root, radius: 0.72 * s, height: 0.12 * s, color: k.water, at: SCNVector3(0, 0.26 * s, 0), segments: 12)
        k.cylinder(to: root, radius: 0.16 * s, height: 0.95 * s, color: k.stoneDark, at: SCNVector3(0, 0.72 * s, 0), segments: 8)
        k.cone(to: root, top: 0.22 * s, bottom: 0.08 * s, height: 0.22 * s, color: k.stone, at: SCNVector3(0, 1.25 * s, 0))
        k.sphere(to: root, radius: 0.10 * s, color: k.water, at: SCNVector3(0, 1.42 * s, 0), segments: 6)
        k.sphere(to: root, radius: 0.07 * s, color: k.water, at: SCNVector3(0.12 * s, 1.18 * s, 0.08 * s), segments: 5)
        k.sphere(to: root, radius: 0.06 * s, color: k.water, at: SCNVector3(-0.10 * s, 1.10 * s, -0.06 * s), segments: 5)
        return root
    }

    private static func named(_ name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name
        return node
    }
}
