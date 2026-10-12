//
//  PlantsButtonExpandedView.swift
//  Feudalism
//
//  Biljke (map editor): stabla koja se mogu posjeći.
//

import SwiftUI

struct TreeIcon: View {
    var size: CGFloat = 36
    var trunk = Color(red: 0.36, green: 0.24, blue: 0.14)
    var leaf = Color(red: 0.22, green: 0.48, blue: 0.18)
    var leafLight = Color(red: 0.42, green: 0.66, blue: 0.26)

    var body: some View {
        let s = size
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.04)
                .fill(LinearGradient(colors: [trunk, trunk.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                .frame(width: s * 0.14, height: s * 0.42)
                .offset(y: s * 0.27)
            Circle()
                .fill(leaf)
                .frame(width: s * 0.46, height: s * 0.46)
                .offset(x: -s * 0.18, y: -s * 0.02)
            Circle()
                .fill(leaf)
                .frame(width: s * 0.44, height: s * 0.44)
                .offset(x: s * 0.18, y: 0)
            Circle()
                .fill(LinearGradient(colors: [leafLight, leaf], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: s * 0.58, height: s * 0.58)
                .offset(y: -s * 0.17)
        }
        .frame(width: s, height: s)
    }
}

struct OakIcon: View {
    var size: CGFloat = 36
    var body: some View {
        TreeIcon(
            size: size,
            trunk: Color(red: 0.28, green: 0.18, blue: 0.10),
            leaf: Color(red: 0.16, green: 0.38, blue: 0.12),
            leafLight: Color(red: 0.30, green: 0.50, blue: 0.16)
        )
    }
}

struct FirIcon: View {
    var size: CGFloat = 36
    var body: some View {
        let s = size
        ZStack {
            Rectangle()
                .fill(Color(red: 0.30, green: 0.20, blue: 0.12))
                .frame(width: s * 0.10, height: s * 0.28)
                .offset(y: s * 0.32)
            Triangle()
                .fill(Color(red: 0.10, green: 0.32, blue: 0.16))
                .frame(width: s * 0.72, height: s * 0.34)
                .offset(y: s * 0.14)
            Triangle()
                .fill(Color(red: 0.16, green: 0.40, blue: 0.18))
                .frame(width: s * 0.58, height: s * 0.30)
                .offset(y: -s * 0.04)
            Triangle()
                .fill(Color(red: 0.22, green: 0.48, blue: 0.22))
                .frame(width: s * 0.40, height: s * 0.26)
                .offset(y: -s * 0.22)
        }
        .frame(width: s, height: s)
    }
}

struct CypressIcon: View {
    var size: CGFloat = 36
    var body: some View {
        let s = size
        ZStack {
            Capsule()
                .fill(Color(red: 0.18, green: 0.34, blue: 0.16))
                .frame(width: s * 0.28, height: s * 0.86)
            Capsule()
                .fill(Color(red: 0.26, green: 0.44, blue: 0.18).opacity(0.7))
                .frame(width: s * 0.16, height: s * 0.55)
                .offset(y: -s * 0.12)
        }
        .frame(width: s, height: s)
    }
}

struct PalmIcon: View {
    var size: CGFloat = 36
    var body: some View {
        let s = size
        ZStack {
            Capsule()
                .fill(Color(red: 0.48, green: 0.32, blue: 0.16))
                .frame(width: s * 0.10, height: s * 0.58)
                .rotationEffect(.degrees(8))
                .offset(y: s * 0.16)
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? Color(red: 0.22, green: 0.52, blue: 0.18) : Color(red: 0.38, green: 0.64, blue: 0.22))
                    .frame(width: s * 0.10, height: s * 0.36)
                    .rotationEffect(.degrees(Double(i) * 36 - 72))
                    .offset(y: -s * 0.16)
            }
        }
        .frame(width: s, height: s)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

struct RockIcon: View {
    var size: CGFloat = 36
    var scale: CGFloat = 1

    var body: some View {
        let s = size * scale
        let stone = Color(red: 0.48, green: 0.45, blue: 0.40)
        let dark = Color(red: 0.34, green: 0.32, blue: 0.28)
        let light = Color(red: 0.62, green: 0.58, blue: 0.52)
        ZStack {
            Ellipse()
                .fill(dark)
                .frame(width: s * 0.72, height: s * 0.42)
                .offset(x: s * 0.08, y: s * 0.16)
            Ellipse()
                .fill(stone)
                .frame(width: s * 0.78, height: s * 0.48)
                .offset(y: s * 0.04)
            Ellipse()
                .fill(light)
                .frame(width: s * 0.42, height: s * 0.28)
                .offset(x: -s * 0.12, y: -s * 0.08)
        }
        .frame(width: size, height: size)
    }
}

struct PlantsButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "tree", systemName: "leaf.fill", labelKey: "plant_tree", action: { select(Tree.objectId) }, customIcon: AnyView(TreeIcon(size: 36))),
            CategoryExpandedItem(assetName: "oak", systemName: "leaf.fill", labelKey: "plant_oak", action: { select(Oak.objectId) }, customIcon: AnyView(OakIcon(size: 36))),
            CategoryExpandedItem(assetName: "fir", systemName: "triangle.fill", labelKey: "plant_fir", action: { select(Fir.objectId) }, customIcon: AnyView(FirIcon(size: 36))),
            CategoryExpandedItem(assetName: "cypress", systemName: "leaf.fill", labelKey: "plant_cypress", action: { select(Cypress.objectId) }, customIcon: AnyView(CypressIcon(size: 36))),
            CategoryExpandedItem(assetName: "palm", systemName: "leaf.fill", labelKey: "plant_palm", action: { select(Palm.objectId) }, customIcon: AnyView(PalmIcon(size: 36))),
            CategoryExpandedItem(assetName: "stone_resource", systemName: "circle.fill", labelKey: "plant_rock_small", action: { select(SmallRock.objectId) }, customIcon: AnyView(RockIcon(size: 36, scale: 0.62))),
            CategoryExpandedItem(assetName: "stone_resource", systemName: "circle.fill", labelKey: "plant_rock_medium", action: { select(MediumRock.objectId) }, customIcon: AnyView(RockIcon(size: 36, scale: 0.82))),
            CategoryExpandedItem(assetName: "stone_resource", systemName: "circle.fill", labelKey: "plant_rock_large", action: { select(LargeRock.objectId) }, customIcon: AnyView(RockIcon(size: 36, scale: 1))),
        ])
        .frame(maxWidth: 620)
    }

    private func select(_ objectId: String) {
        gameState.selectedPlacementObjectId = objectId
    }
}
