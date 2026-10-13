import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

private func imageWithTransparentWhiteBackground(_ image: NSImage, whiteThreshold: UInt8 = 235) -> NSImage? {
    let width = Int(image.size.width)
    let height = Int(image.size.height)
    guard width > 0, height > 0 else { return nil }
    let bytesPerRow = width * 4
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: bytesPerRow,
        bitsPerPixel: 32
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.bitmapData else { return nil }
    let threshold = whiteThreshold
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * 4
            let r = data[offset]
            let g = data[offset + 1]
            let b = data[offset + 2]
            let a = data[offset + 3]
            let isWhite = r >= threshold && g >= threshold && b >= threshold
            let brightness = (Int(r) + Int(g) + Int(b)) / 3
            let isVeryLight = brightness >= Int(threshold)
            if (isWhite || isVeryLight) && a > 0 {
                data[offset] = 0
                data[offset + 1] = 0
                data[offset + 2] = 0
                data[offset + 3] = 0
            }
        }
    }
    let outImage = NSImage(size: image.size)
    outImage.addRepresentation(rep)
    return outImage
}

private func printIconDiagnostics() {}

private func loadResourceIcon(named name: String) -> NSImage? {
    loadBarIcon(named: name)
}

private let resourceMaxDisplay = 9_999

private let resourceDigitWidth: CGFloat = 46
private let hudBarIcon: CGFloat = 48
private let hudStatIcon: CGFloat = 16
private let hudStatFont: CGFloat = 12
private let hudStatHeight: CGFloat = 28
private let hudStatWidth: CGFloat = 120

private struct ResourceRow: View {
    let iconName: String
    let value: Int
    var iconSize: CGFloat = 44
    var systemFallback: String = "cube.fill"
    var iconOnly: Bool = false
    private var image: NSImage? { HUDIconTrim.image(named: iconName) }
    private var displayValue: Int { min(resourceMaxDisplay, max(0, value)) }
    var body: some View {
        HStack(spacing: iconOnly ? 0 : 4) {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemFallback)
                        .font(.system(size: iconSize * 0.72, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .frame(width: iconSize, height: iconSize)
            if !iconOnly {
                Text("\(displayValue)")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: resourceDigitWidth, alignment: .leading)
            }
        }
        .frame(width: iconOnly ? iconSize : ResourceRow.fixedWidth(iconSize: iconSize))
    }
    static func fixedWidth(iconSize: CGFloat) -> CGFloat { iconSize + 4 + resourceDigitWidth }
}

/// Resource PNG-ovi imaju velik prazan rub, pa isti okvir kao zlatnik izgleda sitno.
/// Reže se prozirni rub da crtež ispuni isti kvadrat kao ikona novca.
private enum HUDIconTrim {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let source = loadResourceIcon(named: name) else { return nil }
        let trimmed = croppedToOpaquePixels(source)
        cache[name] = trimmed
        return trimmed
    }

    private static func croppedToOpaquePixels(_ image: NSImage) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let width = cg.width
        let height = cg.height
        guard width > 0, height > 0 else { return image }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
                if alpha > 16 {
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        let pad = 6
        let originX = max(0, minX - pad)
        let originY = max(0, minY - pad)
        let cropWidth = min(width - originX, maxX - minX + 1 + pad * 2)
        let cropHeight = min(height - originY, maxY - minY + 1 + pad * 2)
        let cgY = max(0, height - originY - cropHeight)
        let rect = CGRect(x: originX, y: cgY, width: cropWidth, height: cropHeight)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: cropWidth, height: cropHeight))
    }
}

private enum ResourceStripMode {
    case resources
    case weapons
    case food
}

private struct MarkedPeopleBar: View {
    let people: [MarkedPerson]

    var body: some View {
        HStack(spacing: 22) {
            ForEach(people) { person in
                VStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(color(hex: person.colorHex))
                        .frame(width: 36, height: 36)
                    Text(person.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 88)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func color(hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let num = UInt64(s, radix: 16) else { return .white }
        return Color(
            red: Double((num >> 16) & 0xFF) / 255,
            green: Double((num >> 8) & 0xFF) / 255,
            blue: Double(num & 0xFF) / 255
        )
    }
}

private struct DoubleClickTarget<Content: View>: View {
    var onDouble: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var wait: DispatchWorkItem?

    var body: some View {
        Button {
            if let wait {
                wait.cancel()
                self.wait = nil
                onDouble()
            } else {
                let work = DispatchWorkItem { self.wait = nil }
                self.wait = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: work)
            }
        } label: {
            content()
        }
        .buttonStyle(.plain)
    }
}

private struct PeopleCountView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            hudAssetIcon("people", fallback: "person.fill", size: hudStatIcon)
            Text("\(max(0, count))")
                .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: hudStatWidth, height: hudStatHeight)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Ljudi")
    }
}

private struct GoldStatView: View {
    let amount: Int
    @State private var shownGold = 0

    var body: some View {
        HStack(spacing: 6) {
            hudAssetIcon("gold", fallback: "dollarsign.circle.fill", size: hudStatIcon)
            Text("\(shownGold)")
                .contentTransition(.numericText())
                .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: hudStatWidth, height: hudStatHeight)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Zlato")
        .onAppear { rollGold(to: amount) }
        .onChange(of: amount) { target in
            if abs(target - shownGold) >= 8 { rollGold(to: target) }
            else { shownGold = max(0, target) }
        }
    }

    private func rollGold(to target: Int) {
        let end = max(0, target)
        let start = shownGold
        let delta = end - start
        guard delta != 0 else { return }
        let steps = 28
        Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 36_000_000)
                shownGold = start + delta * step / steps
            }
            shownGold = end
        }
    }
}

private struct HappinessStatView: View {
    let happiness: Int

    private var shown: Int { min(100, max(0, happiness)) }

    var body: some View {
        HStack(spacing: 6) {
            hudAssetIcon("happy", fallback: "face.smiling", size: hudStatIcon)
            Text("\(shown) %")
                .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: hudStatWidth, height: hudStatHeight)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Sreća. Počinje na 100 %.")
    }
}

private func hudAssetIcon(_ name: String, fallback: String, size: CGFloat) -> some View {
    Group {
        if let img = loadBarIcon(named: name) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallback)
                .font(.system(size: size * 0.7))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
    .frame(width: size, height: size)
}

