//
//  EarthTiles.swift
//  Feudalism
//
//  Tri vrste gole zemlje i podzemno tlo. Miješaju se po veličini i okretu.
//

import AppKit

enum EarthTiles {
    /// soil_1 Ground106, soil_2 Ground051, soil_3 Ground048.
    private static let surfaceNames = [
        "Ground106_1K-JPG_Color",
        "Ground051_1K-JPG_Color",
        "Ground048_1K-JPG_Color"
    ]
    /// underground_soil Ground039.
    private static let undergroundName = "Ground039_1K-JPG_Color"

    private static let folders: [String?] = [
        "Core/Objects/Textures/tlo/soil_1",
        "Core/Objects/Textures/tlo/soil_2",
        "Core/Objects/Textures/tlo/soil_3",
        "Core/Objects/Textures/tlo/underground_soil",
        "Core/Objects/Textures/tlo",
        "Textures/tlo",
        "Feudalism/Core/Objects/Textures/tlo/soil_1",
        "Feudalism/Core/Objects/Textures/tlo/soil_2",
        "Feudalism/Core/Objects/Textures/tlo/soil_3",
        "Feudalism/Core/Objects/Textures/tlo/underground_soil",
        nil
    ]

    static let images: [CGImage] = surfaceNames.compactMap { load($0) }
    static let heights: [CGImage] = [
        "Ground106_1K-JPG_Displacement",
        "Ground051_1K-JPG_Displacement",
        "Ground048_1K-JPG_Displacement"
    ].compactMap { load($0) }
    static let underground: CGImage? = load(undergroundName)

    private static let cacheLock = NSLock()
    private static var atlasCache: NSImage?
    private static var undergroundFloorCache: NSImage?
    private static var previewCache: NSImage?

    /// Dekodira teksture i složi atlas, podzemlje i pregled. Zove se dok traje uvodno učitavanje.
    static func prepare() {
        _ = images
        _ = heights
        _ = underground
        _ = colorAtlas()
        _ = undergroundFloorImage()
        _ = previewImage()
    }

