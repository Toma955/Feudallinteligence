import SwiftUI
import UniformTypeIdentifiers

enum SoloMapType: String, CaseIterable, Identifiable {
    case level = "Level (bundle)"
    case procedural = "Proceduralna"
    var id: String { rawValue }
    var levelName: String? {
        switch self {
        case .level: return "Level"
        case .procedural: return nil
        }
    }
}

private enum SoloMapChoice: Hashable {
    case empty(Int)
    case catalog(String)
}

private enum SoloSetupPage {
    case maps
    case resources
}

private let stepperButtonSize: CGFloat = 40
private let resourceStep: Int = 25
private let resourceMax: Int = 9999

struct SoloSetupView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @Binding var showResources: Bool
    var importTick: Int = 0
    @State private var selected: SoloMapChoice?
    @State private var catalogRevision = 0
    @State private var page: SoloSetupPage = .maps
    @State private var loadProgress: Double = 0
    @State private var preparedMap: GameMap?
    @State private var preparedFromFile = false
    @State private var preparedUnderground: [Placement] = []
    @State private var loadToken = UUID()
    @State private var initialGold: Int = 0
    @State private var initialWood: Int = 0
    @State private var initialIron: Int = 0
    @State private var initialStone: Int = 0
    @State private var initialFood: Int = 0
    @State private var initialHop: Int = 0
    @State private var initialHay: Int = 0
    @State private var initialChicken: Int = 0
    @State private var initialEggs: Int = 0
    @State private var initialCorn: Int = 0
    @State private var initialGrapes: Int = 0
    @State private var initialMeat: Int = 0
    @State private var initialCheese: Int = 0
    @State private var initialBeer: Int = 0
    @State private var initialApple: Int = 0
    @State private var initialBanana: Int = 0
    @State private var initialCandle: Int = 0
    @State private var initialFlowers: Int = 0
    @State private var initialLeather: Int = 0
    @State private var initialMedicine: Int = 0
    @State private var initialShield: Int = 0
    @State private var initialSausages: Int = 0
    @State private var initialSpear: Int = 0
    @State private var initialSpices: Int = 0
    @State private var initialSword: Int = 0
    @State private var initialVegetables: Int = 0
    @State private var initialVine: Int = 0
    @State private var initialCrossbow: Int = 0
    @State private var initialMace: Int = 0
    @State private var initialBowAndSparrow: Int = 0
    @State private var showRecordings = false

    private let cardSide: CGFloat = 96

    private var canStart: Bool { preparedMap != nil && loadProgress >= 0.999 }

    var body: some View {
        Group {
            if showRecordings {
                VStack(spacing: 10) {
                    HStack {
                        Button {
                            showRecordings = false
                        } label: {
                            Label(L("menu_back"), systemImage: "chevron.backward")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    MatchHistoryView()
                        .environmentObject(gameState)
                }
            } else {
                setupBody
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadDefaultsFromFile()
            page = showResources ? .resources : .maps
        }
        .onDisappear { loadToken = UUID() }
        .onChange(of: showResources) { open in
            page = open ? .resources : .maps
        }
        .onChange(of: importTick) { tick in
            if tick > 0 { importMap() }
        }
    }

    private var setupBody: some View {
        VStack(spacing: 12) {
            Group {
                if page == .maps {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(MapSizePreset.allCases) { preset in
                            sizeColumn(preset)
                        }
                    }
                } else {
                    resourcesSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomBar
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            nazadButton
            MatchRecordBar { showRecordings = true }
            pokreniButton
            Spacer(minLength: 0)
        }
    }

    private var nazadButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { isPresented = false }
        } label: {
            Label(L("menu_back"), systemImage: "chevron.backward")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(minWidth: 100, minHeight: 44)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("solo_nazad")
    }

    private func sizeColumn(_ preset: MapSizePreset) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text("\(preset.side)x\(preset.side)")
                .font(.custom("Georgia", size: 17))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity)
            ScrollView {
                VStack(spacing: 10) {
                    mapCard(
                        title: L("solo_empty_map"),
                        choice: .empty(preset.side),
                        accessibilityId: "solo_empty_map_\(preset.side)"
                    )
                    ForEach(MapCatalog.entries(forSide: preset.side)) { entry in
                        mapCard(
                            title: entry.displayName,
                            choice: .catalog(entry.path),
                            accessibilityId: "solo_map_\(entry.path)"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(catalogRevision)
    }

    private func mapCard(title: String, choice: SoloMapChoice, accessibilityId: String) -> some View {
        let isOn = selected == choice
        return Button {
            selectAndLoad(choice)
        } label: {
            VStack(spacing: 6) {
                EmptyMapThumbnail()
                    .frame(width: cardSide, height: cardSide)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isOn ? Color.green : Color.white.opacity(0.22), lineWidth: isOn ? 3 : 1)
                    )
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: cardSide)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
        .help(title)
    }

    private var pokreniButton: some View {
        Button(action: startSelected) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.55))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geo.size.width * loadProgress)
                    Text(canStart ? "Pokreni" : "\(Int((loadProgress * 100).rounded()))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 168, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .opacity(canStart ? 1 : 0.95)
        .accessibilityIdentifier("solo_pokreni")
    }

    private func selectAndLoad(_ choice: SoloMapChoice) {
        selected = choice
        preparedMap = nil
        preparedUnderground = []
        preparedFromFile = false
        loadProgress = 0
        let token = UUID()
        loadToken = token
        Task { await loadChoice(choice, token: token) }
    }

    private func loadChoice(_ choice: SoloMapChoice, token: UUID) async {
        switch choice {
        case .empty(let side):
            let map = await buildEmptyMap(side: side, token: token)
            await finishLoad(map: map, fromFile: false, underground: [], token: token)
        case .catalog(let path):
            let loaded = await loadCatalogMap(path: path, token: token)
            await finishLoad(map: loaded?.map, fromFile: true, underground: loaded?.underground ?? [], token: token)
        }
    }

    private func finishLoad(map: GameMap?, fromFile: Bool, underground: [Placement], token: UUID) async {
        guard loadToken == token else { return }
        if let map {
            preparedMap = map
            preparedFromFile = fromFile
            preparedUnderground = underground
            withAnimation(.easeOut(duration: 0.18)) { loadProgress = 1 }
        } else {
            preparedMap = nil
            loadProgress = 0
        }
    }

    private func buildEmptyMap(side: Int, token: UUID) async -> GameMap? {
        let rows = side
        let cols = side
        return await Task.detached(priority: .userInitiated) {
            var cells: [String: MapCell] = [:]
            cells.reserveCapacity(rows * cols)
            let step = max(1, rows / 20)
            for r in 0..<rows {
                if Task.isCancelled { return nil }
                for c in 0..<cols {
                    let coord = MapCoordinate(row: r, col: c)
                    cells[coord.cellId] = MapCell(coordinate: coord, povrsina: .default)
                }
                if r % step == 0 {
                    let p = Double(r + 1) / Double(rows) * 0.9
                    await reportProgress(p, token: token)
                }
            }
            let heights = GameMap.makeInitialVertexHeights(rows: rows, cols: cols)
            await reportProgress(0.97, token: token)
            return GameMap(rows: rows, cols: cols, cells: cells, vertexHeights: heights)
        }.value
    }

    private func loadCatalogMap(path: String, token: UUID) async -> (map: GameMap, underground: [Placement])? {
        await reportProgress(0.08, token: token)
        guard let root = MapStorage.mapsRoot() else { return nil }
        let url = root.appendingPathComponent(path)
        return await Task.detached(priority: .userInitiated) {
            await reportProgress(0.2, token: token)
            guard let data = MapFileManager.load(from: url) else { return nil }
            await reportProgress(0.55, token: token)
            let cells = data.cells ?? GameMap.makeGrid(rows: data.rows, cols: data.cols)
            let heights: [String: CGFloat]
            if let vh = data.vertexHeights {
                heights = Dictionary(uniqueKeysWithValues: vh.map { ($0.key, CGFloat($0.value)) })
            } else {
                heights = GameMap.makeInitialVertexHeights(rows: data.rows, cols: data.cols)
            }
            await reportProgress(0.88, token: token)
            let map = GameMap(rows: data.rows, cols: data.cols, cells: cells, vertexHeights: heights)
            map.replacePlacements(data.placements)
            map.replaceVertexOffsets(data.vertexOffsetPoints)
            map.replaceLordStarts(data.lordStartSlots)
            map.originOffsetX = CGFloat(data.originOffsetX ?? 0)
            map.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
            return (map, data.undergroundPlacements ?? [])
        }.value
    }

    private func reportProgress(_ value: Double, token: UUID) async {
        await MainActor.run {
            guard loadToken == token else { return }
            loadProgress = min(0.99, max(loadProgress, value))
        }
    }

    private func startSelected() {
        guard canStart, let map = preparedMap else { return }
        AudioManager.shared.stopIntroSoundtrack()
        gameState.startSandboxWithPreparedMap(
            map: map,
            loadedFromFile: preparedFromFile,
            undergroundPlacements: preparedUnderground,
            initialGold: initialGold,
            initialWood: initialWood,
            initialIron: initialIron,
            initialStone: initialStone,
            initialFood: initialFood,
            initialHop: initialHop,
            initialHay: initialHay
        )
        applyExtraStartingGoods()
        isPresented = false
    }

    private func applyExtraStartingGoods() {
        gameState.addGood(.beer, initialBeer)
        gameState.addGood(.corn, initialCorn)
        gameState.addGood(.eggs, initialEggs)
        gameState.addGood(.grapes, initialGrapes)
        gameState.addGood(.meat, initialMeat)
        gameState.addGood(.cheese, initialCheese)
        gameState.addGood(.apple, initialApple)
        gameState.addGood(.candle, initialCandle)
        gameState.addGood(.flowers, initialFlowers)
        gameState.addGood(.leather, initialLeather)
        gameState.addGood(.shield, initialShield)
        gameState.addGood(.sausages, initialSausages)
        gameState.addGood(.spear, initialSpear)
        gameState.addGood(.spices, initialSpices)
        gameState.addGood(.sword, initialSword)
        gameState.addGood(.vegetables, initialVegetables)
        gameState.addGood(.wine, initialVine)
        gameState.addGood(.bow, initialBowAndSparrow)
    }

    private static let resourceGridColumns = 6
    private var resourceItems: [(iconName: String, value: Binding<Int>, fallback: String)] {
        [
            ("gold", $initialGold, "dollarsign.circle.fill"),
            ("wood_resource", $initialWood, "leaf.fill"),
            ("iron_resource", $initialIron, "cylinder.fill"),
            ("stone_resource", $initialStone, "mountain.2.fill"),
            ("bread_resource", $initialFood, "fork.knife"),
            ("hop_resource", $initialHop, "mug.fill"),
            ("hay_resource", $initialHay, "circle.hexagongrid.fill"),
            ("chicken_resource", $initialChicken, "bird.fill"),
            ("eggs_resouce", $initialEggs, "oval.fill"),
            ("corn_resource", $initialCorn, "leaf.fill"),
            ("grapes_resource", $initialGrapes, "leaf.circle.fill"),
            ("meat_resouce", $initialMeat, "fork.knife"),
            ("cheese_resource", $initialCheese, "square.fill"),
            ("beer_resource", $initialBeer, "mug.fill"),
            ("apple_resource", $initialApple, "apple.logo"),
            ("banana_resource", $initialBanana, "leaf.fill"),
            ("vegetables_resource", $initialVegetables, "carrot.fill"),
            ("spices_resources", $initialSpices, "leaf.fill"),
            ("candle_resource", $initialCandle, "flame.fill"),
            ("vine_resources", $initialVine, "drop.fill"),
            ("sosages_resouce", $initialSausages, "fork.knife"),
            ("leather_resources", $initialLeather, "square.fill"),
            ("flowers_resoiurce", $initialFlowers, "camera.macro"),
            ("medicine_reousrce", $initialMedicine, "cross.case.fill"),
            ("shield_resource", $initialShield, "shield.fill"),
            ("spear_resource", $initialSpear, "line.diagonal"),
            ("sword_resource", $initialSword, "line.diagonal"),
            ("crosbow_resource", $initialCrossbow, "scope"),
            ("mece_resource", $initialMace, "hammer.fill"),
            ("bow_and_sparrow_resouce", $initialBowAndSparrow, "arrow.up"),
        ]
    }

    private var resourcesSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: Self.resourceGridColumns), spacing: 16) {
                ForEach(Array(resourceItems.enumerated()), id: \.offset) { _, item in
                    resourceRow(iconName: item.iconName, value: item.value, systemFallback: item.fallback)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
    }

    private func loadDefaultsFromFile() {
        let def = StartingResourcesLoader.startingResources(for: "solo")
        initialGold = def.gold
        initialWood = def.wood
        initialIron = def.iron
        initialStone = def.stone
        initialFood = def.food
        initialHop = def.hop
        initialHay = def.hay
    }

    private func resourceRow(iconName: String, value: Binding<Int>, systemFallback: String) -> some View {
        let img = loadBarIcon(named: iconName)
        return VStack(spacing: 8) {
            Group {
                if let nsImg = img {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemFallback)
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .frame(width: 88, height: 88)
            HStack(spacing: 8) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - resourceStep)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: stepperButtonSize, height: stepperButtonSize)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.98))
                    .frame(minWidth: 40, alignment: .center)
                Button {
                    value.wrappedValue = min(resourceMax, value.wrappedValue + resourceStep)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: stepperButtonSize, height: stepperButtonSize)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private func importMap() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L("solo_import_map")
        guard panel.runModal() == .OK, let url = panel.url,
              let data = MapFileManager.load(from: url) else { return }
        showResources = false
        page = .maps
        let side = MapStorage.folderSide(rows: data.rows, cols: data.cols)
        let name = data.mapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : data.mapName
        if let path = storeImportedMap(data, from: url, side: side, name: name) {
            catalogRevision += 1
            selectAndLoad(.catalog(path))
        } else {
            loadImportedDirectly(data)
        }
    }

    private func storeImportedMap(_ data: MapEditorSaveData, from url: URL, side: Int, name: String) -> String? {
        let fileName = MapStorage.fileName(forMapName: name, slotFallback: .solo)
        guard let relative = MapStorage.relativePath(side: side, fileName: fileName),
              let destination = MapStorage.fileURL(side: side, fileName: fileName) else { return nil }
        MapStorage.createSizeFoldersIfNeeded()
        if destination.path != url.path {
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            do {
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                return nil
            }
        }
        let category = MapSizeCategory.from(rows: data.rows, cols: data.cols)
        MapCatalog.addOrUpdate(entry: MapCatalogEntry(
            path: relative,
            rows: data.rows,
            cols: data.cols,
            slot: MapEditorSlot.solo.rawValue,
            displayName: name,
            sizeCategory: category.rawValue,
            suggestedPlayers: MapEditorSlot.solo.defaultSuggestedPlayers,
            tags: MapEditorSlot.solo.defaultTags
        ))
        return relative
    }

    private func loadImportedDirectly(_ data: MapEditorSaveData) {
        selected = nil
        let cells = data.cells ?? GameMap.makeGrid(rows: data.rows, cols: data.cols)
        let heights: [String: CGFloat]
        if let stored = data.vertexHeights {
            heights = Dictionary(uniqueKeysWithValues: stored.map { ($0.key, CGFloat($0.value)) })
        } else {
            heights = GameMap.makeInitialVertexHeights(rows: data.rows, cols: data.cols)
        }
        let map = GameMap(rows: data.rows, cols: data.cols, cells: cells, vertexHeights: heights)
        map.replacePlacements(data.placements)
        map.replaceVertexOffsets(data.vertexOffsetPoints)
        map.replaceLordStarts(data.lordStartSlots)
        map.originOffsetX = CGFloat(data.originOffsetX ?? 0)
        map.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
        preparedMap = map
        preparedFromFile = true
        preparedUnderground = data.undergroundPlacements ?? []
        withAnimation(.easeOut(duration: 0.18)) { loadProgress = 1 }
    }

    private func L(_ key: String) -> String {
        LocalizedStrings.string(for: key, language: gameState.appLanguage)
    }
}

private struct EmptyMapThumbnail: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.48, blue: 0.22),
                    Color(red: 0.28, green: 0.38, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                let step = size.width / 8
                var path = Path()
                for i in 1..<8 {
                    let x = step * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    let y = step * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 0.8)
            }
        }
    }
}

#Preview {
    SoloSetupView(isPresented: .constant(true), showResources: .constant(false))
        .environmentObject(GameState())
        .frame(width: 1600, height: 920)
        .background(Color.black.opacity(0.5))
}
