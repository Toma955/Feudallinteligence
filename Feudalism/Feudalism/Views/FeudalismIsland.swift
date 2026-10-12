//
//  FeudalismIsland.swift
//  Feudallinteligence
//
//  Zaobljeni crni panel s obrubom (kao Alexandria Island). Na približavanje (hover) se širi
//  i prikazuje gumbe: Power, Bluetooth mode, Log, Fast game. Kasnije se može proširiti.
//

import SwiftUI
import AppKit

/// Island u HUD-u: zatvoren = mali pill s naslovom, na hover se širi i pokazuje Power, Bluetooth, Log, Fast game.
struct FeudalismIsland: View {
    @Binding var powerMode: Bool
    @Binding var bleEnabled: Bool
    @Binding var showLogPanel: Bool
    @Binding var fastGame: Bool

    @State private var isExpanded = false
    private let accentColor = Color.orange

    private let collapsedWidth: CGFloat = 120
    private let expandedWidth: CGFloat = 360

    var body: some View {
        HStack(spacing: 12) {
            if isExpanded {
                islandButtons
            }
        }
        .padding(.horizontal, isExpanded ? 14 : 8)
        .padding(.vertical, 6)
        .frame(width: isExpanded ? expandedWidth : collapsedWidth, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(accentColor.opacity(0.9), lineWidth: 1.2)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
        .onHover { hovering in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded = hovering
            }
        }
        .overlay {
            if !isExpanded {
                Text("Feudallinteligence")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var islandButtons: some View {
        HStack(spacing: 10) {
            IslandToggleButton(
                icon: "power",
                label: "Power",
                isOn: $powerMode,
                accentColor: accentColor
            )
            IslandToggleButton(
                icon: "antenna.radiowaves.left.and.right",
                label: "Bluetooth",
                isOn: $bleEnabled,
                accentColor: accentColor
            )
            Button {
                showLogPanel.toggle()
            } label: {
                IslandLabelView(icon: "doc.text", label: "Log", accentColor: accentColor)
            }
            .buttonStyle(.plain)
            .help("Log")
            IslandToggleButton(
                icon: "forward.fill",
                label: "Fast game",
                isOn: $fastGame,
                accentColor: accentColor
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toggle gumb (Power, Bluetooth, Fast game)
private struct IslandToggleButton: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let accentColor: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            IslandLabelView(icon: icon, label: label, accentColor: accentColor, isActive: isOn)
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Ikona + label (za toggle i Log)
private struct IslandLabelView: View {
    let icon: String
    let label: String
    let accentColor: Color
    var isActive: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? accentColor : .white.opacity(0.85))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? accentColor : .white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovered ? 0.14 : 0.08))
        )
        .onHover { isHovered = $0 }
    }
}

let menuIslandMotion = Animation.spring(response: 0.52, dampingFraction: 0.78, blendDuration: 0.18)

/// Gornji island na početnom zaslonu. Zatvoren = Feudallinteligence.
/// Otvoren: krug slike preko 2 reda, ime gore na sredini, botuni ispod.
/// Gubi fokus (miš van / klik van) → uvlači se natrag.
struct MenuBrandIsland: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isExpanded: Bool
    var onMultiplayer: () -> Void
    var onTraining: () -> Void
    var onHistory: () -> Void
    var onFriends: () -> Void
    var onPickAvatar: () -> Void
    /// Kad je postavljen, island je Solo graditelj: klik otvara Resursi i Uvezi mapu.
    var soloTitle: String? = nil
    var soloResourcesTitle: String = "Resursi"
    var soloImportTitle: String = "Uvezi mapu"
    var soloResourcesOn: Bool = false
    var onSoloResources: (() -> Void)? = nil
    var onSoloImport: (() -> Void)? = nil
    /// Kad je postavljen, island piše About i otvara Informacije, Kako igrati i Elemente igre.
    var aboutTitle: String? = nil
    var aboutInfoTitle: String = "Informacije"
    var aboutHowToTitle: String = "Kako igrati"
    var aboutElementsTitle: String = "Elementi igre"
    var onAboutInfo: (() -> Void)? = nil
    var onAboutHowTo: (() -> Void)? = nil
    var onAboutElements: (() -> Void)? = nil

    @State private var collapseTask: Task<Void, Never>?

    private let accent = Color.orange
    private let avatarSize: CGFloat = 72

    var body: some View {
        HStack(alignment: .center, spacing: isExpanded ? 14 : 0) {
            if isExpanded, soloTitle == nil, aboutTitle == nil {
                avatarButton
                    .transition(pullOut(from: .leading))
            }

            VStack(spacing: isExpanded ? 8 : 0) {
                if isExpanded, soloTitle != nil {
                    soloExpanded
                        .transition(pullDown)
                } else if isExpanded, aboutTitle != nil {
                    aboutExpanded
                        .transition(pullDown)
                } else if isExpanded {
                    nameRow
                        .transition(pullOut(from: .top))
                    buttonsRow
                        .transition(pullDown)
                } else {
                    collapsedTitle
                        .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .top)))
                }
            }
        }
        .padding(.leading, isExpanded ? 10 : 22)
        .padding(.trailing, isExpanded ? 16 : 22)
        .padding(.vertical, isExpanded ? 8 : 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 26 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 30, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: isExpanded ? 16 : 12, y: isExpanded ? 8 : 6)
        .fixedSize()
        .animation(menuIslandMotion, value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: gameState.powerMode)
        .onHover { hovering in
            hoverChanged(hovering)
        }
        .onDisappear {
            collapseTask?.cancel()
        }
    }

    private var collapsedTitle: some View {
        Button(action: expand) {
            Text(aboutTitle ?? soloTitle ?? "Feudallinteligence")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }

    private var soloExpanded: some View {
        VStack(spacing: 8) {
            Text(soloTitle ?? "")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
            HStack(spacing: 8) {
                soloActionButton(soloResourcesTitle, active: soloResourcesOn, id: "solo_section_resursi") {
                    onSoloResources?()
                }
                soloActionButton(soloImportTitle, active: false, id: "solo_import_map") {
                    onSoloImport?()
                }
            }
        }
    }

    private var aboutExpanded: some View {
        VStack(spacing: 8) {
            Text(aboutTitle ?? "")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
            HStack(spacing: 8) {
                aboutIconButton("info.circle.fill", aboutInfoTitle, active: false, id: "about_info") {
                    onAboutInfo?()
                }
                aboutIconButton("book.fill", aboutHowToTitle, active: false, id: "about_how_to") {
                    onAboutHowTo?()
                }
                aboutIconButton("square.grid.2x2.fill", aboutElementsTitle, active: true, id: "about_elements") {
                    onAboutElements?()
                }
            }
        }
    }

    private func aboutIconButton(_ icon: String, _ title: String, active: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? Color.green : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(active ? Color.green.opacity(0.22) : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func soloActionButton(_ title: String, active: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? Color.green.opacity(0.9) : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var avatarButton: some View {
        Button(action: onPickAvatar) {
            ZStack {
                Circle().fill(Color.white.opacity(0.1))
                if let image = avatarImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: PlayerEmblem(rawValue: gameState.playerEmblemId)?.sfSymbolName ?? "person.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1.4))
        }
        .buttonStyle(.plain)
        .help(LocalizedStrings.string(for: "menu_pick_avatar", language: gameState.appLanguage))
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(gameState.playerGivenName)
                .font(.custom("Georgia", size: 18))
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.98))
            if !gameState.playerFamilyName.isEmpty {
                Text(gameState.playerFamilyName)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.78))
            }
            Button(action: collapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var buttonsRow: some View {
        HStack(spacing: 6) {
            islandButton(icon: "person.2.fill", titleKey: "island_multiplayer", action: onMultiplayer)
            ecoButton
            islandButton(icon: "sportscourt.fill", titleKey: "island_training", action: onTraining)
            islandButton(icon: "text.alignleft", titleKey: "island_history", action: onHistory)
            islandButton(icon: "person.crop.circle.badge.plus", titleKey: "island_friends", action: onFriends)
        }
    }

    private func pullOut(from edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.72, anchor: .top)).combined(with: .move(edge: edge)),
            removal: .opacity.combined(with: .scale(scale: 0.78, anchor: .top))
        )
    }

    private var pullDown: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.84, anchor: .top)).combined(with: .offset(y: 10)),
            removal: .opacity.combined(with: .scale(scale: 0.88, anchor: .top)).combined(with: .offset(y: -6))
        )
    }

    private func expand() {
        collapseTask?.cancel()
        withAnimation(menuIslandMotion) { isExpanded = true }
    }

    private func collapse() {
        collapseTask?.cancel()
        withAnimation(menuIslandMotion) { isExpanded = false }
    }

    private func hoverChanged(_ hovering: Bool) {
        collapseTask?.cancel()
        collapseTask = nil
        guard !hovering, isExpanded else { return }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            collapse()
        }
    }

    private var avatarImage: NSImage? {
        let path = gameState.playerAvatarPath
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private var ecoButton: some View {
        Button {
            gameState.powerMode.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: gameState.powerMode ? "battery.25" : "battery.100")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gameState.powerMode ? accent : .white.opacity(0.9))
                Text(LocalizedStrings.string(for: "island_eco", language: gameState.appLanguage))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(gameState.powerMode ? accent : .white.opacity(0.92))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(gameState.powerMode ? 0.16 : 0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(LocalizedStrings.string(for: "island_eco", language: gameState.appLanguage))
    }

    private func islandButton(icon: String, titleKey: String, action: @escaping () -> Void) -> some View {
        let title = LocalizedStrings.string(for: titleKey, language: gameState.appLanguage)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct SavedMatchThumb: View {
    var entry: SavedMatchEntry

    var body: some View {
        Canvas { context, size in
            let ground = Path(CGRect(origin: .zero, size: size))
            context.fill(ground, with: .color(Color(red: 0.16, green: 0.28, blue: 0.14)))
            for mark in entry.marks {
                let x = mark.x * size.width
                let y = mark.y * size.height
                let dot = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: dot), with: .color(.yellow.opacity(0.9)))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

struct SavedGamesView: View {
    @EnvironmentObject private var gameState: GameState
    var onStarted: () -> Void
    @State private var entries: [SavedMatchEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text("Nema spremljenih igara.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(entries) { entry in
                            Button {
                                gameState.continueSavedMatch(at: entry.url)
                                onStarted()
                            } label: {
                                VStack(spacing: 6) {
                                    SavedMatchThumb(entry: entry)
                                        .frame(height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text(entry.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { entries = gameState.savedMatchEntries() }
    }
}

#Preview("FeudalismIsland") {
    FeudalismIsland(
        powerMode: .constant(true),
        bleEnabled: .constant(false),
        showLogPanel: .constant(false),
        fastGame: .constant(false)
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
