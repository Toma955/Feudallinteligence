//
//  AILordVocabulary.swift
//  Feudalism
//
//  Rječnik bilježnice (kao rječnik tokena kod LLM-a): svaki pojam igre i svaki potez ima svoj broj.
//  Zajednički je za sve lordove i slaže se iz pravila (AILordRulebook), pa prati nove građevine i robu.
//  Redak `i` u matrici pojmova levela pripada tokenu `tokens[i]`; stupac `j` politike potezu `actions[j]`.
//

import Foundation

struct AILordVocabulary: Codable, Equatable {
    /// Svi pojmovi: građevine, roba, vojnici, skladišta, uloge, godišnja doba i potezi.
    let tokens: [String]
    /// Potezi koje lord može odigrati (izlaz politike).
    let actions: [String]

    static let current = build(from: .current)

    func index(of token: String) -> Int? {
        tokens.firstIndex(of: token)
    }

    static func build(from rules: AILordRulebook) -> AILordVocabulary {
        let actions = rules.actions.map(\.id)

        var tokens: [String] = []
        tokens += rules.buildings.map { "building:\($0.objectId)" }
        tokens += rules.goods.map { "good:\($0.id)" }
        tokens += rules.army.soldiers.map { "soldier:\($0.id)" }
        tokens += SpecialistType.allCases.map { "specialist:\($0.id)" }
        tokens += rules.storage.map { "storage:\($0.id)" }
        tokens += PersonRole.allCases.map { "role:\($0.rawValue)" }
        tokens += rules.seasons.order.map { "season:\($0)" }
        tokens += rules.campaigns.map { "campaign:\($0.id)" }
        tokens += FactionRelation.allCases.map { "relation:\($0.rawValue)" }
        tokens += actions
        return AILordVocabulary(tokens: tokens, actions: actions)
    }
}
