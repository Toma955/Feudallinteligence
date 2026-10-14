//
//  TowerPickerExpandedView.swift
//  Feudalism
//
//  Podizbornik Kule unutar istog islanda: Nazad + 5 tipova (helta raste slijeva nadesno).
//

import SwiftUI

struct TowerPickerExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onBack: () -> Void
    var onSelect: (String) -> Void

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

                Text(LocalizedStrings.string(for: "castle_towers", language: gameState.appLanguage))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text("Helta: manje → više")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            CategoryExpandedView(items: TowerKind.allCases.map { kind in
                CategoryExpandedItem(
                    assetName: "towers",
                    systemName: kind.systemImage,
                    labelKey: kind.localeKey,
                    action: { onSelect(kind.objectId) },
                    isHighlighted: gameState.selectedPlacementObjectId == kind.objectId,
                    highlightColor: .yellow
                )
            })
        }
    }
}
