//
//  HUDMessageStrip.swift
//  Feudalism
//
//  Poruke ispod gornjeg islanda. Nema skočnih prozora – sve ide ovdje.
//

import SwiftUI

struct HUDMessageStrip: View {
    @EnvironmentObject private var gameState: GameState

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(gameState.hudMessages.prefix(3))) { msg in
                row(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: msg.id) {
                        try? await Task.sleep(nanoseconds: 5_500_000_000)
                        gameState.dismissHUD(msg.id)
                    }
            }
        }
        .frame(maxWidth: 720)
        .animation(.easeInOut(duration: 0.22), value: gameState.hudMessages.map(\.id))
    }

    private func row(_ msg: HUDMessage) -> some View {
        let tint = Color(red: msg.kind.tint.r, green: msg.kind.tint.g, blue: msg.kind.tint.b)
        return HStack(spacing: 8) {
            Image(systemName: msg.kind.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(msg.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
            Spacer(minLength: 4)
            Button {
                gameState.dismissHUD(msg.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 2)
    }
}

struct BottomBarIslandChrome: View {
    @EnvironmentObject private var gameState: GameState
    var corner: CGFloat = 20

    var body: some View {
        let alpha = gameState.bottomBarOpacity
        RoundedRectangle(cornerRadius: corner)
            .fill(.ultraThinMaterial)
            .opacity(alpha)
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.black.opacity(0.20 * alpha))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white.opacity(0.25 * alpha), lineWidth: 1)
            )
    }
}
