//
//  FactionEconomy.swift
//  Feudalism
//
//  Isti zakoni za svaki dvorac, vodio ga čovjek ili AI: svaka frakcija ima svoje građevine,
//  svoje zalihe, skladišta, ljude, hranu i sreću. Igračeve zalihe ostaju u `resources`/`food`/`goods`
//  (njih čita HUD), zalihe ostalih frakcija su u `factionStocks`.
//

import Foundation

extension GameState {
    func seat(of faction: String) -> RealmSeat? {
        realmSeats.seats.first { $0.id == faction }
    }

    private func isPlayerStock(_ faction: String) -> Bool {
        hasHumanPlayer && faction == playerSeat?.id
    }

    // MARK: - Vlasništvo

    /// Vlasnik građevine. Građevina iz map editora (bez vlasnika) pripada najbližem živom dvorcu.
    func owner(of placement: Placement) -> String? {
        if let id = placement.ownerId { return id }
        let row = Double(placement.row) + Double(placement.height) / 2
        let col = Double(placement.col) + Double(placement.width) / 2
        return realmSeats.seats
            .filter(\.kingAlive)
            .min { hypot($0.castleRow - row, $0.castleCol - col) < hypot($1.castleRow - row, $1.castleCol - col) }?
            .id
    }

    func isOwnedByPlayer(_ placement: Placement) -> Bool {
        guard let player = playerSeat?.id else { return false }
        return owner(of: placement) == player
    }

    // MARK: - Zalihe po frakciji

    func goodAmount(_ good: Good, of faction: String) -> Int {
        isPlayerStock(faction) ? goodAmount(good) : factionStocks[faction]?[good] ?? 0
    }

    func addGood(_ good: Good, _ amount: Int, to faction: String, tracksArrival: Bool = true) {
        guard amount != 0 else { return }
        if isPlayerStock(faction) {
            addGood(good, amount, tracksArrival: tracksArrival)
        } else {
            let before = tracksArrival && FoodRules.isStockFood(good) ? goodAmount(good, of: faction) : 0
            let put: Int = amount > 0 && good != .gold ? unitsThatFit(good, adding: amount, faction: faction) : amount
            guard put != 0 else { return }
            factionStocks[faction, default: [:]][good] = max(0, goodAmount(good, of: faction) + put)
            if tracksArrival, FoodRules.isStockFood(good) {
                recordFoodArrival(good, goodAmount(good, of: faction) - before, faction: faction)
            }
            if good != .gold {
                warehouseGoodsEpoch &+= 1
                DispatchQueue.main.async { [weak self] in
                    self?.syncLagerBays(of: faction)
                }
            }
        }
    }

    /// Na početku partije svaka frakcija dobiva zlato. Ostalo samo ako ima skladište i slobodno polje.
    func seedFactionStocks() {
        applyPendingStartGoods()
        let desired: [Good: Int]
        if hasHumanPlayer {
            desired = Dictionary(uniqueKeysWithValues: Good.allCases.map { ($0, goodAmount($0)) })
        } else {
            let file = StartingResourcesLoader.startingResources()
            desired = [
                .gold: file.gold, .wood: file.wood, .iron: file.iron, .stone: file.stone,
                .food: file.food, .hop: file.hop, .hay: file.hay
            ]
        }
        for seat in realmSeats.seats where !isPlayerStock(seat.id) {
            factionStocks[seat.id] = [:]
            for good in Good.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
                let amount = desired[good] ?? 0
                guard amount > 0 else { continue }
                if good == .gold || lagerHasRoom(for: good, faction: seat.id) {
                    addGood(good, amount, to: seat.id)
                }
            }
        }
    }

    // MARK: - Cijene po frakciji

    func canAfford(_ price: Price, faction: String) -> Bool {
        price.items.allSatisfy { goodAmount($0.key, of: faction) >= $0.value }
    }

    func pay(_ price: Price, faction: String) {
        for (good, amount) in price.items { addGood(good, -amount, to: faction) }
    }

    func missing(for price: Price, faction: String) -> String? {
        let short = price.sortedItems.compactMap { item -> String? in
            let lack = item.amount - goodAmount(item.good, of: faction)
            return lack > 0 ? "\(lack) \(item.good.displayName)" : nil
        }
        return short.isEmpty ? nil : short.joined(separator: ", ")
    }
}

extension ResourceAmountPerTick {
    var goods: [Good: Int] {
        let all: [Good: Int] = [.stone: stone, .wood: wood, .iron: iron, .hop: hop, .beer: beer, .gold: gold]
        return all.filter { $0.value > 0 }
    }
}
