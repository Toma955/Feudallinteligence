//
//  MapEditorView.swift
//  Feudalism
//
//  Map Editor – uređivanje mape: postavljanje zidova, brisanje, spremanje/učitavanje.
//

import SwiftUI
import AppKit

// MARK: - Donji mini izbornik (kategorije)
private enum MapEditorBottomCategory: String, CaseIterable, Identifiable {
    case biljke = "Biljke"
    case životinje = "Životinje"
    case trava = "Trava"
    case teren = "Teren"
    case vode = "Vode"
    case evakuacija = "Evakuacija"

    var id: String { rawValue }
    var label: String { rawValue }
    var systemImage: String {
        switch self {
        case .biljke: return "leaf.fill"
        case .životinje: return "pawprint.fill"
        case .trava: return "crop"
        case .teren: return "map.fill"
        case .vode: return "drop.fill"
        case .evakuacija: return "figure.run"
        }
    }
}

/// Stavka donjeg bara editora: AI lordovi, kategorije građevina iz igre, pa alati editora.
private enum EditorBarItem: Hashable, Identifiable {
    case aiLords
    case build(BottomBarCategory)
    case tool(MapEditorBottomCategory)

    static var all: [EditorBarItem] {
        [.aiLords]
            + BottomBarCategory.surfaceBuildCategories.map { .build($0) }
            + MapEditorBottomCategory.allCases.map { .tool($0) }
    }

    var id: String {
        switch self {
        case .aiLords: return "aiLords"
        case .build(let category): return "build_\(category.rawValue)"
        case .tool(let category): return "tool_\(category.rawValue)"
        }
    }

    var label: String {
        switch self {
        case .aiLords: return "AI lordovi"
        case .build(let category):
            switch category {
            case .castle: return "Dvor"
            case .sword: return "Oružje"
            case .mine: return "Rudnik"
            case .house: return "Kuća"
            case .cave: return "Podzemlje"
            case .farm: return "Farma"
            case .food: return "Hrana"
            case .infra: return "Transportna infrastruktura"
            case .tools: return "Alati"
            }
        case .tool(let category): return category.label
        }
    }

    /// Klik na mapu postavlja odabrani objekt (građevine, biljke).
    var placesObjects: Bool {
        switch self {
        case .build, .tool(.biljke): return true
        default: return false
        }
    }
}

private let editorBottomBarButtonSize: CGFloat = 44
private let editorBottomBarSpacing: CGFloat = 12

