//
//  WeaponPreviewShapes.swift
//  Feudalism
//
//  Oblici oružja u Aboutu: mač, štit, koplje, luk, strijela, samostrijel, buzdovan i koža.
//

import Foundation
import SceneKit
import AppKit

enum WeaponPreviewShapes {
    static func node(_ kind: AboutGoodKind) -> SCNNode {
        let root: SCNNode
        switch kind {
        case .sword: root = sword()
        case .shield: root = shield()
        case .spear: root = spear()
        case .bow: root = bow()
        case .arrow: root = arrow()
        case .crossbow: root = crossbow()
        case .mace: root = mace()
        case .leather: root = leather()
        default: root = SCNNode()
        }
        fitHeight(root, to: 1.15)
        return root
    }

    private static func sword() -> SCNNode {
        let root = SCNNode()
        let steel = mat(NSColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1))
        let dark = mat(NSColor(red: 0.28, green: 0.22, blue: 0.16, alpha: 1))
        let gold = mat(NSColor(red: 0.72, green: 0.58, blue: 0.22, alpha: 1))
        let blade = SCNBox(width: 0.08, height: 0.92, length: 0.02, chamferRadius: 0.006)
        blade.materials = [steel]
        let bladeNode = SCNNode(geometry: blade)
        bladeNode.position.y = 0.62
        root.addChildNode(bladeNode)
        let tip = SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.16)
        tip.materials = [steel]
        let tipNode = SCNNode(geometry: tip)
        tipNode.position.y = 1.14
        root.addChildNode(tipNode)
        let guardBar = SCNBox(width: 0.36, height: 0.04, length: 0.06, chamferRadius: 0.01)
        guardBar.materials = [gold]
        let guardNode = SCNNode(geometry: guardBar)
        guardNode.position.y = 0.16
        root.addChildNode(guardNode)
        let grip = SCNCylinder(radius: 0.035, height: 0.22)
        grip.materials = [dark]
        let gripNode = SCNNode(geometry: grip)
        gripNode.position.y = 0.05
        root.addChildNode(gripNode)
        let pommel = SCNSphere(radius: 0.05)
        pommel.materials = [gold]
        let pommelNode = SCNNode(geometry: pommel)
        pommelNode.position.y = -0.08
        root.addChildNode(pommelNode)
        return root
    }

    private static func shield() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.42, green: 0.26, blue: 0.14, alpha: 1))
        let steel = mat(NSColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 1))
        let face = SCNCylinder(radius: 0.48, height: 0.06)
        face.radialSegmentCount = 28
        face.materials = [wood]
        let faceNode = SCNNode(geometry: face)
        faceNode.eulerAngles.x = .pi / 2
        faceNode.position.y = 0.48
        root.addChildNode(faceNode)
        let rim = SCNTorus(ringRadius: 0.46, pipeRadius: 0.035)
        rim.ringSegmentCount = 28
        rim.pipeSegmentCount = 10
        rim.materials = [steel]
        let rimNode = SCNNode(geometry: rim)
        rimNode.eulerAngles.x = .pi / 2
        rimNode.position.y = 0.48
        root.addChildNode(rimNode)
        let boss = SCNSphere(radius: 0.1)
        boss.materials = [steel]
        let bossNode = SCNNode(geometry: boss)
        bossNode.scale = SCNVector3(1, 0.55, 1)
        bossNode.position = SCNVector3(0, 0.52, 0.04)
        root.addChildNode(bossNode)
        return root
    }

    private static func spear() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.48, green: 0.32, blue: 0.16, alpha: 1))
        let steel = mat(NSColor(red: 0.7, green: 0.72, blue: 0.74, alpha: 1))
        let shaft = SCNCylinder(radius: 0.025, height: 1.15)
        shaft.materials = [wood]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position.y = 0.58
        root.addChildNode(shaftNode)
        let head = SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.28)
        head.materials = [steel]
        let headNode = SCNNode(geometry: head)
        headNode.position.y = 1.24
        root.addChildNode(headNode)
        let socket = SCNCylinder(radius: 0.04, height: 0.08)
        socket.materials = [steel]
        let socketNode = SCNNode(geometry: socket)
        socketNode.position.y = 1.08
        root.addChildNode(socketNode)
        return root
    }

    private static func bow() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1))
        let string = mat(NSColor(red: 0.85, green: 0.82, blue: 0.72, alpha: 1))
        for i in 0..<8 {
            let t = CGFloat(i) / 7
            let angle = -1.15 + t * 2.3
            let limb = SCNCapsule(capRadius: 0.028, height: 0.16)
            limb.materials = [wood]
            let node = SCNNode(geometry: limb)
            node.eulerAngles.z = angle
            node.position = SCNVector3(sin(angle) * 0.42, 0.15 + (1 - cos(angle)) * 0.55, 0)
            root.addChildNode(node)
        }
        let cord = SCNCylinder(radius: 0.008, height: 0.95)
        cord.materials = [string]
        let cordNode = SCNNode(geometry: cord)
        cordNode.position = SCNVector3(0.38, 0.55, 0)
        root.addChildNode(cordNode)
        return root
    }

    private static func arrow() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.55, green: 0.4, blue: 0.22, alpha: 1))
        let steel = mat(NSColor(red: 0.68, green: 0.7, blue: 0.72, alpha: 1))
        let feather = mat(NSColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 1))
        let shaft = SCNCylinder(radius: 0.015, height: 0.95)
        shaft.materials = [wood]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.eulerAngles.z = .pi / 2
        shaftNode.position.y = 0.2
        root.addChildNode(shaftNode)
        let head = SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.16)
        head.materials = [steel]
        let headNode = SCNNode(geometry: head)
        headNode.eulerAngles.z = -.pi / 2
        headNode.position = SCNVector3(0.55, 0.2, 0)
        root.addChildNode(headNode)
        for z in [CGFloat(0.04), CGFloat(-0.04), CGFloat(0)] {
            let vane = SCNBox(width: 0.14, height: 0.012, length: 0.05, chamferRadius: 0)
            vane.materials = [feather]
            let node = SCNNode(geometry: vane)
            node.position = SCNVector3(-0.4, 0.2, z)
            node.eulerAngles.x = z == 0 ? 0.8 : 0
            root.addChildNode(node)
        }
        return root
    }

    private static func crossbow() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.38, green: 0.24, blue: 0.12, alpha: 1))
        let steel = mat(NSColor(red: 0.55, green: 0.57, blue: 0.6, alpha: 1))
        let string = mat(NSColor(white: 0.85, alpha: 1))
        let stock = SCNBox(width: 0.1, height: 0.08, length: 0.85, chamferRadius: 0.02)
        stock.materials = [wood]
        let stockNode = SCNNode(geometry: stock)
        stockNode.position = SCNVector3(0, 0.12, -0.05)
        root.addChildNode(stockNode)
        let prod = SCNBox(width: 0.62, height: 0.04, length: 0.05, chamferRadius: 0.01)
        prod.materials = [steel]
        let prodNode = SCNNode(geometry: prod)
        prodNode.position = SCNVector3(0, 0.2, 0.32)
        root.addChildNode(prodNode)
        let cord = SCNCylinder(radius: 0.008, height: 0.55)
        cord.materials = [string]
        let cordNode = SCNNode(geometry: cord)
        cordNode.eulerAngles.z = .pi / 2
        cordNode.position = SCNVector3(0, 0.2, 0.18)
        root.addChildNode(cordNode)
        let bolt = arrow()
        bolt.scale = SCNVector3(0.45, 0.45, 0.45)
        bolt.position = SCNVector3(0.05, 0.22, 0.05)
        root.addChildNode(bolt)
        return root
    }

    private static func mace() -> SCNNode {
        let root = SCNNode()
        let wood = mat(NSColor(red: 0.4, green: 0.26, blue: 0.14, alpha: 1))
        let steel = mat(NSColor(red: 0.5, green: 0.52, blue: 0.54, alpha: 1))
        let handle = SCNCylinder(radius: 0.04, height: 0.7)
        handle.materials = [wood]
        let handleNode = SCNNode(geometry: handle)
        handleNode.position.y = 0.35
        root.addChildNode(handleNode)
        let head = SCNSphere(radius: 0.16)
        head.segmentCount = 16
        head.materials = [steel]
        let headNode = SCNNode(geometry: head)
        headNode.position.y = 0.78
        root.addChildNode(headNode)
        let spikeDirs: [(CGFloat, CGFloat, CGFloat)] = [
            (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, 0, 1), (0, 0, -1),
            (0.7, 0.7, 0), (-0.7, 0.7, 0)
        ]
        for dir in spikeDirs {
            let spike = SCNCone(topRadius: 0, bottomRadius: 0.035, height: 0.14)
            spike.materials = [steel]
            let node = SCNNode(geometry: spike)
            let len = sqrt(dir.0 * dir.0 + dir.1 * dir.1 + dir.2 * dir.2)
            node.position = SCNVector3(0.16 * dir.0 / len, 0.78 + 0.16 * dir.1 / len, 0.16 * dir.2 / len)
            root.addChildNode(node)
            node.look(at: SCNVector3(node.position.x + dir.0, node.position.y + dir.1, node.position.z + dir.2))
            node.eulerAngles.x += .pi / 2
        }
        return root
    }

    private static func leather() -> SCNNode {
        let root = SCNNode()
        let hide = mat(NSColor(red: 0.42, green: 0.26, blue: 0.14, alpha: 1))
        let dark = mat(NSColor(red: 0.28, green: 0.16, blue: 0.09, alpha: 1))
        let tunic = SCNBox(width: 0.55, height: 0.7, length: 0.22, chamferRadius: 0.06)
        tunic.materials = [hide]
        let tunicNode = SCNNode(geometry: tunic)
        tunicNode.position.y = 0.55
        root.addChildNode(tunicNode)
        let skirt = SCNBox(width: 0.58, height: 0.28, length: 0.24, chamferRadius: 0.04)
        skirt.materials = [hide]
        let skirtNode = SCNNode(geometry: skirt)
        skirtNode.position.y = 0.18
        root.addChildNode(skirtNode)
        for x in [CGFloat(-0.34), CGFloat(0.34)] {
            let sleeve = SCNCapsule(capRadius: 0.08, height: 0.42)
            sleeve.materials = [hide]
            let node = SCNNode(geometry: sleeve)
            node.eulerAngles.z = x < 0 ? 0.5 : -0.5
            node.position = SCNVector3(x, 0.72, 0)
            root.addChildNode(node)
        }
        let belt = SCNBox(width: 0.6, height: 0.07, length: 0.26, chamferRadius: 0.02)
        belt.materials = [dark]
        let beltNode = SCNNode(geometry: belt)
        beltNode.position.y = 0.38
        root.addChildNode(beltNode)
        let buckle = SCNBox(width: 0.1, height: 0.08, length: 0.04, chamferRadius: 0.01)
        buckle.materials = [mat(NSColor(red: 0.7, green: 0.58, blue: 0.24, alpha: 1))]
        let buckleNode = SCNNode(geometry: buckle)
        buckleNode.position = SCNVector3(0, 0.38, 0.14)
        root.addChildNode(buckleNode)
        return root
    }

    private static func mat(_ color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = NSNumber(value: 0.45)
        return material
    }

    private static func fitHeight(_ node: SCNNode, to height: CGFloat) {
        let (minB, maxB) = bounds(node)
        let current = max(CGFloat(maxB.y - minB.y), 0.001)
        let scale = height / current
        node.scale = SCNVector3(scale, scale, scale)
        node.position.y -= minB.y * scale
    }

    private static func bounds(_ node: SCNNode) -> (SCNVector3, SCNVector3) {
        var minB = SCNVector3(10_000, 10_000, 10_000)
        var maxB = SCNVector3(-10_000, -10_000, -10_000)
        var found = false
        node.enumerateHierarchy { child, _ in
            guard let geo = child.geometry else { return }
            let (cmin, cmax) = geo.boundingBox
            for x in [cmin.x, cmax.x] {
                for y in [cmin.y, cmax.y] {
                    for z in [cmin.z, cmax.z] {
                        let world = child.convertPosition(SCNVector3(x, y, z), to: node)
                        minB.x = min(minB.x, world.x)
                        minB.y = min(minB.y, world.y)
                        minB.z = min(minB.z, world.z)
                        maxB.x = max(maxB.x, world.x)
                        maxB.y = max(maxB.y, world.y)
                        maxB.z = max(maxB.z, world.z)
                        found = true
                    }
                }
            }
        }
        return found ? (minB, maxB) : (SCNVector3Zero, SCNVector3(0.2, 0.2, 0.2))
    }
}
