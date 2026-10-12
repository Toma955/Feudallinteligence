//
//  PlaceholderBox.swift
//  Feudalism
//
//  Zajednička kocka (box) za privremene objekte – prostor i razmaci točno određeni
//  (MapScale.objectCubeWorldUnits po ćeliji). Svaka ima boju i natpis. Kasnije zamijeniti stvarnim modelima.
//

import Foundation
import SceneKit
import AppKit

/// Jedan izvor dimenzija za placeholder objekte: 1 ćelija = 1 metar.
enum PlaceholderBox {

    /// Jedna ćelija u world jedinicama (širina/dubina).
    static var worldUnitsPerCell: CGFloat { MapScale.objectCubeWorldUnits }

    /// Napravi jednostavnu kocku (SCNBox) koja okupira točno cellW × cellH ćelija i visinu heightWorld.
    static func makeBox(cellW: Int, cellH: Int, heightWorld: CGFloat, color: NSColor? = nil) -> SCNNode {
        let w = CGFloat(max(1, cellW)) * worldUnitsPerCell
        let l = CGFloat(max(1, cellH)) * worldUnitsPerCell
        let h = max(1, heightWorld)
        let box = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = color ?? NSColor(white: 0.6, alpha: 1)
        mat.ambient.contents = NSColor(white: 0.3, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 0.2
        box.materials = [mat]
        let node = SCNNode(geometry: box)
        node.name = "placeholder_box"
        node.position.y = h / 2
        return node
    }

    /// Visina u metrima.
    static func heightCells(_ n: Int) -> CGFloat {
        CGFloat(max(1, n)) * worldUnitsPerCell
    }

    /// Kocka prema centralnim dimenzijama (ObjectDimensions).
    static func makeBox(dimension: ObjectDimension, color: NSColor? = nil) -> SCNNode {
        makeBox(cellW: dimension.cellWidth, cellH: dimension.cellHeight, heightWorld: heightCells(dimension.heightCells), color: color)
    }

    /// Natpis (3D tekst) iznad kocke – svaki placeholder ga koristi.
    static func makeLabel(_ text: String, boxHeight: CGFloat) -> SCNNode {
        let textGeom = SCNText(string: text, extrusionDepth: 0.02)
        textGeom.font = NSFont.boldSystemFont(ofSize: 0.4)
        textGeom.flatness = 0.1
        textGeom.alignmentMode = "center"
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        mat.ambient.contents = NSColor(white: 0.8, alpha: 1)
        mat.isDoubleSided = true
        textGeom.materials = [mat]
        let labelNode = SCNNode(geometry: textGeom)
        labelNode.name = "placeholder_label"
        let (min, max) = (labelNode.boundingBox.min, labelNode.boundingBox.max)
        let dx = CGFloat((max.x - min.x) / 2 + min.x)
        let dy = CGFloat((max.y - min.y) / 2 + min.y)
        labelNode.pivot = SCNMatrix4MakeTranslation(-dx, -dy, 0)
        labelNode.position = SCNVector3(0, boxHeight + 0.3, 0)
        labelNode.scale = SCNVector3(1, 1, 1)
        labelNode.eulerAngles.x = -.pi / 2
        return labelNode
    }
}
