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

struct MatchTimelineEvent: Codable, Equatable, Identifiable {
    var id: String
    var second: Int
    var turn: Int
    var action: String
    var row: Int
    var col: Int
    var gold: Int
    var wood: Int
    var stone: Int
    var iron: Int
    var food: Int
    var population: Int? = nil
    var happiness: Int? = nil
}

/// Ocjena odluke iz Analize (dobra / loša / neutralna).
enum DecisionQuality: String, Codable, Equatable, CaseIterable {
    case good
    case bad
    case neutral

    var localeKey: String {
        switch self {
        case .good: return "train_decision_good"
        case .bad: return "train_decision_bad"
        case .neutral: return "train_decision_neutral"
        }
    }
}

/// Jedna odluka u snimci: tko, u kojoj sekundi, što.
struct MatchDecision: Codable, Equatable, Identifiable {
    var id: String
    var second: Int
    var actor: String
    var action: String
    var row: Int
    var col: Int
    var population: Int? = nil
    var happiness: Int? = nil
    /// Id iz AI rječnika (npr. `action:build:house`) — za trening politike.
    var actionId: String? = nil
    /// Ocjena iz Analize: good / bad / neutral.
    var quality: DecisionQuality? = nil

    private enum CodingKeys: String, CodingKey {
        case id, second, actor, action, row, col, population, happiness, actionId, quality
    }

    init(
        id: String,
        second: Int,
        actor: String,
        action: String,
        row: Int,
        col: Int,
        population: Int? = nil,
        happiness: Int? = nil,
        actionId: String? = nil,
        quality: DecisionQuality? = nil
    ) {
        self.id = id
        self.second = second
        self.actor = actor
        self.action = action
        self.row = row
        self.col = col
        self.population = population
        self.happiness = happiness
        self.actionId = actionId
        self.quality = quality
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        second = try c.decode(Int.self, forKey: .second)
        actor = try c.decode(String.self, forKey: .actor)
        action = try c.decode(String.self, forKey: .action)
        row = try c.decode(Int.self, forKey: .row)
        col = try c.decode(Int.self, forKey: .col)
        population = try c.decodeIfPresent(Int.self, forKey: .population)
        happiness = try c.decodeIfPresent(Int.self, forKey: .happiness)
        actionId = try c.decodeIfPresent(String.self, forKey: .actionId)
        quality = try c.decodeIfPresent(DecisionQuality.self, forKey: .quality)
    }
}

struct MatchHistoryFrame: Codable, Identifiable {
    var id: String
    var turn: Int
    var main: String
    var underground: String
    var buildings: String
    var army: String
    /// Vrijeme, resursi i koordinate poteza do ovog okvira.
    var timeline: String
    /// Visine sjecišta. Samo GUI, ne za trening ni AI.
    var heightMap: String

    init(id: String, turn: Int, main: String, underground: String, buildings: String, army: String, timeline: String = "", heightMap: String = "") {
        self.id = id
        self.turn = turn
        self.main = main
        self.underground = underground
        self.buildings = buildings
        self.army = army
        self.timeline = timeline
        self.heightMap = heightMap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        turn = try c.decode(Int.self, forKey: .turn)
        main = try c.decode(String.self, forKey: .main)
        underground = try c.decode(String.self, forKey: .underground)
        buildings = try c.decode(String.self, forKey: .buildings)
        army = try c.decode(String.self, forKey: .army)
        timeline = try c.decodeIfPresent(String.self, forKey: .timeline) ?? ""
        heightMap = try c.decodeIfPresent(String.self, forKey: .heightMap) ?? ""
    }
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
    /// Odluke svih koji se snimaju. Stare snimke nemaju ovo polje.
    var decisions: [MatchDecision]? = nil

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
