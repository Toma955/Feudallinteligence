//
//  BuildCategoryBar.swift
//  Feudalism
//
//  Kategorije građevina donjeg bara (ikone + prošireni sadržaj). Dijele ih igra i map editor.
//

import SwiftUI

enum BottomBarCategory: String, CaseIterable {
    case castle
    case sword
    case mine
    case house
    case cave
    case farm
    case food
    case infra
    case tools

    /// Kategorije s građevinama koje se postavljaju na gornju mapu (map editor).
    static let surfaceBuildCategories: [BottomBarCategory] = [.castle, .sword, .mine, .house, .farm, .food, .infra]

    var labelKey: String { "category_\(rawValue)" }
}

struct BuildCategoryIcon: View {
    let category: BottomBarCategory
    var size: CGFloat = 48

    var body: some View {
        switch category {
        case .castle: BarIconView(assetName: "castle", systemName: "building.columns.fill", size: size)
        case .sword: BarIconView(assetName: "sword", systemName: "crossed.swords", size: size)
        case .mine: BarIconView(assetName: "mine", systemName: "hammer.fill", size: size)
        case .house: BarIconView(assetName: "house", systemName: "house.fill", size: size)
        case .cave: BarIconView(assetName: "cave", systemName: "mountain.2.fill", size: size)
        case .farm: BarIconView(assetName: "farm", systemName: "leaf.fill", size: size)
        case .food: BarIconView(assetName: "food", systemName: "fork.knife", size: size)
        case .infra: BarIconView(assetName: "drawbridge", systemName: "road.lanes", size: size)
        case .tools: BarIconView(assetName: "tools", systemName: "wrench.and.screwdriver.fill", size: size)
        }
    }
}

/// Prošireni sadržaj kategorije: klik na objekt ga odabire za postavljanje.
struct BuildCategoryContent: View {
    @EnvironmentObject private var gameState: GameState
    let category: BottomBarCategory
    @State private var showTowerPicker = false

    private func select(_ objectId: String) {
        gameState.selectedToolsPanelItem = nil
        gameState.selectedPlacementObjectId = objectId
    }

