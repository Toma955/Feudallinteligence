//
//  TrainingPanelView.swift
//  Feudalism
//
//  Trening: kartica za svaku vrstu vojnika – slika, potrebna oprema i zlato ispod, brzina.
//  Klik obuči jednog vojnika od slobodnog seljaka; pojavi se ispred Treninga.
//

import SwiftUI

struct TrainingPanelView: View {
    @EnvironmentObject private var gameState: GameState
    let faction: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Label("Slobodnih seljaka: \(gameState.freePeasants(of: faction))", systemImage: "person.3.fill")
                Label("Vojnika: \(soldierCount)", systemImage: "shield.lefthalf.filled")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SoldierType.allCases) { type in
                        card(type)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var soldierCount: Int {
        gameState.peopleOf(faction: faction).filter { $0.role == .soldier }.count
    }

    private func card(_ type: SoldierType) -> some View {
        let problem = gameState.trainingProblem(type, faction: faction)
        return Button {
            gameState.placementError = gameState.trainSoldier(type, faction: faction)
        } label: {
            VStack(spacing: 4) {
                SoldierIcon(type: type, size: 44)
                Text(type.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.85))
                    ForEach(type.equipment.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { good in
                        equipmentChip(good)
                    }
                    goldChip(type.gold)
                }
                Text(type.speedText)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 104)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(problem == nil ? 0.12 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(problem == nil ? 0.35 : 0.1), lineWidth: 1))
            .opacity(problem == nil ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .help(problem ?? "\(type.displayName): \(PriceList.soldierPrice(type).description) + 1 osoba · \(type.speedText) · izdržljivost \(type.health)")
    }

    private func equipmentChip(_ good: Good) -> some View {
        let have = gameState.goodAmount(good, of: faction)
        return BarIconView(assetName: Self.iconAsset(good), systemName: Self.iconSymbol(good), size: 16)
            .opacity(have > 0 ? 1 : 0.35)
            .help("\(good.displayName): ima \(have)")
    }

    private func goldChip(_ amount: Int) -> some View {
        let enough = gameState.goodAmount(.gold, of: faction) >= amount
        return HStack(spacing: 1) {
            BarIconView(assetName: "gold", systemName: "dollarsign.circle.fill", size: 14)
            Text("\(amount)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(enough ? Color.yellow : Color.red)
        }
    }

    static func iconAsset(_ good: Good) -> String {
        switch good {
        case .bow: return "bow_and_sparrow_resouce"
        case .shield: return "shield_resource"
        case .sword: return "sword_resource"
        case .spear: return "spear_resource"
        case .leather: return "leather_resources"
        case .horse: return "horse_resource"
        default: return good.rawValue
        }
    }

    static func iconSymbol(_ good: Good) -> String {
        switch good {
        case .bow: return "arrow.up.right"
        case .shield: return "shield.fill"
        case .sword: return "line.diagonal"
        case .spear: return "line.diagonal.arrow"
        case .leather: return "square.fill"
        case .horse: return "hare.fill"
        default: return "cube.fill"
        }
    }
}

/// Nacrtan vojnik: tunika, kaciga, glavno oružje; štit i oklop ako ih vrsta ima. Konjanik sjedi na konju.
struct SoldierIcon: View {
    let type: SoldierType
    var size: CGFloat = 44

    private let skin = Color(red: 0.9, green: 0.73, blue: 0.58)
    private let iron = Color(white: 0.7)
    private let wood = Color(red: 0.5, green: 0.32, blue: 0.16)
    private let tunic = Color(red: 0.62, green: 0.16, blue: 0.14)

    private let horseColor = Color(red: 0.45, green: 0.28, blue: 0.15)

    var body: some View {
        if type.isMounted {
            ZStack {
                horse(size)
                figure(size * 0.7)
                    .offset(x: size * 0.02, y: -size * 0.2)
            }
            .frame(width: size, height: size)
        } else {
            figure(size)
        }
    }

    private func horse(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(horseColor.opacity(i % 2 == 0 ? 1 : 0.8))
                    .frame(width: s * 0.06, height: s * 0.26)
                    .offset(x: s * (-0.24 + CGFloat(i) * 0.15), y: s * 0.34)
            }
            Ellipse().fill(horseColor)
                .frame(width: s * 0.68, height: s * 0.28)
                .offset(y: s * 0.16)
            Capsule().fill(horseColor)
                .frame(width: s * 0.14, height: s * 0.32)
                .rotationEffect(.degrees(30))
                .offset(x: s * 0.33, y: -s * 0.02)
            Capsule().fill(horseColor)
                .frame(width: s * 0.22, height: s * 0.11)
                .rotationEffect(.degrees(25))
                .offset(x: s * 0.42, y: -s * 0.14)
            Capsule().fill(Color(red: 0.2, green: 0.12, blue: 0.07))
                .frame(width: s * 0.05, height: s * 0.24)
                .rotationEffect(.degrees(-25))
                .offset(x: -s * 0.36, y: s * 0.18)
        }
        .frame(width: s, height: s)
    }

    private func figure(_ s: CGFloat) -> some View {
        ZStack {
            Capsule().fill(Color(red: 0.25, green: 0.17, blue: 0.1))
                .frame(width: s * 0.1, height: s * 0.3)
                .offset(x: -s * 0.07, y: s * 0.32)
            Capsule().fill(Color(red: 0.25, green: 0.17, blue: 0.1))
                .frame(width: s * 0.1, height: s * 0.3)
                .offset(x: s * 0.07, y: s * 0.32)
            RoundedRectangle(cornerRadius: s * 0.06)
                .fill(type.hasArmor ? iron.opacity(0.85) : tunic)
                .frame(width: s * 0.3, height: s * 0.36)
                .offset(y: s * 0.06)
            if type.hasArmor {
                RoundedRectangle(cornerRadius: s * 0.03)
                    .fill(tunic)
                    .frame(width: s * 0.12, height: s * 0.3)
                    .offset(y: s * 0.07)
            }
            Circle().fill(skin)
                .frame(width: s * 0.2, height: s * 0.2)
                .offset(y: -s * 0.21)
            HelmetShape()
                .fill(iron)
                .frame(width: s * 0.24, height: s * 0.13)
                .offset(y: -s * 0.28)
            weapon(s)
            if type.hasShield {
                Ellipse()
                    .fill(LinearGradient(colors: [tunic, tunic.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .overlay(Ellipse().stroke(iron, lineWidth: s * 0.03))
                    .frame(width: s * 0.26, height: s * 0.34)
                    .offset(x: -s * 0.22, y: s * 0.06)
            }
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder
    private func weapon(_ s: CGFloat) -> some View {
        switch type.mainWeapon {
        case .bow:
            BowShape()
                .stroke(wood, lineWidth: s * 0.045)
                .frame(width: s * 0.2, height: s * 0.62)
                .offset(x: s * 0.27, y: 0)
            Rectangle().fill(.white.opacity(0.7))
                .frame(width: s * 0.012, height: s * 0.58)
                .offset(x: s * 0.2, y: 0)
        case .spear:
            Rectangle().fill(wood)
                .frame(width: s * 0.04, height: s * 0.86)
                .offset(x: s * 0.24, y: 0)
            Triangle().fill(iron)
                .frame(width: s * 0.1, height: s * 0.14)
                .offset(x: s * 0.24, y: -s * 0.47)
        default:
            Rectangle().fill(iron)
                .frame(width: s * 0.05, height: s * 0.42)
                .offset(x: s * 0.25, y: -s * 0.08)
            Rectangle().fill(wood)
                .frame(width: s * 0.16, height: s * 0.04)
                .offset(x: s * 0.25, y: s * 0.13)
        }
    }
}

private struct HelmetShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        p.closeSubpath()
        return p
    }
}

private struct BowShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.maxX * 1.6, y: r.midY))
        return p
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
