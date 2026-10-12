//
//  SimulatorView.swift
//  Feudalism
//
//  Tekstualna partija: AI protiv AI, bez mape i 3D sučelja. Ista pravila, brži sat.
//

import SwiftUI

struct SimulatorView: View {
    @EnvironmentObject private var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    gameState.showMainMenu()
                } label: {
                    Label(L("menu_back"), systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("sim_title_ai"))
                    .font(.custom("Georgia", size: 26))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(L("sim_turn")) \(gameState.currentTurn) · \(L("sim_speed"))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(gameState.campaign.type.displayName + " — " + gameState.campaign.type.goalText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))

            if let result = gameState.campaignResult {
                Text("\(result.title) — \(result.detail)")
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(result.playerWon ? Color.yellow : Color.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            lordTable

            Text(L("sim_log"))
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.9))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(gameState.matchLog) { line in
                            Text("[\(line.turn)] \(line.text)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                }
                .onChange(of: gameState.matchLog.last?.id) { id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }

    private var lordTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(gameState.realmSeats.seats, id: \.id) { seat in
                let peopleCount = gameState.peopleOf(faction: seat.id).count
                let gold = gameState.goodAmount(.gold, of: seat.id)
                let happy = Int(gameState.happinessPercent(of: seat.id).rounded())
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: seat.colorHex) ?? .gray).frame(width: 12, height: 12)
                    Text(seat.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 90, alignment: .leading)
                    Text("\(peopleCount) \(L("sim_people"))")
                    Text("\(gold) \(L("sim_gold").lowercased())")
                    Text("\(happy)%")
                    if gameState.campaign.type == .economic {
                        Text("\(L("sim_treasury")) \(gameState.treasuryPaid(by: seat.id).formatted())")
                    }
                    Spacer()
                    Text(seat.kingAlive ? L("sim_king_alive") : L("sim_king_dead"))
                        .foregroundStyle(seat.kingAlive ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func L(_ key: String) -> String {
        LocalizedStrings.string(for: key, language: gameState.appLanguage)
    }
}
