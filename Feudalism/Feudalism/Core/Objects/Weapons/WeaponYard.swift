//
//  WeaponYard.swift
//  Feudalism
//
//  Zajednička baza radionica (oružje i pekara):
//  četiri drvena stupa nose krov, pod je kameni mozaik.
//  Namještaj unutra ovisi o namjeni.
//

import Foundation
import SceneKit
import AppKit

enum WeaponYard {
    enum Craft {
        case sword
        case shield
        case bow
        case spear
        case leather
        case armory
        case bakery
    }

    static func makeNode(name: String, craft: Craft, cells: Int = 5) -> SCNNode {
        let root = SCNNode()
        root.name = name
        addBase(to: root, cells: cells)
        addCraft(craft, to: root)
        return root
    }

    private static func addBase(to root: SCNNode, cells: Int) {
        let k = BuildingKit.self
        let s = k.cell
        let side = CGFloat(max(3, cells)) * s
        let mosaicH: CGFloat = 0.14
        addMosaic(to: root, side: side, height: mosaicH)

        let inset = side * 0.32
        let postH = 2.45 * s
        let postR = 0.11 * s
        let spots: [(CGFloat, CGFloat)] = [(-inset, -inset), (inset, -inset), (-inset, inset), (inset, inset)]
        for spot in spots {
            k.cylinder(to: root, radius: postR, height: postH, color: k.timber, at: SCNVector3(spot.0, mosaicH + postH / 2, spot.1), segments: 8)
            k.box(to: root, postR * 2.4, 0.10 * s, postR * 2.4, k.timberDark, at: SCNVector3(spot.0, mosaicH + 0.05 * s, spot.1))
        }

        k.box(to: root, side * 0.68, 0.12 * s, 0.14 * s, k.timberDark, at: SCNVector3(0, mosaicH + postH, -inset))
        k.box(to: root, side * 0.68, 0.12 * s, 0.14 * s, k.timberDark, at: SCNVector3(0, mosaicH + postH, inset))
        k.box(to: root, 0.14 * s, 0.12 * s, side * 0.68, k.timberDark, at: SCNVector3(-inset, mosaicH + postH, 0))
        k.box(to: root, 0.14 * s, 0.12 * s, side * 0.68, k.timberDark, at: SCNVector3(inset, mosaicH + postH, 0))

        k.adaptiveRoof(
            to: root,
            width: side * 1.08,
            length: side * 1.08,
            height: 1.35 * s,
            color: k.thatch,
            y: mosaicH + postH,
            thatch: true
        )
    }

    private static func addMosaic(to root: SCNNode, side: CGFloat, height: CGFloat) {
        let k = BuildingKit.self
        let tiles = 8
        let tile = side / CGFloat(tiles)
        let a = NSColor(red: 0.58, green: 0.54, blue: 0.48, alpha: 1)
        let b = NSColor(red: 0.42, green: 0.40, blue: 0.37, alpha: 1)
        let c = NSColor(red: 0.50, green: 0.38, blue: 0.32, alpha: 1)
        let palette = [a, b, c, b]
        let origin = -side / 2 + tile / 2
        for r in 0..<tiles {
            for col in 0..<tiles {
                let color = palette[(r + col * 2) % palette.count]
                k.box(
                    to: root,
                    tile * 0.96,
                    height,
                    tile * 0.96,
                    color,
                    at: SCNVector3(origin + CGFloat(col) * tile, height / 2, origin + CGFloat(r) * tile)
                )
            }
        }
    }

    private static func addCraft(_ craft: Craft, to root: SCNNode) {
        switch craft {
        case .sword: addSwords(to: root)
        case .shield: addShields(to: root)
        case .bow: addBows(to: root)
        case .spear: addSpears(to: root)
        case .leather: addLeather(to: root)
        case .armory: addArmory(to: root)
        case .bakery: addBakery(to: root)
        }
    }

