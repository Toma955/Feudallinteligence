//
//  PlaceableSceneKitObject.swift
//  Feudalism
//
//  Protocol za objekte koji se mogu postaviti na 3D kartu – učitavanje modela i primjena teksture.
//  Svaki tip (Wall, Market, Windmill, …) konformira; registry koristi ovaj protokol umjesto switcha.
//

import Foundation
import SceneKit

/// Objekt koji ima 3D model na karti: id, učitavanje čvora i ponovna primjena teksture.
protocol PlaceableSceneKitObject {
    static var objectId: String { get }
    static func loadSceneKitNode(from bundle: Bundle) -> SCNNode?
    static func reapplyTexture(to node: SCNNode, bundle: Bundle) -> Bool
}

/// Svi tipovi koji se mogu postaviti na mapu (redoslijed za registry).
enum PlaceableSceneKitTypes {
    static let all: [PlaceableSceneKitObject.Type] = [
        HugeWall.self,
        SmallWall.self,
        Steps.self,
        Castle.self,
        Market.self,
        Windmill.self,
        Bakery.self,
        Granary.self,
        Brewery.self,
        Distillery.self,
        WineCellar.self,
        Tavern.self,
        Smocnica.self,
        Food.self,
        Canteen.self,
        Well.self,
        Spring.self,
        Tree.self,
        Oak.self,
        Fir.self,
        Cypress.self,
        Palm.self,
        SmallRock.self,
        MediumRock.self,
        LargeRock.self,
        House.self,
        Hotel.self,
        Iron.self,
        Stone.self,
        Farm.self,
        Chicken.self,
        Corn.self,
        Hop.self,
        Hive.self,
        Vegetables.self,
        Grapes.self,
        Spices.self,
        Flower.self,
        AppleOrchard.self,
        Pig.self,
        Cow.self,
        Sheep.self,
        CandleShop.self,
        Sword.self,
        Shield.self,
        Bow.self,
        Spear.self,
        Leather.self,
        Training.self,
        Armory.self,
        Stable.self,
        Gates.self,
        Miners.self,
        Engineering.self,
        Lager.self,
        Wood.self,
        Carriage.self,
        Pharmacy.self,
        Greenhouse.self,
        Church.self,
        Diplomacy.self,
        UndergroundEntrance.self,
        UndergroundCorridor.self,
        Road.self,
        StoneSlab.self,
        Bridge.self,
        Tunnel.self,
        Flag.self,
        Torch.self,
        Monument.self,
        Candle.self,
        OrnamentalTree.self,
        Fountain.self,
        Roof.self,
    ]
}
