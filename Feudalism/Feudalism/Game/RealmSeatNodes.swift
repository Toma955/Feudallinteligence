//
//  RealmSeatNodes.swift
//  Feudalism
//
//  Kocka = dvorac. Lik koji hoda = kralj.
//

import SceneKit
import AppKit

func syncRealmSeats(on root: SCNNode, snapshots: [KingRenderSnapshot], rings: [String: PopulationRingSnapshot], rows: Int, cols: Int) {
    let live = Set(snapshots.map(\.factionId))
    for child in root.childNodes where child.name?.hasPrefix("seat-") == true {
        let id = String(child.name?.dropFirst(5) ?? "")
        if !live.contains(id) { child.removeFromParentNode() }
    }
    for snap in snapshots {
        let node = seatNode(on: root, snapshot: snap)
        placeCastle(in: node, snapshot: snap, rows: rows, cols: cols)
        let hearth = placeHearth(in: node, snapshot: snap, rows: rows, cols: cols)
        placePopulationRing(in: node, at: hearth, ring: rings[snap.factionId])
        placeKing(in: node, snapshot: snap, rows: rows, cols: cols)
    }
}

private func seatNode(on root: SCNNode, snapshot: KingRenderSnapshot) -> SCNNode {
    let name = "seat-\(snapshot.factionId)"
    if let existing = root.childNode(withName: name, recursively: false) {
        return existing
    }
    let node = SCNNode()
    node.name = name
        node.categoryBitMask = 1
    root.addChildNode(node)
    return node
}

private func placeCastle(in node: SCNNode, snapshot: KingRenderSnapshot, rows: Int, cols: Int) {
    let castle: SCNNode
    if let existing = node.childNode(withName: "castle", recursively: false) {
        castle = existing
    } else {
        let d = ObjectDimensions.castle
        let box = SCNBox(width: MapScale.meters(d.cellWidth), height: MapScale.meters(d.heightCells), length: MapScale.meters(d.cellHeight), chamferRadius: 0.15)
        let mat = SCNMaterial()
        mat.diffuse.contents = nsColor(hex: snapshot.colorHex)
        mat.emission.contents = nsColor(hex: snapshot.colorHex).withAlphaComponent(0.25)
        mat.lightingModel = .blinn
        box.materials = [mat]
        castle = SCNNode(geometry: box)
        castle.name = "castle"
        castle.categoryBitMask = 1
        node.addChildNode(castle)
    }
    let pos = seatWorldPosition(row: CGFloat(snapshot.castleRow), col: CGFloat(snapshot.castleCol), rows: rows, cols: cols)
    castle.position = SCNVector3(pos.x, MapScale.meters(ObjectDimensions.castle.heightCells) / 2, pos.z)
}

/// Vatra na tlu ispred dvorca, prema početnom pogledu kamere. Ostaje kao mjesto okupljanja.
private func placeHearth(in node: SCNNode, snapshot: KingRenderSnapshot, rows: Int, cols: Int) -> SCNVector3 {
    let hearth: SCNNode
    if let existing = node.childNode(withName: "hearth", recursively: false) {
        hearth = existing
    } else {
        hearth = GatheringHearth.makeNode()
        node.addChildNode(hearth)
    }
    let pos = seatWorldPosition(row: CGFloat(snapshot.castleRow), col: CGFloat(snapshot.castleCol), rows: rows, cols: cols)
    let front = GatheringHearth.frontOffset(footprintMeters: MapScale.meters(ObjectDimensions.castle.cellHeight))
    hearth.position = SCNVector3(pos.x, 0, pos.z - front)
    return hearth.position
}

