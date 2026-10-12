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

    /// Realna situacija u igri → reakcija i predviđanje. Snapshot je isti format koji Python koristi za treniranje.
    func decideNextAction(gameState: GameState) async {
        _ = think(in: gameState)
    }

    /// Kratka misao i, ako treba, građevina koju lord želi podići.
    func think(in gameState: GameState) -> (thought: String, objectId: String?) {
        let situation = GameSituationSnapshot.from(gameState: gameState, actingRealmId: realmId)
        let own = situation.placements.filter { $0.realmId == realmId }
        let ids = own.map { $0.objectId.lowercased() }
        func has(_ piece: String) -> Bool { ids.contains { $0.contains(piece) } }
        let style = profile?.fightingStyle ?? .balanced

        if !has("house") {
            return ("razmišlja: ljudi nemaju krov, pa gradi kuću.", House.objectId)
        }
        if !has("farm") && !has("corn") && !has("apple") && (style == .economic || style == .balanced) {
            return ("razmišlja: hrana je tanka, pa gradi farmu.", Farm.objectId)
        }
        if !has("smocnica") && !has("food") {
            return ("razmišlja: zaliha nema kamo, pa gradi smočnicu.", Smocnica.objectId)
        }
        if !has("training") && (style == .aggressive || style == .raider) {
            return ("razmišlja: vojska je prazna, pa gradi trening.", Training.objectId)
        }
        if !has("lager") {
            return ("razmišlja: sirovine stoje vani, pa gradi skladište.", Lager.objectId)
        }
        return ("razmišlja: dvorac drži ritam i za sada ne gradi.", nil)
    }
}

extension GameState {
    /// Dva ili više AI lordova: svakih 12 s jedan kaže što misli i, ako može, to i sagradi.
    func tickAILords() {
        guard aiEnabled, recordThisMatch else { return }
        let lords = computerLords.filter { !$0.isDefeated }
        guard lords.count >= 2, currentTurn > 0, currentTurn % 12 == 0 else { return }
        let lord = lords[(currentTurn / 12) % lords.count]
        let decision = ComputerLordAI(realmId: lord.id, profileId: lord.aiProfileId).think(in: self)
        guard let seat = realmSeats.seats.first(where: { $0.id == lord.id || $0.realmIds.contains(lord.id) }) else { return }
        var text = decision.thought
        var row = Int(seat.castleRow.rounded())
        var col = Int(seat.castleCol.rounded())
        if let objectId = decision.objectId {
            if let spot = placeForAI(objectId: objectId, owner: seat.id, nearRow: row, nearCol: col) {
                let built = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
                text += " Napravio: \(built)."
                row = spot.row
                col = spot.col
            } else {
                text += " Napravio: ništa, nema slobodnog mjesta."
            }
        } else {
            text += " Napravio: čeka."
        }
        MatchHistoryStore.shared.noteThought(from: self, lord: lord.name, text: text, row: row, col: col)
    }

    private func placeForAI(objectId: String, owner: String, nearRow: Int, nearCol: Int) -> (row: Int, col: Int)? {
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
                    guard gameMap.place(objectId: objectId, width: width, height: height, atRow: row, col: col, ownerId: owner) != nil else { continue }
                    notePlacementsChanged()
                    return (row, col)
                }
            }
        }
        return nil
    }
}
