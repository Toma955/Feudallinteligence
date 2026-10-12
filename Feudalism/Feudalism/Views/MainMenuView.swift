//
//  MainMenuView.swift
//  Feudalism
//
//  Glavni izbornik: mutna vatrena pozadina, stakleni kvadrat s menijem i ikonama.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let glassCornerRadius: CGFloat = 28
private let buttonCornerRadius: CGFloat = 16

private let postavkeCategoryIconSize: CGFloat = 38
private let postavkeBottomBarHeight: CGFloat = 64
/// Okomiti izbornik – stane bez skrola, ostavlja mjesta islandu gore.
private let menuPanelMaxWidth: CGFloat = 520
private let menuPanelMaxHeight: CGFloat = 590
private let menuTileWidth: CGFloat = 440
private let menuTileHeight: CGFloat = 54
private let postavkePanelMaxWidth: CGFloat = 1500
private let postavkePanelMaxHeight: CGFloat = 900
private let soloPanelWidth: CGFloat = 1600
private let soloPanelHeight: CGFloat = 920
private let historyPanelWidth: CGFloat = 1520
private let historyPanelHeight: CGFloat = 880
private let menuPostavkeTransitionDuration: Double = 0.28
private let titleTopPadding: CGFloat = 28

struct MainMenuView: View {
    /// Kad true, naslov se ne crta (npr. u IntroViewu isti natpis animira do vrha).
    var hideTitle: Bool = false

    @EnvironmentObject private var gameState: GameState
    @State private var showPostavke = false
    @State private var showGameSetup = false
    @State private var showSoloSetup = false
    @State private var showCampaign = false
    @State private var showAILords = false
    @State private var showMapEditorChoice = false
    @State private var showAbout = false
    @State private var postavkeSection: PostavkeSection = .general
    @State private var showExitConfirmation = false
    @State private var islandExpanded = false
    @State private var islandPage: MenuIslandPage = .none
    @State private var soloShowResources = false
    @State private var soloImportTick = 0
    @State private var aboutShowHowTo = false
    @State private var aboutInfoTick = 0

