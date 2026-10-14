//
//  BuildingWorkersNotebook.swift
//  Feudalism
//
//  Bilježnica: koliko radnika treba svaka građevina da radi punom snagom.
//  Čita building_workers.json. Ako datoteke nema, svako radno mjesto treba 1.
//

import Foundation

enum BuildingWorkersNotebook {
    private static let fileName = "building_workers"
    private static let subdirs = ["Config", "Core/Config", "Feudalism/Core/Config"]

    private struct FileShape: Decodable {
        var zadano: Int?
        var gradevine: [String: Int]?
    }

    private static let file: FileShape? = {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(FileShape.self, from: data)
    }()

    /// Koliko radnika mora biti dodijeljeno građevini.
    static func required(for objectId: String) -> Int {
        if let listed = file?.gradevine?[objectId] { return max(1, listed) }
        return max(1, file?.zadano ?? 1)
    }

    /// Koliko ih mora biti unutra da proizvodnja ide (ostali smiju biti kuriri).
    static func producersRequired(for objectId: String) -> Int {
        let crew = required(for: objectId)
        guard crew >= 2, let cycle = WorkCycleCatalog.cycle(for: objectId) else { return crew }
        let hauls = !cycle.inputs.isEmpty
            || cycle.outputs.contains(where: { StorageKind.of($0.key) != nil })
        return hauls ? max(1, crew - 1) : crew
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
