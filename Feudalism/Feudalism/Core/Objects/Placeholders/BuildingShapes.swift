//
//  BuildingShapes.swift
//  Feudalism
//
//  Grubi 3D oblik za građevine koje nisu farme ni kuće oružja.
//  Svaka ima svoj tlocrt – kamenolom nije ista baza kao mlin.
//

import Foundation
import SceneKit
import AppKit

enum BuildingShapes {
    private static var k: BuildingKit.Type { BuildingKit.self }
    private static var s: CGFloat { BuildingKit.cell }

    // MARK: - Dvorac

    static func castle() -> SCNNode {
        let root = named("castle")
        let wall = k.stone
        let keepW: CGFloat = 3.6 * s
        k.slab(to: root, width: 8 * s, depth: 8 * s, color: k.earth, height: 0.08)
        k.box(to: root, 5.2 * s, 3.6 * s, 4.2 * s, k.stoneDark, at: SCNVector3(0, 1.8 * s, -0.6 * s))
        k.roof(to: root, width: 5.6 * s, length: 4.6 * s, height: 1.6 * s, color: k.roofDark, y: 3.6 * s)
        k.box(to: root, keepW, 5.4 * s, keepW, wall, at: SCNVector3(0, 2.7 * s, -1.4 * s))
        k.roof(to: root, width: keepW * 1.1, length: keepW * 1.1, height: 1.8 * s, color: k.roofTile, y: 5.4 * s)
        let towers: [(CGFloat, CGFloat)] = [(-3.3, -3.3), (3.3, -3.3), (-3.3, 3.3), (3.3, 3.3)]
        for t in towers {
            k.cylinder(to: root, radius: 0.72 * s, height: 6.2 * s, color: wall, at: SCNVector3(t.0 * s, 3.1 * s, t.1 * s), segments: 10)
            k.cone(to: root, top: 0, bottom: 0.95 * s, height: 1.4 * s, color: k.roofTile, at: SCNVector3(t.0 * s, 6.9 * s, t.1 * s))
        }
        k.box(to: root, 2.2 * s, 2.8 * s, 1.1 * s, k.stoneDark, at: SCNVector3(0, 1.4 * s, 3.5 * s))
        k.box(to: root, 1.1 * s, 2.0 * s, 0.12 * s, k.door, at: SCNVector3(0, 1.05 * s, 4.08 * s))
        return root
    }

