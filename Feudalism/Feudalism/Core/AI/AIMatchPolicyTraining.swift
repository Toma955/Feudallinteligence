//
//  AIMatchPolicyTraining.swift
//  Feudalism
//
//  Iz snimljene partije gradi uzorke (stanje → akcija) i trenira politiku lordova.
//

import Foundation

struct AIPolicySample: Equatable {
    var state: [Float]
    var actionIndex: Int
    var actionId: String
    var second: Int
}

enum AIMatchPolicyTraining {
    /// Uzorci iz jedne snimke: odluke s actionId (ili izvedene iz teksta) + okvir mape.
    static func samples(from record: MatchHistoryRecord, vocabulary: AILordVocabulary) -> [AIPolicySample] {
        let decisions = record.decisions ?? []
        guard !decisions.isEmpty, !record.frames.isEmpty else {
            return samplesFromFramesOnly(record: record, vocabulary: vocabulary)
        }
        var out: [AIPolicySample] = []
        for decision in decisions {
            guard let actionId = resolvedActionId(decision),
                  let actionIndex = vocabulary.actions.firstIndex(of: actionId) else { continue }
            let frame = frame(nearSecond: decision.second, in: record) ?? record.frames.last!
            let state = AILordStateEncoder.encode(
                frame: frame,
                rows: record.mapRows,
                cols: record.mapCols
            )
            out.append(AIPolicySample(
                state: state,
                actionIndex: actionIndex,
                actionId: actionId,
                second: decision.second
            ))
        }
        if out.isEmpty {
            return samplesFromFramesOnly(record: record, vocabulary: vocabulary)
        }
        return out
    }

    /// Kad nema odluka: iz građevina na zadnjem okviru pretpostavi build akcije koje fale.
    private static func samplesFromFramesOnly(
        record: MatchHistoryRecord,
        vocabulary: AILordVocabulary
    ) -> [AIPolicySample] {
        guard let last = record.frames.last else { return [] }
        let state = AILordStateEncoder.encode(frame: last, rows: record.mapRows, cols: record.mapCols)
        var ids: [String] = []
        let b = last.buildings
        if !b.contains("H") { ids.append("action:build:\(House.objectId)") }
        if !b.contains("A") { ids.append("action:build:\(Farm.objectId)") }
        if !b.contains("K") { ids.append("action:build:\(Smocnica.objectId)") }
        if !b.contains("L") { ids.append("action:build:\(Lager.objectId)") }
        if !b.contains("T") { ids.append("action:build:\(Training.objectId)") }
        if ids.isEmpty { ids.append("action:wait") }
        return ids.compactMap { id in
            guard let idx = vocabulary.actions.firstIndex(of: id) else { return nil }
            return AIPolicySample(state: state, actionIndex: idx, actionId: id, second: max(0, last.turn - 1))
        }
    }

    private static func frame(nearSecond second: Int, in record: MatchHistoryRecord) -> MatchHistoryFrame? {
        let turn = second + 1
        return record.frames.min(by: { abs($0.turn - turn) < abs($1.turn - turn) })
    }

    static func resolvedActionId(_ decision: MatchDecision) -> String? {
        if let id = decision.actionId, !id.isEmpty { return id }
        return inferActionId(from: decision.action)
    }

    /// Starije snimke: iz teksta "izgradio Kuća" / AI misli.
    static func inferActionId(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("ček") || lower.contains("ne gradi") { return "action:wait" }
        let pairs: [(String, String)] = [
            ("kuć", House.objectId), ("kuca", House.objectId), ("house", House.objectId),
            ("farm", Farm.objectId), ("polj", Farm.objectId),
            ("smoč", Smocnica.objectId), ("smoc", Smocnica.objectId),
            ("skladišt", Lager.objectId), ("lager", Lager.objectId),
            ("trening", Training.objectId), ("training", Training.objectId),
            ("tržnic", Market.objectId), ("trzn", Market.objectId), ("market", Market.objectId),
            ("sruš", "action:demolish"),
            ("poslao", "action:send_army"),
            ("označ", "action:mark_army")
        ]
        for (needle, objectOrAction) in pairs {
            guard lower.contains(needle) else { continue }
            if objectOrAction.hasPrefix("action:") { return objectOrAction }
            return "action:build:\(objectOrAction)"
        }
        if lower.contains("izgradio") || lower.contains("sagradio") || lower.contains("gradi") {
            return nil
        }
        return nil
    }
}
