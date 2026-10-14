//
//  AILordOrderedMove.swift
//  Feudalism
//
//  Konkretan AI potez: id akcije iz bilježnice + argumenti (ćelija, pravokutnik).
//  Rječnik nema svaku (r,c) kombinaciju – koordinate idu ovdje uz odabrani tip poteza.
//

import Foundation

/// Jedan odigrani potez AI lorda (ili predloženi potez politike).
struct AILordOrderedMove: Codable, Equatable {
    /// Id iz `AILordRulebook.ActionRule` / rječnika (npr. `action:build:house`).
    var actionId: String
    /// Primarna ćelija (gradnja, rušenje, cilj slanja…).
    var row: Int?
    var col: Int?
    /// Drugi kut pravokutnika (označi vojsku).
    var farRow: Int?
    var farCol: Int?

    var cell: (row: Int, col: Int)? {
        guard let row, let col else { return nil }
        return (row, col)
    }

    var rect: GroundMark? {
        guard let row, let col, let farRow, let farCol else { return nil }
        return GroundMark(originRow: row, originCol: col, farRow: farRow, farCol: farCol)
    }

    static func wait() -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:wait")
    }

    static func build(_ objectId: String, row: Int, col: Int) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:build:\(objectId)", row: row, col: col)
    }

    static func demolish(row: Int, col: Int) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:demolish", row: row, col: col)
    }

    static func sleep(row: Int, col: Int) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:sleep", row: row, col: col)
    }

    static func wake(row: Int, col: Int) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:wake", row: row, col: col)
    }

    static func markArmy(originRow: Int, originCol: Int, farRow: Int, farCol: Int) -> AILordOrderedMove {
        AILordOrderedMove(
            actionId: "action:mark_army",
            row: originRow,
            col: originCol,
            farRow: farRow,
            farCol: farCol
        )
    }

    static func sendArmy(row: Int, col: Int) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:send_army", row: row, col: col)
    }

    static func buy(_ goodId: String) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:buy:\(goodId)")
    }

    static func sell(_ goodId: String) -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:sell:\(goodId)")
    }

    static func taxUp() -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:tax_up")
    }

    static func taxDown() -> AILordOrderedMove {
        AILordOrderedMove(actionId: "action:tax_down")
    }
}

/// Ishod izvršenja AI poteza.
struct AILordActionResult: Equatable {
    var ok: Bool
    var message: String
    var row: Int?
    var col: Int?

    static func fail(_ message: String) -> AILordActionResult {
        AILordActionResult(ok: false, message: message)
    }

    static func success(_ message: String, row: Int? = nil, col: Int? = nil) -> AILordActionResult {
        AILordActionResult(ok: true, message: message, row: row, col: col)
    }
}
