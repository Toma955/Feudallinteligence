//
//  Campaign.swift
//  Feudalism
//
//  Kampanja partije i odnosi među dvorcima. Rat je uvijek moguć: svaka dva dvorca su na početku neprijatelji.
//  - Vojna kampanja: tko je kome neprijatelj ne mijenja se; pobjeđuješ kad su svi neprijatelji mrtvi (kralj pao).
//  - Ekonomska kampanja: savezi se mogu sklapati i raskidati; pobjeđuješ kad u riznicu uplatiš zadani iznos.
//    Uplata je tajna – nitko ne vidi koliko je drugi uplatio. Može se uplaćivati malo po malo ili odjednom.
//  Pravila su ista za igrača i AI lordove.
//

import Foundation

enum CampaignType: String, Codable, CaseIterable, Identifiable {
    case military
    case economic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .military: return "Vojna kampanja"
        case .economic: return "Ekonomska kampanja"
        }
    }

    var goalText: String {
        switch self {
        case .military: return "Pobjeđuješ kad su svi neprijatelji mrtvi. Tko ti je neprijatelj ne mijenja se."
        case .economic: return "Pobjeđuješ kad u riznicu uplatiš zadani iznos zlata. Uplata je tajna, a savezi se mogu mijenjati."
        }
    }
}

enum FactionRelation: String, Codable, CaseIterable, Identifiable {
    case enemy
    case neutral
    case ally

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enemy: return "Neprijatelj"
        case .neutral: return "Neutralan"
        case .ally: return "Prijatelj"
        }
    }
}

struct CampaignSettings: Codable, Equatable {
    var type: CampaignType
    /// Zlato u riznici za ekonomsku pobjedu.
    var economicTarget: Int

    static let targetOptions = [10_000, 50_000, 100_000, 250_000, 1_000_000]
    static let standard = CampaignSettings(type: .military, economicTarget: 100_000)

    var relationsFixed: Bool { type == .military }
}

struct CampaignResult: Equatable {
    enum Reason: Equatable {
        case enemiesDead
        case treasuryPaid
        case kingDied
    }

    /// Frakcije koje su pobijedile (savez pobjeđuje zajedno).
    let winners: [String]
    let reason: Reason
    let playerWon: Bool

    var title: String { playerWon ? "Pobjeda!" : "Poraz" }

    var detail: String {
        switch reason {
        case .enemiesDead: return playerWon ? "Svi tvoji neprijatelji su mrtvi." : "Neprijatelj je pobio sve svoje protivnike."
        case .treasuryPaid: return playerWon ? "Uplatio si cijeli iznos u riznicu." : "Netko je prvi uplatio cijeli iznos u riznicu."
        case .kingDied: return "Tvoj kralj je pao."
        }
    }
}

extension GameState {
    private static func relationKey(_ a: String, _ b: String) -> String {
        a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    func relation(between a: String, and b: String) -> FactionRelation {
        guard a != b else { return .ally }
        return relations[Self.relationKey(a, b)] ?? .enemy
    }

    func enemies(of faction: String) -> [RealmSeat] {
        realmSeats.seats.filter { $0.id != faction && relation(between: faction, and: $0.id) == .enemy }
    }

    /// Na početku partije su svi dvorci neprijatelji (rat je uvijek moguć).
    func resetRelations() {
        var next: [String: FactionRelation] = [:]
        let ids = realmSeats.seats.map(\.id)
        for (i, a) in ids.enumerated() {
            for b in ids[(i + 1)...] { next[Self.relationKey(a, b)] = .enemy }
        }
        relations = next
        treasury = [:]
        campaignResult = nil
        hadEnemiesAtStart = Dictionary(uniqueKeysWithValues: ids.map { id in (id, ids.contains { $0 != id }) })
    }

    /// Samo u ekonomskoj kampanji. Vraća poruku zašto ne, ili nil kad uspije.
    @discardableResult
    func setRelation(_ relation: FactionRelation, between a: String, and b: String) -> String? {
        if campaign.relationsFixed { return "U vojnoj kampanji se ne mijenja tko je kome neprijatelj." }
        guard a != b, seat(of: a) != nil, seat(of: b) != nil else { return "Nema tog dvorca." }
        relations[Self.relationKey(a, b)] = relation
        return nil
    }

    // MARK: - Riznica (tajna)

    /// Koliko je frakcija uplatila; igrač vidi samo svoje.
    func treasuryPaid(by faction: String) -> Int {
        treasury[faction] ?? 0
    }

    var playerTreasuryPaid: Int {
        playerSeat.map { treasuryPaid(by: $0.id) } ?? 0
    }

    /// Uplati zlato u riznicu (samo ekonomska kampanja). Zlato nestaje iz zaliha.
    @discardableResult
    func depositToTreasury(_ amount: Int, faction: String? = nil) -> String? {
        guard campaign.type == .economic else { return "Riznica postoji samo u ekonomskoj kampanji." }
        guard let id = faction ?? playerSeat?.id else { return "Nema dvorca." }
        let available = goodAmount(.gold, of: id)
        let paid = min(max(0, amount), available)
        guard paid > 0 else { return "Nema zlata za uplatu." }
        addGood(.gold, -paid, to: id)
        treasury[id, default: 0] += paid
        return nil
    }

    // MARK: - Pobjeda

    func checkCampaignVictory() {
        guard !isSandboxPlay else { return }
        guard campaignResult == nil, !realmSeats.seats.isEmpty else { return }
        let player = playerSeat
        if let player, !player.kingAlive {
            finishCampaign(CampaignResult(winners: [], reason: .kingDied, playerWon: false))
            return
        }
        let alive = realmSeats.seats.filter(\.kingAlive)
        switch campaign.type {
        case .military:
            let winners = alive.filter { seat in
                hadEnemiesAtStart[seat.id] == true && enemies(of: seat.id).allSatisfy { !$0.kingAlive }
            }
            guard !winners.isEmpty else { return }
            let ids = winners.map(\.id)
            finishCampaign(CampaignResult(winners: ids, reason: .enemiesDead, playerWon: player.map { ids.contains($0.id) } ?? false))
        case .economic:
            let target = max(1, campaign.economicTarget)
            guard let first = alive.first(where: { treasuryPaid(by: $0.id) >= target }) else { return }
            let ids = [first.id]
            finishCampaign(CampaignResult(winners: ids, reason: .treasuryPaid, playerWon: player.map { ids.contains($0.id) } ?? false))
        }
    }

    private func finishCampaign(_ result: CampaignResult) {
        campaignResult = result
        let names = result.winners.compactMap { seat(of: $0)?.displayName }.joined(separator: ", ")
        appendMatchLog("Kraj: \(result.title). \(result.detail)\(names.isEmpty ? "" : " — \(names)").")
        pauseGame()
    }
}
