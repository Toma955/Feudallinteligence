//
//  CampaignMenuView.swift
//  Feudalism
//
//  Ulaz u kampanju. Misije još nisu u igri — ekran je spreman za kasniji katalog.
//

import SwiftUI

struct CampaignMenuView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @State private var showRecordings = false

    var body: some View {
        VStack(spacing: 28) {
            menuBackHeader(titleKey: "menu_campaign", language: gameState.appLanguage) {
                isPresented = false
            }

            if showRecordings {
                MatchHistoryView()
                    .environmentObject(gameState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    MatchRecordBar { showRecordings = true }
                    Image(systemName: "flag.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(LocalizedStrings.string(for: "campaign_placeholder_title", language: gameState.appLanguage))
                        .font(.custom("Georgia", size: 22))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                    Text(LocalizedStrings.string(for: "campaign_placeholder_body", language: gameState.appLanguage))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
