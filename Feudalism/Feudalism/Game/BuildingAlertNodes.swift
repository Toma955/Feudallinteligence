//
//  BuildingAlertNodes.swift
//  Feudalism
//
//  Pločica iznad radnog mjesta: „Nema radnika”, „Nema puta” ili „Spava”. Uvijek okrenuta kameri.
//

import SceneKit
import AppKit

/// Visina vrha modela po objectId; čita se samo s render niti.
private final class BuildingTopCache {
    static let shared = BuildingTopCache()
    private var tops: [String: CGFloat] = [:]

    func top(of objectId: String) -> CGFloat {
        if let top = tops[objectId] { return top }
        let node = SceneKitPlacementRegistry.loadSceneKitNode(objectId: objectId)
        let top = node.map { CGFloat($0.boundingBox.max.y - min(0, $0.boundingBox.min.y)) } ?? 4
        tops[objectId] = top
        return top
    }
}

func syncBuildingAlerts(on root: SCNNode, snapshots: [BuildingAlertSnapshot], rows: Int, cols: Int) {
    let live = Set(snapshots.map(\.placementId))
    for child in root.childNodes {
        guard let name = child.name, name.hasPrefix("alert-") else { continue }
        if !live.contains(String(name.dropFirst(6))) { child.removeFromParentNode() }
    }
    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    for snap in snapshots {
        let name = "alert-\(snap.placementId)"
        var node = root.childNode(withName: name, recursively: false)
        if let existing = node, existing.childNode(withName: "look:\(snap.alert.rawValue)", recursively: false) == nil {
            existing.removeFromParentNode()
            node = nil
        }
        let x = (CGFloat(snap.col) + CGFloat(snap.width) / 2) * cell - halfW
        let z = (CGFloat(snap.row) + CGFloat(snap.height) / 2) * cell - halfH
        let y = BuildingTopCache.shared.top(of: snap.objectId) + 1.6
            + (snap.layer == .underground ? -Underground.depthMeters : 0)
        if let node {
            node.position = SCNVector3(x, y, z)
            continue
        }
        let badge = makeAlertBadge(snap.alert)
        badge.name = name
        badge.position = SCNVector3(x, y, z)
        root.addChildNode(badge)
    }
}

private func makeAlertBadge(_ alert: BuildingAlert) -> SCNNode {
    func flat(_ color: NSColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.readsFromDepthBuffer = false
        return m
    }
    let color: NSColor
    switch alert {
    case .noWorker, .noResources, .noRoomWarehouse, .noRoomPantry, .noRoomArmory, .noRoomOther:
        color = NSColor(red: 0.85, green: 0.5, blue: 0.1, alpha: 0.92)
    case .noMoney: color = NSColor(red: 0.72, green: 0.58, blue: 0.12, alpha: 0.94)
    case .noPath, .onFire: color = NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 0.92)
    case .sleeping: color = NSColor(red: 0.25, green: 0.33, blue: 0.55, alpha: 0.92)
    case .castleClosed: color = NSColor(red: 0.2, green: 0.45, blue: 0.3, alpha: 0.95)
    case .noCandle: color = NSColor(red: 0.92, green: 0.72, blue: 0.22, alpha: 0.94)
    case .noTree: color = NSColor(red: 0.36, green: 0.52, blue: 0.22, alpha: 0.94)
    }

    let root = SCNNode()
    root.categoryBitMask = 1
    root.constraints = [SCNBillboardConstraint()]
    root.renderingOrder = 390

    let text = SCNText(string: alert.text, extrusionDepth: 0)
    text.font = NSFont.systemFont(ofSize: 1, weight: .bold)
    text.flatness = 0.08
    text.materials = [flat(.white)]
    let label = SCNNode(geometry: text)
    let (minB, maxB) = label.boundingBox
    let textW = CGFloat(maxB.x - minB.x)
    let textH = CGFloat(maxB.y - minB.y)
    label.pivot = SCNMatrix4MakeTranslation((maxB.x + minB.x) / 2, (maxB.y + minB.y) / 2, 0)
    label.position = SCNVector3(0, 0, 0.02)
    label.renderingOrder = 392
    label.categoryBitMask = 1

    let plate = SCNPlane(width: textW + 0.7, height: textH + 0.4)
    plate.cornerRadius = 0.25
    plate.materials = [flat(color)]
    let plateNode = SCNNode(geometry: plate)
    plateNode.renderingOrder = 391
    plateNode.categoryBitMask = 1

    root.addChildNode(plateNode)
    root.addChildNode(label)
    let marker = SCNNode()
    marker.name = "look:\(alert.rawValue)"
    root.addChildNode(marker)
    return root
}
