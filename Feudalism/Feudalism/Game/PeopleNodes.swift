//
//  PeopleNodes.swift
//  Feudalism
//
//  Likovi osoba: seljak (lan i slamnati šešir), radnik (tunika frakcije i kožna pregača),
//  vojnik (tunika frakcije, kaciga i oružje). Radnik unutra u građevini se ne vidi.
//

import SceneKit
import AppKit

func syncPeople(on root: SCNNode, snapshots: [PersonRenderSnapshot], rows: Int, cols: Int, viewUnderground: Bool = false, gameMap: GameMap) {
    let live = Set(snapshots.map(\.id))
    for child in root.childNodes {
        guard let name = child.name, name.hasPrefix("person-") else { continue }
        if !live.contains(String(name.dropFirst(7))) { child.removeFromParentNode() }
    }
    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    for snap in snapshots {
        let look = "\(snap.role.rawValue)-\(snap.soldierType?.rawValue ?? "")"
        let name = "person-\(snap.id)"
        var node = root.childNode(withName: name, recursively: false)
        if let existing = node, existing.childNode(withName: "look:\(look)", recursively: false) == nil {
            existing.removeFromParentNode()
            node = nil
        }
        let person: SCNNode
        if let node {
            person = node
        } else {
            person = makePersonNode(snapshot: snap)
            person.name = name
            let marker = SCNNode()
            marker.name = "look:\(look)"
            person.addChildNode(marker)
            root.addChildNode(person)
        }
        let onView = (snap.layer == .underground) == viewUnderground
        person.isHidden = !snap.visible || !onView
        guard snap.visible, onView else { continue }
        let x = CGFloat(snap.col) * cell - halfW + cell / 2
        let z = CGFloat(snap.row) * cell - halfH + cell / 2
        let bob = snap.moving ? CGFloat(abs(sin(snap.walkPhase * 2))) * 0.035 : 0
        let ground = gameMap.vertexHeightAt(vertexRow: Int(snap.row.rounded()), vertexCol: Int(snap.col.rounded()))
        let yBase: CGFloat = snap.layer == .underground ? -Underground.depthMeters : ground
        person.position = SCNVector3(x, yBase + bob, z)
        person.eulerAngles = SCNVector3(0, snap.facing, 0)
        let swing = CGFloat(sin(snap.walkPhase))
        let leg = snap.moving ? swing * 0.6 : 0
        let arm = snap.moving ? -swing * 0.45 : 0
        person.childNode(withName: "legL", recursively: false)?.eulerAngles.x = leg
        person.childNode(withName: "legR", recursively: false)?.eulerAngles.x = -leg
        person.childNode(withName: "armL", recursively: false)?.eulerAngles.x = arm
        person.childNode(withName: "armR", recursively: false)?.eulerAngles.x = snap.role == .soldier ? -0.5 : -arm
        for i in 0..<4 {
            person.childNode(withName: "horseLeg\(i)", recursively: false)?.eulerAngles.x = (i == 0 || i == 3) ? leg * 0.8 : -leg * 0.8
        }
        syncSelectionRing(on: person, marked: snap.marked)
    }
}

/// Zelena aureola ispod označene osobe (vojnik / rudar / inženjer).
private func syncSelectionRing(on person: SCNNode, marked: Bool) {
    let existing = person.childNode(withName: "selectionRing", recursively: false)
    if !marked {
        existing?.removeFromParentNode()
        return
    }
    if existing != nil { return }
    let ring = SCNTorus(ringRadius: 0.42, pipeRadius: 0.045)
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(red: 0.25, green: 0.9, blue: 0.4, alpha: 1)
    mat.emission.contents = NSColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1)
    mat.lightingModel = .constant
    ring.materials = [mat]
    let node = SCNNode(geometry: ring)
    node.name = "selectionRing"
    node.position = SCNVector3(0, 0.06, 0)
    node.categoryBitMask = 1
    person.addChildNode(node)
}

func makeSoldierPreviewNode(type: SoldierType, colorHex: String = "#8B1E1E") -> SCNNode {
    let snap = PersonRenderSnapshot(
        id: type.rawValue,
        colorHex: colorHex,
        role: .soldier,
        soldierType: type,
        row: 0,
        col: 0,
        facing: 0,
        moving: false,
        walkPhase: 0,
        visible: true,
        layer: .surface
    )
    return makePersonNode(snapshot: snap)
}

private func makePersonNode(snapshot: PersonRenderSnapshot) -> SCNNode {
    let figure = makeFigure(snapshot: snapshot)
    guard snapshot.role == .soldier, snapshot.soldierType?.isMounted == true else { return figure }
    let root = SCNNode()
    root.categoryBitMask = 1
    addHorse(to: root)
    figure.position = SCNVector3(0, 0.3, -0.05)
    figure.childNode(withName: "legL", recursively: false)?.eulerAngles = SCNVector3(-0.9, 0, -0.35)
    figure.childNode(withName: "legR", recursively: false)?.eulerAngles = SCNVector3(-0.9, 0, 0.35)
    figure.childNode(withName: "armR", recursively: false)?.eulerAngles.x = -0.5
    root.addChildNode(figure)
    return root
}

