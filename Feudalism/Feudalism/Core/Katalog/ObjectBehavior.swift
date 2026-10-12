//
//  ObjectBehavior.swift
//  Feudalism
//
//  Jedan izvor istine za mehaniku objekta: zdravlje (HP), zapaljivost, trošak izgradnje, proizvodnja.
//

import Foundation

/// Količine resursa po ticku (proizvodnja ili potrošnja): kamen, drvo, željezo, hmelj, pivo; proizvodnja može uključivati i zlato.
struct ResourceAmountPerTick: Equatable {
    var stone: Int
    var wood: Int
    var iron: Int
    var hop: Int
    var beer: Int
    /// Zlato kao output (npr. krčma/hotel prodaju pivo → zlato).
    var gold: Int

    static let zero = ResourceAmountPerTick(stone: 0, wood: 0, iron: 0, hop: 0, beer: 0, gold: 0)

    init(stone: Int = 0, wood: Int = 0, iron: Int = 0, hop: Int = 0, beer: Int = 0, gold: Int = 0) {
        self.stone = stone
        self.wood = wood
        self.iron = iron
        self.hop = hop
        self.beer = beer
        self.gold = gold
    }

    var hasAny: Bool { stone > 0 || wood > 0 || iron > 0 || hop > 0 || beer > 0 || gold > 0 }
    /// Ima li proizvodnju (za backward compatibility).
    var hasProduction: Bool { hasAny }
    /// Ima li potrošnju (input – bez zlata).
    var hasConsumption: Bool { stone > 0 || wood > 0 || iron > 0 || hop > 0 || beer > 0 }
}

/// Zadržano za kompatibilnost; koristi ResourceAmountPerTick.
typealias ProductionPerTick = ResourceAmountPerTick

/// Ponašanje objekta u igri: HP, zapaljivost, trošak izgradnje, proizvodnja i potrošnja po ticku.
struct ObjectBehavior: Equatable {
    /// Broj levela za max HP (npr. 10).
    var healthLevels: Int
    /// HP po levelu (npr. 10 → max 100).
    var hpPerLevel: Int
    /// Može li objekt gorjeti.
    var isFlammable: Bool
    /// Koliko HP vatra oduzima po ticku; koristi se samo ako je isFlammable true.
    var fireDamagePerTick: Int
    /// Trošak izgradnje (kamen, drvo, željezo).
    var buildCost: BuildCost
    /// Što objekt proizvodi po ticku (npr. rudnik +1 iron, pivovara +pivo nakon N tickova).
    var productionPerTick: ResourceAmountPerTick
    /// Što objekt primka/konzumira po ticku (npr. pivovara hmelj → pivo).
    var consumptionPerTick: ResourceAmountPerTick
    /// Broj tickova do završetka jedne pretvorbe (1 = svaki tick; 5 = pivovara svakih 5 tickova uzme hmelj, stvori pivo).
    var craftDurationTicks: Int

    /// Maksimalni HP za ovaj objekt.
    var maxHealth: Int { healthLevels * hpPerLevel }

    /// Konfiguracija zdravlja za ObjectHealth katalog.
    var healthConfig: ObjectHealthConfig {
        ObjectHealthConfig(levels: healthLevels, hpPerLevel: hpPerLevel)
    }

    /// Ima li objekt pretvorbu resursa (nešto primka i nešto proizvodi)?
    var transformsResources: Bool { consumptionPerTick.hasAny && productionPerTick.hasAny }

    /// Je li transformer s vremenom tranzicije (npr. pivovara)?
    var isCraftTransformer: Bool { craftDurationTicks >= 1 && consumptionPerTick.hasConsumption && productionPerTick.hasProduction }

    /// Konstruktor bez proizvodnje i potrošnje (zadano .zero, craft 1).
    static func standard(healthLevels: Int, hpPerLevel: Int, isFlammable: Bool, fireDamagePerTick: Int, buildCost: BuildCost) -> ObjectBehavior {
        ObjectBehavior(healthLevels: healthLevels, hpPerLevel: hpPerLevel, isFlammable: isFlammable, fireDamagePerTick: fireDamagePerTick, buildCost: buildCost, productionPerTick: .zero, consumptionPerTick: .zero, craftDurationTicks: 1)
    }

