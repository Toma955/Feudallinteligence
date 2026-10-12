//
//  CaveButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Podzemlje: objekti koji se grade na donjoj mapi. Koristi CategoryExpandedView.
//

import SwiftUI

struct CaveButtonExpandedView: View {
    var onSelect: (String) -> Void

    private static let entries: [(asset: String, system: String, label: String, objectId: String)] = [
        ("cave", "arrow.down.to.line", "cave_entrance", UndergroundEntrance.objectId),
        ("cave", "rectangle.split.1x2", "cave_corridor", UndergroundCorridor.objectId),
        ("pantry", "cabinet.fill", "food_smocnica", Smocnica.objectId),
        ("lager", "building.2.fill", "industry_lager", Lager.objectId),
    ]

    var body: some View {
        CategoryExpandedView(items: Self.entries.map { entry in
            CategoryExpandedItem(assetName: entry.asset, systemName: entry.system, labelKey: entry.label, action: { onSelect(entry.objectId) })
        })
    }
}
