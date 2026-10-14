//
//  AILordActionExecutor.swift
//  Feudalism
//
//  Izvršava `AILordOrderedMove` za dani realm: stavi na (r,c), označi/pošalji, kupi/prodaj…
//

import Foundation

extension GameState {
    /// Izvrši potez za AI / computer lord. Koordinate moraju biti u potezu kad akcija traži ćeliju.
    @discardableResult
    func executeAIMove(_ move: AILordOrderedMove, forRealmId realmId: String) -> AILordActionResult {
        guard let seat = seatForAIRealm(realmId) else {
            return .fail("Nema sjedišta za realm.")
        }
        let factionId = seat.id
        let rules = AILordRulebook.current
        guard let rule = rules.actions.first(where: { $0.id == move.actionId }) else {
            return .fail("Nepoznata akcija \(move.actionId).")
        }
        if rule.needsRect, move.rect == nil {
            return .fail("Akcija traži pravokutnik (row/col + farRow/farCol).")
        }
        if rule.needsCell, move.cell == nil {
            return .fail("Akcija traži ćeliju (row/col).")
        }

        switch rule.kind {
        case "wait":
            return .success("Čeka.")
        case "build":
            return executeAIBuild(objectId: rule.target, owner: factionId, move: move)
        case "workplace":
            return executeAIWorkplace(rule: rule, factionId: factionId, move: move)
        case "army":
            return executeAIArmy(rule: rule, factionId: factionId, seat: seat, move: move)
        case "trade":
            return executeAITrade(rule: rule, factionId: factionId)
        case "economy":
            return executeAIEconomy(rule: rule, factionId: factionId)
        case "diplomacy":
            return .fail("Diplomacija još nije spojena na izvršavanje.")
        case "train":
            return executeAITrain(target: rule.target, factionId: factionId)
        default:
            return .fail("Nepodržana vrsta \(rule.kind).")
        }
    }

    private func seatForAIRealm(_ realmId: String) -> RealmSeat? {
        realmSeats.seats.first { $0.id == realmId || $0.realmIds.contains(realmId) }
    }

    private func executeAIBuild(objectId: String, owner: String, move: AILordOrderedMove) -> AILordActionResult {
        guard let cell = move.cell else { return .fail("Nema ćelije.") }
        guard placeAIBuilding(objectId: objectId, owner: owner, row: cell.row, col: cell.col) else {
            return .fail("Ne može sagraditi \(objectId) na \(cell.row),\(cell.col).")
        }
        let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
        return .success("Sagradio \(name).", row: cell.row, col: cell.col)
    }

    /// Postavi građevinu točno na (row, col). Bez traženja alternativnog mjesta.
    @discardableResult
    func placeAIBuilding(objectId: String, owner: String, row: Int, col: Int) -> Bool {
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = max(1, obj?.size.width ?? 1)
        let height = max(1, obj?.size.height ?? 1)
        guard row >= 1, col >= 1, row + height <= gameMap.rows, col + width <= gameMap.cols else { return false }
        guard mapLogic.isFree(.surface, row: row, col: col, width: width, height: height) else { return false }
        if buildRuleViolation(objectId: objectId, row: row, col: col, width: width, height: height) != nil { return false }
        guard let placed = gameMap.place(
            objectId: objectId,
            width: width,
            height: height,
            atRow: row,
            col: col,
            ownerId: owner
        ) else { return false }
        noteBuildingBorn(placed.id)
        notePlacementsChanged()
        return true
    }

    private func executeAIWorkplace(
        rule: AILordRulebook.ActionRule,
        factionId: String,
        move: AILordOrderedMove
    ) -> AILordActionResult {
        guard let cell = move.cell else { return .fail("Nema ćelije.") }
        guard let placement = placementOwned(atRow: cell.row, col: cell.col, factionId: factionId) else {
            return .fail("Nema tvoje građevine na \(cell.row),\(cell.col).")
        }
        switch rule.id {
        case "action:sleep":
            setWorkplaceClosed(placementId: placement.id, closed: true)
            return .success("Uspavao građevinu.", row: cell.row, col: cell.col)
        case "action:wake":
            setWorkplaceClosed(placementId: placement.id, closed: false)
            return .success("Probudio građevinu.", row: cell.row, col: cell.col)
        case "action:demolish":
            demolishPlacement(id: placement.id)
            return .success("Srušio građevinu.", row: cell.row, col: cell.col)
        default:
            return .fail("Nepoznato radno mjesto: \(rule.id).")
        }
    }

