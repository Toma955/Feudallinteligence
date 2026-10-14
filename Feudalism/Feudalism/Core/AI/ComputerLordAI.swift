//
//  ComputerLordAI.swift
//  Feudalism
//
//  Inferenca: težine politike + heuristika. Snapshot učitava mape zasebnim pozivima.
//

import Foundation

enum ComputerLordComputeTarget {
    case neuralEngineAndCPU
    case gpuAndCPU
    case all
}

final class ComputerLordAI {
    let realmId: String
    var computeTarget: ComputerLordComputeTarget = .all
    var profileId: String?

    init(realmId: String, profileId: String? = nil) {
        self.realmId = realmId
        self.profileId = profileId
    }

    var profile: AILordProfile? {
        guard let id = profileId else { return nil }
        return AILordProfileStore.shared.profile(id: id)
    }

    func decideNextAction(gameState: GameState) async {
        _ = proposeMove(in: gameState)
    }

    /// Predloži potez: politika (ako ima težine) bira akciju; inače heuristika.
    func proposeMove(in gameState: GameState) -> (thought: String, move: AILordOrderedMove?) {
        _ = GameSituationSnapshot.from(gameState: gameState, actingRealmId: realmId, maps: .routine)

        guard let seat = gameState.realmSeats.seats.first(where: {
            $0.id == realmId || $0.realmIds.contains(realmId)
        }) else {
            return ("nema sjedišta.", nil)
        }
        let nearRow = Int(seat.castleRow.rounded())
        let nearCol = Int(seat.castleCol.rounded())
        let own = gameState.mapLogic.allPlacements
            .map(\.placement)
            .filter { gameState.owner(of: $0) == seat.id }
        let ids = own.map { $0.objectId.lowercased() }
        func has(_ piece: String) -> Bool { ids.contains { $0.contains(piece) } }

        let stateFeatures = AILordStateEncoder.encode(from: gameState)
        let store = AILordProfileStore.shared
        let vocabulary = store.notebook.vocabulary

        if let profile, let weights = store.weights(for: profile) {
            let logits = weights.forward(stateFeatures: stateFeatures).logits
            if let pick = rankedBuildOrWait(
                logits: logits,
                vocabulary: vocabulary,
                has: has,
                style: profile.fightingStyle
            ) {
                if pick.actionId == "action:wait" {
                    return ("politika: čeka (naučeno).", .wait())
                }
                if pick.actionId.hasPrefix("action:build:") {
                    let objectId = String(pick.actionId.dropFirst("action:build:".count))
                    if let spot = gameState.findAIBuildSpot(objectId: objectId, nearRow: nearRow, nearCol: nearCol) {
                        let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
                        return ("politika: gradi \(name).", .build(objectId, row: spot.row, col: spot.col))
                    }
                }
            }
        }

        return heuristicMove(has: has, nearRow: nearRow, nearCol: nearCol, gameState: gameState)
    }

    private func rankedBuildOrWait(
        logits: [Float],
        vocabulary: AILordVocabulary,
        has: (String) -> Bool,
        style: AIFightingStyle
    ) -> (actionId: String, score: Float)? {
        var candidates: [(String, Float)] = []
        for (index, actionId) in vocabulary.actions.enumerated() {
            guard index < logits.count else { continue }
            if actionId == "action:wait" {
                candidates.append((actionId, logits[index]))
                continue
            }
            guard actionId.hasPrefix("action:build:") else { continue }
            let objectId = String(actionId.dropFirst("action:build:".count)).lowercased()
            if objectId.contains("house"), has("house") { continue }
            if (objectId.contains("farm") || objectId.contains("apple") || objectId.contains("corn")),
               has("farm") || has("corn") || has("apple") { continue }
            if objectId.contains("smocnica") || objectId.contains("food"), has("smocnica") || has("food") { continue }
            if objectId.contains("lager"), has("lager") { continue }
            if objectId.contains("training"), has("training") { continue }
            if objectId.contains("market"), style != .economic, style != .balanced { continue }
            candidates.append((actionId, logits[index]))
        }
        return candidates.max(by: { $0.1 < $1.1 }).map { ($0.0, $0.1) }
    }

