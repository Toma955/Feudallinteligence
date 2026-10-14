//
//  SpecialistPanelView.swift
//  Feudalism
//
//  Rudari / Inženjering: kartice za Rudara i Srednjovjekovnog inženjera.
//  Klik kupi / trenira jednog od slobodnog seljaka.
//

import SwiftUI

struct SpecialistPanelView: View {
    @EnvironmentObject private var gameState: GameState
    let faction: String
    /// Samo tipovi za ovu građevinu (Rudari → rudar, Inženjering → inženjer).
    var types: [SpecialistType]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Label("Slobodnih seljaka: \(gameState.freePeasants(of: faction))", systemImage: "person.3.fill")
                Label("Specijalista: \(specialistCount)", systemImage: "person.fill.checkmark")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 8) {
                ForEach(types) { type in
                    card(type)
                }
            }
        }
    }

    private var specialistCount: Int {
        let allowed = Set(types)
        return gameState.peopleOf(faction: faction).filter {
            $0.role == .specialist && ($0.specialistType.map(allowed.contains) ?? false)
        }.count
    }

    private func card(_ type: SpecialistType) -> some View {
        let problem = gameState.specialistTrainingProblem(type, faction: faction)
        return Button {
            gameState.placementError = gameState.trainSpecialist(type, faction: faction)
        } label: {
            VStack(spacing: 4) {
                SpecialistIcon(type: type, size: 44)
                Text(LocalizedStrings.string(for: type.localeKey, language: gameState.appLanguage))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                goldChip(type.gold)
            }
            .frame(width: 120)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(problem == nil ? 0.12 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(problem == nil ? 0.35 : 0.1), lineWidth: 1))
            .opacity(problem == nil ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .help(problem ?? "\(type.displayName): \(type.gold) zlata + 1 osoba")
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
}

struct SpecialistIcon: View {
    let type: SpecialistType
    var size: CGFloat = 44

    private let skin = Color(red: 0.9, green: 0.73, blue: 0.58)

    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.25, green: 0.17, blue: 0.1))
                .frame(width: size * 0.1, height: size * 0.3)
                .offset(x: -size * 0.07, y: size * 0.32)
            Capsule().fill(Color(red: 0.25, green: 0.17, blue: 0.1))
                .frame(width: size * 0.1, height: size * 0.3)
                .offset(x: size * 0.07, y: size * 0.32)
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(type == .miner ? Color(red: 0.45, green: 0.38, blue: 0.28) : Color(red: 0.28, green: 0.36, blue: 0.48))
                .frame(width: size * 0.3, height: size * 0.36)
                .offset(y: size * 0.06)
            Circle().fill(skin)
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(y: -size * 0.21)
            Image(systemName: type.systemImage)
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .offset(x: size * 0.26, y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}
