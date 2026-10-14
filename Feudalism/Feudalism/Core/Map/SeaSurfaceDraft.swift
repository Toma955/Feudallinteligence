//
//  SeaSurfaceDraft.swift
//  Feudalism
//
//  Uređivanje oblika mora: vanjski pravokutnik (obala) je fiksiran;
//  unutarnji oblik = polygon čiji su vrhovi na RUBOVIMA ćelija (grid linije),
//  tako da zeleni obrub i točke leže točno na rubu plavog kvadrata.
//

import Foundation
import CoreGraphics

/// Vrh unutarnjeg polygona mora.
/// Koordinate su na mrežnim linijama (rub ćelije), ne u središtu ćelije.
/// Npr. NW ugao ćelije (r,c) = (r, c); SE ugao = (r+1, c+1).
struct SeaPolygonVertex: Equatable, Codable {
    var row: CGFloat
    var col: CGFloat
}

/// Trajni oblik mora na mapi — prati editor linije, ne kocke ćelija.
struct SeaPolygonShape: Equatable, Codable {
    var vertices: [SeaPolygonVertex]

    init(vertices: [SeaPolygonVertex]) {
        self.vertices = vertices
    }

    init(from draft: SeaSurfaceDraft) {
        self.vertices = draft.vertices
    }
}

/// Privremeni nacrt površine mora dok traje uređivanje.
struct SeaSurfaceDraft: Equatable {
    /// Fiksni vanjski rub (obala / plaža) — ćelije.
    var outerMinRow: Int
    var outerMaxRow: Int
    var outerMinCol: Int
    var outerMaxCol: Int

    /// Vrhovi unutarnjeg polygona na grid linijama (zatvoren). Min. 3.
    var vertices: [SeaPolygonVertex]

    var outerWidth: Int { outerMaxCol - outerMinCol + 1 }
    var outerHeight: Int { outerMaxRow - outerMinRow + 1 }

    /// Unutarnji plavi blok od ćelija [iMinR…iMaxR] × [iMinC…iMaxC] — vrhovi na rubovima.
    static func rectangleVertices(iMinR: Int, iMaxR: Int, iMinC: Int, iMaxC: Int) -> [SeaPolygonVertex] {
        [
            SeaPolygonVertex(row: CGFloat(iMinR), col: CGFloat(iMinC)),           // NW
            SeaPolygonVertex(row: CGFloat(iMinR), col: CGFloat(iMaxC + 1)),       // NE
            SeaPolygonVertex(row: CGFloat(iMaxR + 1), col: CGFloat(iMaxC + 1)),   // SE
            SeaPolygonVertex(row: CGFloat(iMaxR + 1), col: CGFloat(iMinC))        // SW
        ]
    }

    static func fromOuterBounds(minRow: Int, maxRow: Int, minCol: Int, maxCol: Int) -> SeaSurfaceDraft {
        let w = maxCol - minCol + 1
        let h = maxRow - minRow + 1
        // Plavi kvadrat jako blizu žutog — obala ≈ 1 ćelija.
        let inset = (w >= 3 && h >= 3) ? 1 : 0
        let iMinR = minRow + inset
        let iMaxR = maxRow - inset
        let iMinC = minCol + inset
        let iMaxC = maxCol - inset
        let verts: [SeaPolygonVertex]
        if iMinR <= iMaxR, iMinC <= iMaxC {
            verts = rectangleVertices(iMinR: iMinR, iMaxR: iMaxR, iMinC: iMinC, iMaxC: iMaxC)
        } else {
            // Premalo — plavo ≈ cijeli vanjski.
            verts = rectangleVertices(iMinR: minRow, iMaxR: maxRow, iMinC: minCol, iMaxC: maxCol)
        }
        var draft = SeaSurfaceDraft(
            outerMinRow: minRow,
            outerMaxRow: maxRow,
            outerMinCol: minCol,
            outerMaxCol: maxCol,
            vertices: verts
        )
        draft.clampInnerInsideOuter()
        return draft
    }

