//
//  Market.swift
//  Feudalism
//
//  Privremeni placeholder: tržnica 5×5, visina 4 — obična siva kutija.
//

import Foundation
import SceneKit
import AppKit

enum Market: PlaceableSceneKitObject {
    static let objectId = "object_market"
    static let displayCode = "M"

    static var gameObject: GameObject {
        let d = ObjectDimensions.market
        return GameObject(id: objectId, name: "Tržnica", category: .dvorac, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        BuildingShapes.market()
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool { true }
}

struct MarketOffer {
    var good: Good
    var buy: Int
    var sell: Int
}

enum MarketPrices {
    static let offers: [MarketOffer] = [
        MarketOffer(good: .apple, buy: 2, sell: 1),
        MarketOffer(good: .bread, buy: 3, sell: 2),
        MarketOffer(good: .cheese, buy: 4, sell: 2),
        MarketOffer(good: .meat, buy: 5, sell: 3),
        MarketOffer(good: .wood, buy: 2, sell: 1),
        MarketOffer(good: .stone, buy: 2, sell: 1),
        MarketOffer(good: .iron, buy: 6, sell: 4),
        MarketOffer(good: .hop, buy: 3, sell: 2),
        MarketOffer(good: .hay, buy: 2, sell: 1)
    ]
}

extension GameState {
    func marketBuy(_ good: Good) {
        guard let offer = MarketPrices.offers.first(where: { $0.good == good }) else { return }
        guard resources.gold >= offer.buy else { return }
        resources.subtract(gold: offer.buy)
        addGood(good, 1)
    }

    func marketSell(_ good: Good) {
        guard let offer = MarketPrices.offers.first(where: { $0.good == good }) else { return }
        guard goodAmount(good) >= 1 else { return }
        addGood(good, -1)
        resources.add(gold: offer.sell)
    }
}