    /// Konstruktor s proizvodnjom (potrošnja .zero, craft 1).
    static func withProduction(healthLevels: Int, hpPerLevel: Int, isFlammable: Bool, fireDamagePerTick: Int, buildCost: BuildCost, productionPerTick: ResourceAmountPerTick) -> ObjectBehavior {
        ObjectBehavior(healthLevels: healthLevels, hpPerLevel: hpPerLevel, isFlammable: isFlammable, fireDamagePerTick: fireDamagePerTick, buildCost: buildCost, productionPerTick: productionPerTick, consumptionPerTick: .zero, craftDurationTicks: 1)
    }

    /// Konstruktor s proizvodnjom i potrošnjom (pretvorba). Ako duration > 1, svakih N tickova uzme input i stvori output.
    static func withProductionAndConsumption(healthLevels: Int, hpPerLevel: Int, isFlammable: Bool, fireDamagePerTick: Int, buildCost: BuildCost, productionPerTick: ResourceAmountPerTick, consumptionPerTick: ResourceAmountPerTick, craftDurationTicks: Int = 1) -> ObjectBehavior {
        ObjectBehavior(healthLevels: healthLevels, hpPerLevel: hpPerLevel, isFlammable: isFlammable, fireDamagePerTick: fireDamagePerTick, buildCost: buildCost, productionPerTick: productionPerTick, consumptionPerTick: consumptionPerTick, craftDurationTicks: craftDurationTicks)
    }
}

/// Registar ponašanja svih objekata – jedan izvor istine po objectId.
/// Katalozi (ObjectHealth, FlammableCatalog, BuildCosts) učitavaju podatke odavde.
enum ObjectBehaviorRegistry {
    /// Svi objectId-evi koji imaju definirano ponašanje.
    static var allObjectIds: [String] {
        [
            HugeWall.objectId,
            SmallWall.objectId,
            Steps.objectId,
            Market.objectId,
            Castle.objectId,
            Well.objectId,
            Spring.objectId,
            Tree.objectId,
            Oak.objectId,
            Fir.objectId,
            Cypress.objectId,
            Palm.objectId,
            SmallRock.objectId,
            MediumRock.objectId,
            LargeRock.objectId,
            House.objectId,
            Hotel.objectId,
            Farm.objectId,
            Chicken.objectId,
            Corn.objectId,
            Hop.objectId,
            Hive.objectId,
            Vegetables.objectId,
            Grapes.objectId,
            Spices.objectId,
            Flower.objectId,
            AppleOrchard.objectId,
            Pig.objectId,
            Cow.objectId,
            Sheep.objectId,
            CandleShop.objectId,
            Food.objectId,
            Windmill.objectId,
            Bakery.objectId,
            Granary.objectId,
            Brewery.objectId,
            Distillery.objectId,
            WineCellar.objectId,
            Tavern.objectId,
            Smocnica.objectId,
            Canteen.objectId,
            Industry.objectId,
            Iron.objectId,
            Stone.objectId,
            Sword.objectId,
            Shield.objectId,
            Bow.objectId,
            Spear.objectId,
            Leather.objectId,
            Training.objectId,
            Armory.objectId,
            Stable.objectId,
            Gates.objectId,
            Miners.objectId,
            Engineering.objectId,
            Lager.objectId,
            Wood.objectId,
            Carriage.objectId,
            Pharmacy.objectId,
            Greenhouse.objectId,
            Church.objectId,
            Diplomacy.objectId,
            UndergroundEntrance.objectId,
            UndergroundCorridor.objectId,
            Road.objectId,
            StoneSlab.objectId,
            Bridge.objectId,
            Tunnel.objectId,
            Flag.objectId,
            Torch.objectId,
            Monument.objectId,
            Candle.objectId,
            OrnamentalTree.objectId,
            Fountain.objectId,
            Roof.objectId,
        ]
    }