/// Konj gleda u +z kao i lik; noge su zglobovi "horseLeg0…3" za hod.
private func addHorse(to root: SCNNode) {
    let coat = NSColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1)
    let mane = NSColor(red: 0.18, green: 0.11, blue: 0.06, alpha: 1)
    let saddle = NSColor(red: 0.3, green: 0.17, blue: 0.08, alpha: 1)
    addPart(to: root, SCNBox(width: 0.36, height: 0.4, length: 1.05, chamferRadius: 0.15), coat, at: SCNVector3(0, 0.95, 0))
    addPart(to: root, SCNBox(width: 0.4, height: 0.06, length: 0.4, chamferRadius: 0.02), saddle, at: SCNVector3(0, 1.17, -0.05))
    let neck = addPart(to: root, SCNBox(width: 0.2, height: 0.5, length: 0.24, chamferRadius: 0.08), coat, at: SCNVector3(0, 1.25, 0.5))
    neck.eulerAngles.x = 0.5
    addPart(to: root, SCNBox(width: 0.18, height: 0.18, length: 0.4, chamferRadius: 0.06), coat, at: SCNVector3(0, 1.48, 0.72))
    addPart(to: root, SCNBox(width: 0.04, height: 0.36, length: 0.2, chamferRadius: 0.02), mane, at: SCNVector3(0, 1.4, 0.44)).eulerAngles.x = 0.5
    let tail = addPart(to: root, SCNCylinder(radius: 0.05, height: 0.5), mane, at: SCNVector3(0, 0.85, -0.6))
    tail.eulerAngles.x = -0.4
    let legs: [(CGFloat, CGFloat)] = [(-0.12, 0.38), (0.12, 0.38), (-0.12, -0.38), (0.12, -0.38)]
    for (i, spot) in legs.enumerated() {
        root.addChildNode(personLimb(name: "horseLeg\(i)", length: 0.72, radius: 0.055, color: coat, at: SCNVector3(spot.0, 0.8, spot.1)))
    }
}

private func makeFigure(snapshot: PersonRenderSnapshot) -> SCNNode {
    let root = SCNNode()
    root.categoryBitMask = 1
    let faction = personColor(hex: snapshot.colorHex)
    let skin = NSColor(red: 0.9, green: 0.73, blue: 0.58, alpha: 1)
    let linen = NSColor(red: 0.72, green: 0.65, blue: 0.5, alpha: 1)
    let leather = NSColor(red: 0.36, green: 0.23, blue: 0.13, alpha: 1)
    let iron = NSColor(white: 0.62, alpha: 1)
    let boot = NSColor(red: 0.22, green: 0.15, blue: 0.1, alpha: 1)

    let tunic: NSColor
    switch snapshot.role {
    case .peasant: tunic = linen
    case .worker: tunic = faction.blended(withFraction: 0.35, of: linen) ?? faction
    case .soldier: tunic = faction
    case .specialist: tunic = NSColor(red: 0.42, green: 0.38, blue: 0.32, alpha: 1)
    }

    addPart(to: root, SCNBox(width: 0.34, height: 0.42, length: 0.18, chamferRadius: 0.04), tunic, at: SCNVector3(0, 1.08, 0))
    root.addChildNode(personLimb(name: "legL", length: 0.72, radius: 0.065, color: boot, at: SCNVector3(-0.09, 0.86, 0)))
    root.addChildNode(personLimb(name: "legR", length: 0.72, radius: 0.065, color: boot, at: SCNVector3(0.09, 0.86, 0)))
    root.addChildNode(personLimb(name: "armL", length: 0.48, radius: 0.05, color: tunic, at: SCNVector3(-0.23, 1.24, 0)))
    root.addChildNode(personLimb(name: "armR", length: 0.48, radius: 0.05, color: tunic, at: SCNVector3(0.23, 1.24, 0)))
    addPart(to: root, SCNSphere(radius: 0.13), skin, at: SCNVector3(0, 1.45, 0))

    switch snapshot.role {
    case .peasant:
        let brim = SCNCylinder(radius: 0.22, height: 0.02)
        addPart(to: root, brim, NSColor(red: 0.85, green: 0.72, blue: 0.4, alpha: 1), at: SCNVector3(0, 1.55, 0))
        addPart(to: root, SCNCone(topRadius: 0.04, bottomRadius: 0.12, height: 0.12), NSColor(red: 0.8, green: 0.67, blue: 0.36, alpha: 1), at: SCNVector3(0, 1.62, 0))
    case .worker:
        addPart(to: root, SCNBox(width: 0.3, height: 0.36, length: 0.02, chamferRadius: 0.01), leather, at: SCNVector3(0, 1.0, 0.1))
        addPart(to: root, SCNSphere(radius: 0.135), NSColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 1), at: SCNVector3(0, 1.5, -0.02), scale: SCNVector3(1, 0.5, 0.9))
    case .specialist:
        addPart(to: root, SCNBox(width: 0.28, height: 0.08, length: 0.22, chamferRadius: 0.01), leather, at: SCNVector3(0, 0.92, 0))
        addPart(to: root, SCNBox(width: 0.06, height: 0.28, length: 0.06, chamferRadius: 0), iron, at: SCNVector3(0.28, 1.15, 0))
        addPart(to: root, SCNSphere(radius: 0.13), NSColor(red: 0.28, green: 0.22, blue: 0.16, alpha: 1), at: SCNVector3(0, 1.52, 0), scale: SCNVector3(1, 0.55, 0.9))
    case .soldier:
        addPart(to: root, SCNSphere(radius: 0.145), iron, at: SCNVector3(0, 1.5, 0), scale: SCNVector3(1, 0.75, 1))
        addPart(to: root, SCNBox(width: 0.02, height: 0.1, length: 0.03, chamferRadius: 0), iron, at: SCNVector3(0, 1.43, 0.135))
        addPart(to: root, SCNBox(width: 0.36, height: 0.06, length: 0.2, chamferRadius: 0.01), leather, at: SCNVector3(0, 0.9, 0))
        let type = snapshot.soldierType ?? .swordsman
        if type.hasArmor {
            addPart(to: root, SCNBox(width: 0.38, height: 0.3, length: 0.22, chamferRadius: 0.04), iron.blended(withFraction: 0.4, of: leather) ?? iron,
                    at: SCNVector3(0, 1.16, 0))
        }
        addWeapon(type.mainWeapon, to: root, iron: iron, wood: leather, faction: faction)
        if type.hasShield {
            let shield = SCNCylinder(radius: 0.22, height: 0.03)
            let node = addPart(to: root, shield, faction, at: SCNVector3(-0.3, 1.05, 0.06))
            node.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
            addPart(to: root, SCNSphere(radius: 0.04), iron, at: SCNVector3(-0.3, 1.05, 0.08))
        }
    }
    return root
}

