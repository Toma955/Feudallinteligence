//
//  AIMatchPrediction.swift
//  Feudalism
//
//  Predviđanje: lord vidi SAMO onoliko sekundi snimke koliko mu daš.
//  Iz tog odsječka pogađa što slijedi (sljedeći potez + ishod).
//  Ostatak partije mu nije u ulazu — samo kao meta za učenje.
//

import Foundation

struct AIPredictionTrial: Identifiable, Equatable {
    var id: String
    var matchId: String
    var matchTitle: String
    /// Do koje sekunde je lord smio gledati.
    var visibleThroughSecond: Int
    var second: Int
    var predictedActionId: String
    var actualActionId: String
    var actionHit: Bool
    var predictedValue: Float
    /// 1 = pobjeda, 0 = poraz; nil ako ishod nije poznat. (meta, nije u vidu)
    var outcomeTarget: Float?
    var valueError: Float?
    var note: String
}

struct AIPredictionReport: Equatable {
    var trials: [AIPredictionTrial]
    var actionHits: Int
    var actionTotal: Int
    var meanValueError: Float?
    /// Koliko sekundi vida je korišteno.
    var sightSeconds: Int

    var actionAccuracy: Double {
        guard actionTotal > 0 else { return 0 }
        return Double(actionHits) / Double(actionTotal)
    }
}

/// Jedan uzorak predviđanja: stanje samo iz vida → stvarni potez koji lord nije vidio.
struct AIPredictionSample: Equatable {
    var state: [Float]
    var actionIndex: Int
    var actionId: String
    /// Sekunda reza (do tu vidi).
    var cutSecond: Int
    /// Sekunda stvarnog poteza koji predviđa.
    var targetSecond: Int
}

enum AIMatchPrediction {
    /// Uzorci: za svaki rez t ≤ sightSeconds lord vidi samo okvire do t,
    /// a meta je prvi potez POSLIJE t (što još nije vidio).
    static func samples(
        from record: MatchHistoryRecord,
        vocabulary: AILordVocabulary,
        sightSeconds: Int
    ) -> [AIPredictionSample] {
        let sight = max(0, sightSeconds)
        let decisions = (record.decisions ?? []).sorted { $0.second < $1.second }
        guard !record.frames.isEmpty else { return [] }

        var cuts: [Int] = []
        // Rezovi na trenutcima odluka unutar vida + sam kraj vida.
        for d in decisions where d.second <= sight {
            cuts.append(d.second)
        }
        cuts.append(sight)
        cuts = Array(Set(cuts)).sorted()

        var out: [AIPredictionSample] = []
        for cut in cuts {
            guard let frame = frameAtOrBefore(second: cut, in: record) else { continue }
            guard let next = decisions.first(where: { $0.second > cut }),
                  let actionId = AIMatchPolicyTraining.resolvedActionId(next),
                  let actionIndex = vocabulary.actions.firstIndex(of: actionId) else {
                continue
            }
            let state = AILordStateEncoder.encode(
                frame: frame,
                rows: record.mapRows,
                cols: record.mapCols
            )
            out.append(AIPredictionSample(
                state: state,
                actionIndex: actionIndex,
                actionId: actionId,
                cutSecond: cut,
                targetSecond: next.second
            ))
        }
        return out
    }

