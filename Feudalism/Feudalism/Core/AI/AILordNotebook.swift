//
//  AILordNotebook.swift
//  Feudalism
//
//  Zajednička bilježnica i leveli AI lordova.
//  Bilježnica sadrži opća pravila igre (AILordRulebook); stranice za učenje su još prazne,
//  svaki level je 0.0.
//

import Foundation

/// Jedna bilježnica. Svi zadani lordovi pokazuju na `sharedId`.
/// Stranice i dimenzije dolaze kasnije — za sada je popis prazan.
struct AILordNotebook: Codable, Equatable, Identifiable {
    static let sharedId = "notebook.shared"

    let id: String
    var pages: [AILordNotebookPage]

    var isEmpty: Bool { pages.isEmpty }

    /// Opća pravila igre; ne spremaju se nego se uvijek slažu iz kataloga.
    var rules: AILordRulebook { .current }

    /// Rječnik tokena (pojmovi i potezi), zajednički za sve lordove.
    var vocabulary: AILordVocabulary { .current }

    static var emptyShared: AILordNotebook {
        AILordNotebook(id: sharedId, pages: [])
    }
}

/// Jedna stranica bilježnice: što je lord primijetio u partiji i što je kod sebe popravio.
struct AILordNotebookPage: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var note: String
    var matchId: String

    init(id: String = UUID().uuidString, title: String, note: String, matchId: String) {
        self.id = id
        self.title = title
        self.note = note
        self.matchId = matchId
    }

    private enum CodingKeys: String, CodingKey { case id, title, note, matchId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        matchId = try c.decodeIfPresent(String.self, forKey: .matchId) ?? ""
    }
}

/// Jedan level. `value` je ocjena za prikaz; matrice parametara su u AILordWeights (datoteka po levelu).
/// Lordovi ga dijele tako da imaju isti `id`.
struct AILordLevel: Codable, Equatable, Identifiable {
    let id: String
    var value: Double

    static func empty(id: String) -> AILordLevel {
        AILordLevel(id: id, value: 0.0)
    }
}

/// Osnovna postava: 16 lordova, jedna prazna bilježnica, 16 praznih levela.
enum AILordRoster {
    static let count = 16

    struct Seed {
        let id: String
        let levelId: String
        let name: String
        let description: String
        let iconName: String
        let colorHex: String
        let fightingStyle: AIFightingStyle
        let strategyFocus: AIStrategyFocus
    }

    static let seeds: [Seed] = [
        Seed(id: "lord.vuk", levelId: "level.vuk", name: "Vuk", description: "Brzi napadi, malo obrane.", iconName: "flame.fill", colorHex: "E74C3C", fightingStyle: .aggressive, strategyFocus: .conquest),
        Seed(id: "lord.kamen", levelId: "level.kamen", name: "Kamen", description: "Utvrde i strpljenje.", iconName: "shield.fill", colorHex: "7F8C8D", fightingStyle: .defensive, strategyFocus: .survival),
        Seed(id: "lord.trgovac", levelId: "level.trgovac", name: "Trgovac", description: "Zlato i gradnja.", iconName: "dollarsign.circle.fill", colorHex: "F1C40F", fightingStyle: .economic, strategyFocus: .trade),
        Seed(id: "lord.ravnoteza", levelId: "level.ravnoteza", name: "Ravnoteža", description: "Sve po malo.", iconName: "scale.3d", colorHex: "3498DB", fightingStyle: .balanced, strategyFocus: .expansion),
        Seed(id: "lord.pljackas", levelId: "level.pljackas", name: "Pljačkaš", description: "Napad, uzmi, bježi.", iconName: "theatermasks.fill", colorHex: "D35400", fightingStyle: .raider, strategyFocus: .military),
        Seed(id: "lord.pleme", levelId: "level.pleme", name: "Pleme", description: "Savezi i pregovori.", iconName: "person.3.fill", colorHex: "27AE60", fightingStyle: .diplomat, strategyFocus: .trade),
        Seed(id: "lord.grom", levelId: "level.grom", name: "Grom", description: "Šok i strah.", iconName: "bolt.fill", colorHex: "F39C12", fightingStyle: .aggressive, strategyFocus: .military),
        Seed(id: "lord.pcela", levelId: "level.pcela", name: "Pčela", description: "Rad i blagostanje.", iconName: "ant.fill", colorHex: "B7950B", fightingStyle: .economic, strategyFocus: .expansion),
        Seed(id: "lord.sjenka", levelId: "level.sjenka", name: "Sjenka", description: "Iznenađenje i povlačenje.", iconName: "moon.fill", colorHex: "8E44AD", fightingStyle: .raider, strategyFocus: .survival),
        Seed(id: "lord.most", levelId: "level.most", name: "Most", description: "Savezi prije svega.", iconName: "link", colorHex: "1ABC9C", fightingStyle: .diplomat, strategyFocus: .trade),
        Seed(id: "lord.sokol", levelId: "level.sokol", name: "Sokol", description: "Visoko i brzo.", iconName: "bird.fill", colorHex: "5DADE2", fightingStyle: .aggressive, strategyFocus: .conquest),
        Seed(id: "lord.kula", levelId: "level.kula", name: "Kula", description: "Stoji i čeka.", iconName: "building.columns.fill", colorHex: "1A5276", fightingStyle: .defensive, strategyFocus: .survival),
        Seed(id: "lord.kovac", levelId: "level.kovac", name: "Kovač", description: "Željezo i oružje.", iconName: "hammer.fill", colorHex: "922B21", fightingStyle: .economic, strategyFocus: .military),
        Seed(id: "lord.lisica", levelId: "level.lisica", name: "Lisica", description: "Varka i kratki udar.", iconName: "hare.fill", colorHex: "E67E22", fightingStyle: .raider, strategyFocus: .military),
        Seed(id: "lord.opat", levelId: "level.opat", name: "Opat", description: "Mir i utjecaj.", iconName: "cross.fill", colorHex: "6C3483", fightingStyle: .diplomat, strategyFocus: .trade),
        Seed(id: "lord.medvjed", levelId: "level.medvjed", name: "Medvjed", description: "Snaga i zima.", iconName: "pawprint.fill", colorHex: "6E2C00", fightingStyle: .balanced, strategyFocus: .survival)
    ]

    static func makeNotebook() -> AILordNotebook {
        .emptyShared
    }

    static func makeLevels() -> [AILordLevel] {
        seeds.map { AILordLevel.empty(id: $0.levelId) }
    }

    static func makeProfiles() -> [AILordProfile] {
        seeds.map { seed in
            AILordProfile(
                id: seed.id,
                name: seed.name,
                description: seed.description,
                iconName: seed.iconName,
                colorHex: seed.colorHex,
                fightingStyle: seed.fightingStyle,
                strategyFocus: seed.strategyFocus,
                experienceLevel: 0,
                notebookId: AILordNotebook.sharedId,
                levelId: seed.levelId
            )
        }
    }
}
