//
//  SeaBasin.swift
//  Feudalism
//
//  More: šuplje korito (UndergroundTerrain.filledHeight) + zidovi/dno/voda.
//  Attach nakon „Gotovo” u editoru mora (SceneKitMapView).
//  wall  = okomite strane prema unutra (Rock035 u map/sea/wall/)
//  coast = kasnije Ground095A
//  bottom = zasada ista tekstura kao wall; kasnije map/sea/bottom/
//  water = Metal površina (RiverWaterShader.seaProgram) s animacijom valova
//

import SceneKit
import AppKit
import Foundation

enum SeaBasinPart: String, CaseIterable {
    case bottom
    case wall
    case coast

    var folderName: String { rawValue }
}

/// PBR set iz mape (Color + NormalGL + Roughness + AO + Displacement).
struct SeaBasinPBR {
    var color: NSImage?
    var normal: NSImage?
    var roughness: NSImage?
    var ambientOcclusion: NSImage?
    var displacement: NSImage?
}

enum SeaBasinTextures {
    private static var cache: [SeaBasinPart: SeaBasinPBR] = [:]
    private static let lock = NSLock()
    private static let seaRootCandidates: [String] = [
        "Core/Objects/Textures/map/sea",
        "Objects/Textures/map/sea",
        "Textures/map/sea"
    ]

    static func pbr(for part: SeaBasinPart, bundle: Bundle = .main) -> SeaBasinPBR {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[part] { return cached }
        let loaded = loadPBR(in: part.folderName, bundle: bundle) ?? SeaBasinPBR(color: makeFallback(part))
        cache[part] = loaded
        return loaded
    }

    static func image(for part: SeaBasinPart, bundle: Bundle = .main) -> NSImage? {
        pbr(for: part, bundle: bundle).color ?? makeFallback(part)
    }

    private static func loadPBR(in folder: String, bundle: Bundle) -> SeaBasinPBR? {
        guard let dir = resolveFolderURL(folder: folder, bundle: bundle),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return nil
        }
        let images = files.filter {
            let e = $0.pathExtension.lowercased()
            return e == "png" || e == "jpg" || e == "jpeg"
        }
        guard !images.isEmpty else { return nil }