    private func heuristicMove(
        has: (String) -> Bool,
        nearRow: Int,
        nearCol: Int,
        gameState: GameState
    ) -> (thought: String, move: AILordOrderedMove?) {
        let style = profile?.fightingStyle ?? .balanced
        func buildSpot(_ objectId: String, thought: String) -> (String, AILordOrderedMove?) {
            if let spot = gameState.findAIBuildSpot(objectId: objectId, nearRow: nearRow, nearCol: nearCol) {
                return (thought, .build(objectId, row: spot.row, col: spot.col))
            }
            return (thought + " Nema slobodnog mjesta.", nil)
        }
        if !has("house") {
            return buildSpot(House.objectId, thought: "heuristika: gradi kuću.")
        }
        if !has("farm") && !has("corn") && !has("apple") && (style == .economic || style == .balanced) {
            return buildSpot(Farm.objectId, thought: "heuristika: gradi farmu.")
        }
        if !has("smocnica") && !has("food") {
            return buildSpot(Smocnica.objectId, thought: "heuristika: gradi smočnicu.")
        }
        if !has("training") && (style == .aggressive || style == .raider) {
            return buildSpot(Training.objectId, thought: "heuristika: gradi trening.")
        }
        if !has("lager") {
            return buildSpot(Lager.objectId, thought: "heuristika: gradi skladište.")
        }
        if !has("market") && style == .economic {
            return buildSpot(Market.objectId, thought: "heuristika: gradi tržnicu.")
        }
        return ("heuristika: čeka.", .wait())
    }
}

extension GameState {
    func tickAILords() {
        guard aiEnabled, recordThisMatch else { return }
        let lords = computerLords.filter { !$0.isDefeated }
        guard lords.count >= 2, currentTurn > 0, currentTurn % 12 == 0 else { return }
        let lord = lords[(currentTurn / 12) % lords.count]
        let decision = ComputerLordAI(realmId: lord.id, profileId: lord.aiProfileId).proposeMove(in: self)
        var text = decision.thought
        var row = 0
        var col = 0
        if let seat = realmSeats.seats.first(where: { $0.id == lord.id || $0.realmIds.contains(lord.id) }) {
            row = Int(seat.castleRow.rounded())
            col = Int(seat.castleCol.rounded())
        }
        var actionId: String?
        if let move = decision.move {
            actionId = move.actionId
            let result = executeAIMove(move, forRealmId: lord.id)
            text += " \(result.message)"
            if let r = result.row { row = r }
            if let c = result.col { col = c }
        } else {
            text += " Napravio: čeka."
            actionId = "action:wait"
        }
        MatchHistoryStore.shared.noteThought(
            from: self,
            lord: lord.name,
            text: text,
            row: row,
            col: col,
            actionId: actionId
        )
    }

    func findAIBuildSpot(objectId: String, nearRow: Int, nearCol: Int) -> (row: Int, col: Int)? {
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = max(1, obj?.size.width ?? 1)
        let height = max(1, obj?.size.height ?? 1)
        for radius in 3...16 {
            for dr in -radius...radius {
                for dc in -radius...radius where max(abs(dr), abs(dc)) == radius {
                    let row = nearRow + dr
                    let col = nearCol + dc
                    guard row >= 1, col >= 1, row + height < gameMap.rows, col + width < gameMap.cols else { continue }
                    guard mapLogic.isFree(.surface, row: row, col: col, width: width, height: height) else { continue }
                    if buildRuleViolation(objectId: objectId, row: row, col: col, width: width, height: height) != nil { continue }
                    return (row, col)
                }
            }
        }
        return nil
    }
}
