//
//  MatchLog.swift
//  Feudalism
//
//  Tekstualni zapis partije. Kad igra čovjek, partija ide preko mape.
//  Kad igraju samo AI lordovi, ovo je cijeli prikaz – bez 3D sučelja.
//

import Foundation

struct MatchLogLine: Identifiable, Equatable {
    let id: String
    let turn: Int
    let text: String
}

extension GameState {
    /// Čovjek je u partiji → mapa i UI. Samo AI → tekst.
    var hasHumanPlayer: Bool { !humanLords.isEmpty }

    func appendMatchLog(_ text: String) {
        matchLog.append(MatchLogLine(id: UUID().uuidString, turn: currentTurn, text: text))
        if matchLog.count > 400 { matchLog.removeFirst(matchLog.count - 400) }
    }

    func resetMatchLog() {
        matchLog = []
    }

    /// Početak i povremeni sažetak (svakih 10 poteza u tekstualnoj partiji).
    func tickMatchLog() {
        if currentTurn == 1, matchLog.isEmpty {
            let names = realmSeats.seats.map(\.displayName).joined(separator: ", ")
            appendMatchLog("Početak: \(campaign.type.displayName). Dvorci: \(names).")
            if campaign.type == .economic {
                appendMatchLog("Riznica: pobjeda na \(campaign.economicTarget.formatted()) zlatnika.")
            } else {
                appendMatchLog("Vojna: tko je neprijatelj ne mijenja se. Pobjeda kad padnu neprijateljski kraljevi.")
            }
            if !hasHumanPlayer {
                appendMatchLog("Partija je AI protiv AI – bez mape, samo tekst.")
            }
        }
        guard !showsGraphics, currentTurn > 0, currentTurn % 10 == 0 else { return }
        for seat in realmSeats.seats {
            let peopleCount = peopleOf(faction: seat.id).count
            let gold = goodAmount(.gold, of: seat.id)
            let happy = Int(happinessPercent(of: seat.id).rounded())
            let king = seat.kingAlive ? "kralj živ" : "kralj pao"
            var extra = ""
            if campaign.type == .economic {
                extra = " · riznica \(treasuryPaid(by: seat.id).formatted())"
            }
            appendMatchLog("\(seat.displayName): \(peopleCount) ljudi, \(gold) zlata, sreća \(happy) %, \(king)\(extra).")
        }
    }
}
