//
//  RiverPathDraft.swift
//  Feudalism
//
//  Uređivanje rijeke: polilinija s početkom/krajem, mid-točkama (klik = split),
//  zaobljenjem (curve) i širinom (područje rijeke).
//

import Foundation
import CoreGraphics

struct RiverPathVertex: Equatable, Codable {
    var row: CGFloat
    var col: CGFloat
}

/// Privremeni nacrt vode-linije (rijeka / jezero / močvara) dok traje uređivanje.
struct RiverPathDraft: Equatable {
    var pad: PadBrush
    var vertices: [RiverPathVertex]
    /// 0 = oštri lomovi, 1 = jako zaobljeno (Catmull-Rom).
    var curve: CGFloat
    /// Polovična širina u ćelijama (područje oko crte).
    var halfWidth: CGFloat

    static func fromEndpoints(
        pad: PadBrush,
        row0: CGFloat, col0: CGFloat,
        row1: CGFloat, col1: CGFloat
    ) -> RiverPathDraft {
        let defaults = Self.defaults(for: pad)
        var d = RiverPathDraft(
            pad: pad,
            vertices: [
                RiverPathVertex(row: row0, col: col0),
                RiverPathVertex(row: row1, col: col1)
            ],
            curve: defaults.curve,
            halfWidth: defaults.halfWidth
        )
        d.clamp()
        return d
    }

    /// Zadane vrijednosti po tipu vode.
    static func defaults(for pad: PadBrush) -> (curve: CGFloat, halfWidth: CGFloat) {
        switch pad {
        case .jezero, .mocvara: return (0.5, 2.0)
        default: return (0.35, 0.75) // rijeka
        }
    }

    /// Površina koju nacrt boja na mapi.
    var paintedSurface: PovrsinaType {
        pad == .mocvara ? .mocvara : .voda
    }

    /// Indeks kretanja nakon bojanja. Jezero = prohodno; močvara / rijeka = ne.
    var paintedMovementIndex: Double {
        pad == .jezero ? 1 : 0
    }

    mutating func clamp() {
        curve = min(1, max(0, curve))
        halfWidth = min(6, max(0.35, halfWidth))
        guard vertices.count >= 2 else { return }
    }

    /// Kontrolne točke: vrhovi + mid na svakom segmentu.
    func controlHandles() -> [RiverPathHandle] {
        var list: [RiverPathHandle] = []
        let n = vertices.count
        guard n >= 2 else { return list }
        for i in 0..<n {
            let v = vertices[i]
            list.append(RiverPathHandle(kind: .vertex, index: i, row: v.row, col: v.col))
        }
        for i in 0..<(n - 1) {
            let a = vertices[i]
            let b = vertices[i + 1]
            list.append(RiverPathHandle(
                kind: .mid,
                index: i,
                row: (a.row + b.row) / 2,
                col: (a.col + b.col) / 2
            ))
        }
        return list
    }

    mutating func splitSegment(at index: Int) {
        guard index >= 0, index < vertices.count - 1 else { return }
        let a = vertices[index]
        let b = vertices[index + 1]
        let mid = RiverPathVertex(row: (a.row + b.row) / 2, col: (a.col + b.col) / 2)
        vertices.insert(mid, at: index + 1)
    }

    mutating func moveVertex(index: Int, row: CGFloat, col: CGFloat) {
        guard vertices.indices.contains(index) else { return }
        vertices[index].row = row
        vertices[index].col = col
    }