    /// Ograniči vrhove unutar vanjskog ruba (grid linije outer…outer+1).
    mutating func clampInnerInsideOuter() {
        let minC = CGFloat(outerMinCol)
        let maxC = CGFloat(outerMaxCol + 1)
        let minR = CGFloat(outerMinRow)
        let maxR = CGFloat(outerMaxRow + 1)
        for i in vertices.indices {
            vertices[i].col = min(max(vertices[i].col, minC), maxC)
            vertices[i].row = min(max(vertices[i].row, minR), maxR)
        }
    }

    /// Ray-cast: je li središte ćelije unutar polygona (vrhovi na grid linijama)?
    func containsSeaCell(row: Int, col: Int) -> Bool {
        guard vertices.count >= 3 else { return false }
        let pr = CGFloat(row) + 0.5
        let pc = CGFloat(col) + 0.5
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let yi = vertices[i].row
            let xi = vertices[i].col
            let yj = vertices[j].row
            let xj = vertices[j].col
            let denom = yj - yi
            let safeDenom = abs(denom) < 1e-9 ? (denom >= 0 ? 1e-9 : -1e-9) : denom
            let hit = ((yi > pr) != (yj > pr))
                && (pc < (xj - xi) * (pr - yi) / safeDenom + xi)
            if hit { inside.toggle() }
            j = i
        }
        return inside
    }

    func isInOuter(row: Int, col: Int) -> Bool {
        row >= outerMinRow && row <= outerMaxRow && col >= outerMinCol && col <= outerMaxCol
    }

    func innerOutlinePoints(segments: Int = 0) -> [(row: CGFloat, col: CGFloat)] {
        vertices.map { ($0.row, $0.col) }
    }

    /// Vrhovi + mid-točke — sve leže na rubu polygona.
    func controlHandles() -> [SeaSurfaceHandle] {
        var list: [SeaSurfaceHandle] = []
        let n = vertices.count
        guard n >= 2 else { return list }
        for i in 0..<n {
            let v = vertices[i]
            list.append(SeaSurfaceHandle(kind: .vertex, index: i, row: v.row, col: v.col))
        }
        for i in 0..<n {
            let a = vertices[i]
            let b = vertices[(i + 1) % n]
            list.append(SeaSurfaceHandle(
                kind: .mid,
                index: i,
                row: (a.row + b.row) / 2,
                col: (a.col + b.col) / 2
            ))
        }
        return list
    }

    mutating func splitEdge(at edgeIndex: Int) {
        let n = vertices.count
        guard n >= 2, edgeIndex >= 0, edgeIndex < n else { return }
        let a = vertices[edgeIndex]
        let b = vertices[(edgeIndex + 1) % n]
        let mid = SeaPolygonVertex(row: (a.row + b.row) / 2, col: (a.col + b.col) / 2)
        vertices.insert(mid, at: edgeIndex + 1)
        clampInnerInsideOuter()
    }

    mutating func moveVertex(index: Int, row: CGFloat, col: CGFloat) {
        guard vertices.indices.contains(index) else { return }
        vertices[index].row = row
        vertices[index].col = col
        clampInnerInsideOuter()
    }
}

enum SeaSurfaceHandleKind: String, Equatable {
    case vertex
    case mid
}

struct SeaSurfaceHandle: Equatable {
    var kind: SeaSurfaceHandleKind
    var index: Int
    var row: CGFloat
    var col: CGFloat

    var nodeName: String {
        "seaH_\(kind.rawValue)_\(index)"
    }

    static func parse(nodeName: String) -> (kind: SeaSurfaceHandleKind, index: Int)? {
        guard nodeName.hasPrefix("seaH_") else { return nil }
        let rest = nodeName.dropFirst(5)
        let parts = rest.split(separator: "_")
        guard parts.count == 2,
              let kind = SeaSurfaceHandleKind(rawValue: String(parts[0])),
              let idx = Int(parts[1]) else { return nil }
        return (kind, idx)
    }
}
