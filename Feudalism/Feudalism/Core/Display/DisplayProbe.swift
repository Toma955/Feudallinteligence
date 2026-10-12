//
//  DisplayProbe.swift
//  Feudalism
//
//  Mjeri trenutni zaslon: točke, pikseli, omjer i dijagonala u inčima.
//  MacBook obitelj se prepoznaje po pikselima; ostalo je prilagođeni zaslon.
//

import AppKit
import CoreGraphics

struct DisplaySnapshot: Equatable {
    let pointWidth: Int
    let pointHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: CGFloat
    let ratioW: Int
    let ratioH: Int
    let diagonalInches: Double?
    let recognizedName: String
    let isCustom: Bool

    var pointsLabel: String { "\(pointWidth) × \(pointHeight)" }
    var pixelsLabel: String { "\(pixelWidth) × \(pixelHeight)" }
    var ratioLabel: String { "\(ratioW)∶\(ratioH)" }
    var inchesLabel: String {
        guard let inches = diagonalInches else { return "nepoznato" }
        return String(format: "%.1f inča", inches)
    }
}

enum DisplayProbe {
    static let commonRatios: [(Int, Int, String)] = [
        (16, 10, "MacBook (većina)"),
        (16, 9, "Široki / vanjski"),
        (3, 2, "Površina / neki prijenosnici"),
        (4, 3, "Klasični")
    ]

    static func current(screen: NSScreen? = NSScreen.main) -> DisplaySnapshot {
        let screen = screen ?? NSScreen.screens.first
        let frame = screen?.frame ?? .zero
        let scale = screen?.backingScaleFactor ?? 2
        let pw = max(1, Int(frame.width.rounded()))
        let ph = max(1, Int(frame.height.rounded()))
        let pixelsW = max(1, Int((frame.width * scale).rounded()))
        let pixelsH = max(1, Int((frame.height * scale).rounded()))
        let (rw, rh) = reducedRatio(pixelsW, pixelsH)
        let inches = diagonalInches(of: screen)
        let match = recognize(pixelsW: pixelsW, pixelsH: pixelsH, inches: inches)
        return DisplaySnapshot(
            pointWidth: pw,
            pointHeight: ph,
            pixelWidth: pixelsW,
            pixelHeight: pixelsH,
            scale: scale,
            ratioW: rw,
            ratioH: rh,
            diagonalInches: inches,
            recognizedName: match.name,
            isCustom: match.custom
        )
    }

    static func reducedRatio(_ a: Int, _ b: Int) -> (Int, Int) {
        let g = gcd(max(a, 1), max(b, 1))
        return (a / g, b / g)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = a, y = b
        while y != 0 { (x, y) = (y, x % y) }
        return max(1, x)
    }

    private static func diagonalInches(of screen: NSScreen?) -> Double? {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        let mm = CGDisplayScreenSize(CGDirectDisplayID(number.uint32Value))
        guard mm.width > 1, mm.height > 1 else { return nil }
        return hypot(mm.width, mm.height) / 25.4
    }

    private static func recognize(pixelsW: Int, pixelsH: Int, inches: Double?) -> (name: String, custom: Bool) {
        let key = "\(max(pixelsW, pixelsH))x\(min(pixelsW, pixelsH))"
        let known: [String: (String, Double)] = [
            "3456x2234": ("MacBook Pro 16\"", 16.2),
            "3024x1964": ("MacBook Pro 14\"", 14.2),
            "2880x1864": ("MacBook Air 15\"", 15.3),
            "2560x1664": ("MacBook Air 13\"", 13.6),
            "2560x1600": ("MacBook Pro 13\"", 13.3),
            "3072x1920": ("MacBook Pro 16\" (Intel)", 16.0),
            "2880x1800": ("MacBook Pro 15\" (Intel)", 15.4)
        ]
        if let hit = known[key] {
            return (hit.0, false)
        }
        if let inches {
            let close = known.values.min(by: { abs($0.1 - inches) < abs($1.1 - inches) })
            if let close, abs(close.1 - inches) <= 0.35 {
                return (close.0, false)
            }
            return ("Prilagođeni zaslon (\(String(format: "%.1f", inches)) inča)", true)
        }
        return ("Prilagođeni zaslon", true)
    }
}