        func pick(_ suffixes: [String]) -> NSImage? {
            for s in suffixes {
                if let url = images.first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains(s) }),
                   let img = NSImage(contentsOf: url) {
                    return img
                }
            }
            return nil
        }

        // Prefer AmbientOcclusion / Color / NormalGL / Roughness / Displacement iz packa (npr. Rock035_1K-JPG_Color.jpg).
        let color = pick(["_Color.", "_Color_"])
            ?? pickPreviewColor(images)
        let normal = pick(["_NormalGL.", "NormalGL"])
            ?? pick(["_Normal.", "Normal"])
        let roughness = pick(["_Roughness.", "Roughness"])
        let ao = pick(["_AmbientOcclusion.", "AmbientOcclusion", "_AO."])
        let displacement = pick(["_Displacement.", "Displacement", "_Height.", "Height"])

        guard color != nil || normal != nil else { return nil }
        return SeaBasinPBR(
            color: color,
            normal: normal,
            roughness: roughness,
            ambientOcclusion: ao,
            displacement: displacement
        )
    }

    /// Glavna boja: Rock035.png / Ground095A.png, ne Normal/Roughness/AO.
    private static func pickPreviewColor(_ images: [URL]) -> NSImage? {
        let banned = ["normal", "roughness", "displacement", "ambient", "_ao", "metalness"]
        let sorted = images.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in sorted {
            let name = url.lastPathComponent.lowercased()
            if banned.contains(where: { name.contains($0) }) { continue }
            if let img = NSImage(contentsOf: url) { return img }
        }
        return sorted.first.flatMap { NSImage(contentsOf: $0) }
    }

    private static func resolveFolderURL(folder: String, bundle: Bundle) -> URL? {
        for root in seaRootCandidates {
            if let url = bundle.resourceURL?
                .appendingPathComponent(root)
                .appendingPathComponent(folder),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            // Bundle subdirectory API
            if let urls = bundle.urls(forResourcesWithExtension: "jpg", subdirectory: "\(root)/\(folder)"),
               let first = urls.first {
                return first.deletingLastPathComponent()
            }
            if let urls = bundle.urls(forResourcesWithExtension: "png", subdirectory: "\(root)/\(folder)"),
               let first = urls.first {
                return first.deletingLastPathComponent()
            }
        }
        return nil
    }

    private static func makeFallback(_ part: SeaBasinPart) -> NSImage {
        let color: NSColor
        switch part {
        case .bottom: color = NSColor(red: 0.45, green: 0.55, blue: 0.36, alpha: 1)
        case .wall: color = NSColor(red: 0.55, green: 0.48, blue: 0.36, alpha: 1)
        case .coast: color = NSColor(red: 0.82, green: 0.72, blue: 0.50, alpha: 1)
        }
        let img = NSImage(size: NSSize(width: 64, height: 64))
        img.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
        img.unlockFocus()
        return img
    }

    static func applyPBR(to mat: SCNMaterial, part: SeaBasinPart) {
        let maps = pbr(for: part)
        mat.lightingModel = .physicallyBased
        mat.isDoubleSided = true
        mat.diffuse.contents = maps.color ?? makeFallback(part)
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 1, 1)
        if let n = maps.normal {
            mat.normal.contents = n
            mat.normal.wrapS = .repeat
            mat.normal.wrapT = .repeat
            // Jači relief iz iste NormalGL mape.
            mat.normal.intensity = 1.75
        }
        if let r = maps.roughness {
            mat.roughness.contents = r
            mat.roughness.wrapS = .repeat
            mat.roughness.wrapT = .repeat
            // Pojačana hrapavost (manje sjaja / mramornog izgleda).
            mat.roughness.intensity = 1.55
        } else {
            mat.roughness.contents = NSColor(white: 0.92, alpha: 1)
        }
        if let ao = maps.ambientOcclusion {
            mat.ambientOcclusion.contents = ao
            mat.ambientOcclusion.wrapS = .repeat
            mat.ambientOcclusion.wrapT = .repeat
            mat.ambientOcclusion.intensity = 1.15
        }
        mat.metalness.contents = NSColor.black
        mat.specular.contents = NSColor(white: 0.12, alpha: 1)
    }

    private static var displacementRepCache: [ObjectIdentifier: NSBitmapImageRep] = [:]

    /// Uzorkovanje displacement mape u [0,1] (sivi kanal). Bitmap se kešira.
    static func sampleDisplacement(_ image: NSImage?, u: CGFloat, v: CGFloat) -> CGFloat {
        guard let image else { return 0.5 }
        let id = ObjectIdentifier(image)
        let rep: NSBitmapImageRep
        if let cached = displacementRepCache[id] {
            rep = cached
        } else if let tiff = image.tiffRepresentation,
                  let fresh = NSBitmapImageRep(data: tiff) {
            displacementRepCache[id] = fresh
            rep = fresh
        } else {
            return 0.5
        }
        let w = max(rep.pixelsWide, 1)
        let h = max(rep.pixelsHigh, 1)
        let fu = u - floor(u)
        let fv = v - floor(v)
        let x = min(max(Int(fu * CGFloat(w)), 0), w - 1)
        let y = min(max(Int((1 - fv) * CGFloat(h)), 0), h - 1)
        guard let color = rep.colorAt(x: x, y: y) else { return 0.5 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r + g + b) / 3
    }

    static func clearCache() {
        lock.lock()
        cache.removeAll()
        displacementRepCache.removeAll()
        lock.unlock()
    }
}

enum SeaBasin {
    static func isSea(_ gameMap: GameMap, row: Int, col: Int) -> Bool {
        gameMap.cell(row: row, col: col)?.povrsina == .more
    }

    /// Gušće ponavljanje → više detalja iz iste Rock035 mape.
    private static let textureMetersPerRepeat: CGFloat = 3.2
    /// Blagi UV rot da se uzorak ne poravna s mrežom ćelija.
    private static let textureUVAngle: CGFloat = 0.37
    /// Amplituda geometrijskog reliefa (metri) — samo šum (bez sporog CPU samplinga teksture).
    private static let displacementAmplitude: CGFloat = 0.14
    /// Podjela ćelije za dno / zidove (2 = brzo; dovoljno uz normal mape).
    private static let rockSubdiv = 2

