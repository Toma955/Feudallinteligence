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
            .offset(y: iconName == "hop_resource" ? 8 : 0)
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
        let rect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
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

private struct PeopleCountView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            hudAssetIcon("people", fallback: "person.fill", size: 28)
            Text("\(max(0, count))")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 8))
        .help("Ljudi")
    }
}

private struct GoldHouseView: View {
    let amount: Int
    let happiness: Int

    private var shown: Int { max(0, amount) }
    private var shownHappiness: Int { min(100, max(0, happiness)) }

    var body: some View {
        HStack(spacing: 8) {
            hudAssetIcon("gold", fallback: "dollarsign.circle.fill", size: hudBarIcon)
            Text("\(shown)")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: 1, height: 28)
            hudAssetIcon("happy", fallback: "face.smiling", size: 28)
            Text("\(shownHappiness) %")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 8))
        .help("Zlato i sreća. Sreća počinje na 100 %.")
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
    @State private var displayedSeason: SeasonIcon = .winter
    @State private var displayedYear: Int = 1100
    @State private var outgoingSeason: SeasonIcon?
    @State private var seasonAnimOffset: CGFloat = 0
    @State private var gameStartTime: Date?
    @State private var showTreasury = false
    @State private var showDiplomacy = false

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
                                        .padding(.vertical, expandedBottomCategory != nil ? 10 : 16)
                                        .padding(.bottom, expandedBottomCategory != nil ? 12 : 2)
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
                        .padding(.bottom, bottomBarCategoryOpen ? 72 : 28)
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard gameState.isLevelReady, !gameState.isShowingMainMenu, !gameState.isMapEditorMode, !gameState.isGamePaused else { return }
            guard gameStartTime != nil else { return }
            let totalSeconds = max(0, gameState.currentTurn - 1)
            let (newSeason, yearOffset) = SeasonIcon.fromElapsedSeconds(totalSeconds)
            let newYear = 1100 + yearOffset
            if newSeason != displayedSeason {
                applySeasonChange(to: newSeason, year: newYear)
            } else if newYear != displayedYear {
                displayedYear = newYear
            }
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

    private var seasonHUDView: some View {
        HStack(spacing: 8) {
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
            .frame(width: 22, height: 28)
            .clipped()
        }
        .padding(.horizontal, 10)
        .frame(width: 120, height: 28)
        .clipped()
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Godina i godišnje doba")
    }

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
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 22, height: 22)
    }

    private var gameHUD: some View {
        VStack(spacing: 8) {
            hudIsland
            HUDMessageStrip()
        }
    }

    private var hudIsland: some View {
        MapScreenHUDBar(onBackgroundTap: toggleHUDIsland, barHeight: 64, itemSpacing: 8) {
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
                    )
                )

                ZoomPhaseView(mapCameraSettings: Binding(
                    get: { gameState.mapCameraSettings },
                    set: { gameState.mapCameraSettings = $0 }
                ))

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

            PeopleCountView(count: gameState.peopleCount)

            GoldHouseView(
                amount: gameState.resources.gold,
                happiness: Int((gameState.playerSeat.flatMap { gameState.happiness[$0.id] } ?? HappinessRules.start).rounded())
            )

            HUDBarDivider(height: 32)

            HStack(spacing: 4) {
                ForEach(entriesForCurrentStrip()) { entry in
                    resourceRow(for: entry, gameState: gameState)
                }
            }
            .id(resourceStripMode)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: resourceStripMode)
        }
        .padding(.bottom, 8)
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
            resourceStripMode = mode
        } label: {
            hudIconImage(name, fallback: fallback, size: 42)
                .padding(2)
                .background(
                    resourceStripMode == mode ? Color.white.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func entriesForCurrentStrip() -> [HUDResourceEntry] {
        switch resourceStripMode {
        case .resources: return HUDResourceCatalog.resourcesStrip
        case .weapons: return HUDResourceCatalog.weaponsStrip
        case .food: return HUDResourceCatalog.foodStrip
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
                pauseMenuButton("Spremi", action: presentSaveMatchPanel)
                pauseMenuButton("Učitaj", action: presentLoadMatchPanel)
                pauseMenuButton("Ponovno pokreni") {
                    pausedAt = nil
                    showPauseMenu = false
                    pauseMessage = nil
                    gameState.restartCurrentMatch()
                    gameStartTime = Date()
                    displayedSeason = .winter
                    displayedYear = 1100
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