private func placeKing(in node: SCNNode, snapshot: KingRenderSnapshot, rows: Int, cols: Int) {
    let king: SCNNode
    if let existing = node.childNode(withName: "king", recursively: false) {
        king = existing
    } else {
        king = makeKingNode(colorHex: snapshot.colorHex)
        king.name = "king"
        node.addChildNode(king)
    }
    let pos = seatWorldPosition(row: CGFloat(snapshot.kingRow), col: CGFloat(snapshot.kingCol), rows: rows, cols: cols)
    if snapshot.alive {
        let bob = snapshot.moving ? CGFloat(abs(sin(snapshot.walkPhase * 2))) * 0.04 : CGFloat(sin(snapshot.walkPhase)) * 0.012
        king.position = SCNVector3(pos.x, bob, pos.z)
        king.eulerAngles = SCNVector3(0, snapshot.facing, 0)
        king.opacity = 1
        poseKing(king, moving: snapshot.moving, phase: snapshot.walkPhase)
    } else {
        king.position = SCNVector3(pos.x, 0.15, pos.z)
        king.eulerAngles = SCNVector3(Float.pi / 2, Float(snapshot.facing), 0)
        king.opacity = 0.45
        poseKing(king, moving: false, phase: 0)
    }
    placeHealthBar(in: node, at: pos, percent: snapshot.healthPercent)
}

private func poseKing(_ king: SCNNode, moving: Bool, phase: Double) {
    let swing = CGFloat(sin(phase))
    let leg = moving ? swing * 0.65 : swing * 0.06
    let arm = moving ? -swing * 0.5 : swing * 0.08
    king.childNode(withName: "legL", recursively: false)?.eulerAngles.x = leg
    king.childNode(withName: "legR", recursively: false)?.eulerAngles.x = -leg
    king.childNode(withName: "armL", recursively: false)?.eulerAngles.x = arm
    king.childNode(withName: "armR", recursively: false)?.eulerAngles.x = -arm
}

private func placeHealthBar(in node: SCNNode, at pos: SCNVector3, percent: Double) {
    let bar: SCNNode
    if let existing = node.childNode(withName: "kingHealth", recursively: false) {
        bar = existing
    } else {
        bar = SCNNode()
        bar.name = "kingHealth"
        bar.categoryBitMask = 1
        let track = SCNBox(width: 1.0, height: 0.12, length: 0.08, chamferRadius: 0)
        let trackMat = SCNMaterial()
        trackMat.diffuse.contents = NSColor(white: 0.15, alpha: 1)
        trackMat.lightingModel = .constant
        track.materials = [trackMat]
        let trackNode = SCNNode(geometry: track)
        trackNode.name = "track"
        trackNode.categoryBitMask = 1
        let fill = SCNBox(width: 1.0, height: 0.12, length: 0.1, chamferRadius: 0)
        let fillMat = SCNMaterial()
        fillMat.diffuse.contents = NSColor(red: 0.2, green: 0.75, blue: 0.3, alpha: 1)
        fillMat.lightingModel = .constant
        fill.materials = [fillMat]
        let fillNode = SCNNode(geometry: fill)
        fillNode.name = "fill"
        fillNode.categoryBitMask = 1
        bar.addChildNode(trackNode)
        bar.addChildNode(fillNode)
        node.addChildNode(bar)
    }
    let clamped = min(100, max(0, percent)) / 100
    bar.position = SCNVector3(pos.x, 2.15, pos.z)
    if let fill = bar.childNode(withName: "fill", recursively: false) {
        fill.scale = SCNVector3(clamped, 1, 1)
        fill.position = SCNVector3(-0.5 * (1 - clamped), 0, 0)
    }
}