    /// World-space UV (kontinuirano preko cijelog mora, ne 0–1 po ćeliji).
    private static func worldUV(x: CGFloat, z: CGFloat, height: CGFloat = 0) -> CGPoint {
        let ca = cos(textureUVAngle), sa = sin(textureUVAngle)
        let xr = x * ca - z * sa
        let zr = x * sa + z * ca
        // Visina ulazi malo u V da zidovi i dno ne budu isti uzorak na spoju.
        let s = textureMetersPerRepeat
        return CGPoint(x: xr / s, y: (zr + height * 0.35) / s)
    }

    /// Pseudo-random [0,1] za lokalni šum na stilu.
    private static func hash01(_ x: CGFloat, _ z: CGFloat) -> CGFloat {
        let n = sin(Double(x) * 127.1 + Double(z) * 311.7) * 43758.5453
        return CGFloat(n - floor(n))
    }

    private static func rockNoise(_ x: CGFloat, _ z: CGFloat) -> CGFloat {
        let n1 = hash01(x * 0.85, z * 0.85)
        let n2 = hash01(x * 2.1 + 3.1, z * 2.1 - 1.7)
        let n3 = hash01(x * 4.4 - 2.2, z * 4.4 + 0.9)
        return n1 * 0.55 + n2 * 0.3 + n3 * 0.15
    }