private enum SeasonIcon: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case attun = "attun"
    case winter = "winter"

    private static let cycle: [SeasonIcon] = [.winter, .spring, .summer, .attun]

    static func next(after s: SeasonIcon) -> (season: SeasonIcon, yearCompleted: Bool) {
        guard let idx = cycle.firstIndex(of: s) else { return (.winter, false) }
        let nextIdx = (idx + 1) % cycle.count
        let nextSeason = cycle[nextIdx]
        let yearCompleted = (nextIdx == 0)
        return (nextSeason, yearCompleted)
    }

    static func fromElapsedSeconds(_ totalSeconds: Int) -> (season: SeasonIcon, yearOffset: Int) {
        let perSeason = Season.turnsPerSeason
        let seasonIndex = (totalSeconds / perSeason) % cycle.count
        let yearOffset = totalSeconds / (perSeason * cycle.count)
        return (cycle[seasonIndex], yearOffset)
    }

    static let wheelOrder: [SeasonIcon] = cycle

    var ringColor: Color {
        switch self {
        case .winter: return Color(red: 0.55, green: 0.78, blue: 1)
        case .spring: return Color(red: 0.35, green: 0.86, blue: 0.38)
        case .summer: return Color(red: 0.95, green: 0.28, blue: 0.22)
        case .attun: return Color(red: 1, green: 0.58, blue: 0.16)
        }
    }

    var displayName: String {
        switch self {
        case .winter: return "Zima"
        case .spring: return "Proljeće"
        case .summer: return "Ljeto"
        case .attun: return "Jesen"
        }
    }
}