    /// Tri boje jedna uz drugu. Alfa je visina (displacement), za height blend.
    private static func makeColorAtlas() -> NSImage? {
        guard images.count == 3 else { return nil }
        let tileW = images[0].width
        let tileH = images[0].height
        let w = tileW * 3
        guard let ctx = CGContext(
            data: nil, width: w, height: tileH, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        for i in 0..<3 {
            ctx.draw(images[i], in: CGRect(x: i * tileW, y: 0, width: tileW, height: tileH))
            if i < heights.count {
                stampHeight(heights[i], into: ctx, x: i * tileW, tileW: tileW, tileH: tileH)
            }
        }
        guard let cg = ctx.makeImage() else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: w, height: tileH))
        cacheLock.lock()
        atlasCache = image
        cacheLock.unlock()
        return image
    }

    static func colorAtlas() -> NSImage? {
        cacheLock.lock()
        if let atlasCache {
            cacheLock.unlock()
            return atlasCache
        }
        cacheLock.unlock()
        return makeColorAtlas()
    }

    /// Jedan teksel po ćeliji: koja zemlja prevladava. Shader je uzorkuje bilinearno.
    static func splat(rows: Int, cols: Int, salt: Int = 1) -> NSImage? {
        guard rows > 0, cols > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: cols * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: rows * cols * 4)
        for row in 0..<rows {
            for col in 0..<cols {
                var n = UInt32(truncatingIfNeeded: row) &* 374761393
                n &+= UInt32(truncatingIfNeeded: col) &* 668265263
                n &+= UInt32(truncatingIfNeeded: salt) &* 1440671
                n = (n ^ (n >> 13)) &* 1274126177
                let which = Int(n % 3)
                let i = ((rows - 1 - row) * cols + col) * 4
                pixels[i] = which == 0 ? 255 : 0
                pixels[i + 1] = which == 1 ? 255 : 0
                pixels[i + 2] = which == 2 ? 255 : 0
                pixels[i + 3] = 255
            }
        }
        guard let cg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cols, height: rows))
    }

    /// Podzemni pod, složen jednom. Ne računa se pri otvaranju scene.
    static func undergroundFloorImage() -> NSImage {
        cacheLock.lock()
        if let undergroundFloorCache {
            cacheLock.unlock()
            return undergroundFloorCache
        }
        cacheLock.unlock()
        let image = bakedField(cells: 64, scale: 16, tiles: underground.map { [$0] } ?? images)
        cacheLock.lock()
        undergroundFloorCache = image
        cacheLock.unlock()
        return image
    }

    /// Mali pregled običnog tla za About.
    static func previewImage() -> NSImage {
        cacheLock.lock()
        if let previewCache {
            cacheLock.unlock()
            return previewCache
        }
        cacheLock.unlock()
        let image = bakedField(cells: 8, scale: 64, tiles: images)
        cacheLock.lock()
        previewCache = image
        cacheLock.unlock()
        return image
    }

    private static func bakedField(cells: Int, scale: Int, tiles: [CGImage]) -> NSImage {
        let side = cells * scale
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(size: NSSize(width: 8, height: 8))
        }
        paint(in: ctx, rows: cells, cols: cells, scale: scale, tiles: tiles)
        guard let cg = ctx.makeImage() else {
            return NSImage(size: NSSize(width: 8, height: 8))
        }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }

    private static func stampHeight(_ height: CGImage, into ctx: CGContext, x: Int, tileW: Int, tileH: Int) {
        guard let data = ctx.data else { return }
        let w = tileW * 3
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * tileH * 4)
        guard let hctx = CGContext(
            data: nil, width: tileW, height: tileH, bitsPerComponent: 8, bytesPerRow: tileW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        hctx.draw(height, in: CGRect(x: 0, y: 0, width: tileW, height: tileH))
        guard let raw = hctx.data else { return }
        let src = raw.bindMemory(to: UInt8.self, capacity: tileW * tileH * 4)
        for y in 0..<tileH {
            for px in 0..<tileW {
                let s = (y * tileW + px) * 4
                let d = (y * w + x + px) * 4
                pixels[d + 3] = src[s]
            }
        }
    }

    private static func load(_ name: String) -> CGImage? {
        for folder in folders {
            let url = folder == nil
                ? Bundle.main.url(forResource: name, withExtension: "jpg")
                : Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: folder)
            if let url, let img = NSImage(contentsOf: url),
               let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return cg
            }
        }
        return nil
    }

    /// Puna zemlja. Ground048 (treća) je baza, najmanje oko pola. Ostale dvije su raspršene šumom, bez rešetke.
    static func paint(in ctx: CGContext, rows: Int, cols: Int, scale: Int, tiles: [CGImage]) {
        guard rows > 0, cols > 0 else { return }
        let width = cols * scale
        let height = rows * scale
        ctx.setFillColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard tiles.count >= 3, let data = ctx.data else { return }
        let samples = tiles.prefix(3).map { ImageSample($0) }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let gx = Float(x) / Float(scale)
                let gy = Float(y) / Float(scale)
                let nA = fbm(gx * 0.038, gy * 0.038)
                let nB = fbm(gx * 0.026 + 8.4, gy * 0.026 + 3.1)
                var w0 = smooth(0.57, 0.80, nA)
                var w1 = smooth(0.60, 0.82, nB)
                w0 = min(w0, 0.55)
                w1 = min(w1, 0.55)
                let extra = w0 + w1
                if extra > 1.05 {
                    w0 *= 1.05 / extra
                    w1 *= 1.05 / extra
                }
                let w2: Float = 1
                let sum = w0 + w1 + w2
                let u0 = (gx * 0.22, gy * 0.22)
                let u1 = (gx * 0.081, gy * 0.081)
                let u2 = (gx * 0.029, gy * 0.029)
                var rgb = SIMD3<Float>(0, 0, 0)
                let ws = [w0 / sum, w1 / sum, w2 / sum]
                let angles: [Float] = [0.4, 1.7, 2.5]
                for i in 0..<3 {
                    let c0 = samples[i].sample(rot(u0.0, u0.1, angles[i]))
                    let c1 = samples[i].sample(rot(u1.0, u1.1, angles[i] + 0.6))
                    let c2 = samples[i].sample(rot(u2.0, u2.1, angles[i] + 1.2))
                    let layered = c0 * 0.55 + c1 * 0.30 + c2 * 0.15
                    rgb += layered * ws[i]
                }
                let macro = fbm(gx * 0.012, gy * 0.012)
                rgb *= 0.80 + macro * 0.34
                let i = (y * width + x) * 4
                pixels[i] = UInt8(min(255, max(0, rgb.x * 255)))
                pixels[i + 1] = UInt8(min(255, max(0, rgb.y * 255)))
                pixels[i + 2] = UInt8(min(255, max(0, rgb.z * 255)))
                pixels[i + 3] = 255
            }
        }
    }

    private static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    private static func rot(_ u: Float, _ v: Float, _ angle: Float) -> (Float, Float) {
        let c = cos(angle)
        let s = sin(angle)
        return (c * u - s * v, s * u + c * v)
    }

    private static func fbm(_ x: Float, _ y: Float) -> Float {
        noise(x, y) * 0.55 + noise(x * 2.13 + 4, y * 2.13) * 0.3 + noise(x * 4.27, y * 4.27 + 9) * 0.15
    }

    private static func noise(_ x: Float, _ y: Float) -> Float {
        let ix = floor(x)
        let iy = floor(y)
        let fx = x - ix
        let fy = y - iy
        let ux = fx * fx * (3 - 2 * fx)
        let uy = fy * fy * (3 - 2 * fy)
        let a = hash(ix, iy)
        let b = hash(ix + 1, iy)
        let c = hash(ix, iy + 1)
        let d = hash(ix + 1, iy + 1)
        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    }

    private static func hash(_ x: Float, _ y: Float) -> Float {
        let n = sin(x * 127.1 + y * 311.7) * 43758.5453
        return n - floor(n)
    }
}

private struct ImageSample {
    let pixels: [UInt8]
    let width: Int
    let height: Int

    init(_ image: CGImage) {
        let w = image.width
        let h = image.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        pixels = buffer
        width = w
        height = h
    }

    func sample(_ uv: (Float, Float)) -> SIMD3<Float> {
        guard width > 0, height > 0 else { return SIMD3(0.4, 0.3, 0.18) }
        let u = uv.0 - floor(uv.0)
        let v = uv.1 - floor(uv.1)
        let x = u * Float(width - 1)
        let y = v * Float(height - 1)
        let x0 = Int(x)
        let y0 = Int(y)
        let x1 = min(width - 1, x0 + 1)
        let y1 = min(height - 1, y0 + 1)
        let tx = x - Float(x0)
        let ty = y - Float(y0)
        let c00 = rgb(x0, y0)
        let c10 = rgb(x1, y0)
        let c01 = rgb(x0, y1)
        let c11 = rgb(x1, y1)
        let top = c00 + (c10 - c00) * tx
        let bottom = c01 + (c11 - c01) * tx
        return top + (bottom - top) * ty
    }

    private func rgb(_ x: Int, _ y: Int) -> SIMD3<Float> {
        let i = (y * width + x) * 4
        return SIMD3(Float(pixels[i]) / 255, Float(pixels[i + 1]) / 255, Float(pixels[i + 2]) / 255)
    }
}
