//
//  PovrsinaType.swift
//  Feudalism
//
//  Teren ćelije mape – označen slovom. Default G = poluplodna zemlja.
//  Novi tereni se dodaju ovdje (slovo, ime, kretanje, gradnja, plodnost).
//

import Foundation

/// Teren jedne ćelije. Slovo = kratka oznaka za datoteku mape i UI.
enum PovrsinaType: String, Codable, CaseIterable, Identifiable {
    case pustinja = "D"
    case poluplodna = "G"
    case plodna = "F"
    case trava = "T"
    case voda = "W"
    case more = "M"
    case put = "R"
    case kamen = "S"
    case mocvara = "B"

    var id: String { rawValue }

    var letterCode: String { rawValue }

    var displayName: String {
        switch self {
        case .pustinja: return "Pustinja"
        case .poluplodna: return "Poluplodna zemlja"
        case .plodna: return "Plodna zemlja"
        case .trava: return "Trava"
        case .voda: return "Voda"
        case .more: return "More"
        case .put: return "Put"
        case .kamen: return "Kamen / stijena"
        case .mocvara: return "Močvara"
        }
    }

    /// Standardni indeks kretanja: 1 = normalno, 0 = neprohodno, veće od 1 = brže.
    var defaultMovementIndex: Double {
        switch self {
        case .put: return 1.5
        case .poluplodna, .plodna, .trava: return 1
        case .pustinja: return 0.8
        case .kamen: return 0.6
        case .mocvara: return 0.4
        case .voda, .more: return 0
        }
    }

    var isBuildable: Bool {
        switch self {
        case .voda, .more, .mocvara: return false
        case .pustinja, .poluplodna, .plodna, .trava, .put, .kamen: return true
        }
    }

    var isWalkable: Bool { defaultMovementIndex > 0 }

    /// Plodnost za farme: 0 = ništa ne raste, 1 = najbolje.
    var fertility: Double {
        switch self {
        case .plodna: return 1
        case .poluplodna: return 0.6
        case .trava: return 0
        case .mocvara: return 0.3
        case .pustinja: return 0.1
        case .voda, .more, .put, .kamen: return 0
        }
    }

    static var `default`: PovrsinaType { .poluplodna }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let value = PovrsinaType(rawValue: raw) {
            self = value
        } else {
            // Stare mape: P = ravnica.
            self = .poluplodna
        }
    }
}