    private static func addSwords(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        k.box(to: root, 1.55 * s, 0.62 * s, 0.55 * s, k.timber, at: SCNVector3(-0.85 * s, 0.48 * s, -0.15 * s))
        k.box(to: root, 0.58 * s, 0.38 * s, 0.58 * s, k.ironDark, at: SCNVector3(0.85 * s, 0.36 * s, 0.15 * s))
        k.box(to: root, 0.12 * s, 0.95 * s, 0.04 * s, k.iron, at: SCNVector3(0.85 * s, 0.92 * s, 0.15 * s))
        k.box(to: root, 0.28 * s, 0.05 * s, 0.05 * s, k.timber, at: SCNVector3(0.85 * s, 0.58 * s, 0.15 * s))
        k.box(to: root, 0.48 * s, 0.55 * s, 0.48 * s, k.ironDark, at: SCNVector3(1.25 * s, 0.42 * s, -0.85 * s))
        k.box(to: root, 0.20 * s, 0.75 * s, 0.20 * s, k.stoneDark, at: SCNVector3(1.25 * s, 0.95 * s, -0.85 * s))
        for i in 0..<4 {
            let x = (-1.15 + CGFloat(i) * 0.28) * s
            k.box(to: root, 0.06 * s, 0.85 * s, 0.03 * s, k.iron, at: SCNVector3(x, 0.78 * s, 0.95 * s))
            k.box(to: root, 0.20 * s, 0.04 * s, 0.04 * s, k.timber, at: SCNVector3(x, 0.46 * s, 0.95 * s))
        }
        k.box(to: root, 1.25 * s, 0.10 * s, 0.10 * s, k.timberDark, at: SCNVector3(-0.70 * s, 0.32 * s, 0.95 * s))
    }

    private static func addShields(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        k.box(to: root, 1.45 * s, 0.58 * s, 0.62 * s, k.timber, at: SCNVector3(0.15 * s, 0.46 * s, -0.55 * s))
        let spots: [(CGFloat, CGFloat)] = [(-1.05, 0.55), (-0.15, 1.05), (0.85, 0.65)]
        for (i, spot) in spots.enumerated() {
            k.cylinder(to: root, radius: 0.04 * s, height: 1.15 * s, color: k.timber, at: SCNVector3(spot.0 * s, 0.74 * s, spot.1 * s))
            let shield = k.cylinder(
                to: root,
                radius: 0.36 * s,
                height: 0.07 * s,
                color: i % 2 == 0 ? NSColor(red: 0.55, green: 0.18, blue: 0.16, alpha: 1) : NSColor(red: 0.22, green: 0.32, blue: 0.48, alpha: 1),
                at: SCNVector3(spot.0 * s, 0.95 * s, spot.1 * s)
            )
            shield.eulerAngles.x = CGFloat.pi / 2
            k.sphere(to: root, radius: 0.07 * s, color: k.iron, at: SCNVector3(spot.0 * s, 0.95 * s, spot.1 * s + 0.05 * s), segments: 6)
        }
    }

    private static func addBows(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        k.box(to: root, 1.35 * s, 0.38 * s, 0.55 * s, k.timberDark, at: SCNVector3(-0.75 * s, 0.34 * s, 0.15 * s))
        for i in 0..<5 {
            let x = (-1.2 + CGFloat(i) * 0.22) * s
            k.box(to: root, 0.08 * s, 0.08 * s, 1.25 * s, k.timber, at: SCNVector3(x, 0.58 * s, 0.15 * s))
        }
        for x in [-0.15, 0.45, 1.05] {
            let bow = SCNTorus(ringRadius: 0.48 * s, pipeRadius: 0.03 * s)
            bow.materials = [k.material(k.timber)]
            let node = SCNNode(geometry: bow)
            node.position = SCNVector3(x * s, 0.98 * s, 0.85 * s)
            node.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
            node.scale = SCNVector3(0.35, 1, 1)
            root.addChildNode(node)
        }
        k.box(to: root, 0.40 * s, 0.22 * s, 0.50 * s, k.straw, at: SCNVector3(1.15 * s, 0.28 * s, -0.65 * s))
    }

    private static func addSpears(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        k.box(to: root, 1.7 * s, 0.14 * s, 0.14 * s, k.timberDark, at: SCNVector3(0, 0.95 * s, 0.35 * s))
        k.box(to: root, 0.10 * s, 1.15 * s, 0.10 * s, k.timber, at: SCNVector3(-0.80 * s, 0.74 * s, 0.35 * s))
        k.box(to: root, 0.10 * s, 1.15 * s, 0.10 * s, k.timber, at: SCNVector3(0.80 * s, 0.74 * s, 0.35 * s))
        for i in 0..<7 {
            let x = (-0.70 + CGFloat(i) * 0.22) * s
            k.cylinder(to: root, radius: 0.025 * s, height: 1.75 * s, color: k.timber, at: SCNVector3(x, 1.12 * s, 0.35 * s), segments: 5)
            k.cone(to: root, top: 0, bottom: 0.045 * s, height: 0.16 * s, color: k.iron, at: SCNVector3(x, 2.08 * s, 0.35 * s))
        }
        k.box(to: root, 1.1 * s, 0.55 * s, 0.50 * s, k.timber, at: SCNVector3(-0.15 * s, 0.44 * s, -0.75 * s))
    }