    static func house() -> SCNNode {
        let root = named("house")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 3.4 * s, depth: 3.1 * s, wallH: 2.4 * s, roofH: 1.5 * s)
        k.chimney(to: root, at: SCNVector3(1.1 * s, 3.3 * s, -0.4 * s), height: 1.5 * s)
        return root
    }

    static func hotel() -> SCNNode {
        let root = named("hotel")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.stoneDark)
        k.box(to: root, 4.4 * s, 6.2 * s, 3.8 * s, k.plasterLight, at: SCNVector3(0, 3.1 * s, -0.15 * s))
        k.roof(to: root, width: 4.8 * s, length: 4.2 * s, height: 1.8 * s, color: k.roofTile, y: 6.2 * s)
        k.box(to: root, 0.7 * s, 1.6 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.85 * s, 1.8 * s))
        k.chimney(to: root, at: SCNVector3(1.6 * s, 7.2 * s, 0.4 * s), height: 1.6 * s)
        for floor in 0..<2 {
            for x in [-1.2, 1.2] {
                k.box(to: root, 0.55 * s, 0.55 * s, 0.06 * s, k.timberDark, at: SCNVector3(x * s, (2.2 + CGFloat(floor) * 1.8) * s, 1.78 * s))
            }
        }
        return root
    }

    static func market() -> SCNNode {
        let root = named("market")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.earth, height: 0.06)
        let stalls: [(CGFloat, CGFloat, NSColor)] = [
            (-1.4, -1.2, NSColor(red: 0.72, green: 0.22, blue: 0.18, alpha: 1)),
            (1.3, -1.1, NSColor(red: 0.22, green: 0.38, blue: 0.62, alpha: 1)),
            (-1.3, 1.3, NSColor(red: 0.78, green: 0.62, blue: 0.20, alpha: 1)),
            (1.25, 1.25, NSColor(red: 0.28, green: 0.48, blue: 0.28, alpha: 1)),
        ]
        for stall in stalls {
            k.box(to: root, 1.7 * s, 0.55 * s, 1.5 * s, k.timber, at: SCNVector3(stall.0 * s, 0.34 * s, stall.1 * s))
            k.box(to: root, 1.9 * s, 0.08 * s, 1.7 * s, stall.2, at: SCNVector3(stall.0 * s, 1.35 * s, stall.1 * s))
            k.box(to: root, 0.08 * s, 1.25 * s, 0.08 * s, k.timberDark, at: SCNVector3((stall.0 - 0.75) * s, 0.70 * s, (stall.1 - 0.65) * s))
            k.box(to: root, 0.08 * s, 1.25 * s, 0.08 * s, k.timberDark, at: SCNVector3((stall.0 + 0.75) * s, 0.70 * s, (stall.1 + 0.65) * s))
        }
        return root
    }

    static func well() -> SCNNode {
        let root = named("well")
        k.cylinder(to: root, radius: 0.72 * s, height: 1.05 * s, color: k.stone, at: SCNVector3(0, 0.52 * s, 0), segments: 12)
        k.cylinder(to: root, radius: 0.48 * s, height: 0.12 * s, color: k.water, at: SCNVector3(0, 0.95 * s, 0), segments: 10)
        k.box(to: root, 0.10 * s, 1.15 * s, 0.10 * s, k.timber, at: SCNVector3(-0.55 * s, 1.55 * s, 0))
        k.box(to: root, 0.10 * s, 1.15 * s, 0.10 * s, k.timber, at: SCNVector3(0.55 * s, 1.55 * s, 0))
        k.box(to: root, 1.3 * s, 0.08 * s, 0.85 * s, k.thatch, at: SCNVector3(0, 2.15 * s, 0))
        k.cylinder(to: root, radius: 0.06 * s, height: 0.95 * s, color: k.timberDark, at: SCNVector3(0, 1.55 * s, 0), segments: 6)
        k.cylinder(to: root, radius: 0.06 * s, height: 0.95 * s, color: k.timberDark, at: SCNVector3(0, 1.55 * s, 0), segments: 6)
            .eulerAngles.z = CGFloat.pi / 2
        return root
    }

    static func spring() -> SCNNode {
        let root = named("spring")
        k.cylinder(to: root, radius: 0.85 * s, height: 0.28 * s, color: k.stone, at: SCNVector3(0, 0.14 * s, 0), segments: 12)
        k.cylinder(to: root, radius: 0.62 * s, height: 0.12 * s, color: k.water, at: SCNVector3(0, 0.26 * s, 0), segments: 10)
        k.sphere(to: root, radius: 0.18 * s, color: k.stoneDark, at: SCNVector3(-0.55 * s, 0.28 * s, 0.35 * s), segments: 6)
        k.sphere(to: root, radius: 0.14 * s, color: k.stone, at: SCNVector3(0.48 * s, 0.24 * s, -0.28 * s), segments: 6)
        return root
    }

    static func stable() -> SCNNode {
        let root = named("stable")
        k.slab(to: root, width: 5 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 4.6 * s, depth: 3.2 * s, wallH: 2.3 * s, roofH: 1.4 * s, wall: k.timber, roofColor: k.thatch)
        k.box(to: root, 1.4 * s, 0.35 * s, 0.7 * s, k.straw, at: SCNVector3(-1.6 * s, 0.22 * s, 1.5 * s))
        k.box(to: root, 1.1 * s, 0.28 * s, 0.55 * s, k.straw, at: SCNVector3(1.5 * s, 0.18 * s, 1.45 * s))
        return root
    }

    static func gates() -> SCNNode {
        let root = named("gates")
        k.box(to: root, 1.15 * s, 4.6 * s, 1.15 * s, k.stone, at: SCNVector3(-1.45 * s, 2.3 * s, 0))
        k.box(to: root, 1.15 * s, 4.6 * s, 1.15 * s, k.stone, at: SCNVector3(1.45 * s, 2.3 * s, 0))
        k.box(to: root, 1.8 * s, 1.1 * s, 0.7 * s, k.stoneDark, at: SCNVector3(0, 3.5 * s, 0))
        k.box(to: root, 1.15 * s, 2.4 * s, 0.12 * s, k.timberDark, at: SCNVector3(-0.45 * s, 1.2 * s, 0.08 * s))
        k.box(to: root, 1.15 * s, 2.4 * s, 0.12 * s, k.timberDark, at: SCNVector3(0.45 * s, 1.2 * s, 0.08 * s))
        k.cone(to: root, top: 0, bottom: 0.85 * s, height: 1.1 * s, color: k.roofTile, at: SCNVector3(-1.45 * s, 5.2 * s, 0))
        k.cone(to: root, top: 0, bottom: 0.85 * s, height: 1.1 * s, color: k.roofTile, at: SCNVector3(1.45 * s, 5.2 * s, 0))
        return root
    }

    static func miners() -> SCNNode {
        let root = named("miners")
        k.slab(to: root, width: 4 * s, depth: 6 * s, color: k.earth)
        k.cottage(to: root, width: 2.6 * s, depth: 2.4 * s, wallH: 2.0 * s, roofH: 1.1 * s, wall: k.timber, roofColor: k.thatch)
        root.childNode(withName: "cottage", recursively: false)?.position = SCNVector3(0, 0, -1.6 * s)
        let mound = k.sphere(to: root, radius: 1.35 * s, color: k.stoneDark, at: SCNVector3(0, 0.55 * s, 1.4 * s), segments: 8)
        mound.scale = SCNVector3(1.3, 0.55, 1.0)
        k.box(to: root, 1.15 * s, 1.25 * s, 0.55 * s, k.timberDark, at: SCNVector3(0, 0.72 * s, 0.55 * s))
        k.box(to: root, 0.85 * s, 0.85 * s, 0.12 * s, NSColor.black.withAlphaComponent(0.85), at: SCNVector3(0, 0.62 * s, 0.30 * s))
        k.box(to: root, 0.7 * s, 0.35 * s, 0.5 * s, k.iron, at: SCNVector3(-1.35 * s, 0.22 * s, 1.6 * s))
        k.box(to: root, 0.55 * s, 0.28 * s, 0.4 * s, k.ironDark, at: SCNVector3(1.25 * s, 0.18 * s, 1.85 * s))
        return root
    }

    static func engineering() -> SCNNode {
        let root = named("engineering")
        k.slab(to: root, width: 4 * s, depth: 6 * s, color: k.stoneDark)
        k.cottage(to: root, width: 3.5 * s, depth: 3.0 * s, wallH: 2.4 * s, roofH: 1.2 * s, wall: k.plaster, roofColor: k.roofDark)
        root.childNode(withName: "cottage", recursively: false)?.position = SCNVector3(0, 0, -1.1 * s)
        k.box(to: root, 1.6 * s, 0.25 * s, 2.2 * s, k.timber, at: SCNVector3(0, 0.20 * s, 1.7 * s))
        k.cylinder(to: root, radius: 0.45 * s, height: 0.16 * s, color: k.iron, at: SCNVector3(-0.7 * s, 0.45 * s, 1.5 * s), segments: 10)
        k.cylinder(to: root, radius: 0.32 * s, height: 0.14 * s, color: k.ironDark, at: SCNVector3(0.65 * s, 0.40 * s, 1.9 * s), segments: 10)
        k.box(to: root, 0.15 * s, 1.4 * s, 1.8 * s, k.timberDark, at: SCNVector3(1.55 * s, 0.75 * s, 1.6 * s))
        return root
    }

    static func church() -> SCNNode {
        let root = named("church")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.stone)
        k.box(to: root, 2.6 * s, 2.8 * s, 3.4 * s, k.plasterLight, at: SCNVector3(0, 1.4 * s, 0.15 * s))
        k.roof(to: root, width: 2.9 * s, length: 3.7 * s, height: 1.5 * s, color: k.roofDark, y: 2.8 * s)
        k.box(to: root, 1.15 * s, 4.4 * s, 1.15 * s, k.stone, at: SCNVector3(0, 2.2 * s, -1.45 * s))
        k.cone(to: root, top: 0, bottom: 0.95 * s, height: 1.8 * s, color: k.roofTile, at: SCNVector3(0, 5.3 * s, -1.45 * s))
        k.box(to: root, 0.55 * s, 1.35 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.72 * s, 1.9 * s))
        return root
    }

    static func diplomacy() -> SCNNode {
        let root = named("diplomacy")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.stone)
        k.box(to: root, 4.2 * s, 3.4 * s, 3.6 * s, k.plasterLight, at: SCNVector3(0, 1.7 * s, 0))
        k.roof(to: root, width: 4.6 * s, length: 4.0 * s, height: 1.7 * s, color: k.roofTile, y: 3.4 * s)
        for x in [-1.5, -0.5, 0.5, 1.5] {
            k.cylinder(to: root, radius: 0.14 * s, height: 2.2 * s, color: k.stone, at: SCNVector3(x * s, 1.15 * s, 1.95 * s), segments: 8)
        }
        k.box(to: root, 3.4 * s, 0.18 * s, 0.55 * s, k.stoneDark, at: SCNVector3(0, 2.3 * s, 1.95 * s))
        k.box(to: root, 0.7 * s, 1.5 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.8 * s, 1.85 * s))
        return root
    }

    static func pharmacy() -> SCNNode {
        let root = named("pharmacy")
        k.slab(to: root, width: 6 * s, depth: 6 * s, color: k.earth)
        k.cottage(to: root, width: 3.8 * s, depth: 3.4 * s, wallH: 4.6 * s, roofH: 2.2 * s, wall: NSColor(red: 0.62, green: 0.78, blue: 0.68, alpha: 1), roofColor: k.roofTile)
        k.chimney(to: root, at: SCNVector3(1.3 * s, 5.8 * s, -0.4 * s), height: 1.8 * s)
        for i in 0..<6 {
            let x = (-2.4 + CGFloat(i) * 0.85) * s
            k.cylinder(to: root, radius: 0.18 * s, height: 0.28 * s, color: k.timber, at: SCNVector3(x, 0.18 * s, 2.35 * s), segments: 6)
            k.sphere(to: root, radius: 0.16 * s, color: NSColor(red: 0.25, green: 0.55, blue: 0.22, alpha: 1), at: SCNVector3(x, 0.42 * s, 2.35 * s), segments: 6)
        }
        return root
    }

    static func greenhouse() -> SCNNode {
        let root = named("greenhouse")
        k.slab(to: root, width: 6 * s, depth: 6 * s, color: k.earth)
        k.box(to: root, 5.2 * s, 2.8 * s, 4.6 * s, k.glass, at: SCNVector3(0, 1.5 * s, 0))
        k.roof(to: root, width: 5.5 * s, length: 4.9 * s, height: 1.8 * s, color: NSColor(red: 0.40, green: 0.62, blue: 0.48, alpha: 0.5), y: 2.8 * s)
        k.box(to: root, 5.4 * s, 0.16 * s, 0.16 * s, k.timber, at: SCNVector3(0, 2.8 * s, 2.3 * s))
        k.box(to: root, 0.16 * s, 2.8 * s, 0.16 * s, k.timber, at: SCNVector3(-2.55 * s, 1.4 * s, 2.25 * s))
        k.box(to: root, 0.16 * s, 2.8 * s, 0.16 * s, k.timber, at: SCNVector3(2.55 * s, 1.4 * s, 2.25 * s))
        k.box(to: root, 0.55 * s, 1.3 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.7 * s, 2.35 * s))
        return root
    }

    // MARK: - Hrana

    static func windmill() -> SCNNode {
        let root = named("windmill")
        k.cylinder(to: root, radius: 0.85 * s, height: 6.4 * s, color: k.plaster, at: SCNVector3(0, 3.2 * s, 0), segments: 10)
        k.cone(to: root, top: 0.05 * s, bottom: 1.05 * s, height: 1.6 * s, color: k.roofTile, at: SCNVector3(0, 7.2 * s, 0))
        k.box(to: root, 0.4 * s, 1.15 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.62 * s, 0.88 * s))
        let hub = k.cylinder(to: root, radius: 0.16 * s, height: 0.55 * s, color: k.timberDark, at: SCNVector3(0, 5.4 * s, 0.95 * s), segments: 8)
        hub.eulerAngles.x = CGFloat.pi / 2
        let sails = SCNNode()
        sails.position = SCNVector3(0, 5.4 * s, 1.15 * s)
        for i in 0..<4 {
            let blade = SCNNode(geometry: {
                let g = SCNBox(width: 0.45 * s, height: 3.4 * s, length: 0.06 * s, chamferRadius: 0)
                g.materials = [k.material(k.straw)]
                return g
            }())
            blade.position = SCNVector3(0, 1.7 * s, 0)
            let arm = SCNNode()
            arm.addChildNode(blade)
            arm.eulerAngles.z = CGFloat(i) * CGFloat.pi / 2
            sails.addChildNode(arm)
        }
        sails.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 8)))
        root.addChildNode(sails)
        return root
    }

    static func bakery() -> SCNNode {
        let root = named("bakery")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 3.2 * s, depth: 2.8 * s, wallH: 2.2 * s, roofH: 1.2 * s, wall: k.plasterLight, roofColor: k.roofTile)
        k.cylinder(to: root, radius: 0.55 * s, height: 1.15 * s, color: k.stoneDark, at: SCNVector3(1.35 * s, 0.62 * s, 1.15 * s), segments: 10)
        k.chimney(to: root, at: SCNVector3(1.35 * s, 1.7 * s, 1.15 * s), height: 1.2 * s)
        k.box(to: root, 0.7 * s, 0.18 * s, 0.35 * s, NSColor(red: 0.78, green: 0.52, blue: 0.28, alpha: 1), at: SCNVector3(-1.15 * s, 0.18 * s, 1.35 * s))
        return root
    }

    static func granary() -> SCNNode {
        let root = named("granary")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.earth)
        k.box(to: root, 3.6 * s, 3.2 * s, 3.6 * s, k.timber, at: SCNVector3(0, 1.85 * s, 0))
        k.roof(to: root, width: 4.1 * s, length: 4.1 * s, height: 1.6 * s, color: k.thatch, y: 3.45 * s)
        for x in [-1.4, 1.4] {
            for z in [-1.4, 1.4] {
                k.cylinder(to: root, radius: 0.12 * s, height: 0.55 * s, color: k.timberDark, at: SCNVector3(x * s, 0.32 * s, z * s), segments: 6)
            }
        }
        k.box(to: root, 0.7 * s, 1.2 * s, 0.08 * s, k.door, at: SCNVector3(0, 1.15 * s, 1.85 * s))
        return root
    }

    static func brewery() -> SCNNode {
        let root = named("brewery")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.earth)
        k.cottage(to: root, width: 3.6 * s, depth: 3.2 * s, wallH: 2.6 * s, roofH: 1.3 * s, wall: k.plaster, roofColor: k.roofTile)
        k.chimney(to: root, at: SCNVector3(1.3 * s, 3.4 * s, -0.4 * s), height: 1.5 * s)
        for i in 0..<3 {
            k.cylinder(to: root, radius: 0.38 * s, height: 0.55 * s, color: k.timberDark, at: SCNVector3((-1.2 + CGFloat(i) * 0.85) * s, 0.35 * s, 1.85 * s), segments: 10)
        }
        k.cylinder(to: root, radius: 0.55 * s, height: 1.15 * s, color: k.iron, at: SCNVector3(1.55 * s, 0.65 * s, 1.55 * s), segments: 10)
        return root
    }

    static func distillery() -> SCNNode {
        let root = named("distillery")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.stoneDark)
        k.cottage(to: root, width: 3.0 * s, depth: 2.6 * s, wallH: 2.3 * s, roofH: 1.2 * s)
        k.cylinder(to: root, radius: 0.48 * s, height: 1.35 * s, color: NSColor(red: 0.72, green: 0.45, blue: 0.18, alpha: 1), at: SCNVector3(1.25 * s, 0.75 * s, 1.15 * s), segments: 10)
        k.cone(to: root, top: 0.06 * s, bottom: 0.48 * s, height: 0.55 * s, color: k.iron, at: SCNVector3(1.25 * s, 1.70 * s, 1.15 * s))
        k.chimney(to: root, at: SCNVector3(-1.0 * s, 3.1 * s, -0.3 * s), height: 1.6 * s)
        return root
    }

    static func wineCellar() -> SCNNode {
        let root = named("wine_cellar")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.stoneDark)
        k.box(to: root, 4.2 * s, 1.8 * s, 3.6 * s, k.stone, at: SCNVector3(0, 0.95 * s, 0))
        k.roof(to: root, width: 4.5 * s, length: 3.9 * s, height: 1.0 * s, color: k.roofDark, y: 1.8 * s)
        k.box(to: root, 0.7 * s, 1.2 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.65 * s, 1.85 * s))
        for i in 0..<4 {
            k.cylinder(to: root, radius: 0.28 * s, height: 0.72 * s, color: k.timberDark, at: SCNVector3((-1.4 + CGFloat(i) * 0.9) * s, 0.42 * s, 2.15 * s), segments: 8)
                .eulerAngles.z = CGFloat.pi / 2
        }
        return root
    }

    static func tavern() -> SCNNode {
        let root = named("tavern")
        k.slab(to: root, width: 5 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 4.2 * s, depth: 3.2 * s, wallH: 2.8 * s, roofH: 1.4 * s, wall: NSColor(red: 0.62, green: 0.42, blue: 0.30, alpha: 1), roofColor: k.roofTile)
        k.box(to: root, 0.08 * s, 0.85 * s, 0.08 * s, k.timber, at: SCNVector3(1.6 * s, 1.55 * s, 1.7 * s))
        k.box(to: root, 0.55 * s, 0.35 * s, 0.06 * s, NSColor(red: 0.55, green: 0.12, blue: 0.10, alpha: 1), at: SCNVector3(1.6 * s, 1.85 * s, 1.7 * s))
        k.cylinder(to: root, radius: 0.22 * s, height: 0.35 * s, color: k.timberDark, at: SCNVector3(-1.7 * s, 0.22 * s, 1.55 * s), segments: 8)
        return root
    }

    static func smocnica() -> SCNNode {
        let root = named("smocnica")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        let house = k.cottage(to: root, width: 3.2 * s, depth: 3.0 * s, wallH: 2.5 * s, roofH: 1.3 * s, wall: k.plaster, roofColor: k.thatch)
        if let wall = house.childNodes.first(where: { $0.geometry is SCNBox })?.geometry?.firstMaterial {
            wall.transparency = 0.42
            wall.transparencyMode = .dualLayer
            wall.blendMode = .alpha
            wall.isDoubleSided = true
        }
        k.box(to: root, 0.7 * s, 0.45 * s, 0.5 * s, k.timber, at: SCNVector3(-1.4 * s, 0.28 * s, 1.45 * s))
        k.box(to: root, 0.55 * s, 0.38 * s, 0.42 * s, k.timberDark, at: SCNVector3(-0.65 * s, 0.24 * s, 1.5 * s))
        k.box(to: root, 0.45 * s, 0.32 * s, 0.38 * s, k.straw, at: SCNVector3(1.35 * s, 0.20 * s, 1.4 * s))
        return root
    }

    static func canteen() -> SCNNode {
        let root = named("canteen")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 3.5 * s, depth: 3.1 * s, wallH: 2.2 * s, roofH: 1.1 * s, wall: NSColor(red: 0.78, green: 0.58, blue: 0.40, alpha: 1), roofColor: k.roofTile)
        k.box(to: root, 1.8 * s, 0.55 * s, 0.55 * s, k.timber, at: SCNVector3(0, 0.35 * s, 1.7 * s))
        return root
    }

    static func candleShop() -> SCNNode {
        let root = named("candle_shop")
        k.slab(to: root, width: 3 * s, depth: 3 * s, color: k.earth)
        k.cottage(to: root, width: 2.4 * s, depth: 2.2 * s, wallH: 2.0 * s, roofH: 1.0 * s, wall: NSColor(red: 0.90, green: 0.82, blue: 0.62, alpha: 1), roofColor: k.roofTile)
        for i in 0..<4 {
            k.cylinder(to: root, radius: 0.04 * s, height: 0.28 * s, color: NSColor(red: 0.95, green: 0.90, blue: 0.72, alpha: 1), at: SCNVector3((-0.45 + CGFloat(i) * 0.28) * s, 0.22 * s, 1.2 * s), segments: 5)
        }
        return root
    }

    // MARK: - Industrija

    static func stoneQuarry() -> SCNNode {
        let root = named("stone")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.stoneDark, height: 0.10)
        k.box(to: root, 5 * s, 1.4 * s, 0.85 * s, k.stone, at: SCNVector3(0, 0.75 * s, -1.95 * s))
        k.box(to: root, 5 * s, 2.2 * s, 0.75 * s, k.stoneDark, at: SCNVector3(0, 1.15 * s, -1.25 * s))
        k.box(to: root, 4.2 * s, 1.1 * s, 0.7 * s, k.stone, at: SCNVector3(-0.2 * s, 0.60 * s, -0.45 * s))
        let blocks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-1.5, 0.35, 0.9, 0.7),
            (-0.4, 0.28, 1.3, 0.55),
            (0.85, 0.42, 0.7, 0.85),
            (1.6, 0.22, 1.5, 0.45),
            (-1.2, 0.25, 1.8, 0.5),
        ]
        for b in blocks {
            k.box(to: root, b.3 * s, b.1 * 2 * s, b.3 * 0.8 * s, k.stone, at: SCNVector3(b.0 * s, b.1 * s, b.2 * s))
        }
        k.box(to: root, 0.16 * s, 3.4 * s, 0.16 * s, k.timberDark, at: SCNVector3(1.7 * s, 1.75 * s, 0.2 * s))
        k.box(to: root, 2.4 * s, 0.12 * s, 0.16 * s, k.timber, at: SCNVector3(0.55 * s, 3.35 * s, 0.2 * s))
        k.box(to: root, 0.12 * s, 1.1 * s, 0.12 * s, k.iron, at: SCNVector3(-0.35 * s, 2.75 * s, 0.2 * s))
        k.box(to: root, 0.45 * s, 0.28 * s, 0.45 * s, k.stone, at: SCNVector3(-0.35 * s, 2.10 * s, 0.2 * s))
        k.box(to: root, 1.6 * s, 0.12 * s, 0.7 * s, k.timber, at: SCNVector3(-1.4 * s, 0.18 * s, 1.9 * s))
        return root
    }

    static func ironMine() -> SCNNode {
        let root = named("iron")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        let hill = k.sphere(to: root, radius: 1.7 * s, color: NSColor(red: 0.32, green: 0.24, blue: 0.18, alpha: 1), at: SCNVector3(0, 0.45 * s, -0.55 * s), segments: 8)
        hill.scale = SCNVector3(1.15, 0.62, 1.05)
        k.box(to: root, 1.35 * s, 1.45 * s, 0.85 * s, k.timberDark, at: SCNVector3(0, 0.80 * s, 0.55 * s))
        k.box(to: root, 0.95 * s, 1.05 * s, 0.12 * s, NSColor.black.withAlphaComponent(0.9), at: SCNVector3(0, 0.70 * s, 0.20 * s))
        k.box(to: root, 0.12 * s, 1.55 * s, 0.12 * s, k.timber, at: SCNVector3(-0.7 * s, 0.85 * s, 0.85 * s))
        k.box(to: root, 0.12 * s, 1.55 * s, 0.12 * s, k.timber, at: SCNVector3(0.7 * s, 0.85 * s, 0.85 * s))
        k.box(to: root, 1.6 * s, 0.12 * s, 0.12 * s, k.timber, at: SCNVector3(0, 1.65 * s, 0.85 * s))
        k.box(to: root, 0.65 * s, 0.32 * s, 0.5 * s, k.iron, at: SCNVector3(-1.25 * s, 0.20 * s, 1.35 * s))
        k.box(to: root, 0.5 * s, 0.26 * s, 0.4 * s, k.ironDark, at: SCNVector3(1.15 * s, 0.18 * s, 1.25 * s))
        return root
    }

    /// Jedna ploča 5×5 debela 10 cm. Na njoj četiri skladišna mjesta 2×2, svako debelo 11 cm.
    static func lager() -> SCNNode {
        let root = named("lager")
        let step = s
        let base: CGFloat = 0.10
        let pad: CGFloat = 0.11
        k.box(to: root, 5 * step, base, 5 * step, k.stone, at: SCNVector3(0, base / 2, 0))
        let spots: [(CGFloat, CGFloat)] = [(-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)]
        for spot in spots {
            k.box(to: root, 2 * step, pad, 2 * step, k.stoneDark, at: SCNVector3(spot.0 * step, base + pad / 2, spot.1 * step))
        }
        let stock = SCNNode()
        stock.name = "warehouse_stock"
        root.addChildNode(stock)
        return root
    }

    static func woodcutter() -> SCNNode {
        let root = named("wood")
        k.slab(to: root, width: 4 * s, depth: 4 * s, color: k.earth)
        k.cottage(to: root, width: 2.4 * s, depth: 2.2 * s, wallH: 2.0 * s, roofH: 1.1 * s, wall: k.timber, roofColor: k.thatch)
        root.childNode(withName: "cottage", recursively: false)?.position = SCNVector3(-0.6 * s, 0, -0.7 * s)
        for i in 0..<4 {
            k.cylinder(to: root, radius: 0.16 * s, height: 1.35 * s, color: k.timberDark, at: SCNVector3((0.4 + CGFloat(i) * 0.12) * s, 0.22 * s, 1.15 * s), segments: 6)
                .eulerAngles.z = CGFloat.pi / 2
        }
        k.cylinder(to: root, radius: 0.18 * s, height: 1.15 * s, color: k.timber, at: SCNVector3(1.15 * s, 0.62 * s, 0.15 * s), segments: 6)
        k.box(to: root, 0.7 * s, 0.35 * s, 0.55 * s, k.straw, at: SCNVector3(-1.35 * s, 0.22 * s, 1.25 * s))
        return root
    }

    static func carriage() -> SCNNode {
        let root = named("carriage")
        k.box(to: root, 2.2 * s, 0.55 * s, 1.15 * s, k.timber, at: SCNVector3(0, 0.72 * s, 0))
        k.box(to: root, 0.85 * s, 0.70 * s, 1.05 * s, k.timberDark, at: SCNVector3(-0.85 * s, 1.25 * s, 0))
        for xz in [(-0.7, 0.58), (0.7, 0.58), (-0.7, -0.58), (0.7, -0.58)] {
            let wheel = k.cylinder(to: root, radius: 0.38 * s, height: 0.14 * s, color: k.timberDark, at: SCNVector3(xz.0 * s, 0.38 * s, xz.1 * s), segments: 10)
            wheel.eulerAngles.x = CGFloat.pi / 2
        }
        k.box(to: root, 0.12 * s, 0.12 * s, 1.35 * s, k.timber, at: SCNVector3(-1.35 * s, 0.85 * s, 0))
        return root
    }

    static func training() -> SCNNode {
        let root = named("training")
        k.slab(to: root, width: 5 * s, depth: 5 * s, color: k.earth, height: 0.07)
        for i in 0..<5 {
            k.box(to: root, 0.08 * s, 0.85 * s, 0.08 * s, k.timber, at: SCNVector3((-2.2 + CGFloat(i) * 1.1) * s, 0.45 * s, -2.2 * s))
            k.box(to: root, 0.08 * s, 0.85 * s, 0.08 * s, k.timber, at: SCNVector3((-2.2 + CGFloat(i) * 1.1) * s, 0.45 * s, 2.2 * s))
        }
        k.box(to: root, 4.6 * s, 0.08 * s, 0.08 * s, k.timberDark, at: SCNVector3(0, 0.72 * s, -2.2 * s))
        k.box(to: root, 4.6 * s, 0.08 * s, 0.08 * s, k.timberDark, at: SCNVector3(0, 0.72 * s, 2.2 * s))
        let dummies: [(CGFloat, CGFloat)] = [(-1.1, 0.2), (0.9, -0.6), (0.15, 1.2)]
        for d in dummies {
            k.cylinder(to: root, radius: 0.08 * s, height: 1.45 * s, color: k.timber, at: SCNVector3(d.0 * s, 0.78 * s, d.1 * s), segments: 6)
            k.box(to: root, 0.85 * s, 0.12 * s, 0.12 * s, k.timberDark, at: SCNVector3(d.0 * s, 1.25 * s, d.1 * s))
            k.sphere(to: root, radius: 0.16 * s, color: k.straw, at: SCNVector3(d.0 * s, 1.62 * s, d.1 * s), segments: 6)
        }
        k.cottage(to: root, width: 1.6 * s, depth: 1.4 * s, wallH: 1.5 * s, roofH: 0.7 * s, wall: k.timber, roofColor: k.thatch)
        root.childNode(withName: "cottage", recursively: false)?.position = SCNVector3(1.55 * s, 0, 1.55 * s)
        return root
    }

    static func undergroundEntrance() -> SCNNode {
        let root = named("underground_entrance")
        k.box(to: root, 2 * s, 0.35 * s, 2 * s, k.stone, at: SCNVector3(0, 0.18 * s, 0))
        k.cylinder(to: root, radius: 0.55 * s, height: 0.16 * s, color: NSColor(white: 0.06, alpha: 1), at: SCNVector3(0, 0.38 * s, 0), segments: 10)
        k.box(to: root, 0.55 * s, 0.12 * s, 0.85 * s, k.timberDark, at: SCNVector3(0, 0.42 * s, 0.35 * s))
        k.box(to: root, 0.55 * s, 0.12 * s, 0.75 * s, k.timber, at: SCNVector3(0, 0.30 * s, 0.05 * s))
        k.box(to: root, 0.55 * s, 0.12 * s, 0.65 * s, k.timberDark, at: SCNVector3(0, 0.18 * s, -0.25 * s))
        k.box(to: root, 0.10 * s, 0.85 * s, 0.10 * s, k.timber, at: SCNVector3(-0.7 * s, 0.70 * s, -0.55 * s))
        k.box(to: root, 0.10 * s, 0.85 * s, 0.10 * s, k.timber, at: SCNVector3(0.7 * s, 0.70 * s, -0.55 * s))
        k.box(to: root, 1.55 * s, 0.08 * s, 0.12 * s, k.timberDark, at: SCNVector3(0, 1.12 * s, -0.55 * s))
        return root
    }

    static func undergroundCorridor() -> SCNNode {
        let root = named("underground_corridor")
        k.box(to: root, 0.95 * s, 2.2 * s, 0.12 * s, k.timberDark, at: SCNVector3(-0.42 * s, 1.1 * s, 0))
        k.box(to: root, 0.95 * s, 2.2 * s, 0.12 * s, k.timberDark, at: SCNVector3(0.42 * s, 1.1 * s, 0))
        k.box(to: root, 1.0 * s, 0.14 * s, 0.95 * s, k.timber, at: SCNVector3(0, 2.25 * s, 0))
        k.box(to: root, 0.9 * s, 0.08 * s, 0.9 * s, k.earth, at: SCNVector3(0, 0.04 * s, 0))
        return root
    }

    // MARK: - Katalog (nema SceneKit tipa)

    static func catalogFallback(name: String) -> SCNNode? {
        switch name {
        case "Skladište": return lager()
        case "Silos": return granary()
        case "Baraka": return training()
        case "Kula": return tower()
        case "Cesta": return InfrastructureShapes.road()
        case "Most": return InfrastructureShapes.bridge()
        case "Crkva", "Samostan": return church()
        case "Zidine": return wallStub()
        case "Zlato": return pile(NSColor(red: 0.82, green: 0.68, blue: 0.22, alpha: 1))
        case "Drvo": return woodcutter()
        case "Kamen": return stoneQuarry()
        case "Pšenica": return pile(NSColor(red: 0.82, green: 0.68, blue: 0.22, alpha: 1))
        case "Povrće": return pile(NSColor(red: 0.32, green: 0.55, blue: 0.22, alpha: 1))
        default: return nil
        }
    }

    static func tower() -> SCNNode {
        let root = named("tower")
        k.cylinder(to: root, radius: 1.15 * s, height: 6.4 * s, color: k.stone, at: SCNVector3(0, 3.2 * s, 0), segments: 10)
        k.cone(to: root, top: 0, bottom: 1.45 * s, height: 1.6 * s, color: k.roofTile, at: SCNVector3(0, 7.2 * s, 0))
        k.box(to: root, 0.45 * s, 1.15 * s, 0.08 * s, k.door, at: SCNVector3(0, 0.62 * s, 1.18 * s))
        return root
    }

    static func road() -> SCNNode {
        let root = named("road")
        k.box(to: root, 2.4 * s, 0.08 * s, 1.1 * s, k.stoneDark, at: SCNVector3(0, 0.04 * s, 0))
        k.box(to: root, 0.18 * s, 0.04 * s, 1.0 * s, k.stone, at: SCNVector3(0, 0.08 * s, 0))
        return root
    }

    static func bridge() -> SCNNode {
        let root = named("bridge")
        k.box(to: root, 2.4 * s, 0.18 * s, 1.0 * s, k.timber, at: SCNVector3(0, 0.55 * s, 0))
        k.box(to: root, 0.16 * s, 0.7 * s, 0.16 * s, k.timberDark, at: SCNVector3(-1.0 * s, 0.35 * s, 0.4 * s))
        k.box(to: root, 0.16 * s, 0.7 * s, 0.16 * s, k.timberDark, at: SCNVector3(1.0 * s, 0.35 * s, 0.4 * s))
        k.box(to: root, 0.16 * s, 0.7 * s, 0.16 * s, k.timberDark, at: SCNVector3(-1.0 * s, 0.35 * s, -0.4 * s))
        k.box(to: root, 0.16 * s, 0.7 * s, 0.16 * s, k.timberDark, at: SCNVector3(1.0 * s, 0.35 * s, -0.4 * s))
        return root
    }

    static func wallStub() -> SCNNode {
        let root = named("wall")
        k.box(to: root, 1.0 * s, 2.4 * s, 0.45 * s, k.stone, at: SCNVector3(0, 1.2 * s, 0))
        k.box(to: root, 1.05 * s, 0.22 * s, 0.55 * s, k.stoneDark, at: SCNVector3(0, 2.5 * s, 0))
        return root
    }

    static func pile(_ color: NSColor) -> SCNNode {
        let root = named("pile")
        k.sphere(to: root, radius: 0.55 * s, color: color, at: SCNVector3(0, 0.35 * s, 0), segments: 8)
            .scale = SCNVector3(1.2, 0.7, 1.1)
        k.sphere(to: root, radius: 0.32 * s, color: color.blended(withFraction: 0.2, of: .black) ?? color, at: SCNVector3(0.35 * s, 0.22 * s, 0.15 * s), segments: 6)
        return root
    }

    static func foodHall() -> SCNNode {
        let root = named("food")
        let side = 4 * s
        let post = 0.16 * s
        let half = side / 2 - post / 2
        let beam = 0.14 * s

        k.box(to: root, side, 0.08 * s, side, k.earth, at: SCNVector3(0, 0.04 * s, 0))

        let corners: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for c in corners {
            k.box(to: root, post, side, post, k.timberDark, at: SCNVector3(c.0 * half, side / 2, c.1 * half))
        }
        for y in [beam / 2, side - beam / 2] {
            k.box(to: root, side, beam, beam, k.timber, at: SCNVector3(0, y, -half))
            k.box(to: root, side, beam, beam, k.timber, at: SCNVector3(0, y, half))
            k.box(to: root, beam, beam, side, k.timber, at: SCNVector3(-half, y, 0))
            k.box(to: root, beam, beam, side, k.timber, at: SCNVector3(half, y, 0))
        }

        let panel = 0.06 * s
        let wallH = side - beam * 2
        let wallY = side / 2
        glassWood(to: root, side - post * 2, wallH, panel, at: SCNVector3(0, wallY, -half))
        glassWood(to: root, panel, wallH, side - post * 2, at: SCNVector3(-half, wallY, 0))
        glassWood(to: root, panel, wallH, side - post * 2, at: SCNVector3(half, wallY, 0))
        let doorW = 1.15 * s
        let sideW = (side - post * 2 - doorW) / 2
        let sideX = doorW / 2 + sideW / 2
        glassWood(to: root, sideW, wallH, panel, at: SCNVector3(-sideX, wallY, half))
        glassWood(to: root, sideW, wallH, panel, at: SCNVector3(sideX, wallY, half))
        k.box(to: root, 0.08 * s, 2.3 * s, 0.08 * s, k.timberDark, at: SCNVector3(-doorW / 2, 1.15 * s, half))
        k.box(to: root, 0.08 * s, 2.3 * s, 0.08 * s, k.timberDark, at: SCNVector3(doorW / 2, 1.15 * s, half))
        k.box(to: root, doorW, 0.08 * s, 0.08 * s, k.timberDark, at: SCNVector3(0, 2.3 * s, half))

        k.box(to: root, 2.4 * s, 0.06 * s, 0.7 * s, k.timber, at: SCNVector3(-0.4 * s, 1.15 * s, -0.7 * s))
        k.box(to: root, 2.4 * s, 0.06 * s, 0.7 * s, k.timber, at: SCNVector3(-0.4 * s, 2.15 * s, -0.7 * s))
        k.box(to: root, 0.55 * s, 0.38 * s, 0.45 * s, k.timberDark, at: SCNVector3(-1.15 * s, 0.28 * s, 0.85 * s))
        k.box(to: root, 0.48 * s, 0.32 * s, 0.4 * s, k.straw, at: SCNVector3(-0.45 * s, 0.24 * s, 0.95 * s))
        k.box(to: root, 0.42 * s, 0.28 * s, 0.36 * s, k.straw, at: SCNVector3(0.15 * s, 0.5 * s, 0.9 * s))
        k.cylinder(to: root, radius: 0.22 * s, height: 0.42 * s, color: k.timberDark, at: SCNVector3(1.05 * s, 0.28 * s, -0.85 * s), segments: 8)
        k.cylinder(to: root, radius: 0.18 * s, height: 0.36 * s, color: k.timber, at: SCNVector3(1.15 * s, 0.72 * s, -0.35 * s), segments: 8)
        return root
    }

    @discardableResult
    private static func glassWood(to root: SCNNode, _ w: CGFloat, _ h: CGFloat, _ l: CGFloat, at p: SCNVector3) -> SCNNode {
        let wood = NSColor(red: 0.62, green: 0.40, blue: 0.20, alpha: 1)
        let node = k.box(to: root, w, h, l, wood, at: p)
        if let mat = node.geometry?.firstMaterial {
            mat.transparency = 0.38
            mat.transparencyMode = .dualLayer
            mat.blendMode = .alpha
            mat.isDoubleSided = true
        }
        return node
    }

    static func industryHall() -> SCNNode {
        let root = named("industry")
        k.slab(to: root, width: 3 * s, depth: 3 * s, color: k.stoneDark)
        k.cottage(to: root, width: 2.5 * s, depth: 2.3 * s, wallH: 2.0 * s, roofH: 1.0 * s, wall: k.stone, roofColor: k.roofDark)
        return root
    }

    private static func named(_ name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name
        return node
    }
}
