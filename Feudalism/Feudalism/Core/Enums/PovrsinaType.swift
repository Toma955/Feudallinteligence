//
//  PovrsinaType.swift
//  Feudalism
//
//  Teren jedne ćelije, broj 0…7.
//  Trava je tekstura na običnom tlu. Put nije površina.
//

import Foundation

/// Teren jedne ćelije. Broj je šifra u snimci i u datoteci mape.
enum PovrsinaType: Int, Codable, CaseIterable, Identifiable {
    case pustinja = 0
    case kamen = 1
    case zeljezo = 2
    case tlo = 3
    case plodna = 4
    case more = 5
    case mocvara = 6
    case voda = 7

    var id: Int { rawValue }

    /// Ključ u starom map_textures.json, dok se datoteka ne prepiše brojevima.
    var textureKey: String {
        switch self {
        case .pustinja: return "D"
        case .kamen: return "S"
        case .zeljezo: return "2"
        case .tlo: return "G"
        case .plodna: return "F"
        case .more: return "M"
        case .mocvara: return "B"
        case .voda: return "W"
        }
    }

    var displayName: String {
        switch self {
        case .pustinja: return "Pustinja"
        case .kamen: return "Kamen"
        case .zeljezo: return "Željezo"
        case .tlo: return "Tlo obično"
        case .plodna: return "Plodna ravnica"
        case .more: return "More"
        case .mocvara: return "Močvara"
        case .voda: return "Voda"
        }
    }

    /// 1 = normalno, 0 = neprohodno.
    var defaultMovementIndex: Double {
        switch self {
        case .tlo, .plodna: return 1
        case .pustinja: return 0.8
        case .kamen, .zeljezo: return 0.6
        case .mocvara: return 0.4
        case .voda, .more: return 0
        }
    }

    var isBuildable: Bool {
        switch self {
        case .voda, .more, .mocvara: return false
        case .pustinja, .kamen, .zeljezo, .tlo, .plodna: return true
        }
    }

    var isWalkable: Bool { defaultMovementIndex > 0 }

    /// Plodnost za farme: 0 = ništa ne raste, 1 = najbolje.
    var fertility: Double {
        switch self {
        case .plodna: return 1
        case .tlo: return 0.6
        case .mocvara: return 0.3
        case .pustinja: return 0.1
        case .voda, .more, .kamen, .zeljezo: return 0
        }
    }

    static var `default`: PovrsinaType { .tlo }

    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if let number = try? box.decode(Int.self), let value = PovrsinaType(rawValue: number) {
            self = value
            return
        }
        let raw = (try? box.decode(String.self)) ?? ""
        if let number = Int(raw), let value = PovrsinaType(rawValue: number) {
            self = value
            return
        }
        switch raw {
        case "D": self = .pustinja
        case "S": self = .kamen
        case "F": self = .plodna
        case "M": self = .more
        case "B": self = .mocvara
        case "W": self = .voda
        case "G", "T", "R", "P": self = .tlo
        default: self = .tlo
        }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        try box.encode(rawValue)
    }
}
