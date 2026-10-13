//
//  FoodConsumption.swift
//  Feudalism
//
//  Hrana se troši tek kad frakcija ima smočnicu i barem jednu mjeru hrane.
//  Svakih 60 s (jedno godišnje doba) ode točno jedna mjera, prva koja je ušla (FIFO).
//  Jabuke, sir i ostalo su ista mjera; redoslijed ulaska određuje što izlazi.
//  Glad spušta sreću (Happiness.swift). Pravila su ista za igrača i AI lordove.
//

import Foundation

enum FoodRules {
    /// Jedna mjera hrane po ovom broju poteza. Grafika: 1 potez = 1 s, dakle 60 s.
    static let ticksPerMeal = Season.turnsPerSeason
    /// Jedna mjera po obroku, ne po osobi. Ostaje u pravilniku AI-a.
    static let portionPerPerson = 1
    /// Sva hrana u smočnici i roba „hrana”, stabilan redoslijed samo za zalihu koja je već bila tu.
    static var stockFood: [Good] {
        StorageKind.pantry.goods.sorted { $0.rawValue < $1.rawValue } + [.food]
    }

    static func isStockFood(_ good: Good) -> Bool {
        good == .food || StorageKind.pantry.goods.contains(good)
    }

    static var edible: [Good] { stockFood }
}

extension GameState {
    func population(of faction: String) -> Int {
        peopleOf(faction: faction).count
    }

    var playerPopulation: Int {
        playerSeat.map { population(of: $0.id) } ?? 0
    }

    /// 1 dok smočnica postoji (tada se jedna mjera traži), inače 0 i hrana se ne dira.
    func mealSize(of faction: String) -> Int {
        liveCount(Smocnica.objectId, of: faction) > 0 ? 1 : 0
    }

    var mealSize: Int { playerSeat.map { mealSize(of: $0.id) } ?? 0 }

    var edibleFood: Int { playerSeat.map { edibleFood(of: $0.id) } ?? 0 }

    var playerFoodShortfall: Int { playerSeat.flatMap { foodShortfall[$0.id] } ?? 0 }

    func edibleFood(of faction: String) -> Int {
        FoodRules.stockFood.reduce(0) { $0 + goodAmount($1, of: faction) }
    }

    /// Zaliha koja je ušla prije nego što se red pratio ide na početak, u stabilnom redu vrsta.
    func alignFoodQueue(for faction: String) {
        var queue = foodArrival[faction] ?? []
        var counts: [Good: Int] = [:]
        for good in FoodRules.stockFood {
            let amount = goodAmount(good, of: faction)
            if amount > 0 { counts[good] = amount }
        }
        var queued: [Good: Int] = [:]
        for good in queue { queued[good, default: 0] += 1 }
        var changed = false
        for good in FoodRules.stockFood {
            let extra = (queued[good] ?? 0) - (counts[good] ?? 0)
            guard extra > 0 else { continue }
            var left = extra
            queue = queue.filter { item in
                if item == good, left > 0 {
                    left -= 1
                    return false
                }
                return true
            }
            queued[good] = counts[good] ?? 0
            changed = true
        }
        var older: [Good] = []
        for good in FoodRules.stockFood {
            let missing = (counts[good] ?? 0) - (queued[good] ?? 0)
            if missing > 0 { older.append(contentsOf: repeatElement(good, count: missing)) }
        }
        if !older.isEmpty { changed = true }
        if changed { foodArrival[faction] = older + queue }
    }

    /// Upis ulaska i izlaska jedne vrste. Jelo po FIFO-u zove oduzimanje s tracksArrival: false.
    func recordFoodArrival(_ good: Good, _ amount: Int, faction: String) {
        guard FoodRules.isStockFood(good), amount != 0 else { return }
        var queue = foodArrival[faction] ?? []
        if amount > 0 {
            queue.append(contentsOf: repeatElement(good, count: amount))
        } else {
            var left = -amount
            queue = queue.filter { item in
                if item == good, left > 0 {
                    left -= 1
                    return false
                }
                return true
            }
        }
        foodArrival[faction] = queue
    }

    /// Jedna mjera, prva u redu. Vraća 1 kad obrok nije pojeden (nema smočnice ili nema hrane).
    private func eatOne(_ seat: RealmSeat) -> Int {
        guard liveCount(Smocnica.objectId, of: seat.id) > 0 else { return 1 }
        alignFoodQueue(for: seat.id)
        guard var queue = foodArrival[seat.id], !queue.isEmpty else { return 1 }
        let good = queue.removeFirst()
        foodArrival[seat.id] = queue
        addGood(good, -1, to: seat.id, tracksArrival: false)
        return 0
    }

    func tickFood() {
        guard currentTurn > 0, currentTurn % FoodRules.ticksPerMeal == 0 else { return }
        var shortfall: [String: Int] = [:]
        for seat in realmSeats.seats where seat.kingAlive {
            shortfall[seat.id] = eatOne(seat)
        }
        if foodShortfall != shortfall { foodShortfall = shortfall }
    }
}
