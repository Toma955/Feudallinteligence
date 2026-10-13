//
//  WorkCycles.swift
//  Feudalism
//
//  Radna mjesta: objekti hrane, resursa, farmi i oružja (mač, štit, luk, koplje, koža).
//  Rade samo kad je radnik unutra; svaki ciklus uzme ulaz (ako ga ima) i donese proizvod.
//  Brzina ciklusa ovisi prvenstveno o godišnjem dobu.
//  Farme i industrija proizvode sirovine; ostali ih uzimaju i rade proizvode
//  (kuća mača: željezo → mač, luk i koplje: drvo; mlin: sijeno → brašno → pekara → kruh).
//  Svaki proizvod ide u svoje skladište (StorageKind): oružje u oružarnicu (60), hrana u smočnicu (396), konji u štalu (5),
//  sirovine i međuproizvodi u skladište (400). Sirovine se uzimaju iz skladišta; kad je puno, radnik čeka.
//

import Foundation

/// Roba na zalihi. Kamen, drvo, željezo, hmelj, pivo i zlato idu u GameResources, hrana u GameState.food,
/// ostalo u GameState.goods.
enum Good: String, CaseIterable, Codable {
    case stone, wood, iron, hop, beer, gold, food
    case wheat, flour, bread, corn, eggs, apple, spirits, wine
    case honey, wax, candle
    case vegetables, grapes, spices, flowers
    case meat, sausages, milk, cheese, wool, hay
    case sword, shield, bow, spear, leather
    case horse

    var displayName: String {
        switch self {
        case .stone: return "kamen"
        case .wood: return "drvo"
        case .iron: return "željezo"
        case .hop: return "hmelj"
        case .beer: return "pivo"
        case .gold: return "zlato"
        case .food: return "hrana"
        case .wheat: return "pšenica"
        case .flour: return "vreće brašna"
        case .bread: return "kruh"
        case .corn: return "kukuruz"
        case .eggs: return "jaja"
        case .apple: return "jabuke"
        case .spirits: return "rakija"
        case .wine: return "vino"
        case .honey: return "med"
        case .wax: return "vosak"
        case .candle: return "svijeća"
        case .vegetables: return "povrće"
        case .grapes: return "grožđe"
        case .spices: return "začini"
        case .flowers: return "cvijeće"
        case .meat: return "meso"
        case .sausages: return "kobasice"
        case .milk: return "mlijeko"
        case .cheese: return "sir"
        case .wool: return "vuna"
        case .hay: return "sijeno"
        case .sword: return "mač"
        case .shield: return "štit"
        case .bow: return "luk"
        case .spear: return "koplje"
        case .leather: return "koža"
        case .horse: return "konj"
        }
    }
}

/// Vrsta rada – određuje kako godišnje doba utječe na brzinu.
enum WorkKind: String, Codable {
    /// Polja (pšenica, kukuruz, hmelj): zimi stoje, jesen je žetva.
    case field
    /// Životinje (kokoši): zimi sporije.
    case animal
    /// Prerada hrane (mlin, pekara, pivovara…).
    case food
    /// Rudnici, kamenolom, drvosječa: zimi sporije.
    case resource
    /// Radionice oružja i kože.
    case weapon

    /// Koliko ciklusa napreduje po potezu (1 = puna brzina, 0 = stoji).
    func seasonFactor(_ season: Season) -> Double {
        switch (self, season) {
        case (.field, .winter): return 0
        case (.field, .spring): return 0.5
        case (.field, .summer): return 1
        case (.field, .autumn): return 1.5
        case (.animal, .winter): return 0.5
        case (.animal, .autumn): return 0.8
        case (.animal, _): return 1
        case (.food, .winter): return 0.8
        case (.food, .autumn): return 1.2
        case (.food, _): return 1
        case (.resource, .winter): return 0.5
        case (.resource, .summer): return 1
        case (.resource, _): return 0.9
        case (.weapon, .winter): return 0.9
        case (.weapon, _): return 1
        }
    }
}

struct WorkCycle {
    let kind: WorkKind
    /// Potezi jednog ciklusa pri punoj brzini.
    let durationTicks: Int
    let inputs: [Good: Int]
    let outputs: [Good: Int]
}

enum WorkCycleCatalog {
    /// nil = objekt nije radno mjesto (nema radnika ni ciklusa). production.json ima prednost.
    static func cycle(for objectId: String) -> WorkCycle? {
        ProductionConfig.cycles[objectId] ?? builtIn(objectId)
    }