    /// Prođi snimke uz ograničen vid.
    static func evaluate(
        weights: AILordWeights,
        records: [MatchHistoryRecord],
        vocabulary: AILordVocabulary,
        sightSeconds: Int
    ) -> AIPredictionReport {
        var trials: [AIPredictionTrial] = []
        for record in records {
            let outcome = outcomeTarget(record)
            let samples = samples(from: record, vocabulary: vocabulary, sightSeconds: sightSeconds)
            for sample in samples {
                let pass = weights.forward(stateFeatures: sample.state)
                let predIdx = pass.logits.indices.max(by: { pass.logits[$0] < pass.logits[$1] }) ?? 0
                let predId = vocabulary.actions.indices.contains(predIdx)
                    ? vocabulary.actions[predIdx]
                    : "?"
                let hit = predIdx == sample.actionIndex
                let valueErr = outcome.map { abs(pass.value - $0) }
                let note: String
                if hit {
                    note = "Uz vid do \(sample.cutSecond)s pogodio potez u \(sample.targetSecond)s."
                } else {
                    note = "Vid do \(sample.cutSecond)s: očekivao \(shortName(predId)), bilo \(shortName(sample.actionId)) (@\(sample.targetSecond)s)."
                }
                trials.append(AIPredictionTrial(
                    id: "\(record.id)-\(sample.cutSecond)-\(sample.targetSecond)-\(sample.actionId)",
                    matchId: record.id,
                    matchTitle: record.title,
                    visibleThroughSecond: sample.cutSecond,
                    second: sample.targetSecond,
                    predictedActionId: predId,
                    actualActionId: sample.actionId,
                    actionHit: hit,
                    predictedValue: pass.value,
                    outcomeTarget: outcome,
                    valueError: valueErr,
                    note: note
                ))
            }
        }
        let hits = trials.filter(\.actionHit).count
        let errs = trials.compactMap(\.valueError)
        let meanErr: Float? = errs.isEmpty ? nil : errs.reduce(0, +) / Float(errs.count)
        return AIPredictionReport(
            trials: trials.sorted { $0.visibleThroughSecond < $1.visibleThroughSecond },
            actionHits: hits,
            actionTotal: trials.count,
            meanValueError: meanErr,
            sightSeconds: sightSeconds
        )
    }

    /// Jedan epoch uz ograničen vid. Ishod je samo meta (nije u stanju).
    static func trainStep(
        weights: inout AILordWeights,
        records: [MatchHistoryRecord],
        vocabulary: AILordVocabulary,
        sightSeconds: Int,
        learningRate: Float = 0.04
    ) -> Float {
        var lossSum: Float = 0
        var n = 0
        for record in records {
            let outcome = outcomeTarget(record)
            for sample in samples(from: record, vocabulary: vocabulary, sightSeconds: sightSeconds) {
                let pred = weights.bestActionIndex(stateFeatures: sample.state)
                let rate = pred == sample.actionIndex ? learningRate * 0.35 : learningRate
                lossSum += weights.imitate(
                    stateFeatures: sample.state,
                    actionIndex: sample.actionIndex,
                    learningRate: rate
                )
                if let target = outcome {
                    lossSum += weights.fitValue(
                        stateFeatures: sample.state,
                        target: target,
                        learningRate: learningRate * 0.5
                    )
                }
                n += 1
            }
        }
        return n > 0 ? lossSum / Float(n) : 0
    }

    /// Okvir na ili PRIJE sekunde — nikad budućnost.
    static func frameAtOrBefore(second: Int, in record: MatchHistoryRecord) -> MatchHistoryFrame? {
        let turn = second + 1
        return record.frames
            .filter { $0.turn <= turn }
            .max(by: { $0.turn < $1.turn })
    }

    static func outcomeTarget(_ record: MatchHistoryRecord) -> Float? {
        guard let result = record.result?.lowercased() else { return nil }
        if result.contains("pobj") || result.contains("win") || result.contains("victory") { return 1 }
        if result.contains("poraz") || result.contains("loss") || result.contains("defeat") { return 0 }
        return nil
    }

    /// Najduža snimka među označenima (za klizač).
    static func maxSeconds(in records: [MatchHistoryRecord]) -> Int {
        let fromFrames = records.compactMap { $0.frames.last.map { max(0, $0.turn - 1) } }.max() ?? 0
        let fromDecisions = records.compactMap { ($0.decisions ?? []).map(\.second).max() }.max() ?? 0
        return max(fromFrames, fromDecisions, 10)
    }

    private static func shortName(_ actionId: String) -> String {
        if actionId.hasPrefix("action:build:") {
            return String(actionId.dropFirst("action:build:".count))
        }
        if actionId.hasPrefix("action:") {
            return String(actionId.dropFirst("action:".count))
        }
        return actionId
    }
}
