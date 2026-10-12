//
//  ProductionConfig.swift
//  Feudalism
//
//  Čita production.json: trajanje, ulaz i izlaz svakog radnog mjesta (npr. koliko traje konj u štali)
//  i kapacitete skladišta. Što u datoteci nema, uzima se iz ugrađenih vrijednosti (WorkCycleCatalog).
//

import Foundation

enum ProductionConfig {
    private static let fileName = "production"
    private static let subdirs = ["Config", "Core/Config", "Feudalism/Core/Config"]

    private struct FileShape: Decodable {
        var gradevine: [String: Entry]?
        var skladista: [String: Int]?

        struct Entry: Decodable {
            var vrsta: String?
            var potezi: Int?
            var ulaz: [String: Int]?
            var izlaz: [String: Int]?
        }
    }

    private static let file: FileShape? = {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(FileShape.self, from: data)
    }()

    /// Ciklusi iz datoteke; građevina se preskače ako joj fali vrsta/potezi ili ima nepoznatu robu.
    static let cycles: [String: WorkCycle] = {
        var result: [String: WorkCycle] = [:]
        for (objectId, entry) in file?.gradevine ?? [:] {
            guard let kind = entry.vrsta.flatMap(WorkKind.init(rawValue:)),
                  let ticks = entry.potezi, ticks > 0,
                  let inputs = goods(entry.ulaz ?? [:]),
                  let outputs = goods(entry.izlaz ?? [:]) else { continue }
            result[objectId] = WorkCycle(kind: kind, durationTicks: ticks, inputs: inputs, outputs: outputs)
        }
        return result
    }()

    static func storageCapacity(_ kind: StorageKind) -> Int? {
        file?.skladista?[kind.rawValue].map { max(0, $0) }
    }

    private static func goods(_ raw: [String: Int]) -> [Good: Int]? {
        var result: [Good: Int] = [:]
        for (key, amount) in raw {
            guard let good = Good(rawValue: key) else { return nil }
            result[good] = max(0, amount)
        }
        return result
    }

    private static func loadData() -> Data? {
        let bundle = Bundle.main
        for sub in subdirs {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        if let url = bundle.url(forResource: fileName, withExtension: "json"), let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}
