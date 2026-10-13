//
//  Happiness.swift
//  Feudalism
//
//  Sreća frakcije (0–100 %), ista pravila za igrača i AI lordove. Na početku je 100 %.
//  Svakih 60 s treba otići jedna mjera hrane. Ako obrok izostane, sreća polako ide prema 0.
//  Ako smočnice nema (nije sagrađena ili je srušena), sreća pada brzo.
//  Ispod 50 %, kad je dvorac pun, ljudi napuštaju. Dok ima mjesta (10 + 10 po kući), novi i dalje dolaze.
//  Visoka sreća je rezerva: dopušta podizanje poreza, a da ljudi ne odu.
//

import Foundation

enum HappinessRules {
    /// Fiksno: svaka partija počinje sa 100 % za sve dvorce. Nije u postavkama ni u JSON-u.
    static let start: Double = 100
    /// Ispod ovoga ljudi odlaze, a novi ne dolaze.
    static let leaveBelow: Double = 50
    /// Kad zadnji obrok nije pojeden: toliko postotnih poena po godišnjem dobu (60 s).
    static let stepPerMeal: Double = 10
    /// Bez smočnice: postotnih poena u sekundi. Od 100 do 0 za 50 s.
    static let stepWithoutPantry: Double = 2
    /// Stari iznos kazne; pravilnik AI-a ga i dalje čita. Pad sreće vode koraci iznad.
    static let hungerPenalty: Double = 60
    /// Kazna po razini poreza.
    static let taxPenaltyPerLevel: Double = 10
    static let maxTaxLevel = 5
    /// Dok je sreća niska, svakih toliko poteza jedna osoba ode.
    static let leaveEveryTicks = 10
    /// Koliko ćelija od vatre osoba hoda prije nego nestane.
    static let leaveDistance: Double = 18
}

extension GameState {
    func resetHappinessForNewMatch() {
        happiness = Dictionary(uniqueKeysWithValues: realmSeats.seats.map { ($0.id, HappinessRules.start) })
    }

    func happinessPercent(of faction: String) -> Double {
        happiness[faction] ?? HappinessRules.start
    }

    var playerHappiness: Double {
        playerSeat.map { happinessPercent(of: $0.id) } ?? HappinessRules.start
    }

    func taxLevel(of faction: String) -> Int {
        taxLevels[faction] ?? 0
    }

    func setTaxLevel(_ level: Int, faction: String) {
        taxLevels[faction] = min(max(0, level), HappinessRules.maxTaxLevel)
    }

    /// 0 dok nema smočnice ili zadnji obrok nije pojeden. Inače 100 umanjeno za porez.
    func happinessTarget(of faction: String) -> Double {
        if liveCount(Smocnica.objectId, of: faction) == 0 { return 0 }
        if (foodShortfall[faction] ?? 0) > 0 { return 0 }
        let tax = Double(taxLevel(of: faction)) * HappinessRules.taxPenaltyPerLevel
        return min(100, max(0, HappinessRules.start - tax))
    }

    /// Brzi korak bez smočnice, inače 10 poena raspoređenih na 60 s.
    func happinessStep(of faction: String) -> Double {
        if liveCount(Smocnica.objectId, of: faction) == 0 {
            return HappinessRules.stepWithoutPantry
        }
        return HappinessRules.stepPerMeal / Double(FoodRules.ticksPerMeal)
    }

    func updateHappinessAfterMeal(faction: String) {
        let current = happinessPercent(of: faction)
        let target = happinessTarget(of: faction)
        let step = min(happinessStep(of: faction), abs(target - current))
        let moved = current + (target > current ? step : -step)
        happiness[faction] = min(100, max(0, moved))
    }

    /// Svake sekunde sreća ide prema cilju, pa se broj na traci miče i između obroka.
    func tickHappiness() {
        var next = happiness
        var changed = false
        for seat in realmSeats.seats where seat.kingAlive {
            let target = happinessTarget(of: seat.id)
            let step = happinessStep(of: seat.id)
            let current = next[seat.id] ?? HappinessRules.start
            if abs(target - current) <= 0.05 {
                if next[seat.id] == nil {
                    next[seat.id] = HappinessRules.start
                    changed = true
                }
                continue
            }
            let delta = min(step, abs(target - current))
            let moved = current + (target > current ? delta : -delta)
            next[seat.id] = min(100, max(0, (moved * 10).rounded() / 10))
            changed = true
        }
        if changed { happiness = next }
    }

    /// Nesretna frakcija gubi jednu osobu (seljak prvi, pa radnik). Ritam vodi `tickPopulationFlow`.
    func sendAwayOne(from seat: RealmSeat) {
        let present = peopleOf(faction: seat.id)
        guard let person = present.first(where: { $0.role == .peasant })
                ?? present.first(where: { $0.role == .worker }) else { return }
        if let job = person.activity.jobPlacementId {
            releaseWorker(of: job)
            buildingStates[job]?.worker = .none
        }
        let hearth = hearthCell(of: seat)
        let angle = atan2(person.col - hearth.col, person.row - hearth.row)
        let row = min(max(1, hearth.row + cos(angle) * HappinessRules.leaveDistance), Double(gameMap.rows - 2))
        let col = min(max(1, hearth.col + sin(angle) * HappinessRules.leaveDistance), Double(gameMap.cols - 2))
        people.update(id: person.id) {
            $0.role = .peasant
            $0.activity = .leaving
            $0.targetRow = row
            $0.targetCol = col
            $0.targetLayer = .surface
        }
        refreshPeopleCount()
    }
}