    private func placementOwned(atRow row: Int, col: Int, factionId: String) -> Placement? {
        guard let p = gameMap.placement(at: MapCoordinate(row: row, col: col)) else { return nil }
        guard owner(of: p) == factionId, !p.isDestroyed else { return nil }
        return p
    }

    private func executeAIArmy(
        rule: AILordRulebook.ActionRule,
        factionId: String,
        seat: RealmSeat,
        move: AILordOrderedMove
    ) -> AILordActionResult {
        switch rule.id {
        case "action:mark_army":
            guard let mark = move.rect else { return .fail("Nema pravokutnika.") }
            let marked = people(inside: mark, factionId: factionId)
            aiMarkedByFaction[factionId] = marked
            if factionId == playerSeat?.id {
                groundMark = mark
                markedPeople = marked
            }
            return .success(
                "Označio \(marked.count) jedinica.",
                row: mark.originRow,
                col: mark.originCol
            )
        case "action:send_army":
            guard let cell = move.cell else { return .fail("Nema cilja.") }
            let marked = aiMarkedByFaction[factionId]
                ?? (factionId == playerSeat?.id ? markedPeople : [])
            guard !marked.isEmpty else { return .fail("Nema označenih jedinica.") }
            sendArmy(marked, factionId: factionId, row: cell.row, col: cell.col)
            if factionId == playerSeat?.id {
                markedPeople = marked
            }
            return .success("Poslao vojsku.", row: cell.row, col: cell.col)
        default:
            return .fail("Nepoznata vojna akcija.")
        }
    }

    private func executeAITrade(rule: AILordRulebook.ActionRule, factionId: String) -> AILordActionResult {
        guard let good = Good(rawValue: rule.target) else {
            return .fail("Nepoznata roba \(rule.target).")
        }
        if rule.id.hasPrefix("action:buy:") {
            let before = goodAmount(good)
            marketBuy(good, faction: factionId)
            let after = goodAmount(good)
            guard after > before else { return .fail("Kupnja \(good.rawValue) nije uspjela.") }
            return .success("Kupio \(good.rawValue).")
        }
        if rule.id.hasPrefix("action:sell:") {
            let before = goodAmount(good)
            marketSell(good, faction: factionId)
            let after = goodAmount(good)
            guard after < before else { return .fail("Prodaja \(good.rawValue) nije uspjela.") }
            return .success("Prodao \(good.rawValue).")
        }
        return .fail("Nepoznata trgovina.")
    }

    private func executeAIEconomy(rule: AILordRulebook.ActionRule, factionId: String) -> AILordActionResult {
        switch rule.id {
        case "action:tax_up":
            setTaxLevel(taxLevel(of: factionId) + 1, faction: factionId)
            return .success("Porez \(taxLevel(of: factionId)).")
        case "action:tax_down":
            setTaxLevel(taxLevel(of: factionId) - 1, faction: factionId)
            return .success("Porez \(taxLevel(of: factionId)).")
        case "action:deposit_gold":
            return .fail("Uplata u riznicu još nije spojena.")
        default:
            return .fail("Nepoznata ekonomija.")
        }
    }

    private func executeAITrain(target: String, factionId: String) -> AILordActionResult {
        if let soldier = SoldierType.allCases.first(where: { $0.id == target }) {
            let err = trainSoldier(soldier, faction: factionId)
            if let err { return .fail(err) }
            return .success("Obučio \(soldier.displayName).")
        }
        if let specialist = SpecialistType.allCases.first(where: { $0.id == target }) {
            let err = trainSpecialist(specialist, faction: factionId)
            if let err { return .fail(err) }
            return .success("Obučio \(specialist.displayName).")
        }
        return .fail("Nepoznat tip \(target).")
    }
}
