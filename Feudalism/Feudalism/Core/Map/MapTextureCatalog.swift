//
//  MapTextureCatalog.swift
//  Feudalism
//
//  Teksture tla mape po vrsti površine (PovrsinaType). Slike idu u Core/Objects/Textures/map/
//  (map_plodna.png, map_voda.png…). Dok slike nema, koristi se boja iz map_textures.json.
//

import Foundation
import AppKit

struct MapTextureEntry {
    let surface: PovrsinaType
    let name: String
    let fileName: String
    let color: (CGFloat, CGFloat, CGFloat)
}

enum MapTextureCatalog {
    private static let fileName = "map_textures"
    private static let subdirs: [String?] = [
        "Core/Objects/Textures/map",
        "Objects/Textures/map",
        "Textures/map",
        "Feudalism/Core/Objects/Textures/map",
        nil
    ]

    private struct FileShape: Decodable {
        var teksture: [String: Entry]?
        struct Entry: Decodable {
            var naziv: String?
            var datoteka: String?
            var boja: [Double]?
        }
    }

    private static let file: FileShape? = {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(FileShape.self, from: data)
    }()

    static let entries: [MapTextureEntry] = PovrsinaType.allCases.map { surface in
        let raw = file?.teksture?[surface.textureKey] ?? file?.teksture?["\(surface.rawValue)"]
        let rgb = raw?.boja
        let r = CGFloat(rgb?[safe: 0] ?? Double(fallbackColor(surface).0))
        let g = CGFloat(rgb?[safe: 1] ?? Double(fallbackColor(surface).1))
        let b = CGFloat(rgb?[safe: 2] ?? Double(fallbackColor(surface).2))
        return MapTextureEntry(
            surface: surface,
            name: raw?.naziv ?? surface.displayName,
            fileName: raw?.datoteka ?? "map_\(surface)",
            color: (r, g, b)
        )
    }

    static func entry(for surface: PovrsinaType) -> MapTextureEntry {
        entries.first { $0.surface == surface } ?? MapTextureEntry(
            surface: surface, name: surface.displayName, fileName: "map_\(surface)", color: fallbackColor(surface)
        )
    }

    static func fallbackColor(_ surface: PovrsinaType) -> (CGFloat, CGFloat, CGFloat) {
        switch surface {
        case .pustinja: return (0.93, 0.80, 0.45)
        case .kamen: return (0.55, 0.55, 0.58)
        case .zeljezo: return (0.45, 0.28, 0.24)
        case .tlo: return (0.38, 0.58, 0.24)
        case .plodna: return (0.20, 0.62, 0.18)
        case .more: return (0.05, 0.20, 0.65)
        case .mocvara: return (0.30, 0.40, 0.25)
        case .voda: return (0.25, 0.60, 1.00)
        }
    }

    private static func loadData() -> Data? {
        let bundle = Bundle.main
        for sub in subdirs {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        if let url = bundle.url(forResource: fileName, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Učitava i kešira ploče tla po površini. Ako slike nema, pravi ploču iz boje.
final class MapTextureLoader {
    static let shared = MapTextureLoader()

    private var cache: [PovrsinaType: CGImage] = [:]
    private let lock = NSLock()
    private let tileSize = 64
    private let imageSubdirs: [String?] = [
        "Core/Objects/Textures/map",
        "Objects/Textures/map",
        "Textures/map",
        "Feudalism/Core/Objects/Textures/map",
        nil
    ]

    private init() {}

    func tileImage(for surface: PovrsinaType, bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[surface] { return cached }
        let entry = MapTextureCatalog.entry(for: surface)
        let loaded = loadImage(named: entry.fileName, bundle: bundle)
            ?? (surface == .tlo ? TerrainTextureLoader.shared.tileImage(for: .grass, bundle: bundle) : nil)
            ?? makeColorTile(entry.color)
        if let loaded { cache[surface] = loaded }
        return loaded
    }

    func tileImages(bundle: Bundle = .main) -> [PovrsinaType: CGImage] {
        Dictionary(uniqueKeysWithValues: PovrsinaType.allCases.compactMap { surface in
            tileImage(for: surface, bundle: bundle).map { (surface, $0) }
        })
    }

    func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    private func loadImage(named name: String, bundle: Bundle) -> CGImage? {
        for sub in imageSubdirs {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub)
                ?? bundle.url(forResource: name, withExtension: "jpg", subdirectory: sub),
               let img = NSImage(contentsOf: url),
               let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return cg
            }
        }
        return nil
    }

    private func makeColorTile(_ color: (CGFloat, CGFloat, CGFloat)) -> CGImage? {
        let w = tileSize
        guard let ctx = CGContext(
            data: nil, width: w, height: w, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))
        return ctx.makeImage()
    }
}
