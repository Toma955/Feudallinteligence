//
//  AILordProfile.swift
//  Feudalism
//
//  Profil AI lorda – svaki bot drugačiji: način borbe, taktika, strategija.
//  Profili tijekom vremena uče i postaju sve bolji (iskustvo, level, pobede).
//

import Foundation

/// Način borbe / fokus taktike – svaki profil može imati drugačiji stil.
enum AIFightingStyle: String, Codable, CaseIterable, Identifiable {
    case aggressive = "Agresivan"
    case defensive = "Defenzivan"
    case economic = "Ekonomski"
    case balanced = "Uravnotežen"
    case raider = "Pljačkaš"
    case diplomat = "Diplomata"

    var id: String { rawValue }

    /// Ključ u Locales/{jezik}.json. Sirova vrijednost ostaje hrvatski naziv zbog spremljenih profila.
    var localizationKey: String {
        switch self {
        case .aggressive: return "ai_style_aggressive"
        case .defensive: return "ai_style_defensive"
        case .economic: return "ai_style_economic"
        case .balanced: return "ai_style_balanced"
        case .raider: return "ai_style_raider"
        case .diplomat: return "ai_style_diplomat"
        }
    }
}

/// Strategija na razini kraljevstva – dugoročni prioritet.
enum AIStrategyFocus: String, Codable, CaseIterable, Identifiable {
    case conquest = "Osvajanje"
    case expansion = "Širenje"
    case trade = "Trgovina"
    case military = "Vojska"
    case survival = "Preživljavanje"

    var id: String { rawValue }

    /// Ključ u Locales/{jezik}.json. Sirova vrijednost ostaje hrvatski naziv zbog spremljenih profila.
    var localizationKey: String {
        switch self {
        case .conquest: return "ai_focus_conquest"
        case .expansion: return "ai_focus_expansion"
        case .trade: return "ai_focus_trade"
        case .military: return "ai_focus_military"
        case .survival: return "ai_focus_survival"
        }
    }
}

/// Jedan profil AI lorda – osobina bota (taktika, strategija) koji uči i postaje bolji.
struct AILordProfile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String

    /// SF Symbol ime za ikonu (npr. "flame.fill") – da se lordovi razlikuju.
    var iconName: String?
    /// Boja u hex (npr. "E74C3C") – za prikaz na karti i u listi.
    var colorHex: String?

    /// Način borbe / taktika – svaki bot drugačiji.
    var fightingStyle: AIFightingStyle
    /// Strategijski fokus.
    var strategyFocus: AIStrategyFocus

    // MARK: - Učenje – tokom vremena postaju sve bolji

    /// Razina iskustva (raste s igrama).
    var experienceLevel: Int
    /// Ukupno odigranih partija.
    var gamesPlayed: Int
    /// Pobjede – za feedback u model.
    var wins: Int
    /// Porazi – za učenje.
    var losses: Int
    /// Opcionalno: verzija/iteracija Core ML modela (nakon retrain-a).
    var modelVersion: Int

    /// Svi zadani lordovi dijele istu bilježnicu. Dimenzije bilježnice još nisu definirane.
    var notebookId: String
    /// Level je zaseban zapis. Za sada svaki lord ima svoj, svi na 0.0. Kasnije ih se može dijeliti.
    var levelId: String

    init(
        id: String? = nil,
        name: String,
        description: String = "",
        iconName: String? = nil,
        colorHex: String? = nil,
        fightingStyle: AIFightingStyle = .balanced,
        strategyFocus: AIStrategyFocus = .expansion,
        experienceLevel: Int = 1,
        gamesPlayed: Int = 0,
        wins: Int = 0,
        losses: Int = 0,
        modelVersion: Int = 1,
        notebookId: String = AILordNotebook.sharedId,
        levelId: String? = nil
    ) {
        let resolvedId = id ?? UUID().uuidString
        self.id = resolvedId
        self.name = name
        self.description = description
        self.iconName = iconName
        self.colorHex = colorHex
        self.fightingStyle = fightingStyle
        self.strategyFocus = strategyFocus
        self.experienceLevel = experienceLevel
        self.gamesPlayed = gamesPlayed
        self.wins = wins
        self.losses = losses
        self.modelVersion = modelVersion
        self.notebookId = notebookId
        self.levelId = levelId ?? "level.\(resolvedId)"
    }

    /// Ikona za UI (fallback ako nije postavljeno).
    var displayIconName: String { iconName ?? "person.fill" }
    /// Boja za UI (fallback).
    var displayColorHex: String { colorHex ?? "808080" }

    /// Omjer pobjeda (za težinu / odabir modela).
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed)
    }

    /// Ime za prikaz. Poznati zadani lordovi idu kroz Locales; ostali ostaju kako su spremljeni.
    func localizedName(language: AppLanguage) -> String {
        AILordCopy.localizedName(id: id, storedName: name, language: language)
    }

    /// Opis za prikaz. Isti princip kao `localizedName`.
    func localizedDescription(language: AppLanguage) -> String {
        AILordCopy.localizedDescription(id: id, storedDescription: description, language: language)
    }

    /// Zabilježi odigranu partiju – pobjeda ili poraz; povećava level/iskustvo.
    mutating func recordGame(won: Bool) {
        gamesPlayed += 1
        if won { wins += 1 } else { losses += 1 }
        if gamesPlayed % 5 == 0 {
            experienceLevel = min(experienceLevel + 1, 99)
        }
    }
}

