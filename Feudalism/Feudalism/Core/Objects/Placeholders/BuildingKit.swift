//
//  BuildingKit.swift
//  Feudalism
//
//  Zajednički dijelovi za grubi 3D oblik građevina (kutija, krov, stup).
//

import Foundation
import SceneKit
import AppKit

enum BuildingKit {
    static var cell: CGFloat { PlaceholderBox.worldUnitsPerCell }

    static let plaster = NSColor(red: 0.72, green: 0.62, blue: 0.50, alpha: 1)
    static let plasterLight = NSColor(red: 0.80, green: 0.72, blue: 0.60, alpha: 1)
    static let timber = NSColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1)
    static let timberDark = NSColor(red: 0.28, green: 0.17, blue: 0.10, alpha: 1)
    static let stone = NSColor(red: 0.56, green: 0.53, blue: 0.48, alpha: 1)
    static let stoneDark = NSColor(red: 0.38, green: 0.36, blue: 0.33, alpha: 1)
    static let roofTile = NSColor(red: 0.48, green: 0.18, blue: 0.14, alpha: 1)
    static let roofDark = NSColor(red: 0.34, green: 0.14, blue: 0.12, alpha: 1)
    static let thatch = NSColor(red: 0.64, green: 0.52, blue: 0.28, alpha: 1)
    static let iron = NSColor(red: 0.42, green: 0.43, blue: 0.45, alpha: 1)
    static let ironDark = NSColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
    static let earth = NSColor(red: 0.28, green: 0.20, blue: 0.12, alpha: 1)
    static let straw = NSColor(red: 0.72, green: 0.62, blue: 0.32, alpha: 1)
    static let water = NSColor(red: 0.22, green: 0.42, blue: 0.62, alpha: 0.9)
    static let glass = NSColor(red: 0.55, green: 0.75, blue: 0.62, alpha: 0.55)
    static let door = NSColor(red: 0.26, green: 0.15, blue: 0.09, alpha: 1)

    static func material(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.ambient.contents = color.blended(withFraction: 0.35, of: .black) ?? color
        mat.lightingModel = .blinn
        mat.isDoubleSided = color.alphaComponent < 0.99
        return mat
    }

    @discardableResult
    static func box(
        to root: SCNNode,
        _ w: CGFloat, _ h: CGFloat, _ l: CGFloat,
        _ color: NSColor,
        at p: SCNVector3,
        name: String? = nil
    ) -> SCNNode {
        let geom = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        geom.materials = [material(color)]
        let node = SCNNode(geometry: geom)
        node.position = p
        node.name = name
        root.addChildNode(node)
        return node
    }

    @discardableResult
    static func cylinder(
        to root: SCNNode,
        radius: CGFloat,
        height: CGFloat,
        color: NSColor,
        at p: SCNVector3,
        segments: Int = 10
    ) -> SCNNode {
        let geom = SCNCylinder(radius: radius, height: height)
        geom.radialSegmentCount = segments
        geom.materials = [material(color)]
        let node = SCNNode(geometry: geom)
        node.position = p
        root.addChildNode(node)
        return node
    }

    @discardableResult
    static func cone(
        to root: SCNNode,
        top: CGFloat,
        bottom: CGFloat,
        height: CGFloat,
        color: NSColor,
        at p: SCNVector3
    ) -> SCNNode {
        let geom = SCNCone(topRadius: top, bottomRadius: bottom, height: height)
        geom.radialSegmentCount = 8
        geom.materials = [material(color)]
        let node = SCNNode(geometry: geom)
        node.position = p
        root.addChildNode(node)
        return node
    }

    @discardableResult
    static func sphere(
        to root: SCNNode,
        radius: CGFloat,
        color: NSColor,
        at p: SCNVector3,
        segments: Int = 8
    ) -> SCNNode {
        let geom = SCNSphere(radius: radius)
        geom.segmentCount = segments
        geom.materials = [material(color)]
        let node = SCNNode(geometry: geom)
        node.position = p
        root.addChildNode(node)
        return node
    }

    @discardableResult
    static func roof(
        to root: SCNNode,
        width: CGFloat,
        length: CGFloat,
        height: CGFloat,
        color: NSColor,
        y: CGFloat
    ) -> SCNNode {
        let geom = SCNPyramid(width: width, height: height, length: length)
        geom.materials = [material(color)]
        let node = SCNNode(geometry: geom)
        node.position = SCNVector3(0, y + height * 0.5, 0)
        root.addChildNode(node)
        return node
    }

    /// Klasični dvovod. Na mapi se može pretvoriti u L ako su zidovi u kutu.
    @discardableResult
    static func adaptiveRoof(
        to root: SCNNode,
        width: CGFloat,
        length: CGFloat,
        height: CGFloat,
        color: NSColor,
        y: CGFloat,
        thatch: Bool = false
    ) -> SCNNode {
        let node = RoofShapes.make(kind: .gableX, width: width, length: length, height: height, color: color, thatch: thatch)
        node.position = SCNVector3(0, y, 0)
        root.addChildNode(node)
        return node
    }

    /// Jednostavna kuća: zidovi + krov + vrata. Središte u tlocrtu, dno na y=0.
    @discardableResult
    static func cottage(
        to root: SCNNode,
        width: CGFloat,
        depth: CGFloat,
        wallH: CGFloat,
        roofH: CGFloat,
        wall: NSColor = plaster,
        roofColor: NSColor = roofTile,
        doorOnZ: Bool = true
    ) -> SCNNode {
        let house = SCNNode()
        house.name = "cottage"
        box(to: house, width, wallH, depth, wall, at: SCNVector3(0, wallH / 2, 0))
        adaptiveRoof(to: house, width: width * 1.12, length: depth * 1.12, height: roofH, color: roofColor, y: wallH, thatch: roofColor == thatch)
        let doorW = min(0.55, width * 0.22)
        let doorH = min(1.15, wallH * 0.62)
        if doorOnZ {
            box(to: house, doorW, doorH, 0.06, door, at: SCNVector3(0, doorH / 2, depth / 2 + 0.02))
        } else {
            box(to: house, 0.06, doorH, doorW, door, at: SCNVector3(width / 2 + 0.02, doorH / 2, 0))
        }
        root.addChildNode(house)
        return house
    }

    static func slab(to root: SCNNode, width: CGFloat, depth: CGFloat, color: NSColor, height: CGFloat = 0.14) {
        box(to: root, width, height, depth, color, at: SCNVector3(0, height / 2, 0), name: "slab")
    }

    static func chimney(to root: SCNNode, at p: SCNVector3, height: CGFloat = 1.4) {
        box(to: root, 0.32, height, 0.32, stoneDark, at: p)
        box(to: root, 0.40, 0.12, 0.40, stone, at: SCNVector3(p.x, p.y + height / 2 + 0.04, p.z))
    }
}