    private static func builtIn(_ objectId: String) -> WorkCycle? {
        switch objectId {
        // Farme
        case Farm.objectId: return WorkCycle(kind: .field, durationTicks: 20, inputs: [:], outputs: [.wheat: 3, .hay: 1])
        case Corn.objectId: return WorkCycle(kind: .field, durationTicks: 20, inputs: [:], outputs: [.corn: 3])
        case Hop.objectId: return WorkCycle(kind: .field, durationTicks: 20, inputs: [:], outputs: [.hop: 2])
        case Vegetables.objectId: return WorkCycle(kind: .field, durationTicks: 18, inputs: [:], outputs: [.vegetables: 3])
        case Grapes.objectId: return WorkCycle(kind: .field, durationTicks: 22, inputs: [:], outputs: [.grapes: 3])
        case Spices.objectId: return WorkCycle(kind: .field, durationTicks: 24, inputs: [:], outputs: [.spices: 2])
        case Flower.objectId: return WorkCycle(kind: .field, durationTicks: 16, inputs: [:], outputs: [.flowers: 2])
        case AppleOrchard.objectId: return WorkCycle(kind: .field, durationTicks: 22, inputs: [:], outputs: [.food: 1])
        case Chicken.objectId: return WorkCycle(kind: .animal, durationTicks: 15, inputs: [:], outputs: [.eggs: 2])
        case Hive.objectId: return WorkCycle(kind: .animal, durationTicks: 20, inputs: [:], outputs: [.honey: 2, .wax: 1])
        case Pig.objectId: return WorkCycle(kind: .animal, durationTicks: 22, inputs: [:], outputs: [.meat: 2, .sausages: 1])
        case Cow.objectId: return WorkCycle(kind: .animal, durationTicks: 20, inputs: [:], outputs: [.milk: 2, .cheese: 1, .leather: 1])
        case Sheep.objectId: return WorkCycle(kind: .animal, durationTicks: 18, inputs: [:], outputs: [.wool: 2, .milk: 1])
        // Hrana
        case Food.objectId: return WorkCycle(kind: .food, durationTicks: 12, inputs: [:], outputs: [.food: 2])
        case Windmill.objectId: return WorkCycle(kind: .food, durationTicks: 10, inputs: [.hay: 2], outputs: [.flour: 2])
        case Bakery.objectId: return WorkCycle(kind: .food, durationTicks: 12, inputs: [.flour: 2], outputs: [.bread: 6])
        case Granary.objectId: return WorkCycle(kind: .food, durationTicks: 15, inputs: [.wheat: 3], outputs: [.food: 3])
        case Brewery.objectId: return WorkCycle(kind: .food, durationTicks: 10, inputs: [.hop: 2], outputs: [.beer: 2])
        case Distillery.objectId: return WorkCycle(kind: .food, durationTicks: 20, inputs: [.corn: 2], outputs: [.spirits: 1])
        case WineCellar.objectId: return WorkCycle(kind: .food, durationTicks: 30, inputs: [.grapes: 2], outputs: [.wine: 1])
        case Tavern.objectId: return WorkCycle(kind: .food, durationTicks: 6, inputs: [.beer: 1], outputs: [.gold: 2])
        case Canteen.objectId: return WorkCycle(kind: .food, durationTicks: 12, inputs: [.corn: 2, .eggs: 1], outputs: [.food: 5])
        case CandleShop.objectId: return WorkCycle(kind: .food, durationTicks: 10, inputs: [.wax: 1], outputs: [.candle: 2])
        // Resursi
        case Iron.objectId: return WorkCycle(kind: .resource, durationTicks: 12, inputs: [:], outputs: [.iron: 2])
        case Stone.objectId: return WorkCycle(kind: .resource, durationTicks: 10, inputs: [:], outputs: [.stone: 3])
        case Wood.objectId: return WorkCycle(kind: .resource, durationTicks: 8, inputs: [:], outputs: [.wood: 3])
        case Market.objectId: return WorkCycle(kind: .resource, durationTicks: 40, inputs: [:], outputs: [:])
        // Oružje
        case Sword.objectId: return WorkCycle(kind: .weapon, durationTicks: 20, inputs: [.iron: 1], outputs: [.sword: 1])
        case Shield.objectId: return WorkCycle(kind: .weapon, durationTicks: 18, inputs: [.wood: 2], outputs: [.shield: 1])
        case Bow.objectId: return WorkCycle(kind: .weapon, durationTicks: 15, inputs: [.wood: 1], outputs: [.bow: 1])
        case Spear.objectId: return WorkCycle(kind: .weapon, durationTicks: 12, inputs: [.wood: 1], outputs: [.spear: 1])
        case Leather.objectId: return WorkCycle(kind: .weapon, durationTicks: 20, inputs: [:], outputs: [.leather: 1])
        // Štala: štalar uzgaja konje i drži ih u njoj
        case Stable.objectId: return WorkCycle(kind: .animal, durationTicks: 40, inputs: [:], outputs: [.horse: 1])
        default: return nil
        }
    }

    static func isWorkplace(_ objectId: String) -> Bool { cycle(for: objectId) != nil }
}