    /// Ponašanje za dani objectId. Ako nije u registru, vraća zadano (100 HP, nezapaljiv, besplatno).
    static func behavior(for objectId: String) -> ObjectBehavior {
        switch objectId {
        case HugeWall.objectId:
            return .standard(healthLevels: 10, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case SmallWall.objectId:
            return .standard(healthLevels: 6, hpPerLevel: 6, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Steps.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 1, buildCost: .zero)
        case Market.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Castle.objectId:
            return .standard(healthLevels: 15, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 1, buildCost: .zero)
        case Well.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 1, buildCost: .zero)
        case Spring.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case Tree.objectId, Oak.objectId, Fir.objectId, Cypress.objectId, Palm.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 6, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case SmallRock.objectId, MediumRock.objectId, LargeRock.objectId:
            return .standard(healthLevels: 6, hpPerLevel: 8, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case House.objectId:
            return .standard(healthLevels: 6, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Hotel.objectId:
            return .withProductionAndConsumption(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero, productionPerTick: ResourceAmountPerTick(gold: 1), consumptionPerTick: ResourceAmountPerTick(beer: 1), craftDurationTicks: 1)
        case Farm.objectId, Vegetables.objectId, Grapes.objectId, Spices.objectId, Flower.objectId, AppleOrchard.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Chicken.objectId, Pig.objectId, Cow.objectId, Sheep.objectId, Hive.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Corn.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Hop.objectId:
            return .withProduction(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero, productionPerTick: ResourceAmountPerTick(hop: 1))
        case Food.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Windmill.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Bakery.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Granary.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Brewery.objectId:
            return .withProductionAndConsumption(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero, productionPerTick: ResourceAmountPerTick(beer: 1), consumptionPerTick: ResourceAmountPerTick(hop: 1), craftDurationTicks: 5)
        case Distillery.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case WineCellar.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Tavern.objectId:
            return .withProductionAndConsumption(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero, productionPerTick: ResourceAmountPerTick(gold: 1), consumptionPerTick: ResourceAmountPerTick(beer: 1), craftDurationTicks: 1)
        case Smocnica.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Canteen.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case CandleShop.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Industry.objectId:
            return .standard(healthLevels: 6, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Iron.objectId:
            return .withProduction(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 1, buildCost: .zero, productionPerTick: ProductionPerTick(stone: 0, wood: 0, iron: 1))
        case Stone.objectId:
            return .withProduction(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 1, buildCost: .zero, productionPerTick: ProductionPerTick(stone: 1, wood: 0, iron: 0))
        case Sword.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Shield.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Bow.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Spear.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Leather.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Training.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Armory.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Stable.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Gates.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Miners.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Engineering.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Lager.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Wood.objectId:
            return .withProduction(healthLevels: 4, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero, productionPerTick: ProductionPerTick(stone: 0, wood: 1, iron: 0))
        case Carriage.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Pharmacy.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Greenhouse.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Church.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Diplomacy.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 10, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case UndergroundEntrance.objectId:
            return .standard(healthLevels: 4, hpPerLevel: 8, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case UndergroundCorridor.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 6, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case Road.objectId, StoneSlab.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 6, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case Bridge.objectId, Tunnel.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 8, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        case Flag.objectId, Torch.objectId, Candle.objectId, OrnamentalTree.objectId:
            return .standard(healthLevels: 2, hpPerLevel: 6, isFlammable: true, fireDamagePerTick: 3, buildCost: .zero)
        case Monument.objectId, Fountain.objectId:
            return .standard(healthLevels: 5, hpPerLevel: 8, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero)
        case Roof.objectId:
            return .standard(healthLevels: 3, hpPerLevel: 6, isFlammable: true, fireDamagePerTick: 2, buildCost: .zero)
        default:
            return ObjectBehavior(healthLevels: 5, hpPerLevel: 10, isFlammable: false, fireDamagePerTick: 0, buildCost: .zero, productionPerTick: .zero, consumptionPerTick: .zero, craftDurationTicks: 1)
        }
    }
}
