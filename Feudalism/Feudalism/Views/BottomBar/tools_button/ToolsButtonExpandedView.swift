//
//  ToolsButtonExpandedView.swift
//  Feudalism
//
//  Alati: Sword, Mace, Report, Shovel, Pen + 4 zasebna map prozora (svaki svoj poziv).
//

import SwiftUI

struct ToolsButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var selectedToolId: String?
    var onSelectSword: () -> Void
    var onSelectMace: () -> Void
    var onSelectReport: () -> Void
    var onSelectShovel: () -> Void
    var onSelectPen: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "sword_icon", systemName: "crossed.swords", labelKey: "tools_sword", action: onSelectSword, isHighlighted: selectedToolId == "sword", highlightColor: .green),
            CategoryExpandedItem(assetName: "mace", systemName: "hammer.fill", labelKey: "tools_mace", action: onSelectMace, isHighlighted: selectedToolId == "mace", highlightColor: .red),
            CategoryExpandedItem(assetName: "report", systemName: "doc.text.fill", labelKey: "tools_report", action: onSelectReport, isHighlighted: selectedToolId == "report", highlightColor: .green),
            CategoryExpandedItem(assetName: "shovel", systemName: "square.fill", labelKey: "tools_shovel", action: onSelectShovel, isHighlighted: selectedToolId == "shovel", highlightColor: .green),
            CategoryExpandedItem(assetName: "pen", systemName: "pencil", labelKey: "tools_pen", action: onSelectPen, isHighlighted: selectedToolId == "pen", highlightColor: .green),
            mapItem(.surface),
            mapItem(.underground),
            mapItem(.buildings),
            mapItem(.army),
        ])
    }

    private func mapItem(_ id: LiveMapWindowId) -> CategoryExpandedItem {
        let toolId = "map_\(id.rawValue)"
        let open = gameState.openTextMapWindows.contains(id.rawValue)
        return CategoryExpandedItem(
            assetName: "",
            systemName: id.systemImage,
            labelKey: labelKey(id),
            action: {
                gameState.selectedPlacementObjectId = nil
                gameState.inspectedBuildingTitle = nil
                gameState.inspectedPlacementId = nil
                gameState.toggleTextMapWindow(id.rawValue)
                if gameState.openTextMapWindows.contains(id.rawValue) {
                    selectedToolId = toolId
                } else if selectedToolId == toolId {
                    selectedToolId = nil
                }
            },
            isHighlighted: open || selectedToolId == toolId,
            highlightColor: .green
        )
    }

    private func labelKey(_ id: LiveMapWindowId) -> String {
        switch id {
        case .surface: return "tools_map_surface"
        case .underground: return "tools_map_underground"
        case .buildings: return "tools_map_buildings"
        case .army: return "tools_map_army"
        case .decisions: return "history_map_decisions"
        }
    }
}
