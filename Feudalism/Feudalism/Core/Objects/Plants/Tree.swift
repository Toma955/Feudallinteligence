//
//  Tree.swift
//  Feudalism
//
//  Stablo (listopadno): deblo s dvije grane i krošnja od nekoliko grudica lišća. 2×2, ~7 m.
//

import Foundation
import SceneKit
import AppKit

enum Tree: PlaceableSceneKitObject {
    static let objectId = "object_tree"
    static let displayCode = "ST"

    static var gameObject: GameObject {
        let d = ObjectDimensions.tree
        return GameObject(id: objectId, name: "Stablo", category: .resursi, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    private static func material(_ color: NSColor, roughness: CGFloat = 0.9) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.ambient.contents = color.blended(withFraction: 0.5, of: .black)
        m.specular.contents = NSColor(white: 0.08, alpha: 1)
        m.roughness.contents = roughness
        m.lightingModel = .blinn
        return m
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "tree"
        let height = PlaceholderBox.heightCells(ObjectDimensions.tree.heightCells)
        let unit = height / 7

        let bark = material(NSColor(red: 0.36, green: 0.24, blue: 0.14, alpha: 1))
        let leavesDark = material(NSColor(red: 0.16, green: 0.36, blue: 0.14, alpha: 1))
        let leavesMid = material(NSColor(red: 0.24, green: 0.48, blue: 0.18, alpha: 1))
        let leavesLight = material(NSColor(red: 0.36, green: 0.58, blue: 0.22, alpha: 1))

        let flare = SCNCone(topRadius: 0.26 * unit, bottomRadius: 0.42 * unit, height: 0.35 * unit)
        flare.radialSegmentCount = 10
        flare.materials = [bark]
        let flareNode = SCNNode(geometry: flare)
        flareNode.position = SCNVector3(0, 0.175 * unit, 0)
        container.addChildNode(flareNode)

        let trunkHeight = 3.6 * unit
        let trunk = SCNCone(topRadius: 0.14 * unit, bottomRadius: 0.26 * unit, height: trunkHeight)
        trunk.radialSegmentCount = 10
        trunk.materials = [bark]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, 0.3 * unit + trunkHeight / 2, 0)
        trunkNode.eulerAngles.z = 0.04
        container.addChildNode(trunkNode)

        let branches: [(y: CGFloat, yaw: CGFloat, tilt: CGFloat, length: CGFloat)] = [
            (2.5, 0.3, 0.85, 1.4),
            (2.9, 2.6, 0.75, 1.2),
            (3.3, 4.4, 0.6, 1.0),
        ]
        for branch in branches {
            let geo = SCNCylinder(radius: 0.07 * unit, height: branch.length * unit)
            geo.radialSegmentCount = 6
            geo.materials = [bark]
            let node = SCNNode(geometry: geo)
            node.pivot = SCNMatrix4MakeTranslation(0, -branch.length * unit / 2, 0)
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, branch.y * unit, 0)
            pivot.eulerAngles.y = branch.yaw
            node.eulerAngles.z = branch.tilt
            pivot.addChildNode(node)
            container.addChildNode(pivot)
        }

        let clumps: [(x: CGFloat, y: CGFloat, z: CGFloat, r: CGFloat, mat: SCNMaterial)] = [
            (0, 4.6, 0, 1.55, leavesMid),
            (0.9, 4.1, 0.3, 1.1, leavesDark),
            (-0.8, 4.2, -0.4, 1.15, leavesDark),
            (0.2, 4.0, -1.0, 1.0, leavesMid),
            (-0.3, 4.0, 0.95, 1.05, leavesMid),
            (0.35, 5.6, 0.2, 1.0, leavesLight),
            (-0.45, 5.3, -0.35, 0.85, leavesLight),
        ]
        for clump in clumps {
            let sphere = SCNSphere(radius: clump.r * unit)
            sphere.segmentCount = 12
            sphere.materials = [clump.mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(clump.x * unit, clump.y * unit, clump.z * unit)
            node.scale = SCNVector3(1, 0.82, 1)
            container.addChildNode(node)
        }
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}
