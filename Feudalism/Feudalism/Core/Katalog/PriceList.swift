//
//  PriceList.swift
//  Feudalism
//
//  Cjenik: fiksna cijena izgradnje svake građevine i obuke vojnika. Vrijedi jednako za sve
//  (igrača i AI lordove). Cijena je bilo koja roba sa zalihe: kamen, drvo (daske), željezo, zlato…
//  Map Editor ne naplaćuje.
//

import Foundation

struct Price: Equatable {
    var items: [Good: Int]

    static let free = Price(items: [:])

    init(items: [Good: Int]) {
        self.items = items.filter { $0.value > 0 }
    }

    init(stone: Int = 0, wood: Int = 0, iron: Int = 0, gold: Int = 0) {
        self.init(items: [.stone: stone, .wood: wood, .iron: iron, .gold: gold])
    }

    var isFree: Bool { items.isEmpty }

    /// Redoslijed prikaza: kamen, drvo, željezo, zlato, pa ostalo.
    var sortedItems: [(good: Good, amount: Int)] {
        let order: [Good] = [.stone, .wood, .iron, .gold]
        return items.map { ($0.key, $0.value) }.sorted { a, b in
            let ia = order.firstIndex(of: a.0) ?? order.count
            let ib = order.firstIndex(of: b.0) ?? order.count
            return ia != ib ? ia < ib : a.0.rawValue < b.0.rawValue
        }
    }

    /// Npr. "10 drvo + 10 zlato"; "besplatno" kad nema cijene.
    var description: String {
        isFree ? "besplatno" : sortedItems.map { "\($0.amount) \($0.good.displayName)" }.joined(separator: " + ")
    }
}

enum PriceList {
    /// Cijena izgradnje po objectId. Zid se plaća po kocki.
    /// Za sada su sve cijene 0 – cjenik postoji, iznosi se dopunjuju kasnije.
    static func price(for objectId: String) -> Price {
        switch objectId {
        // Dvor
        case HugeWall.objectId, SmallWall.objectId, Steps.objectId: return Price(stone: 0)
        case Gates.objectId: return Price(stone: 0, wood: 0)
        case Castle.objectId: return Price(stone: 0, wood: 0, gold: 0)
        case Market.objectId: return Price(wood: 0, gold: 0)
        case Stable.objectId: return Price(wood: 0, gold: 0)
        case Miners.objectId: return Price(wood: 0, gold: 0)
        case Engineering.objectId: return Price(wood: 0, iron: 0, gold: 0)
        // Kuća
        case House.objectId: return Price(wood: 0, gold: 0)
        case Well.objectId: return Price(stone: 0, wood: 0)
        case Spring.objectId: return Price(stone: 0)
        case Hotel.objectId: return Price(stone: 0, wood: 0, gold: 0)
        case Church.objectId: return Price(stone: 0, wood: 0, gold: 0)
        case Pharmacy.objectId: return Price(wood: 0, gold: 0)
        case Greenhouse.objectId: return Price(stone: 0, wood: 0, gold: 0)
        case Diplomacy.objectId: return Price(stone: 0, gold: 0)
        // Farme
        case Farm.objectId, Hop.objectId, Vegetables.objectId, Grapes.objectId, Spices.objectId, Flower.objectId, AppleOrchard.objectId: return Price(wood: 0)
        case Corn.objectId: return Price(wood: 0)
        case Chicken.objectId, Pig.objectId, Cow.objectId, Sheep.objectId: return Price(wood: 0, gold: 0)
        case Hive.objectId: return Price(wood: 0)
        // Hrana
        case Food.objectId: return Price(wood: 0)
        case Windmill.objectId: return Price(stone: 0, wood: 0)
        case Bakery.objectId: return Price(stone: 0, wood: 0)
        case Granary.objectId: return Price(wood: 0)
        case Brewery.objectId: return Price(wood: 0, gold: 0)
        case Distillery.objectId: return Price(wood: 0, iron: 0, gold: 0)
        case WineCellar.objectId: return Price(stone: 0, wood: 0)
        case Tavern.objectId: return Price(wood: 0, gold: 0)
        case Smocnica.objectId: return Price(wood: 0)
        case Canteen.objectId: return Price(wood: 0, gold: 0)
        case CandleShop.objectId: return Price(wood: 0)
        // Industrija
        case Wood.objectId: return Price(gold: 0)
        case Stone.objectId, SmallRock.objectId, MediumRock.objectId, LargeRock.objectId: return Price(wood: 0)
        case Iron.objectId: return Price(wood: 0)
        case Lager.objectId: return Price(wood: 0)
        case Carriage.objectId: return Price(wood: 0, iron: 0)
        case Industry.objectId: return Price(wood: 0)
        // Oružje
        case Sword.objectId, Shield.objectId: return Price(wood: 0, gold: 0)
        case Bow.objectId, Spear.objectId: return Price(wood: 0)
        case Leather.objectId: return Price(wood: 0, gold: 0)
        case Training.objectId: return Price(wood: 0, gold: 0)
        case Armory.objectId: return Price(stone: 0, wood: 0)
        // Podzemlje
        case UndergroundEntrance.objectId, UndergroundCorridor.objectId: return Price(stone: 0, wood: 0)
        case Road.objectId, StoneSlab.objectId: return Price(stone: 0)
        case Bridge.objectId, Tunnel.objectId: return Price(stone: 0, wood: 0)
        case Flag.objectId, Torch.objectId, Candle.objectId: return Price(wood: 0)
        case Monument.objectId, Fountain.objectId: return Price(stone: 0)
        case OrnamentalTree.objectId: return Price(wood: 0)
        case Roof.objectId: return Price(wood: 0)
        default: return .free
        }
    }

    /// Obuka vojnika: oprema iz oružarnice + zlato (vidi SoldierType). Osoba se ne plaća – uzima se slobodni seljak.
    static func soldierPrice(_ type: SoldierType) -> Price {
        Price(items: type.equipment.merging([.gold: type.gold]) { $0 + $1 })
    }
}

extension GameState {
    func canAfford(_ price: Price) -> Bool {
        price.items.allSatisfy { goodAmount($0.key) >= $0.value }
    }

    /// Što nedostaje, npr. "5 kamen, 10 zlato"; nil kad se može platiti.
    func missing(for price: Price) -> String? {
        let short = price.sortedItems.compactMap { item -> String? in
            let lack = item.amount - goodAmount(item.good)
            return lack > 0 ? "\(lack) \(item.good.displayName)" : nil
        }
        return short.isEmpty ? nil : short.joined(separator: ", ")
    }

    func pay(_ price: Price) {
        for (good, amount) in price.items { addGood(good, -amount) }
    }
}
