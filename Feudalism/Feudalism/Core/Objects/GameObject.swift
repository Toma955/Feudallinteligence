//
//  GameObject.swift
//  Feudalism
//
//  Jedan objekt u igri – uvijek pripada jednoj kategoriji (ObjectCategory).
//  Prostorna veličina u jedinicama 1×1 (najmanja); npr. kuća = 4×4.
//

import Foundation

/// Zajednički protokol za sve objekte u igri.
protocol GameObjectProtocol: Identifiable, Equatable {
    var id: String { get }
    var name: String { get }
    var category: ObjectCategory { get }
    var size: SpatialSize { get }
    var displayCode: String { get }
    /// Ime 3D modela u bundleu (bez ekstenzije), npr. "Wall" za Wall.obj / Wall.usdz. Nil = bez 3D modela.
    var modelAssetName: String? { get }
}

/// Konkretni objekt – ima prostornu veličinu (1×1 = najmanja, kuća = 4×4, …).
struct GameObject: GameObjectProtocol {
    let id: String
    let name: String
    let category: ObjectCategory
    let size: SpatialSize
    let displayCode: String
    /// 3D model: ime datoteke bez ekstenzije (npr. "Wall" → Wall.obj ili Wall.usdz u bundleu).
    let modelAssetName: String?

    init(id: String? = nil, name: String, category: ObjectCategory, width: Int = 1, height: Int = 1, displayCode: String? = nil, modelAssetName: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.category = category
        self.size = SpatialSize(width: width, height: height)
        self.displayCode = displayCode ?? String(name.prefix(1)).uppercased()
        self.modelAssetName = modelAssetName
    }
}

// MARK: - Primjeri po kategorijama – veličine u 1×1 jedinicama (kuća = 4×4 basic)

extension ObjectCategory {

    /// Zadani objekti u ovoj kategoriji. Veličine: 1×1 minimalno, kuća 4×4, veće zgrade veće.
    static func defaultObjects(for category: ObjectCategory) -> [GameObject] {
        switch category {
        case .spremista:
            return [
                GameObject(name: "Skladište", category: .spremista, width: 3, height: 3),
                GameObject(name: "Silos", category: .spremista, width: 2, height: 2)
            ]
        case .resursi:
            return [
                Tree.gameObject,
                Oak.gameObject,
                Fir.gameObject,
                Cypress.gameObject,
                Palm.gameObject,
                SmallRock.gameObject,
                MediumRock.gameObject,
                LargeRock.gameObject,
                GameObject(name: "Zlato", category: .resursi),
                GameObject(name: "Drvo", category: .resursi),
                GameObject(name: "Kamen", category: .resursi)
            ]
        case .hrana:
            return [
                Food.gameObject,
                Windmill.gameObject,
                Bakery.gameObject,
                Granary.gameObject,
                Brewery.gameObject,
                Distillery.gameObject,
                WineCellar.gameObject,
                Tavern.gameObject,
                Smocnica.gameObject,
                Canteen.gameObject,
                GameObject(name: "Pšenica", category: .hrana),
                GameObject(name: "Povrće", category: .hrana)
            ]
        case .farme:
            return [
                Farm.gameObject,
                Chicken.gameObject,
                Corn.gameObject,
                Hop.gameObject,
                Vegetables.gameObject,
                Grapes.gameObject,
                Spices.gameObject,
                Flower.gameObject,
                AppleOrchard.gameObject,
                Pig.gameObject,
                Cow.gameObject,
                Sheep.gameObject,
            ]
        case .vojska:
            return [
                Sword.gameObject,
                Shield.gameObject,
                Bow.gameObject,
                Spear.gameObject,
                Leather.gameObject,
                Training.gameObject,
                Armory.gameObject,
                GameObject(name: "Baraka", category: .vojska, width: 4, height: 3),
                GameObject(name: "Zidine", category: .vojska, width: 1, height: 1)
            ]
        case .religija:
            return [
                GameObject(name: "Crkva", category: .religija, width: 5, height: 6),
                GameObject(name: "Samostan", category: .religija, width: 6, height: 5)
            ]
        case .dvorac:
            return [
                Castle.gameObject,
                Steps.gameObject,
                House.gameObject,
                Hotel.gameObject,
                Stable.gameObject,
                Gates.gameObject,
                Miners.gameObject,
                Engineering.gameObject,
                Pharmacy.gameObject,
                Greenhouse.gameObject,
                Church.gameObject,
                Diplomacy.gameObject,
            ] + TowerKind.allCases.map { Tower.gameObject($0) }
        case .vojnici:
            return [
                GameObject(name: "Vitez", category: .vojnici),
                GameObject(name: "Pješak", category: .vojnici),
                GameObject(name: "Strijelac", category: .vojnici)
            ]
        case .radnici:
            return [
                GameObject(name: "Seljak", category: .radnici),
                GameObject(name: "Obrtnik", category: .radnici)
            ]
        case .industrija:
            return [
                Industry.gameObject,
                Lager.gameObject,
                Wood.gameObject,
                Carriage.gameObject,
                Iron.gameObject,
                Stone.gameObject,
                Market.gameObject
            ]
        case .infrastruktura:
            return [
                Road.gameObject,
                StoneSlab.gameObject,
                Bridge.gameObject,
                Tunnel.gameObject,
                Canal.gameObject,
                River.gameObject,
                Well.gameObject,
                Spring.gameObject,
                Flag.gameObject,
                Torch.gameObject,
                Monument.gameObject,
                Candle.gameObject,
                OrnamentalTree.gameObject,
                Fountain.gameObject,
                Roof.gameObject,
            ]
        case .podzemlje:
            return [
                UndergroundEntrance.gameObject,
                UndergroundCorridor.gameObject,
                UndergroundLightOpening.gameObject,
                Smocnica.gameObject,
                Lager.gameObject
            ]
        case .ostali:
            return [
                HugeWall.gameObject,
                SmallWall.gameObject,
            ]
        }
    }
}
