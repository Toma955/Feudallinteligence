//
//  AIMatchDecisionAnalysis.swift
//  Feudalism
//
//  Analiza odluka: je li potez bio dobar ili loš (za lorda koji uči).
//  To nije trening — samo ocjena. Trening kasnije koristi ocjene.
//

import Foundation

struct JudgedDecision: Identifiable, Equatable {
    var id: String
    var matchId: String
    var matchTitle: String
    var decision: MatchDecision
    var quality: DecisionQuality
    /// Zašto je ocijenjeno tako.
    var reason: String
    var actionId: String?
}

enum AIMatchDecisionAnalysis {
    /// Prođi sve odluke u snimkama i označi dobre / loše / neutralne.
    static func judge(records: [MatchHistoryRecord]) -> [JudgedDecision] {
        var out: [JudgedDecision] = []
        for record in records {
            out.append(contentsOf: judge(record: record))
        }
        return out.sorted { $0.decision.second < $1.decision.second }
    }

    static func judge(record: MatchHistoryRecord) -> [JudgedDecision] {
        let decisions = record.decisions ?? []
        guard !decisions.isEmpty else { return [] }
        let won = recordLooksWon(record)
        let last = record.frames.last
        let gaps = missingBuildingGaps(in: last?.buildings ?? "")

        return decisions.map { d in
            let actionId = AIMatchPolicyTraining.resolvedActionId(d)
            let (quality, reason) = score(
                decision: d,
                actionId: actionId,
                record: record,
                won: won,
                gaps: gaps
            )
            return JudgedDecision(
                id: d.id,
                matchId: record.id,
                matchTitle: record.title,
                decision: d,
                quality: quality,
                reason: reason,
                actionId: actionId
            )
        }
    }

    /// Spremi ocjene natrag u snimku (quality na svakoj odluci).
    static func persistJudgments(_ judgments: [JudgedDecision], into store: MatchHistoryStore) {
        let byMatch = Dictionary(grouping: judgments, by: \.matchId)
        for (matchId, list) in byMatch {
            guard var record = store.record(id: matchId) else { continue }
            var decisions = record.decisions ?? []
            let map = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0.quality) })
            for i in decisions.indices {
                if let q = map[decisions[i].id] {
                    decisions[i].quality = q
                }
            }
            record.decisions = decisions
            store.updateRecord(record)
        }
    }

    private static func score(
        decision: MatchDecision,
        actionId: String?,
        record: MatchHistoryRecord,
        won: Bool?,
        gaps: Set<String>
    ) -> (DecisionQuality, String) {
        let text = decision.action.lowercased()
        let id = actionId ?? ""

        // Ručna / već spremljena ocjena ima prednost ako postoji.
        if let existing = decision.quality {
            return (existing, "Već ocijenjeno u snimci.")
        }

        // Poraz + agresivna gradnja kasno bez hrane/kuća → loše.
        if won == false, decision.second > 40, gaps.contains("house") || gaps.contains("food") {
            if id.hasPrefix("action:build:") || text.contains("izgradio") {
                return (.bad, "Poraz: kasna gradnja dok još fali krov ili hrana.")
            }
        }

        // Pobjeda + bilo koji produktivni potez → dobro.
        if won == true, id.hasPrefix("action:build:") || text.contains("izgradio") {
            return (.good, "Pobjeda: gradnja je doprinijela uspjehu.")
        }

        // Popunjava jasnu rupu (nema kuće pa gradi kuću) → dobro.
        if id.contains("house"), gaps.contains("house") {
            return (.good, "Popunio je manjak kuća.")
        }
        if (id.contains("farm") || id.contains("smocnica") || id.contains("food")),
           gaps.contains("food") || gaps.contains("farm") {
            return (.good, "Popunio je lanac hrane.")
        }
        if id.contains("lager"), gaps.contains("store") {
            return (.good, "Dodao skladište kad ga nije bilo.")
        }
        if id.contains("training") || id == "action:send_army", gaps.contains("army") {
            return (.good, "Pojačao vojsku kad je bila tanka.")
        }

        // Čekanje dok fali osnovno → loše.
        if id == "action:wait" || text.contains("čeka") {
            if !gaps.isEmpty {
                return (.bad, "Čekao dok još fali: \(gaps.sorted().joined(separator: ", ")).")
            }
            return (.neutral, "Čekanje bez jasne štete.")
        }

        // Rušenje vlastitog → loše (osim ako eksplicitno nema konteksta).
        if id == "action:demolish" || text.contains("srušio") {
            return (.bad, "Rušenje građevine rijetko pomaže naučenom stylu.")
        }

        // Sreća / populacija nakon poteza.
        if let happy = decision.happiness, happy < 30 {
            return (.bad, "Sreća pala ispod 30 % u trenutku poteza.")
        }
        if let pop = decision.population, let happy = decision.happiness, pop > 0, happy >= 60 {
            return (.good, "Stabilna populacija i sreća uz potez.")
        }

        if won == false {
            return (.neutral, "Poraz partije — potez nije jasno štetan ni koristan.")
        }
        if won == true {
            return (.neutral, "Pobjeda — potez bez jake veze s ishodom.")
        }
        return (.neutral, "Nema dovoljno signala za jaku ocjenu.")
    }

    private static func recordLooksWon(_ record: MatchHistoryRecord) -> Bool? {
        guard let result = record.result?.lowercased() else { return nil }
        if result.contains("pobj") || result.contains("win") || result.contains("victory") { return true }
        if result.contains("poraz") || result.contains("loss") || result.contains("defeat") { return false }
        return nil
    }

    private static func missingBuildingGaps(in buildings: String) -> Set<String> {
        var gaps = Set<String>()
        if !buildings.contains("H") { gaps.insert("house") }
        if !buildings.contains("A") { gaps.insert("farm") }
        if !buildings.contains("K") { gaps.insert("food") }
        if !buildings.contains("L") { gaps.insert("store") }
        // Vojska: ako nema treninga (T) ni tipova u army — army gap se puni drugdje.
        if !buildings.contains("T") && !buildings.contains("W") { gaps.insert("army") }
        return gaps
    }
}
