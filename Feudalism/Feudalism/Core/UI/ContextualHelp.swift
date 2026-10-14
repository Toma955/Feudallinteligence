//
//  ContextualHelp.swift
//  Feudalism
//
//  Kratice: hover → mali natpis ispod islanda; nakon 10 s → info gumb → ekran objašnjenja.
//

import Foundation
import SwiftUI
import Combine

/// Tema kratice (kartica / ikona / resurs).
enum ContextualHelpID: String, CaseIterable, Identifiable {
    case islandMultiplayer
    case islandPower
    case islandTraining
    case islandHistory
    case islandFriends
    case islandAvatar
    case soloResources
    case soloImport
    case soloPersona
    case aboutInfo
    case aboutHowTo
    case aboutElements

    var id: String { rawValue }

    var titleKey: String { "help_\(rawValue)_title" }
    var shortKey: String { "help_\(rawValue)_short" }
    var detailKey: String { "help_\(rawValue)_detail" }

    func title(language: AppLanguage) -> String {
        LocalizedStrings.string(for: titleKey, language: language)
    }

    func shortCaption(language: AppLanguage) -> String {
        LocalizedStrings.string(for: shortKey, language: language)
    }

    func detail(language: AppLanguage) -> String {
        LocalizedStrings.string(for: detailKey, language: language)
    }
}

/// Trenutni hover: odmah natpis → zadržavanje = info → bez klika 10 s = zatvori.
@MainActor
final class ContextualHelpController: ObservableObject {
    static let shared = ContextualHelpController()

    /// Koliko dugo treba stajati da se natpis pretvori u info gumb.
    static let promoteSeconds: TimeInterval = 1.5
    /// Koliko dugo info gumb smije stajati bez klika (miš i dalje na ikoni) prije zatvaranja.
    static let autoCloseSeconds: TimeInterval = 10

    @Published private(set) var activeID: ContextualHelpID?
    /// True kad se zadržao — natpis postaje info gumb.
    @Published private(set) var showInfoButton = false
    /// Otvoreni ekran objašnjenja.
    @Published var openDetailID: ContextualHelpID?

    private var promoteTask: Task<Void, Never>?
    private var autoCloseTask: Task<Void, Never>?
    /// Nakon auto-zatvaranja ne prikazuj ništa dok miš ne ode s ikone.
    private var suppressedID: ContextualHelpID?

    func begin(_ id: ContextualHelpID) {
        if suppressedID == id { return }
        if activeID == id { return }
        cancelTimers()
        activeID = id
        showInfoButton = false
        promoteTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.promoteSeconds))
            guard !Task.isCancelled, activeID == id else { return }
            showInfoButton = true
            scheduleAutoClose(for: id)
        }
    }

    func end(_ id: ContextualHelpID) {
        if suppressedID == id { suppressedID = nil }
        guard activeID == id else { return }
        cancelTimers()
        activeID = nil
        showInfoButton = false
    }

    func clear() {
        cancelTimers()
        activeID = nil
        showInfoButton = false
        suppressedID = nil
    }

    func openDetail() {
        guard let id = activeID, showInfoButton else { return }
        autoCloseTask?.cancel()
        autoCloseTask = nil
        openDetailID = id
    }

    private func scheduleAutoClose(for id: ContextualHelpID) {
        autoCloseTask?.cancel()
        autoCloseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.autoCloseSeconds))
            guard !Task.isCancelled, activeID == id, showInfoButton, openDetailID == nil else { return }
            // Miš još na ikoni, nije kliknuo → zatvori info (i natpis) do odlaska miša.
            showInfoButton = false
            activeID = nil
            suppressedID = id
        }
    }

    private func cancelTimers() {
        promoteTask?.cancel()
        promoteTask = nil
        autoCloseTask?.cancel()
        autoCloseTask = nil
    }
}

/// Hover: aktivira kraticu (ako je personalizacija upaljena).
struct ContextualHelpHoverModifier: ViewModifier {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var help = ContextualHelpController.shared
    let id: ContextualHelpID

    func body(content: Content) -> some View {
        content.onHover { hovering in
            guard gameState.showContextualShortcuts else {
                if !hovering { help.end(id) }
                return
            }
            if hovering { help.begin(id) } else { help.end(id) }
        }
    }
}

extension View {
    func contextualHelp(_ id: ContextualHelpID) -> some View {
        modifier(ContextualHelpHoverModifier(id: id))
    }
}

/// Mali natpis / info gumb ispod islanda.
struct ContextualHelpCaptionBar: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var help = ContextualHelpController.shared

    var body: some View {
        Group {
            if gameState.showContextualShortcuts, let id = help.activeID {
                if help.showInfoButton {
                    Button {
                        help.openDetail()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(id.title(language: gameState.appLanguage))
                                .font(.system(size: 12, weight: .semibold))
                            Text(LocalizedStrings.string(for: "help_open_info", language: gameState.appLanguage))
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.75)
                        }
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Text(id.shortCaption(language: gameState.appLanguage))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.28), in: Capsule())
                        .transition(.opacity)
                }
            }
        }
        .frame(minHeight: 28)
        .animation(.easeInOut(duration: 0.2), value: help.activeID)
        .animation(.easeInOut(duration: 0.25), value: help.showInfoButton)
    }
}

/// Ekran s punim objašnjenjem.
struct ContextualHelpDetailSheet: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var help = ContextualHelpController.shared

    var body: some View {
        if let id = help.openDetailID {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { help.openDetailID = nil }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.yellow.opacity(0.95))
                        Text(id.title(language: gameState.appLanguage))
                            .font(.custom("Georgia", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.98))
                        Spacer()
                        Button {
                            help.openDetailID = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(8)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    ScrollView {
                        Text(id.detail(language: gameState.appLanguage))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
                .frame(maxWidth: 520, maxHeight: 360)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
            }
            .transition(.opacity)
        }
    }
}
