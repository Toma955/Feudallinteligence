//
//  ComputerLordAI.swift
//  Feudalism
//
//  Igra je isključivo za treniranje i ograđivanje AI modela. Modeli imaju osnovne postavke
//  (profil: stil borbe, taktika, strategija) i prema njima se ponašaju. Koriste REALNU
//  situaciju u igri – reagiraju na nju, predviđaju budućnost. Treniranje: Python (isti
//  format situacije, npr. JSON). Inferenca u igri: Swift + Core ML (Neural Engine / GPU / CPU).
//

import Foundation

/// Označava da će computer lord koristiti Apple ML stack (Neural Engine, CPU, GPU).
enum ComputerLordComputeTarget {
    case neuralEngineAndCPU
    case gpuAndCPU
    case all
}

/// Kontroler AI za computer lord. Koristi realnu situaciju u igri (GameSituationSnapshot),
/// osnovne postavke profila i prema njima reagira i predvida; Python koristi isti snapshot za treniranje.
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

    /// Realna situacija u igri → predloženi potez (s koordinatama kad treba).
    func decideNextAction(gameState: GameState) async {
        _ = proposeMove(in: gameState)
    }

    /// Heuristika dok nema naučene politike: bira tip poteza i točnu ćeliju.
    func proposeMove(in gameState: GameState) -> (thought: String, move: AILordOrderedMove?) {
        let situation = GameSituationSnapshot.from(gameState: gameState, actingRealmId: realmId)
        let own = situation.placements.filter { $0.realmId == realmId }
        let ids = own.map { $0.objectId.lowercased() }
        func has(_ piece: String) -> Bool { ids.contains { $0.contains(piece) } }
        let style = profile?.fightingStyle ?? .balanced

        guard let seat = gameState.realmSeats.seats.first(where: {
            $0.id == realmId || $0.realmIds.contains(realmId)
        }) else {
            return ("nema sjedišta.", nil)
        }
        let nearRow = Int(seat.castleRow.rounded())
        let nearCol = Int(seat.castleCol.rounded())

        func buildSpot(_ objectId: String, thought: String) -> (String, AILordOrderedMove?) {
            if let spot = gameState.findAIBuildSpot(
                objectId: objectId,
                nearRow: nearRow,
                nearCol: nearCol
            ) {
                return (thought, .build(objectId, row: spot.row, col: spot.col))
            }
            return (thought + " Nema slobodnog mjesta.", nil)
        }

        if !has("house") {
            return buildSpot(House.objectId, thought: "razmišlja: ljudi nemaju krov, pa gradi kuću.")
        }
        if !has("farm") && !has("corn") && !has("apple") && (style == .economic || style == .balanced) {
            return buildSpot(Farm.objectId, thought: "razmišlja: hrana je tanka, pa gradi farmu.")
        }
        if !has("smocnica") && !has("food") {
            return buildSpot(Smocnica.objectId, thought: "razmišlja: zaliha nema kamo, pa gradi smočnicu.")
        }
        if !has("training") && (style == .aggressive || style == .raider) {
            return buildSpot(Training.objectId, thought: "razmišlja: vojska je prazna, pa gradi trening.")
        }
        if !has("lager") {
            return buildSpot(Lager.objectId, thought: "razmišlja: sirovine stoje vani, pa gradi skladište.")
        }
        if !has("market") && style == .economic {
            return buildSpot(Market.objectId, thought: "razmišlja: treba tržnica za kupnju i prodaju.")
        }
        return ("razmišlja: dvorac drži ritam i za sada ne gradi.", .wait())
    }

    /// Stari API: misao + tip građevine (bez koordinate).
    func think(in gameState: GameState) -> (thought: String, objectId: String?) {
        let proposal = proposeMove(in: gameState)
        let objectId: String?
        if let move = proposal.move, move.actionId.hasPrefix("action:build:") {
            objectId = String(move.actionId.dropFirst("action:build:".count))
        } else {
            objectId = nil
        }
        return (proposal.thought, objectId)
    }
}

extension GameState {
    /// Dva ili više AI lordova: svakih 12 s jedan odigra potez (s točnom ćelijom).
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
        if let move = decision.move {
            let result = executeAIMove(move, forRealmId: lord.id)
            text += " \(result.message)"
            if let r = result.row { row = r }
            if let c = result.col { col = c }
        } else {
            text += " Napravio: čeka."
        }
        MatchHistoryStore.shared.noteThought(from: self, lord: lord.name, text: text, row: row, col: col)
    }

    /// Pronađi prvo slobodno mjesto oko točke (za predlaganje poteza).
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
