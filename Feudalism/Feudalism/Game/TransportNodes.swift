//
//  TransportNodes.swift
//  Feudalism
//
//  Ruta prijevoza: linija, kutovi, sive polutočke, i volovi s kolima.
//

import SceneKit
import AppKit

func syncTransport(
    on root: SCNNode,
    lines: [String: TransportLine],
    oxen: [OxRenderSnapshot],
    editingId: String?,
    rows: Int,
    cols: Int
) {
    let liveLines = Set(lines.keys)
    for child in root.childNodes {
        guard let name = child.name else { continue }
        if name.hasPrefix("tline-"), !liveLines.contains(String(name.dropFirst(6))) {
            child.removeFromParentNode()
        }
        if name.hasPrefix("ox-") {
            let id = String(name.dropFirst(3))
            if !oxen.contains(where: { $0.id == id }) { child.removeFromParentNode() }
        }
    }
    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    func world(_ p: TransportPoint) -> SCNVector3 {
        SCNVector3(CGFloat(p.col) * cell - halfW + cell / 2, 0.18, CGFloat(p.row) * cell - halfH + cell / 2)
    }

    for (id, line) in lines where line.corners.count >= 2 {
        let name = "tline-\(id)"
        let node = root.childNode(withName: name, recursively: false) ?? {
            let n = SCNNode()
            n.name = name
            n.categoryBitMask = 1
            root.addChildNode(n)
            return n
        }()
        let editing = id == editingId
        let sig = line.corners.map { "\(Int($0.row * 10))_\(Int($0.col * 10))" }.joined(separator: ".") + (editing ? ".e" : "")
        if node.childNode(withName: "look:\(sig)", recursively: false) != nil {
            // ruta se nije promijenila
        } else {
        node.childNodes.forEach { $0.removeFromParentNode() }
        let mark = SCNNode()
        mark.name = "look:\(sig)"
        node.addChildNode(mark)
        for i in 0..<(line.corners.count - 1) {
            node.addChildNode(makeSegment(from: world(line.corners[i]), to: world(line.corners[i + 1]), strong: editing))
            if editing, let mid = line.midpoint(after: i) {
                node.addChildNode(makeHandle(at: world(mid), name: "tmid_\(i)", active: false))
            }
        }
        if editing {
            for (i, corner) in line.corners.enumerated() {
                node.addChildNode(makeHandle(at: world(corner), name: "tcorner_\(i)", active: i > 0))
            }
        }
        }
    }

    for snap in oxen {
        let name = "ox-\(snap.id)"
        var node = root.childNode(withName: name, recursively: false)
        if node == nil {
            node = makeOxCart(colorHex: snap.colorHex)
            node?.name = name
            root.addChildNode(node!)
        }
        guard let cart = node else { continue }
        let x = CGFloat(snap.col) * cell - halfW + cell / 2
        let z = CGFloat(snap.row) * cell - halfH + cell / 2
        let bob = snap.moving ? CGFloat(abs(sin(snap.walkPhase * 2))) * 0.03 : 0
        cart.position = SCNVector3(x, bob, z)
        cart.eulerAngles = SCNVector3(0, snap.facing, 0)
    }
}

private func makeSegment(from a: SCNVector3, to b: SCNVector3, strong: Bool) -> SCNNode {
    let dx = b.x - a.x, dz = b.z - a.z
    let length = hypot(dx, dz)
    let box = SCNBox(width: 0.18, height: 0.06, length: length, chamferRadius: 0)
    let mat = SCNMaterial()
    mat.diffuse.contents = strong
        ? NSColor(red: 0.92, green: 0.74, blue: 0.28, alpha: 0.95)
        : NSColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 0.7)
    mat.lightingModel = .constant
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.position = SCNVector3((a.x + b.x) / 2, 0.18, (a.z + b.z) / 2)
    node.eulerAngles.y = atan2(dx, dz)
    node.categoryBitMask = 1
    return node
}

private func makeHandle(at position: SCNVector3, name: String, active: Bool) -> SCNNode {
    let sphere = SCNSphere(radius: active ? 0.38 : 0.26)
    let mat = SCNMaterial()
    mat.diffuse.contents = active
        ? NSColor(red: 0.95, green: 0.82, blue: 0.28, alpha: 1)
        : NSColor(white: 0.55, alpha: 0.85)
    mat.lightingModel = .constant
    sphere.materials = [mat]
    let node = SCNNode(geometry: sphere)
    node.name = name
    node.position = SCNVector3(position.x, 0.45, position.z)
    node.categoryBitMask = 1
    node.renderingOrder = 400
    return node
}

private func makeOxCart(colorHex: String) -> SCNNode {
    let root = SCNNode()
    root.categoryBitMask = 1
    let wood = NSColor(red: 0.45, green: 0.3, blue: 0.16, alpha: 1)
    let hide = NSColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
    let faction = personColorForTransport(hex: colorHex)
    addTransportPart(to: root, SCNBox(width: 0.7, height: 0.35, length: 0.9, chamferRadius: 0.04), wood, at: SCNVector3(0, 0.55, -0.15))
    addTransportPart(to: root, SCNBox(width: 0.08, height: 0.28, length: 0.7, chamferRadius: 0), faction, at: SCNVector3(0.32, 0.72, -0.15))
    addTransportPart(to: root, SCNCylinder(radius: 0.18, height: 0.08), wood, at: SCNVector3(-0.38, 0.22, 0.15)).eulerAngles.z = .pi / 2
    addTransportPart(to: root, SCNCylinder(radius: 0.18, height: 0.08), wood, at: SCNVector3(0.38, 0.22, 0.15)).eulerAngles.z = .pi / 2
    addTransportPart(to: root, SCNCylinder(radius: 0.18, height: 0.08), wood, at: SCNVector3(-0.38, 0.22, -0.4)).eulerAngles.z = .pi / 2
    addTransportPart(to: root, SCNCylinder(radius: 0.18, height: 0.08), wood, at: SCNVector3(0.38, 0.22, -0.4)).eulerAngles.z = .pi / 2
    addTransportPart(to: root, SCNBox(width: 0.22, height: 0.28, length: 0.5, chamferRadius: 0.08), hide, at: SCNVector3(-0.16, 0.55, 0.55))
    addTransportPart(to: root, SCNBox(width: 0.22, height: 0.28, length: 0.5, chamferRadius: 0.08), hide, at: SCNVector3(0.16, 0.55, 0.55))
    addTransportPart(to: root, SCNBox(width: 0.1, height: 0.12, length: 0.16, chamferRadius: 0.03), hide, at: SCNVector3(-0.16, 0.72, 0.78))
    addTransportPart(to: root, SCNBox(width: 0.1, height: 0.12, length: 0.16, chamferRadius: 0.03), hide, at: SCNVector3(0.16, 0.72, 0.78))
    return root
}

@discardableResult
private func addTransportPart(to root: SCNNode, _ geometry: SCNGeometry, _ color: NSColor, at position: SCNVector3) -> SCNNode {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .blinn
    geometry.materials = [mat]
    let node = SCNNode(geometry: geometry)
    node.position = position
    node.categoryBitMask = 1
    root.addChildNode(node)
    return node
}

private func personColorForTransport(hex: String) -> NSColor {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let num = UInt64(s, radix: 16) else { return .brown }
    return NSColor(red: CGFloat((num >> 16) & 0xFF) / 255, green: CGFloat((num >> 8) & 0xFF) / 255, blue: CGFloat(num & 0xFF) / 255, alpha: 1)
}
