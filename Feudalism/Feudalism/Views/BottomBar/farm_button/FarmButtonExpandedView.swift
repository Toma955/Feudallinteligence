//
//  FarmButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Farma: jedan red ikona, ispod jedan red natpisa.
//

import SwiftUI

/// Visina ikona u proširenom izborniku (niska traka).
private let expandedIconSize: CGFloat = 34

struct FarmButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectAppleFarm: () -> Void
    var onSelectPigFarm: () -> Void
    var onSelectHayFarm: () -> Void
    var onSelectCowFarm: () -> Void
    var onSelectSheepFarm: () -> Void
    var onSelectWheatFarm: () -> Void
    var onSelectCornFarm: () -> Void
    var onSelectChickenFarm: () -> Void
    var onSelectVegetablesFarm: () -> Void
    var onSelectGrapesFarm: () -> Void
    var onSelectSpicesFarm: () -> Void
    var onSelectFlowerFarm: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Red ikona
            HStack(spacing: 6) {
                AppleFarmBarButtonView(action: onSelectAppleFarm, iconOnly: true, iconOnlySize: 34)
                    .frame(maxWidth: .infinity, alignment: .center)
                WheatFarmBarButtonView(action: onSelectWheatFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                CornFarmBarButtonView(action: onSelectCornFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                HayFarmBarButtonView(action: onSelectHayFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                VegetablesFarmBarButtonView(action: onSelectVegetablesFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                GrapesFarmBarButtonView(action: onSelectGrapesFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                SpicesFarmBarButtonView(action: onSelectSpicesFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                FlowerFarmBarButtonView(action: onSelectFlowerFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1, height: expandedIconSize)
                PigFarmBarButtonView(action: onSelectPigFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                CowFarmBarButtonView(action: onSelectCowFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                SheepFarmBarButtonView(action: onSelectSheepFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                ChickenFarmBarButtonView(action: onSelectChickenFarm, iconOnly: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            // Jedan red natpisa, malo dole
            HStack(spacing: 6) {
                farmLabel("apple_farm")
                farmLabel("wheat_farm")
                farmLabel("corn_farm")
                farmLabel("resource_hop")
                farmLabel("vegetables_farm")
                farmLabel("grapes_farm")
                farmLabel("spices_farm")
                farmLabel("flower_farm")
                Color.clear.frame(width: 1)
                farmLabel("pig_farm")
                farmLabel("cow_farm")
                farmLabel("sheep_farm")
                farmLabel("chicken_farm")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func farmLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .top)
    }
}
