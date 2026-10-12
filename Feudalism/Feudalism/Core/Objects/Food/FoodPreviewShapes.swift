//
//  FoodPreviewShapes.swift
//  Feudalism
//
//  Oblici hrane u Aboutu. Košara jabuka i košara jaja su posebno.
//

import Foundation
import SceneKit
import AppKit

enum FoodPreviewShapes {
    static func node(_ kind: AboutGoodKind) -> SCNNode {
        let root: SCNNode
        switch kind {
        case .cheese: root = cheese()
        case .meat: root = meat()
        case .bread: root = bread()
        case .chicken: root = chicken()
        case .corn: root = corn()
        case .grapes: root = grapes()
        case .banana: root = banana()
        case .vegetables: root = vegetables()
        case .spices: root = spices()
        case .wine: root = wine()
        case .sausages: root = sausages()
        default: root = SCNNode()
        }
        fitHeight(root, to: 1.05)
        return root
    }

    private static func cheese() -> SCNNode {
        let root = SCNNode()
        let wheel = SCNCylinder(radius: 0.62, height: 0.28)
        wheel.radialSegmentCount = 40
        wheel.materials = [mat(NSColor(red: 0.93, green: 0.76, blue: 0.28, alpha: 1))]
        let wheelNode = SCNNode(geometry: wheel)
        wheelNode.position.y = 0.14
        root.addChildNode(wheelNode)
        let rind = SCNTorus(ringRadius: 0.62, pipeRadius: 0.045)
        rind.ringSegmentCount = 40
        rind.pipeSegmentCount = 10
        rind.materials = [mat(NSColor(red: 0.78, green: 0.58, blue: 0.16, alpha: 1))]
        let rindNode = SCNNode(geometry: rind)
        rindNode.position.y = 0.14
        root.addChildNode(rindNode)
        let holes: [(CGFloat, CGFloat)] = [(-0.18, 0.08), (0.16, -0.1), (0.02, 0.2), (-0.08, -0.18), (0.22, 0.14)]
        for hole in holes {
            let disk = SCNCylinder(radius: 0.07, height: 0.02)
            disk.materials = [mat(NSColor(red: 0.62, green: 0.46, blue: 0.12, alpha: 1))]
            let node = SCNNode(geometry: disk)
            node.position = SCNVector3(hole.0, 0.29, hole.1)
            root.addChildNode(node)
        }
        return root
    }