    /// wall + bottom (ista tekstura). Coast isključen dok ne smeta slaganju mora.
    static func makeNode(gameMap: GameMap) -> SCNNode? {
        let rows = gameMap.rows
        let cols = gameMap.cols
        guard rows > 0, cols > 0 else { return nil }

        let depth = UndergroundTerrain.filledHeight
        let halfW = MapScale.worldWidth(cols: cols) / 2
        let halfH = MapScale.worldHeight(rows: rows) / 2
        let step = MapScale.worldUnitsPerMapCell

        // Jedna kontinuirana mreža: dijeljeni vrhovi na rubovima ćelija (nema šavova/pločica).
        var floorKeyToIndex: [String: Int32] = [:]
        var floorVerts: [SCNVector3] = []
        var floorUV: [CGPoint] = []
        var floorIdx: [Int32] = []
        var waterKeyToIndex: [String: Int32] = [:]
        var waterVerts: [SCNVector3] = []
        var waterUV: [CGPoint] = []
        var waterIdx: [Int32] = []
        var wallVerts: [SCNVector3] = []
        var wallUV: [CGPoint] = []
        var wallIdx: [Int32] = []

        /// Površina vode malo ispod ruba korita (ispunjava otvor).
        let waterHeight: CGFloat = -0.05
        /// Metal valovi; 3 quada po ćeliji = dovoljno brzo za map editor.
        let waterSubdiv = 3
        let rockN = rockSubdiv

        func floorDisplace(x: CGFloat, z: CGFloat) -> CGFloat {
            let n = rockNoise(x, z)
            return (n - 0.5) * displacementAmplitude
        }

        func floorVertex(x: CGFloat, z: CGFloat) -> Int32 {
            let key = String(format: "%.4f_%.4f", Double(x), Double(z))
            if let i = floorKeyToIndex[key] { return i }
            let i = Int32(floorVerts.count)
            floorKeyToIndex[key] = i
            let h = -depth + floorDisplace(x: x, z: z)
            floorVerts.append(SCNVector3(x, -z, h))
            floorUV.append(worldUV(x: x, z: z, height: -depth))
            return i
        }

        func waterVertex(x: CGFloat, z: CGFloat) -> Int32 {
            let key = String(format: "%.3f_%.3f", Double(x), Double(z))
            if let i = waterKeyToIndex[key] { return i }
            let i = Int32(waterVerts.count)
            waterKeyToIndex[key] = i
            waterVerts.append(SCNVector3(x, -z, waterHeight))
            waterUV.append(worldUV(x: x, z: z, height: waterHeight))
            return i
        }

        func addFloorCell(x0: CGFloat, x1: CGFloat, z0: CGFloat, z1: CGFloat) {
            for i in 0..<rockN {
                for j in 0..<rockN {
                    let fx0 = CGFloat(i) / CGFloat(rockN)
                    let fx1 = CGFloat(i + 1) / CGFloat(rockN)
                    let fz0 = CGFloat(j) / CGFloat(rockN)
                    let fz1 = CGFloat(j + 1) / CGFloat(rockN)
                    let xa = x0 + (x1 - x0) * fx0
                    let xb = x0 + (x1 - x0) * fx1
                    let za = z0 + (z1 - z0) * fz0
                    let zb = z0 + (z1 - z0) * fz1
                    let a = floorVertex(x: xa, z: za)
                    let b = floorVertex(x: xb, z: za)
                    let c = floorVertex(x: xb, z: zb)
                    let d = floorVertex(x: xa, z: zb)
                    // Winding prema gore (+z).
                    floorIdx.append(contentsOf: [a, d, c, a, c, b])
                }
            }
        }

        func addWaterCell(x0: CGFloat, x1: CGFloat, z0: CGFloat, z1: CGFloat) {
            let n = waterSubdiv
            for i in 0..<n {
                for j in 0..<n {
                    let fx0 = CGFloat(i) / CGFloat(n)
                    let fx1 = CGFloat(i + 1) / CGFloat(n)
                    let fz0 = CGFloat(j) / CGFloat(n)
                    let fz1 = CGFloat(j + 1) / CGFloat(n)
                    let xa = x0 + (x1 - x0) * fx0
                    let xb = x0 + (x1 - x0) * fx1
                    let za = z0 + (z1 - z0) * fz0
                    let zb = z0 + (z1 - z0) * fz1
                    let a = waterVertex(x: xa, z: za)
                    let b = waterVertex(x: xb, z: za)
                    let c = waterVertex(x: xb, z: zb)
                    let d = waterVertex(x: xa, z: zb)
                    // Winding prema gore (+z) — inače Metal cull može sakriti površinu.
                    waterIdx.append(contentsOf: [a, d, c, a, c, b])
                }
            }
        }

        /// Zid s podjelom + šum prema unutra (brzo; detalj dolazi iz Normal mape).
        func addInwardWall(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat, inwardX: CGFloat, inwardY: CGFloat) {
            let len = hypot(x1 - x0, y1 - y0)
            let segsU = max(rockN, Int(ceil(Double(len / max(step / CGFloat(rockN), 0.01)))))
            let segsV = max(2, Int(ceil(Double(depth / 1.2))))
            let nx = inwardX, ny = inwardY
            for iu in 0..<segsU {
                for iv in 0..<segsV {
                    let u0 = CGFloat(iu) / CGFloat(segsU)
                    let u1 = CGFloat(iu + 1) / CGFloat(segsU)
                    let v0 = CGFloat(iv) / CGFloat(segsV)
                    let v1 = CGFloat(iv + 1) / CGFloat(segsV)
                    func corner(_ u: CGFloat, _ v: CGFloat) -> (SCNVector3, CGPoint) {
                        let x = x0 + (x1 - x0) * u
                        let y = y0 + (y1 - y0) * u
                        let h = -depth + depth * v
                        let mapZ = -y
                        let n = rockNoise(x * 1.3 + h, mapZ * 1.3 - h)
                        let push = (n - 0.5) * displacementAmplitude
                        return (SCNVector3(x + nx * push, y + ny * push, h), worldUV(x: x, z: mapZ, height: h))
                    }
                    let (p00, uv00) = corner(u0, v0)
                    let (p10, uv10) = corner(u1, v0)
                    let (p11, uv11) = corner(u1, v1)
                    let (p01, uv01) = corner(u0, v1)
                    let b = Int32(wallVerts.count)
                    wallVerts.append(contentsOf: [p00, p10, p11, p01])
                    wallUV.append(contentsOf: [uv00, uv10, uv11, uv01])
                    wallIdx.append(contentsOf: [b, b + 1, b + 2, b, b + 2, b + 3])
                }
            }
        }

        /// World XZ iz ćelijskih grid-linija (isti prostor kao editor linije).
        func worldXZ(row: CGFloat, col: CGFloat) -> (x: CGFloat, z: CGFloat) {
            (-halfW + col * step, -halfH + row * step)
        }

        /// More iz polygona editora — prati linije, ne kocke ćelija.
        func addPolygonBasin(_ shape: SeaPolygonShape) {
            let verts = shape.vertices
            guard verts.count >= 3 else { return }
            var pts: [(x: CGFloat, z: CGFloat)] = verts.map { worldXZ(row: $0.row, col: $0.col) }
            var cx: CGFloat = 0, cz: CGFloat = 0
            for p in pts { cx += p.x; cz += p.z }
            let inv = 1 / CGFloat(pts.count)
            cx *= inv; cz *= inv

            // Voda + dno: fan od središta; rubovi podijeljeni za Metal valove.
            let edgeSubdiv = max(waterSubdiv, 4)
            var ring: [(x: CGFloat, z: CGFloat)] = []
            for i in 0..<pts.count {
                let a = pts[i]
                let b = pts[(i + 1) % pts.count]
                for s in 0..<edgeSubdiv {
                    let t = CGFloat(s) / CGFloat(edgeSubdiv)
                    ring.append((a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t))
                }
            }
            let centerW = waterVertex(x: cx, z: cz)
            let centerF = floorVertex(x: cx, z: cz)
            var ringW: [Int32] = []
            var ringF: [Int32] = []
            ringW.reserveCapacity(ring.count)
            ringF.reserveCapacity(ring.count)
            for p in ring {
                ringW.append(waterVertex(x: p.x, z: p.z))
                ringF.append(floorVertex(x: p.x, z: p.z))
            }
            for i in 0..<ring.count {
                let j = (i + 1) % ring.count
                waterIdx.append(contentsOf: [centerW, ringW[i], ringW[j]])
                floorIdx.append(contentsOf: [centerF, ringF[j], ringF[i]])
            }

            // Zidovi duž editor linija (CW poligon → inward = rotacija 90° CCW u XZ).
            for i in 0..<pts.count {
                let a = pts[i]
                let b = pts[(i + 1) % pts.count]
                let dx = b.x - a.x
                let dz = b.z - a.z
                let len = hypot(dx, dz)
                guard len > 0.01 else { continue }
                let inx = -dz / len
                let inz = dx / len
                // SceneKit: y = -mapZ → inwardY = -inz
                addInwardWall(
                    x0: a.x, y0: -a.z,
                    x1: b.x, y1: -b.z,
                    inwardX: inx, inwardY: -inz
                )
            }
        }

        var anySea = false
        if !gameMap.seaPolygons.isEmpty {
            for shape in gameMap.seaPolygons where shape.vertices.count >= 3 {
                anySea = true
                addPolygonBasin(shape)
            }
        } else {
            // Fallback: stare mape bez polygona — kocke po ćelijama.
            for r in 0..<rows {
                for c in 0..<cols {
                    guard isSea(gameMap, row: r, col: c) else { continue }
                    anySea = true
                    let x0 = -halfW + CGFloat(c) * step
                    let x1 = -halfW + CGFloat(c + 1) * step
                    let z0 = -halfH + CGFloat(r) * step
                    let z1 = -halfH + CGFloat(r + 1) * step
                    addFloorCell(x0: x0, x1: x1, z0: z0, z1: z1)
                    addWaterCell(x0: x0, x1: x1, z0: z0, z1: z1)
                    if !(gameMap.isValid(MapCoordinate(row: r - 1, col: c)) && isSea(gameMap, row: r - 1, col: c)) {
                        addInwardWall(x0: x0, y0: -z0, x1: x1, y1: -z0, inwardX: 0, inwardY: -1)
                    }
                    if !(gameMap.isValid(MapCoordinate(row: r + 1, col: c)) && isSea(gameMap, row: r + 1, col: c)) {
                        addInwardWall(x0: x1, y0: -z1, x1: x0, y1: -z1, inwardX: 0, inwardY: 1)
                    }
                    if !(gameMap.isValid(MapCoordinate(row: r, col: c - 1)) && isSea(gameMap, row: r, col: c - 1)) {
                        addInwardWall(x0: x0, y0: -z0, x1: x0, y1: -z1, inwardX: 1, inwardY: 0)
                    }
                    if !(gameMap.isValid(MapCoordinate(row: r, col: c + 1)) && isSea(gameMap, row: r, col: c + 1)) {
                        addInwardWall(x0: x1, y0: -z1, x1: x1, y1: -z0, inwardX: -1, inwardY: 0)
                    }
                }
            }
        }
        guard anySea else { return nil }

        func makeNormals(vertices: [SCNVector3], indices: [Int32]) -> [SCNVector3] {
            var acc = Array(repeating: SCNVector3(0, 0, 0), count: vertices.count)
            for i in stride(from: 0, to: indices.count, by: 3) {
                let ia = Int(indices[i]), ib = Int(indices[i + 1]), ic = Int(indices[i + 2])
                let a = vertices[ia], b = vertices[ib], c = vertices[ic]
                let e1 = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
                let e2 = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
                let nx = e1.y * e2.z - e1.z * e2.y
                let ny = e1.z * e2.x - e1.x * e2.z
                let nz = e1.x * e2.y - e1.y * e2.x
                acc[ia].x += nx; acc[ia].y += ny; acc[ia].z += nz
                acc[ib].x += nx; acc[ib].y += ny; acc[ib].z += nz
                acc[ic].x += nx; acc[ic].y += ny; acc[ic].z += nz
            }
            return acc.map { n in
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                guard len > 1e-6 else { return SCNVector3(0, 0, 1) }
                return SCNVector3(n.x / len, n.y / len, n.z / len)
            }
        }

        func makeGeo(vertices: [SCNVector3], uvs: [CGPoint], indices: [Int32], upwardFallback: Bool) -> SCNGeometry {
            let normals: [SCNVector3]
            if upwardFallback {
                normals = vertices.map { _ in SCNVector3(0, 0, 1) }
            } else {
                normals = makeNormals(vertices: vertices, indices: indices)
            }
            let uvData = uvs.map { [Float($0.x), Float($0.y)] }.flatMap { $0 }
            let uvSource = SCNGeometrySource(
                data: Data(bytes: uvData, count: uvData.count * MemoryLayout<Float>.size),
                semantic: .texcoord,
                vectorCount: uvs.count,
                usesFloatComponents: true,
                componentsPerVector: 2,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<Float>.size * 2
            )
            return SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: vertices),
                    SCNGeometrySource(normals: normals),
                    uvSource
                ],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
        }

        let root = SCNNode()
        root.name = "seaBasin"

        // Dno: ista Rock035 tekstura, s geometrijskim reliefom.
        if !floorIdx.isEmpty {
            let floorMat = SCNMaterial()
            SeaBasinTextures.applyPBR(to: floorMat, part: .wall)
            let geo = makeGeo(vertices: floorVerts, uvs: floorUV, indices: floorIdx, upwardFallback: false)
            geo.materials = [floorMat]
            let n = SCNNode(geometry: geo)
            n.name = "seaBasinFloor"
            n.categoryBitMask = 1
            root.addChildNode(n)
        }

        if !wallIdx.isEmpty {
            let wallMat = SCNMaterial()
            SeaBasinTextures.applyPBR(to: wallMat, part: .wall)
            let geo = makeGeo(vertices: wallVerts, uvs: wallUV, indices: wallIdx, upwardFallback: false)
            geo.materials = [wallMat]
            let n = SCNNode(geometry: geo)
            n.name = "seaBasinWalls"
            n.categoryBitMask = 1
            root.addChildNode(n)
        }

        // Površina vode: Metal (plava + valovi). Bez depth-write da se vidi korito.
        if !waterIdx.isEmpty {
            let waterMat = SCNMaterial()
            RiverWaterShader.applySeaSurface(to: waterMat)
            let geo = makeGeo(vertices: waterVerts, uvs: waterUV, indices: waterIdx, upwardFallback: true)
            geo.materials = [waterMat]
            let n = SCNNode(geometry: geo)
            n.name = "seaBasinWater"
            n.categoryBitMask = 1
            n.renderingOrder = 50
            n.castsShadow = false
            root.addChildNode(n)
        }

        root.categoryBitMask = 1
        root.renderingOrder = -99
        return root.childNodes.isEmpty ? nil : root
    }

    static func attach(to terrain: SCNNode, gameMap: GameMap) {
        terrain.childNode(withName: "seaBasin", recursively: false)?.removeFromParentNode()
        guard let basin = makeNode(gameMap: gameMap) else { return }
        terrain.addChildNode(basin)
    }
}
