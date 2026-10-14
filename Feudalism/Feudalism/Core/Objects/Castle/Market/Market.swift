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
        return GameObject(id: objectId, name: "Tržnica", category: .industrija, width: d.cellWidth, height: d.cellHeight, displayCode: displayCode, modelAssetName: nil)
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
        MarketOffer(good: .banana, buy: 2, sell: 1),
        MarketOffer(good: .honey, buy: 3, sell: 2),
        MarketOffer(good: .bread, buy: 3, sell: 2),
        MarketOffer(good: .cheese, buy: 4, sell: 2),
        MarketOffer(good: .meat, buy: 5, sell: 3),
        MarketOffer(good: .chicken, buy: 4, sell: 2),
        MarketOffer(good: .eggs, buy: 2, sell: 1),
        MarketOffer(good: .vegetables, buy: 2, sell: 1),
        MarketOffer(good: .corn, buy: 2, sell: 1),
        MarketOffer(good: .grapes, buy: 3, sell: 1),
        MarketOffer(good: .wood, buy: 2, sell: 1),
        MarketOffer(good: .stone, buy: 2, sell: 1),
        MarketOffer(good: .iron, buy: 6, sell: 4),
        MarketOffer(good: .hop, buy: 3, sell: 2),
        MarketOffer(good: .hay, buy: 2, sell: 1)
    ]
}

extension GameState {
    /// Tržnica igrača je sagrađena i radi: nije srušena, ne spava i ne gori.
    func marketIsWorking(of faction: String? = nil) -> Bool {
        let faction = faction ?? playerSeat?.id
        return mapLogic.allPlacements.contains { located in
            let placement = located.placement
            guard placement.objectId == Market.objectId, !placement.isDestroyed else { return false }
            if let faction, owner(of: placement) != faction { return false }
            let state = buildingStates[placement.id]
            return state?.isOnFire != true && state?.isClosed != true
        }
    }

    func tradeQuote(_ good: Good) -> (buy: Int, sell: Int)? {
        guard good != .gold else { return nil }
        if let offer = MarketPrices.offers.first(where: { $0.good == good }) {
            return (offer.buy, offer.sell)
        }
        let buy = max(1, PriceList.shopUnitPrice(good))
        return (buy, max(1, buy - 1))
    }

    func marketBuy(_ good: Good, faction: String? = nil) {
        let faction = faction ?? playerSeat?.id
        guard marketIsWorking(of: faction), let quote = tradeQuote(good), resources.gold >= quote.buy else { return }
        guard let faction, unitsThatFit(good, adding: 1, faction: faction) >= 1 else {
            postHUD(.resources, "Nema slobodnog mjesta u skladištu.")
            return
        }
        resources.subtract(gold: quote.buy)
        addGood(good, 1)
    }

    func marketSell(_ good: Good, faction: String? = nil) {
        let faction = faction ?? playerSeat?.id
        guard marketIsWorking(of: faction), let quote = tradeQuote(good), goodAmount(good) >= 1 else { return }
        addGood(good, -1)
        resources.add(gold: quote.sell)
    }
}
