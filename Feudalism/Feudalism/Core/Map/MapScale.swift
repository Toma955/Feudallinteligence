//
//  MapScale.swift
//  Feudalism
//
//  Jedan izvor istine za prostor na mapi:
//  - 1 world jedinica = 1 metar.
//  - Mapa 200×200 = 200×200 metara (200 ćelija po strani).
//  - 1 ćelija za postavljanje = 1×1 metar. Građevina 4×4×4 zauzima 4×4×4 metra.
//  - Mreže 10×10 i 40×40 u Map Editoru su linije svakih 10 m i 40 m.
//
//  Što svaka minimalna prostorna jedinica (10×10) mora imati (nepromjenjivo):
//  - id, x (koordinata), y (koordinata)
//  - textureId (ID teksture – jedna po polju)
//  - objectIds (ID objekata – više po polju; npr. zelena polja: žbunje, stabla; može biti voda)
//  - elevation (elevacija; može ići u minus)
//  - walkable (Bool: hodanje), buildable (Bool: građenje objekata), canAfforest (Bool: pošumljavanje), canDigChannels (Bool: kupanje kanala)
//
//  Na mapi mora postojati točka 0.0, 0.0 (world x, y) kao ishodište za pozicioniranje mreža (10×10, 40×40) i sadržaja.
//

import Foundation
import CoreGraphics

/// Pravila prostora i dimenzija. 1 world jedinica = 1 metar.
enum MapScale {
    // MARK: - Ishodište mape (0, 0)
    /// World X ishodišta mape – uvijek 0.0; mreže i sadržaj pozicioniraju se relativno na to.
    static let mapOriginWorldX: CGFloat = 0
    /// World Z ishodišta mape (y u ravnini XZ) – uvijek 0.0; mreže i sadržaj pozicioniraju se relativno na to.
    static let mapOriginWorldZ: CGFloat = 0

    // MARK: - Metar
    /// 1 world jedinica = 1 metar. Mapa, građevine i visine koriste ovu skalu.
    static let metersPerWorldUnit: CGFloat = 1

    /// Najmanja prostorna jedinica: 1×1 metar.
    static let smallSpatialUnitWorldUnits: CGFloat = 1

    /// Jedna ćelija za gradnju = 1 metar. Nema dodatnog množenja.
    static let smallCellsPerObjectCubeSide: Int = 1

    /// 1 ćelija za postavljanje i zid = 1×1 metar.
    static var objectCubeWorldUnits: CGFloat { metersPerWorldUnit }

    /// Pretvori metre u world jedinice.
    static func meters(_ value: Int) -> CGFloat { CGFloat(value) * metersPerWorldUnit }

    /// Editor: linija mreže svakih 10 metara.
    static let gridStep10Meters: CGFloat = 10
    /// Editor: linija mreže svakih 40 metara.
    static let gridStep40Meters: CGFloat = 40

    /// 10 prostornih kocki čini jedinicu dimenzije mape (mapa side = broj metara po strani).
    static let objectCubesPerMapDimensionUnit: Int = 10

    // MARK: - Izvedene veličine (ćelija = 1×1 metar)
    /// 1 logička ćelija mape = 1×1 metar. Preset 200×200 = 200×200 metara.
    static var worldUnitsPerMapCell: CGFloat { metersPerWorldUnit }

    /// Elevacija: 1 korak = 1 metar.
    static var worldUnitsPerElevationStep: CGFloat { metersPerWorldUnit }

    /// Broj minimalnih jedinica po strani za dani preset (200, 400, …). To je „side” u MapDimension.
    static func smallUnitsPerSide(presetSide side: Int) -> Int { side }

    /// Broj ćelija za gradnju po strani. 200 m → 200 ćelija.
    static func placementCellsPerSide(smallUnitsPerSide side: Int) -> Int {
        side / smallCellsPerObjectCubeSide
    }

    /// World širina mape kad ima side metara po strani.
    static func worldWidth(smallUnitsPerSide side: Int) -> CGFloat {
        CGFloat(side) * smallSpatialUnitWorldUnits
    }

