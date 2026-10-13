//
//  AILordsMenuView.swift
//  Feudalism
//
//  Pregled AI lordova. Profili već postoje; ovdje se samo prikazuju.
//

import SwiftUI

struct AILordsMenuView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var profileStore = AILordProfileStore.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            menuBackHeader(titleKey: "menu_ai_lords", language: gameState.appLanguage) {
                isPresented = false
            }

            Text(LocalizedStrings.string(for: "ai_lords_intro", language: gameState.appLanguage))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)

            Text(notebookSummary)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(profileStore.profiles) { profile in
                        lordCard(profile)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private var notebookSummary: String {
        let rules = profileStore.notebook.rules
        let format = LocalizedStrings.string(for: "ai_notebook_rules_shared", language: gameState.appLanguage)
        let vocabulary = profileStore.notebook.vocabulary
        let vocabFormat = LocalizedStrings.string(for: "ai_notebook_vocabulary", language: gameState.appLanguage)
        let actionFormat = LocalizedStrings.string(for: "ai_notebook_actions", language: gameState.appLanguage)
        let houseFormat = LocalizedStrings.string(for: "ai_notebook_people_per_house", language: gameState.appLanguage)
        return String(format: format, rules.buildings.count, rules.goods.count) + " · "
            + String(format: actionFormat, rules.actions.count) + " · "
            + String(format: vocabFormat, vocabulary.tokens.count, vocabulary.actions.count) + " · "
            + String(format: houseFormat, profileStore.notebook.peoplePerHouse)
    }

    private func lordCard(_ profile: AILordProfile) -> some View {
        let language = gameState.appLanguage
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: profile.displayIconName)
                .font(.system(size: 26))
                .foregroundStyle(Color(hex: profile.displayColorHex) ?? .gray)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.localizedName(language: language))
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(.white.opacity(0.95))
                Text(profile.localizedDescription(language: language))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                Text(styleLine(profile, language: language))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text(levelLine(profile, language: language))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func styleLine(_ profile: AILordProfile, language: AppLanguage) -> String {
        let style = LocalizedStrings.string(for: profile.fightingStyle.localizationKey, language: language)
        let focus = LocalizedStrings.string(for: profile.strategyFocus.localizationKey, language: language)
        return "\(style) · \(focus)"
    }

    private func levelLine(_ profile: AILordProfile, language: AppLanguage) -> String {
        let label = LocalizedStrings.string(for: "ai_stat_level", language: language)
        let value = profileStore.level(for: profile).value
        let params = profileStore.weights(for: profile)?.parameterCount ?? 0
        let format = LocalizedStrings.string(for: "ai_stat_params", language: language)
        return "\(label) \(String(format: "%.1f", value)) · \(String(format: format, params))"
    }
}
