//
//  AILordVision.swift
//  Feudalism
//
//  Što AI čita s karte: svaki sloj je zaseban poziv. Odluke (LivePartyLog) nisu mapa
//  za trenutni gameplay — kasnije za treniranje / review.
//

import Foundation

/// Koje tekstualne mape lord traži u ovom potezu.
struct AILordMapRequest: OptionSet, Codable, Hashable {
    let rawValue: Int

    init(rawValue: Int) { self.rawValue = rawValue }

    static let surface = AILordMapRequest(rawValue: 1 << 0)
    static let underground = AILordMapRequest(rawValue: 1 << 1)
    static let buildings = AILordMapRequest(rawValue: 1 << 2)
    static let army = AILordMapRequest(rawValue: 1 << 3)

    /// Uobičajeni pogled: ljudi/vojnici + građevine/resursi na površini. Bez podzemlja.
    static let routine: AILordMapRequest = [.surface, .buildings, .army]

    /// Sve četiri mape (skupo — rijetko).
    static let all: AILordMapRequest = [.surface, .underground, .buildings, .army]

    var kinds: [TextMapCapture.MapLayerKind] {
        var list: [TextMapCapture.MapLayerKind] = []
        if contains(.surface) { list.append(.surface) }
        if contains(.underground) { list.append(.underground) }
        if contains(.buildings) { list.append(.buildings) }
        if contains(.army) { list.append(.army) }
        return list
    }
}

/// Rezultat zasebnih poziva mapa — samo ispunjeni slojevi koje je AI zatražio.
struct AILordVision: Equatable {
    var surface: String?
    var underground: String?
    var buildings: String?
    var army: String?
    var blockSize: Int

    /// Učitaj samo tražene slojeve (svaki `TextMapCapture.capture` zasebno).
    static func read(from state: GameState, maps: AILordMapRequest = .routine) -> AILordVision {
        var vision = AILordVision(
            surface: nil,
            underground: nil,
            buildings: nil,
            army: nil,
            blockSize: TextMapCapture.blockSize(rows: state.gameMap.rows, cols: state.gameMap.cols)
        )
        if maps.contains(.surface) {
            vision.surface = TextMapCapture.captureSurface(from: state)
        }
        if maps.contains(.underground) {
            vision.underground = TextMapCapture.captureUnderground(from: state)
        }
        if maps.contains(.buildings) {
            vision.buildings = TextMapCapture.captureBuildings(from: state)
        }
        if maps.contains(.army) {
            vision.army = TextMapCapture.captureArmy(from: state)
        }
        return vision
    }

    /// Jedan sloj — kad treba samo vojska ili samo građevine.
    static func read(_ kind: TextMapCapture.MapLayerKind, from state: GameState) -> String {
        TextMapCapture.capture(kind, from: state)
    }
}
