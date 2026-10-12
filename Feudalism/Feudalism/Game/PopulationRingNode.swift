//
//  PopulationRingNode.swift
//  Feudalism
//
//  Neprekinuti prsten iznad vatre. Podloga je cijeli torus; punjenje su preklopljeni
//  segmenti (prazni se skrivaju da ne izgledaju kao točkice). Polumjer dolazi iz
//  broja mjesta oko vatre.
//

import SceneKit
import AppKit
import QuartzCore

enum PopulationRingStyle {
    static let segments = 72
    static let pipeRadius: CGFloat = 0.055
    static let height: CGFloat = 2.15
    static let fallbackRadius: CGFloat = 1.55

    static let track: SCNMaterial = material(NSColor(white: 0.92, alpha: 1), transparency: 0.28)
    static let green: SCNMaterial = material(NSColor(red: 0.22, green: 0.86, blue: 0.34, alpha: 1), transparency: 1)
    static let red: SCNMaterial = material(NSColor(red: 0.92, green: 0.2, blue: 0.16, alpha: 1), transparency: 1)

    private static func material(_ color: NSColor, transparency: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color.withAlphaComponent(0.55)
        mat.lightingModel = .constant
        mat.transparency = transparency
        mat.isDoubleSided = true
        return mat
    }
}

func placePopulationRing(in node: SCNNode, at hearth: SCNVector3, ring: PopulationRingSnapshot?) {
    let radius = CGFloat(ring?.radius ?? PopulationRingStyle.fallbackRadius)
    let root: SCNNode
    if let existing = node.childNode(withName: "populationRing", recursively: false) {
        let old = (existing.childNode(withName: "track", recursively: false)?.geometry as? SCNTorus)?.ringRadius ?? 0
        if abs(old - radius) > 0.04 {
            existing.removeFromParentNode()
            root = makePopulationRing(radius: radius)
            node.addChildNode(root)
        } else {
            root = existing
        }
    } else {
        root = makePopulationRing(radius: radius)
        node.addChildNode(root)
    }
    root.position = SCNVector3(hearth.x, PopulationRingStyle.height, hearth.z)

    let trend = ring?.trend ?? .steady
    let shown = ring?.shown(at: CACurrentMediaTime()) ?? 0
    let total = PopulationRingStyle.segments
    let filled = trend == .steady ? total : Int((shown * Double(total)).rounded())
    for child in root.childNodes {
        guard let name = child.name, name.hasPrefix("fill-"), let index = Int(name.dropFirst(5)) else { continue }
        let on: Bool
        switch trend {
        case .steady:
            on = true
        case .growing:
            on = index < filled
        case .shrinking:
            on = (total - 1 - index) < filled
        }
        child.isHidden = !on
        if on, let segment = child.childNodes.first {
            let wanted = trend == .shrinking ? PopulationRingStyle.red : PopulationRingStyle.green
            if segment.geometry?.firstMaterial !== wanted {
                segment.geometry?.materials = [wanted]
            }
        }
    }
}

/// Segment 0 je na strani −z (gore na ekranu); indeksi rastu u smjeru kazaljke gledano odozgo.
private func makePopulationRing(radius: CGFloat) -> SCNNode {
    let root = SCNNode()
    root.name = "populationRing"
    root.categoryBitMask = 1

    let track = SCNTorus(ringRadius: radius, pipeRadius: PopulationRingStyle.pipeRadius)
    track.ringSegmentCount = 64
    track.pipeSegmentCount = 10
    track.materials = [PopulationRingStyle.track]
    let trackNode = SCNNode(geometry: track)
    trackNode.name = "track"
    trackNode.categoryBitMask = 1
    root.addChildNode(trackNode)

    let total = PopulationRingStyle.segments
    let length = 2 * .pi * radius / CGFloat(total) * 1.2
    for i in 0..<total {
        let angle = -CGFloat.pi / 2 + CGFloat(i) / CGFloat(total) * 2 * .pi
        let pivot = SCNNode()
        pivot.name = "fill-\(i)"
        pivot.eulerAngles.y = -angle
        pivot.categoryBitMask = 1
        let tube = SCNCylinder(radius: PopulationRingStyle.pipeRadius * 1.05, height: length)
        tube.radialSegmentCount = 8
        tube.materials = [PopulationRingStyle.green]
        let segment = SCNNode(geometry: tube)
        segment.position = SCNVector3(radius, 0, 0)
        segment.eulerAngles.x = .pi / 2
        segment.categoryBitMask = 1
        pivot.addChildNode(segment)
        root.addChildNode(pivot)
    }
    return root
}
