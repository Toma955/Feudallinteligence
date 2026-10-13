//
//  InfraButtonExpandedView.swift
//  Feudalism
//
//  Infrastruktura i ukras dvorca u donjem baru.
//

import SwiftUI

struct InfraButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelect: (String) -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "infra_road", systemName: "rectangle.split.1x2", labelKey: "infra_road", action: { onSelect(Road.objectId) }),
            CategoryExpandedItem(assetName: "infra_slab", systemName: "square.grid.2x2.fill", labelKey: "infra_slab", action: { onSelect(StoneSlab.objectId) }),
            CategoryExpandedItem(assetName: "infra_roof", systemName: "triangle.fill", labelKey: "infra_roof", action: { onSelect(Roof.objectId) }),
            CategoryExpandedItem(assetName: "drawbridge", systemName: "road.lanes", labelKey: "infra_bridge", action: { onSelect(Bridge.objectId) }),
            CategoryExpandedItem(assetName: "infra_tunnel", systemName: "archivebox.fill", labelKey: "infra_tunnel", action: { onSelect(Tunnel.objectId) }),
            CategoryExpandedItem(assetName: "infra_flag", systemName: "flag.fill", labelKey: "infra_flag", action: { onSelect(Flag.objectId) }),
            CategoryExpandedItem(assetName: "infra_torch", systemName: "flame.fill", labelKey: "infra_torch", action: { onSelect(Torch.objectId) }),
            CategoryExpandedItem(assetName: "infra_monument", systemName: "building.columns.fill", labelKey: "infra_monument", action: { onSelect(Monument.objectId) }),
            CategoryExpandedItem(assetName: "infra_candle", systemName: "light.max", labelKey: "infra_candle", action: { onSelect(Candle.objectId) }),
            CategoryExpandedItem(assetName: "infra_tree", systemName: "leaf.fill", labelKey: "infra_tree", action: { onSelect(OrnamentalTree.objectId) }),
            CategoryExpandedItem(assetName: "infra_fountain", systemName: "drop.fill", labelKey: "infra_fountain", action: { onSelect(Fountain.objectId) }),
        ])
    }
}
