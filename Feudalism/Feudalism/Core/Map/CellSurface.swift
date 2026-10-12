//
//  CellSurface.swift
//  Feudalism
//
//  Oblik ploče jedne ćelije: 5 točaka (4 kuta + sredina). Kutovi se dijele sa susjedima,
//  sredina pripada samo ćeliji. Svaka točka ima visinu i mali pomak u ravnini.
//

import Foundation
import CoreGraphics

enum TerrainHeight {
    static let min: CGFloat = -5
    static let max: CGFloat = 100

    static func clamp(_ value: CGFloat) -> CGFloat {
        Swift.min(max, Swift.max(min, value))
    }
}

/// Pomak točke u ravnini (u metrima). Ograničen da se ploče ne prevrnu.
enum TerrainPointOffset {
    static let limit: CGFloat = 0.45

    static func clamp(_ value: CGFloat) -> CGFloat {
        Swift.min(limit, Swift.max(-limit, value))
    }
}

/// Srednja točka ćelije. nil u ćeliji = automatski (sredina, prosjek kutova).
struct CellCenterPoint: Codable, Equatable {
    var dx: CGFloat = 0
    var dz: CGFloat = 0
    var height: CGFloat

    init(dx: CGFloat = 0, dz: CGFloat = 0, height: CGFloat) {
        self.dx = TerrainPointOffset.clamp(dx)
        self.dz = TerrainPointOffset.clamp(dz)
        self.height = TerrainHeight.clamp(height)
    }
}

/// Jedna točka ploče u koordinatama mreže: x = stupac, z = red (1 = 1 m), y = visina.
struct CellSurfacePoint: Equatable {
    var x: CGFloat
    var z: CGFloat
    var height: CGFloat
}

/// Svih 5 točaka ploče jedne ćelije.
struct CellSurface: Equatable {
    var topLeft: CellSurfacePoint
    var topRight: CellSurfacePoint
    var bottomRight: CellSurfacePoint
    var bottomLeft: CellSurfacePoint
    var center: CellSurfacePoint

    var corners: [CellSurfacePoint] { [topLeft, topRight, bottomRight, bottomLeft] }
    var allPoints: [CellSurfacePoint] { corners + [center] }

    /// Razlika najviše i najniže točke.
    var slope: CGFloat {
        let heights = allPoints.map(\.height)
        return (heights.max() ?? 0) - (heights.min() ?? 0)
    }

    var isFlat: Bool { slope < 0.01 }
}