    private static func meat() -> SCNNode {
        let root = SCNNode()
        let roast = SCNSphere(radius: 0.42)
        roast.segmentCount = 24
        roast.materials = [mat(NSColor(red: 0.55, green: 0.16, blue: 0.12, alpha: 1))]
        let body = SCNNode(geometry: roast)
        body.scale = SCNVector3(1.35, 0.72, 0.85)
        body.position = SCNVector3(-0.05, 0.32, 0)
        root.addChildNode(body)
        let bone = SCNCylinder(radius: 0.045, height: 0.55)
        bone.materials = [mat(NSColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1))]
        let boneNode = SCNNode(geometry: bone)
        boneNode.eulerAngles.z = .pi / 2
        boneNode.position = SCNVector3(0.55, 0.34, 0)
        root.addChildNode(boneNode)
        for end in [CGFloat(0.22), CGFloat(-0.22)] {
            let knob = SCNSphere(radius: 0.09)
            knob.materials = [mat(NSColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1))]
            let node = SCNNode(geometry: knob)
            node.position = SCNVector3(0.55, 0.34, end)
            root.addChildNode(node)
        }
        return root
    }

    private static func bread() -> SCNNode {
        let root = SCNNode()
        let loaf = SCNSphere(radius: 0.42)
        loaf.segmentCount = 28
        loaf.materials = [mat(NSColor(red: 0.76, green: 0.48, blue: 0.22, alpha: 1))]
        let body = SCNNode(geometry: loaf)
        body.scale = SCNVector3(1.45, 0.72, 0.95)
        body.position.y = 0.28
        root.addChildNode(body)
        let crust = SCNBox(width: 0.04, height: 0.02, length: 0.7, chamferRadius: 0.01)
        crust.materials = [mat(NSColor(red: 0.45, green: 0.24, blue: 0.12, alpha: 1))]
        for x in [CGFloat(-0.18), CGFloat(0), CGFloat(0.18)] {
            let cut = SCNNode(geometry: crust)
            cut.position = SCNVector3(x, 0.56, 0)
            cut.eulerAngles.y = .pi / 2
            root.addChildNode(cut)
        }
        return root
    }

    private static func chicken() -> SCNNode {
        let root = SCNNode()
        let white = mat(NSColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1))
        let red = mat(NSColor(red: 0.78, green: 0.16, blue: 0.12, alpha: 1))
        let dark = mat(NSColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1))
        let beakColor = mat(NSColor(red: 0.92, green: 0.62, blue: 0.16, alpha: 1))

        let bodyGeo = SCNSphere(radius: 0.38)
        bodyGeo.segmentCount = 20
        bodyGeo.materials = [white]
        let body = SCNNode(geometry: bodyGeo)
        body.scale = SCNVector3(1.15, 0.9, 0.8)
        body.position = SCNVector3(-0.05, 0.48, 0)
        root.addChildNode(body)

        let headGeo = SCNSphere(radius: 0.18)
        headGeo.segmentCount = 16
        headGeo.materials = [white]
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0.38, 0.78, 0)
        root.addChildNode(head)

        let beak = SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.14)
        beak.radialSegmentCount = 8
        beak.materials = [beakColor]
        let beakNode = SCNNode(geometry: beak)
        beakNode.eulerAngles.z = -.pi / 2
        beakNode.position = SCNVector3(0.58, 0.76, 0)
        root.addChildNode(beakNode)

        let comb = SCNSphere(radius: 0.06)
        comb.materials = [red]
        for i in 0..<3 {
            let node = SCNNode(geometry: comb)
            node.position = SCNVector3(0.32 + CGFloat(i) * 0.05, 0.96, 0)
            node.scale = SCNVector3(0.7, 1.3, 0.45)
            root.addChildNode(node)
        }
        let wattle = SCNSphere(radius: 0.045)
        wattle.materials = [red]
        let wattleNode = SCNNode(geometry: wattle)
        wattleNode.scale = SCNVector3(0.6, 1.4, 0.5)
        wattleNode.position = SCNVector3(0.48, 0.64, 0)
        root.addChildNode(wattleNode)

        let eye = SCNSphere(radius: 0.025)
        eye.materials = [dark]
        for z in [CGFloat(0.1), CGFloat(-0.1)] {
            let node = SCNNode(geometry: eye)
            node.position = SCNVector3(0.5, 0.82, z)
            root.addChildNode(node)
        }

        let tail = SCNCone(topRadius: 0.02, bottomRadius: 0.1, height: 0.34)
        tail.materials = [white]
        for i in 0..<3 {
            let node = SCNNode(geometry: tail)
            node.eulerAngles.z = 0.7 + CGFloat(i) * 0.18
            node.position = SCNVector3(-0.42, 0.62, CGFloat(i - 1) * 0.06)
            root.addChildNode(node)
        }

        let leg = SCNCylinder(radius: 0.025, height: 0.28)
        leg.materials = [beakColor]
        for x in [CGFloat(0.08), CGFloat(-0.16)] {
            let node = SCNNode(geometry: leg)
            node.position = SCNVector3(x, 0.14, 0)
            root.addChildNode(node)
        }
        return root
    }

    private static func corn() -> SCNNode {
        let root = SCNNode()
        let cob = SCNCylinder(radius: 0.16, height: 0.85)
        cob.radialSegmentCount = 16
        cob.materials = [mat(NSColor(red: 0.92, green: 0.78, blue: 0.18, alpha: 1))]
        let cobNode = SCNNode(geometry: cob)
        cobNode.position.y = 0.48
        root.addChildNode(cobNode)
        let leaf = SCNBox(width: 0.08, height: 0.7, length: 0.28, chamferRadius: 0.02)
        leaf.materials = [mat(NSColor(red: 0.28, green: 0.48, blue: 0.16, alpha: 1))]
        for i in 0..<4 {
            let node = SCNNode(geometry: leaf)
            let angle = CGFloat(i) * .pi / 2
            node.position = SCNVector3(sin(angle) * 0.16, 0.42, cos(angle) * 0.16)
            node.eulerAngles.z = sin(angle) * 0.45
            node.eulerAngles.x = cos(angle) * 0.45
            root.addChildNode(node)
        }
        let silk = SCNCylinder(radius: 0.03, height: 0.22)
        silk.materials = [mat(NSColor(red: 0.86, green: 0.72, blue: 0.28, alpha: 1))]
        let silkNode = SCNNode(geometry: silk)
        silkNode.position.y = 0.98
        root.addChildNode(silkNode)
        return root
    }

    private static func grapes() -> SCNNode {
        let root = SCNNode()
        let purple = mat(NSColor(red: 0.36, green: 0.12, blue: 0.38, alpha: 1))
        let deep = mat(NSColor(red: 0.24, green: 0.08, blue: 0.28, alpha: 1))
        var index = 0
        for row in 0..<4 {
            let count = 4 - row
            let y = 0.16 + CGFloat(row) * 0.16
            for i in 0..<count {
                let geo = SCNSphere(radius: 0.11)
                geo.segmentCount = 12
                geo.materials = [index.isMultiple(of: 2) ? purple : deep]
                let node = SCNNode(geometry: geo)
                let span = CGFloat(count - 1) * 0.16
                node.position = SCNVector3(-span / 2 + CGFloat(i) * 0.16, y, CGFloat(row % 2) * 0.06)
                root.addChildNode(node)
                index += 1
            }
        }
        let stem = SCNCylinder(radius: 0.015, height: 0.28)
        stem.materials = [mat(NSColor(red: 0.36, green: 0.28, blue: 0.14, alpha: 1))]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.86, 0)
        root.addChildNode(stemNode)
        return root
    }

    private static func banana() -> SCNNode {
        let root = SCNNode()
        let yellow = mat(NSColor(red: 0.95, green: 0.82, blue: 0.22, alpha: 1))
        let tip = mat(NSColor(red: 0.45, green: 0.32, blue: 0.12, alpha: 1))
        for bunch in 0..<3 {
            let z = CGFloat(bunch - 1) * 0.12
            for i in 0..<6 {
                let t = CGFloat(i) / 5
                let angle = -0.9 + t * 1.7
                let cap = SCNCapsule(capRadius: 0.055, height: 0.16)
                cap.materials = [i == 5 ? tip : yellow]
                let node = SCNNode(geometry: cap)
                node.eulerAngles.z = angle
                node.position = SCNVector3(sin(angle) * 0.42, 0.22 + (1 - cos(angle)) * 0.28, z)
                root.addChildNode(node)
            }
        }
        return root
    }

    private static func vegetables() -> SCNNode {
        let root = SCNNode()
        let carrot = SCNCone(topRadius: 0.02, bottomRadius: 0.12, height: 0.55)
        carrot.radialSegmentCount = 12
        carrot.materials = [mat(NSColor(red: 0.9, green: 0.42, blue: 0.1, alpha: 1))]
        let carrotNode = SCNNode(geometry: carrot)
        carrotNode.position = SCNVector3(-0.28, 0.28, 0.05)
        root.addChildNode(carrotNode)
        let leaves = SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.28)
        leaves.materials = [mat(NSColor(red: 0.22, green: 0.5, blue: 0.16, alpha: 1))]
        let leafNode = SCNNode(geometry: leaves)
        leafNode.position = SCNVector3(-0.28, 0.66, 0.05)
        root.addChildNode(leafNode)

        let tomato = SCNSphere(radius: 0.2)
        tomato.segmentCount = 16
        tomato.materials = [mat(NSColor(red: 0.78, green: 0.14, blue: 0.12, alpha: 1))]
        let tomatoNode = SCNNode(geometry: tomato)
        tomatoNode.position = SCNVector3(0.22, 0.2, -0.05)
        root.addChildNode(tomatoNode)

        let cabbage = SCNSphere(radius: 0.26)
        cabbage.segmentCount = 16
        cabbage.materials = [mat(NSColor(red: 0.32, green: 0.55, blue: 0.24, alpha: 1))]
        let cabbageNode = SCNNode(geometry: cabbage)
        cabbageNode.scale = SCNVector3(1.1, 0.75, 1.1)
        cabbageNode.position = SCNVector3(0.02, 0.2, 0.22)
        root.addChildNode(cabbageNode)
        return root
    }

    private static func spices() -> SCNNode {
        let root = SCNNode()
        let board = SCNBox(width: 0.9, height: 0.06, length: 0.55, chamferRadius: 0.02)
        board.materials = [mat(NSColor(red: 0.45, green: 0.3, blue: 0.16, alpha: 1))]
        let boardNode = SCNNode(geometry: board)
        boardNode.position.y = 0.03
        root.addChildNode(boardNode)
        let colors = [
            NSColor(red: 0.72, green: 0.18, blue: 0.12, alpha: 1),
            NSColor(red: 0.62, green: 0.4, blue: 0.14, alpha: 1),
            NSColor(red: 0.86, green: 0.72, blue: 0.22, alpha: 1)
        ]
        for (index, color) in colors.enumerated() {
            let jar = SCNCylinder(radius: 0.1, height: 0.32)
            jar.materials = [mat(NSColor(white: 0.9, alpha: 0.55))]
            let jarNode = SCNNode(geometry: jar)
            let x = CGFloat(index - 1) * 0.26
            jarNode.position = SCNVector3(x, 0.22, 0)
            root.addChildNode(jarNode)
            let powder = SCNCylinder(radius: 0.08, height: 0.16)
            powder.materials = [mat(color)]
            let powderNode = SCNNode(geometry: powder)
            powderNode.position = SCNVector3(x, 0.18, 0)
            root.addChildNode(powderNode)
        }
        return root
    }

    private static func wine() -> SCNNode {
        let root = SCNNode()
        let glass = mat(NSColor(red: 0.12, green: 0.28, blue: 0.18, alpha: 0.72))
        glass.transparency = 0.35
        glass.isDoubleSided = true
        let wineColor = mat(NSColor(red: 0.45, green: 0.06, blue: 0.1, alpha: 1))
        let body = SCNCylinder(radius: 0.18, height: 0.5)
        body.materials = [glass]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 0.28
        root.addChildNode(bodyNode)
        let fill = SCNCylinder(radius: 0.15, height: 0.36)
        fill.materials = [wineColor]
        let fillNode = SCNNode(geometry: fill)
        fillNode.position.y = 0.24
        root.addChildNode(fillNode)
        let shoulder = SCNCone(topRadius: 0.06, bottomRadius: 0.18, height: 0.16)
        shoulder.materials = [glass]
        let shoulderNode = SCNNode(geometry: shoulder)
        shoulderNode.position.y = 0.6
        root.addChildNode(shoulderNode)
        let neck = SCNCylinder(radius: 0.05, height: 0.32)
        neck.materials = [glass]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position.y = 0.82
        root.addChildNode(neckNode)
        return root
    }

    private static func sausages() -> SCNNode {
        let root = SCNNode()
        let skin = mat(NSColor(red: 0.62, green: 0.24, blue: 0.16, alpha: 1))
        let tie = mat(NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1))
        for row in 0..<2 {
            for i in 0..<3 {
                let piece = SCNCapsule(capRadius: 0.08, height: 0.34)
                piece.materials = [skin]
                let node = SCNNode(geometry: piece)
                node.eulerAngles.z = .pi / 2
                node.eulerAngles.y = CGFloat(row) * 0.4
                node.position = SCNVector3(CGFloat(i - 1) * 0.28, 0.1 + CGFloat(row) * 0.16, CGFloat(row) * 0.12)
                root.addChildNode(node)
                if i < 2 {
                    let knot = SCNSphere(radius: 0.035)
                    knot.materials = [tie]
                    let knotNode = SCNNode(geometry: knot)
                    knotNode.position = SCNVector3(CGFloat(i) * 0.28 - 0.14, 0.1 + CGFloat(row) * 0.16, CGFloat(row) * 0.12)
                    root.addChildNode(knotNode)
                }
            }
        }
        return root
    }

    private static func mat(_ color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = NSNumber(value: 0.55)
        if color.alphaComponent < 0.99 {
            material.transparency = color.alphaComponent
            material.transparencyMode = .dualLayer
        }
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