private struct ContentAreaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 830
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var performance = PerformanceMonitor.shared
    @State private var showMinijatureWall = false
    @State private var showMinimap = false
    @State private var performanceOffset = CGSize(width: 0, height: -196)
    @State private var performanceDragOrigin = CGSize(width: 0, height: -196)
    @State private var expandedBottomCategory: BottomBarCategory? = nil
    @State private var hudMouseNear = false
    @State private var contentAreaWidth: CGFloat = 830
    @State private var showGrid = false
    @State private var showPivotIndicator = false
    @State private var showPauseMenu = false
    @State private var pauseMessage: String?
    @State private var pausedAt: Date?
    @State private var resourceStripMode: ResourceStripMode = .resources
    @State private var showFoodRow = false
    @State private var displayedSeason: SeasonIcon = .winter
    @State private var displayedYear: Int = 1100
    @State private var outgoingSeason: SeasonIcon?
    @State private var seasonAnimOffset: CGFloat = 0
    /// Trenutak zadnjeg poteza, da se obrub puni i između sekundi.
    @State private var seasonClockAnchor: (turn: Int, date: Date)?
    @State private var seasonNow = Date()
    /// Smanjeni sat. Kad se uključi, reći će se posebno.
    @State private var seasonClockCompact = false
    @State private var seasonRingSpin: Double = 0
    @State private var gameStartTime: Date?
    @State private var showTreasury = false
    @State private var showDiplomacy = false
    @State private var showTimePanel = false
    @State private var seasonButtonFrame: CGRect = .zero
    @State private var seasonRevealHeight: CGFloat = 28
    @State private var seasonInCenter = false
    @State private var seasonPanelToken = 0
    @State private var showCompassDrop = false
    @State private var showZoomDrop = false
    @State private var compassFrame: CGRect = .zero
    @State private var zoomFrame: CGRect = .zero
    @State private var compassReveal: CGFloat = 28
    @State private var zoomReveal: CGFloat = 28
    @State private var compassToken = 0
    @State private var zoomToken = 0
    @State private var showPeopleDrop = false
    @State private var showGoldDrop = false
    @State private var showHappyDrop = false
    @State private var peopleFrame: CGRect = .zero
    @State private var goldFrame: CGRect = .zero
    @State private var happyFrame: CGRect = .zero
    @State private var peopleReveal: CGFloat = 28
    @State private var goldReveal: CGFloat = 28
    @State private var happyReveal: CGFloat = 28
    @State private var peopleToken = 0
    @State private var goldToken = 0
    @State private var happyToken = 0
    @State private var hudMainWidth: CGFloat = 0
    @State private var foodNaturalWidth: CGFloat = 1

    var body: some View {
        MapScreenLayout(
            topBar: { gameHUD },
            content: {
                ZStack {
                    SceneKitMapView(showGrid: showGrid, handPanMode: .constant(false), showPivotIndicator: showPivotIndicator)
                        .id(gameState.mapSceneEpoch)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    if !gameState.isMapEditorMode, let objectId = gameState.selectedPlacementObjectId {
                        priceTag(objectId: objectId)
                    }

                    if !gameState.isMapEditorMode, showTreasury || showDiplomacy {
                        VStack(alignment: .trailing, spacing: 10) {
                            if showTreasury, gameState.campaign.type == .economic {
                                TreasuryPanel { showTreasury = false }
                            }
                            if showDiplomacy {
                                DiplomacyPanel { showDiplomacy = false }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                    }

                    if let result = gameState.campaignResult, !gameState.isMapEditorMode, !gameState.isSandboxPlay {
                        CampaignResultOverlay(result: result)
                    }

                    if let notice = gameState.factionDefeatNotice {
                        VStack {
                            Text(notice)
                                .font(.custom("Georgia", size: 18))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                                .padding(.top, 12)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }

                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            bottomBarSideSlot(showsMap: true)
                            VStack(spacing: 0) {
                                if bottomBarShowsPeople {
                                    MarkedPeopleBar(people: gameState.markedPeople)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .transition(.opacity)
                                } else if let placementId = gameState.inspectedPlacementId, let title = gameState.inspectedBuildingTitle {
                                    BuildingStatusView(placementId: placementId, title: title)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else if let title = gameState.inspectedBuildingTitle {
                                    Text(title)
                                        .font(.custom("Georgia", size: 22))
                                        .foregroundStyle(.white.opacity(0.95))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    if let category = expandedBottomCategory {
                                        expandedBottomBarContent(category: category)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 12)
                                            .padding(.bottom, 8)
                                            .transition(.opacity)
                                    }
                                    Spacer(minLength: 0)
                                    bottomBarStrip
                                        .padding(.horizontal, expandedBottomCategory != nil ? 36 : 48)
                                        .padding(.top, expandedBottomCategory != nil ? 10 : 16)
                                        .padding(.bottom, 16)
                                }
                            }
                            .animation(.easeInOut(duration: 0.28), value: expandedBottomCategory)
                            .animation(.easeInOut(duration: 0.22), value: bottomBarShowsPeople)
                            .animation(.easeInOut(duration: 0.3), value: gameState.isUndergroundView)
                            .frame(width: bottomBarWidth, height: bottomBarPanelHeight)
                            .background { BottomBarIslandChrome(corner: 26) }
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                            .shadow(color: .black.opacity(0.3 * gameState.bottomBarOpacity), radius: 10, x: 0, y: 4)
                            .layoutPriority(1)
                            bottomBarSideSlot(showsMap: false)
                        }
                        .padding(.bottom, 28)
                        .animation(.easeInOut(duration: 0.28), value: expandedBottomCategory)
                        .animation(.easeInOut(duration: 0.22), value: bottomBarShowsPeople)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentAreaWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(ContentAreaWidthKey.self) { contentAreaWidth = $0 }
            },
            loadingMessage: gameState.isLevelReady ? nil : (gameState.levelLoadingMessage ?? "Učitavanje levela…"),
            customOverlay: {
                Group {
                    if showMinijatureWall {
                        minijatureWallOverlay
                    }
                    if gameState.showLogPanel {
                        logPanelOverlay
                    }
                    if gameState.showFPS {
                        performancePanelOverlay
                    }
                }
            }
        )
        .overlay {
            if showPauseMenu {
                pauseMenuOverlay
            }
        }
        .overlay {
            if showTimePanel || showCompassDrop || showZoomDrop || showPeopleDrop || showGoldDrop || showHappyDrop {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { closeHUDDrops() }
            }
        }
        .overlay(alignment: .topLeading) {
            if showTimePanel, seasonButtonFrame.width > 1 {
                seasonExpanded
                    .frame(width: seasonButtonFrame.width, height: seasonRevealHeight, alignment: .top)
                    .clipped()
                    .offset(x: seasonButtonFrame.minX, y: seasonButtonFrame.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            if showCompassDrop, compassFrame.width > 1 {
                compassExpanded
                    .frame(width: compassFrame.width, height: compassReveal, alignment: .top)
                    .clipped()
                    .offset(x: compassFrame.minX, y: compassFrame.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            if showZoomDrop, zoomFrame.width > 1 {
                zoomExpanded
                    .frame(width: zoomFrame.width, height: zoomReveal, alignment: .top)
                    .clipped()
                    .offset(x: zoomFrame.minX, y: zoomFrame.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            if showPeopleDrop, peopleFrame.width > 1 {
                peopleExpanded
                    .frame(width: peopleFrame.width, height: peopleReveal, alignment: .top)
                    .clipped()
                    .offset(x: peopleFrame.minX, y: peopleFrame.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            if showGoldDrop, goldFrame.width > 1 {
                goldExpanded
                    .frame(width: goldFrame.width, height: goldReveal, alignment: .top)
                    .clipped()
                    .offset(x: goldFrame.minX, y: goldFrame.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            if showHappyDrop, happyFrame.width > 1 {
                happyExpanded
                    .frame(width: happyFrame.width, height: happyReveal, alignment: .top)
                    .clipped()
                    .offset(x: happyFrame.minX, y: happyFrame.minY)
            }
        }
        .coordinateSpace(name: "gameRoot")
        .onChange(of: expandedBottomCategory) { category in
            if category == .cave {
                gameState.enterUnderground()
            } else {
                gameState.leaveUnderground()
            }
        }
        .onChange(of: gameState.isUndergroundView) { underground in
            if underground, expandedBottomCategory != .cave {
                expandedBottomCategory = .cave
            } else if !underground, expandedBottomCategory == .cave {
                expandedBottomCategory = nil
            }
        }
        .onChange(of: gameState.inspectedBuildingTitle) { title in
            if title != nil { expandedBottomCategory = nil }
        }
        .onChange(of: gameState.isGamePaused) { paused in
            if paused {
                pausedAt = Date()
            } else if let began = pausedAt, let start = gameStartTime {
                gameStartTime = start.addingTimeInterval(Date().timeIntervalSince(began))
                pausedAt = nil
            }
        }
        .onChange(of: gameState.isLevelReady) { ready in
            if ready {
                gameStartTime = Date()
                gameState.focusSoloCameraOnCenter()
                gameState.spawnRealmSeatsIfNeeded(animated: true)
                gameState.beginMatchClock()
                AudioManager.shared.playMapMusicIfAvailable(volume: gameState.effectiveMusicVolume)
            } else {
                gameStartTime = nil
                AudioManager.shared.stopMapMusic()
            }
        }
        .onChange(of: gameState.audioMusicVolume) { _ in
            AudioManager.shared.updateMapMusicVolume(volume: gameState.effectiveMusicVolume)
        }
        .onChange(of: gameState.audioMuted) { _ in
            AudioManager.shared.updateMapMusicVolume(volume: gameState.effectiveMusicVolume)
        }
        .onChange(of: gameState.showFPS) { show in
            if show { performance.start() } else { performance.stop() }
        }
        .onAppear {
            printIconDiagnostics()
            if gameState.showFPS { performance.start() }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { now in
            guard gameState.isLevelReady, !gameState.isShowingMainMenu, !gameState.isMapEditorMode, !gameState.isGamePaused else { return }
            seasonNow = now
            refreshSeasonLabel()
        }
        .onChange(of: gameState.currentTurn) { turn in
            seasonClockAnchor = (turn, Date())
            refreshSeasonLabel()
        }
        .onChange(of: gameState.isGamePaused) { paused in
            if !paused { seasonClockAnchor = (gameState.currentTurn, Date()) }
        }
        .onAppear {
            seasonClockAnchor = (gameState.currentTurn, Date())
            seasonNow = Date()
            refreshSeasonLabel()
        }
        .coordinateSpace(name: "gameRoot")
        .onPreferenceChange(SeasonFrameKey.self) { seasonButtonFrame = $0 }
        .onPreferenceChange(CompassFrameKey.self) { compassFrame = $0 }
        .onPreferenceChange(ZoomFrameKey.self) { zoomFrame = $0 }
        .onPreferenceChange(HUDMainWidthKey.self) { hudMainWidth = $0 }
        .onPreferenceChange(FoodNaturalWidthKey.self) { foodNaturalWidth = max(1, $0) }
        .onPreferenceChange(PeopleFrameKey.self) { peopleFrame = $0 }
        .onPreferenceChange(GoldFrameKey.self) { goldFrame = $0 }
        .onPreferenceChange(HappyFrameKey.self) { happyFrame = $0 }
    }

    /// Koliko je tekuće doba prošlo, 0...1. Jedno doba traje `Season.turnsPerSeason` sekundi.
    private func seasonFraction(at now: Date) -> Double {
        let whole = Double(max(0, gameState.currentTurn - 1))
        let tick = 1.0 / Double(min(3, max(1, gameState.gameSpeed)))
        let partial: Double
        if gameState.isGamePaused {
            partial = 0
        } else if let seasonClockAnchor, seasonClockAnchor.turn == gameState.currentTurn {
            partial = min(1.15, max(0, now.timeIntervalSince(seasonClockAnchor.date) / tick))
        } else {
            partial = 0
        }
        let period = Double(Season.turnsPerSeason)
        return (whole + partial).truncatingRemainder(dividingBy: period) / period
    }

    private func refreshSeasonLabel() {
        guard gameState.isLevelReady, !gameState.isShowingMainMenu, !gameState.isMapEditorMode, !gameState.isGamePaused else { return }
        let totalSeconds = max(0, gameState.currentTurn - 1)
        let (newSeason, yearOffset) = SeasonIcon.fromElapsedSeconds(totalSeconds)
        let newYear = 1100 + yearOffset
        if newSeason != displayedSeason {
            applySeasonChange(to: newSeason, year: newYear)
        } else if newYear != displayedYear {
            displayedYear = newYear
        }
    }

    private func applySeasonChange(to newSeason: SeasonIcon, year newYear: Int) {
        let leaving = displayedSeason
        outgoingSeason = leaving
        displayedSeason = newSeason
        displayedYear = newYear
        seasonAnimOffset = 0
        withAnimation(.easeInOut(duration: 0.45)) {
            seasonAnimOffset = 36
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            outgoingSeason = nil
            seasonAnimOffset = 0
        }
    }

    private var bottomBarShowsPeople: Bool { !gameState.markedPeople.isEmpty }

    private var bottomBarArea: CGFloat { CGFloat(gameState.bottomBarAreaScale) }
    private var bottomBarIcon: CGFloat { CGFloat(gameState.bottomBarIconScale) }

    /// Širina koja stane sve ikone, pa se bar širi do toga da budu ravnomjerno raspoređene.
    private var bottomBarFitWidth: CGFloat {
        let icon = (bottomBarCategoryOpen ? 34 : 46) * bottomBarIcon
        let count = CGFloat(BottomBarCategory.allCases.count)
        let inset: CGFloat = bottomBarCategoryOpen ? 88 : 112
        return count * icon + inset
    }

    private var bottomBarWidth: CGFloat {
        let desired = (bottomBarCategoryOpen ? 1280 : 1120) * bottomBarArea
        let limit = max(bottomBarFitWidth, contentAreaWidth - 72)
        return min(max(bottomBarFitWidth, desired), limit)
    }

    /// Otvorena kategorija ili pregled građevine (stanje, trening) trebaju viši bar.
    private var bottomBarPanelHeight: CGFloat {
        let base: CGFloat
        if bottomBarCategoryOpen { base = 196 }
        else if !bottomBarShowsPeople, gameState.inspectedPlacementId != nil { base = 196 }
        else { base = 104 }
        return base * bottomBarArea
    }

    private var bottomBarCategoryOpen: Bool {
        !bottomBarShowsPeople && gameState.inspectedBuildingTitle == nil && expandedBottomCategory != nil
    }

    private var bottomBarStrip: some View {
        barIconsRow(
            compact: expandedBottomCategory != nil,
            expandedCategory: expandedBottomCategory
        )
    }

    private func barIconsRow(compact: Bool, expandedCategory: BottomBarCategory?) -> some View {
        let iconSize: CGFloat = (compact ? 34 : 46) * bottomBarIcon
        return HStack(spacing: 0) {
            ForEach(BottomBarCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        if let expanded = expandedCategory, cat == expanded {
                            expandedBottomCategory = nil
                        } else {
                            if expandedCategory != nil, gameState.playBarTransitionSound {
                                AudioManager.shared.playSound(named: "transition", volume: gameState.effectiveSoundsVolume)
                            }
                            expandedBottomCategory = cat
                        }
                    }
                } label: {
                    barIcon(for: cat, size: iconSize)
                        .frame(maxWidth: .infinity, minHeight: iconSize)
                        .padding(.vertical, 2)
                        .background(
                            cat == .cave && gameState.isUndergroundView ? Color.white.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func barIcon(for category: BottomBarCategory, size: CGFloat = 48) -> some View {
        BuildCategoryIcon(category: category, size: size)
    }

    private func expandedBottomBarContent(category: BottomBarCategory) -> some View {
        BuildCategoryContent(category: category)
            .frame(minWidth: 280)
    }

    /// Cijena odabrane građevine iz cjenika; crveno ono što nedostaje.
    private func priceTag(objectId: String) -> some View {
        let price = PriceList.price(for: objectId)
        let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
        return VStack {
            Spacer()
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if price.isFree {
                    Text("besplatno")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                ForEach(price.sortedItems, id: \.good) { item in
                    Text("\(item.amount) \(item.good.displayName)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(gameState.goodAmount(item.good) >= item.amount ? .white.opacity(0.9) : Color(red: 1, green: 0.45, blue: 0.4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 150)
        }
        .allowsHitTesting(false)
    }

    private var seasonRingColor: Color {
        switch displayedSeason {
        case .winter: return Color(red: 0.55, green: 0.78, blue: 1)
        case .spring: return Color(red: 0.35, green: 0.86, blue: 0.38)
        case .summer: return Color(red: 0.95, green: 0.28, blue: 0.22)
        case .attun: return Color(red: 1, green: 0.58, blue: 0.16)
        }
    }

    private var seasonHUDView: some View {
        Button {
            if showTimePanel { closeSeasonPanel() } else { openSeasonPanel() }
        } label: {
            Group {
                if seasonClockCompact {
                    compactSeasonClock
                } else {
                    expandedSeasonClock
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Vrijeme")
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SeasonFrameKey.self, value: geo.frame(in: .named("gameRoot")))
            }
        )
    }

    private var expandedSeasonClock: some View {
        let fraction = seasonFraction(at: seasonNow)
        return HStack(spacing: 6) {
            Text(verbatim: String(displayedYear))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))

            Spacer(minLength: 4)

            ZStack {
                if let out = outgoingSeason {
                    seasonIconView(out)
                        .offset(y: seasonAnimOffset)
                        .opacity(Double(1.0 - min(1.0, Double(seasonAnimOffset) / 36.0)))
                }
                seasonIconView(displayedSeason)
                    .offset(y: outgoingSeason == nil ? 0 : CGFloat(-36) + seasonAnimOffset)
                    .opacity(outgoingSeason == nil ? 1 : Double(min(1.0, Double(seasonAnimOffset) / 36.0)))
            }
            .frame(width: 16, height: 22)
            .clipped()
        }
        .padding(.horizontal, 10)
        .frame(width: 108, height: 28)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay(seasonBorder(fraction: fraction, color: seasonRingColor))
    }

    /// Smanjeni sat: krug, a na obrubu se vrte zelene nijanse proljeća.
    private var compactSeasonClock: some View {
        Circle()
            .fill(Color(white: 0, opacity: 0.35))
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.62, green: 0.92, blue: 0.45),
                                Color(red: 0.18, green: 0.62, blue: 0.28),
                                Color(red: 0.78, green: 0.95, blue: 0.35),
                                Color(red: 0.28, green: 0.78, blue: 0.42),
                                Color(red: 0.62, green: 0.92, blue: 0.45)
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .padding(1.5)
                    .rotationEffect(.degrees(seasonRingSpin))
            )
            .onAppear {
                guard seasonRingSpin == 0 else { return }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    seasonRingSpin = 360
                }
            }
    }

    private func seasonBorder(fraction: Double, color: Color) -> some View {
        let track = RoundedRectangle(cornerRadius: 8).inset(by: 1.6)
        return ZStack {
            track.stroke(color.opacity(0.28), lineWidth: 2.5)
            SeasonPerimeter(fraction: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .allowsHitTesting(false)
    }

    private func openSeasonPanel() {
        closeCompassDrop(animated: false)
        closeZoomDrop(animated: false)
        closePeopleDrop(animated: false)
        closeGoldDrop(animated: false)
        closeHappyDrop(animated: false)
        seasonPanelToken += 1
        showTimePanel = true
        seasonRevealHeight = 28
        seasonInCenter = false
        let target = seasonOpenHeight
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.4)) {
                seasonRevealHeight = target
                seasonInCenter = true
            }
        }
    }

    private func closeSeasonPanel() {
        guard showTimePanel else { return }
        seasonPanelToken += 1
        let token = seasonPanelToken
        withAnimation(.easeIn(duration: 0.22)) {
            seasonInCenter = false
            seasonRevealHeight = 28
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            if seasonPanelToken == token { showTimePanel = false }
        }
    }

    private func closeHUDDrops() {
        closeSeasonPanel()
        closeCompassDrop()
        closeZoomDrop()
        closePeopleDrop()
        closeGoldDrop()
        closeHappyDrop()
    }

    private func openCompassDrop() {
        closeSeasonPanel()
        closeZoomDrop(animated: false)
        closePeopleDrop(animated: false)
        closeGoldDrop(animated: false)
        closeHappyDrop(animated: false)
        compassToken += 1
        showCompassDrop = true
        compassReveal = 28
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34)) { compassReveal = 28 + max(108, compassFrame.width) }
        }
    }

    private func closeCompassDrop(animated: Bool = true) {
        guard showCompassDrop else { return }
        compassToken += 1
        let token = compassToken
        if animated {
            withAnimation(.easeIn(duration: 0.22)) { compassReveal = 28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if compassToken == token { showCompassDrop = false }
            }
        } else {
            compassReveal = 28
            showCompassDrop = false
        }
    }

    private func openZoomDrop() {
        closeSeasonPanel()
        closeCompassDrop(animated: false)
        closePeopleDrop(animated: false)
        closeGoldDrop(animated: false)
        closeHappyDrop(animated: false)
        zoomToken += 1
        showZoomDrop = true
        zoomReveal = 28
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34)) { zoomReveal = 28 + 36 * 3 }
        }
    }

    private func closeZoomDrop(animated: Bool = true) {
        guard showZoomDrop else { return }
        zoomToken += 1
        let token = zoomToken
        if animated {
            withAnimation(.easeIn(duration: 0.22)) { zoomReveal = 28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if zoomToken == token { showZoomDrop = false }
            }
        } else {
            zoomReveal = 28
            showZoomDrop = false
        }
    }

    private func openPeopleDrop() {
        closeSeasonPanel()
        closeCompassDrop(animated: false)
        closeZoomDrop(animated: false)
        closeGoldDrop(animated: false)
        closeHappyDrop(animated: false)
        peopleToken += 1
        showPeopleDrop = true
        peopleReveal = 28
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34)) { peopleReveal = 28 + 28 * 3 }
        }
    }

    private func closePeopleDrop(animated: Bool = true) {
        guard showPeopleDrop else { return }
        peopleToken += 1
        let token = peopleToken
        if animated {
            withAnimation(.easeIn(duration: 0.22)) { peopleReveal = 28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if peopleToken == token { showPeopleDrop = false }
            }
        } else {
            peopleReveal = 28
            showPeopleDrop = false
        }
    }

    private func openGoldDrop() {
        closeSeasonPanel()
        closeCompassDrop(animated: false)
        closeZoomDrop(animated: false)
        closePeopleDrop(animated: false)
        closeHappyDrop(animated: false)
        goldToken += 1
        showGoldDrop = true
        goldReveal = 28
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34)) { goldReveal = 28 + 28 }
        }
    }

    private func closeGoldDrop(animated: Bool = true) {
        guard showGoldDrop else { return }
        goldToken += 1
        let token = goldToken
        if animated {
            withAnimation(.easeIn(duration: 0.22)) { goldReveal = 28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if goldToken == token { showGoldDrop = false }
            }
        } else {
            goldReveal = 28
            showGoldDrop = false
        }
    }

    private func openHappyDrop() {
        closeSeasonPanel()
        closeCompassDrop(animated: false)
        closeZoomDrop(animated: false)
        closePeopleDrop(animated: false)
        closeGoldDrop(animated: false)
        happyToken += 1
        showHappyDrop = true
        happyReveal = 28
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34)) { happyReveal = 28 + 28 }
        }
    }

    private func closeHappyDrop(animated: Bool = true) {
        guard showHappyDrop else { return }
        happyToken += 1
        let token = happyToken
        if animated {
            withAnimation(.easeIn(duration: 0.22)) { happyReveal = 28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if happyToken == token { showHappyDrop = false }
            }
        } else {
            happyReveal = 28
            showHappyDrop = false
        }
    }

    private var peopleExpanded: some View {
        let width = max(hudStatWidth, peopleFrame.width)
        let faction = gameState.playerSeat?.id
        let present = faction.map { gameState.peopleOf(faction: $0) } ?? []
        let rows = [
            ("Seljaci", present.filter { $0.role == .peasant }.count),
            ("Radnici", present.filter { $0.role == .worker }.count),
            ("Vojnici", present.filter { $0.role == .soldier }.count)
        ]
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                hudAssetIcon("people", fallback: "person.fill", size: hudStatIcon)
                Text("\(gameState.peopleCount)")
                    .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(width: width, height: 28)
            .contentShape(Rectangle())
            .onTapGesture { closePeopleDrop() }
            ForEach(rows, id: \.0) { name, count in
                Text("\(name)  \(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: width - 12, height: 26)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.bottom, 4)
        }
        .frame(width: width, alignment: .top)
        .background(Color(white: 0.1, opacity: 0.94), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.35), lineWidth: 1.5))
    }

    private var goldExpanded: some View {
        let width = max(hudStatWidth, goldFrame.width)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                hudAssetIcon("gold", fallback: "dollarsign.circle.fill", size: hudStatIcon)
                Text("\(gameState.resources.gold)")
                    .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(width: width, height: 28)
            .contentShape(Rectangle())
            .onTapGesture { closeGoldDrop() }
            Text("Zlato  \(gameState.resources.gold)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: width - 12, height: 26)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 4)
        }
        .frame(width: width, alignment: .top)
        .background(Color(white: 0.1, opacity: 0.94), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.7), lineWidth: 1.5))
    }

    private var happyExpanded: some View {
        let width = max(hudStatWidth, happyFrame.width)
        let faction = gameState.playerSeat?.id
        let percent = Int((faction.map { gameState.happinessPercent(of: $0) } ?? HappinessRules.start).rounded())
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                hudAssetIcon("happy", fallback: "face.smiling", size: hudStatIcon)
                Text("\(min(100, max(0, percent))) %")
                    .font(.system(size: hudStatFont, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(width: width, height: 28)
            .contentShape(Rectangle())
            .onTapGesture { closeHappyDrop() }
            Text("Odlazak ispod 50 %")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: width - 12, height: 26)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 4)
        }
        .frame(width: width, alignment: .top)
        .background(Color(white: 0.1, opacity: 0.94), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.55), lineWidth: 1.5))
    }

    private func setCameraRotation(_ value: CGFloat) {
        var settings = gameState.mapCameraSettings
        settings.mapRotation = value
        gameState.mapCameraSettings = settings
    }

    private var compassExpanded: some View {
        let width = max(108, compassFrame.width)
        let current = compassCardinalIndex(from: gameState.mapCameraSettings.mapRotation)
        return VStack(spacing: 0) {
            Text(compassCardinals[current])
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: width, height: 28)
                .contentShape(Rectangle())
                .onTapGesture { closeCompassDrop() }
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                ForEach(Array(compassCardinals.enumerated()), id: \.offset) { index, letter in
                    let step = (index - current + 4) % 4
                    let degrees = 90.0 + Double(step) * 90.0
                    let rad = degrees * .pi / 180
                    let radius = width * 0.32
                    Button {
                        spinCamera(toCardinal: index, from: gameState.mapCameraSettings.mapRotation) { setCameraRotation($0) }
                    } label: {
                        Text(letter)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(index == current ? .black : .white)
                            .frame(width: 28, height: 28)
                            .background(index == current ? Color.yellow : Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: width / 2 + CGFloat(sin(rad)) * radius,
                        y: width / 2 - CGFloat(cos(rad)) * radius
                    )
                }
            }
            .frame(width: width, height: width)
        }
        .frame(width: width, alignment: .top)
        .background(Color(white: 0.1, opacity: 0.94), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.35), lineWidth: 1.5))
    }

    private var zoomExpanded: some View {
        let width = zoomFrame.width
        let current = min(3, max(1, gameState.mapCameraSettings.zoomPhase))
        return VStack(spacing: 0) {
            ZoomPhaseIcon(phase: current)
                .frame(width: width, height: 28)
                .contentShape(Rectangle())
                .onTapGesture { closeZoomDrop() }
            ForEach(1...3, id: \.self) { phase in
                Button {
                    var settings = gameState.mapCameraSettings
                    settings.setZoomPhase(phase)
                    gameState.mapCameraSettings = settings
                } label: {
                    ZoomPhaseIcon(phase: phase)
                        .frame(width: width - 12, height: 32)
                        .background(phase == current ? Color.yellow.opacity(0.85) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .frame(width: width, alignment: .top)
        .background(Color(white: 0.1, opacity: 0.94), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.7), lineWidth: 1.5))
    }

    private var seasonOpenHeight: CGFloat { 28 + 80 }

    private var seasonExpanded: some View {
        let width = max(108, seasonButtonFrame.width)
        let fraction = seasonFraction(at: seasonNow)
        let side = min(76, width - 16)
        let circleTop: CGFloat = 22
        let centerY = circleTop + side / 2
        return ZStack(alignment: .topLeading) {
            seasonWheel(side: side, fraction: fraction)
                .frame(width: side, height: side)
                .position(x: width / 2, y: centerY)
            seasonIconView(displayedSeason)
                .position(x: width - 20, y: 14)
                .opacity(seasonInCenter ? 0 : 1)
                .scaleEffect(seasonInCenter ? 0.3 : 1)
            Text(verbatim: String(displayedYear))
                .font(.system(size: seasonInCenter ? 11 : 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .position(x: seasonInCenter ? width / 2 : 34, y: seasonInCenter ? centerY + 8 : 14)
        }
        .frame(width: width, height: seasonOpenHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.1, opacity: 0.94))
                .onTapGesture { closeSeasonPanel() }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(seasonRingColor, lineWidth: 2)
                .allowsHitTesting(false)
        )
        .animation(.easeOut(duration: 0.28), value: seasonInCenter)
    }

    private func seasonWheel(side: CGFloat, fraction: Double) -> some View {
        let seasons = SeasonIcon.wheelOrder
        let current = seasons.firstIndex(of: displayedSeason) ?? 0
        let turn = Double(current) * 90
        let amount = min(1, max(0, fraction))
        return ZStack {
            Circle()
                .stroke(seasonRingColor.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: amount)
                .stroke(seasonRingColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)
            ZStack {
                ForEach(Array(seasons.enumerated()), id: \.offset) { index, season in
                    seasonIconView(season)
                        .scaleEffect(0.55)
                        .rotationEffect(.degrees(-turn))
                        .position(seasonIconPoint(index: index, side: side))
                }
            }
            .rotationEffect(.degrees(turn))
            .opacity(seasonInCenter ? 1 : 0)
            .animation(.easeIn(duration: 0.28).delay(seasonInCenter ? 0.18 : 0), value: seasonInCenter)
            .animation(.easeInOut(duration: 0.55), value: displayedSeason)
            Button {
                gameState.setGameSpeed(gameState.gameSpeed % 3 + 1)
            } label: {
                HStack(spacing: 1) {
                    ForEach(0..<gameState.gameSpeed, id: \.self) { _ in
                        SpeedTriangle()
                            .fill(Color.white)
                            .frame(width: 7, height: 10)
                    }
                }
                .frame(width: 26, height: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(y: -9)
            .help(gameState.gameSpeed == 1 ? "Normalno" : "Ubrzanje \(gameState.gameSpeed)×")
        }
        .frame(width: side, height: side)
    }

    /// Indeks 0 je gore. Sljedeće doba ide ulijevo, zdesna nalijevo.
    private func seasonIconPoint(index: Int, side: CGFloat) -> CGPoint {
        let angle = -.pi / 2 - Double(index) / 4 * 2 * .pi
        let radius = side * 0.34
        let center = side / 2
        return CGPoint(x: center + CGFloat(cos(angle) * radius), y: center + CGFloat(sin(angle) * radius))
    }

}

private struct PeopleFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct GoldFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct HappyFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct HUDMainWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FoodNaturalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CompassFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct ZoomFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct SeasonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

private struct SpeedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Obrub oznake godine. Putanja ostaje u okviru pločice i puni se od 0 do 1.
private struct SeasonPerimeter: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: 1.6, dy: 1.6)
        let full = Path(roundedRect: box, cornerRadius: min(7, box.height / 2))
        let amount = min(1, max(0, fraction))
        guard amount > 0.001 else { return Path() }
        return full.trimmedPath(from: 0, to: amount)
    }
}