    var body: some View {
        ZStack {
            FireBackgroundView()

            // Središnji element – centriran na ekranu (Solo, Nova igra, …)
            VStack(spacing: 0) {
                if showPostavke {
                    embeddedPostavkeContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showSoloSetup {
                    SoloSetupView(
                        isPresented: $showSoloSetup,
                        showResources: $soloShowResources,
                        importTick: soloImportTick
                    )
                        .environmentObject(gameState)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showCampaign {
                    CampaignMenuView(isPresented: $showCampaign)
                        .environmentObject(gameState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showAILords {
                    AILordsMenuView(isPresented: $showAILords)
                        .environmentObject(gameState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showMapEditorChoice {
                    MapEditorChoiceView(isPresented: $showMapEditorChoice)
                        .environmentObject(gameState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showAbout {
                    AboutView(isPresented: $showAbout, showHowTo: $aboutShowHowTo, infoTick: aboutInfoTick)
                        .environmentObject(gameState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if islandPage != .none {
                    islandPageContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else {
                    menuContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                }
            }
            .padding(homeDockPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .frame(maxWidth: activePanelMaxWidth, maxHeight: activePanelMaxHeight)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showPostavke)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showSoloSetup)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showCampaign)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showAILords)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showMapEditorChoice)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showAbout)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: islandPage)
            .padding(.horizontal, isHomeDock ? 24 : 48)
            .padding(.top, isHomeDock ? 88 : 48)
            .padding(.bottom, showSoloSetup ? 0 : (isHomeDock ? 36 : 48))

            if !hideTitle {
                if islandExpanded {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(menuIslandMotion) { islandExpanded = false }
                        }
                }
                MenuBrandIsland(
                    isExpanded: $islandExpanded,
                    onMultiplayer: { openIslandPage(.multiplayer) },
                    onTraining: { openIslandPage(.training) },
                    onHistory: { openIslandPage(.history) },
                    onFriends: { openIslandPage(.friends) },
                    onPickAvatar: pickAvatar,
                    soloTitle: showSoloSetup ? L("menu_solo") : nil,
                    soloResourcesTitle: L("solo_resources"),
                    soloImportTitle: L("solo_import_map"),
                    soloResourcesOn: soloShowResources,
                    onSoloResources: toggleSoloResources,
                    onSoloImport: requestSoloImport,
                    aboutTitle: showAbout ? L("menu_about") : nil,
                    aboutInfoTitle: L("about_info"),
                    aboutHowToTitle: L("about_how_to"),
                    aboutElementsTitle: L("about_elements"),
                    onAboutInfo: openAboutInfo,
                    onAboutHowTo: openAboutHowTo,
                    onAboutElements: openAboutElements
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, titleTopPadding)
            }
        }
        .sheet(isPresented: $showGameSetup) {
            GameSetupView()
                .environmentObject(gameState)
        }
        .onChange(of: showSoloSetup) { open in
            if !open {
                soloShowResources = false
                islandExpanded = false
            }
        }
        .onChange(of: showAbout) { open in
            if !open {
                aboutShowHowTo = false
                islandExpanded = false
            }
        }
    }

    private var isHomeDock: Bool {
        !showPostavke && !showSoloSetup && !showCampaign && !showAILords
            && !showMapEditorChoice && !showAbout && islandPage == .none
    }

    private var homeDockPadding: EdgeInsets {
        if showSoloSetup { return EdgeInsets(top: 72, leading: 72, bottom: 0, trailing: 72) }
        if islandPage == .history { return EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22) }
        if isHomeDock { return EdgeInsets(top: 18, leading: 28, bottom: 18, trailing: 28) }
        return EdgeInsets(top: 48, leading: 48, bottom: 48, trailing: 48)
    }

    private func toggleSoloResources() {
        soloShowResources.toggle()
        withAnimation(menuIslandMotion) { islandExpanded = false }
    }

    private func requestSoloImport() {
        soloImportTick += 1
        withAnimation(menuIslandMotion) { islandExpanded = false }
    }

    private func openAboutInfo() {
        aboutShowHowTo = false
        aboutInfoTick += 1
        withAnimation(menuIslandMotion) { islandExpanded = false }
    }

    private func openAboutHowTo() {
        aboutShowHowTo = true
        withAnimation(menuIslandMotion) { islandExpanded = false }
    }

    private func openAboutElements() {
        aboutShowHowTo = false
        withAnimation(menuIslandMotion) { islandExpanded = false }
    }

    private func openIslandPage(_ page: MenuIslandPage) {
        withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
            showPostavke = false
            showSoloSetup = false
            showCampaign = false
            showAILords = false
            showMapEditorChoice = false
            showAbout = false
            islandPage = page
        }
    }

    private var menuContent: some View {
        VStack(spacing: 8) {
            dockTile(title: L("menu_solo"), icon: "play.circle.fill", id: "menu_solo") {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showSoloSetup = true }
            }
            dockTile(title: L("menu_campaign"), icon: "flag.fill", id: "menu_campaign") {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showCampaign = true }
            }
            dockTile(title: L("menu_new_game"), icon: "plus.circle.fill", id: "menu_new_game") {
                AudioManager.shared.stopIntroSoundtrack()
                showGameSetup = true
            }
            dockTile(title: L("menu_ai_lords"), icon: "person.3.fill", id: "menu_ai_lords") {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showAILords = true }
            }
            dockTile(title: L("menu_map_editor"), icon: "map.fill", id: "menu_map_editor") {
                AudioManager.shared.stopIntroSoundtrack()
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showMapEditorChoice = true }
            }
            dockTile(title: L("menu_settings"), icon: "gearshape.fill", id: "menu_settings") {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showPostavke = true }
            }
            dockTile(title: L("menu_about"), icon: "info.circle.fill", id: "menu_about") {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) { showAbout = true }
            }
            exitTile
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L("menu_pick_avatar")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Feudalism", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder ?? URL(fileURLWithPath: NSTemporaryDirectory()), withIntermediateDirectories: true)
        let dest = (folder ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("avatar.png")
        if let image = NSImage(contentsOf: url),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dest)
            gameState.playerAvatarPath = dest.path
        }
    }

    private var islandPageContent: some View {
        VStack(spacing: islandPage == .history ? 10 : 18) {
            menuBackHeader(titleKey: islandPage.titleKey, language: gameState.appLanguage) {
                withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
                    islandPage = .none
                }
            }
            if islandPage == .history {
                MatchHistoryView()
                    .environmentObject(gameState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer(minLength: 8)
                Image(systemName: islandPage.icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(L("island_coming_soon"))
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 8)
            }
        }
    }

    private var embeddedPostavkeContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
                        showPostavke = false
                    }
                } label: {
                    Label(L("menu_back"), systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text(L("menu_settings"))
                        .font(.custom("Georgia", size: 22))
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.98))
                    Text(postavkeSection.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 12)

            ScrollView {
                PostavkeSectionContent(section: postavkeSection)
                    .environmentObject(gameState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 16) {
                Button {
                    if let prev = postavkeSection.previous { postavkeSection = prev }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    ForEach(PostavkeSection.allCases) { section in
                        Button {
                            postavkeSection = section
                        } label: {
                            Image(systemName: section.icon)
                                .font(.system(size: postavkeCategoryIconSize))
                                .foregroundStyle(section == postavkeSection ? .white : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    if let next = postavkeSection.next { postavkeSection = next }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .frame(height: postavkeBottomBarHeight)
        }
    }

    private func L(_ key: String) -> String {
        LocalizedStrings.string(for: key, language: gameState.appLanguage)
    }

    private var activePanelMaxWidth: CGFloat {
        if showPostavke { return postavkePanelMaxWidth }
        if showSoloSetup { return soloPanelWidth }
        if showAILords { return 1180 }
        if showAbout { return 1500 }
        if islandPage == .history { return historyPanelWidth }
        if islandPage != .none { return 720 }
        if showMapEditorChoice || showCampaign { return 980 }
        return menuPanelMaxWidth
    }

    private var activePanelMaxHeight: CGFloat {
        if showPostavke { return postavkePanelMaxHeight }
        if showSoloSetup { return soloPanelHeight }
        if showAILords { return 820 }
        if showCampaign { return 560 }
        if showAbout { return 860 }
        if showMapEditorChoice { return 520 }
        if islandPage == .history { return historyPanelHeight }
        if islandPage != .none { return 360 }
        return menuPanelMaxHeight
    }

    private func dockTile(title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            if showExitConfirmation {
                withAnimation(.easeOut(duration: 0.18)) { showExitConfirmation = false }
            }
            action()
        } label: {
            ZStack(alignment: .leading) {
                Text(title)
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.leading, 16)
            }
            .frame(width: menuTileWidth, height: menuTileHeight)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(PlainMenuButtonStyle())
        .accessibilityIdentifier(id)
        .help(title)
    }

    private var exitTile: some View {
        ZStack {
            if showExitConfirmation {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.leading, 16)
                    Text(L("menu_exit_ask"))
                        .font(.custom("Georgia", size: 20))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                    Button(L("menu_exit_no")) {
                        withAnimation(.easeOut(duration: 0.18)) { showExitConfirmation = false }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
                    Button(L("menu_yes")) {
                        AudioManager.shared.stopIntroSoundtrack()
                        exitApp()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.78), in: Capsule())
                    .padding(.trailing, 12)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showExitConfirmation = true }
                } label: {
                    ZStack(alignment: .leading) {
                        Text(L("menu_exit"))
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                        Image(systemName: "power")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.leading, 16)
                    }
                }
                .buttonStyle(PlainMenuButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: menuTileWidth, height: menuTileHeight)
        .background(.white.opacity(showExitConfirmation ? 0.16 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: showExitConfirmation)
        .accessibilityIdentifier("menu_exit")
        .help(L("menu_exit"))
    }

    private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}

private enum MenuIslandPage: Equatable {
    case none
    case multiplayer
    case training
    case history
    case friends

    var titleKey: String {
        switch self {
        case .none: return ""
        case .multiplayer: return "island_multiplayer"
        case .training: return "island_training"
        case .history: return "island_history"
        case .friends: return "island_friends"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle"
        case .multiplayer: return "person.2.fill"
        case .training: return "sportscourt.fill"
        case .history: return "clock.arrow.circlepath"
        case .friends: return "person.crop.circle.badge.plus"
        }
    }
}

private struct PlainMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GameState())
        .frame(width: 800, height: 600)
}
