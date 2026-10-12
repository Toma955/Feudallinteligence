//
//  RoofLogic.swift
//  Feudalism
//
//  Oblik krova: slobodna građevina = dvovod (greben u sredini, pad lijevo/desno).
//  Kut slova L uz zidove = pad s dvije strane. Rušenje zida vraća standard.
//

import Foundation
import SceneKit
import AppKit

enum RoofKind: Equatable {
    /// Greben sjever–jug, pad istočno i zapadno (klasična kuća).
    case gableX
    /// Greben istok–zapad, pad sjeverno i južno.
    case gableZ
    case cornerNE
    case cornerNW
    case cornerSE
    case cornerSW
}

enum RoofLogic {
    static let nodeName = "adaptive_roof"

    static func kind(for placement: Placement, wallCells: Set<MapCoordinate>) -> RoofKind {
        var n = false, s = false, e = false, w = false
        for r in placement.row..<(placement.row + placement.height) {
            for c in placement.col..<(placement.col + placement.width) {
                if wallCells.contains(MapCoordinate(row: r - 1, col: c)) { n = true }
                if wallCells.contains(MapCoordinate(row: r + 1, col: c)) { s = true }
                if wallCells.contains(MapCoordinate(row: r, col: c + 1)) { e = true }
                if wallCells.contains(MapCoordinate(row: r, col: c - 1)) { w = true }
            }
        }
        if n && e && !s && !w { return .cornerNE }
        if n && w && !s && !e { return .cornerNW }
        if s && e && !n && !w { return .cornerSE }
        if s && w && !n && !e { return .cornerSW }
        if (n || s) && !(e || w) { return .gableZ }
        return .gableX
    }

    static func apply(to node: SCNNode, kind: RoofKind) {
        guard let old = node.childNode(withName: nodeName, recursively: true) else { return }
        let width = RoofShapes.number(old.value(forKey: "roofW"), fallback: 2)
        let length = RoofShapes.number(old.value(forKey: "roofL"), fallback: 2)
        let height = RoofShapes.number(old.value(forKey: "roofH"), fallback: 1.2)
        let thatch = (old.value(forKey: "roofThatch") as? NSNumber)?.boolValue ?? false
        let color = thatch ? BuildingKit.thatch : BuildingKit.roofTile
        let next = RoofShapes.make(kind: kind, width: width, length: length, height: height, color: color, thatch: thatch)
        next.position = old.position
        next.eulerAngles = old.eulerAngles
        old.parent?.addChildNode(next)
        old.removeFromParentNode()
    }
}

enum RoofShapes {
    static func make(kind: RoofKind, width: CGFloat, length: CGFloat, height: CGFloat, color: NSColor, thatch: Bool) -> SCNNode {
        let node: SCNNode
        switch kind {
        case .gableX: node = gable(width: width, length: length, height: height, color: color, alongZ: true)
        case .gableZ: node = gable(width: length, length: width, height: height, color: color, alongZ: true)
            node.eulerAngles.y = CGFloat.pi / 2
        case .cornerNE: node = corner(width: width, length: length, height: height, color: color, highN: true, highE: true)
        case .cornerNW: node = corner(width: width, length: length, height: height, color: color, highN: true, highE: false)
        case .cornerSE: node = corner(width: width, length: length, height: height, color: color, highN: false, highE: true)
        case .cornerSW: node = corner(width: width, length: length, height: height, color: color, highN: false, highE: false)
        }
        node.name = RoofLogic.nodeName
        node.setValue(NSNumber(value: Double(width)), forKey: "roofW")
        node.setValue(NSNumber(value: Double(length)), forKey: "roofL")
        node.setValue(NSNumber(value: Double(height)), forKey: "roofH")
        node.setValue(NSNumber(value: thatch), forKey: "roofThatch")
        return node
    }

    static func number(_ value: Any?, fallback: CGFloat) -> CGFloat {
        (value as? NSNumber).map { CGFloat(truncating: $0) } ?? fallback
    }

    /// Dva krova od srednjeg grebena: pad lijevo i desno.
    private static func gable(width: CGFloat, length: CGFloat, height: CGFloat, color: NSColor, alongZ: Bool) -> SCNNode {
        _ = alongZ
        let root = SCNNode()
        let half = width / 2
        let slope = hypot(half, height)
        let angle = atan2(height, half)
        let thick: CGFloat = 0.10
        func panel(sign: CGFloat) {
            let box = SCNBox(width: slope, height: thick, length: length * 1.06, chamferRadius: 0)
            box.materials = [BuildingKit.material(color)]
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(sign * half * 0.5, height * 0.5, 0)
            n.eulerAngles.z = -sign * angle
            root.addChildNode(n)
        }
        panel(sign: -1)
        panel(sign: 1)
        BuildingKit.box(to: root, 0.08, 0.08, length * 1.04, BuildingKit.timberDark, at: SCNVector3(0, height, 0))
        return root
    }

    /// L-krov: visoki rubovi uz zidove, pad na dvije otvorene strane.
    private static func corner(width: CGFloat, length: CGFloat, height: CGFloat, color: NSColor, highN: Bool, highE: Bool) -> SCNNode {
        let root = SCNNode()
        let thick: CGFloat = 0.10
        let halfW = width / 2
        let halfL = length / 2
        let slopeW = hypot(halfW, height)
        let slopeL = hypot(halfL, height)
        let angW = atan2(height, halfW)
        let angL = atan2(height, halfL)

        let ns = SCNBox(width: width * 1.04, height: thick, length: slopeL, chamferRadius: 0)
        ns.materials = [BuildingKit.material(color)]
        let nsNode = SCNNode(geometry: ns)
        let nSign: CGFloat = highN ? -1 : 1
        nsNode.position = SCNVector3(0, height * 0.5, nSign * halfL * 0.5)
        nsNode.eulerAngles.x = nSign * angL
        root.addChildNode(nsNode)

        let ew = SCNBox(width: slopeW, height: thick, length: length * 1.04, chamferRadius: 0)
        ew.materials = [BuildingKit.material(color)]
        let ewNode = SCNNode(geometry: ew)
        let eSign: CGFloat = highE ? 1 : -1
        ewNode.position = SCNVector3(eSign * halfW * 0.5, height * 0.5, 0)
        ewNode.eulerAngles.z = -eSign * angW
        root.addChildNode(ewNode)

        BuildingKit.box(
            to: root,
            0.10,
            0.10,
            0.10,
            BuildingKit.timberDark,
            at: SCNVector3(eSign * halfW * 0.15, height, nSign * halfL * 0.15)
        )
        return root
    }
}
