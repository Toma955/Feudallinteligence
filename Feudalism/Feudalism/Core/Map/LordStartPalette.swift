//
//  LordStartPalette.swift
//  Feudalism
//
//  Boje početnih mjesta AI lordova (map editor) – ista boja u izborniku i na mapi.
//

import AppKit
import SwiftUI

enum LordStartPalette {
    private static let hexes = ["D64545", "2E86AB", "3BA55C", "E0A526", "8E44AD", "E67E22", "1ABC9C", "7F8C8D"]

    static func hex(slot: Int) -> String {
        hexes[(max(1, slot) - 1) % hexes.count]
    }

    static func color(slot: Int) -> NSColor {
        let value = UInt32(hex(slot: slot), radix: 16) ?? 0
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func swiftUIColor(slot: Int) -> Color {
        Color(nsColor: color(slot: slot))
    }
}