private func addWeapon(_ weapon: Good, to root: SCNNode, iron: NSColor, wood: NSColor, faction: NSColor) {
    switch weapon {
    case .spear:
        addPart(to: root, SCNCylinder(radius: 0.02, height: 1.9), wood, at: SCNVector3(0.3, 1.05, 0.12))
        addPart(to: root, SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.16), iron, at: SCNVector3(0.3, 2.07, 0.12))
    case .bow:
        let bow = SCNTorus(ringRadius: 0.36, pipeRadius: 0.015)
        let node = addPart(to: root, bow, wood, at: SCNVector3(0.3, 1.1, 0.05))
        node.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
        node.scale = SCNVector3(1, 1, 0.35)
        addPart(to: root, SCNCylinder(radius: 0.05, height: 0.4), wood, at: SCNVector3(0.05, 1.2, -0.13))
    default:
        addPart(to: root, SCNBox(width: 0.04, height: 0.6, length: 0.015, chamferRadius: 0), iron, at: SCNVector3(0.3, 0.85, 0.15))
        addPart(to: root, SCNBox(width: 0.16, height: 0.03, length: 0.03, chamferRadius: 0), wood, at: SCNVector3(0.3, 1.15, 0.15))
    }
}

@discardableResult
private func addPart(to root: SCNNode, _ geometry: SCNGeometry, _ color: NSColor, at position: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .blinn
    geometry.materials = [mat]
    let node = SCNNode(geometry: geometry)
    node.position = position
    node.scale = scale
    node.categoryBitMask = 1
    root.addChildNode(node)
    return node
}

private func personLimb(name: String, length: CGFloat, radius: CGFloat, color: NSColor, at pivot: SCNVector3) -> SCNNode {
    let joint = SCNNode()
    joint.name = name
    joint.position = pivot
    joint.categoryBitMask = 1
    let cap = SCNCapsule(capRadius: radius, height: length)
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .blinn
    cap.materials = [mat]
    let node = SCNNode(geometry: cap)
    node.position = SCNVector3(0, -length / 2, 0)
    node.categoryBitMask = 1
    joint.addChildNode(node)
    return joint
}

private func personColor(hex: String) -> NSColor {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let num = UInt64(s, radix: 16) else { return .brown }
    return NSColor(red: CGFloat((num >> 16) & 0xFF) / 255, green: CGFloat((num >> 8) & 0xFF) / 255, blue: CGFloat(num & 0xFF) / 255, alpha: 1)
}
