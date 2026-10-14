//
//  BuildRules.swift
//  Feudalism
//
//  Zakon gradnje — isti u map editoru i u igri, ne može se isključiti:
//  - farme: najmanje 80 % tlocrta na plodnom tlu,
//  - rudnik željeza / kamenolom: najmanje 80 % na željeznoj / kamenoj rudi,
//  - ostale građevine: najmanje 80 % na ravnoj podlozi,
//  - more: ništa; voda/rijeka: samo objekti iz waterObjectIds,
//  - izvor: samo na podzemnoj vodi.
//

import Foundation

enum BuildRules {
    /// Najmanji dio tlocrta koji mora sjediti na traženoj podlozi.
    static let minPadCoverage = 0.80

    /// Objekti koji se smiju graditi na vodi/rijeci.
    static let waterObjectIds: Set<String> = [Windmill.objectId, Steps.objectId, Bridge.objectId]

    /// Farme samo na plodnom tlu koje se crta u map editoru.
    static let farmSurfaces: Set<PovrsinaType> = [.plodna]

    /// Stabla i kamenčići nisu građevine — ne traže podlogu.
    static let decorationObjectIds: Set<String> = [
        Tree.objectId, Oak.objectId, Fir.objectId, Cypress.objectId, Palm.objectId,
        SmallRock.objectId, MediumRock.objectId, LargeRock.objectId
    ]

    /// Ceste, ploče i ukras dvorca idu na bilo koju građevnu ćeliju.
    static let infrastructureObjectIds: Set<String> = [
        Road.objectId, StoneSlab.objectId, Bridge.objectId, Tunnel.objectId,
        Canal.objectId, River.objectId,
        Flag.objectId, Torch.objectId, Monument.objectId, Candle.objectId,
        OrnamentalTree.objectId, Fountain.objectId, Roof.objectId,
        Well.objectId, Spring.objectId
    ]

    /// Što se smije graditi u podzemlju. Kasnije se lista širi.
    static let undergroundObjectIds: Set<String> = [
        UndergroundEntrance.objectId,
        UndergroundCorridor.objectId,
        UndergroundLightOpening.objectId,
        Smocnica.objectId,
        Lager.objectId
    ]

    enum PadKind {
        case iron
        case stone
        case fertile
        case flat
        case none
    }

    /// Naslaga koju objekt traži (željezo / kamen).
    static func requiredDeposit(for objectId: String) -> ResourceType? {
        switch objectId {
        case Iron.objectId: return .iron
        case Stone.objectId: return .stone
        default: return nil
        }
    }

    static func isFarm(_ objectId: String) -> Bool {
        ObjectCatalog.shared.object(id: objectId)?.category == .farme
    }

    /// Koju podlogu građevina mora imati. Zakon je isti svugdje.
    static func requiredPad(for objectId: String) -> PadKind {
        if decorationObjectIds.contains(objectId) || waterObjectIds.contains(objectId) || infrastructureObjectIds.contains(objectId) {
            return .none
        }
        if objectId == UndergroundCorridor.objectId || objectId == UndergroundLightOpening.objectId {
            return .none
        }
        switch requiredDeposit(for: objectId) {
        case .iron: return .iron
        case .stone: return .stone
        default:
            return isFarm(objectId) ? .fertile : .flat
        }
    }

    /// Smije li se objekt na jednoj ćeliji (samo teren i oznaka ćelije).
    static func cellAllows(_ cell: MapCell, objectId: String) -> Bool {
        switch cell.povrsina {
        case .more:
            return false
        case .voda:
            return waterObjectIds.contains(objectId)
        default:
            return cell.buildable
        }
    }

    static func cellMatchesPad(_ cell: MapCell, row: Int, col: Int, pad: PadKind, map: GameMap) -> Bool {
        switch pad {
        case .iron:
            return cell.resource == .iron
        case .stone:
            return cell.resource == .stone
        case .fertile:
            return farmSurfaces.contains(cell.povrsina)
        case .flat:
            return map.isFlat(row: row, col: col) && cell.buildable && cell.povrsina.isBuildable
        case .none:
            return true
        }
    }

    /// nil = smije se graditi, inače poruka zašto ne.
    static func violation(objectId: String, row: Int, col: Int, width: Int, height: Int, map: GameMap, groundwater: GroundwaterMap?) -> String? {
        let pad = requiredPad(for: objectId)
        let footprintW = max(1, width)
        let footprintH = max(1, height)
        var total = 0
        var matching = 0
        for r in row..<(row + footprintH) {
            for c in col..<(col + footprintW) {
                guard let cell = map.cell(row: r, col: c) else {
                    return "Građevina mora stati unutar mape."
                }
                if cell.povrsina == .more { return "Na moru se ne može graditi." }
                if !cellAllows(cell, objectId: objectId) {
                    return cell.povrsina == .voda
                        ? "Na vodi se mogu graditi samo neki objekti."
                        : "Na ovom području se ne može graditi."
                }
                total += 1
                if cellMatchesPad(cell, row: r, col: c, pad: pad, map: map) {
                    matching += 1
                }
            }
        }
        if pad != .none, total > 0, Double(matching) / Double(total) < minPadCoverage {
            let percent = Int(minPadCoverage * 100)
            switch pad {
            case .iron:
                return "Rudnik željeza treba barem \(percent) % tlocrta na željeznoj rudi."
            case .stone:
                return "Kamenolom treba barem \(percent) % tlocrta na kamenoj rudi."
            case .fertile:
                return "Farma treba barem \(percent) % tlocrta na plodnom tlu."
            case .flat:
                return "Građevina treba barem \(percent) % tlocrta na ravnoj podlozi."
            case .none:
                break
            }
        }
        if objectId == Spring.objectId,
           groundwater?.coversWater(row: row, col: col, width: width, height: height) != true {
            return "Izvor se može postaviti samo na podzemnu vodu."
        }
        if objectId == UndergroundCorridor.objectId {
            return "Hodnik se gradi samo u podzemlju."
        }
        return nil
    }

    /// nil = smije se graditi u podzemlju.
    static func undergroundViolation(objectId: String) -> String? {
        undergroundObjectIds.contains(objectId) ? nil : "Ova građevina se u podzemlju još ne gradi."
    }
}
