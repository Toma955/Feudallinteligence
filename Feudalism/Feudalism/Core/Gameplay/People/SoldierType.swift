//
//  SoldierType.swift
//  Feudalism
//
//  Vrste vojnika koje se obučavaju na Treningu. Svaki treba jednu osobu (slobodnog seljaka),
//  oružje iz oružarnice i zlato. Lakši su brži, teži sporiji, ali izdržljiviji.
//  Konjanici uz to trebaju konja iz štale i najbrži su.
//

import Foundation

enum SoldierType: String, Codable, CaseIterable, Identifiable {
    case archer
    case armoredArcher
    case spearman
    case shieldSpearman
    case swordsman
    case shieldSwordsman
    case heavyInfantry
    case mountedArcher
    case lancer
    case knight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .archer: return "Strijelac"
        case .armoredArcher: return "Strijelac u oklopu"
        case .spearman: return "Kopljanik"
        case .shieldSpearman: return "Kopljanik sa štitom"
        case .swordsman: return "Mačevalac"
        case .shieldSwordsman: return "Mačevalac sa štitom"
        case .heavyInfantry: return "Teški pješak"
        case .mountedArcher: return "Konjanik strijelac"
        case .lancer: return "Konjanik s kopljem"
        case .knight: return "Vitez"
        }
    }

    /// Oružje i oprema iz oružarnice.
    var equipment: [Good: Int] {
        switch self {
        case .archer: return [.bow: 1]
        case .armoredArcher: return [.bow: 1, .shield: 1]
        case .spearman: return [.spear: 1]
        case .shieldSpearman: return [.spear: 1, .shield: 1]
        case .swordsman: return [.sword: 1]
        case .shieldSwordsman: return [.sword: 1, .shield: 1]
        case .heavyInfantry: return [.sword: 1, .shield: 1, .leather: 1]
        case .mountedArcher: return [.horse: 1, .bow: 1]
        case .lancer: return [.horse: 1, .spear: 1, .shield: 1]
        case .knight: return [.horse: 1, .sword: 1, .shield: 1, .leather: 1]
        }
    }

    var gold: Int {
        switch self {
        case .archer, .spearman: return 5
        case .swordsman: return 8
        case .armoredArcher, .shieldSpearman: return 10
        case .shieldSwordsman: return 12
        case .heavyInfantry, .mountedArcher: return 15
        case .lancer: return 18
        case .knight: return 25
        }
    }

    /// Množitelj osnovne brzine hoda (1 = kao seljak).
    var speedFactor: Double {
        switch self {
        case .mountedArcher: return 1.9
        case .lancer: return 1.75
        case .knight: return 1.6
        case .archer: return 1.4
        case .spearman: return 1.3
        case .armoredArcher, .swordsman: return 1.1
        case .shieldSpearman: return 1.0
        case .shieldSwordsman: return 0.9
        case .heavyInfantry: return 0.75
        }
    }

    /// Izdržljivost (zdravlje) za borbu; seljak ima 50.
    var health: Int {
        switch self {
        case .archer: return 60
        case .spearman: return 70
        case .armoredArcher: return 90
        case .swordsman: return 100
        case .shieldSpearman: return 110
        case .shieldSwordsman: return 130
        case .heavyInfantry: return 170
        case .mountedArcher: return 90
        case .lancer: return 150
        case .knight: return 220
        }
    }

    var speedText: String {
        switch speedFactor {
        case 1.6...: return "najbrži (konj)"
        case 1.3..<1.6: return "vrlo brz"
        case 1.05..<1.3: return "brz"
        case 0.95..<1.05: return "srednji"
        case 0.8..<0.95: return "spor"
        default: return "vrlo spor"
        }
    }

    /// Glavno oružje (za prikaz u ruci).
    var mainWeapon: Good {
        switch self {
        case .archer, .armoredArcher, .mountedArcher: return .bow
        case .spearman, .shieldSpearman, .lancer: return .spear
        case .swordsman, .shieldSwordsman, .heavyInfantry, .knight: return .sword
        }
    }

    var hasShield: Bool { equipment[.shield] != nil }
    var hasArmor: Bool { equipment[.leather] != nil }
    var isMounted: Bool { equipment[.horse] != nil }

    /// Stari zapis (samo oružje) → vrsta vojnika.
    static func legacy(weapon: Good?) -> SoldierType {
        switch weapon {
        case .bow: return .archer
        case .spear: return .spearman
        default: return .swordsman
        }
    }
}
