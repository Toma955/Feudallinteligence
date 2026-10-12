//
//  MatchHistoryModels.swift
//  Feudalism
//
//  Snimka partije: popis i okviri. Svaki okvir ima četiri tekstualne mape
//  kako ih AI vidi (glavna, podzemlje, građevine, vojska).
//

import Foundation

enum MatchHistoryKind: String, Codable, CaseIterable, Identifiable {
    case sandbox
    case military
    case economic

    var id: String { rawValue }

    var localeKey: String {
        switch self {
        case .sandbox: return "history_filter_sandbox"
        case .military: return "history_filter_military"
        case .economic: return "history_filter_economic"
        }
    }
}

struct MatchHistoryPlayer: Codable, Hashable {
    var name: String
    var isHuman: Bool
}

struct MatchHistorySummary: Codable, Identifiable, Hashable {
    var id: String
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var kind: MatchHistoryKind
    var mapLabel: String
    var players: [MatchHistoryPlayer]
    var result: String?
    var frameCount: Int
    var lastTurn: Int

    var partyLabel: String {
        players.map(\.name).joined(separator: " · ")
    }
}

struct MatchHistoryFrame: Codable, Identifiable {
    var id: String
    var turn: Int
    var main: String
    var underground: String
    var buildings: String
    var army: String
}

struct MatchHistoryRecord: Codable, Identifiable {
    var id: String
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var kind: MatchHistoryKind
    var mapLabel: String
    var mapRows: Int
    var mapCols: Int
    var block: Int
    var visionRows: Int
    var visionCols: Int
    var players: [MatchHistoryPlayer]
    var result: String?
    var frames: [MatchHistoryFrame]

    var summary: MatchHistorySummary {
        MatchHistorySummary(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            title: title,
            kind: kind,
            mapLabel: mapLabel,
            players: players,
            result: result,
            frameCount: frames.count,
            lastTurn: frames.last?.turn ?? 1
        )
    }
}
