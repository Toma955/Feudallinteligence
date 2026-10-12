//
//  AILordWeights.swift
//  Feudalism
//
//  Parametri levela jednog AI lorda: matrice slučajnih brojeva (kao težine malog LLM-a).
//  - embedding: redak po tokenu rječnika × embeddingDim
//  - state_in → hidden → policy (potezi) i value (procjena pobjede), svaki sa svojim biasom
//  - traits: imenovane osobine 0…1
//  Za sada je sve po lordu; kasnije se pojedini blok može označiti zajedničkim i prebaciti u bilježnicu.
//  Brojevi su deterministički iz id-a levela, pa isti lord uvijek krene s istim brojevima.
//

import Foundation

struct AILordParameterBlock: Codable, Equatable {
    let name: String
    let rows: Int
    let cols: Int
    /// Zasad uvijek false; true = blok se dijeli preko bilježnice.
    var shared: Bool
    /// rows × cols Float32, redak po redak.
    var values: [Float]

    func value(row: Int, col: Int) -> Float { values[row * cols + col] }

    private enum CodingKeys: String, CodingKey { case name, rows, cols, shared, data }

    init(name: String, rows: Int, cols: Int, shared: Bool = false, values: [Float]) {
        self.name = name
        self.rows = rows
        self.cols = cols
        self.shared = shared
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        rows = try c.decode(Int.self, forKey: .rows)
        cols = try c.decode(Int.self, forKey: .cols)
        shared = try c.decodeIfPresent(Bool.self, forKey: .shared) ?? false
        let data = try c.decode(Data.self, forKey: .data)
        var floats = [Float](repeating: 0, count: data.count / MemoryLayout<Float>.size)
        _ = floats.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        values = floats
        guard values.count == rows * cols else {
            throw DecodingError.dataCorruptedError(forKey: .data, in: c, debugDescription: "Veličina bloka \(name) ne odgovara.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(rows, forKey: .rows)
        try c.encode(cols, forKey: .cols)
        try c.encode(shared, forKey: .shared)
        try c.encode(values.withUnsafeBufferPointer { Data(buffer: $0) }, forKey: .data)
    }
}

struct AILordWeights: Codable, Equatable {
    static let embeddingDim = 32
    /// Broj ulaznih značajki stanja partije (što lord "vidi"); značajke se definiraju kasnije.
    static let stateFeatures = 64
    static let hiddenSize = 128
    static let traitNames = [
        "aggression", "defense", "economy", "expansion", "risk", "patience", "greed", "tax_tolerance",
        "food_reserve", "army_size", "cavalry", "archers", "infantry", "diplomacy", "trade", "build_speed"
    ]

    let levelId: String
    let seed: UInt64
    /// Rječnik i potezi iz kojih je level složen; ako se promijene, level se slaže iznova.
    let vocabularySize: Int
    let actionCount: Int
    var blocks: [AILordParameterBlock]

    var parameterCount: Int { blocks.reduce(0) { $0 + $1.values.count } }

    func block(_ name: String) -> AILordParameterBlock? {
        blocks.first { $0.name == name }
    }

    /// Pomakne jednu osobinu (0…1). Lord time upisuje što je naučio iz partije.
    mutating func nudgeTrait(_ name: String, by delta: Float) {
        guard let index = Self.traitNames.firstIndex(of: name),
              let blockIndex = blocks.firstIndex(where: { $0.name == "traits" }),
              blocks[blockIndex].values.indices.contains(index) else { return }
        let next = blocks[blockIndex].values[index] + delta
        blocks[blockIndex].values[index] = min(1, max(0, next))
    }

    func traitValue(_ name: String) -> Float {
        guard let index = Self.traitNames.firstIndex(of: name),
              let block = block("traits"),
              block.values.indices.contains(index) else { return 0 }
        return block.values[index]
    }

    func fits(_ vocabulary: AILordVocabulary) -> Bool {
        vocabularySize == vocabulary.tokens.count && actionCount == vocabulary.actions.count
            && block("traits")?.cols == Self.traitNames.count
    }

    static func random(levelId: String, vocabulary: AILordVocabulary) -> AILordWeights {
        let seed = stableSeed(levelId)
        var rng = SplitMix64(seed: seed)
        let v = vocabulary.tokens.count
        let a = vocabulary.actions.count
        let e = embeddingDim, f = stateFeatures, h = hiddenSize

        func matrix(_ name: String, _ rows: Int, _ cols: Int) -> AILordParameterBlock {
            let limit = Float((6.0 / Double(rows + cols)).squareRoot())
            return AILordParameterBlock(name: name, rows: rows, cols: cols, values: (0..<rows * cols).map { _ in rng.uniform(-limit, limit) })
        }
        func bias(_ name: String, _ cols: Int) -> AILordParameterBlock {
            AILordParameterBlock(name: name, rows: 1, cols: cols, values: (0..<cols).map { _ in rng.uniform(-0.01, 0.01) })
        }

        let blocks = [
            matrix("embedding", v, e),
            matrix("state_in", f + e, h), bias("state_in.bias", h),
            matrix("hidden", h, h), bias("hidden.bias", h),
            matrix("policy", h, a), bias("policy.bias", a),
            matrix("value", h, 1), bias("value.bias", 1),
            AILordParameterBlock(name: "traits", rows: 1, cols: traitNames.count, values: traitNames.map { _ in rng.uniform(0, 1) })
        ]
        return AILordWeights(levelId: levelId, seed: seed, vocabularySize: v, actionCount: a, blocks: blocks)
    }

    /// FNV-1a: isti id daje isti broj na svakom pokretanju (Hasher se mijenja).
    private static func stableSeed(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func uniform(_ low: Float, _ high: Float) -> Float {
        let unit = Float(next() >> 40) / Float(1 << 24)
        return low + (high - low) * unit
    }
}

/// Jedna datoteka po levelu: Application Support/Feudalism/AILevels/<levelId>.json.
enum AILordWeightsStore {
    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Feudalism/AILevels", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load(levelId: String) -> AILordWeights? {
        guard let url = directory?.appendingPathComponent("\(levelId).json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AILordWeights.self, from: data)
    }

    static func save(_ weights: AILordWeights) {
        guard let url = directory?.appendingPathComponent("\(weights.levelId).json"),
              let data = try? JSONEncoder().encode(weights) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Učitaj level; ako ga nema ili rječnik više ne odgovara, složi nove slučajne brojeve.
    static func loadOrCreate(levelId: String, vocabulary: AILordVocabulary) -> AILordWeights {
        if let saved = load(levelId: levelId), saved.fits(vocabulary) { return saved }
        let fresh = AILordWeights.random(levelId: levelId, vocabulary: vocabulary)
        save(fresh)
        return fresh
    }
}