struct MapEditorView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var gridShow10 = false
    @State private var gridShow40 = false
    @State private var handPanMode = false
    @State private var eraseMode = false
    @State private var saveLoadMessage: String?
    @State private var showSaveLoadAlert = false
    @State private var expandedItem: EditorBarItem?
    @State private var selectedLordSlot: Int = 1
    @State private var terrainToolOption: TerrainToolOption = .raise5
    @State private var terrainBrushOption: TerrainBrushOption = .size1
    @State private var paintMode: MapEditorPaintMode = .visina
    @State private var surfaceBrush: PovrsinaType = .plodna
    @State private var padBrush: PadBrush = .plodna
    @State private var depositBrush: DepositBrush = .kamen
    @State private var buildableBrush = false
    @State private var movementBrush: Double = 1

    private var isTerrainActive: Bool { expandedItem == .tool(.teren) }
    private var isAILordsActive: Bool { expandedItem == .aiLords }

    var body: some View {
        MapScreenLayout(
            topBar: { editorToolbar },
            content: {
                SceneKitMapView(
                    showGrid: gridShow10 || gridShow40,
                    gridShow10: gridShow10,
                    gridShow40: gridShow40,
                    handPanMode: $handPanMode,
                    isEraseMode: eraseMode,
                    onRemoveAt: eraseMode ? { gameState.removePlacement(at: MapCoordinate(row: $0, col: $1)) } : nil,
                    isTerrainEditMode: isTerrainActive,
                    terrainTool: isTerrainActive ? terrainToolOption : nil,
                    terrainBrushOption: isTerrainActive ? terrainBrushOption : nil,
                    onTerrainEdit: nil,
                    onTerrainAddBrushSelection: isTerrainActive ? { r, c in
                        applyTerrainBrush(row: r, col: c)
                    } : (isAILordsActive ? { r, c in
                        placeLordStart(row: r, col: c)
                    } : nil),
                    onCellSelectionToggle: nil,
                    isCellSelectionMode: false,
                    onVertexDotSelected: nil,
                    onExitTerrainEditMode: isTerrainActive ? { withAnimation(.easeInOut(duration: 0.28)) { expandedItem = nil } } : nil,
                    editorOverlayMode: isTerrainActive ? paintMode : nil,
                    selectedLordStartSlot: isAILordsActive ? selectedLordSlot : nil
                )
                .ignoresSafeArea()
            },
            loadingMessage: nil,
            darkBackground: false,
            customOverlay: {
                ZStack(alignment: .bottom) {
                    // Status teksture samo kad nije u redu (greška); kad je OK – ništa ne prikazujemo
                    ZStack(alignment: .bottomLeading) {
                        if let status = gameState.wallTextureStatus, status != "OK" {
                            Text(status)
                                .font(.caption.monospaced())
                                .padding(8)
                                .background(.black.opacity(0.7))
                                .foregroundStyle(.orange)
                                .cornerRadius(6)
                                .padding(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    // Donji bar kao "island": klik na ikonu proširuje sam bar
                    editorBottomBar
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear) // eksplicitno prozirno – bez implicitnog zatamnjenja kad je Teren odabran
            }
        )
        .onAppear {
            PlacementDebugConsole.verbose = true
            let (ok, message) = HugeWall.checkAndLogTextureStatus(bundle: .main)
            gameState.wallTextureStatus = ok ? "OK" : message
        }
        .onChange(of: expandedItem) { item in
            if item?.placesObjects == true { eraseMode = false } else { gameState.selectedPlacementObjectId = nil }
        }
        .alert("Uređivač mape", isPresented: $showSaveLoadAlert) {
            Button("OK") { showSaveLoadAlert = false }
        } message: {
            if let msg = saveLoadMessage { Text(msg) }
        }
    }

    /// Klik na mapu u kategoriji Teren: primijeni odabrani način rada na četkicu.
    private func applyTerrainBrush(row: Int, col: Int) {
        switch paintMode {
        case .visina:
            gameState.applyTerrainElevation(centerRow: row, centerCol: col, tool: terrainToolOption, brushOption: terrainBrushOption)
        case .teren:
            gameState.paintSurface(centerRow: row, centerCol: col, brushOption: terrainBrushOption, surface: surfaceBrush)
        case .podloge:
            gameState.paintPad(centerRow: row, centerCol: col, brushOption: terrainBrushOption, pad: padBrush)
        case .naslage:
            gameState.paintDeposit(centerRow: row, centerCol: col, brushOption: terrainBrushOption, deposit: depositBrush)
        case .gradnja:
            gameState.paintBuildable(centerRow: row, centerCol: col, brushOption: terrainBrushOption, buildable: buildableBrush)
        case .kretanje:
            gameState.paintMovementIndex(centerRow: row, centerCol: col, brushOption: terrainBrushOption, index: movementBrush)
        case .precizno:
            gameState.mapEditorState?.selectedCell = MapCoordinate(row: row, col: col)
            gameState.objectWillChange.send()
        }
    }

    private func pill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? .yellow : .white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// Panel za teren: visina, teren, podloge, naslage, gradnja, kretanje, precizno.
    /// Sve se mijenja samo na gornjoj mapi; podzemlje se ne podiže ni ne spušta.
    private var terrainToolPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(MapEditorPaintMode.allCases) { mode in
                    pill(mode.rawValue, selected: paintMode == mode) { paintMode = mode }
                }
            }
            switch paintMode {
            case .visina:
                heightToolRows
            case .teren:
                HStack(spacing: 6) {
                    ForEach(PovrsinaType.allCases) { surface in
                        pill(surface.displayName, selected: surfaceBrush == surface) { surfaceBrush = surface }
                    }
                }
            case .podloge:
                HStack(spacing: 8) {
                    ForEach(PadBrush.allCases) { pad in
                        padSwatch(pad, selected: padBrush == pad)
                    }
                    Text("Trava je samo tekstura. Zeleno = farme, sivo = kamen, crveno-sivo = željezo.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            case .naslage:
                HStack(spacing: 6) {
                    ForEach(DepositBrush.allCases) { deposit in
                        pill(deposit.rawValue, selected: depositBrush == deposit) { depositBrush = deposit }
                    }
                    Text("Rudnik i kamenolom: najmanje 80 % tlocrta na rudi. Ista pravila u editoru i u igri.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            case .gradnja:
                HStack(spacing: 6) {
                    pill("Zabrani gradnju", selected: !buildableBrush) { buildableBrush = false }
                    pill("Dozvoli gradnju", selected: buildableBrush) { buildableBrush = true }
                    Text("Crveno = ne može se graditi (i more, voda, močvara).")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            case .kretanje:
                HStack(spacing: 6) {
                    ForEach([0, 0.4, 0.6, 0.8, 1, 1.5], id: \.self) { index in
                        pill(String(format: "%.1f", index), selected: movementBrush == index) { movementBrush = index }
                    }
                    Text("0 = neprohodno, 1 = normalno, 1.5 = put.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            case .precizno:
                precisePointsPanel
            }
        }
    }

    /// Precizno: 5 točaka odabrane ćelije – visina ±0.25 m, pomak ±0.05 m.
    @ViewBuilder
    private var precisePointsPanel: some View {
        if let cell = gameState.mapEditorState?.selectedCell {
            let surface = gameState.gameMap.surface(row: cell.row, col: cell.col)
            let names = ["Gore lijevo", "Gore desno", "Dolje desno", "Dolje lijevo", "Sredina"]
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ćelija \(cell.cellId) · \(surface.isFlat ? "ravna" : "nakošena")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Spacer()
                    pill("Poništi pomake", selected: false) { gameState.resetSurfacePoints(row: cell.row, col: cell.col) }
                }
                ForEach(0..<5, id: \.self) { index in
                    let point = surface.allPoints[index]
                    HStack(spacing: 6) {
                        Text("\(names[index]): \(String(format: "%.2f", point.height)) m")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 170, alignment: .leading)
                        pill("▲", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dHeight: 0.25) }
                        pill("▼", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dHeight: -0.25) }
                        pill("←", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dx: -0.05) }
                        pill("→", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dx: 0.05) }
                        pill("↑", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dz: -0.05) }
                        pill("↓", selected: false) { gameState.nudgeSurfacePoint(row: cell.row, col: cell.col, point: index, dz: 0.05) }
                    }
                }
            }
        } else {
            Text("Klikni ćeliju na mapi. Svaka ploča ima 5 točaka: 4 kuta i sredinu.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var heightToolRows: some View {
        let selectedVertex = gameState.mapEditorState?.selectedVertex
        return VStack(alignment: .leading, spacing: 12) {
            Text("Podiži i spuštaj samo gornju mapu (−5 … +100 m). Podzemlje ostaje ravno, 10 m ispod.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
            if let v = selectedVertex {
                HStack(spacing: 10) {
                    Text("Točka \(v.row),\(v.col)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.yellow)
                    ForEach(TerrainToolOption.allCases.filter { $0 != .flatten }, id: \.rawValue) { option in
                        heightToolIcon(option, selected: false, size: 30) {
                            gameState.applyVertexElevation(vertexRow: v.row, vertexCol: v.col, tool: option)
                        }
                    }
                    Button("Odznači") {
                        gameState.mapEditorState?.selectedVertex = nil
                        gameState.mapEditorState?.objectWillChange.send()
                        gameState.objectWillChange.send()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.15))
                }
                .padding(8)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 8) {
                ForEach(TerrainToolOption.allCases, id: \.rawValue) { option in
                    heightToolIcon(option, selected: paintMode == .visina && terrainToolOption == option, size: 40) {
                        paintMode = .visina
                        terrainToolOption = option
                    }
                    if option == .raise10 || option == .lower10 {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 1, height: 28)
                    }
                }
                Rectangle()
                    .fill(.white.opacity(0.45))
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 6)
                ForEach(PadBrush.allCases) { pad in
                    padSwatch(pad, selected: paintMode == .podloge && padBrush == pad)
                }
            }
        }
    }

    private func padSwatch(_ pad: PadBrush, selected: Bool) -> some View {
        Button {
            paintMode = .podloge
            padBrush = pad
        } label: {
            VStack(spacing: 3) {
                padPreview(pad)
                    .frame(width: 36, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(selected ? Color.yellow : Color.white.opacity(0.25), lineWidth: selected ? 2 : 1)
                    )
                Text(pad.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(selected ? .yellow : .white.opacity(0.88))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(selected ? Color.white.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(pad.rawValue)
    }

    @ViewBuilder
    private func padPreview(_ pad: PadBrush) -> some View {
        switch pad {
        case .trava:
            Color(red: 0.38, green: 0.58, blue: 0.24)
        case .plodna:
            Color(red: 0.18, green: 0.62, blue: 0.22)
        case .kamen:
            Color(red: 0.55, green: 0.55, blue: 0.58)
        case .zeljezo:
            HStack(spacing: 0) {
                Color(red: 0.22, green: 0.22, blue: 0.24)
                Color(red: 0.78, green: 0.16, blue: 0.14)
            }
        case .rijeka:
            Color(red: 0.25, green: 0.55, blue: 0.88)
        case .more:
            Color(red: 0.08, green: 0.24, blue: 0.58)
        case .pijesak:
            Color(red: 0.86, green: 0.74, blue: 0.46)
        case .obicno:
            Color(red: 0.40, green: 0.27, blue: 0.15)
        case .mocvara:
            Color(red: 0.28, green: 0.38, blue: 0.22)
        case .obrisi:
            Color.white.opacity(0.18)
        }
    }

    /// Ikona alata za visinu: strelica gore/dolje s brojem metara, ili izravnaj.
    private func heightToolIcon(_ option: TerrainToolOption, selected: Bool, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: option.systemImage)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(selected ? .yellow : .white.opacity(0.92))
                    .frame(width: size, height: size)
                if let badge = option.badge {
                    Text(badge)
                        .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3)
                        .background(selected ? Color.yellow : Color.white, in: Capsule())
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: size, height: size)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help(option.rawValue)
    }

    /// Klik na mapu u AI lordovima: odabrano mjesto sjeda na ćeliju, odabir prelazi na sljedeće prazno.
    private func placeLordStart(row: Int, col: Int) {
        let map = gameState.gameMap
        map.setLordStart(slot: selectedLordSlot, at: MapCoordinate(row: row, col: col))
        if let next = (1...GameMap.maxLordStarts).first(where: { map.lordStarts[$0] == nil }) {
            selectedLordSlot = next
        }
    }

    /// AI lordovi: početna mjesta dvoraca (1 … 8). Lordovi u partiji redom zauzimaju mjesta.
    private var aiLordsPanel: some View {
        let starts = gameState.gameMap.lordStarts
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(1...GameMap.maxLordStarts, id: \.self) { slot in
                    let placed = starts[slot]
                    Button {
                        selectedLordSlot = slot
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(placed != nil ? LordStartPalette.swiftUIColor(slot: slot) : Color.white.opacity(0.08))
                                Circle()
                                    .strokeBorder(
                                        selectedLordSlot == slot ? Color.yellow : LordStartPalette.swiftUIColor(slot: slot).opacity(0.9),
                                        lineWidth: selectedLordSlot == slot ? 2.5 : 1.5
                                    )
                                Text("\(slot)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 38, height: 38)
                            Text(placed.map { "\($0.row),\($0.col)" } ?? "—")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .buttonStyle(.plain)
                    .help(placed == nil ? "Lord \(slot): klikni na mapu za početno mjesto" : "Lord \(slot): klikni na mapu za premještanje")
                }
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1, height: 36)
                pill("Ukloni \(selectedLordSlot)", selected: false) {
                    gameState.gameMap.setLordStart(slot: selectedLordSlot, at: nil)
                    gameState.objectWillChange.send()
                }
                pill("Ukloni sve", selected: false) {
                    gameState.gameMap.replaceLordStarts([:])
                    gameState.objectWillChange.send()
                }
            }
            Text("Odaberi broj pa klikni na mapu – tu će AI lord dobiti dvorac. Lordovi bez mjesta raspoređuju se u krug.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func expandedContent(for item: EditorBarItem) -> some View {
        switch item {
        case .aiLords:
            aiLordsPanel
        case .build(let category):
            BuildCategoryContent(category: category)
        case .tool(.biljke):
            PlantsButtonExpandedView()
        case .tool(.teren):
            terrainToolPanel
        case .tool(let category):
            Text("\(category.label) – uskoro.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func barIcon(for item: EditorBarItem, size: CGFloat) -> some View {
        switch item {
        case .aiLords:
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.yellow.opacity(0.95))
        case .build(let category):
            BuildCategoryIcon(category: category, size: size * 0.62)
        case .tool(.biljke):
            TreeIcon(size: size * 0.7)
        case .tool(let category):
            Image(systemName: category.systemImage)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// Donji bar kao "island": jedan oblik; klik na ikonu ga proširuje prema gore sa sadržajem kategorije,
    /// ponovni klik na istu ikonu ga skuplja.
    private var editorBottomBar: some View {
        let compact = expandedItem != nil
        let icon = CGFloat(gameState.bottomBarIconScale)
        let area = CGFloat(gameState.bottomBarAreaScale)
        let buttonSize: CGFloat = (compact ? 38 : editorBottomBarButtonSize) * icon
        return VStack(spacing: 0) {
            if let item = expandedItem {
                expandedContent(for: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                    .id(item.id)
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
            HStack(spacing: (compact ? 8 : editorBottomBarSpacing) * icon) {
                ForEach(EditorBarItem.all) { item in
                    let selected = expandedItem == item
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            if selected {
                                expandedItem = nil
                            } else {
                                if expandedItem != nil, gameState.playBarTransitionSound {
                                    AudioManager.shared.playSound(named: "transition", volume: gameState.effectiveSoundsVolume)
                                }
                                expandedItem = item
                            }
                        }
                    } label: {
                        barIcon(for: item, size: buttonSize)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(selected ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(selected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(item.label)
                    if item == .aiLords || item == .build(.food) {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 1, height: buttonSize * 0.6)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, compact ? 10 : 12)
        }
        .fixedSize(horizontal: !compact, vertical: true)
        .frame(maxWidth: compact ? 1180 * area : nil)
        .background { BottomBarIslandChrome(corner: compact ? 20 : 24) }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 20 : 24))
        .shadow(color: .black.opacity(0.25 * gameState.bottomBarOpacity), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.28), value: expandedItem)
        .padding(.horizontal, 18)
    }

    private var editorToolbar: some View {
        VStack(spacing: 8) {
            editorHUDIsland
            HUDMessageStrip()
        }
    }

    private var editorHUDIsland: some View {
        MapScreenHUDBar {
            // Isti kompas i zoom kao u solo modu (kamera)
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

            HUDBarDivider()

            Button {
                gameState.closeMapEditor()
            } label: {
                Label("Nazad", systemImage: "chevron.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.plain)

            HUDBarDivider()

            if isTerrainActive {
                // Četkica: 1×1, 3×3, 5×5, 7×7 — jednim klikom cijelo područje.
                HStack(spacing: 10) {
                    ForEach(TerrainBrushOption.allCases, id: \.rawValue) { option in
                        Button {
                            terrainBrushOption = option
                        } label: {
                            Text(option.displayLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(terrainBrushOption == option ? .yellow : .white.opacity(0.6))
                                .frame(minWidth: 36)
                        }
                        .buttonStyle(.plain)
                        .help("Četkica \(option.displayLabel)")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .help("Visina elementa (ćelija): veličina četkice. Klik na mapu mijenja visinu cijele ćelije ili područja.")
                HUDBarDivider()
            }

            Button {
                eraseMode.toggle()
                if eraseMode { gameState.selectedPlacementObjectId = nil }
            } label: {
                Label("Briši", systemImage: "eraser.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(eraseMode ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            HUDBarDivider()

            Button {
                gameState.clearEditorMap()
            } label: {
                Label("Očisti mapu", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                let result = gameState.saveEditorMap()
                if result.success {
                    saveLoadMessage = "Mapa spremljena."
                } else {
                    saveLoadMessage = result.errorMessage ?? "Spremanje nije uspjelo."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Spremi", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                if gameState.loadEditorMap(fromSlot: .solo) {
                    saveLoadMessage = "Mapa učitana."
                } else {
                    saveLoadMessage = "Učitavanje nije uspjelo (nema datoteke ili format)."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Učitaj", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HUDBarDivider()

            Text("Mapa: \(gameState.gameMap.displayDimensionString)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            HUDBarDivider()

            Text("Mreža:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                gridShow10.toggle()
            } label: {
                Text("10×10")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(gridShow10 ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                gridShow40.toggle()
            } label: {
                Text("40×40")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(gridShow40 ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

        }
    }
}

#Preview {
    MapEditorView()
        .environmentObject(GameState())
        .frame(width: 1200, height: 800)
}