private func makeKingNode(colorHex: String) -> SCNNode {
    let root = SCNNode()
    root.categoryBitMask = 1
    let tunic = nsColor(hex: colorHex)
    let skin = NSColor(red: 0.93, green: 0.76, blue: 0.62, alpha: 1)
    let hair = NSColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1)
    let gold = NSColor(red: 0.86, green: 0.68, blue: 0.22, alpha: 1)
    let boot = NSColor(red: 0.22, green: 0.14, blue: 0.1, alpha: 1)

    let torso = SCNBox(width: 0.38, height: 0.46, length: 0.2, chamferRadius: 0.04)
    torso.materials = [litMaterial(tunic)]
    let torsoNode = SCNNode(geometry: torso)
    torsoNode.position = SCNVector3(0, 1.16, 0)
    torsoNode.categoryBitMask = 1
    root.addChildNode(torsoNode)

    let belt = SCNBox(width: 0.4, height: 0.06, length: 0.22, chamferRadius: 0.01)
    belt.materials = [litMaterial(gold)]
    let beltNode = SCNNode(geometry: belt)
    beltNode.position = SCNVector3(0, 0.94, 0)
    beltNode.categoryBitMask = 1
    root.addChildNode(beltNode)

    root.addChildNode(limb(name: "legL", length: 0.78, radius: 0.07, color: boot, at: SCNVector3(-0.1, 0.92, 0)))
    root.addChildNode(limb(name: "legR", length: 0.78, radius: 0.07, color: boot, at: SCNVector3(0.1, 0.92, 0)))
    root.addChildNode(limb(name: "armL", length: 0.52, radius: 0.055, color: tunic, at: SCNVector3(-0.26, 1.32, 0)))
    root.addChildNode(limb(name: "armR", length: 0.52, radius: 0.055, color: tunic, at: SCNVector3(0.26, 1.32, 0)))

    let head = SCNSphere(radius: 0.14)
    head.materials = [litMaterial(skin)]
    let headNode = SCNNode(geometry: head)
    headNode.position = SCNVector3(0, 1.56, 0)
    headNode.categoryBitMask = 1
    root.addChildNode(headNode)

    let hairCap = SCNSphere(radius: 0.145)
    hairCap.materials = [litMaterial(hair)]
    let hairNode = SCNNode(geometry: hairCap)
    hairNode.position = SCNVector3(0, 1.62, -0.02)
    hairNode.scale = SCNVector3(1, 0.55, 0.9)
    hairNode.categoryBitMask = 1
    root.addChildNode(hairNode)

    let beard = SCNBox(width: 0.12, height: 0.1, length: 0.08, chamferRadius: 0.03)
    beard.materials = [litMaterial(hair)]
    let beardNode = SCNNode(geometry: beard)
    beardNode.position = SCNVector3(0, 1.44, 0.08)
    beardNode.categoryBitMask = 1
    root.addChildNode(beardNode)

    for side in [-1.0, 1.0] as [CGFloat] {
        let eye = SCNSphere(radius: 0.018)
        eye.materials = [litMaterial(NSColor(white: 0.08, alpha: 1))]
        let eyeNode = SCNNode(geometry: eye)
        eyeNode.position = SCNVector3(side * 0.045, 1.58, 0.12)
        eyeNode.categoryBitMask = 1
        root.addChildNode(eyeNode)
    }

    let crown = SCNTorus(ringRadius: 0.11, pipeRadius: 0.02)
    crown.materials = [litMaterial(gold)]
    let crownNode = SCNNode(geometry: crown)
    crownNode.position = SCNVector3(0, 1.7, 0)
    crownNode.eulerAngles.x = .pi / 2
    crownNode.categoryBitMask = 1
    root.addChildNode(crownNode)
    for i in 0..<4 {
        let point = SCNCone(topRadius: 0, bottomRadius: 0.025, height: 0.07)
        point.materials = [litMaterial(gold)]
        let pointNode = SCNNode(geometry: point)
        let angle = Float(i) * .pi / 2
        pointNode.position = SCNVector3(cos(angle) * 0.1, 1.76, sin(angle) * 0.1)
        pointNode.categoryBitMask = 1
        root.addChildNode(pointNode)
    }
    return root
}

private func limb(name: String, length: CGFloat, radius: CGFloat, color: NSColor, at pivot: SCNVector3) -> SCNNode {
    let joint = SCNNode()
    joint.name = name
    joint.position = pivot
    joint.categoryBitMask = 1
    let cap = SCNCapsule(capRadius: radius, height: length)
    cap.materials = [litMaterial(color)]
    let node = SCNNode(geometry: cap)
    node.position = SCNVector3(0, -length / 2, 0)
    node.categoryBitMask = 1
    joint.addChildNode(node)
    return joint
}

private func litMaterial(_ color: NSColor) -> SCNMaterial {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .blinn
    return mat
}

private func seatWorldPosition(row: CGFloat, col: CGFloat, rows: Int, cols: Int) -> SCNVector3 {
    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    let x = col * cell - halfW + cell / 2
    let z = row * cell - halfH + cell / 2
    return SCNVector3(x, 0, z)
}

private func nsColor(hex: String) -> NSColor {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let num = UInt64(s, radix: 16) else { return .brown }
    let r = CGFloat((num >> 16) & 0xFF) / 255
    let g = CGFloat((num >> 8) & 0xFF) / 255
    let b = CGFloat(num & 0xFF) / 255
    return NSColor(red: r, green: g, blue: b, alpha: 1)
}