    /// Uzorkovana središnja crta (zaobljeni Catmull-Rom kad je curve > 0).
    func sampledCenterline(samplesPerSegment: Int = 12) -> [(row: CGFloat, col: CGFloat)] {
        let n = vertices.count
        guard n >= 2 else { return [] }
        if curve < 0.02 || n == 2 {
            // Linearno uzorkovanje po segmentima.
            var pts: [(CGFloat, CGFloat)] = []
            let segs = max(2, samplesPerSegment)
            for i in 0..<(n - 1) {
                let a = vertices[i]
                let b = vertices[i + 1]
                let steps = (i == n - 2) ? segs : segs - 1
                for s in 0..<steps {
                    let t = CGFloat(s) / CGFloat(segs - 1)
                    pts.append((a.row + (b.row - a.row) * t, a.col + (b.col - a.col) * t))
                }
            }
            let last = vertices[n - 1]
            pts.append((last.row, last.col))
            return pts.map { ($0.0, $0.1) }
        }
        // Catmull-Rom kroz točke; curve miješa s linearnim.
        var out: [(CGFloat, CGFloat)] = []
        let segs = max(4, samplesPerSegment)
        for i in 0..<(n - 1) {
            let p0 = vertices[max(0, i - 1)]
            let p1 = vertices[i]
            let p2 = vertices[i + 1]
            let p3 = vertices[min(n - 1, i + 2)]
            let steps = (i == n - 2) ? segs : segs - 1
            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(segs - 1)
                let cr = catmull(p0, p1, p2, p3, t)
                let linR = p1.row + (p2.row - p1.row) * t
                let linC = p1.col + (p2.col - p1.col) * t
                let r = linR + (cr.row - linR) * curve
                let c = linC + (cr.col - linC) * curve
                out.append((r, c))
            }
        }
        let last = vertices[n - 1]
        out.append((last.row, last.col))
        return out
    }

    private func catmull(
        _ p0: RiverPathVertex, _ p1: RiverPathVertex,
        _ p2: RiverPathVertex, _ p3: RiverPathVertex,
        _ t: CGFloat
    ) -> (row: CGFloat, col: CGFloat) {
        let t2 = t * t
        let t3 = t2 * t
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        }
        return (
            axis(p0.row, p1.row, p2.row, p3.row),
            axis(p0.col, p1.col, p2.col, p3.col)
        )
    }

    /// Rubovi trake (lijevo/desno) za preview širine.
    func ribbonEdges(samplesPerSegment: Int = 12) -> (left: [(CGFloat, CGFloat)], right: [(CGFloat, CGFloat)]) {
        let center = sampledCenterline(samplesPerSegment: samplesPerSegment)
        guard center.count >= 2 else { return ([], []) }
        var left: [(CGFloat, CGFloat)] = []
        var right: [(CGFloat, CGFloat)] = []
        left.reserveCapacity(center.count)
        right.reserveCapacity(center.count)
        for i in 0..<center.count {
            let prev = center[max(0, i - 1)]
            let next = center[min(center.count - 1, i + 1)]
            var dr = next.row - prev.row
            var dc = next.col - prev.col
            let len = hypot(dr, dc)
            if len < 1e-6 {
                dr = 0; dc = 1
            } else {
                dr /= len; dc /= len
            }
            // Normala u (row, col): (-dc, dr)
            let nr = -dc * halfWidth
            let nc = dr * halfWidth
            left.append((center[i].row + nr, center[i].col + nc))
            right.append((center[i].row - nr, center[i].col - nc))
        }
        return (left, right)
    }

    /// Je li središte ćelije unutar trake rijeke?
    func containsRiverCell(row: Int, col: Int) -> Bool {
        let pr = CGFloat(row) + 0.5
        let pc = CGFloat(col) + 0.5
        let center = sampledCenterline(samplesPerSegment: 10)
        guard center.count >= 2 else { return false }
        var best = CGFloat.greatestFiniteMagnitude
        for i in 0..<(center.count - 1) {
            let a = center[i]
            let b = center[i + 1]
            best = min(best, distPointToSegment(pr, pc, a.row, a.col, b.row, b.col))
        }
        return best <= halfWidth
    }

    private func distPointToSegment(
        _ px: CGFloat, _ py: CGFloat,
        _ ax: CGFloat, _ ay: CGFloat,
        _ bx: CGFloat, _ by: CGFloat
    ) -> CGFloat {
        let abx = bx - ax, aby = by - ay
        let apx = px - ax, apy = py - ay
        let ab2 = abx * abx + aby * aby
        if ab2 < 1e-12 { return hypot(apx, apy) }
        var t = (apx * abx + apy * aby) / ab2
        t = min(1, max(0, t))
        let qx = ax + abx * t
        let qy = ay + aby * t
        return hypot(px - qx, py - qy)
    }
}

enum RiverPathHandleKind: String, Equatable {
    case vertex
    case mid
}

struct RiverPathHandle: Equatable {
    var kind: RiverPathHandleKind
    var index: Int
    var row: CGFloat
    var col: CGFloat

    var nodeName: String { "rivH_\(kind.rawValue)_\(index)" }

    static func parse(nodeName: String) -> (kind: RiverPathHandleKind, index: Int)? {
        guard nodeName.hasPrefix("rivH_") else { return nil }
        let parts = nodeName.dropFirst(5).split(separator: "_")
        guard parts.count == 2,
              let kind = RiverPathHandleKind(rawValue: String(parts[0])),
              let idx = Int(parts[1]) else { return nil }
        return (kind, idx)
    }
}
