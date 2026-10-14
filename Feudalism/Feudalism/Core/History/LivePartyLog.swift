//
//  LivePartyLog.swift
//  Feudalism
//
//  Uživi log partije bez snimanja na disk: zadnjih 25 odluka (starije se brišu).
//

import Foundation
import Combine

final class LivePartyLog: ObservableObject {
    static let shared = LivePartyLog()
    static let maxDecisions = 25

    @Published private(set) var decisions: [MatchDecision] = []

    private init() {}

    func clear() {
        decisions = []
    }

    /// Dodaj odluku; drži samo zadnjih `maxDecisions` (najstarije nestaju).
    func note(
        actor: String,
        second: Int,
        action: String,
        row: Int,
        col: Int,
        population: Int? = nil,
        happiness: Int? = nil,
        actionId: String? = nil
    ) {
        decisions.append(MatchDecision(
            id: UUID().uuidString,
            second: second,
            actor: actor,
            action: action,
            row: row,
            col: col,
            population: population,
            happiness: happiness,
            actionId: actionId
        ))
        trim()
    }

    func noteBuild(from state: GameState, name: String, row: Int, col: Int, actionId: String? = nil) {
        let actor = state.playerSeat?.displayName ?? state.playerProfileName
        let trimmed = actor.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = trimmed.isEmpty ? "Igrač" : trimmed
        let faction = state.playerSeat?.id
        let pop = faction.map { state.population(of: $0) } ?? state.playerPopulation
        let happy = faction.map { Int(state.happinessPercent(of: $0).rounded()) }
            ?? Int(state.playerHappiness.rounded())
        note(
            actor: who,
            second: max(0, state.currentTurn - 1),
            action: "izgradio \(name) · populacija \(pop) · sreća \(happy)%",
            row: row,
            col: col,
            population: pop,
            happiness: happy,
            actionId: actionId
        )
    }

    func noteDemolish(from state: GameState, name: String, row: Int, col: Int) {
        let actor = state.playerSeat?.displayName ?? "Igrač"
        note(
            actor: actor,
            second: max(0, state.currentTurn - 1),
            action: "srušio \(name)",
            row: row,
            col: col,
            actionId: "action:demolish"
        )
    }

    func noteArmy(from state: GameState, action: String, row: Int, col: Int) {
        let actor = state.playerSeat?.displayName ?? "Igrač"
        note(
            actor: actor,
            second: max(0, state.currentTurn - 1),
            action: action,
            row: row,
            col: col,
            actionId: "action:send_army"
        )
    }

    func noteAI(from state: GameState, lord: String, text: String, row: Int, col: Int, actionId: String? = nil) {
        note(
            actor: lord,
            second: max(0, state.currentTurn - 1),
            action: text,
            row: row,
            col: col,
            actionId: actionId
        )
    }

    private func trim() {
        let overflow = decisions.count - Self.maxDecisions
        if overflow > 0 {
            decisions.removeFirst(overflow)
        }
    }
}