    private static func addLeather(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        let hide = NSColor(red: 0.55, green: 0.36, blue: 0.22, alpha: 1)
        let hideDark = NSColor(red: 0.38, green: 0.22, blue: 0.12, alpha: 1)
        for (i, x) in [CGFloat(-0.95), -0.10, 0.75].enumerated() {
            k.box(to: root, 0.08 * s, 1.35 * s, 0.08 * s, k.timber, at: SCNVector3(x * s, 0.86 * s, -0.35 * s))
            k.box(to: root, 0.08 * s, 1.35 * s, 0.08 * s, k.timber, at: SCNVector3(x * s, 0.86 * s, 0.45 * s))
            k.box(to: root, 0.08 * s, 0.08 * s, 0.88 * s, k.timber, at: SCNVector3(x * s, 1.50 * s, 0.05 * s))
            let skin = k.box(to: root, 0.04 * s, 0.90 * s, 0.62 * s, i == 1 ? hideDark : hide, at: SCNVector3(x * s, 0.98 * s, 0.05 * s))
            skin.eulerAngles.z = i == 2 ? 0.10 : -0.08
        }
        k.box(to: root, 1.15 * s, 0.22 * s, 0.62 * s, k.timber, at: SCNVector3(0.15 * s, 0.28 * s, 1.05 * s))
    }

    private static func addArmory(to root: SCNNode) {
        addSwords(to: root)
        let k = BuildingKit.self
        let s = k.cell
        k.box(to: root, 0.70 * s, 0.45 * s, 0.48 * s, k.timberDark, at: SCNVector3(1.15 * s, 0.38 * s, 1.05 * s))
        k.box(to: root, 0.70 * s, 0.40 * s, 0.48 * s, k.timber, at: SCNVector3(1.15 * s, 0.80 * s, 1.05 * s))
        let shield = k.cylinder(
            to: root,
            radius: 0.30 * s,
            height: 0.06 * s,
            color: NSColor(red: 0.45, green: 0.16, blue: 0.14, alpha: 1),
            at: SCNVector3(-1.25 * s, 0.90 * s, 1.05 * s)
        )
        shield.eulerAngles.x = CGFloat.pi / 2
    }

    private static func addBakery(to root: SCNNode) {
        let k = BuildingKit.self
        let s = k.cell
        k.cylinder(to: root, radius: 0.52 * s, height: 0.95 * s, color: k.stoneDark, at: SCNVector3(0.85 * s, 0.62 * s, -0.15 * s), segments: 10)
        k.box(to: root, 0.28 * s, 0.85 * s, 0.28 * s, k.stone, at: SCNVector3(0.85 * s, 1.35 * s, -0.15 * s))
        k.box(to: root, 1.45 * s, 0.55 * s, 0.62 * s, k.timber, at: SCNVector3(-0.55 * s, 0.44 * s, 0.20 * s))
        let bread = NSColor(red: 0.78, green: 0.52, blue: 0.26, alpha: 1)
        k.box(to: root, 0.28 * s, 0.10 * s, 0.16 * s, bread, at: SCNVector3(-0.85 * s, 0.76 * s, 0.20 * s))
        k.box(to: root, 0.26 * s, 0.09 * s, 0.15 * s, bread, at: SCNVector3(-0.45 * s, 0.76 * s, 0.28 * s))
        k.box(to: root, 0.24 * s, 0.08 * s, 0.14 * s, bread, at: SCNVector3(-0.20 * s, 0.75 * s, 0.08 * s))
        k.box(to: root, 0.40 * s, 0.32 * s, 0.32 * s, k.straw, at: SCNVector3(-0.95 * s, 0.32 * s, 0.95 * s))
        k.box(to: root, 0.36 * s, 0.28 * s, 0.30 * s, NSColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1), at: SCNVector3(-0.50 * s, 0.30 * s, 0.95 * s))
        k.box(to: root, 0.22 * s, 0.42 * s, 0.08 * s, k.timberDark, at: SCNVector3(0.85 * s, 0.42 * s, 0.42 * s))
    }
}
