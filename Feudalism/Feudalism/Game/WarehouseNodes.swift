//
//  WarehouseNodes.swift
//  Feudalism
//
//  Tlocrt skladišta na mapi i ruta radnika do mjesta robe.
//

import SceneKit
import AppKit

func syncWarehouse(
    on root: SCNNode,
    layouts: [String: WarehouseLayout],
    stores: [Placement],
    editing: WarehouseRouteEdit?,
    inspectedId: String?,
    rows: Int,
    cols: Int
) {
    let live = Set(stores.map(\.id))
    for child in root.childNodes {
        guard let name = child.name, name.hasPrefix("wh-") else { continue }
        let id = String(name.dropFirst(3))
        if !live.contains(id) { child.removeFromParentNode() }
    }
    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    func world(_ row: Double, _ col: Double, y: CGFloat) -> SCNVector3 {
        SCNVector3(CGFloat(col) * cell - halfW + cell / 2, y, CGFloat(row) * cell - halfH + cell / 2)
    }

    for store in stores {
        let name = "wh-\(store.id)"
        let node = root.childNode(withName: name, recursively: false) ?? {
            let n = SCNNode()
            n.name = name
            n.categoryBitMask = 1
            root.addChildNode(n)
            return n
        }()
        let layout = layouts[store.id]
        let showSlots = inspectedId == store.id
        let routes = editing?.storeId == store.id ? (layout?.routes ?? []) : []
        let sig = "\(showSlots ? "s" : "")-\(layout?.slots.map { "\($0.localRow)\($0.localCol)\($0.good.rawValue)" }.joined() ?? "")-\(editing?.workplaceId ?? "")-\(editing?.good.rawValue ?? "")-\(routes.map { $0.corners.map { "\(Int($0.row * 10))" }.joined() }.joined())"
        if node.childNode(withName: "look:\(sig)", recursively: false) != nil { continue }
        node.childNodes.forEach { $0.removeFromParentNode() }
        let mark = SCNNode()
        mark.name = "look:\(sig)"
        node.addChildNode(mark)
        if showSlots {
            for slot in layout?.slots ?? [] {
                let plane = SCNPlane(width: cell * 0.85, height: cell * 0.85)
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 0.55)
                mat.lightingModel = .constant
                plane.materials = [mat]
                let tile = SCNNode(geometry: plane)
                tile.eulerAngles.x = -.pi / 2
                tile.position = world(Double(store.row + slot.localRow), Double(store.col + slot.localCol), y: 0.25)
                tile.categoryBitMask = 1
                node.addChildNode(tile)
            }
        }
        if let editing {
            if let route = layout?.route(workplaceId: editing.workplaceId, good: editing.good), route.corners.count >= 2 {
                for i in 0..<(route.corners.count - 1) {
                    node.addChildNode(warehouseSegment(from: world(route.corners[i].row, route.corners[i].col, y: 0.2), to: world(route.corners[i + 1].row, route.corners[i + 1].col, y: 0.2)))
                    let mid = TransportPoint(row: (route.corners[i].row + route.corners[i + 1].row) / 2, col: (route.corners[i].col + route.corners[i + 1].col) / 2)
                    node.addChildNode(warehouseHandle(at: world(mid.row, mid.col, y: 0.45), name: "tmid_\(i)", active: false))
                }
                for (i, corner) in route.corners.enumerated() {
                    node.addChildNode(warehouseHandle(at: world(corner.row, corner.col, y: 0.45), name: "tcorner_\(i)", active: i > 0))
                }
            }
        }
    }
}

private func warehouseSegment(from a: SCNVector3, to b: SCNVector3) -> SCNNode {
    let dx = b.x - a.x, dz = b.z - a.z
    let length = hypot(dx, dz)
    let box = SCNBox(width: 0.16, height: 0.05, length: length, chamferRadius: 0)
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(red: 0.35, green: 0.72, blue: 0.95, alpha: 0.95)
    mat.lightingModel = .constant
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.position = SCNVector3((a.x + b.x) / 2, 0.2, (a.z + b.z) / 2)
    node.eulerAngles.y = atan2(dx, dz)
    node.categoryBitMask = 1
    return node
}

private func warehouseHandle(at position: SCNVector3, name: String, active: Bool) -> SCNNode {
    let sphere = SCNSphere(radius: active ? 0.36 : 0.24)
    let mat = SCNMaterial()
    mat.diffuse.contents = active ? NSColor.systemTeal : NSColor(white: 0.6, alpha: 0.85)
    mat.lightingModel = .constant
    sphere.materials = [mat]
    let node = SCNNode(geometry: sphere)
    node.name = name
    node.position = position
    node.categoryBitMask = 1
    node.renderingOrder = 400
    return node
}