/// Prikaz zadanih AI lordova na odabranom jeziku. Ključ je spremljeno hrvatsko ime.
enum AILordCopy {
    private static let nameKeysById: [String: String] = [
        "lord.vuk": "ai_lord_wolf_name",
        "lord.kamen": "ai_lord_stone_name",
        "lord.trgovac": "ai_lord_merchant_name",
        "lord.ravnoteza": "ai_lord_balance_name",
        "lord.pljackas": "ai_lord_raider_name",
        "lord.pleme": "ai_lord_tribe_name",
        "lord.grom": "ai_lord_thunder_name",
        "lord.pcela": "ai_lord_bee_name",
        "lord.sjenka": "ai_lord_shadow_name",
        "lord.most": "ai_lord_bridge_name",
        "lord.sokol": "ai_lord_falcon_name",
        "lord.kula": "ai_lord_tower_name",
        "lord.kovac": "ai_lord_smith_name",
        "lord.lisica": "ai_lord_fox_name",
        "lord.opat": "ai_lord_abbot_name",
        "lord.medvjed": "ai_lord_bear_name"
    ]

    private static let descriptionKeysById: [String: String] = [
        "lord.vuk": "ai_lord_wolf_desc",
        "lord.kamen": "ai_lord_stone_desc",
        "lord.trgovac": "ai_lord_merchant_desc",
        "lord.ravnoteza": "ai_lord_balance_desc",
        "lord.pljackas": "ai_lord_raider_desc",
        "lord.pleme": "ai_lord_tribe_desc",
        "lord.grom": "ai_lord_thunder_desc",
        "lord.pcela": "ai_lord_bee_desc",
        "lord.sjenka": "ai_lord_shadow_desc",
        "lord.most": "ai_lord_bridge_desc",
        "lord.sokol": "ai_lord_falcon_desc",
        "lord.kula": "ai_lord_tower_desc",
        "lord.kovac": "ai_lord_smith_desc",
        "lord.lisica": "ai_lord_fox_desc",
        "lord.opat": "ai_lord_abbot_desc",
        "lord.medvjed": "ai_lord_bear_desc"
    ]

    static func localizedName(id: String, storedName: String, language: AppLanguage) -> String {
        resolved(key: nameKeysById[id], fallback: storedName, language: language)
    }

    static func localizedDescription(id: String, storedDescription: String, language: AppLanguage) -> String {
        resolved(key: descriptionKeysById[id], fallback: storedDescription, language: language)
    }

    private static func resolved(key: String?, fallback: String, language: AppLanguage) -> String {
        guard let key else { return fallback }
        let value = LocalizedStrings.string(for: key, language: language)
        return value == key ? fallback : value
    }
}
