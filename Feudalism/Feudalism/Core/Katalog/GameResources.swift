//
//  GameResources.swift
//  Feudalism
//
//  Glavni izvor istine za resurse u igri. Svi koji daju, prodaju ili troše resurse
//  (gradnja, farme, industrija, tržnica) koriste isključivo ovaj modul.
//

import Foundation
import SwiftUI

/// Jedini izvor istine za stanje resursa (stockpile): kamen, drvo, željezo, hmelj, pivo, novac.
/// Proizvođači dodaju ovdje, transformeri (pivovara) i konzumenti (krčma, hotel) uzimaju odavde.
final class GameResources: ObservableObject {
    @Published private(set) var stone: Int = 0
    @Published private(set) var wood: Int = 0
    @Published private(set) var iron: Int = 0
    @Published private(set) var hop: Int = 0
    @Published private(set) var beer: Int = 0
    @Published private(set) var gold: Int = 0

    /// Trenutno stanje kao ResourceStock (za provjere i oduzimanje prema BuildCost).
    var stock: ResourceStock {
        ResourceStock(stone: stone, wood: wood, iron: iron)
    }

    /// Ima li dovoljno resursa za zadanu potrošnju (npr. pivovara treba 1 hmelj, krčma 1 pivo)?
    func canAfford(consumption: ResourceAmountPerTick) -> Bool {
        stone >= consumption.stone && wood >= consumption.wood && iron >= consumption.iron
            && hop >= consumption.hop && beer >= consumption.beer
    }

    // MARK: - Čitanje

    /// Može li se priuštiti zadani trošak?
    func canAfford(_ cost: BuildCost) -> Bool {
        stock.canAfford(cost: cost)
    }

    /// Može li se priuštiti izgradnja objekta (prema BuildCosts katalogu)?
    func canAfford(objectId: String) -> Bool {
        let cost = BuildCosts.shared.cost(for: objectId)
        return canAfford(cost)
    }

    // MARK: - Trošenje (gradnja, prodaja, potrošnja)

    /// Oduzmi trošak izgradnje. Pozivati samo ako canAfford(cost) vraća true.
    func subtract(_ cost: BuildCost) {
        stone = max(0, stone - cost.stone)
        wood = max(0, wood - cost.wood)
        iron = max(0, iron - cost.iron)
    }

    /// Oduzmi resurse za objekt (prema BuildCosts). Vraća true ako je oduzeto.
    func subtractForBuilding(objectId: String) -> Bool {
        let cost = BuildCosts.shared.cost(for: objectId)
        guard canAfford(cost) else { return false }
        subtract(cost)
        return true
    }

    /// Oduzmi proizvoljne količine (npr. prodaja, potrošnja). Ne dopušta negativne vrijednosti.
    func subtract(stone s: Int = 0, wood w: Int = 0, iron i: Int = 0, hop h: Int = 0, beer b: Int = 0, gold g: Int = 0) {
        stone = max(0, stone - s)
        wood = max(0, wood - w)
        iron = max(0, iron - i)
        hop = max(0, hop - h)
        beer = max(0, beer - b)
        gold = max(0, gold - g)
    }

    /// Oduzmi prema ResourceAmountPerTick (potrošnja: hmelj, pivo, itd.).
    func subtract(_ consumption: ResourceAmountPerTick) {
        subtract(stone: consumption.stone, wood: consumption.wood, iron: consumption.iron, hop: consumption.hop, beer: consumption.beer)
    }

    // MARK: - Dodavanje (farme, industrija, stockpile)

    /// Dodaj resurse (proizvodnja ili output transformera ide na stockpile).
    func add(stone s: Int = 0, wood w: Int = 0, iron i: Int = 0, hop h: Int = 0, beer b: Int = 0, gold g: Int = 0) {
        stone += s
        wood += w
        iron += i
        hop += h
        beer += b
        gold += g
    }

    /// Dodaj prema ResourceAmountPerTick (proizvodnja: kamen, drvo, hmelj, pivo, zlato).
    func add(_ production: ResourceAmountPerTick) {
        add(stone: production.stone, wood: production.wood, iron: production.iron, hop: production.hop, beer: production.beer, gold: production.gold)
    }

    /// Postavi zalihu na točne vrijednosti (nova igra, učitavanje savea).
    func setStock(stone s: Int, wood w: Int, iron i: Int, hop h: Int = 0, beer b: Int = 0, gold g: Int = 0) {
        stone = max(0, s)
        wood = max(0, w)
        iron = max(0, i)
        hop = max(0, h)
        beer = max(0, b)
        gold = max(0, g)
    }

    /// Postavi na nulu (reset na početak igre).
    func reset() {
        setStock(stone: 0, wood: 0, iron: 0, hop: 0, beer: 0, gold: 0)
    }

    // MARK: - Solo: jedina istina za početak

    /// Reset za novu igru (solo): resursi i novac na nulu. Gornji traka čita odavde.
    func resetForNewSoloGame() {
        setStock(stone: 0, wood: 0, iron: 0, hop: 0, beer: 0, gold: 0)
    }
}