private extension ContentView {
    private func hudPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var castleClosedHUDView: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
            Text("Dvorac zatvoren")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Dvorac je opasan zidovima, vodom i vratima – nitko ne može ući ni izaći osim kroz vrata.")
    }

    private func seasonIconView(_ season: SeasonIcon) -> some View {
        Group {
            if let img = loadBarIcon(named: season.rawValue) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 16, height: 16)
    }

    private var gameHUD: some View {
        VStack(spacing: 8) {
            hudIsland
            HUDMessageStrip()
        }
    }

    private var hudIsland: some View {
        MapScreenHUDBar(onBackgroundTap: toggleHUDIsland, barHeight: 64, itemSpacing: 8, expandsDown: showFoodRow) {
            VStack(alignment: .leading, spacing: showFoodRow ? 8 : 0) {
            HStack(alignment: .center, spacing: 8) {
            if hudMouseNear {
                HStack(spacing: 8) {
                Button {
                    showMinimap.toggle()
                } label: {
                    hudIconImage("map", fallback: "map", size: 28)
                }
                .buttonStyle(.plain)
                .help(showMinimap ? "Sakrij mapu" : "Mapa")

                seasonHUDView

                if gameState.isPlayerCastleEnclosed {
                    castleClosedHUDView
                }

                if !gameState.isSandboxPlay {
                    Button {
                        showDiplomacy.toggle()
                    } label: {
                        hudPill(icon: "person.2.wave.2.fill", text: "Diplomacija", color: .white)
                    }
                    .buttonStyle(.plain)
                    .help(gameState.campaign.type.goalText)

                    if gameState.campaign.type == .economic {
                        Button {
                            showTreasury.toggle()
                        } label: {
                            hudPill(icon: "building.columns.fill", text: "Riznica", color: .yellow)
                        }
                        .buttonStyle(.plain)
                        .help("Uplati zlato u riznicu – \(gameState.campaign.economicTarget.formatted()) za pobjedu.")
                    }
                }

                CompassCubeView(
                    mapRotation: Binding(
                        get: { gameState.mapCameraSettings.mapRotation },
                        set: { new in
                            var s = gameState.mapCameraSettings
                            s.mapRotation = new
                            gameState.mapCameraSettings = s
                        }
                    ),
                    panOffset: Binding(
                        get: { gameState.mapCameraSettings.panOffset },
                        set: { new in
                            var s = gameState.mapCameraSettings
                            s.panOffset = new
                            gameState.mapCameraSettings = s
                        }
                    ),
                    onPress: { openCompassDrop() }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CompassFrameKey.self, value: geo.frame(in: .named("gameRoot")))
                    }
                )

                ZoomPhaseView(
                    mapCameraSettings: Binding(
                        get: { gameState.mapCameraSettings },
                        set: { gameState.mapCameraSettings = $0 }
                    ),
                    onPress: { openZoomDrop() }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ZoomFrameKey.self, value: geo.frame(in: .named("gameRoot")))
                    }
                )

                HUDBarDivider(height: 32)

                HStack(spacing: 4) {
                    Button {
                        togglePauseFromHUD()
                    } label: {
                        hudIconImage("gear", fallback: "gearshape.fill", size: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Pauza")
                    resourceCategoryButton("foodbottun", mode: .food, fallback: "fork.knife", help: "Hrana")
                    resourceCategoryButton("weapons", mode: .weapons, fallback: "crossed.swords", help: "Oružje")
                    resourceCategoryButton("resources", mode: .resources, fallback: "square.stack.3d.up.fill", help: "Resursi")
                }

                HUDBarDivider(height: 32)
                }
                .transition(.opacity)
            }

            DoubleClickTarget(onDouble: openPeopleDrop) {
                PeopleCountView(count: gameState.peopleCount)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PeopleFrameKey.self, value: geo.frame(in: .named("gameRoot")))
                }
            )

            DoubleClickTarget(onDouble: openGoldDrop) {
                GoldStatView(amount: gameState.resources.gold)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: GoldFrameKey.self, value: geo.frame(in: .named("gameRoot")))
                }
            )

            DoubleClickTarget(onDouble: openHappyDrop) {
                HappinessStatView(
                    happiness: Int((gameState.playerSeat.flatMap { gameState.happiness[$0.id] } ?? HappinessRules.start).rounded())
                )
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HappyFrameKey.self, value: geo.frame(in: .named("gameRoot")))
                }
            )

            HUDBarDivider(height: 32)

            resourceStrip
            }
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HUDMainWidthKey.self, value: geo.size.width)
                }
            )
            if showFoodRow {
                foodSecondRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            }
        }
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.32), value: showFoodRow)
        .animation(.easeInOut(duration: 0.22), value: resourceStripMode)
        .background {
            Button(action: togglePauseFromHUD) { Color.clear }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func toggleHUDIsland() {
        withAnimation(.easeInOut(duration: 0.22)) {
            hudMouseNear.toggle()
        }
    }

    private func togglePauseFromHUD() {
        if showPauseMenu {
            resumeFromPause()
        } else {
            openPauseMenu()
        }
    }

    private func resourceCategoryButton(_ name: String, mode: ResourceStripMode, fallback: String, help: String) -> some View {
        Button {
            if mode == .food {
                withAnimation(.easeInOut(duration: 0.32)) { showFoodRow.toggle() }
            } else {
                resourceStripMode = mode
            }
        } label: {
            hudIconImage(name, fallback: fallback, size: 42)
                .padding(2)
                .background(
                    (mode == .food ? showFoodRow : resourceStripMode == mode) ? Color.white.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var resourceStrip: some View {
        HStack(spacing: 4) {
            ForEach(entriesForCurrentStrip()) { entry in
                resourceRow(for: entry, gameState: gameState)
            }
        }
        .id(resourceStripMode)
    }

    private var foodSecondRow: some View {
        let scale: CGFloat = (hudMainWidth > 1 && foodNaturalWidth > 1) ? min(1, hudMainWidth / foodNaturalWidth) : 1
        let rowHeight = hudBarIcon * scale
        return HStack(spacing: 4) {
            ForEach(HUDResourceCatalog.foodStrip) { entry in
                resourceRow(for: entry, gameState: gameState)
            }
        }
        .fixedSize()
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: FoodNaturalWidthKey.self, value: geo.size.width)
            }
        )
        .scaleEffect(scale, anchor: .leading)
        .frame(width: hudMainWidth > 1 ? hudMainWidth : nil, height: max(rowHeight, hudBarIcon), alignment: .leading)
    }

    private func entriesForCurrentStrip() -> [HUDResourceEntry] {
        switch resourceStripMode {
        case .weapons: return HUDResourceCatalog.weaponsStrip
        case .resources, .food: return HUDResourceCatalog.resourcesStrip
        }
    }

    @ViewBuilder
    private func resourceRow(for entry: HUDResourceEntry, gameState: GameState) -> some View {
        let row = ResourceRow(
            iconName: entry.iconName,
            value: gameState.resourceValue(for: entry.id),
            iconSize: hudBarIcon,
            systemFallback: entry.systemFallback,
            iconOnly: false
        )
        if let key = entry.helpKey {
            row.help(LocalizedStrings.string(for: key, language: gameState.appLanguage))
        } else {
            row
        }
    }

    private var pauseMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Pauza")
                    .font(.custom("Georgia", size: 28))
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)
                pauseMenuButton("Nastavi", action: resumeFromPause)
                pauseMenuButton("Snimi partiju", action: recordMatchSnapshot)
                pauseMenuButton("Spremi partiju", action: presentSaveMatchPanel)
                pauseMenuButton("Učitaj", action: presentLoadMatchPanel)
                pauseMenuButton("Ponovno pokreni") {
                    pausedAt = nil
                    showPauseMenu = false
                    pauseMessage = nil
                    gameState.restartCurrentMatch()
                    gameStartTime = Date()
                    displayedSeason = .winter
                    displayedYear = 1100
                    seasonClockAnchor = (gameState.currentTurn, Date())
                }
                pauseMenuButton("Glavni izbornik") {
                    pausedAt = nil
                    showPauseMenu = false
                    pauseMessage = nil
                    gameState.showMainMenu()
                }
                if let pauseMessage {
                    Text(pauseMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 4)
                }
            }
            .padding(22)
            .frame(width: 280)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func pauseMenuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.18))
    }

    private func openPauseMenu() {
        pauseMessage = nil
        gameState.pauseGame()
        showPauseMenu = true
    }

    private func resumeFromPause() {
        showPauseMenu = false
        pauseMessage = nil
        gameState.resumeGame()
    }

    private func recordMatchSnapshot() {
        pauseMessage = gameState.captureMatchRecording()
    }

    private func presentSaveMatchPanel() {
        let panel = NSSavePanel()
        panel.title = "Spremi partiju"
        panel.prompt = "Spremi"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Partija"
        if let dir = GameState.matchSavesDirectory() {
            panel.directoryURL = dir
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        applyMatchLoadResult(message: gameState.saveMatch(to: url, elapsedSeconds: matchElapsedSeconds()), elapsed: nil)
    }

    private func presentLoadMatchPanel() {
        let panel = NSOpenPanel()
        panel.title = "Učitaj partiju"
        panel.prompt = "Učitaj"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let dir = GameState.matchSavesDirectory() {
            panel.directoryURL = dir
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let result = gameState.loadMatch(from: url)
        applyMatchLoadResult(message: result.message, elapsed: result.elapsedSeconds)
    }

    private func matchElapsedSeconds() -> Int {
        max(0, gameState.currentTurn - 1)
    }

    private func applyMatchLoadResult(message: String, elapsed: Int?) {
        pauseMessage = message
        guard let elapsed else { return }
        gameStartTime = Date().addingTimeInterval(-TimeInterval(elapsed))
        let (season, yearOffset) = SeasonIcon.fromElapsedSeconds(elapsed)
        displayedSeason = season
        displayedYear = 1100 + yearOffset
        outgoingSeason = nil
        seasonClockAnchor = (gameState.currentTurn, Date())
        seasonAnimOffset = 0
    }

    private func hudIconImage(_ name: String, fallback systemName: String, size: CGFloat = 22) -> some View {
        Group {
            if let img = loadBarIcon(named: name) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.64))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.white.opacity(0.9))
    }

    private var minijatureWallOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showMinijatureWall = false }

            VStack(spacing: 0) {
                HStack {
                    Text("Zid (minijatura)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Button {
                        showMinijatureWall = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

                WallPreviewView()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .frame(width: 244)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        }
    }

    private var bottomBarHeight: CGFloat {
        bottomBarPanelHeight
    }

    /// Lijevi i desni razmak uz bar su jednaki, pa bar ostaje na sredini. Mapa je na sredini lijevog razmaka, u visini bara.
    private func bottomBarSideSlot(showsMap: Bool) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: bottomBarHeight)
            .overlay {
                if showsMap, showMinimap {
                    GeometryReader { geo in
                        let side = min(bottomBarHeight, max(36, geo.size.width - 24))
                        minimapCard(side: side)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
            }
            .allowsHitTesting(showsMap && showMinimap)
    }

    private func minimapCard(side: CGFloat) -> some View {
        MinimapMiniature(
            rows: gameState.gameMap.rows,
            cols: gameState.gameMap.cols,
            placements: gameState.gameMap.placements
        )
        .frame(width: side - 12, height: side - 12)
        .padding(6)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    private var logPanelOverlay: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Log")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Spacer()
                        Button {
                            gameState.showLogPanel = false
                        } label: {
                            Text("x")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("Zatvori")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    Text("Log panel – poruke će se prikazivati ovdje.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
                .frame(width: 280)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(true)
    }

    private var performancePanelOverlay: some View {
        VStack {
            Spacer(minLength: 0)
                .allowsHitTesting(false)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Performanse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Spacer()
                        Button {
                            gameState.showFPS = false
                            performance.stop()
                        } label: {
                            Text("x")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Zatvori")
                    }
                    performanceRow("Sličice", "\(performance.fps) fps")
                    performanceRow("Kadar", String(format: "%.1f ms", performance.frameMs))
                    performanceRow("Procesor", String(format: "%.0f %%", performance.cpuPercent))
                    performanceRow("RAM igre", String(format: "%.0f MB", performance.appRamMB))
                    performanceRow("RAM", String(format: "%.1f / %.0f GB", performance.systemRamUsedGB, performance.systemRamTotalGB))
                    performanceRow("Grafika", performance.gpuName)
                    performanceRow("GPU memorija", String(format: "%.0f MB", performance.gpuAllocatedMB))
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(width: 260)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
                .offset(performanceOffset)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            performanceOffset = CGSize(
                                width: performanceDragOrigin.width + value.translation.width,
                                height: performanceDragOrigin.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            performanceDragOrigin = performanceOffset
                        }
                )
                .padding(.leading, 20)
                .padding(.bottom, 100)
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
        }
    }

    private func performanceRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.65))
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .font(.caption.monospacedDigit())
    }
}

private struct MinimapMiniature: View {
    let rows: Int
    let cols: Int
    let placements: [Placement]

    var body: some View {
        Canvas { context, size in
            let ground = Color(red: 0.74, green: 0.64, blue: 0.46)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ground))
            let sx = size.width / CGFloat(max(cols, 1))
            let sy = size.height / CGFloat(max(rows, 1))
            let stone = Color(white: 0.62)
            for placement in placements {
                let rect = CGRect(
                    x: CGFloat(placement.col) * sx,
                    y: CGFloat(placement.row) * sy,
                    width: max(1, CGFloat(placement.width) * sx),
                    height: max(1, CGFloat(placement.height) * sy)
                )
                context.fill(Path(rect), with: .color(stone))
            }
            let mark = CGRect(x: size.width / 2 - 3, y: size.height / 2 - 3, width: 6, height: 6)
            context.fill(Path(mark), with: .color(Color(red: 0.18, green: 0.53, blue: 0.67)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ContentView()
        .environmentObject(GameState())
        .frame(width: 1280, height: 800)
}
