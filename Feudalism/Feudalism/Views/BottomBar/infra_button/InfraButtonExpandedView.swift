//
//  InfraButtonExpandedView.swift
//  Feudalism
//
//  Infrastruktura: cesta, podloga, most, tunel, kanal, rijeka +
//  kategorije Biljke / Spomenici / Ukrasi (isti island, Nazad).
//

import SwiftUI

private enum InfraSubmenu: Equatable {
    case biljke
    case spomenici
    case ukrasi
}

struct InfraButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelect: (String) -> Void
    @State private var submenu: InfraSubmenu?

    var body: some View {
        Group {
            if let submenu {
                InfraSubmenuExpandedView(
                    submenu: submenu,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.submenu = nil
                        }
                    },
                    onSelect: onSelect
                )
                .transition(.opacity)
            } else {
                CategoryExpandedView(items: [
                    CategoryExpandedItem(assetName: "infra_road", systemName: "rectangle.split.1x2", labelKey: "infra_road", action: { onSelect(Road.objectId) }),
                    CategoryExpandedItem(assetName: "infra_slab", systemName: "square.grid.2x2.fill", labelKey: "infra_slab", action: { onSelect(StoneSlab.objectId) }),
                    CategoryExpandedItem(assetName: "drawbridge", systemName: "road.lanes", labelKey: "infra_bridge", action: { onSelect(Bridge.objectId) }),
                    CategoryExpandedItem(assetName: "infra_tunnel", systemName: "archivebox.fill", labelKey: "infra_tunnel", action: { onSelect(Tunnel.objectId) }),
                    CategoryExpandedItem(assetName: "infra_canal", systemName: "rectangle.split.3x1", labelKey: "infra_canal", action: { onSelect(Canal.objectId) }),
                    CategoryExpandedItem(assetName: "infra_river", systemName: "water.waves", labelKey: "infra_river", action: { onSelect(River.objectId) }),
                    CategoryExpandedItem(assetName: "tree", systemName: "leaf.fill", labelKey: "infra_cat_plants", action: {
                        withAnimation(.easeInOut(duration: 0.2)) { submenu = .biljke }
                    }),
                    CategoryExpandedItem(assetName: "infra_monument", systemName: "building.columns.fill", labelKey: "infra_cat_monuments", action: {
                        withAnimation(.easeInOut(duration: 0.2)) { submenu = .spomenici }
                    }),
                    CategoryExpandedItem(assetName: "infra_fountain", systemName: "sparkles", labelKey: "infra_cat_decor", action: {
                        withAnimation(.easeInOut(duration: 0.2)) { submenu = .ukrasi }
                    }),
                ])
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: submenu)
    }
}

private struct InfraSubmenuExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    let submenu: InfraSubmenu
    var onBack: () -> Void
    var onSelect: (String) -> Void

    private var titleKey: String {
        switch submenu {
        case .biljke: return "infra_cat_plants"
        case .spomenici: return "infra_cat_monuments"
        case .ukrasi: return "infra_cat_decor"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Nazad")

                Text(LocalizedStrings.string(for: titleKey, language: gameState.appLanguage))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            CategoryExpandedView(items: items)
        }
    }

    private var items: [CategoryExpandedItem] {
        switch submenu {
        case .biljke:
            return [
                CategoryExpandedItem(assetName: "infra_tree", systemName: "leaf.fill", labelKey: "infra_tree", action: { onSelect(OrnamentalTree.objectId) }),
                CategoryExpandedItem(assetName: "tree", systemName: "leaf.fill", labelKey: "plant_tree", action: { onSelect(Tree.objectId) }, customIcon: AnyView(TreeIcon(size: 36))),
                CategoryExpandedItem(assetName: "oak", systemName: "leaf.fill", labelKey: "plant_oak", action: { onSelect(Oak.objectId) }, customIcon: AnyView(OakIcon(size: 36))),
                CategoryExpandedItem(assetName: "fir", systemName: "triangle.fill", labelKey: "plant_fir", action: { onSelect(Fir.objectId) }, customIcon: AnyView(FirIcon(size: 36))),
                CategoryExpandedItem(assetName: "cypress", systemName: "leaf.fill", labelKey: "plant_cypress", action: { onSelect(Cypress.objectId) }, customIcon: AnyView(CypressIcon(size: 36))),
                CategoryExpandedItem(assetName: "palm", systemName: "leaf.fill", labelKey: "plant_palm", action: { onSelect(Palm.objectId) }, customIcon: AnyView(PalmIcon(size: 36))),
            ]
        case .spomenici:
            return [
                CategoryExpandedItem(assetName: "infra_monument", systemName: "building.columns.fill", labelKey: "infra_monument", action: { onSelect(Monument.objectId) }),
            ]
        case .ukrasi:
            return [
                CategoryExpandedItem(assetName: "infra_flag", systemName: "flag.fill", labelKey: "infra_flag", action: { onSelect(Flag.objectId) }),
                CategoryExpandedItem(assetName: "infra_torch", systemName: "flame.fill", labelKey: "infra_torch", action: { onSelect(Torch.objectId) }),
                CategoryExpandedItem(assetName: "infra_candle", systemName: "light.max", labelKey: "infra_candle", action: { onSelect(Candle.objectId) }),
                CategoryExpandedItem(assetName: "infra_fountain", systemName: "drop.fill", labelKey: "infra_fountain", action: { onSelect(Fountain.objectId) }),
                CategoryExpandedItem(assetName: "infra_roof", systemName: "triangle.fill", labelKey: "infra_roof", action: { onSelect(Roof.objectId) }),
                CategoryExpandedItem(assetName: "water_well", systemName: "drop.fill", labelKey: "house_water_well", action: { onSelect(Well.objectId) }),
                CategoryExpandedItem(assetName: "spring", systemName: "drop.circle.fill", labelKey: "house_spring", action: { onSelect(Spring.objectId) }),
            ]
        }
    }
}
