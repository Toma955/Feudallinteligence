//
//  CategoryExpandedView.swift
//  Feudalism
//
//  Jedan generički view za prošireni sadržaj kategorije donjeg bara: red ikona + red natpisa.
//  Zamjenjuje duplicirani layout u Castle, Food, House, Mine, Sword, Tools.
//

import SwiftUI

/// Jedna stavka u proširenom izborniku: ikona (asset ili SF Symbol), natpis, akcija; opcionalno highlight (npr. za Alati).
struct CategoryExpandedItem {
    let assetName: String
    let systemName: String
    let labelKey: String
    let action: () -> Void
    var isHighlighted: Bool = false
    var highlightColor: Color = .green
    /// Nacrtana ikona (bez asseta), ima prednost pred assetom i SF Symbolom.
    var customIcon: AnyView? = nil
    /// Crnu linijsku PNG ikonu oboji foreground bojom.
    var asTemplate: Bool = false
}

/// Prošireni sadržaj kategorije: HStack ikona, ispod HStack natpisa. Koristi BarIconCache za ikone.
struct CategoryExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    let items: [CategoryExpandedItem]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    categoryButton(item: item)
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    categoryLabel(item: item)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func categoryButton(item: CategoryExpandedItem) -> some View {
        Button(action: item.action) {
            Group {
                if let custom = item.customIcon {
                    custom
                } else if let img = BarIconCache.shared.image(named: item.assetName, bundle: .main) {
                    Image(nsImage: templateCopy(img, enabled: item.asTemplate))
                        .resizable()
                        .renderingMode(item.asTemplate ? .template : .original)
                        .scaledToFit()
                } else {
                    Image(systemName: item.systemName)
                        .font(.system(size: 28))
                }
            }
            .frame(width: 36, height: 36)
            .foregroundStyle(item.isHighlighted ? item.highlightColor : .white.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(item.isHighlighted ? item.highlightColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func categoryLabel(item: CategoryExpandedItem) -> some View {
        Text(LocalizedStrings.string(for: item.labelKey, language: gameState.appLanguage))
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { item.action() }
    }
}
