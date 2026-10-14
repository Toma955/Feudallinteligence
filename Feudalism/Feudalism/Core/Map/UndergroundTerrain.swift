//
//  UndergroundTerrain.swift
//  Feudalism
//
//  Simbioza nadzemlje ↔ podzemlje:
//  - Nadzemlje na visini 0 nastavlja se u podzemni sloj.
//  - Podzemlje visine `filledHeight` (10) = 100 % popunjeno.
//  - Visina 9 = fali 1 m, 8 = fali 2 m, … (šupljina od stropa prema dolje).
//  - More: šuplje korito 10 m (dno + bokovi + obala), bez površine vode zasada.
//  - Rijeka / izvor okupiraju podzemlje vodom (visina 10).
//  - More i izvor se ne brišu; rijeka zasad može. Protok izvora se može namjestiti.
//  Mora ostati usklađeno s Underground.depthMeters u scene sloju.
//

import CoreGraphics
import Foundation

enum UndergroundTerrain {
    /// Visina potpuno popunjenog podzemlja (metri). Nova mapa uvijek kreće s ovom vrijednošću.
    static let filledHeight: CGFloat = 10

    /// Zadani protok izvora (jedinice po potezu). Izvor se ne briše; samo se mijenja protok.
    static let defaultSpringFlow: Double = 1

    /// Koliko metara „fali” (šupljina) za danu podzemnu visinu.
    static func missingMeters(fillHeight: CGFloat) -> CGFloat {
        max(0, filledHeight - fillHeight)
    }

    /// Koja voda okupira podzemnu ćeliju: more, rijeka, ili nil (čvrsto tlo).
    static func waterOccupation(surface: PovrsinaType, underSpring: Bool) -> PovrsinaType? {
        if surface == .more { return .more }
        if surface == .voda || underSpring { return .voda }
        return nil
    }
}
