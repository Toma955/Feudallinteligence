//
//  HUDMessage.swift
//  Feudalism
//
//  Upozorenja i poruke u gornjem islandu: podloga, resursi, neprijatelj, igra, multiplayer.
//

import Foundation

enum HUDMessageKind: String, Equatable {
    case pad
    case resources
    case enemy
    case game
    case multiplayer

    var icon: String {
        switch self {
        case .pad: return "square.dashed"
        case .resources: return "shippingbox"
        case .enemy: return "shield.slash"
        case .game: return "exclamationmark.bubble"
        case .multiplayer: return "person.2.wave.2"
        }
    }

    var tint: (r: Double, g: Double, b: Double) {
        switch self {
        case .pad: return (0.95, 0.62, 0.22)
        case .resources: return (0.95, 0.38, 0.32)
        case .enemy: return (0.86, 0.22, 0.22)
        case .game: return (0.95, 0.82, 0.35)
        case .multiplayer: return (0.45, 0.72, 1.0)
        }
    }

    static func inferred(from text: String) -> HUDMessageKind {
        let t = text.lowercased()
        if t.contains("podlog") || t.contains("plodn") || t.contains("rudi") || t.contains("ravn")
            || t.contains("moru") || t.contains("vodi") || t.contains("mape") || t.contains("područ")
            || t.contains("tlocrt") || t.contains("izvor") || t.contains("hodnik") {
            return .pad
        }
        if t.contains("nedovoljno") || t.contains("nedostaje") || t.contains("cijena") || t.contains("resurs")
            || t.contains("zlato") || t.contains("seljak") {
            return .resources
        }
        if t.contains("neprijatelj") || t.contains("blizin") || t.contains("napad") {
            return .enemy
        }
        if t.contains("savez") || t.contains("diplom") || t.contains("igrač") || t.contains("multi") {
            return .multiplayer
        }
        return .game
    }
}

struct HUDMessage: Identifiable, Equatable {
    let id: UUID
    let kind: HUDMessageKind
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), kind: HUDMessageKind, text: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
    }
}
