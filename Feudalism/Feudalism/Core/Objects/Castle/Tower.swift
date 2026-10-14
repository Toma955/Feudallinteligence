//
//  Tower.swift
//  Feudalism
//
//  Pet tipova kula (Dvor → Kule): od najslabije do najjače helte.
//

import Foundation
import AppKit
import SceneKit

/// Tip kule za gradnju. Redoslijed = rastuća helta.
enum TowerKind: String, CaseIterable, Identifiable {
    /// Visoka uska okrugla — najmanje helte.
    case roundTall
    /// Niska kvadratna mala.
    case squareSmall
    /// Srednje kvadratna.
    case squareMedium
    /// Velika kvadratna.
    case squareLarge
    /// Velika okrugla — najviše helte.
    case roundLarge

    var id: String { rawValue }

    var objectId: String { "object_tower_\(rawValue)" }

    var localeKey: String { "tower_\(rawValue)" }

    var displayName: String {
        switch self {
        case .roundTall: return "Visoka uska okrugla"
        case .squareSmall: return "Niska kvadratna mala"
        case .squareMedium: return "Srednja kvadratna"
        case .squareLarge: return "Velika kvadratna"
        case .roundLarge: return "Velika okrugla"
        }
    }

    /// Tlocrt u ćelijama.
    var footprint: (width: Int, height: Int) {
        switch self {
        case .roundTall: return (1, 1)
        case .squareSmall: return (1, 1)
        case .squareMedium: return (2, 2)
        case .squareLarge: return (3, 3)
        case .roundLarge: return (3, 3)
        }
    }

    /// levels × hpPerLevel — prva najmanje, zadnja najviše.
    var healthLevels: Int {
        switch self {
        case .roundTall: return 4
        case .squareSmall: return 6
        case .squareMedium: return 8
        case .squareLarge: return 10
        case .roundLarge: return 14
        }
    }

    var hpPerLevel: Int { 10 }

    var maxHealth: Int { healthLevels * hpPerLevel }

    var systemImage: String {
        switch self {
        case .roundTall: return "cylinder.fill"
        case .squareSmall: return "cube.fill"
        case .squareMedium: return "square.fill"
        case .squareLarge: return "square.fill.on.square.fill"
        case .roundLarge: return "building.columns.fill"
        }
    }

    static func kind(for objectId: String) -> TowerKind? {
        allCases.first { $0.objectId == objectId }
    }

    static func isTower(_ objectId: String) -> Bool {
        kind(for: objectId) != nil
    }

    static var allObjectIds: [String] { allCases.map(\.objectId) }
}

// MARK: - Placeable tipovi (jedan po vrsti)

enum TowerRoundTall: PlaceableSceneKitObject {
    static let kind = TowerKind.roundTall
    static var objectId: String { kind.objectId }
    static var gameObject: GameObject { Tower.gameObject(kind) }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { Tower.loadNode(kind: kind) }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum TowerSquareSmall: PlaceableSceneKitObject {
    static let kind = TowerKind.squareSmall
    static var objectId: String { kind.objectId }
    static var gameObject: GameObject { Tower.gameObject(kind) }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { Tower.loadNode(kind: kind) }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum TowerSquareMedium: PlaceableSceneKitObject {
    static let kind = TowerKind.squareMedium
    static var objectId: String { kind.objectId }
    static var gameObject: GameObject { Tower.gameObject(kind) }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { Tower.loadNode(kind: kind) }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum TowerSquareLarge: PlaceableSceneKitObject {
    static let kind = TowerKind.squareLarge
    static var objectId: String { kind.objectId }
    static var gameObject: GameObject { Tower.gameObject(kind) }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { Tower.loadNode(kind: kind) }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum TowerRoundLarge: PlaceableSceneKitObject {
    static let kind = TowerKind.roundLarge
    static var objectId: String { kind.objectId }
    static var gameObject: GameObject { Tower.gameObject(kind) }
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? { Tower.loadNode(kind: kind) }
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

enum Tower {
    static let placeableTypes: [PlaceableSceneKitObject.Type] = [
        TowerRoundTall.self,
        TowerSquareSmall.self,
        TowerSquareMedium.self,
        TowerSquareLarge.self,
        TowerRoundLarge.self
    ]

    static func gameObject(_ kind: TowerKind) -> GameObject {
        let fp = kind.footprint
        return GameObject(
            id: kind.objectId,
            name: kind.displayName,
            category: .dvorac,
            width: fp.width,
            height: fp.height,
            displayCode: "K",
            modelAssetName: nil
        )
    }

    static func loadNode(kind: TowerKind) -> SCNNode {
        BuildingShapes.tower(kind: kind)
    }
}
