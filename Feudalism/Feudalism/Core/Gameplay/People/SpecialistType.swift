//
//  SpecialistType.swift
//  Feudalism
//
//  Specijalisti: Rudari / Inženjering / Akademija.
//  Treba građevinu, zlato i jednog slobodnog seljaka.
//

import Foundation

enum SpecialistType: String, Codable, CaseIterable, Identifiable {
    case miner
    case engineer
    /// Akademija
    case attackCommander
    case defenseCommander
    case diplomat
    case logistician
    case spy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .miner: return "Rudar"
        case .engineer: return "Srednjovjekovni inženjer"
        case .attackCommander: return "Vojskovođa (napad)"
        case .defenseCommander: return "Vojskovođa (obrana)"
        case .diplomat: return "Diplomat"
        case .logistician: return "Logističar"
        case .spy: return "Špijun"
        }
    }

    /// Građevina na kojoj se obučava.
    var buildingObjectId: String {
        switch self {
        case .miner: return Miners.objectId
        case .engineer: return Engineering.objectId
        case .attackCommander, .defenseCommander, .diplomat, .logistician, .spy:
            return Academy.objectId
        }
    }

    /// Tipovi koje Akademija nudi.
    static var academyTypes: [SpecialistType] {
        [.attackCommander, .defenseCommander, .diplomat, .logistician, .spy]
    }

    var gold: Int {
        switch self {
        case .miner: return 8
        case .engineer: return 12
        case .attackCommander, .defenseCommander: return 20
        case .diplomat: return 16
        case .logistician: return 14
        case .spy: return 18
        }
    }

    var systemImage: String {
        switch self {
        case .miner: return "hammer.fill"
        case .engineer: return "wrench.and.screwdriver.fill"
        case .attackCommander: return "flag.fill"
        case .defenseCommander: return "shield.lefthalf.filled"
        case .diplomat: return "envelope.fill"
        case .logistician: return "shippingbox.fill"
        case .spy: return "eye.fill"
        }
    }

    var localeKey: String {
        switch self {
        case .miner: return "specialist_miner"
        case .engineer: return "specialist_engineer"
        case .attackCommander: return "specialist_attack_commander"
        case .defenseCommander: return "specialist_defense_commander"
        case .diplomat: return "specialist_diplomat"
        case .logistician: return "specialist_logistician"
        case .spy: return "specialist_spy"
        }
    }

    /// Poruka kad građevina za obuku ne postoji.
    var missingBuildingMessage: String {
        switch self {
        case .miner: return "Treba Rudari."
        case .engineer: return "Treba Inženjering."
        case .attackCommander, .defenseCommander, .diplomat, .logistician, .spy:
            return "Treba Akademija."
        }
    }
}
