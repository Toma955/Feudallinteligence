//
//  Placement.swift
//  Feudalism
//
//  Jedan postavljeni objekt na mapi – referenca na template (GameObject) + pozicija + veličina.
//  Objekt veličine 4×4 zauzima 16 ćelija (4 reda × 4 stupca) od točke (row, col).
//

import Foundation

/// Jedan postavljeni objekt na mapi: gornji-lijevi ugao (row, col) + veličina (width × height) + život (HP).
struct Placement: Identifiable, Codable, Sendable {
    /// Jedinstveni id instance (npr. za brisanje).
    let id: String
    /// Id objekta iz kataloga (GameObject.id).
    let objectId: String
    /// Red gornjeg-lijevog kuta (u 1×1 jedinicama).
    let row: Int
    /// Stupac gornjeg-lijevog kuta (u 1×1 jedinicama).
    let col: Int
    /// Širina u jedinicama (npr. 4 za kuću).
    let width: Int
    /// Visina u jedinicama (npr. 4 za kuću).
    let height: Int
    /// Trenutni život (HP). Maksimum iz ObjectHealth za objectId (npr. zid: 10 levela × 10 = 100).
    let currentHealth: Int
    /// Frakcija (RealmSeat.id) koja posjeduje građevinu. nil = postavljeno u map editoru;
    /// u partiji takvu građevinu preuzima najbliži dvorac.
    let ownerId: String?

    enum CodingKeys: String, CodingKey {
        case id, objectId, row, col, width, height, currentHealth, ownerId
    }

    init(id: String? = nil, objectId: String, row: Int, col: Int, width: Int, height: Int, currentHealth: Int? = nil, ownerId: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.objectId = objectId
        self.row = row
        self.col = col
        self.width = max(1, width)
        self.height = max(1, height)
        self.currentHealth = currentHealth ?? ObjectHealth.shared.maxHealth(for: objectId)
        self.ownerId = ownerId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        let decodedObjectId = try c.decode(String.self, forKey: .objectId)
        objectId = decodedObjectId
        row = try c.decode(Int.self, forKey: .row)
        col = try c.decode(Int.self, forKey: .col)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        currentHealth = try c.decodeIfPresent(Int.self, forKey: .currentHealth) ?? ObjectHealth.shared.maxHealth(for: decodedObjectId)
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(objectId, forKey: .objectId)
        try c.encode(row, forKey: .row)
        try c.encode(col, forKey: .col)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(currentHealth, forKey: .currentHealth)
        try c.encodeIfPresent(ownerId, forKey: .ownerId)
    }

    /// Sve koordinate koje ovaj placement pokriva: [row..row+height) × [col..col+width).
    func coveredCoordinates() -> [MapCoordinate] {
        (row..<(row + height)).flatMap { r in
            (col..<(col + width)).map { c in MapCoordinate(row: r, col: c) }
        }
    }

    /// Sadrži li ovaj placement danu koordinatu?
    func contains(_ coordinate: MapCoordinate) -> Bool {
        coordinate.row >= row && coordinate.row < row + height &&
        coordinate.col >= col && coordinate.col < col + width
    }

    /// Kopija placementa s novim trenutnim zdravljem (za primjenu štete ili liječenja).
    func withHealth(_ newHealth: Int) -> Placement {
        Placement(id: id, objectId: objectId, row: row, col: col, width: width, height: height, currentHealth: max(0, newHealth), ownerId: ownerId)
    }

    /// Je li objekt uništen (0 HP)?
    var isDestroyed: Bool { currentHealth <= 0 }
}