    /// World širina mape u metrima: cols ćelija × 1 m.
    static func worldWidth(cols: Int) -> CGFloat {
        CGFloat(cols) * worldUnitsPerMapCell
    }

    /// World dubina mape u metrima: rows ćelija × 1 m.
    static func worldHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * worldUnitsPerMapCell
    }

    // MARK: - Dimenzija mape (uvijek kockasta) – izvor: Core/Enums/MapDimensions.swift
    /// Dozvoljene strane mape u minimalnim jedinicama: 200, 400, 600, 800, 1000 (broj 10×10 jedinica po strani).
    static var allowedMapSides: [Int] { MapDimension.allSides }

    /// Je li zadani side valjan (kockasta mapa).
    static func isValidMapSide(_ side: Int) -> Bool {
        MapDimension.isValid(side)
    }
}

// MARK: - Generator mape (nova mapa)
enum MapGenerator {
    /// Kreira prvu (praznu) mapu i file preko MapFileManager.createMapFile (sinkrono – može blokirati glavnu nit).
    static func createAndSaveMap(name: String, side: Int, slot: MapEditorSlot = .solo) -> GameMap? {
        MapFileManager.createMapFile(name: name, side: side, slot: slot)
    }

    /// Kreira prvu mapu s enumom dimenzije (npr. .size200 → 200×200). Isto što createAndSaveMap(name:side:slot:) s dimension.side.
    static func createAndSaveMap(name: String, dimension: MapDimension, slot: MapEditorSlot = .solo) -> GameMap? {
        createAndSaveMap(name: name, side: dimension.side, slot: slot)
    }

    /// Kreira mapu na pozadinskom threadu (igra ne zastaje), sprema u file, na main thread pozove completion s GameMap ili nil.
    static func createAndSaveMapAsync(name: String, side: Int, slot: MapEditorSlot = .solo, completion: @escaping (GameMap?) -> Void) {
        guard MapScale.isValidMapSide(side) else { DispatchQueue.main.async { completion(nil) }; return }
        let nameTrimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameTrimmed.isEmpty else { DispatchQueue.main.async { completion(nil) }; return }

        DispatchQueue.global(qos: .userInitiated).async {
            let rows = MapCreationRules.rows(forPresetSide: side)
            let cols = MapCreationRules.cols(forPresetSide: side)
            let cells = GameMap.makeGrid(rows: rows, cols: cols)
            let vertexHeights = GameMap.makeInitialVertexHeights(rows: rows, cols: cols)
            let gameMap = GameMap(rows: rows, cols: cols, cells: cells, vertexHeights: vertexHeights)
            let vertexHeightsDouble = Dictionary(uniqueKeysWithValues: vertexHeights.map { ($0.key, Double($0.value)) })
            let data = MapEditorSaveData(
                mapName: nameTrimmed,
                rows: rows,
                cols: cols,
                placements: [],
                cells: cells,
                createdDate: Date(),
                originOffsetX: 0,
                originOffsetZ: 0,
                vertexHeights: vertexHeightsDouble
            )
            let fileName = MapStorage.fileName(forMapName: nameTrimmed, slotFallback: slot)
            guard let fileURL = MapStorage.fileURL(side: side, fileName: fileName) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            MapStorage.createSizeFoldersIfNeeded()

            DispatchQueue.global(qos: .utility).async {
                let (saved, _) = MapFileManager.save(data: data, to: fileURL)
                DispatchQueue.main.async {
                    if saved, let rel = MapStorage.relativePath(side: side, fileName: fileName) {
                        let category = MapSizeCategory.from(rows: rows, cols: cols)
                        let entry = MapCatalogEntry(
                            path: rel,
                            rows: rows,
                            cols: cols,
                            slot: slot.rawValue,
                            displayName: nameTrimmed,
                            sizeCategory: category.rawValue,
                            suggestedPlayers: slot.defaultSuggestedPlayers,
                            tags: slot.defaultTags
                        )
                        MapCatalog.addOrUpdate(entry: entry)
                    }
                    completion(saved ? gameMap : nil)
                }
            }
        }
    }
}