    var body: some View {
        switch category {
        case .castle:
            Group {
                if showTowerPicker {
                    TowerPickerExpandedView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTowerPicker = false
                            }
                        },
                        onSelect: { objectId in
                            placementDebugLog("UI click castle/tower -> \(objectId)")
                            select(objectId)
                        }
                    )
                    .transition(.opacity)
                } else {
                    CastleButtonExpandedView(
                        onSelectWall: {
                            placementDebugLog("UI click castle/huge_wall -> \(HugeWall.objectId)")
                            select(HugeWall.objectId)
                        },
                        onSelectSmallWall: {
                            placementDebugLog("UI click castle/wall_small -> \(SmallWall.objectId)")
                            select(SmallWall.objectId)
                        },
                        onSelectCastle: {
                            placementDebugLog("UI click castle/castle -> \(Castle.objectId)")
                            select(Castle.objectId)
                        },
                        onSelectSteps: {
                            let targetId = gameState.isSoloMode || gameState.isMapEditorMode ? Steps.objectId : HugeWall.objectId
                            placementDebugLog("UI click castle/steps -> \(targetId)")
                            select(targetId)
                        },
                        onSelectStairs: {
                            let targetId = gameState.isSoloMode || gameState.isMapEditorMode ? Steps.objectId : HugeWall.objectId
                            placementDebugLog("UI click castle/stairs -> \(targetId)")
                            select(targetId)
                        },
                        onSelectGates: { select(Gates.objectId) },
                        onSelectStable: { select(Stable.objectId) },
                        onSelectMiners: { select(Miners.objectId) },
                        onSelectEngineering: { select(Engineering.objectId) },
                        onSelectTowers: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTowerPicker = true
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showTowerPicker)
            .onChange(of: category) { _ in
                showTowerPicker = false
            }
        case .farm:
            FarmButtonExpandedView(
                onSelectAppleFarm: { select(AppleOrchard.objectId) },
                onSelectPigFarm: { select(Pig.objectId) },
                onSelectHayFarm: { select(Hop.objectId) },
                onSelectCowFarm: { select(Cow.objectId) },
                onSelectSheepFarm: { select(Sheep.objectId) },
                onSelectWheatFarm: { select(Farm.objectId) },
                onSelectCornFarm: { select(Corn.objectId) },
                onSelectChickenFarm: { select(Chicken.objectId) },
                onSelectVegetablesFarm: { select(Vegetables.objectId) },
                onSelectGrapesFarm: { select(Grapes.objectId) },
                onSelectSpicesFarm: { select(Spices.objectId) },
                onSelectFlowerFarm: { select(Flower.objectId) }
            )
        case .sword:
            SwordButtonExpandedView(
                onSelectSwordHouse: { select(Sword.objectId) },
                onSelectShield: { select(Shield.objectId) },
                onSelectBow: { select(Bow.objectId) },
                onSelectSpear: { select(Spear.objectId) },
                onSelectLeather: { select(Leather.objectId) },
                onSelectTraining: { select(Training.objectId) },
                onSelectArmory: { select(Armory.objectId) }
            )
        case .mine:
            MineButtonExpandedView(
                onSelectLager: { select(Lager.objectId) },
                onSelectStump: { select(Wood.objectId) },
                onSelectIronMine: { select(Iron.objectId) },
                onSelectStoneMine: { select(Stone.objectId) },
                onSelectCarriage: { select(Carriage.objectId) },
                onSelectMarket: {
                    placementDebugLog("UI click industry/market -> \(Market.objectId)")
                    select(Market.objectId)
                }
            )
        case .tools:
            ToolsButtonExpandedView(
                selectedToolId: $gameState.selectedToolsPanelItem,
                onSelectSword: {
                    gameState.selectedToolsPanelItem = "sword"
                },
                onSelectMace: {
                    gameState.selectedPlacementObjectId = nil
                    gameState.inspectedBuildingTitle = nil
                    gameState.inspectedPlacementId = nil
                    gameState.selectedToolsPanelItem = "mace"
                },
                onSelectReport: { gameState.selectedToolsPanelItem = "report" },
                onSelectShovel: { gameState.selectedToolsPanelItem = "shovel" },
                onSelectPen: { gameState.selectedToolsPanelItem = "pen" },
                onSelectWindow: {
                    gameState.selectedPlacementObjectId = nil
                    gameState.inspectedBuildingTitle = nil
                    gameState.inspectedPlacementId = nil
                    // Ponovni klik: zatvori sve pa otvori sve ispočetka.
                    if gameState.selectedToolsPanelItem == "window" {
                        gameState.selectedToolsPanelItem = nil
                        gameState.textMapWindowSession += 1
                        DispatchQueue.main.async {
                            gameState.selectedToolsPanelItem = "window"
                        }
                    } else {
                        gameState.textMapWindowSession += 1
                        gameState.selectedToolsPanelItem = "window"
                    }
                }
            )
        case .house:
            HouseButtonExpandedView(
                onSelectHouse: { select(House.objectId) },
                onSelectPharmacy: { select(Pharmacy.objectId) },
                onSelectGreenHouse: { select(Greenhouse.objectId) },
                onSelectHotel: { select(Hotel.objectId) },
                onSelectChurch: { select(Church.objectId) },
                onSelectDiplomacy: { select(Diplomacy.objectId) }
            )
        case .food:
            FoodButtonExpandedView(
                onSelectMill: { select(Windmill.objectId) },
                onSelectBrewery: { select(Brewery.objectId) },
                onSelectDistillery: { select(Distillery.objectId) },
                onSelectWineCellar: { select(WineCellar.objectId) },
                onSelectTavern: { select(Tavern.objectId) },
                onSelectPantry: { select(Smocnica.objectId) },
                onSelectBakery: { select(Bakery.objectId) },
                onSelectCanteen: { select(Canteen.objectId) }
            )
        case .cave:
            CaveButtonExpandedView(onSelect: { select($0) })
        case .infra:
            InfraButtonExpandedView(onSelect: { select($0) })
        }
    }
}
