//
//  WarehouseSpotNotebook.swift
//  Feudalism
//
//  Bilježnica jednog polja 2×2: koliko jedinica jednog resursa na njega stane.
//  Čita warehouse_spots.json. Ako datoteke nema, kamen je 60, sve ostalo 50.
//

import Foundation

enum WarehouseSpotNotebook {
    private static let fileName = "warehouse_spots"
    private static let subdirs = ["Config", "Core/Config", "Feudalism/Core/Config"]

    private struct FileShape: Decodable {
        var zadano: Int?
        var mjesto: [String: Int]?
    }

    private static let file: FileShape? = {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(FileShape.self, from: data)
    }()

    /// Najviše jedinica te robe na jednom polju. Zlato nema polje.
    static func limit(for good: Good) -> Int {
        if good == .gold { return 0 }
        if let listed = file?.mjesto?[good.rawValue] { return max(0, listed) }
        if good == .stone { return 60 }
        return max(0, file?.zadano ?? 50)
    }

    private static func loadData() -> Data? {
        let bundle = Bundle.main
        for sub in subdirs {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        if let url = bundle.url(forResource: fileName, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}
