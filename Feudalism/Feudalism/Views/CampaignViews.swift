//
//  CampaignViews.swift
//  Feudalism
//
//  Izbor kampanje prije partije, riznica (tajna uplata), diplomacija i kraj partije.
//

import SwiftUI

/// Prije partije: vojna ili ekonomska kampanja i iznos za ekonomsku pobjedu.
struct CampaignSetupSection: View {
    @Binding var campaign: CampaignSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kampanja")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 10) {
                ForEach(CampaignType.allCases) { type in
                    Button {
                        campaign.type = type
                    } label: {
                        Label(type.displayName, systemImage: type == .military ? "shield.lefthalf.filled" : "dollarsign.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(campaign.type == type ? Color.green.opacity(0.75) : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(campaign.type.goalText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            if campaign.type == .economic {
                HStack(spacing: 8) {
                    Text("Iznos za pobjedu:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    ForEach(CampaignSettings.targetOptions, id: \.self) { amount in
                        Button {
                            campaign.economicTarget = amount
                        } label: {
                            Text(amount.formatted())
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(campaign.economicTarget == amount ? .black : .yellow)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(campaign.economicTarget == amount ? Color.yellow : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// Riznica: uplaćuješ zlato malo po malo ili odjednom. Drugi ne vide koliko si uplatio.
struct TreasuryPanel: View {
    @EnvironmentObject private var gameState: GameState
    let onClose: () -> Void

    var body: some View {
        let target = gameState.campaign.economicTarget
        let paid = gameState.playerTreasuryPaid
        let gold = gameState.playerSeat.map { gameState.goodAmount(.gold, of: $0.id) } ?? 0
        VStack(alignment: .leading, spacing: 10) {
            header("Riznica", icon: "building.columns.fill")
            Text("Uplaćeno: \(paid.formatted()) / \(target.formatted())")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)
            ProgressView(value: Double(min(paid, target)), total: Double(max(1, target)))
                .tint(.yellow)
            Text("Zlato na zalihi: \(gold.formatted())")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 6) {
                ForEach([10, 100, 1000, 10_000], id: \.self) { amount in
                    depositButton("+\(amount.formatted())", amount: amount, enabled: gold > 0)
                }
                depositButton("Sve", amount: gold, enabled: gold > 0)
            }
            Text("Uplata je tajna – nitko ne zna koliko si uplatio. Uplaćeno zlato se ne vraća.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(14)
        .frame(width: 330)
        .background(Color(white: 0.08, opacity: 0.92), in: RoundedRectangle(cornerRadius: 10))
    }

    private func depositButton(_ title: String, amount: Int, enabled: Bool) -> some View {
        Button {
            gameState.placementError = gameState.depositToTreasury(amount)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(enabled ? 1 : 0.35), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func header(_ title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Diplomacija: tko ti je prijatelj, a tko neprijatelj. U vojnoj kampanji samo za čitanje.
struct DiplomacyPanel: View {
    @EnvironmentObject private var gameState: GameState
    let onClose: () -> Void

    var body: some View {
        let me = gameState.playerSeat?.id
        let others = gameState.realmSeats.seats.filter { $0.id != me }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Diplomacija", systemImage: "person.2.wave.2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Text(gameState.campaign.relationsFixed
                 ? "Vojna kampanja: tko ti je neprijatelj ne mijenja se."
                 : "Ekonomska kampanja: savezi se mogu mijenjati.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            if others.isEmpty {
                Text("Nema drugih dvoraca.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            ForEach(others, id: \.id) { seat in
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: seat.colorHex) ?? .gray).frame(width: 12, height: 12)
                    Text(seat.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(seat.kingAlive ? .white : .white.opacity(0.4))
                        .strikethrough(!seat.kingAlive)
                    Spacer()
                    if let me {
                        relationControl(me: me, other: seat.id)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(Color(white: 0.08, opacity: 0.92), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func relationControl(me: String, other: String) -> some View {
        let current = gameState.relation(between: me, and: other)
        if gameState.campaign.relationsFixed {
            Text(current.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color(current))
        } else {
            HStack(spacing: 4) {
                ForEach(FactionRelation.allCases) { relation in
                    Button {
                        gameState.placementError = gameState.setRelation(relation, between: me, and: other)
                    } label: {
                        Text(relation.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(current == relation ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(current == relation ? color(relation) : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func color(_ relation: FactionRelation) -> Color {
        switch relation {
        case .enemy: return .red
        case .neutral: return .gray
        case .ally: return .green
        }
    }
}

/// Kraj partije: pobjeda ili poraz.
struct CampaignResultOverlay: View {
    @EnvironmentObject private var gameState: GameState
    let result: CampaignResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: result.playerWon ? "crown.fill" : "flag.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(result.playerWon ? .yellow : .red)
                Text(result.title)
                    .font(.custom("Georgia", size: 34))
                    .foregroundStyle(.white)
                Text(result.detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                Text(gameState.campaign.type.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                Button {
                    gameState.showMainMenu()
                } label: {
                    Text("Glavni izbornik")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(Color(white: 0.08, opacity: 0.95), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
