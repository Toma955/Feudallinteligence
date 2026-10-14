//
//  TreeYieldNotebook.swift
//  Feudalism
//
//  Bilježnica: koliko dasaka i koliko traje sječa/piljenje po vrsti stabla.
//  Čita tree_yields.json. Ako datoteke nema, svako stablo daje 10 dasaka.
//

import Foundation

enum TreeYieldNotebook {
    private static let fileName = "tree_yields"
    private static let subdirs = ["Config", "Core/Config", "Feudalism/Core/Config"]

    private struct Entry: Decodable {
        var cut: Int?
        var saw: Int?
        var planks: Int?
        var bananas: Int?
    }

    private struct FileShape: Decodable {
        var zadano: Entry?
        var stabla: [String: Entry]?
    }

    private static let file: FileShape? = {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(FileShape.self, from: data)
    }()

    static func yield(for objectId: String) -> HarvestTrees.Yield {
        let entry = file?.stabla?[objectId] ?? file?.zadano
        let bananas = max(0, entry?.bananas ?? (HarvestTrees.isPalm(objectId) ? 4 : 0))
        let planksDefault = HarvestTrees.isPalm(objectId) ? 0 : 10
        return HarvestTrees.Yield(
            cutTicks: max(1, entry?.cut ?? 8),
            sawTicks: max(0, entry?.saw ?? (HarvestTrees.isPalm(objectId) ? 1 : 6)),
            planks: max(0, entry?.planks ?? planksDefault),
            bananas: bananas
        )
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
