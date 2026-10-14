//
//  SpecialistType.swift
//  Feudalism
//
//  Specijalisti koje se kupuju / trenira u Rudarima i Inženjeringu.
//  Treba građevinu, zlato i jednog slobodnog seljaka.
//

import Foundation

enum SpecialistType: String, Codable, CaseIterable, Identifiable {
    case miner
    case engineer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .miner: return "Rudar"
        case .engineer: return "Srednjovjekovni inženjer"
        }
    }

    /// Građevina na kojoj se obučava.
    var buildingObjectId: String {
        switch self {
        case .miner: return Miners.objectId
        case .engineer: return Engineering.objectId
        }
    }

    var gold: Int {
        switch self {
        case .miner: return 8
        case .engineer: return 12
        }
    }

    var systemImage: String {
        switch self {
        case .miner: return "hammer.fill"
        case .engineer: return "wrench.and.screwdriver.fill"
        }
    }

    var localeKey: String {
        switch self {
        case .miner: return "specialist_miner"
        case .engineer: return "specialist_engineer"
        }
    }
}
