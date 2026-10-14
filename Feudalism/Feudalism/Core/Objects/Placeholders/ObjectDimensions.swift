//
//  ObjectDimensions.swift
//  Feudalism
//
//  Jedna datoteka za sve dimenzije objekata: širina/dubina u ćelijama i visina u „katovima”.
//  Prostor i razmaci ostaju ovdje – placeholders i stvarni modeli koriste iste vrijednosti.
//

import Foundation

/// Dimenzije jednog objekta u metrima: tlocrt (cellWidth × cellHeight) i visina.
struct ObjectDimension {
    let cellWidth: Int
    let cellHeight: Int
    /// Visina u metrima (1 = 1 metar).
    let heightCells: Int
}

/// Jedan izvor dimenzija za sve objekte. Mijenjaj vrijednosti ovdje.
enum ObjectDimensions {

    // MARK: - Zidovi i stepenice (reference – ne koriste PlaceholderBox)
    static let hugeWall = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 10)
    static let smallWall = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 6)
    static let steps = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)

    // MARK: - Dvorac
    /// Dvorac: 8×8 ćelija, visina 8 kata.
    static let castle = ObjectDimension(cellWidth: 8, cellHeight: 8, heightCells: 8)
    /// Tržnica: 5×5 ćelija, visina 4 kata.
    static let market = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 4)
    /// Bunar (zdenac): 2×2×3.
    static let well = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 3)
    /// Izvor: 2×2×1.
    static let spring = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 1)
    /// Stablo: 2×2, visina 7 m.
    static let tree = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 7)
    /// Veliki hrast: 4×4, visina 12 m.
    static let oak = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 12)
    /// Jela: 2×2, visina 9 m.
    static let fir = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 9)
    /// Čempres: 2×2, visina 10 m.
    static let cypress = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 10)
    /// Palma: 2×2, visina 8 m.
    static let palm = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 8)
    static let rockSmall = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let rockMedium = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 2)
    static let rockLarge = ObjectDimension(cellWidth: 3, cellHeight: 3, heightCells: 4)
    static let hotel = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 10)
    /// Staja za konje: 5×4×4.
    static let stable = ObjectDimension(cellWidth: 5, cellHeight: 4, heightCells: 4)
    /// Vrata: 4×4×5.
    static let gates = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 5)
    /// Rudari: 4×6×4.
    static let miners = ObjectDimension(cellWidth: 4, cellHeight: 6, heightCells: 4)
    /// Inženjering: 4×6×4.
    static let engineering = ObjectDimension(cellWidth: 4, cellHeight: 6, heightCells: 4)

    // MARK: - Hrana
    static let windmill = ObjectDimension(cellWidth: 3, cellHeight: 2, heightCells: 10)
    static let bakery = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 2)
    static let granary = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 4)
    /// Pivovara: 4×4×4.
    static let brewery = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    /// Destilerija: 4×4×5.
    static let distillery = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 5)
    /// Vinski podrum: 5×5×3.
    static let wineCellar = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 3)
    /// Krčma: 5×4×4.
    static let tavern = ObjectDimension(cellWidth: 5, cellHeight: 4, heightCells: 4)
    /// Smočnica: 4×4×4.
    static let smocnica = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    /// Hrana: prozirna drvena kocka 4×4×4.
    static let food = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    /// Zalogajnica: 4×4×3.
    static let canteen = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 3)
    /// Svijećarnica: 3×3×3.
    static let candleShop = ObjectDimension(cellWidth: 3, cellHeight: 3, heightCells: 3)

    // MARK: - Farme
    /// Sve farme: 5×5 (četiri polja 2×2 + križ širine 1 + zgrada na polju 4).
    static let farmYard = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 2)
    static let farm = farmYard
    static let chicken = farmYard
    static let corn = farmYard
    static let hop = farmYard
    static let vegetables = farmYard
    static let grapes = farmYard
    static let spices = farmYard
    static let flower = farmYard
    static let appleOrchard = farmYard
    static let pig = farmYard
    static let cow = farmYard
    static let sheep = farmYard
    static let hive = farmYard

    // MARK: - Industrija
    static let iron = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 3)
    static let stone = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 6)
    /// Skladište (lager): 5×5×1 (vrlo nisko 0.1 → 1 kat).
    static let lager = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 1)
    /// Spremište za granu: 4×4×4 metra.
    static let wood = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    /// Kola: 3×2×3.
    static let carriage = ObjectDimension(cellWidth: 3, cellHeight: 2, heightCells: 3)

    // MARK: - Kuća
    /// Kuća: 4×4×4.
    static let house = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    /// Ljekarna: 6×6×11.
    static let pharmacy = ObjectDimension(cellWidth: 6, cellHeight: 6, heightCells: 11)
    /// Staklenik: 6×6×11.
    static let greenhouse = ObjectDimension(cellWidth: 6, cellHeight: 6, heightCells: 11)
    /// Crkva: 4×4×6.
    static let church = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 6)
    /// Diplomacija: 5×5×6.
    static let diplomacy = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 6)
    /// Akademija: 5×5×5.
    static let academy = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 5)

    // MARK: - Oružje
    /// Mač, štit, luk, koplje i koža: 4×4 metra. Trening i oružarnica ostaju 5×5.
    static let sword = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    static let shield = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    static let bow = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    static let spear = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    static let leather = ObjectDimension(cellWidth: 4, cellHeight: 4, heightCells: 4)
    static let training = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 4)
    static let armory = ObjectDimension(cellWidth: 5, cellHeight: 5, heightCells: 4)

    // MARK: - Infrastruktura
    static let road = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let stoneSlab = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let bridge = ObjectDimension(cellWidth: 3, cellHeight: 1, heightCells: 2)
    static let tunnel = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 3)
    static let canal = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let river = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let flag = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 4)
    static let torch = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 2)
    static let monument = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 4)
    static let candle = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
    static let ornamentalTree = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 5)
    static let fountain = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 2)
    static let roof = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 3)

    // MARK: - Podzemlje
    /// Ulaz: 2×2×2.
    static let undergroundEntrance = ObjectDimension(cellWidth: 2, cellHeight: 2, heightCells: 2)
    /// Hodnik: 1×1×3.
    static let undergroundCorridor = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 3)
    /// Svjetlosni otvor: 1×1×1.
    static let undergroundLightOpening = ObjectDimension(cellWidth: 1, cellHeight: 1, heightCells: 1)
}
