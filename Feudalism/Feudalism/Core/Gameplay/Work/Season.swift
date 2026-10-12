//
//  Season.swift
//  Feudalism
//
//  Godišnje doba u logici igre (ne u prikazu): ovisi samo o potezu, pa vrijedi i u simulatoru.
//

import Foundation

enum Season: String, CaseIterable, Codable {
    case winter
    case spring
    case summer
    case autumn

    /// Redoslijed u godini; partija počinje zimom.
    static let cycle: [Season] = [.winter, .spring, .summer, .autumn]

    /// Poteza po godišnjem dobu. 1 potez = 1 s, dakle 45 s po dobu i 180 s po godini.
    static let turnsPerSeason = 45

    static func at(turn: Int) -> (season: Season, yearOffset: Int) {
        let elapsed = max(0, turn - 1)
        let index = (elapsed / turnsPerSeason) % cycle.count
        return (cycle[index], elapsed / (turnsPerSeason * cycle.count))
    }

    var displayName: String {
        switch self {
        case .winter: return "Zima"
        case .spring: return "Proljeće"
        case .summer: return "Ljeto"
        case .autumn: return "Jesen"
        }
    }
}
