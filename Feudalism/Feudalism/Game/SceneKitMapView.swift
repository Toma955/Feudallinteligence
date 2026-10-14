//
//  SceneKitMapView.swift
//  Feudalism
//
//  Zamjenjuje GameView+GameScene: prikaz mape preko SceneKit (prava 3D kamera, hitTest, bez skewa).
//

import SwiftUI
import SceneKit
import SpriteKit
import AppKit
import CoreGraphics

/// World veličine mape iz MapScale (1 ćelija = 1 metar).
private var worldUnitsPerCell: CGFloat { MapScale.worldUnitsPerMapCell }
private func effectiveMapWorldW(cols: Int) -> CGFloat { MapScale.worldWidth(cols: cols) }
private func effectiveMapWorldH(rows: Int) -> CGFloat { MapScale.worldHeight(rows: rows) }

// MARK: - Pravila mreže (samo prikaz – koji grid crtati)
/// Mreža 40×40 = linija svakih 40 m. Mreža 10×10 = linija svakih 10 m. Ćelija za gradnju ostaje 1 m.

/// Broj podjela za mrežu „40×40” (linija svakih 40 metara).
private func gridDivisionsBuilding(rows: Int, cols: Int) -> Int {
    max(1, Int((CGFloat(cols) * MapScale.worldUnitsPerMapCell / MapScale.gridStep40Meters).rounded()))
}

/// Broj podjela za mrežu „10×10” (linija svakih 10 metara).
private func gridDivisionsDisplay(rows: Int, cols: Int) -> Int {
    max(1, Int((CGFloat(cols) * MapScale.worldUnitsPerMapCell / MapScale.gridStep10Meters).rounded()))
}

/// Razina mreže i tla – ispod y=0 se ništa ne gradi i ne smiju biti objekti.
private let groundLevelY: CGFloat = 0

// MARK: - Terrain texture (procedural, isto kao SpriteKit)
/// Pozadina mape: tamnija siva. Fallback boja terena kad tekstura nije dostupna.
private let terrainFallbackColor = NSColor(white: 0.42, alpha: 1)
private let placementDebugLogs = true
private func placementDebug(_ msg: String) {
    guard placementDebugLogs else { return }
    placementDebugLog(msg)
}

/// Piksela po logičkoj ćeliji – veće = oštrija tekstura (max 24). Za velike mape smanjujemo da CGContext ne padne.
private let terrainTextureScaleBase = 24
/// Maksimalna stranica composite slike da ne alociramo previše (npr. 200×24 = 4800 → preveliko).
private let terrainTextureMaxSide = 2048

private func terrainTextureScale(rows: Int, cols: Int) -> Int {
    let side = max(rows, cols, 1)
    let scale = terrainTextureScaleBase
    if side * scale <= terrainTextureMaxSide { return scale }
    return max(1, terrainTextureMaxSide / side)
}

/// Proceduralna tekstura (siva pozadina). Koristi capped scale za velike mape.
private func makeTerrainCGImage(rows: Int? = nil, cols: Int? = nil) -> CGImage? {
    let c = cols ?? 200
    let r = rows ?? 200
    let scale = terrainTextureScale(rows: r, cols: c)
    let w = c * scale
    let h = r * scale
    guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                             space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let gray: CGFloat = 0.42
    ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

/// Gradi teksturu terena iz GameMap: svaka ćelija dobiva tile prema cell.povrsina (katalog map_textures).
private func makeTerrainCGImage(gameMap: GameMap, tileImages: [PovrsinaType: CGImage]) -> CGImage? {
    let rows = gameMap.rows
    let cols = gameMap.cols
    let scale = terrainTextureScale(rows: rows, cols: cols)
    let w = cols * scale
    let h = rows * scale
    guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                             space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let gray: CGFloat = 0.42
    let fallbackColor = (gray, gray, gray)
    EarthTiles.paint(in: ctx, rows: rows, cols: cols, scale: scale, tiles: EarthTiles.images)
    for row in 0..<rows {
        for col in 0..<cols {
            let surface = gameMap.cell(row: row, col: col)?.povrsina ?? .default
            if surface == .tlo { continue }
            let y = rows - 1 - row
            let rect = CGRect(x: col * scale, y: y * scale, width: scale, height: scale)
            if let tile = tileImages[surface] {
                ctx.draw(tile, in: rect)
            } else {
                ctx.setFillColor(red: fallbackColor.0, green: fallbackColor.1, blue: fallbackColor.2, alpha: 1)
                ctx.fill(rect)
            }
        }
    }
    return ctx.makeImage()
}

/// Tekstura terena: kao Wall – NSImage za diffuse. Composite iz tilea; za velike mape scale je ograničen da ne padne.
private func makeTerrainTexture(gameMap: GameMap? = nil, useWhiteBackground: Bool = false) -> Any? {
    if useWhiteBackground {
        let rows = gameMap?.rows ?? 200
        let cols = gameMap?.cols ?? 200
        guard let cg = makeTerrainCGImage(rows: rows, cols: cols) else { return terrainFallbackColor }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    let tiles = MapTextureLoader.shared.tileImages(bundle: .main)
    if let map = gameMap, map.rows > 0, map.cols > 0 {
        if let cg = makeTerrainCGImage(gameMap: map, tileImages: tiles) {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        /// Ako composite nije uspio (npr. memorija), ispuni tilanjem poluplodne zemlje da ne ostane siva.
        if let groundTile = tiles[.tlo], let cg = makeTiledGroundImage(tile: groundTile, size: terrainTextureMaxSide) {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }
    let rows = gameMap?.rows ?? 200
    let cols = gameMap?.cols ?? 200
    guard let cg = makeTerrainCGImage(rows: rows, cols: cols) else { return terrainFallbackColor }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

/// Ispuni kvadratnu sliku ponavljanjem jednog tilea (fallback kad composite prevelike mape padne).
private func makeTiledGroundImage(tile: CGImage, size: Int) -> CGImage? {
    let tw = tile.width
    let th = tile.height
    guard tw > 0, th > 0, size > 0, size <= 2048 else { return nil }
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    for y in stride(from: 0, to: size, by: th) {
        for x in stride(from: 0, to: size, by: tw) {
            ctx.draw(tile, in: CGRect(x: x, y: y, width: tw, height: th))
        }
    }
    return ctx.makeImage()
}

/// Orijentacija terena: ravnina u XZ (width = X, height = Z), usklađeno s mrežom za crtanje objekata.
private let terrainPlaneRotationX: CGFloat = -.pi / 2

/// Boja bočnih strana i donje plohe podignutih kocki (bijela).
private let terrainSideColor = NSColor.white

/// Brzi checksum visina terena – da se mesh ne gradi svaki frame, samo kad se elevacija promijeni (ćelije + vertex visine).
private func terrainHeightsChecksum(gameMap: GameMap) -> Double {
    var sum: Double = 0
    for cell in gameMap.cells.values {
        sum += Double(cell.height)
        if let center = cell.center { sum += Double(center.height * 3 + center.dx * 7 + center.dz * 11) }
    }
    for (_, h) in gameMap.vertexHeights { sum += Double(h) }
    for (_, o) in gameMap.vertexOffsets { sum += Double(o.x * 13 + o.y * 17) }
    return sum
}

/// Mesh terena: gornja ploča po ćeliji (4 vrha po ćeliji – vertex visine). Svaka ćelija ima UV 0–1 da dobije jednu tilabilnu ground teksturu.
private func makeTerrainGeometryWithHeights(gameMap: GameMap) -> SCNGeometry? {
    let rows = gameMap.rows
    let cols = gameMap.cols
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let stepW = worldUnitsPerCell
    let stepH = worldUnitsPerCell
    let baseZ: CGFloat = 0
    var vertices: [SCNVector3] = []
    var uvs: [CGPoint] = []
    var colors: [Float] = []
    var topIndices: [Int32] = []
    let coveredByFloors = cellsCoveredByBuildingFloors(gameMap)
    for r in 0..<rows {
        for c in 0..<cols {
            // More: rupa u gornjoj plohi — korito + voda dolaze iz SeaBasin.
            if gameMap.cell(row: r, col: c)?.povrsina == .more { continue }
            let surface = gameMap.surface(row: r, col: c)
            let tint = terrainPadTint(gameMap.cell(row: r, col: c), gameMap: gameMap, row: r, col: c, covered: coveredByFloors)
            let base = Int32(vertices.count)
            for point in surface.allPoints {
                let x = -halfW + point.x * stepW
                let z = -halfH + point.z * stepH
                vertices.append(SCNVector3(x, -z, point.height))
                let mapW = CGFloat(cols) * stepW
                let mapH = CGFloat(rows) * stepH
                uvs.append(CGPoint(x: (x + halfW) / mapW, y: (z + halfH) / mapH))
                colors.append(contentsOf: tint)
            }
            let center = base + 4
            topIndices.append(contentsOf: [
                base, base + 1, center,
                base + 1, base + 2, center,
                base + 2, base + 3, center,
                base + 3, base, center
            ])
        }
    }
    // Nema gornje plohe (samo more / prazno) — SeaBasin drži korito.
    if topIndices.isEmpty {
        if vertices.isEmpty {
            vertices.append(SCNVector3(0, 0, 0))
            uvs.append(.zero)
            colors.append(contentsOf: [1, 1, 1] as [Float])
        }
        topIndices.append(contentsOf: [0, 0, 0])
    }
    func triNormal(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> SCNVector3 {
        let e1 = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let e2 = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        let nx = e1.y * e2.z - e1.z * e2.y
        let ny = e1.z * e2.x - e1.x * e2.z
        let nz = e1.x * e2.y - e1.y * e2.x
        let len = sqrt(nx * nx + ny * ny + nz * nz)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(nx / len, ny / len, nz / len)
    }
    var normals: [SCNVector3] = Array(repeating: SCNVector3(0, 0, 0), count: vertices.count)
    for i in stride(from: 0, to: topIndices.count, by: 3) {
        let ia = Int(topIndices[i]), ib = Int(topIndices[i + 1]), ic = Int(topIndices[i + 2])
        let n = triNormal(vertices[ia], vertices[ib], vertices[ic])
        normals[ia].x += n.x; normals[ia].y += n.y; normals[ia].z += n.z
        normals[ib].x += n.x; normals[ib].y += n.y; normals[ib].z += n.z
        normals[ic].x += n.x; normals[ic].y += n.y; normals[ic].z += n.z
    }
    var sideBottomIndices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let h00 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c)
            let h01 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c + 1)
            let h10 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c)
            let h11 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c + 1)
            let maxH = max(h00, h01, h10, h11)
            guard maxH > 0 else { continue }
            let x0 = -halfW + CGFloat(c) * stepW
            let x1 = -halfW + CGFloat(c + 1) * stepW
            let z0 = -halfH + CGFloat(r) * stepH
            let z1 = -halfH + CGFloat(r + 1) * stepH
            func addQuad(_ v: [SCNVector3], _ n: SCNVector3, winding: [Int]) {
                let b = Int32(vertices.count)
                vertices.append(contentsOf: v)
                for _ in 0..<4 { normals.append(n); colors.append(contentsOf: [1, 1, 1]) }
                uvs.append(CGPoint(x: 0, y: 0))
                uvs.append(CGPoint(x: 1, y: 0))
                uvs.append(CGPoint(x: 1, y: 1))
                uvs.append(CGPoint(x: 0, y: 1))
                sideBottomIndices.append(contentsOf: [b + Int32(winding[0]), b + Int32(winding[1]), b + Int32(winding[2]), b + Int32(winding[0]), b + Int32(winding[2]), b + Int32(winding[3])])
            }
            // Donja ploča (z = baseZ), normala (0,0,-1)
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x0, -z1, baseZ)], SCNVector3(0, 0, -1), winding: [0, 2, 1, 3])
            // 4 bočne strane (gornji rub po vertex visinama)
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z0, h01), SCNVector3(x0, -z0, h00)], SCNVector3(0, -1, 0), winding: [0, 1, 2, 3])
            addQuad([SCNVector3(x0, -z1, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x1, -z1, h11), SCNVector3(x0, -z1, h10)], SCNVector3(0, 1, 0), winding: [0, 2, 1, 3])
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x0, -z1, baseZ), SCNVector3(x0, -z1, h10), SCNVector3(x0, -z0, h00)], SCNVector3(-1, 0, 0), winding: [0, 2, 1, 3])
            addQuad([SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x1, -z1, h11), SCNVector3(x1, -z0, h01)], SCNVector3(1, 0, 0), winding: [0, 1, 2, 3])
        }
    }
    let normalsN = normals.map { n -> SCNVector3 in
        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(n.x / len, n.y / len, n.z / len)
    }
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normalsN)
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
    let colorSource = SCNGeometrySource(
        data: colors.withUnsafeBufferPointer { Data(buffer: $0) },
        semantic: .color,
        vectorCount: colors.count / 3,
        usesFloatComponents: true,
        componentsPerVector: 3,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 3
    )
    let topElement = SCNGeometryElement(indices: topIndices, primitiveType: .triangles)
    let elements: [SCNGeometryElement] = sideBottomIndices.isEmpty ? [topElement] : [topElement, SCNGeometryElement(indices: sideBottomIndices, primitiveType: .triangles)]
    return SCNGeometry(sources: [vertexSource, normalSource, uvSource, colorSource], elements: elements)
}

/// Boja ploče na terenu: bijelo = obična trava, inače podloga ostaje vidljiva.
/// Pod građevine prekriva podlogu — tu teren ostaje neutralan.
private func terrainPadTint(_ cell: MapCell?, gameMap: GameMap, row: Int, col: Int, covered: Set<MapCoordinate> = []) -> [Float] {
    if covered.contains(MapCoordinate(row: row, col: col)) { return [1, 1, 1] }
    guard let cell, let pad = buildPadOverlayColor(cell, row: row, col: col) else { return [1, 1, 1] }
    return [0.22 + pad[0] * 0.78, 0.22 + pad[1] * 0.78, 0.22 + pad[2] * 0.78]
}

/// Transformacija teksture: okreni V da se slika terena (row 0 na dnu) uskladi s world Z (row 0 = min Z).
private func terrainTextureFlipVTransform() -> SCNMatrix4 {
    var t = SCNMatrix4MakeTranslation(0, 1, 0)
    let s = SCNMatrix4MakeScale(1, -1, 1)
    return SCNMatrix4Mult(t, s)
}

/// Jedno ponavljanje zemlje na 4 m. Kamera je na 40 m, 10 m i oko 6 m; na 10 m se tekstura slije u jednu boju.
private let terrainMetersPerRepeat: CGFloat = 4
/// Stari spremljeni teren ima UV podijeljen s 10 m. Ovim se dovede na isti korak od 4 m.
private let terrainCachedMetersPerRepeat: CGFloat = 10

/// Postavi PBR na materijal gornje plohe terena: diffuse + normal + roughness, kao Wall.
private func applyTerrainPBR(to mat: SCNMaterial, diffuseContents: Any?) {
    mat.diffuse.contents = diffuseContents
    mat.diffuse.contentsTransform = terrainTextureFlipVTransform()
    mat.diffuse.wrapS = .clamp
    mat.diffuse.wrapT = .clamp
    mat.ambient.contents = NSColor.white
    mat.specular.contents = NSColor.darkGray
    mat.isDoubleSided = true
    mat.lightingModel = .physicallyBased
    if let normalCG = TerrainTextureLoader.shared.groundNormalImage(bundle: .main) {
        let normalImg = NSImage(cgImage: normalCG, size: NSSize(width: normalCG.width, height: normalCG.height))
        mat.normal.contents = normalImg
        mat.normal.intensity = 1.0
        mat.normal.wrapS = .repeat
        mat.normal.wrapT = .repeat
        mat.normal.contentsTransform = SCNMatrix4MakeScale(1, -1, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.normal.contentsTransform = SCNMatrix4Mult(tr, mat.normal.contentsTransform)
    }
    if let roughCG = TerrainTextureLoader.shared.groundRoughnessImage(bundle: .main) {
        let roughImg = NSImage(cgImage: roughCG, size: NSSize(width: roughCG.width, height: roughCG.height))
        mat.roughness.contents = roughImg
        mat.roughness.wrapS = .repeat
        mat.roughness.wrapT = .repeat
        mat.roughness.contentsTransform = SCNMatrix4MakeScale(1, -1, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.roughness.contentsTransform = SCNMatrix4Mult(tr, mat.roughness.contentsTransform)
    }
}

/// Gola zemlja je jedan sloj. Shader miješa tri teksture po pikselu.
private func applyTerrainPBRTiled(to mat: SCNMaterial, gameMap: GameMap? = nil) {
    if let gameMap {
        EarthGroundMaterial.applyTerrain(mat, map: gameMap)
        return
    }
    EarthGroundMaterial.applyPreview(mat)
}

/// Ravnina terena kao mreža kvadova: jedan quad po ćeliji, UV 0–1 po ćeliji da svaka kocka ima svoju ground teksturu.
private func makeProceduralTerrainGrid(rows: Int, cols: Int) -> SCNGeometry? {
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let stepW = worldUnitsPerCell
    let stepH = worldUnitsPerCell
    var vertices: [SCNVector3] = []
    var uvs: [CGPoint] = []
    var indices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let x0 = -halfW + CGFloat(c) * stepW
            let x1 = -halfW + CGFloat(c + 1) * stepW
            let z0 = -halfH + CGFloat(r) * stepH
            let z1 = -halfH + CGFloat(r + 1) * stepH
            let base = Int32(vertices.count)
            vertices.append(SCNVector3(x0, -z0, 0))
            vertices.append(SCNVector3(x1, -z0, 0))
            vertices.append(SCNVector3(x1, -z1, 0))
            vertices.append(SCNVector3(x0, -z1, 0))
            let u0 = CGFloat(c) / CGFloat(cols)
            let u1 = CGFloat(c + 1) / CGFloat(cols)
            let v0 = CGFloat(r) / CGFloat(rows)
            let v1 = CGFloat(r + 1) / CGFloat(rows)
            uvs.append(CGPoint(x: u0, y: v0))
            uvs.append(CGPoint(x: u1, y: v0))
            uvs.append(CGPoint(x: u1, y: v1))
            uvs.append(CGPoint(x: u0, y: v1))
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }
    }
    let normals = vertices.map { _ in SCNVector3(0, 0, 1) }
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normals)
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
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    return SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [element])
}

/// Teren iz spremljene mape: visine ćelija, ista orijentacija kao ravni teren.
private func makeHeightTerrainNode(gameMap: GameMap) -> SCNNode {
    let mat = SCNMaterial()
    applyTerrainPBRTiled(to: mat, gameMap: gameMap)
    let node = SCNNode()
    if let geo = makeTerrainGeometryWithHeights(gameMap: gameMap) {
        if geo.elements.count > 1 {
            let sideMat = SCNMaterial()
            sideMat.diffuse.contents = NSColor.white
            sideMat.ambient.contents = NSColor.white
            sideMat.specular.contents = NSColor.darkGray
            sideMat.isDoubleSided = true
            sideMat.lightingModel = .physicallyBased
            geo.materials = [mat, sideMat]
        } else {
            geo.materials = [mat]
        }
        node.geometry = geo
    }
    node.eulerAngles.x = terrainPlaneRotationX
    node.position = SCNVector3Zero
    node.name = "terrain"
    node.categoryBitMask = 1
    node.renderingOrder = -100
    SeaBasin.attach(to: node, gameMap: gameMap)
    return node
}

/// Proceduralni teren: mreža kvadova (jedan po ćeliji), svaka ćelija s ground teksturom (UV 0–1).
/// width/height u world jedinicama: cols×40, rows×40.
private func makeProceduralTerrainNode(width: CGFloat, height: CGFloat, terrainTexture: Any? = nil, gameMap: GameMap? = nil) -> SCNNode {
    let cols = max(1, Int(round(width / worldUnitsPerCell)))
    let rows = max(1, Int(round(height / worldUnitsPerCell)))
    let terrainMat = SCNMaterial()
    applyTerrainPBRTiled(to: terrainMat, gameMap: gameMap)
    if let gridGeo = makeProceduralTerrainGrid(rows: rows, cols: cols) {
        gridGeo.materials = [terrainMat]
        let planeNode = SCNNode(geometry: gridGeo)
        planeNode.eulerAngles.x = terrainPlaneRotationX
        planeNode.position = SCNVector3(0, 0, 0)
        planeNode.name = "terrain"
        planeNode.categoryBitMask = 1
        planeNode.renderingOrder = -100
        return planeNode
    }
    let plane = SCNPlane(width: width, height: height)
    plane.materials = [terrainMat]
    let planeNode = SCNNode(geometry: plane)
    planeNode.eulerAngles.x = terrainPlaneRotationX
    planeNode.position = SCNVector3(0, 0, 0)
    planeNode.name = "terrain"
    planeNode.categoryBitMask = 1
    planeNode.renderingOrder = -100
    return planeNode
}

/// Učitani teren iz .scn: orijentacija XZ, PBR tiled (jedna ground tekstura po ćeliji), redoslijed crtanja.
private func fixLoadedTerrainOrientationAndMaterial(_ root: SCNNode) {
    guard let terrain = findTerrainInHierarchy(root) else { return }
    terrain.eulerAngles.x = terrainPlaneRotationX
    terrain.eulerAngles.y = 0
    terrain.eulerAngles.z = 0
    terrain.renderingOrder = -100
    guard let geo = terrain.geometry, let mat = geo.materials.first else { return }
    applyTerrainPBRTiled(to: mat)
    let boost = terrainCachedMetersPerRepeat / terrainMetersPerRepeat
    let scale = SCNMatrix4MakeScale(boost, boost, 1)
    mat.diffuse.contentsTransform = SCNMatrix4Mult(mat.diffuse.contentsTransform, scale)
    if mat.normal.contents != nil {
        mat.normal.contentsTransform = SCNMatrix4Mult(mat.normal.contentsTransform, scale)
    }
}

/// Pomakne učitani teren tako da mu je sredina na world (0, 0), isto mjesto kao dvorac i kralj.
private func centerTerrainOnMapOrigin(_ root: SCNNode) {
    guard let terrain = findTerrainInHierarchy(root) else { return }
    let (minB, maxB) = terrain.boundingBox
    let center = SCNVector3(
        (minB.x + maxB.x) / 2,
        (minB.y + maxB.y) / 2,
        (minB.z + maxB.z) / 2
    )
    let worldCenter = terrain.convertPosition(center, to: root)
    root.position = SCNVector3(-worldCenter.x, root.position.y, -worldCenter.z)
}

private func findTerrainInHierarchy(_ node: SCNNode) -> SCNNode? {
    if node.name == "terrain" { return node }
    for child in node.childNodes {
        if let t = findTerrainInHierarchy(child) { return t }
    }
    return nil
}

private func isTerrainMaterialWhiteOrEmpty(_ contents: Any?) -> Bool {
    guard let c = contents else { return true }
    if let color = c as? NSColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.95 && g > 0.95 && b > 0.95
    }
    return false
}

/// Učita sliku za kursor iz Icons ili bundlea po imenu (bez ekstenzije).
private func loadCursorImage(named name: String) -> NSImage? {
    if let img = NSImage(named: name) { return img }
    for sub in ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons", nil] as [String?] {
        let url: URL? = sub != nil
            ? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: sub)
            : Bundle.main.url(forResource: name, withExtension: "png")
        if let url = url, let img = NSImage(contentsOf: url) { return img }
    }
    return nil
}

/// Veličina kursora u pikselima (ista za mač i buzdovan).
private let gameCursorSize: CGFloat = 32

/// Crtaj sliku u 32×32 s opcionalnom rotacijom 90° udesno; hot spot u centru.
private func makeCursorImage(from src: NSImage, rotate90Clockwise: Bool) -> NSCursor {
    guard src.isValid, src.size.width > 0, src.size.height > 0 else { return .arrow }
    let srcSize = src.size
    let scale = min(gameCursorSize / srcSize.width, gameCursorSize / srcSize.height)
    let scaledW = srcSize.width * scale
    let scaledH = srcSize.height * scale

    let out = NSImage(size: NSSize(width: gameCursorSize, height: gameCursorSize))
    out.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let ctx = NSGraphicsContext.current?.cgContext
    if rotate90Clockwise {
        ctx?.translateBy(x: gameCursorSize / 2, y: gameCursorSize / 2)
        ctx?.rotate(by: .pi / 2)
        ctx?.translateBy(x: -scaledW / 2, y: -scaledH / 2)
    } else {
        ctx?.translateBy(x: (gameCursorSize - scaledW) / 2, y: (gameCursorSize - scaledH) / 2)
    }
    src.draw(in: CGRect(x: 0, y: 0, width: scaledW, height: scaledH),
             from: CGRect(origin: .zero, size: srcSize),
             operation: .sourceOver,
             fraction: 1)
    out.unlockFocus()

    let hotSpot = NSPoint(x: gameCursorSize / 2, y: gameCursorSize / 2)
    return NSCursor(image: out, hotSpot: hotSpot)
}

/// Kursor mača: sword_mouse.png, 32×32, rotiran 90° udesno.
private func makeSwordCursor() -> NSCursor {
    guard let src = loadCursorImage(named: "sword_mouse") else { return .arrow }
    return makeCursorImage(from: src, rotate90Clockwise: true)
}

/// Kursor buzdovana: mace_mouse.png, iste dimenzije (32×32), bez rotacije.
private func makeMaceCursor() -> NSCursor {
    guard let src = loadCursorImage(named: "mace_mouse") else { return .arrow }
    return makeCursorImage(from: src, rotate90Clockwise: false)
}

// MARK: - NSView wrapper za SCNView (miš, tipke)
private final class SceneKitMapNSView: NSView {
    var scnView: SCNView?
    var onWillDetach: (() -> Void)?
    var onPanChange: ((CGPoint) -> Void)?
    /// Pomak kamere u metrima (world X, world Z) tako da polje ostane pod kursorom.
    var onPanLock: ((CGFloat, CGFloat) -> Void)?
    /// Poziva se kad se pokrene pan (klik u handPan ili povuci preko thresholda); argument = pozicija miša u viewu.
    var onPanStart: ((NSPoint) -> Void)?
    var onZoomDelta: ((CGFloat) -> Void)?
    var onRotationDelta: ((CGFloat) -> Void)?
    var onTiltDelta: ((CGFloat) -> Void)?
    /// Space: kosi ↔ odozgo (nacrt).
    var onToggleTopDown: (() -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var onWallLinePreview: (([(Int, Int)]) -> Void)?
    var onWallLineCommit: (([(Int, Int)]) -> Void)?

    /// Zaustavi crtanje prije nego SwiftUI zbriše pogled. Inače Metal padne pri povratku na izbornik.
    @objc func stopScene() {
        onWillDetach?()
        scnView?.delegate = nil
        scnView?.rendersContinuously = false
        scnView?.isPlaying = false
    }

    var isPanning = false
    var lastPanLocation: NSPoint = .zero
    var handPanMode = false
    var isEraseMode = false
    /// Map Editor – mod „Odabir ćelija”: klik označuje/uklanja ćeliju.
    var isCellSelectionMode = false
    /// Map Editor – alat Teren: click-drag označava pravokutnik za paint (more, podloge…).
    var isTerrainEditMode = false
    /// Pregled pravokutnika (r0,c0,r1,c1) dok se vuče.
    var onTerrainPaintPreview: ((Int, Int, Int, Int) -> Void)?
    /// Primjena na pravokutnik pri mouseUp.
    var onTerrainPaintCommit: ((Int, Int, Int, Int) -> Void)?
    /// Uređivanje unutarnje crte mora: kontrolne točke aktivne.
    var seaHandleEditing = false
    /// Dimenzije mape za float ćelijske koordinate (handle drag).
    var mapRows: Int = 200
    var mapCols: Int = 200
    /// Povlačenje vrha: (index, row, col, ended).
    var onSeaVertexDrag: ((Int, CGFloat, CGFloat, Bool) -> Void)?
    /// Klik na mid-točku: podijeli rub (edge index).
    var onSeaMidSplit: ((Int) -> Void)?
    private(set) var draggingSeaHandle: (kind: SeaSurfaceHandleKind, index: Int)?
    var isSeaHandleDragging: Bool { draggingSeaHandle != nil }
    /// Uređivanje linije rijeke.
    var riverHandleEditing = false
    var onRiverVertexDrag: ((Int, CGFloat, CGFloat, Bool) -> Void)?
    var onRiverMidSplit: ((Int) -> Void)?
    private(set) var draggingRiverHandle: (kind: RiverPathHandleKind, index: Int)?
    var isRiverHandleDragging: Bool { draggingRiverHandle != nil }
    var hasObjectSelected: Bool = false
    /// Pan kamere dozvoljen samo kad ništa nije označeno (nema objekta za postavljanje, nije Teren, nije Briši).
    var cameraPanAllowed: Bool = true
    /// World koordinata → (row, col) za hit na terenu (poziv iz hit testa).
    var onCellHit: ((SCNVector3) -> (row: Int, col: Int)?)?
    /// Klik na kuglu (točku sjecišta) – (vertexRow, vertexCol). Jedna kugla = jedan vrh.
    var onVertexDotSelected: ((Int, Int) -> Void)?
    /// Poziva se pri pomicanju miša – za ghost objekta (npr. zid) na kursoru.
    var onMouseMove: ((NSPoint) -> Void)?
    /// Ažuriraj ghost iz trenutne pozicije miša (poziva se iz renderera kad mouseMoved ne stiže).
    func updateGhostFromCurrentMouseLocation() {
        guard let win = window else { return }
        let loc = convert(win.mouseLocationOutsideOfEventStream, from: nil)
        updateGroundMarkFar(at: loc)
        onMouseMove?(loc)
    }
    /// Desni klik (npr. otkaz place mode) – ne postavlja objekt.
    var onRightClick: (() -> Void)?
    /// Lijevi klik na dvorac.
    var onCastleClick: (() -> Void)?
    /// Poziva se nakon uspješnog place da se odmah osvježe čvorovi na sceni (ne čeka updateNSView).
    var onPlacementsDidChange: (() -> Void)?
    private var keyMonitor: Any?
    private var rightClickMonitor: Any?
    private var trackingArea: NSTrackingArea?
    /// Lijevi klik: hit test na mouseDown, poziv onClick tek na mouseUp ako nije bilo pomicanja (da se ne pomiješa s panom).
    private var pendingClickCell: (row: Int, col: Int)?
    /// Klik na dvorac (ne na zid). Na mouseUp otvara natpis zgrade.
    private var pendingCastleClick = false
    /// Klik na kuglu – vertex (row, col) sjecišta; na mouseUp poziva se onVertexDotSelected.
    private var pendingVertexDot: (row: Int, col: Int)?
    private var wallLineStartCell: (row: Int, col: Int)?
    private var wallLineCells: [(Int, Int)] = []
    var isWallLineActive: Bool { wallLineStartCell != nil }
    private static let clickDragThreshold: CGFloat = 6
    private var mouseDownLocation: NSPoint = .zero
    private var terrainPaintOrigin: (row: Int, col: Int)?
    private var terrainPaintFar: (row: Int, col: Int)?
    private(set) var terrainPaintDragging = false
    /// True dok je lijevi klik držan u Teren modu (preview / drag).
    var isTerrainPaintActive: Bool { terrainPaintOrigin != nil }
    /// Kad true: dva prsta = pan, pinch = zoom, rotacija = mapRotation. Kad false: miš (povuci = pan, scroll = zoom).
    var useTrackpad: Bool = true
    private var magnifyMonitor: Any?
    private var rotateMonitor: Any?
    /// Jedna gesta pinch = jedan korak zooma; akumuliramo dok traje gesta, na .ended šaljemo jedan korak.
    private var magnifyAccumulator: CGFloat = 0
    private static let magnifyThreshold: CGFloat = 0.02
    /// Jedna gesta rotacije = jedna strana svijeta (kao klik na kompas); akumuliramo kut, na .ended šaljemo ±90°.
    private var rotateAccumulator: CGFloat = 0
    private static let rotateThreshold: CGFloat = 0.15

    private static let swordCursor: NSCursor = makeSwordCursor()
    private static let maceCursor: NSCursor = makeMaceCursor()

    /// Odabrani alat u panelu Alati ("sword", "mace", …). Određuje koji kursor se prikazuje (mač ili buzdovan).
    var selectedToolsPanelItem: String?
    /// Lijevi povlak crta kvadrat. Desni povlak pomiče kameru.
    var groundMarkEnabled = false
    private var markOrigin: (row: Int, col: Int)?
    private var markFar: (row: Int, col: Int)?
    private var markFollowing = false
    private var markDragged = false
    private var pressMarkCell: (row: Int, col: Int)?
    private var selectionDragging = false
    private var rightPanLocation: NSPoint = .zero
    private var rightPanMoved = false
    /// Podzemlje: lijevi klik ne označava i ne gradi, ravnina tla je na dubini podzemlja.
    var isUnderground = false
    var groundPlaneY: CGFloat = 0
    var undergroundEntranceAt: ((Int, Int) -> Bool)?
    var onUndergroundEntrance: ((Int, Int) -> Void)?
    private var middleMonitor: Any?
    private var middlePanLocation: NSPoint = .zero
    private var middlePanning = false
    /// Map editor: klik je za alate (teren, brisanje), ne za označavanje ljudi.
    var isMapEditor: Bool = false
    /// Ima li građevina na ćeliji – klik na nju otvara njezino stanje umjesto oznake.
    var hasPlacementAt: ((Int, Int) -> Bool)?
    var isMarkFollowing: Bool { markFollowing }

    private var canGroundMark: Bool {
        !isMapEditor && currentSelectedPlacementObjectId == nil && !isEraseMode && !isCellSelectionMode && !handPanMode
    }
    var onGroundMarkPreview: (((row: Int, col: Int), (row: Int, col: Int))?) -> Void = { _ in }
    var onGroundMarkCommit: ((row: Int, col: Int), (row: Int, col: Int)) -> Void = { _, _ in }
    var onGroundMarkDraftStarted: () -> Void = {}
    /// Prekid nacrta oznake (bez potvrde) – makni označene osobe.
    var onGroundMarkCancelled: () -> Void = {}
    var hasMarkedSoldiers: (() -> Bool)?
    var onMoveOrder: ((Int, Int) -> Void)?
    private var pendingMoveOrder: (row: Int, col: Int)?
    var editingTransportId: String?
    var editingWarehouseRoute = false
    var onTransportCornerDrag: ((Int, Int, Int) -> Void)?
    var onTransportMidPromote: ((Int, Int, Int) -> Void)?
    private var draggingTransportCorner: Int?

    override func resetCursorRects() {
        super.resetCursorRects()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if handPanMode {
            addCursorRect(bounds, cursor: .openHand)
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override func layout() {
        super.layout()
        if let sv = scnView, bounds.width > 0, bounds.height > 0 {
            sv.frame = bounds
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
            trackingArea = nil
        }
        guard bounds.width > 0, bounds.height > 0 else { return }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        updateGroundMarkFar(at: loc)
        onMouseMove?(loc)
    }

    func setGroundMarkEnabled(_ enabled: Bool) {
        if groundMarkEnabled, !enabled, markFollowing {
            markFollowing = false
            if let origin = markOrigin, let far = markFar {
                finishGroundMark(origin: origin, far: far)
            }
        }
        groundMarkEnabled = enabled
    }

    private func handleGroundMarkClick(_ cell: (row: Int, col: Int)) {
        if markFollowing, let origin = markOrigin {
            finishGroundMark(origin: origin, far: cell)
        } else {
            markOrigin = cell
            markFar = cell
            markFollowing = true
            onGroundMarkDraftStarted()
            onGroundMarkPreview((cell, cell))
            markDragged = false
        }
    }

    /// Završi oznaku: potvrdi ljude, makni zeleni kvadrat i lokalni draft.
    private func finishGroundMark(origin: (row: Int, col: Int), far: (row: Int, col: Int)) {
        markFollowing = false
        markDragged = false
        markFar = far
        onGroundMarkCommit(origin, far)
        markOrigin = nil
        markFar = nil
    }

    private func updateGroundMarkFar(at loc: NSPoint) {
        guard markFollowing, let origin = markOrigin, let cell = groundCell(at: loc) else { return }
        if cell.row == markFar?.row, cell.col == markFar?.col { return }
        markFar = cell
        onGroundMarkPreview((origin, cell))
    }

    /// Ćelija pod mišem. Ako dvorac zakloni teren, sjecište s ravninom tla.
    private func groundCell(at pointInContainer: NSPoint) -> (row: Int, col: Int)? {
        if let cell = terrainCell(at: pointInContainer) { return cell }
        guard let world = planePoint(at: pointInContainer) else { return nil }
        return onCellHit?(world)
    }

    private func planePoint(at pointInContainer: NSPoint) -> SCNVector3? {
        guard let sv = scnView else { return nil }
        let p = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(p) else { return nil }
        let near = sv.unprojectPoint(SCNVector3(p.x, p.y, 0))
        let far = sv.unprojectPoint(SCNVector3(p.x, p.y, 1))
        let dy = far.y - near.y
        guard abs(dy) > 0.00001 else { return nil }
        let t = (groundPlaneY - near.y) / dy
        guard t.isFinite else { return nil }
        return SCNVector3(
            near.x + (far.x - near.x) * t,
            groundPlaneY,
            near.z + (far.z - near.z) * t
        )
    }

    private func clearGroundMark(cancelSelection: Bool = true) {
        let hadDraft = markOrigin != nil
        markOrigin = nil
        markFar = nil
        markFollowing = false
        markDragged = false
        onGroundMarkPreview(nil)
        if cancelSelection, hadDraft {
            onGroundMarkCancelled()
        }
    }

    func dismissGroundMark() {
        guard markOrigin != nil || markFollowing else { return }
        clearGroundMark(cancelSelection: true)
    }

    override func mouseEntered(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        onMouseMove?(loc)
    }

    override func rotate(with event: NSEvent) {
        let phase = event.phase
        if phase.contains(.began) { rotateAccumulator = 0 }
        if phase.contains(.changed) { rotateAccumulator += CGFloat(event.rotation) * .pi / 180 }
        if phase.contains(.ended) || phase.contains(.cancelled) {
            if rotateAccumulator > Self.rotateThreshold {
                onRotationDelta?(.pi / 2)
            } else if rotateAccumulator < -Self.rotateThreshold {
                onRotationDelta?(-.pi / 2)
            }
            rotateAccumulator = 0
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
            installKeyMonitor()
            installRightClickMonitor()
            syncPanInputMonitors()
        } else {
            stopScene()
            removeKeyMonitor()
            removeRightClickMonitor()
            removeTrackpadMonitors()
            removeMiddlePanMonitor()
        }
    }

    func installTrackpadMonitorsIfNeeded() {
        guard useTrackpad, window != nil, magnifyMonitor == nil else { return }
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else { return event }
            let phase = event.phase
            if phase.contains(.began) { self.magnifyAccumulator = 0 }
            if phase.contains(.changed) { self.magnifyAccumulator += event.magnification }
            if phase.contains(.ended) || phase.contains(.cancelled) {
                if self.magnifyAccumulator > Self.magnifyThreshold {
                    self.onZoomDelta?(1)
                } else if self.magnifyAccumulator < -Self.magnifyThreshold {
                    self.onZoomDelta?(-1)
                }
                self.magnifyAccumulator = 0
            }
            return nil
        }
        // Rotaciju ne hvatimo monitorom (može blokirati isporuku); view prima rotate(with:) iz responder lanca.
        rotateMonitor = nil
    }

    func removeTrackpadMonitors() {
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
        if let m = rotateMonitor { NSEvent.removeMonitor(m); rotateMonitor = nil }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil, window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window != nil, self.window!.isKeyWindow else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    private func installRightClickMonitor() {
        guard rightClickMonitor == nil, window != nil else { return }
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .rightMouseDragged, .rightMouseUp]) { [weak self] event in
            guard let self = self, self.window == event.window else { return event }
            let locInView = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(locInView) else { return event }
            switch event.type {
            case .rightMouseDown:
                self.rightPanLocation = locInView
                self.rightPanMoved = false
            case .rightMouseDragged:
                guard self.useTrackpad else { break }
                let dist = hypot(locInView.x - self.rightPanLocation.x, locInView.y - self.rightPanLocation.y)
                if dist > Self.clickDragThreshold { self.rightPanMoved = true }
                if self.rightPanMoved, self.cameraPanAllowed {
                    self.panCamera(from: self.rightPanLocation, to: locInView)
                    self.rightPanLocation = locInView
                }
            case .rightMouseUp:
                if !self.useTrackpad || !self.rightPanMoved {
                    self.pendingClickCell = nil
                    self.pendingVertexDot = nil
                    self.pendingCastleClick = false
                    self.clearWallLineDraft()
                    if self.markOrigin != nil { self.clearGroundMark() }
                    self.onRightClick?()
                }
                self.rightPanMoved = false
            default:
                break
            }
            return nil
        }
    }

    private func removeRightClickMonitor() {
        if let m = rightClickMonitor {
            NSEvent.removeMonitor(m)
            rightClickMonitor = nil
        }
    }

    func syncPanInputMonitors() {
        if useTrackpad {
            removeMiddlePanMonitor()
            installTrackpadMonitorsIfNeeded()
        } else {
            removeTrackpadMonitors()
            installMiddlePanMonitorIfNeeded()
        }
    }

    private func installMiddlePanMonitorIfNeeded() {
        guard !useTrackpad, window != nil, middleMonitor == nil else { return }
        middleMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .otherMouseDragged, .otherMouseUp]) { [weak self] event in
            guard let self = self, !self.useTrackpad, self.window == event.window, event.buttonNumber == 2 else { return event }
            let loc = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(loc) else { return event }
            switch event.type {
            case .otherMouseDown:
                guard self.cameraPanAllowed else { break }
                self.middlePanLocation = loc
                self.middlePanning = true
                self.onPanStart?(loc)
                NSCursor.closedHand.push()
            case .otherMouseDragged:
                guard self.middlePanning, self.cameraPanAllowed else { break }
                self.panCamera(from: self.middlePanLocation, to: loc)
                self.middlePanLocation = loc
            case .otherMouseUp:
                if self.middlePanning {
                    self.middlePanning = false
                    NSCursor.closedHand.pop()
                }
            default:
                break
            }
            return nil
        }
    }

    private func removeMiddlePanMonitor() {
        if middlePanning {
            middlePanning = false
            NSCursor.closedHand.pop()
        }
        if let m = middleMonitor {
            NSEvent.removeMonitor(m)
            middleMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Ne kradi tipke dok se tipka u polju teksta.
        if let fr = window?.firstResponder, fr is NSTextView || fr is NSTextField { return false }
        switch event.keyCode {
        case 53:
            if markOrigin != nil { clearGroundMark() }
            onRightClick?()
            return true
        case 49: // Space — nacrt odozgo ↔ kosi pogled
            onToggleTopDown?()
            return true
        case 126: onTiltDelta?(0.06); return true
        case 125: onTiltDelta?(-0.06); return true
        case 0x0D: onPanChange?(CGPoint(x: 0, y: 28)); return true
        case 0x01: onPanChange?(CGPoint(x: 0, y: -28)); return true
        case 0x00: onPanChange?(CGPoint(x: -28, y: 0)); return true
        case 0x02: onPanChange?(CGPoint(x: 28, y: 0)); return true
        default: return false
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }
    override func resignFirstResponder() -> Bool { true }

    /// Donji bar (Nazad, Zid, Tržnica) mora primati klikove – vrati nil za područje bara da SwiftUI gumbi rade.
    private static let bottomBarHitTestHeight: CGFloat = 140

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        // Ispod ove visine je donji bar; ne uzimaj hit da Nazad, Zid i Market primaju klik.
        if point.y < Self.bottomBarHitTestHeight { return nil }
        return self
    }

    /// Kad hit test ne uspije, postavi ovu poruku da parent može prikazati alert (opcionalno).
    var onPlacementError: ((String) -> Void)?
    /// Kopija odabranog objekta za postavljanje (ažurira se u updateNSView) da klik uvijek vidi aktualnu vrijednost.
    var currentSelectedPlacementObjectId: String?

    /// Točka na terenu ispod kursora, u world koordinatama.
    private func groundPoint(at pointInContainer: NSPoint) -> SCNVector3? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1,
            .ignoreHiddenNodes: true
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        return hits.first(where: { isBuildSurface($0.node, underground: isUnderground) })?.worldCoordinates
    }

    /// Najbliži pogodak je dvorac. Zid se ne broji.
    private func castleHit(at pointInContainer: NSPoint) -> Bool {
        guard !isUnderground, let sv = scnView else { return false }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return false }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .categoryBitMask: 1,
            .ignoreHiddenNodes: true
        ]
        guard let hit = sv.hitTest(hitPointInView, options: hitOptions).first else { return false }
        var node: SCNNode? = hit.node
        while let current = node {
            if current.name == "castle" { return true }
            node = current.parent
        }
        return false
    }

    private func terrainCell(at pointInContainer: NSPoint) -> (row: Int, col: Int)? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        guard let hit = hits.first(where: { isBuildSurface($0.node, underground: isUnderground) }),
              let convertCell = onCellHit,
              let cell = convertCell(hit.worldCoordinates) else { return nil }
        return cell
    }

    private func transportHandleHit(at pointInContainer: NSPoint) -> (kind: String, index: Int)? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hits = sv.hitTest(hitPointInView, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ])
        guard let name = hits.first(where: { $0.node.name?.hasPrefix("tcorner_") == true || $0.node.name?.hasPrefix("tmid_") == true })?.node.name else { return nil }
        if name.hasPrefix("tcorner_"), let i = Int(name.dropFirst(8)) { return ("corner", i) }
        if name.hasPrefix("tmid_"), let i = Int(name.dropFirst(5)) { return ("mid", i) }
        return nil
    }

    private func seaHandleHit(at pointInContainer: NSPoint) -> (kind: SeaSurfaceHandleKind, index: Int)? {
        guard seaHandleEditing, let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hits = sv.hitTest(hitPointInView, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ])
        var vertexHit: (SeaSurfaceHandleKind, Int)?
        for hit in hits {
            var node: SCNNode? = hit.node
            while let current = node {
                if let parsed = SeaSurfaceHandle.parse(nodeName: current.name ?? "") {
                    // Mid ima prednost (manja točka na rubu).
                    if parsed.kind == .mid { return parsed }
                    if vertexHit == nil { vertexHit = parsed }
                }
                node = current.parent
            }
        }
        return vertexHit
    }

    private func riverHandleHit(at pointInContainer: NSPoint) -> (kind: RiverPathHandleKind, index: Int)? {
        guard riverHandleEditing, let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hits = sv.hitTest(hitPointInView, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ])
        var vertexHit: (RiverPathHandleKind, Int)?
        for hit in hits {
            var node: SCNNode? = hit.node
            while let current = node {
                if let parsed = RiverPathHandle.parse(nodeName: current.name ?? "") {
                    if parsed.kind == .mid { return parsed }
                    if vertexHit == nil { vertexHit = parsed }
                }
                node = current.parent
            }
        }
        return vertexHit
    }

    /// Decimalne ćelijske koordinate (row, col) ispod kursora.
    /// Ravnina ima prednost (brže / bez kašnjenja pri drag handlea).
    private func groundCellFloat(at pointInContainer: NSPoint) -> (row: CGFloat, col: CGFloat)? {
        let world = planePoint(at: pointInContainer) ?? groundPoint(at: pointInContainer)
        guard let world else { return nil }
        let halfW = effectiveMapWorldW(cols: mapCols) / 2
        let halfH = effectiveMapWorldH(rows: mapRows) / 2
        let step = worldUnitsPerCell
        let col = (CGFloat(world.x) + halfW) / step
        let row = (CGFloat(world.z) + halfH) / step
        return (row, col)
    }

    /// Hit na kuglu (točku sjecišta). Vraća (vertexRow, vertexCol) ako je prvi pogodak čvor s imenom "dot_*".
    private func vertexDotHit(at pointInContainer: NSPoint) -> (row: Int, col: Int)? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        guard let hit = hits.first(where: { $0.node.name?.hasPrefix("dot_") == true }),
              let name = hit.node.name else { return nil }
        let parts = name.dropFirst(4).split(separator: "_")
        guard parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]) else { return nil }
        return (r, c)
    }

    private func buildStraightLineCells(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> [(Int, Int)] {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        if dRow == 0 {
            let step = dCol >= 0 ? 1 : -1
            return stride(from: start.col, through: end.col, by: step).map { (start.row, $0) }
        }
        if dCol == 0 {
            let step = dRow >= 0 ? 1 : -1
            return stride(from: start.row, through: end.row, by: step).map { ($0, start.col) }
        }

        // Dominantna osa + progresivni "lom":
        // zadržava efekt 50/50 kod malog pomaka, a pri daljnjem pomicanju nastavlja stepenasto.
        if abs(dCol) >= abs(dRow) {
            let stepCol = dCol > 0 ? 1 : -1
            let count = abs(dCol)
            let rowSign = dRow > 0 ? 1 : -1
            return (0...count).map { i in
                let t = Double(i) / Double(max(1, count))
                let shiftedRows = Int((t * Double(abs(dRow))).rounded())
                return (start.row + rowSign * shiftedRows, start.col + i * stepCol)
            }
        } else {
            let stepRow = dRow > 0 ? 1 : -1
            let count = abs(dRow)
            let colSign = dCol > 0 ? 1 : -1
            return (0...count).map { i in
                let t = Double(i) / Double(max(1, count))
                let shiftedCols = Int((t * Double(abs(dCol))).rounded())
                return (start.row + i * stepRow, start.col + colSign * shiftedCols)
            }
        }
    }

    private func clearWallLineDraft() {
        wallLineStartCell = nil
        wallLineCells.removeAll(keepingCapacity: false)
        onWallLinePreview?([])
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPanLocation = convert(event.locationInWindow, from: nil)
        mouseDownLocation = lastPanLocation
        pendingClickCell = nil
        pendingVertexDot = nil
        pendingCastleClick = false
        let mouseDownLog = "[Camera] mouseDown loc=(\(String(format: "%.0f", lastPanLocation.x)),\(String(format: "%.0f", lastPanLocation.y))) handPanMode=\(handPanMode)"
        print(mouseDownLog)
        Task { @MainActor in PlacementDebugConsole.shared.append(mouseDownLog) }
        guard event.buttonNumber == 0 else { return }
        if handPanMode, cameraPanAllowed {
            isPanning = true
            onPanStart?(mouseDownLocation)
            NSCursor.closedHand.push()
            return
        }
        if riverHandleEditing, let handle = riverHandleHit(at: lastPanLocation) {
            pendingClickCell = nil
            if handle.kind == .mid {
                onRiverMidSplit?(handle.index)
                return
            }
            draggingRiverHandle = handle
            if let pos = groundCellFloat(at: lastPanLocation) {
                onRiverVertexDrag?(handle.index, pos.row, pos.col, false)
            }
            return
        }
        if seaHandleEditing, let handle = seaHandleHit(at: lastPanLocation) {
            pendingClickCell = nil
            if handle.kind == .mid {
                // Klik na mid → podijeli rub na pola (nova točka).
                onSeaMidSplit?(handle.index)
                return
            }
            // Vrh → povuci.
            draggingSeaHandle = handle
            if let pos = groundCellFloat(at: lastPanLocation) {
                onSeaVertexDrag?(handle.index, pos.row, pos.col, false)
            }
            return
        }
        if (editingTransportId != nil || editingWarehouseRoute), let handle = transportHandleHit(at: lastPanLocation) {
            if handle.kind == "mid" {
                if let cell = groundCell(at: lastPanLocation) {
                    onTransportMidPromote?(handle.index, cell.row, cell.col)
                    draggingTransportCorner = handle.index + 1
                }
            } else if handle.index > 0 {
                draggingTransportCorner = handle.index
            }
            pendingClickCell = nil
            return
        }
        if !isUnderground, !markFollowing, currentSelectedPlacementObjectId == nil, !isEraseMode,
           let cell = terrainCell(at: lastPanLocation),
           undergroundEntranceAt?(cell.row, cell.col) == true {
            if hasMarkedSoldiers?() == true {
                pendingMoveOrder = cell
            } else {
                dismissGroundMark()
            }
            onUndergroundEntrance?(cell.row, cell.col)
            return
        }
        if canGroundMark, !markFollowing, hasMarkedSoldiers?() == true, wallLineStartCell == nil,
           currentSelectedPlacementObjectId == nil, let cell = groundCell(at: lastPanLocation) {
            pendingMoveOrder = cell
            return
        }
        if canGroundMark, wallLineStartCell == nil, let cell = groundCell(at: lastPanLocation) {
            if markFollowing, let origin = markOrigin {
                pendingClickCell = nil
                pendingVertexDot = nil
                pendingCastleClick = false
                finishGroundMark(origin: origin, far: cell)
                return
            }
            if !castleHit(at: lastPanLocation), hasPlacementAt?(cell.row, cell.col) != true {
                markOrigin = cell
                markFar = cell
                markFollowing = true
                pendingClickCell = nil
                pendingVertexDot = nil
                pendingCastleClick = false
                onGroundMarkDraftStarted()
                onGroundMarkPreview((cell, cell))
                markDragged = false
                return
            }
        }
        if isPanning { return }
        if let vertex = vertexDotHit(at: lastPanLocation) {
            pendingVertexDot = vertex
            return
        }
        if castleHit(at: lastPanLocation) {
            pendingCastleClick = true
            return
        }
        guard let (row, col) = terrainCell(at: lastPanLocation) else {
            onPlacementError?("Klik nije pogodio teren.")
            return
        }
        if !isEraseMode, let id = currentSelectedPlacementObjectId, WallParent.isWall(objectId: id) {
            wallLineStartCell = (row, col)
            wallLineCells = [(row, col)]
            onWallLinePreview?(wallLineCells)
            return
        }
        if isTerrainEditMode, !seaHandleEditing {
            // groundCell (ravnina) — mesh hit pada na rupama/moru i prekida označavanje.
            let cell = groundCell(at: lastPanLocation) ?? (row, col)
            terrainPaintOrigin = cell
            terrainPaintFar = cell
            terrainPaintDragging = false
            pendingClickCell = cell
            onTerrainPaintPreview?(cell.row, cell.col, cell.row, cell.col)
            return
        }
        pendingClickCell = (row, col)
    }

    override func rightMouseDown(with event: NSEvent) {
        pendingClickCell = nil
        pendingVertexDot = nil
        pendingCastleClick = false
        clearWallLineDraft()
        if markOrigin != nil {
            clearGroundMark()
        }
        onRightClick?()
    }

    private func panCamera(from: NSPoint, to loc: NSPoint) {
        if let a = planePoint(at: from) ?? groundPoint(at: from), let b = planePoint(at: loc) ?? groundPoint(at: loc) {
            onPanLock?(CGFloat(b.x - a.x), CGFloat(b.z - a.z))
        } else {
            onPanChange?(CGPoint(x: -(loc.x - from.x), y: -(loc.y - from.y)))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0 else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if let handle = draggingRiverHandle, handle.kind == .vertex, let pos = groundCellFloat(at: loc) {
            onRiverVertexDrag?(handle.index, pos.row, pos.col, false)
            lastPanLocation = loc
            return
        }
        if let handle = draggingSeaHandle, handle.kind == .vertex, let pos = groundCellFloat(at: loc) {
            onSeaVertexDrag?(handle.index, pos.row, pos.col, false)
            lastPanLocation = loc
            return
        }
        if let index = draggingTransportCorner, let cell = groundCell(at: loc) {
            onTransportCornerDrag?(index, cell.row, cell.col)
            lastPanLocation = loc
            return
        }
        if let start = pendingMoveOrder {
            let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
            if dist > Self.clickDragThreshold {
                pendingMoveOrder = nil
                markOrigin = start
                markFar = start
                markFollowing = true
                onGroundMarkDraftStarted()
                onGroundMarkPreview((start, start))
                markDragged = true
                updateGroundMarkFar(at: loc)
                lastPanLocation = loc
                return
            }
        }
        if markFollowing {
            pendingClickCell = nil
            pendingVertexDot = nil
            pendingCastleClick = false
            isPanning = false
            markDragged = true
            updateGroundMarkFar(at: loc)
            lastPanLocation = loc
            return
        }
        if isTerrainEditMode, let origin = terrainPaintOrigin {
            let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
            if dist > Self.clickDragThreshold {
                terrainPaintDragging = true
                pendingClickCell = nil
            }
            if let cell = groundCell(at: loc) {
                terrainPaintFar = cell
                onTerrainPaintPreview?(origin.row, origin.col, cell.row, cell.col)
            }
            lastPanLocation = loc
            return
        }
        if let start = wallLineStartCell {
            if let end = terrainCell(at: loc) {
                let newCells = buildStraightLineCells(from: start, to: end)
                let changed = newCells.count != wallLineCells.count || zip(newCells, wallLineCells).contains { lhs, rhs in
                    lhs.0 != rhs.0 || lhs.1 != rhs.1
                }
                if changed {
                    wallLineCells = newCells
                    onWallLinePreview?(newCells)
                }
            }
            lastPanLocation = loc
            return
        }
        if !isPanning {
            let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
            if dist > Self.clickDragThreshold { pendingClickCell = nil; pendingVertexDot = nil; pendingCastleClick = false }
            if cameraPanAllowed && handPanMode && dist > Self.clickDragThreshold {
                isPanning = true
                onPanStart?(mouseDownLocation)
                NSCursor.closedHand.push()
            } else {
                return
            }
        }
        guard cameraPanAllowed else { return }
        if let from = groundPoint(at: lastPanLocation), let to = groundPoint(at: loc) {
            onPanLock?(CGFloat(to.x - from.x), CGFloat(to.z - from.z))
        } else {
            let dx = loc.x - lastPanLocation.x
            let dy = loc.y - lastPanLocation.y
            onPanChange?(CGPoint(x: -dx, y: -dy))
        }
        lastPanLocation = loc
    }

    override func mouseUp(with event: NSEvent) {
        if event.buttonNumber == 0, let handle = draggingRiverHandle {
            let loc = convert(event.locationInWindow, from: nil)
            if handle.kind == .vertex {
                if let pos = groundCellFloat(at: loc) {
                    onRiverVertexDrag?(handle.index, pos.row, pos.col, true)
                } else {
                    onRiverVertexDrag?(handle.index, .nan, .nan, true)
                }
            }
            draggingRiverHandle = nil
            pendingClickCell = nil
            return
        }
        if event.buttonNumber == 0, let handle = draggingSeaHandle {
            let loc = convert(event.locationInWindow, from: nil)
            if handle.kind == .vertex {
                if let pos = groundCellFloat(at: loc) {
                    onSeaVertexDrag?(handle.index, pos.row, pos.col, true)
                } else {
                    onSeaVertexDrag?(handle.index, .nan, .nan, true)
                }
            }
            draggingSeaHandle = nil
            pendingClickCell = nil
            return
        }
        if event.buttonNumber == 0, draggingTransportCorner != nil {
            draggingTransportCorner = nil
            pendingClickCell = nil
            return
        }
        if event.buttonNumber == 0, markFollowing {
            if markDragged, let origin = markOrigin, let far = markFar ?? markOrigin {
                finishGroundMark(origin: origin, far: far)
            }
            pendingClickCell = nil
            pendingVertexDot = nil
            pendingCastleClick = false
            return
        }
        if event.buttonNumber == 0, wallLineStartCell != nil {
            let commitCells = wallLineCells
            clearWallLineDraft()
            if !commitCells.isEmpty {
                onWallLineCommit?(commitCells)
            }
            return
        }
        if event.buttonNumber == 0, isTerrainEditMode, let origin = terrainPaintOrigin {
            let far = terrainPaintFar ?? origin
            let wasDrag = terrainPaintDragging
            terrainPaintOrigin = nil
            terrainPaintFar = nil
            terrainPaintDragging = false
            if wasDrag {
                onTerrainPaintCommit?(origin.row, origin.col, far.row, far.col)
                pendingClickCell = nil
                pendingVertexDot = nil
                pendingCastleClick = false
                return
            }
            // Jedan klik bez povlačenja – postojeći onClick / četkica.
        }
        if event.buttonNumber == 0, let order = pendingMoveOrder, !isPanning {
            pendingMoveOrder = nil
            onMoveOrder?(order.row, order.col)
            pendingClickCell = nil
            pendingVertexDot = nil
            pendingCastleClick = false
            return
        }
        pendingMoveOrder = nil
        if event.buttonNumber == 0, !isPanning {
            if let vertex = pendingVertexDot {
                onVertexDotSelected?(vertex.row, vertex.col)
            } else if pendingCastleClick {
                onCastleClick?()
            } else if let cell = pendingClickCell {
                onClick?(cell.row, cell.col)
            }
        }
        pendingClickCell = nil
        pendingVertexDot = nil
        pendingCastleClick = false
        if isPanning {
            isPanning = false
            NSCursor.closedHand.pop()
            NSCursor.openHand.push()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if useTrackpad, cameraPanAllowed {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            if dx != 0 || dy != 0 {
                onPanChange?(CGPoint(x: -dx, y: -dy))
            }
        } else if !useTrackpad {
            let dy = event.scrollingDeltaY
            if dy != 0 { onZoomDelta?(dy > 0 ? CGFloat(0.15) : CGFloat(-0.15)) }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onRightClick?()
        case 49: onToggleTopDown?()
        case 126: onTiltDelta?(0.06)
        case 125: onTiltDelta?(-0.06)
        case 0x0D: if cameraPanAllowed { onPanChange?(CGPoint(x: 0, y: 28)) }
        case 0x01: if cameraPanAllowed { onPanChange?(CGPoint(x: 0, y: -28)) }
        case 0x00: if cameraPanAllowed { onPanChange?(CGPoint(x: -28, y: 0)) }
        case 0x02: if cameraPanAllowed { onPanChange?(CGPoint(x: 28, y: 0)) }
        default: break
        }
    }
}

/// Boja linija i točaka: bijela za obje mreže (40×40 i 10×10). Točke na sjecištima služe za mikropodešavanja.
private func gridLineColor(isLargeGrid: Bool) -> NSColor {
    NSColor.white.withAlphaComponent(0.95)
}

/// Ponovno gradi linije rešetke. Mreža je uvijek ravna na fiksnoj visini – ne prati teren. Točke (vertex) će se drugi put implementirati iz Map Editora.
private func refreshGrid(gridNode: SCNNode, zoom: CGFloat, gridDivisions: Int, mapWidth: CGFloat, mapHeight: CGFloat, gameMap: GameMap? = nil, rows: Int? = nil, cols: Int? = nil, lineColor: NSColor? = nil) {
    gridNode.childNodes.forEach { $0.removeFromParentNode() }
    let divisionsForBuilding = Int(mapWidth / worldUnitsPerCell)
    let isLarge = (gridDivisions == divisionsForBuilding)
    let lineColor = lineColor ?? gridLineColor(isLargeGrid: isLarge)
    let baseW: CGFloat = 2.5
    let baseH: CGFloat = 8
    let z = max(0.1, min(50, zoom))
    let lineW = baseW / z
    let lineH = baseH / z
    let halfW = mapWidth / 2
    let halfH = mapHeight / 2
    let stepW = mapWidth / CGFloat(gridDivisions)
    let stepH = mapHeight / CGFloat(gridDivisions)
    let gridY = groundLevelY + lineH / 2
    var x = -halfW
    while x <= halfW {
        let box = SCNBox(width: lineW, height: lineH, length: mapHeight, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(x, gridY, 0)
        gridNode.addChildNode(n)
        x += stepW
    }
    var zCoord = -halfH
    while zCoord <= halfH {
        let box = SCNBox(width: mapWidth, height: lineH, length: lineW, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(0, gridY, zCoord)
        gridNode.addChildNode(n)
        zCoord += stepH
    }
}

/// Tlo na kojem se gradi: teren gore, pod podzemlja dolje.
private func isBuildSurface(_ node: SCNNode, underground: Bool) -> Bool {
    underground ? node.name == "undergroundFloor" : node.name == "terrain"
}

/// Iz world pozicije na terenu vraća (row, col) ili nil. 1 ćelija = 40 world jedinica.
private func cellFromMapLocalPosition(_ localPos: SCNVector3, rows: Int, cols: Int) -> (row: Int, col: Int)? {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let col = Int((CGFloat(localPos.x) + halfW) / worldUnitsPerCell)
    let row = Int((CGFloat(localPos.z) + halfH) / worldUnitsPerCell)
    guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
    return (row, col)
}

/// Visina terena u world (x, z); bilinearna interpolacija iz vertex visina (GameMap.vertexHeightAt). Koristi se da mreža prati deformaciju terena.
private func terrainHeightAtWorld(x: CGFloat, z: CGFloat, gameMap: GameMap, rows: Int, cols: Int) -> CGFloat {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let c_f = (x + halfW) / step
    let r_f = (z + halfH) / step
    let c0 = max(0, min(cols - 1, Int(floor(c_f))))
    let r0 = max(0, min(rows - 1, Int(floor(r_f))))
    let c1 = min(cols, c0 + 1)
    let r1 = min(rows, r0 + 1)
    let h00 = gameMap.vertexHeightAt(vertexRow: r0, vertexCol: c0)
    let h01 = c1 > c0 ? gameMap.vertexHeightAt(vertexRow: r0, vertexCol: c1) : h00
    let h10 = r1 > r0 ? gameMap.vertexHeightAt(vertexRow: r1, vertexCol: c0) : h00
    let h11 = (c1 > c0 && r1 > r0) ? gameMap.vertexHeightAt(vertexRow: r1, vertexCol: c1) : h00
    let tx = c_f - CGFloat(c0)
    let tz = r_f - CGFloat(r0)
    return (1 - tx) * (1 - tz) * h00 + tx * (1 - tz) * h01 + (1 - tx) * tz * h10 + tx * tz * h11
}

/// Zelena površina samo nad označenim ćelijama: ravni quad po ćeliji na visini te ćelije (Y = visina, horizontalno u XZ – ostale ćelije na miru).
private func makeGreenSurfaceGeometry(gameMap: GameMap, cells: Set<MapCoordinate>, rows: Int, cols: Int) -> SCNGeometry? {
    makeSelectionSurfaceGeometry(
        gameMap: gameMap, cells: cells, rows: rows, cols: cols,
        diffuse: NSColor(red: 0.5, green: 0.98, blue: 0.55, alpha: 0.75),
        emission: NSColor(red: 0.55, green: 1.0, blue: 0.6, alpha: 0.6)
    )
}

/// Overlay označenog područja (zeleno ili more-plavo dok se vuče četkica).
/// Prati površinu terena (vertex visine), kao ground mark — inače overlay završi ispod mreže.
private func makeSelectionSurfaceGeometry(
    gameMap: GameMap,
    cells: Set<MapCoordinate>,
    rows: Int,
    cols: Int,
    diffuse: NSColor,
    emission: NSColor,
    lift: CGFloat = 0.22
) -> SCNGeometry? {
    guard !cells.isEmpty else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    var vertices: [SCNVector3] = []
    var indices: [Int32] = []
    for coord in cells {
        let (r, c) = (coord.row, coord.col)
        guard r >= 0, r < rows, c >= 0, c < cols else { continue }
        let surface = gameMap.surface(row: r, col: c)
        let base = Int32(vertices.count)
        // Y-up (overlay na scene.rootNode), ista formula kao ground mark / pad overlay.
        for point in surface.allPoints {
            vertices.append(SCNVector3(
                point.x * step - halfW,
                point.height + lift,
                point.z * step - halfH
            ))
        }
        let center = base + 4
        indices.append(contentsOf: [
            base, center, base + 1,
            base + 1, center, base + 2,
            base + 2, center, base + 3,
            base + 3, center, base
        ])
    }
    guard !vertices.isEmpty else { return nil }
    let mat = SCNMaterial()
    mat.diffuse.contents = diffuse
    mat.emission.contents = emission
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.transparencyMode = .singleLayer
    mat.writesToDepthBuffer = false
    mat.readsFromDepthBuffer = false
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices)],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    geo.materials = [mat]
    return geo
}

/// Zeleno plodno tlo, siva kamena ruda, kockasto tamnosivo/crveno željezna ruda.
private func buildPadOverlayColor(_ cell: MapCell, row: Int, col: Int) -> [Float]? {
    switch cell.resource {
    case .iron:
        return (row + col) % 2 == 0 ? [0.18, 0.18, 0.20] : [0.82, 0.14, 0.12]
    case .stone:
        return [0.62, 0.62, 0.66]
    case .wood, nil:
        if cell.povrsina == .plodna { return [0.16, 0.68, 0.22] }
        if cell.povrsina == .pustinja { return [0.86, 0.76, 0.48] }
        if cell.povrsina == .obala { return [0.90, 0.78, 0.48] } // plaža / obala
        if cell.povrsina == .voda { return [0.25, 0.55, 0.86] }
        if cell.povrsina == .more {
            // Dublje = tamnije plavo (seaDepth 1…10).
            let t = Float(min(1, max(0, cell.effectiveSeaDepth / UndergroundTerrain.seaDepthMax)))
            return [0.04 + (1 - t) * 0.06, 0.12 + (1 - t) * 0.18, 0.40 + (1 - t) * 0.35]
        }
        if cell.povrsina == .mocvara { return [0.28, 0.38, 0.22] }
        return nil
    }
}

/// Boja ćelije u sloju editora (RGB). nil = ćelija se ne boji.
private func editorOverlayColor(_ cell: MapCell, mode: MapEditorPaintMode, row: Int, col: Int) -> [Float]? {
    switch mode {
    case .teren:
        let c = MapTextureCatalog.entry(for: cell.povrsina).color
        return [Float(c.0), Float(c.1), Float(c.2)]
    case .podloge:
        return buildPadOverlayColor(cell, row: row, col: col)
    case .naslage:
        switch cell.resource {
        case .stone: return [0.75, 0.75, 0.78]
        case .iron: return [0.75, 0.35, 0.2]
        case .wood, nil: return nil
        }
    case .gradnja:
        return cell.buildable && cell.povrsina.isBuildable ? nil : [0.95, 0.15, 0.15]
    case .kretanje:
        let t = Float(min(1.5, max(0, cell.movementIndex)) / 1.5)
        return [1 - t, t, 0.25]
    case .visina, .precizno:
        return nil
    }
}

/// Sloj editora: svaka ćelija obojena prema modu, prati 5 točaka ploče.
private func makeEditorCellOverlayGeometry(gameMap: GameMap, mode: MapEditorPaintMode, selected: MapCoordinate?) -> SCNGeometry? {
    let rows = gameMap.rows, cols = gameMap.cols
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let lift: CGFloat = 0.06
    var vertices: [SCNVector3] = []
    var colors: [Float] = []
    var indices: [Int32] = []
    func addCell(row: Int, col: Int, color: [Float]) {
        let surface = gameMap.surface(row: row, col: col)
        let base = Int32(vertices.count)
        for point in surface.allPoints {
            vertices.append(SCNVector3(point.x * step - halfW, point.height + lift, point.z * step - halfH))
            colors.append(contentsOf: color)
        }
        let center = base + 4
        indices.append(contentsOf: [base, center, base + 1, base + 1, center, base + 2, base + 2, center, base + 3, base + 3, center, base])
    }
    if mode == .precizno {
        if let selected, gameMap.isValid(selected) {
            addCell(row: selected.row, col: selected.col, color: [1, 0.85, 0.1])
        }
    } else {
        for r in 0..<rows {
            for c in 0..<cols {
                guard let cell = gameMap.cell(row: r, col: c), let color = editorOverlayColor(cell, mode: mode, row: r, col: c) else { continue }
                addCell(row: r, col: c, color: color)
            }
        }
    }
    guard !vertices.isEmpty else { return nil }
    let colorSource = SCNGeometrySource(
        data: colors.withUnsafeBufferPointer { Data(buffer: $0) },
        semantic: .color,
        vectorCount: colors.count / 3,
        usesFloatComponents: true,
        componentsPerVector: 3,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 3
    )
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices), colorSource],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(white: 1, alpha: mode == .precizno ? 0.6 : 0.5)
    mat.lightingModel = .constant
    mat.isDoubleSided = true
    mat.writesToDepthBuffer = false
    geo.materials = [mat]
    return geo
}

/// Ćelije koje prekriva pod građevine — pad terena tu ne smije ostati iznad.
private func cellsCoveredByBuildingFloors(_ gameMap: GameMap) -> Set<MapCoordinate> {
    var covered = Set<MapCoordinate>()
    for placement in gameMap.placements {
        guard !BuildRules.decorationObjectIds.contains(placement.objectId) else { continue }
        for coord in placement.coveredCoordinates() {
            covered.insert(coord)
        }
    }
    return covered
}

/// Trajni sloj podloga: plodno tlo, kamena ruda, željezna ruda.
/// Ispod građevine se ne crta — pod objekta je iznad i dominantniji.
private func makeBuildPadOverlayGeometry(gameMap: GameMap) -> SCNGeometry? {
    let rows = gameMap.rows, cols = gameMap.cols
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let lift: CGFloat = 0.09
    let hidden = cellsCoveredByBuildingFloors(gameMap)
    var vertices: [SCNVector3] = []
    var colors: [Float] = []
    var indices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            if hidden.contains(MapCoordinate(row: r, col: c)) { continue }
            guard let cell = gameMap.cell(row: r, col: c), let color = buildPadOverlayColor(cell, row: r, col: c) else { continue }
            let surface = gameMap.surface(row: r, col: c)
            let base = Int32(vertices.count)
            for point in surface.allPoints {
                vertices.append(SCNVector3(point.x * step - halfW, point.height + lift, point.z * step - halfH))
                colors.append(contentsOf: color)
            }
            let center = base + 4
            indices.append(contentsOf: [base, center, base + 1, base + 1, center, base + 2, base + 2, center, base + 3, base + 3, center, base])
        }
    }
    guard !vertices.isEmpty else { return nil }
    let colorSource = SCNGeometrySource(
        data: colors.withUnsafeBufferPointer { Data(buffer: $0) },
        semantic: .color,
        vectorCount: colors.count / 3,
        usesFloatComponents: true,
        componentsPerVector: 3,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 3
    )
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices), colorSource],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(white: 1, alpha: 0.88)
    mat.emission.contents = NSColor(white: 0.18, alpha: 1)
    mat.lightingModel = .constant
    mat.isDoubleSided = true
    mat.readsFromDepthBuffer = true
    mat.writesToDepthBuffer = false
    mat.transparencyMode = .singleLayer
    geo.materials = [mat]
    return geo
}

/// Plavi sloj podzemnih voda, prati teren. Prikazuje se dok je odabran bunar ili izvor.
private func makeGroundwaterGeometry(gameMap: GameMap, water: GroundwaterMap) -> SCNGeometry? {
    let rows = gameMap.rows, cols = gameMap.cols
    guard rows > 0, cols > 0, water.rows == rows, water.cols == cols else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let lift: CGFloat = 0.08
    var vertices: [SCNVector3] = []
    var colors: [Float] = []
    var indices: [Int32] = []
    let deep: [Float] = [0.1, 0.45, 1.0]
    let shore: [Float] = [0.35, 0.75, 1.0]
    for r in 0..<rows {
        for c in 0..<cols where water.hasWater(row: r, col: c) {
            let edge = !water.hasWater(row: r - 1, col: c) || !water.hasWater(row: r + 1, col: c)
                || !water.hasWater(row: r, col: c - 1) || !water.hasWater(row: r, col: c + 1)
            let x0 = CGFloat(c) * step - halfW
            let x1 = CGFloat(c + 1) * step - halfW
            let z0 = CGFloat(r) * step - halfH
            let z1 = CGFloat(r + 1) * step - halfH
            let base = Int32(vertices.count)
            vertices.append(SCNVector3(x0, gameMap.vertexHeightAt(vertexRow: r, vertexCol: c) + lift, z0))
            vertices.append(SCNVector3(x1, gameMap.vertexHeightAt(vertexRow: r, vertexCol: c + 1) + lift, z0))
            vertices.append(SCNVector3(x1, gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c + 1) + lift, z1))
            vertices.append(SCNVector3(x0, gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c) + lift, z1))
            let color = edge ? shore : deep
            for _ in 0..<4 { colors.append(contentsOf: color) }
            indices.append(contentsOf: [base, base + 2, base + 1, base, base + 3, base + 2])
        }
    }
    guard !vertices.isEmpty else { return nil }
    let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
    let colorSource = SCNGeometrySource(
        data: colorData,
        semantic: .color,
        vectorCount: colors.count / 3,
        usesFloatComponents: true,
        componentsPerVector: 3,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 3
    )
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices), colorSource],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(white: 1, alpha: 0.42)
    mat.lightingModel = .constant
    mat.isDoubleSided = true
    mat.writesToDepthBuffer = false
    mat.transparencyMode = .singleLayer
    geo.materials = [mat]
    return geo
}

/// Ćelije koje četkica pokriva (kockica: 1×1, 3×3, 5×5, 7×7).
private func brushCells(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, rows: Int, cols: Int) -> Set<MapCoordinate> {
    let r = brushOption.radius
    var cells: Set<MapCoordinate> = []
    for dr in -r...r {
        for dc in -r...r {
            let row = centerRow + dr
            let col = centerCol + dc
            guard row >= 0, row < rows, col >= 0, col < cols else { continue }
            if !brushOption.isSquare, dr * dr + dc * dc > r * r { continue }
            cells.insert(MapCoordinate(row: row, col: col))
        }
    }
    return cells
}

/// Sredina ćelije (row, col) u world koordinatama. 1 ćelija = 40 world jedinica.
private func worldPositionAtCell(row: Int, col: Int, rows: Int, cols: Int) -> SCNVector3 {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let x = CGFloat(col) * worldUnitsPerCell - halfW + worldUnitsPerCell / 2
    let z = CGFloat(row) * worldUnitsPerCell - halfH + worldUnitsPerCell / 2
    return SCNVector3(x, groundLevelY, z)
}

/// Ciljna točka poteza: mala svijetla točka na polju.
private func refreshMoveOrderMarker(
    _ node: SCNNode?,
    marker: MoveOrderMarker?,
    viewUnderground: Bool,
    rows: Int,
    cols: Int,
    gameMap: GameMap,
    lastKey: inout String?
) {
    guard let node else { return }
    let key: String?
    if let marker, (marker.layer == .underground) == viewUnderground {
        key = "\(marker.row)_\(marker.col)_\(marker.layer.rawValue)"
    } else {
        key = nil
    }
    if key == lastKey { return }
    lastKey = key
    node.childNodes.forEach { $0.removeFromParentNode() }
    guard let marker,
          (marker.layer == .underground) == viewUnderground,
          rows > 0, cols > 0,
          marker.row >= 0, marker.row < rows,
          marker.col >= 0, marker.col < cols else { return }

    let cell = MapScale.worldUnitsPerMapCell
    let halfW = MapScale.worldWidth(cols: cols) / 2
    let halfH = MapScale.worldHeight(rows: rows) / 2
    let x = CGFloat(marker.col) * cell - halfW + cell / 2
    let z = CGFloat(marker.row) * cell - halfH + cell / 2
    let ground = gameMap.vertexHeightAt(vertexRow: marker.row, vertexCol: marker.col)
    let yBase: CGFloat = marker.layer == .underground ? -Underground.depthMeters : ground

    let disc = SCNCylinder(radius: cell * 0.18, height: 0.06)
    let discMat = SCNMaterial()
    discMat.diffuse.contents = NSColor(red: 0.95, green: 0.92, blue: 0.35, alpha: 0.95)
    discMat.emission.contents = NSColor(red: 1, green: 0.95, blue: 0.4, alpha: 1)
    discMat.lightingModel = .constant
    disc.materials = [discMat]
    let discNode = SCNNode(geometry: disc)
    discNode.position = SCNVector3(x, yBase + 0.08, z)
    discNode.categoryBitMask = 1
    discNode.renderingOrder = 900
    node.addChildNode(discNode)

    let pin = SCNSphere(radius: cell * 0.1)
    let pinMat = SCNMaterial()
    pinMat.diffuse.contents = NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
    pinMat.emission.contents = NSColor(red: 1, green: 0.9, blue: 0.35, alpha: 1)
    pinMat.lightingModel = .constant
    pin.materials = [pinMat]
    let pinNode = SCNNode(geometry: pin)
    pinNode.position = SCNVector3(x, yBase + 0.28, z)
    pinNode.categoryBitMask = 1
    pinNode.renderingOrder = 901
    node.addChildNode(pinNode)

    pinNode.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.scale(to: 1.18, duration: 0.45),
        SCNAction.scale(to: 0.92, duration: 0.45)
    ])))
}

/// Kvadrat oznake vojske: samo lagana prozirna zelena ploha na tlu (bez gornjeg obruba).
private func refreshGroundMark(_ node: SCNNode?, origin: (row: Int, col: Int)?, far: (row: Int, col: Int)?, rows: Int, cols: Int, gameMap: GameMap?) {
    guard let node else { return }
    node.childNodes.forEach { $0.removeFromParentNode() }
    guard let origin, let far, rows > 0, cols > 0 else { return }
    let minR = min(max(0, min(origin.row, far.row)), rows - 1)
    let maxR = min(max(0, max(origin.row, far.row)), rows - 1)
    let minC = min(max(0, min(origin.col, far.col)), cols - 1)
    let maxC = min(max(0, max(origin.col, far.col)), cols - 1)
    var cells = Set<MapCoordinate>()
    for r in minR...maxR {
        for c in minC...maxC { cells.insert(MapCoordinate(row: r, col: c)) }
    }
    if let gameMap, let geo = makeGroundMarkGeometry(gameMap: gameMap, cells: cells, rows: rows, cols: cols) {
        let fill = SCNNode(geometry: geo)
        fill.name = "groundMarkFill"
        fill.categoryBitMask = 1
        fill.renderingOrder = 800
        node.addChildNode(fill)
    }
}

private func makeGroundMarkGeometry(gameMap: GameMap, cells: Set<MapCoordinate>, rows: Int, cols: Int) -> SCNGeometry? {
    guard !cells.isEmpty else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let lift: CGFloat = 0.1
    var vertices: [SCNVector3] = []
    var indices: [Int32] = []
    for coord in cells {
        guard coord.row >= 0, coord.row < rows, coord.col >= 0, coord.col < cols else { continue }
        let surface = gameMap.surface(row: coord.row, col: coord.col)
        let base = Int32(vertices.count)
        for point in surface.allPoints {
            vertices.append(SCNVector3(point.x * step - halfW, point.height + lift, point.z * step - halfH))
        }
        let center = base + 4
        indices.append(contentsOf: [base, center, base + 1, base + 1, center, base + 2, base + 2, center, base + 3, base + 3, center, base])
    }
    guard !vertices.isEmpty else { return nil }
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.22)
    mat.emission.contents = NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.08)
    mat.lightingModel = .constant
    mat.isDoubleSided = true
    mat.readsFromDepthBuffer = false
    mat.writesToDepthBuffer = false
    mat.transparencyMode = .singleLayer
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices)],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    geo.materials = [mat]
    return geo
}

/// Označavanje odabranih ćelija: površina (3D) koja prati teren.
/// `seaPreview` = plavo označavanje mora: vanjski kvadrat + unutarnji oblik (nacrt ili inset).
private func refreshCellSelectionOverlay(
    overlayNode: SCNNode,
    selectedCells: Set<MapCoordinate>,
    gameMap: GameMap,
    rows: Int,
    cols: Int,
    seaPreview: Bool = false,
    seaDraft: SeaSurfaceDraft? = nil,
    riverDraft: RiverPathDraft? = nil
) {
    overlayNode.childNodes.forEach { $0.removeFromParentNode() }
    if let draft = seaDraft {
        addSeaSurfaceDraftOverlay(
            to: overlayNode,
            draft: draft,
            gameMap: gameMap,
            rows: rows,
            cols: cols
        )
        return
    }
    if let river = riverDraft {
        addRiverPathDraftOverlay(
            to: overlayNode,
            draft: river,
            gameMap: gameMap,
            rows: rows,
            cols: cols
        )
        return
    }
    guard !selectedCells.isEmpty else { return }
    if seaPreview {
        addSeaSurfaceNestedSquares(
            to: overlayNode,
            cells: selectedCells,
            gameMap: gameMap,
            rows: rows,
            cols: cols
        )
        return
    }
    let diffuse = NSColor(calibratedRed: 0.45, green: 0.95, blue: 0.50, alpha: 0.65)
    let emission = NSColor(calibratedRed: 0.50, green: 1.0, blue: 0.55, alpha: 0.55)
    if let geo = makeSelectionSurfaceGeometry(
        gameMap: gameMap, cells: selectedCells, rows: rows, cols: cols,
        diffuse: diffuse,
        emission: emission,
        lift: 0.28
    ) {
        let node = SCNNode(geometry: geo)
        node.name = "cellSelection"
        node.categoryBitMask = 1
        node.renderingOrder = 900
        node.opacity = 1
        overlayNode.addChildNode(node)
    }
}

/// Tema uređivanja mora: žuta obala, plavo more, zelena crta + točke.
private enum SeaDraftTheme {
    static let coastFill = NSColor(calibratedRed: 0.95, green: 0.82, blue: 0.28, alpha: 0.78)
    static let coastEmit = NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.22, alpha: 0.45)
    static let seaFill = NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.95, alpha: 0.72)
    static let seaEmit = NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.0, alpha: 0.40)
    /// Zelena linija / točke — lagano prozirne.
    static let line = NSColor(calibratedRed: 0.25, green: 0.92, blue: 0.38, alpha: 0.78)
    static let lineEmit = NSColor(calibratedRed: 0.30, green: 0.95, blue: 0.42, alpha: 0.55)
    static let vertex = NSColor(calibratedRed: 0.28, green: 0.95, blue: 0.40, alpha: 0.82)
    static let mid = NSColor(calibratedRed: 0.22, green: 0.88, blue: 0.36, alpha: 0.70)
}

/// Površina mora iz nacrta: žuti vanjski (fiksno) + plavi = isti polygon kao zeleni obrub + točke na crti.
private func addSeaSurfaceDraftOverlay(
    to overlayNode: SCNNode,
    draft: SeaSurfaceDraft,
    gameMap: GameMap,
    rows: Int,
    cols: Int
) {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let bounds = (
        minRow: draft.outerMinRow, maxRow: draft.outerMaxRow,
        minCol: draft.outerMinCol, maxCol: draft.outerMaxCol
    )
    let x0 = CGFloat(bounds.minCol) * step - halfW
    let x1 = CGFloat(bounds.maxCol + 1) * step - halfW
    let z0 = CGFloat(bounds.minRow) * step - halfH
    let z1 = CGFloat(bounds.maxRow + 1) * step - halfH
    let y = seaOverlayHeight(gameMap: gameMap, bounds: bounds) + 0.28

    // 1) Žuti kvadrat (obala) — fiksni, ne miče se.
    addSeaOverlayQuad(
        to: overlayNode,
        name: "seaDraftCoast",
        xa: x0, xb: x1, za: z0, zb: z1, y: y,
        diffuse: SeaDraftTheme.coastFill,
        emission: SeaDraftTheme.coastEmit,
        order: 900
    )

    let outline = draft.innerOutlinePoints()
    guard outline.count >= 3 else { return }

    // Isti world vrhovi za plavo + zeleni obrub + točke.
    let fillY = y + 0.05
    let rimY = y + 0.14
    var fillVerts: [SCNVector3] = []
    var rimVerts: [SCNVector3] = []
    fillVerts.reserveCapacity(outline.count)
    rimVerts.reserveCapacity(outline.count)
    for pt in outline {
        let x = pt.col * step - halfW
        let z = pt.row * step - halfH
        fillVerts.append(SCNVector3(x, fillY, z))
        rimVerts.append(SCNVector3(x, rimY, z))
    }

    // 2) Jedan plavi polygon — rubovi = zeleni obrub (ne odvojen fill).
    addSeaDraftPolygonFill(to: overlayNode, vertices: fillVerts)

    // 3) Prozirno-zeleni obrub točno na rubu plavog.
    let lineThickness = max(step * 0.07, 0.4)
    for i in 0..<rimVerts.count {
        let a = rimVerts[i]
        let b = rimVerts[(i + 1) % rimVerts.count]
        addSeaDraftEdgeLine(to: overlayNode, from: a, to: b, thickness: lineThickness)
    }

    // 4) Točke na pola / uglovima — ista Y kao obrub.
    addSeaSurfaceHandles(
        to: overlayNode,
        draft: draft,
        y: rimY,
        halfW: halfW,
        halfH: halfH,
        step: step
    )
}

/// Jedan plavi fill iz istih vrhova kao obrub (bez ćelijskih „trokuta”).
private func addSeaDraftPolygonFill(to overlayNode: SCNNode, vertices: [SCNVector3]) {
    guard vertices.count >= 3 else { return }
    var cx: CGFloat = 0, cy: CGFloat = 0, cz: CGFloat = 0
    for v in vertices {
        cx += CGFloat(v.x); cy += CGFloat(v.y); cz += CGFloat(v.z)
    }
    let inv = 1 / CGFloat(vertices.count)
    let centroid = SCNVector3(cx * inv, cy * inv, cz * inv)
    let fanVerts = [centroid] + vertices
    var fanIdx: [Int32] = []
    for i in 0..<vertices.count {
        fanIdx.append(contentsOf: [0, Int32(i + 1), Int32((i + 1) % vertices.count + 1)])
    }
    let mat = SCNMaterial()
    // Neprozirni diffuse + transparency — bez dvostrukog alpha blendanja trokuta.
    mat.diffuse.contents = NSColor(calibratedRed: 0.15, green: 0.52, blue: 0.98, alpha: 1)
    mat.emission.contents = NSColor(calibratedRed: 0.18, green: 0.55, blue: 1.0, alpha: 1)
    mat.transparency = 0.38
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.transparencyMode = .aOne
    mat.writesToDepthBuffer = true
    mat.readsFromDepthBuffer = true
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: fanVerts)],
        elements: [SCNGeometryElement(indices: fanIdx, primitiveType: .triangles)]
    )
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    node.name = "seaDraftWater"
    node.categoryBitMask = 1
    node.renderingOrder = 901
    overlayNode.addChildNode(node)
}

private func addSeaDraftEdgeLine(
    to overlayNode: SCNNode,
    from: SCNVector3,
    to: SCNVector3,
    thickness: CGFloat
) {
    let dx = CGFloat(to.x - from.x)
    let dy = CGFloat(to.y - from.y)
    let dz = CGFloat(to.z - from.z)
    let len = sqrt(dx * dx + dy * dy + dz * dz)
    guard len > 0.02 else { return }
    // Box: length uz lokalni Z — look(at:) s localFront Z pouzdano leži u XZ.
    let box = SCNBox(width: thickness, height: thickness * 0.55, length: len, chamferRadius: thickness * 0.15)
    let mat = SCNMaterial()
    mat.diffuse.contents = SeaDraftTheme.line
    mat.emission.contents = SeaDraftTheme.lineEmit
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.transparencyMode = .singleLayer
    mat.writesToDepthBuffer = false
    mat.readsFromDepthBuffer = false
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.name = "seaDraftEdge"
    node.categoryBitMask = 0
    node.renderingOrder = 920
    node.position = SCNVector3(
        (CGFloat(from.x) + CGFloat(to.x)) * 0.5,
        (CGFloat(from.y) + CGFloat(to.y)) * 0.5,
        (CGFloat(from.z) + CGFloat(to.z)) * 0.5
    )
    node.look(
        at: SCNVector3(CGFloat(to.x), CGFloat(to.y), CGFloat(to.z)),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, 1)
    )
    overlayNode.addChildNode(node)
}

private func addSeaSurfaceHandles(
    to overlayNode: SCNNode,
    draft: SeaSurfaceDraft,
    y: CGFloat,
    halfW: CGFloat,
    halfH: CGFloat,
    step: CGFloat
) {
    for handle in draft.controlHandles() {
        let radius: CGFloat
        let color: NSColor
        switch handle.kind {
        case .vertex:
            radius = step * 0.14
            color = SeaDraftTheme.vertex
        case .mid:
            radius = step * 0.09
            color = SeaDraftTheme.mid
        }
        let sphere = SCNSphere(radius: radius)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = SeaDraftTheme.lineEmit
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        mat.transparencyMode = .singleLayer
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = false
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        node.name = handle.nodeName
        node.categoryBitMask = 1
        node.renderingOrder = 950
        let x = handle.col * step - halfW
        let z = handle.row * step - halfH
        node.position = SCNVector3(x, y, z)
        overlayNode.addChildNode(node)

        // Tanki zeleni obruč.
        let ring = SCNTube(innerRadius: radius * 1.15, outerRadius: radius * 1.35, height: radius * 0.1)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = SeaDraftTheme.line.withAlphaComponent(0.55)
        ringMat.emission.contents = SeaDraftTheme.lineEmit.withAlphaComponent(0.40)
        ringMat.lightingModel = .constant
        ringMat.blendMode = .alpha
        ringMat.transparencyMode = .singleLayer
        ringMat.writesToDepthBuffer = false
        ringMat.readsFromDepthBuffer = false
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = .pi / 2
        ringNode.categoryBitMask = 0
        ringNode.renderingOrder = 951
        node.addChildNode(ringNode)
    }
}

/// Nacrt rijeke: traka širine + središnja crta + točke (vrhovi / mid).
private func addRiverPathDraftOverlay(
    to overlayNode: SCNNode,
    draft: RiverPathDraft,
    gameMap: GameMap,
    rows: Int,
    cols: Int
) {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let center = draft.sampledCenterline(samplesPerSegment: 14)
    guard center.count >= 2 else { return }
    let minR = Int(floor(center.map(\.row).min()!))
    let maxR = Int(ceil(center.map(\.row).max()!))
    let minC = Int(floor(center.map(\.col).min()!))
    let maxC = Int(ceil(center.map(\.col).max()!))
    let y = seaOverlayHeight(
        gameMap: gameMap,
        bounds: (
            minRow: max(0, minR), maxRow: min(rows - 1, maxR),
            minCol: max(0, minC), maxCol: min(cols - 1, maxC)
        )
    ) + 0.3
    let ribbonY = y
    let lineY = y + 0.08

    func xz(_ row: CGFloat, _ col: CGFloat) -> (CGFloat, CGFloat) {
        (col * step - halfW, row * step - halfH)
    }

    let (fillDiffuse, fillEmit, riverLine, riverEmit): (NSColor, NSColor, NSColor, NSColor) = {
        switch draft.pad {
        case .mocvara:
            return (
                NSColor(calibratedRed: 0.32, green: 0.52, blue: 0.22, alpha: 0.50),
                NSColor(calibratedRed: 0.40, green: 0.62, blue: 0.28, alpha: 0.30),
                NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.35, alpha: 0.85),
                NSColor(calibratedRed: 0.60, green: 0.95, blue: 0.40, alpha: 0.55)
            )
        case .jezero:
            return (
                NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.90, alpha: 0.48),
                NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.0, alpha: 0.30),
                NSColor(calibratedRed: 0.25, green: 0.75, blue: 1.0, alpha: 0.85),
                NSColor(calibratedRed: 0.30, green: 0.85, blue: 1.0, alpha: 0.55)
            )
        default: // rijeka
            return (
                NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.95, alpha: 0.45),
                NSColor(calibratedRed: 0.25, green: 0.70, blue: 1.0, alpha: 0.28),
                NSColor(calibratedRed: 0.15, green: 0.85, blue: 0.55, alpha: 0.80),
                NSColor(calibratedRed: 0.20, green: 0.95, blue: 0.60, alpha: 0.55)
            )
        }
    }()

    // Traka širine (područje vode).
    let (left, right) = draft.ribbonEdges(samplesPerSegment: 14)
    if left.count >= 2, right.count == left.count {
        var verts: [SCNVector3] = []
        var idx: [Int32] = []
        for i in 0..<left.count {
            let (lx, lz) = xz(left[i].0, left[i].1)
            let (rx, rz) = xz(right[i].0, right[i].1)
            verts.append(SCNVector3(lx, ribbonY, lz))
            verts.append(SCNVector3(rx, ribbonY, rz))
        }
        for i in 0..<(left.count - 1) {
            let b = Int32(i * 2)
            idx.append(contentsOf: [b, b + 1, b + 3, b, b + 3, b + 2])
        }
        let mat = SCNMaterial()
        mat.diffuse.contents = fillDiffuse
        mat.emission.contents = fillEmit
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        mat.transparencyMode = .singleLayer
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = false
        mat.isDoubleSided = true
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: verts)],
            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)]
        )
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.name = "riverDraftRibbon"
        node.categoryBitMask = 1
        node.renderingOrder = 900
        overlayNode.addChildNode(node)
    }

    // Središnja crta.
    let lineThickness = max(step * 0.06, 0.35)
    for i in 0..<(center.count - 1) {
        let (x0, z0) = xz(center[i].row, center[i].col)
        let (x1, z1) = xz(center[i + 1].row, center[i + 1].col)
        addColoredEdgeLine(
            to: overlayNode,
            name: "riverDraftEdge",
            from: SCNVector3(x0, lineY, z0),
            to: SCNVector3(x1, lineY, z1),
            thickness: lineThickness,
            diffuse: riverLine,
            emission: riverEmit
        )
    }

    // Točke.
    for handle in draft.controlHandles() {
        let radius = handle.kind == .vertex ? step * 0.14 : step * 0.09
        let sphere = SCNSphere(radius: radius)
        let mat = SCNMaterial()
        mat.diffuse.contents = riverLine
        mat.emission.contents = riverEmit
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        mat.transparencyMode = .singleLayer
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = false
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        node.name = handle.nodeName
        node.categoryBitMask = 1
        node.renderingOrder = 950
        let (x, z) = xz(handle.row, handle.col)
        node.position = SCNVector3(x, lineY, z)
        overlayNode.addChildNode(node)
    }
}

private func addColoredEdgeLine(
    to overlayNode: SCNNode,
    name: String,
    from: SCNVector3,
    to: SCNVector3,
    thickness: CGFloat,
    diffuse: NSColor,
    emission: NSColor
) {
    let dx = CGFloat(to.x - from.x)
    let dy = CGFloat(to.y - from.y)
    let dz = CGFloat(to.z - from.z)
    let len = sqrt(dx * dx + dy * dy + dz * dz)
    guard len > 0.02 else { return }
    let box = SCNBox(width: thickness, height: thickness * 0.55, length: len, chamferRadius: thickness * 0.15)
    let mat = SCNMaterial()
    mat.diffuse.contents = diffuse
    mat.emission.contents = emission
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.transparencyMode = .singleLayer
    mat.writesToDepthBuffer = false
    mat.readsFromDepthBuffer = false
    box.materials = [mat]
    let node = SCNNode(geometry: box)
    node.name = name
    node.categoryBitMask = 0
    node.renderingOrder = 920
    node.position = SCNVector3(
        (CGFloat(from.x) + CGFloat(to.x)) * 0.5,
        (CGFloat(from.y) + CGFloat(to.y)) * 0.5,
        (CGFloat(from.z) + CGFloat(to.z)) * 0.5
    )
    node.look(
        at: SCNVector3(CGFloat(to.x), CGFloat(to.y), CGFloat(to.z)),
        up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, 1)
    )
    overlayNode.addChildNode(node)
}

/// Površina mora: vanjski kvadrat = obala/plaža, unutarnji = more (tijekom drag previewa).
private func addSeaSurfaceNestedSquares(
    to overlayNode: SCNNode,
    cells: Set<MapCoordinate>,
    gameMap: GameMap,
    rows: Int,
    cols: Int
) {
    guard let bounds = seaCellsBoundingBox(cells, rows: rows, cols: cols) else { return }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell

    let x0 = CGFloat(bounds.minCol) * step - halfW
    let x1 = CGFloat(bounds.maxCol + 1) * step - halfW
    let z0 = CGFloat(bounds.minRow) * step - halfH
    let z1 = CGFloat(bounds.maxRow + 1) * step - halfH

    let y = seaOverlayHeight(gameMap: gameMap, bounds: bounds) + 0.28
    let (inner, hasInner) = seaInnerCellBounds(bounds)
    let ix0: CGFloat
    let ix1: CGFloat
    let iz0: CGFloat
    let iz1: CGFloat
    if hasInner {
        ix0 = CGFloat(inner.minCol) * step - halfW
        ix1 = CGFloat(inner.maxCol + 1) * step - halfW
        iz0 = CGFloat(inner.minRow) * step - halfH
        iz1 = CGFloat(inner.maxRow + 1) * step - halfH
    } else {
        // Premalo za prsten obale — samo prikaži more (mali uvučeni kvadrat).
        let inset = max(step * 0.15, min(x1 - x0, z1 - z0) * 0.2)
        ix0 = x0 + inset
        ix1 = x1 - inset
        iz0 = z0 + inset
        iz1 = z1 - inset
    }

    // Vanjski = žuta obala.
    addSeaOverlayQuad(
        to: overlayNode,
        name: "seaPaintCoast",
        xa: x0, xb: x1, za: z0, zb: z1, y: y,
        diffuse: SeaDraftTheme.coastFill,
        emission: SeaDraftTheme.coastEmit,
        order: 900
    )
    // Unutarnji = plavo more (blizu žutog).
    addSeaOverlayQuad(
        to: overlayNode,
        name: "seaPaintWater",
        xa: ix0, xb: ix1, za: iz0, zb: iz1, y: y + 0.06,
        diffuse: SeaDraftTheme.seaFill,
        emission: SeaDraftTheme.seaEmit,
        order: 901
    )
}

private func addSeaOverlayQuad(
    to overlayNode: SCNNode,
    name: String,
    xa: CGFloat, xb: CGFloat, za: CGFloat, zb: CGFloat, y: CGFloat,
    diffuse: NSColor, emission: NSColor, order: Int
) {
    guard xb - xa > 0.05, zb - za > 0.05 else { return }
    let vertices: [SCNVector3] = [
        SCNVector3(xa, y, za),
        SCNVector3(xa, y, zb),
        SCNVector3(xb, y, zb),
        SCNVector3(xb, y, za)
    ]
    let indices: [Int32] = [0, 1, 2, 0, 2, 3]
    let mat = SCNMaterial()
    mat.diffuse.contents = diffuse
    mat.emission.contents = emission
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.transparencyMode = .singleLayer
    mat.writesToDepthBuffer = false
    mat.readsFromDepthBuffer = false
    let geo = SCNGeometry(
        sources: [SCNGeometrySource(vertices: vertices)],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    node.name = name
    node.categoryBitMask = 1
    node.renderingOrder = order
    overlayNode.addChildNode(node)
}

/// Unutarnji pravokutnik ćelija (more); prsten oko njega = obala. `hasInner` false ako je područje premalo.
private func seaInnerCellBounds(
    _ bounds: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)
) -> (inner: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int), hasInner: Bool) {
    let w = bounds.maxCol - bounds.minCol + 1
    let h = bounds.maxRow - bounds.minRow + 1
    // Plavo jako blizu žutog — obala ≈ 1 ćelija.
    let inset = (w >= 3 && h >= 3) ? 1 : 0
    let iMinR = bounds.minRow + inset
    let iMaxR = bounds.maxRow - inset
    let iMinC = bounds.minCol + inset
    let iMaxC = bounds.maxCol - inset
    guard iMinR <= iMaxR, iMinC <= iMaxC else {
        return (bounds, false)
    }
    return ((iMinR, iMaxR, iMinC, iMaxC), true)
}

private func seaCellsBoundingBox(_ cells: Set<MapCoordinate>, rows: Int, cols: Int)
    -> (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)? {
    guard !cells.isEmpty else { return nil }
    var minR = Int.max, maxR = Int.min, minC = Int.max, maxC = Int.min
    for cell in cells {
        guard cell.row >= 0, cell.row < rows, cell.col >= 0, cell.col < cols else { continue }
        minR = min(minR, cell.row)
        maxR = max(maxR, cell.row)
        minC = min(minC, cell.col)
        maxC = max(maxC, cell.col)
    }
    guard minR <= maxR, minC <= maxC else { return nil }
    return (minR, maxR, minC, maxC)
}

private func seaOverlayHeight(
    gameMap: GameMap,
    bounds: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)
) -> CGFloat {
    var sum: CGFloat = 0
    var n = 0
    for r in bounds.minRow...bounds.maxRow {
        for c in bounds.minCol...bounds.maxCol {
            let s = gameMap.surface(row: r, col: c)
            sum += s.center.height
            n += 1
        }
    }
    return n > 0 ? sum / CGFloat(n) : 0
}

private func applyRenderQuality(to scnView: SCNView, gameState: GameState) {
    switch gameState.graphicsQuality {
    case .low: scnView.antialiasingMode = .none
    case .medium: scnView.antialiasingMode = .multisampling2X
    case .high, .ultra: scnView.antialiasingMode = .multisampling4X
    }
    if gameState.powerMode || gameState.graphicsQuality == .low {
        scnView.preferredFramesPerSecond = 30
    } else if gameState.graphicsQuality == .ultra, !gameState.vsyncEnabled {
        scnView.preferredFramesPerSecond = 120
    } else {
        scnView.preferredFramesPerSecond = 60
    }
}

// MARK: - SceneKitMapView (SwiftUI)
struct SceneKitMapView: NSViewRepresentable {
    @EnvironmentObject private var gameState: GameState
    var showGrid: Bool = true
    /// Map Editor: prikaži mrežu 10×10 (može zajedno s 40×40).
    var gridShow10: Bool = true
    /// Map Editor: prikaži mrežu 40×40 (može zajedno s 10×10).
    var gridShow40: Bool = false
    /// Map Editor: prikaži kugle na sjecištima (gumb Kugle).
    @Binding var handPanMode: Bool
    var showPivotIndicator: Bool = false
    var isEraseMode: Bool = false
    var onRemoveAt: ((Int, Int) -> Void)?
    /// Map Editor – alat Teren: kad true, klik primjenjuje elevaciju (Podigni za 5/10, Izravnaj).
    var isTerrainEditMode: Bool = false
    var terrainTool: TerrainToolOption? = nil
    var terrainBrushOption: TerrainBrushOption? = nil
    var onTerrainEdit: ((Int, Int) -> Void)? = nil
    /// Map Editor – klik primjenjuje četkicu (kockica 1×1, 3×3, 5×5, 7×7).
    var onTerrainAddBrushSelection: ((Int, Int) -> Void)? = nil
    /// Map Editor – click-drag: pregled pravokutnika (r0,c0,r1,c1).
    var onTerrainPaintPreview: ((Int, Int, Int, Int) -> Void)? = nil
    /// Map Editor – click-drag: primjena na pravokutnik.
    var onTerrainPaintCommit: ((Int, Int, Int, Int) -> Void)? = nil
    /// Kad true, overlay označenog područja je more-plav (alat More).
    var terrainPaintSeaPreview: Bool = false
    /// Map Editor – mod „Odabir ćelija”: klik uključuje/isključuje ćeliju u označene (toggle).
    var onCellSelectionToggle: ((Int, Int) -> Void)? = nil
    /// Map Editor – mod „Odabir ćelija”: klik označuje/uklanja jednu ćeliju (precizno).
    var isCellSelectionMode: Bool = false
    /// Map Editor – klik na kuglu (točku sjecišta) označi taj vrh za gore/dolje (samo ta točka).
    var onVertexDotSelected: ((Int, Int) -> Void)? = nil
    /// Map Editor – dvoprstni/desni klik izlazi iz alata Teren (elevator).
    var onExitTerrainEditMode: (() -> Void)? = nil
    /// Map Editor – obojeni sloj preko terena (teren, podloge, naslage, gradnja, kretanje).
    var editorOverlayMode: MapEditorPaintMode? = nil
    /// Map Editor – istaknuto početno mjesto AI lorda.
    var selectedLordStartSlot: Int? = nil
    /// Map Editor – klik na ćeliju kad nije paint/place/erase (npr. otvori editor mora).
    var onMapEditorCellTap: ((Int, Int) -> Void)? = nil
    var isPlaceMode: Bool { gameState.selectedPlacementObjectId != nil }

    /// U Map Editoru: jedna ili obje mreže (10×10, 40×40); kad obje isključene, nema mreže.
    private var isMapEditorGridMode: Bool { gameState.isMapEditorMode }

    /// Vraća proceduralnu teksturu terena za pred-učitavanje (paralelni loader). Može se zvati s background threada.
    static func createTerrainTextureForPreload() -> Any? {
        makeTerrainTexture()
    }

    /// Spremi proceduralnu teksturu terena u PNG na zadani URL (fallback kad nema čvora).
    static func exportTerrainTexture(to url: URL) -> Bool {
        guard let cg = makeTerrainCGImage() else { return false }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = NSSize(width: cg.width, height: cg.height)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// Spremi teksturu s teren čvora u PNG (voda/vegetacija/zemlja već na materijalu). Koristi se pri spremanju SoloLevel.scn.
    static func exportTerrainTextureFromNode(_ terrainNode: SCNNode, to url: URL) -> Bool {
        guard let mat = terrainNode.geometry?.materials.first,
              let contents = mat.diffuse.contents else { return exportTerrainTexture(to: url) }
        if let img = contents as? NSImage, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: cg.width, height: cg.height)
            guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return false }
            do {
                try data.write(to: url)
                return true
            } catch {
                return false
            }
        }
        if let skTex = contents as? SKTexture {
            let cg = skTex.cgImage()
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: cg.width, height: cg.height)
            guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return false }
            do {
                try data.write(to: url)
                return true
            } catch {
                return false
            }
        }
        return exportTerrainTexture(to: url)
    }

    /// Pred-učitanje (legacy) – preferiraj GameAssetLoader.loadAll() koji radi paralelno s progressom.
    static func preloadGameAssets() {
        Task { await GameAssetLoader.shared.loadAllIfNeeded() }
    }

    private func setupSceneAndTerrain(into scene: SCNScene, loader: GameAssetLoader, terrainTexture: Any?) {
        let terrainTextureOnMainThread = terrainTexture
        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        var level: LoadedLevel?
        // Solo i mapa iz datoteke: teren iz ćelija, podloga je tlo.
        if gameState.isSoloMode && !gameState.isMapEditorMode {
            let terrain = makeHeightTerrainNode(gameMap: gameState.gameMap)
            terrain.position = SCNVector3Zero
            scene.rootNode.addChildNode(terrain)
            return
        }
        // Map Editor: nikad ne koristiti cache level – teren mora biti točno rows×cols s 40×40 world jedinicama po ćeliji.
        let useCachedLevel = gameState.isSoloMode && !gameState.isMapEditorMode
        if useCachedLevel {
            if loader.isLoaded, let cached = loader.cachedLevel() {
                level = cached
            } else {
                level = SceneKitLevelLoader.loadForSoloMode(bundleLevelName: gameState.currentLevelName, bundle: .main)
                if level == nil {
                    let w = effectiveMapWorldW(cols: cols)
                    let h = effectiveMapWorldH(rows: rows)
                    let proceduralTerrain = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread, gameMap: gameState.gameMap)
                    level = SceneKitLevelLoader.generateAndSaveSoloLevel(terrainNode: proceduralTerrain)
                }
            }
        } else if gameState.isMapEditorMode {
            // Uvijek proceduralni teren: cols×40 (X) × rows×40 (Z) world jedinica. 1 ćelija = 40×40.
            // Ne mijenjati eulerAngles – makeProceduralTerrainNode postavlja eulerAngles.x = -π/2 da ravnina leži u XZ (inače bi stajala pod 90°).
            let w = effectiveMapWorldW(cols: cols)
            let h = effectiveMapWorldH(rows: rows)
            let proceduralTerrain = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread, gameMap: gameState.gameMap)
            proceduralTerrain.position = SCNVector3Zero
            scene.rootNode.addChildNode(proceduralTerrain)
            return
        } else {
            level = gameState.currentLevelName.flatMap { SceneKitLevelLoader.load(name: $0, bundle: .main) }
        }
        if let level = level {
            level.levelRoot.position = SCNVector3Zero
            level.levelRoot.eulerAngles = SCNVector3Zero
            fixLoadedTerrainOrientationAndMaterial(level.levelRoot)
            centerTerrainOnMapOrigin(level.levelRoot)
            scene.rootNode.addChildNode(level.levelRoot)
            if level.terrainNode == nil {
                let w = effectiveMapWorldW(cols: cols)
                let h = effectiveMapWorldH(rows: rows)
                let fallbackPlane = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread, gameMap: gameState.gameMap)
                scene.rootNode.addChildNode(fallbackPlane)
            }
        } else {
            let w = effectiveMapWorldW(cols: cols)
            let h = effectiveMapWorldH(rows: rows)
            let planeNode = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread, gameMap: gameState.gameMap)
            scene.rootNode.addChildNode(planeNode)
        }
    }

    private func setupGridNode(zoom: CGFloat, gridDivisions: Int, mapWidth: CGFloat, mapHeight: CGFloat, gameMap: GameMap? = nil, rows: Int? = nil, cols: Int? = nil) -> SCNNode {
        let gridNode = SCNNode()
        gridNode.name = "grid"
        gridNode.categoryBitMask = 1
        gridNode.position = SCNVector3Zero
        gridNode.eulerAngles = SCNVector3Zero
        /// Mreža se crta iznad terena da ne prekrije teksturu u Map Builderu.
        gridNode.renderingOrder = 100
        refreshGrid(gridNode: gridNode, zoom: zoom, gridDivisions: gridDivisions, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameMap, rows: rows, cols: cols)
        return gridNode
    }

    private func setupCameraAndLights(in scene: SCNScene, halfW: CGFloat, halfH: CGFloat) -> (SCNNode, SCNNode, SCNNode) {
        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 500000
        let cameraNode = SCNNode()
        cameraNode.camera = cam
        cameraNode.name = "camera"
        let cameraTarget = SCNNode()
        cameraTarget.name = "cameraTarget"
        cameraTarget.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraTarget)

        let pivotIndicator = makePivotIndicatorNode()
        pivotIndicator.name = "pivotIndicator"
        scene.rootNode.addChildNode(pivotIndicator)

        scene.rootNode.addChildNode(cameraNode)
        let lookAt = SCNLookAtConstraint(target: cameraTarget)
        lookAt.isGimbalLockEnabled = true
        lookAt.worldUp = SCNVector3(0, 1, 0)
        cameraNode.constraints = [lookAt]

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .directional
        light.light?.intensity = 900
        light.eulerAngles = SCNVector3(-CGFloat.pi / 3, CGFloat.pi / 5, 0)
        light.position = SCNVector3(halfW, 3000, halfH)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 700
        scene.rootNode.addChildNode(ambient)

        return (cameraNode, cameraTarget, pivotIndicator)
    }

    private func setupPlacementTemplatesAndGhosts(coord: Coordinator, scene: SCNScene, loader: GameAssetLoader) {
        for config in SceneKitPlacementRegistry.allConfigs {
            // Wall uvijek gradimo svježe (bez cachea) da ne ostane stari minijaturni node.
            let useCache = !WallParent.isWall(objectId: config.objectId)
            let cachedRaw = (loader.isLoaded && useCache) ? loader.cachedPlacementNode(objectId: config.objectId) : nil
            let cachedNode = cachedRaw?.clone()
            let (template, ghost) = makeTemplateAndGhost(config: config, cachedNode: cachedNode)
            if let t = template {
                coord.placementTemplates[config.objectId] = t
            }
            coord.ghostNodes[config.objectId] = ghost
            ghost.isHidden = true
            ghost.categoryBitMask = 0
            ghost.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghost)
        }
    }

    func makeNSView(context: Context) -> NSView {
        let container = SceneKitMapNSView()
        container.wantsLayer = true
        let scnView = SCNView()
        scnView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scnView)
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: container.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.scnView = scnView
        NotificationCenter.default.addObserver(container, selector: #selector(SceneKitMapNSView.stopScene), name: .feudalismStopMapScene, object: nil)

        scnView.wantsLayer = true
        scnView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        scnView.backgroundColor = NSColor(white: 0.15, alpha: 1)
        scnView.allowsCameraControl = false
        applyRenderQuality(to: scnView, gameState: gameState)

        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        let mapWidth = effectiveMapWorldW(cols: cols)
        let mapHeight = effectiveMapWorldH(rows: rows)
        let halfW = mapWidth / 2
        let halfH = mapHeight / 2

        let scene = SCNScene()
        scene.rootNode.position = SCNVector3Zero
        scene.rootNode.eulerAngles = SCNVector3Zero

        let loader = GameAssetLoader.shared
        setupSceneAndTerrain(into: scene, loader: loader, terrainTexture: nil)

        let coord = context.coordinator
        container.onWillDetach = { [weak coord] in coord?.retired = true }
        let zoom = gameState.mapCameraSettings.currentZoom
        let div40 = gridDivisionsBuilding(rows: rows, cols: cols)
        let div10 = gridDivisionsDisplay(rows: rows, cols: cols)
        if isMapEditorGridMode {
            if gridShow10 {
                let n10 = setupGridNode(zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
                n10.name = "grid10"
                scene.rootNode.addChildNode(n10)
                coord.gridNode10 = n10
            } else { coord.gridNode10 = nil }
            if gridShow40 {
                let n40 = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
                n40.name = "grid40"
                scene.rootNode.addChildNode(n40)
                coord.gridNode40 = n40
            } else { coord.gridNode40 = nil }
            coord.gridNode = nil
        } else {
            let gridNode = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
            scene.rootNode.addChildNode(gridNode)
            coord.gridNode = gridNode
            coord.gridNode10 = nil
            coord.gridNode40 = nil
        }

        let placementsNode = SCNNode()
        placementsNode.name = "placements"
        placementsNode.position = SCNVector3Zero
        placementsNode.eulerAngles = SCNVector3Zero
        placementsNode.categoryBitMask = 0
        scene.rootNode.addChildNode(placementsNode)
        let surfacePlacementsNode = SCNNode()
        surfacePlacementsNode.name = "surfacePlacements"
        surfacePlacementsNode.categoryBitMask = 0
        scene.rootNode.addChildNode(surfacePlacementsNode)
        coord.surfacePlacementsNode = surfacePlacementsNode
        let seatsNode = SCNNode()
        seatsNode.name = "realmSeats"
        seatsNode.categoryBitMask = 1
        scene.rootNode.addChildNode(seatsNode)
        coord.seatsNode = seatsNode
        let peopleNode = SCNNode()
        peopleNode.name = "people"
        peopleNode.categoryBitMask = 1
        scene.rootNode.addChildNode(peopleNode)
        coord.peopleNode = peopleNode
        let transportNode = SCNNode()
        transportNode.name = "transport"
        transportNode.categoryBitMask = 1
        scene.rootNode.addChildNode(transportNode)
        coord.transportNode = transportNode
        let warehouseNode = SCNNode()
        warehouseNode.name = "warehouse"
        warehouseNode.categoryBitMask = 1
        scene.rootNode.addChildNode(warehouseNode)
        coord.warehouseNode = warehouseNode
        let buildingAlertsNode = SCNNode()
        buildingAlertsNode.name = "buildingAlerts"
        buildingAlertsNode.categoryBitMask = 1
        scene.rootNode.addChildNode(buildingAlertsNode)
        coord.buildingAlertsNode = buildingAlertsNode
        let wallLinePreviewNode = SCNNode()
        wallLinePreviewNode.name = "wallLinePreview"
        wallLinePreviewNode.position = SCNVector3Zero
        wallLinePreviewNode.eulerAngles = SCNVector3Zero
        wallLinePreviewNode.categoryBitMask = 0
        scene.rootNode.addChildNode(wallLinePreviewNode)
        let groundMarkNode = SCNNode()
        groundMarkNode.name = "groundMark"
        groundMarkNode.categoryBitMask = 1
        scene.rootNode.addChildNode(groundMarkNode)
        let moveOrderMarkerNode = SCNNode()
        moveOrderMarkerNode.name = "moveOrderMarker"
        moveOrderMarkerNode.categoryBitMask = 1
        scene.rootNode.addChildNode(moveOrderMarkerNode)
        let undergroundNode = Underground.makeLayer(mapWidth: mapWidth, mapLength: mapHeight)
        scene.rootNode.addChildNode(undergroundNode)
        coord.undergroundNode = undergroundNode

        let (cameraNode, cameraTarget, pivotIndicator) = setupCameraAndLights(in: scene, halfW: halfW, halfH: halfH)
        scnView.pointOfView = cameraNode

        coord.scene = scene
        coord.placementsNode = placementsNode
        coord.cameraNode = cameraNode
        coord.cameraTarget = cameraTarget
        coord.pivotIndicatorNode = pivotIndicator
        coord.wallLinePreviewNode = wallLinePreviewNode
        coord.groundMarkNode = groundMarkNode
        coord.moveOrderMarkerNode = moveOrderMarkerNode
        coord.mapRows = rows
        coord.mapCols = cols
        setupPlacementTemplatesAndGhosts(coord: coord, scene: scene, loader: loader)

        let opt = terrainBrushOption ?? .size1
        let brushPreviewOverlay = SCNNode()
        brushPreviewOverlay.name = "brushPreviewOverlay"
        brushPreviewOverlay.renderingOrder = 400
        scene.rootNode.addChildNode(brushPreviewOverlay)
        coord.brushPreviewOverlayNode = brushPreviewOverlay
        coord.terrainBrushOption = opt
        coord.isTerrainEditMode = isTerrainEditMode

        let cellSelectionOverlay = SCNNode()
        cellSelectionOverlay.name = "cellSelectionOverlay"
        cellSelectionOverlay.renderingOrder = 900
        cellSelectionOverlay.categoryBitMask = 1
        scene.rootNode.addChildNode(cellSelectionOverlay)
        coord.cellSelectionOverlayNode = cellSelectionOverlay

        let groundwaterOverlay = SCNNode()
        groundwaterOverlay.name = "groundwaterOverlay"
        groundwaterOverlay.renderingOrder = 350
        groundwaterOverlay.isHidden = true
        groundwaterOverlay.opacity = 0
        scene.rootNode.addChildNode(groundwaterOverlay)
        coord.groundwaterOverlayNode = groundwaterOverlay

        let editorCellOverlay = SCNNode()
        editorCellOverlay.name = "editorCellOverlay"
        editorCellOverlay.renderingOrder = 360
        editorCellOverlay.isHidden = true
        scene.rootNode.addChildNode(editorCellOverlay)
        coord.editorCellOverlayNode = editorCellOverlay

        let buildPadOverlay = SCNNode()
        buildPadOverlay.name = "buildPadOverlay"
        buildPadOverlay.renderingOrder = 355
        buildPadOverlay.categoryBitMask = 1
        buildPadOverlay.isHidden = true
        scene.rootNode.addChildNode(buildPadOverlay)
        coord.buildPadOverlayNode = buildPadOverlay

        let lordStarts = SCNNode()
        lordStarts.name = "lordStartMarkers"
        lordStarts.isHidden = true
        scene.rootNode.addChildNode(lordStarts)
        coord.lordStartsNode = lordStarts

        coord.lastGridZoom = CGFloat(gameState.mapCameraSettings.currentZoom)

        container.onCellHit = { [rows, cols] worldPos in
            cellFromMapLocalPosition(worldPos, rows: rows, cols: cols)
        }

        container.onMouseMove = { [weak container, gameState, rows, cols] loc in
            if coord.isTerrainEditMode, let overlayNode = coord.brushPreviewOverlayNode, let option = coord.terrainBrushOption, let container, let sv = container.scnView {
                let ptInView = container.convert(loc, to: sv)
                let inBounds = sv.bounds.contains(ptInView)
                var centerRow = rows / 2
                var centerCol = cols / 2
                if inBounds {
                    let hitOptions: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue]
                    let hits = sv.hitTest(ptInView, options: hitOptions)
                    let terrainHit = hits.first(where: { $0.node.name == "terrain" })
                    if let hit = terrainHit, let cell = cellFromMapLocalPosition(hit.worldCoordinates, rows: rows, cols: cols) {
                        centerRow = cell.row
                        centerCol = cell.col
                    }
                }
                let cells = brushCells(centerRow: centerRow, centerCol: centerCol, brushOption: option, rows: rows, cols: cols)
                if let geo = makeGreenSurfaceGeometry(gameMap: gameState.gameMap, cells: cells, rows: rows, cols: cols) {
                    overlayNode.geometry = geo
                    overlayNode.isHidden = false
                } else {
                    overlayNode.geometry = nil
                    overlayNode.isHidden = true
                }
                return
            }
            coord.brushPreviewOverlayNode?.isHidden = true

            let objId = gameState.selectedPlacementObjectId
            coord.ghostNodes.values.forEach { $0.isHidden = true }
            guard let objectId = objId, SceneKitPlacementRegistry.placeableObjectIds.contains(objectId),
                  let ghost = coord.ghostNodes[objectId],
                  let config = SceneKitPlacementRegistry.config(for: objectId) else { return }
            guard let container else { return }
            if WallParent.isWall(objectId: objectId), container.isWallLineActive { return }
            guard let sv = container.scnView, sv.bounds.contains(container.convert(loc, to: sv)) else { return }
            let hitOptions: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue, .categoryBitMask: 1]
            let hits = sv.hitTest(container.convert(loc, to: sv), options: hitOptions)
            guard let hit = hits.first(where: { isBuildSurface($0.node, underground: container.isUnderground) }),
                  let (row, col) = cellFromMapLocalPosition(hit.worldCoordinates, rows: rows, cols: cols) else { return }
            let (centerRow, centerCol): (Int, Int) = config.cellW == 1 && config.cellH == 1
                ? (row, col)
                : (row + config.cellH / 2, col + config.cellW / 2)
            let cellsForConditions = [(centerRow, centerCol)]
            let canPlaceWall = !WallParent.isWall(objectId: objectId)
                || WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objectId, cells: cellsForConditions)
            let touchesWater = gameState.groundwater.touchesWater(row: row, col: col, width: config.cellW, height: config.cellH)
            let canPlace = canPlaceWall
                && gameState.buildRuleViolation(objectId: objectId, row: row, col: col, width: config.cellW, height: config.cellH) == nil
            let ghostColor: NSColor
            if !canPlace {
                ghostColor = NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)      // crvena = onemogućeno
            } else if objectId == Well.objectId, !container.isUnderground, !touchesWater {
                ghostColor = NSColor(red: 1, green: 0.62, blue: 0.15, alpha: 1)      // narančasta = bunar bez vode
            } else {
                ghostColor = NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)   // zelena = dozvoljeno
            }
            applyGhostColorRecursive(ghost, color: ghostColor, transparency: 0.55)
            let pos = worldPositionAtCell(row: centerRow, col: centerCol, rows: rows, cols: cols)
            var (minB, _) = ghost.boundingBox
            let y = max(groundLevelY, -CGFloat(minB.y) + config.yOffset) + container.groundPlaneY
            ghost.position = SCNVector3(pos.x, y, pos.z)
            ghost.isHidden = false
            if WallParent.isWall(objectId: objectId) {
                let last = coord.lastGhostCellByObject[objectId]
                if last?.0 != centerRow || last?.1 != centerCol {
                    coord.lastGhostCellByObject[objectId] = (centerRow, centerCol)
                    placementDebug("ghost Wall cell=(\(centerRow),\(centerCol)) pos=(\(Int(pos.x)),\(String(format: "%.2f", y)),\(Int(pos.z))) bboxMinY=\(String(format: "%.3f", CGFloat(minB.y)))")
                }
            }
        }

        container.onWallLinePreview = { [gameState] cells in
            let existingWalls = wallCellsSet(from: gameState.activeMap.placements)
            var wallObjectIds = wallCellToObjectId(from: gameState.activeMap.placements)
            let objectId = gameState.selectedPlacementObjectId ?? HugeWall.objectId
            for (row, col) in cells {
                wallObjectIds[MapCoordinate(row: row, col: col)] = objectId
            }
            refreshWallLinePreview(
                coord.wallLinePreviewNode,
                cells: cells,
                templates: coord.placementTemplates,
                existingWallCells: existingWalls,
                wallObjectIdPerCell: wallObjectIds,
                gameState: gameState,
                objectId: objectId,
                mapRows: rows,
                mapCols: cols
            )
        }
        container.onWallLineCommit = { [gameState, coord] cells in
            guard !cells.isEmpty else { return }
            DispatchQueue.main.async {
                let objectId = gameState.selectedPlacementObjectId ?? HugeWall.objectId
                if !WallParent.isWall(objectId: objectId) {
                    gameState.selectedPlacementObjectId = HugeWall.objectId
                }
                let objectIdForWall = gameState.selectedPlacementObjectId ?? HugeWall.objectId
                if WallParent.isWall(objectId: objectIdForWall), !WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objectIdForWall, cells: cells) {
                    return
                }
                var placedAny = false
                for (row, col) in cells {
                    let ok = gameState.placeSelectedObjectAt(row: row, col: col, playSound: false)
                    if ok { placedAny = true }
                }
                if placedAny && gameState.playPlacementSound {
                    AudioManager.shared.playSound(named: "place", volume: gameState.effectiveSoundsVolume)
                }
                if placedAny, let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.activeMap.placements, templates: coord.placementTemplates, mapRows: rows, mapCols: cols)
                    coord.lastPlacementsCount = gameState.activeMap.placements.count
                }
            }
        }

        scnView.scene = scene
        scnView.rendersContinuously = true
        applyRenderQuality(to: scnView, gameState: gameState)
        coord.gameState = gameState
        coord.mapViewContainer = container
        coord.animatedZoom = CGFloat(gameState.mapCameraSettings.currentZoom)
        scnView.delegate = coord
        applyCamera(cameraNode: cameraNode, targetNode: cameraTarget, settings: gameState.mapCameraSettings)
        coord.gridNode?.isHidden = !showGrid
        coord.gridNode10?.isHidden = !showGrid || !gridShow10
        coord.gridNode40?.isHidden = !showGrid || !gridShow40
        // Postojeće građevine (iz spremljene mape) – bez objectWillChange usred makeNSView.
        let placements = gameState.activeMap.placements
        refreshPlacements(placementsNode, placements: placements, templates: coord.placementTemplates, mapRows: rows, mapCols: cols)
        coord.lastPlacementsCount = placements.count
        DispatchQueue.main.async {
            gameState.levelLoadingMessage = nil
            gameState.isLevelReady = true
        }

        container.onPanStart = { _ in }
        container.onPanLock = { [gameState] worldDX, worldDZ in
            var s = gameState.mapCameraSettings
            s.panOffset.x -= worldDX
            s.panOffset.y -= worldDZ
            gameState.setMapCameraSettingsSilent(s)
        }
        container.onPanChange = { [gameState] delta in
            var s = gameState.mapCameraSettings
            let h = SceneKitMapView.cameraBaseHeight / max(s.currentZoom, 0.01)
            let metersPerPixel = h / 350 * CGFloat(gameState.cameraSensitivity)
            s.panOffset.x -= delta.x * metersPerPixel
            s.panOffset.y -= delta.y * metersPerPixel
            gameState.setMapCameraSettingsSilent(s)
        }
        container.onZoomDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            let zoomIn = gameState.invertScrollZoom ? delta < 0 : delta > 0
            s.stepZoomPhaseByScroll(zoomIn: zoomIn)
            gameState.setMapCameraSettingsSilent(s)
        }
        container.onTiltDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            let signed = gameState.invertYAxis ? -delta : delta
            s.tiltAngle = min(MapCameraSettings.tiltMax, max(MapCameraSettings.tiltMin, s.tiltAngle + signed))
            gameState.setMapCameraSettingsSilent(s)
        }
        container.onToggleTopDown = { [gameState] in
            var s = gameState.mapCameraSettings
            s.isTopDown.toggle()
            gameState.setMapCameraSettingsSilent(s)
        }
        container.onRotationDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.mapRotation += delta
            gameState.setMapCameraSettingsSilent(s)
        }
        container.useTrackpad = gameState.inputDevice == .trackpad
        container.syncPanInputMonitors()
        container.onCastleClick = { [weak container, gameState] in
            container?.dismissGroundMark()
            DispatchQueue.main.async {
                gameState.inspectedPlacementId = nil
                gameState.inspectedBuildingTitle = Castle.gameObject.name
            }
        }
        container.onClick = { [weak container, gameState, coord] row, col in
            DispatchQueue.main.async { gameState.inspectedBuildingTitle = nil }
            guard let container else { return }
            if let cb = coord.onCellSelectionToggle {
                cb(row, col)
                DispatchQueue.main.async { gameState.objectWillChange.send() }
                return
            }
            if let cb = coord.onTerrainAddBrushSelection {
                cb(row, col)
                DispatchQueue.main.async { gameState.objectWillChange.send() }
                return
            }
            if coord.isTerrainEditMode, let cb = coord.onTerrainEdit {
                cb(row, col)
                return
            }
            if container.isEraseMode, let onRemoveAt = onRemoveAt {
                onRemoveAt(row, col)
                if let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.activeMap.placements, templates: coord.placementTemplates, mapRows: coord.mapRows, mapCols: coord.mapCols)
                    coord.lastPlacementsCount = gameState.activeMap.placements.count
                }
                return
            }
            let objectId = container.currentSelectedPlacementObjectId ?? gameState.selectedPlacementObjectId
            placementDebug("map click row=\(row) col=\(col) selected=\(objectId ?? "nil")")
            guard let objId = objectId, !objId.isEmpty else {
                if gameState.isMapEditorMode, let tap = onMapEditorCellTap {
                    tap(row, col)
                    return
                }
                if !gameState.isMapEditorMode, let placement = gameState.activeMap.placement(at: MapCoordinate(row: row, col: col)) {
                    container.dismissGroundMark()
                    DispatchQueue.main.async { gameState.inspectPlacement(placement) }
                    return
                }
                if gameState.markedPeople.contains(where: {
                    $0.isKing || gameState.people.person(id: $0.id)?.canBeMarked == true
                }) {
                    DispatchQueue.main.async { gameState.sendMarkedSoldiers(row: row, col: col) }
                    return
                }
                guard !container.isUnderground else { return }
                container.dismissGroundMark()
                DispatchQueue.main.async { gameState.movePlayerKing(toRow: row, col: col) }
                return
            }
            if WallParent.isWall(objectId: objId), !WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objId, cells: [(row, col)]) {
                return
            }
            DispatchQueue.main.async {
                if gameState.selectedPlacementObjectId != objId {
                    gameState.selectedPlacementObjectId = objId
                }
                let ok = gameState.placeSelectedObjectAt(row: row, col: col)
                placementDebug("placeSelectedObjectAt object=\(objId) row=\(row) col=\(col) ok=\(ok)")
                if ok, let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.activeMap.placements, templates: coord.placementTemplates, mapRows: coord.mapRows, mapCols: coord.mapCols)
                    coord.lastPlacementsCount = gameState.activeMap.placements.count
                }
            }
        }
        container.onRightClick = { [gameState, isTerrainEditMode, onExitTerrainEditMode] in
            if isTerrainEditMode, let exit = onExitTerrainEditMode {
                DispatchQueue.main.async { exit() }
            } else {
                DispatchQueue.main.async {
                    gameState.leaveUnderground()
                    gameState.selectedPlacementObjectId = nil
                    gameState.inspectedBuildingTitle = nil
                }
            }
        }
        container.onPlacementError = { [gameState] msg in
            DispatchQueue.main.async { gameState.placementError = msg }
        }
        coord.isTerrainEditMode = isTerrainEditMode
        coord.onTerrainEdit = onTerrainEdit
        coord.onTerrainAddBrushSelection = onTerrainAddBrushSelection
        coord.onCellSelectionToggle = onCellSelectionToggle
        coord.terrainPaintSeaPreview = terrainPaintSeaPreview
        container.isTerrainEditMode = isTerrainEditMode
        wireTerrainPaintDrag(container: container, coord: coord, gameState: gameState)
        wireSeaHandleDrag(container: container, coord: coord, gameState: gameState)
        wireRiverHandleDrag(container: container, coord: coord, gameState: gameState)
        container.onVertexDotSelected = { [onVertexDotSelected] vr, vc in
            DispatchQueue.main.async { onVertexDotSelected?(vr, vc) }
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.isCellSelectionMode = isCellSelectionMode
        container.hasObjectSelected = isPlaceMode && !isTerrainEditMode
        container.cameraPanAllowed = !isPlaceMode && !isTerrainEditMode && !isEraseMode && !isCellSelectionMode
        container.currentSelectedPlacementObjectId = gameState.selectedPlacementObjectId
        container.useTrackpad = gameState.inputDevice == .trackpad
        container.syncPanInputMonitors()
        container.selectedToolsPanelItem = gameState.selectedToolsPanelItem
        container.isMapEditor = gameState.isMapEditorMode
        bindGroundMark(container: container, coord: coord)
        applyGroundwaterOverlay(coord: coord)
        applyEditorCellOverlay(coord: coord)
        applyBuildPadOverlay(coord: coord)
        applyLordStartMarkers(coord: coord)
        applyUndergroundMode(container: container, coord: coord)

        return container
    }

    /// Kontrolne točke mora: vrhovi (drag) + mid (klik = split).
    /// Za vrijeme draga samo mijenjamo pozicije čvorova (bez punog rebuilda → bez kašnjenja).
    private func wireSeaHandleDrag(container: SceneKitMapNSView, coord: Coordinator, gameState: GameState) {
        let draftActive = gameState.mapEditorState?.seaSurfaceDraft != nil
        container.seaHandleEditing = draftActive
        container.mapRows = coord.mapRows
        container.mapCols = coord.mapCols

        func fullRefresh(_ draft: SeaSurfaceDraft, coord: Coordinator) {
            guard let overlay = coord.cellSelectionOverlayNode else { return }
            refreshCellSelectionOverlay(
                overlayNode: overlay,
                selectedCells: [],
                gameMap: gameState.gameMap,
                rows: coord.mapRows,
                cols: coord.mapCols,
                seaPreview: true,
                seaDraft: draft
            )
        }

        /// Live update: plavo + zeleni obrub + točke zajedno (žuti vanjski ostaje).
        func liveMoveInner(_ draft: SeaSurfaceDraft, coord: Coordinator) {
            guard let overlay = coord.cellSelectionOverlayNode else { return }
            let halfW = effectiveMapWorldW(cols: coord.mapCols) / 2
            let halfH = effectiveMapWorldH(rows: coord.mapRows) / 2
            let step = worldUnitsPerCell
            let rimY: CGFloat = {
                if let h = overlay.childNode(withName: "seaH_vertex_0", recursively: true) {
                    return CGFloat(h.position.y)
                }
                return 0.4
            }()
            let fillY = rimY - 0.09
            for child in overlay.childNodes {
                let n = child.name ?? ""
                if n == "seaDraftEdge" || n == "seaDraftWater" || n.hasPrefix("seaH_") || n.hasPrefix("seaDraftWater") {
                    child.removeFromParentNode()
                }
            }
            let outline = draft.innerOutlinePoints()
            var fillVerts: [SCNVector3] = []
            var rimVerts: [SCNVector3] = []
            for pt in outline {
                let x = pt.col * step - halfW
                let z = pt.row * step - halfH
                fillVerts.append(SCNVector3(x, fillY, z))
                rimVerts.append(SCNVector3(x, rimY, z))
            }
            addSeaDraftPolygonFill(to: overlay, vertices: fillVerts)
            let lineThickness = max(step * 0.07, 0.4)
            for i in 0..<rimVerts.count {
                addSeaDraftEdgeLine(
                    to: overlay,
                    from: rimVerts[i],
                    to: rimVerts[(i + 1) % rimVerts.count],
                    thickness: lineThickness
                )
            }
            addSeaSurfaceHandles(
                to: overlay,
                draft: draft,
                y: rimY,
                halfW: halfW,
                halfH: halfH,
                step: step
            )
        }

        container.onSeaMidSplit = { [weak coord, gameState] edgeIndex in
            guard let coord else { return }
            var draft = coord.seaDraftLive ?? gameState.mapEditorState?.seaSurfaceDraft
            guard var draft else { return }
            draft.splitEdge(at: edgeIndex)
            coord.seaDraftLive = draft
            fullRefresh(draft, coord: coord)
            let final = draft
            DispatchQueue.main.async {
                gameState.commitSeaSurfaceDraft(final)
                coord.seaDraftLive = nil
            }
        }

        container.onSeaVertexDrag = { [weak coord, gameState] index, row, col, ended in
            guard let coord else { return }
            var draft = coord.seaDraftLive ?? gameState.mapEditorState?.seaSurfaceDraft
            guard var draft else { return }
            if row.isFinite, col.isFinite {
                draft.moveVertex(index: index, row: row, col: col)
            }
            coord.seaDraftLive = draft
            if ended {
                fullRefresh(draft, coord: coord)
                let final = draft
                DispatchQueue.main.async {
                    gameState.commitSeaSurfaceDraft(final)
                    coord.seaDraftLive = nil
                }
            } else {
                liveMoveInner(draft, coord: coord)
            }
        }
    }

    /// Kontrolne točke rijeke: vrhovi (drag) + mid (klik = split).
    private func wireRiverHandleDrag(container: SceneKitMapNSView, coord: Coordinator, gameState: GameState) {
        let draftActive = gameState.mapEditorState?.riverPathDraft != nil
        container.riverHandleEditing = draftActive
        container.mapRows = coord.mapRows
        container.mapCols = coord.mapCols

        func fullRefresh(_ draft: RiverPathDraft, coord: Coordinator) {
            guard let overlay = coord.cellSelectionOverlayNode else { return }
            refreshCellSelectionOverlay(
                overlayNode: overlay,
                selectedCells: [],
                gameMap: gameState.gameMap,
                rows: coord.mapRows,
                cols: coord.mapCols,
                riverDraft: draft
            )
        }

        /// Live: traka + crta + točke bez GameState publish.
        func liveRefresh(_ draft: RiverPathDraft, coord: Coordinator) {
            guard let overlay = coord.cellSelectionOverlayNode else { return }
            for child in overlay.childNodes {
                let n = child.name ?? ""
                if n == "riverDraftRibbon" || n == "riverDraftEdge" || n.hasPrefix("rivH_") {
                    child.removeFromParentNode()
                }
            }
            addRiverPathDraftOverlay(
                to: overlay,
                draft: draft,
                gameMap: gameState.gameMap,
                rows: coord.mapRows,
                cols: coord.mapCols
            )
        }

        container.onRiverMidSplit = { [weak coord, gameState] segmentIndex in
            guard let coord else { return }
            var draft = coord.riverDraftLive ?? gameState.mapEditorState?.riverPathDraft
            guard var draft else { return }
            draft.splitSegment(at: segmentIndex)
            coord.riverDraftLive = draft
            fullRefresh(draft, coord: coord)
            let final = draft
            DispatchQueue.main.async {
                gameState.commitRiverPathDraft(final)
                coord.riverDraftLive = nil
            }
        }

        container.onRiverVertexDrag = { [weak coord, gameState] index, row, col, ended in
            guard let coord else { return }
            var draft = coord.riverDraftLive ?? gameState.mapEditorState?.riverPathDraft
            guard var draft else { return }
            if row.isFinite, col.isFinite {
                draft.moveVertex(index: index, row: row, col: col)
            }
            coord.riverDraftLive = draft
            if ended {
                fullRefresh(draft, coord: coord)
                let final = draft
                DispatchQueue.main.async {
                    gameState.commitRiverPathDraft(final)
                    coord.riverDraftLive = nil
                }
            } else {
                liveRefresh(draft, coord: coord)
            }
        }
    }

    /// Click-drag preview: samo SceneKit overlay (bez GameState publish → nema SwiftUI reentrancy).
    private func wireTerrainPaintDrag(container: SceneKitMapNSView, coord: Coordinator, gameState: GameState) {
        let onCommit = onTerrainPaintCommit
        container.onTerrainPaintPreview = { [weak coord] r0, c0, r1, c1 in
            guard let coord, let overlay = coord.cellSelectionOverlayNode else { return }
            let cells = Set(gameState.cellsInRectangle(row0: r0, col0: c0, row1: r1, col1: c1))
            coord.terrainPaintPreviewCells = cells
            // Dok vučeš pravokutnik, sakrij zeleni brush ghost da se vidi plavo područje.
            coord.brushPreviewOverlayNode?.isHidden = true
            refreshCellSelectionOverlay(
                overlayNode: overlay,
                selectedCells: cells,
                gameMap: gameState.gameMap,
                rows: coord.mapRows,
                cols: coord.mapCols,
                seaPreview: coord.terrainPaintSeaPreview
            )
        }
        container.onTerrainPaintCommit = { [weak coord] r0, c0, r1, c1 in
            coord?.terrainPaintPreviewCells = nil
            if let overlay = coord?.cellSelectionOverlayNode {
                overlay.childNodes.forEach { $0.removeFromParentNode() }
            }
            coord?.brushPreviewOverlayNode?.isHidden = false
            // Commit u sljedećem turnu — ne publishaj usred view update / mouse-up.
            DispatchQueue.main.async {
                onCommit?(r0, c0, r1, c1)
            }
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SceneKitMapNSView,
              container.scnView != nil else { return }
        let coord = context.coordinator

        let wasTerrain = coord.isTerrainEditMode
        coord.isTerrainEditMode = isTerrainEditMode
        coord.onTerrainEdit = onTerrainEdit
        coord.onTerrainAddBrushSelection = onTerrainAddBrushSelection
        coord.onCellSelectionToggle = onCellSelectionToggle
        coord.terrainPaintSeaPreview = terrainPaintSeaPreview
        container.isTerrainEditMode = isTerrainEditMode
        wireTerrainPaintDrag(container: container, coord: coord, gameState: gameState)
        wireSeaHandleDrag(container: container, coord: coord, gameState: gameState)
        wireRiverHandleDrag(container: container, coord: coord, gameState: gameState)
        container.onVertexDotSelected = { [onVertexDotSelected] vr, vc in
            DispatchQueue.main.async { onVertexDotSelected?(vr, vc) }
        }
        if !isTerrainEditMode {
            coord.brushPreviewOverlayNode?.isHidden = true
        } else {
            coord.brushPreviewOverlayNode?.isHidden = false
            // Ne diraj ghost usred paint-draga — layout reentrancy.
            if !container.isTerrainPaintActive {
                container.updateGhostFromCurrentMouseLocation()
            }
        }
        if let option = terrainBrushOption {
            coord.terrainBrushOption = option
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.isCellSelectionMode = isCellSelectionMode
        container.hasObjectSelected = isPlaceMode && !isTerrainEditMode
        container.cameraPanAllowed = !isPlaceMode && !isTerrainEditMode && !isEraseMode && !isCellSelectionMode
        container.currentSelectedPlacementObjectId = gameState.selectedPlacementObjectId
        container.selectedToolsPanelItem = gameState.selectedToolsPanelItem
        container.isMapEditor = gameState.isMapEditorMode
        container.useTrackpad = gameState.inputDevice == .trackpad
        if let scnView = container.scnView {
            applyRenderQuality(to: scnView, gameState: gameState)
        }
        bindGroundMark(container: container, coord: coord)
        // Zelena ploha samo dok traje nacrt; committed oznaka se ne crta ponovo.
        applyGroundwaterOverlay(coord: coord)
        applyEditorCellOverlay(coord: coord)
        applyBuildPadOverlay(coord: coord)
        applyLordStartMarkers(coord: coord)
        applyUndergroundMode(container: container, coord: coord)
        container.onRightClick = { [gameState, isTerrainEditMode, onExitTerrainEditMode] in
            if isTerrainEditMode, let exit = onExitTerrainEditMode {
                DispatchQueue.main.async { exit() }
            } else {
                DispatchQueue.main.async {
                    gameState.leaveUnderground()
                    gameState.selectedPlacementObjectId = nil
                    gameState.inspectedBuildingTitle = nil
                }
            }
        }
        // Ne zvati makeFirstResponder / invalidateCursorRects ovdje — uzrokuje NSHostingView reentrancy.

        // Mapa (rootNode, teren, grid, placements) se NIKAD ne dira – samo kamera i target.

        // Odmah primijeni kameru (pan, rotacija) kad se stanje promijeni iz UI (npr. klik na kompas); zoom/orbit ostaju glatko u delegateu.
        if let cam = coord.cameraNode, let target = coord.cameraTarget {
            let s = gameState.mapCameraSettings
            let h = Self.cameraBaseHeight / coord.animatedZoom
            let r = CGFloat(-s.mapRotation)
            let depth = coord.animatedDepth
            let orbit = h * (0.02 + 0.98 * coord.animatedOrbitFactor)
            target.position = SCNVector3(s.panOffset.x, depth, s.panOffset.y)
            cam.position = SCNVector3(
                s.panOffset.x + sin(r) * orbit,
                h + depth,
                s.panOffset.y + cos(r) * orbit
            )
        }

        // Pivot, ghost, grid
        if let pivot = coord.pivotIndicatorNode {
            pivot.position = coord.cameraTarget?.position ?? SCNVector3(
                gameState.mapCameraSettings.panOffset.x,
                0,
                gameState.mapCameraSettings.panOffset.y
            )
            pivot.isHidden = !showPivotIndicator
        }
        let selectedId = gameState.selectedPlacementObjectId
        for (objectId, ghost) in coord.ghostNodes {
            ghost.isHidden = selectedId != objectId
        }
        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        let mapWidth = effectiveMapWorldW(cols: cols)
        let mapHeight = effectiveMapWorldH(rows: rows)
        coord.mapRows = rows
        coord.mapCols = cols
        let placements = gameState.activeMap.placements
        if placements.count != coord.lastPlacementsCount || gameState.placementsVersion != coord.lastPlacementsVersion,
           let node = coord.placementsNode {
            refreshPlacements(node, placements: placements, templates: coord.placementTemplates, mapRows: rows, mapCols: cols)
            coord.lastPlacementsCount = placements.count
            coord.lastPlacementsVersion = gameState.placementsVersion
            coord.warehouseStockKey = ""
            coord.lastWarehouseEpoch = -1
        }
        if let node = coord.warehouseNode {
            let key = WarehouseStacks.stockKey(gameState)
            if key != coord.warehouseStockKey || gameState.warehouseGoodsEpoch != coord.lastWarehouseEpoch {
                coord.warehouseStockKey = key
                coord.lastWarehouseEpoch = gameState.warehouseGoodsEpoch
                WarehouseStacks.syncWorld(on: node, gameState: gameState, rows: rows, cols: cols)
            }
        }
        let zoom = gameState.mapCameraSettings.currentZoom
        let div40 = gridDivisionsBuilding(rows: rows, cols: cols)
        let div10 = gridDivisionsDisplay(rows: rows, cols: cols)
        let mapRows = coord.mapRows
        let mapCols = coord.mapCols
        let gridGameMap = gameState.gameMap
        let shouldRefreshGrid = abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01
        if let grid = coord.gridNode {
            grid.isHidden = !showGrid
            if shouldRefreshGrid {
                coord.lastGridZoom = CGFloat(zoom)
                refreshGrid(gridNode: grid, zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if isMapEditorGridMode, let scene = coord.scene {
            if gridShow10, coord.gridNode10 == nil {
                let n10 = setupGridNode(zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
                n10.name = "grid10"
                scene.rootNode.addChildNode(n10)
                coord.gridNode10 = n10
            } else if !gridShow10, let g10 = coord.gridNode10 {
                g10.removeFromParentNode()
                coord.gridNode10 = nil
            }
            if gridShow40, coord.gridNode40 == nil {
                let n40 = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
                n40.name = "grid40"
                scene.rootNode.addChildNode(n40)
                coord.gridNode40 = n40
            } else if !gridShow40, let g40 = coord.gridNode40 {
                g40.removeFromParentNode()
                coord.gridNode40 = nil
            }
        }
        if let g10 = coord.gridNode10 {
            g10.isHidden = !showGrid || !gridShow10
            if shouldRefreshGrid {
                refreshGrid(gridNode: g10, zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if let g40 = coord.gridNode40 {
            g40.isHidden = !showGrid || !gridShow40
            if shouldRefreshGrid {
                refreshGrid(gridNode: g40, zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if coord.gridNode10 != nil || coord.gridNode40 != nil, abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01 {
            coord.lastGridZoom = CGFloat(zoom)
        }
        if let sid = selectedId, !WallParent.isWall(objectId: sid) {
            coord.wallLinePreviewNode?.childNodes.forEach { $0.removeFromParentNode() }
        }

        // Mesh se osvježi kad se visina ili podloga promijeni, da tekstura ostane na ploči.
        let terrainChecksum = isTerrainEditMode ? terrainHeightsChecksum(gameMap: gameState.gameMap) : coord.lastTerrainHeightsChecksum
        let padVersion = gameState.editorCellsVersion
        let placeVersion = gameState.placementsVersion
        let terrainNeedsRebuild = (isTerrainEditMode && (terrainChecksum != coord.lastTerrainHeightsChecksum || !wasTerrain))
            || padVersion != coord.lastTerrainPadVersion
            || placeVersion != coord.lastTerrainPlacementVersion
        if terrainNeedsRebuild {
            coord.lastTerrainHeightsChecksum = terrainChecksum
            coord.lastTerrainPadVersion = padVersion
            coord.lastTerrainPlacementVersion = placeVersion
        }
        if terrainNeedsRebuild, let scene = coord.scene, let terrain = findTerrainInHierarchy(scene.rootNode),
           let newGeo = makeTerrainGeometryWithHeights(gameMap: gameState.gameMap) {
            let numElements = newGeo.elements.count
            let oldMat = terrain.geometry?.materials.first ?? SCNMaterial()
            applyTerrainPBRTiled(to: oldMat, gameMap: gameState.gameMap)
            // Element 0 = gornja ploha (oldMat), element 1 = bočne + donja ploča (sideMat). SceneKit: materials[i] → element i.
            if numElements > 1 {
                let sideMat = SCNMaterial()
                sideMat.diffuse.contents = NSColor.white
                sideMat.ambient.contents = NSColor.white
                sideMat.specular.contents = NSColor.darkGray
                sideMat.isDoubleSided = true
                sideMat.lightingModel = .physicallyBased
                newGeo.materials = [oldMat, sideMat]
            } else {
                newGeo.materials = [oldMat]
            }
            terrain.geometry = newGeo
            // Gotovo / commit: korito + Metal voda. Tijekom nacrta ostaje editor overlay.
            if gameState.mapEditorState?.seaSurfaceDraft == nil {
                SeaBasin.attach(to: terrain, gameMap: gameState.gameMap)
            } else {
                terrain.childNode(withName: "seaBasin", recursively: false)?.removeFromParentNode()
            }
        }

        // Map Editor – overlay: dok traje drag, SceneKit callback već crta preview (ne prepisuj).
        if gameState.isMapEditorMode, let overlayNode = coord.cellSelectionOverlayNode,
           !container.isTerrainPaintActive,
           !container.isSeaHandleDragging,
           !container.isRiverHandleDragging,
           coord.seaDraftLive == nil,
           coord.riverDraftLive == nil {
            let draft = gameState.mapEditorState?.seaSurfaceDraft
            let riverDraft = gameState.mapEditorState?.riverPathDraft
            let seaCells = gameState.mapEditorState?.editingSeaCells ?? []
            let selected = coord.terrainPaintPreviewCells
                ?? (!seaCells.isEmpty ? seaCells : nil)
                ?? gameState.mapEditorState?.selectedCells
                ?? []
            let seaHighlight = coord.terrainPaintSeaPreview
                || (gameState.mapEditorState?.isSeaEditorActive == true)
                || draft != nil
            refreshCellSelectionOverlay(
                overlayNode: overlayNode,
                selectedCells: selected,
                gameMap: gameState.gameMap,
                rows: coord.mapRows,
                cols: coord.mapCols,
                seaPreview: seaHighlight,
                seaDraft: draft,
                riverDraft: riverDraft
            )
        }

        // Ne osvježavaj placements ovdje – inače se pri svakom updateNSView (rotacija, zoom) cijela scena zidova gradi iznova (39 MB .obj + reapplyTexture) → pad FPS. Osvježavanje samo u onClick (place) i nakon onRemoveAt (erase).
    }

    /// Vizualni čvor na mjestu pivota (gdje kamera gleda) – mali disk + križ.
    private func makePivotIndicatorNode() -> SCNNode {
        let container = SCNNode()
        let radius: CGFloat = 2
        let cyl = SCNCylinder(radius: radius, height: 4)
        cyl.firstMaterial?.diffuse.contents = NSColor.systemYellow
        cyl.firstMaterial?.emission.contents = NSColor.systemYellow.withAlphaComponent(0.5)
        cyl.firstMaterial?.isDoubleSided = true
        cyl.firstMaterial?.lightingModel = .constant
        let disk = SCNNode(geometry: cyl)
        disk.position = SCNVector3(0, 2, 0)
        disk.eulerAngles.x = -.pi / 2
        container.addChildNode(disk)
        let barW: CGFloat = 8
        let barLen: CGFloat = radius * 1.6
        let bar = SCNBox(width: barLen, height: barW, length: barW, chamferRadius: 0)
        bar.firstMaterial?.diffuse.contents = NSColor.systemYellow
        bar.firstMaterial?.lightingModel = .constant
        let h = SCNNode(geometry: bar)
        h.position = SCNVector3(0, 4, 0)
        container.addChildNode(h)
        let v = SCNNode(geometry: bar)
        v.position = SCNVector3(0, 4, 0)
        v.eulerAngles.z = .pi / 2
        container.addChildNode(v)
        return container
    }

    /// Samo kamera i target se pomiču. Mapa se NIKAD ne dira.
    /// Kamera: orbita na visini h (kosi) ili radius 0 (odozgo / nacrt); uvijek gleda pivot.
    private func applyCamera(cameraNode: SCNNode, targetNode: SCNNode, settings: MapCameraSettings) {
        let h = Self.cameraBaseHeight / settings.currentZoom
        let px = settings.panOffset.x
        let pz = settings.panOffset.y
        let rot = CGFloat(-settings.mapRotation)
        let orbitRadius = h * (settings.isTopDown ? 0.02 : 1)
        targetNode.position = SCNVector3(px, 0, pz)
        cameraNode.position = SCNVector3(
            px + sin(rot) * orbitRadius,
            h,
            pz + cos(rot) * orbitRadius
        )
    }

    private func wallCellsSet(from placements: [Placement]) -> Set<MapCoordinate> {
        var set: Set<MapCoordinate> = []
        for p in placements where WallParent.isWall(objectId: p.objectId) {
            for c in p.coveredCoordinates() { set.insert(c) }
        }
        return set
    }

    /// Mapa ćelija zida → objectId (za visinu trokutastih spojnica: mali zid = 240, veliki = 400).
    private func wallCellToObjectId(from placements: [Placement]) -> [MapCoordinate: String] {
        var map: [MapCoordinate: String] = [:]
        for p in placements where WallParent.isWall(objectId: p.objectId) {
            for c in p.coveredCoordinates() { map[c] = p.objectId }
        }
        return map
    }

    private enum TriangleCorner {
        case nw, ne, sw, se
    }

    private func makeRightTrianglePrismNode(corner: TriangleCorner, size: CGFloat, height: CGFloat, color: NSColor, alpha: CGFloat = 1.0) -> SCNNode {
        let h = size / 2
        let a: SCNVector3
        let b: SCNVector3
        let c: SCNVector3
        switch corner {
        case .nw:
            a = SCNVector3(-h, 0, -h); b = SCNVector3(h, 0, -h); c = SCNVector3(-h, 0, h)
        case .ne:
            a = SCNVector3(h, 0, -h); b = SCNVector3(-h, 0, -h); c = SCNVector3(h, 0, h)
        case .sw:
            a = SCNVector3(-h, 0, h); b = SCNVector3(h, 0, h); c = SCNVector3(-h, 0, -h)
        case .se:
            a = SCNVector3(h, 0, h); b = SCNVector3(-h, 0, h); c = SCNVector3(h, 0, -h)
        }
        let vertices: [SCNVector3] = [
            a, b, c,
            SCNVector3(a.x, height, a.z),
            SCNVector3(b.x, height, b.z),
            SCNVector3(c.x, height, c.z),
        ]
        let texcoords: [CGPoint] = vertices.map { v in
            CGPoint(x: (CGFloat(v.x) + h) / size, y: (CGFloat(v.z) + h) / size)
        }
        let indices: [UInt32] = [
            0, 2, 1,
            3, 4, 5,
            0, 1, 4, 0, 4, 3,
            1, 2, 5, 1, 5, 4,
            2, 0, 3, 2, 3, 5,
        ]
        let src = SCNGeometrySource(vertices: vertices)
        let uv = SCNGeometrySource(textureCoordinates: texcoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [src, uv], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.ambient.contents = NSColor.white
        mat.specular.contents = NSColor.darkGray
        mat.isDoubleSided = true
        mat.lightingModel = .physicallyBased
        mat.transparency = alpha
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private func wallCubeHeightFromTemplate(_ template: SCNNode) -> CGFloat {
        let (minB, maxB) = template.boundingBox
        return max(1, CGFloat(maxB.y - minB.y))
    }

    private func isWallLineSloped(_ cells: [(Int, Int)]) -> Bool {
        guard cells.count >= 2 else { return false }
        for i in 1..<cells.count {
            let prev = cells[i - 1]
            let cur = cells[i]
            let dRow = abs(cur.0 - prev.0)
            let dCol = abs(cur.1 - prev.1)
            if dRow > 0 && dCol > 0 { return true }
        }
        return false
    }

    private func hasAnyDiagonalAdjacency(_ wallCells: Set<MapCoordinate>) -> Bool {
        guard wallCells.count >= 2 else { return false }
        for cell in wallCells {
            let se = MapCoordinate(row: cell.row + 1, col: cell.col + 1)
            let sw = MapCoordinate(row: cell.row + 1, col: cell.col - 1)
            if wallCells.contains(se) || wallCells.contains(sw) { return true }
        }
        return false
    }

    private func hasDiagonalAdjacency(in wallCells: Set<MapCoordinate>, involving focus: Set<MapCoordinate>) -> Bool {
        guard !focus.isEmpty, wallCells.count >= 2 else { return false }
        for cell in focus {
            let nw = MapCoordinate(row: cell.row - 1, col: cell.col - 1)
            let ne = MapCoordinate(row: cell.row - 1, col: cell.col + 1)
            let sw = MapCoordinate(row: cell.row + 1, col: cell.col - 1)
            let se = MapCoordinate(row: cell.row + 1, col: cell.col + 1)
            if wallCells.contains(nw) || wallCells.contains(ne) || wallCells.contains(sw) || wallCells.contains(se) {
                return true
            }
        }
        return false
    }

    private func stepsRotation(for corner: TriangleCorner) -> CGFloat {
        switch corner {
        case .nw: return 0
        case .ne: return -.pi / 2
        case .se: return .pi
        case .sw: return .pi / 2
        }
    }

    /// Iz mostne ćelije i susjednih zidova odredi corner pravokutnog trokuta tako da
    /// katete gledaju prema unutra (prema zidovima), a hipotenuza prema van.
    private func outwardCorner(for bridge: MapCoordinate, wallCells: Set<MapCoordinate>) -> TriangleCorner? {
        let n = wallCells.contains(MapCoordinate(row: bridge.row - 1, col: bridge.col))
        let e = wallCells.contains(MapCoordinate(row: bridge.row, col: bridge.col + 1))
        let s = wallCells.contains(MapCoordinate(row: bridge.row + 1, col: bridge.col))
        let w = wallCells.contains(MapCoordinate(row: bridge.row, col: bridge.col - 1))
        let count = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0)
        guard count == 2 else { return nil }
        if n && e { return .ne }
        if e && s { return .se }
        if s && w { return .sw }
        if w && n { return .nw }
        return nil
    }

    private func firstMaterialRecursive(_ node: SCNNode) -> SCNMaterial? {
        if let mat = node.geometry?.firstMaterial { return mat }
        for child in node.childNodes {
            if let mat = firstMaterialRecursive(child) { return mat }
        }
        return nil
    }

    private func addWallDiagonalConnectors(
        to node: SCNNode,
        wallCells: Set<MapCoordinate>,
        focusCells: Set<MapCoordinate>? = nil,
        color: NSColor,
        alpha: CGFloat = 1.0,
        templateForHeight: SCNNode,
        useWallTexture: Bool = false,
        stepsTemplate: SCNNode? = nil,
        wallObjectIdPerCell: [MapCoordinate: String]? = nil,
        smallWallTemplate: SCNNode? = nil,
        mapRows: Int,
        mapCols: Int
    ) -> Int {
        guard !wallCells.isEmpty else { return 0 }
        let _ = stepsTemplate
        var created = 0
        var createdBridgeCells: Set<MapCoordinate> = []
        var diagonalPairsDetected = 0
        var skippedBridgeOccupied = 0
        let defaultH = wallCubeHeightFromTemplate(templateForHeight)
        let connectorSize = worldUnitsPerCell
        func heightForCell(_ cell: MapCoordinate) -> CGFloat {
            guard let ids = wallObjectIdPerCell, let id = ids[cell] else { return defaultH }
            return ParentWall.wallHeight(for: id)
        }
        func templateAndHeightForConnector(cell1: MapCoordinate, cell2: MapCoordinate) -> (template: SCNNode, h: CGFloat) {
            let h = max(heightForCell(cell1), heightForCell(cell2))
            let useSmall = h <= 250
            let template = (useSmall && smallWallTemplate != nil) ? smallWallTemplate! : templateForHeight
            return (template, h)
        }
        func cornerName(_ corner: TriangleCorner) -> String {
            switch corner {
            case .nw: return "nw"
            case .ne: return "ne"
            case .sw: return "sw"
            case .se: return "se"
            }
        }
        for cell in wallCells {
            let r = cell.row
            let c = cell.col

            // NW-SE dijagonala: (r,c) i (r+1,c+1), trokuti u (r,c+1) i (r+1,c)
            let se = MapCoordinate(row: r + 1, col: c + 1)
            if wallCells.contains(se) {
                diagonalPairsDetected += 1
                if focusCells == nil || focusCells!.contains(cell) || focusCells!.contains(se) {
                    let b1 = MapCoordinate(row: r, col: c + 1)
                    let b2 = MapCoordinate(row: r + 1, col: c)
                    if wallCells.contains(b1) { skippedBridgeOccupied += 1 }
                    if wallCells.contains(b2) { skippedBridgeOccupied += 1 }
                    let (connTemplateNWSE, connHNWSE) = templateAndHeightForConnector(cell1: cell, cell2: se)
                    if !createdBridgeCells.contains(b1), !wallCells.contains(b1) {
                        let p = worldPositionAtCell(row: b1.row, col: b1.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b1, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNWSE / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNWSE, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNWSE) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b1.row),\(b1.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b1)
                        created += 1
                    }
                    if !createdBridgeCells.contains(b2), !wallCells.contains(b2) {
                        let p = worldPositionAtCell(row: b2.row, col: b2.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b2, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNWSE / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNWSE, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNWSE) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b2.row),\(b2.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b2)
                        created += 1
                    }
                }
            }

            // NE-SW dijagonala: (r,c) i (r+1,c-1), trokuti u (r,c-1) i (r+1,c)
            let sw = MapCoordinate(row: r + 1, col: c - 1)
            if wallCells.contains(sw) {
                diagonalPairsDetected += 1
                if focusCells == nil || focusCells!.contains(cell) || focusCells!.contains(sw) {
                    let b1 = MapCoordinate(row: r, col: c - 1)
                    let b2 = MapCoordinate(row: r + 1, col: c)
                    if wallCells.contains(b1) { skippedBridgeOccupied += 1 }
                    if wallCells.contains(b2) { skippedBridgeOccupied += 1 }
                    let (connTemplateNESW, connHNESW) = templateAndHeightForConnector(cell1: cell, cell2: sw)
                    if !createdBridgeCells.contains(b1), !wallCells.contains(b1) {
                        let p = worldPositionAtCell(row: b1.row, col: b1.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b1, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNESW / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNESW, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNESW) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b1.row),\(b1.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b1)
                        created += 1
                    }
                    if !createdBridgeCells.contains(b2), !wallCells.contains(b2) {
                        let p = worldPositionAtCell(row: b2.row, col: b2.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b2, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNESW / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNESW, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNESW) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b2.row),\(b2.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b2)
                        created += 1
                    }
                }
            }
        }
        if focusCells != nil {
            placementDebug("wall preview connectors: diagonalPairs=\(diagonalPairsDetected) created=\(created) skippedBridgeOccupied=\(skippedBridgeOccupied)")
        }
        return created
    }

    private func applyAdaptiveWallShape(_ instance: SCNNode, row: Int, col: Int, wallCells: Set<MapCoordinate>) -> (offsetX: CGFloat, offsetZ: CGFloat) {
        // Zidne kocke ostaju netaknute; diagonalni spoj se radi dodatnim trokutima.
        return (0, 0)
    }

    private func addVerticalWallSideSteps(
        to node: SCNNode,
        row: Int,
        col: Int,
        wallCells: Set<MapCoordinate>,
        stepsTemplate: SCNNode,
        alpha: CGFloat,
        ghostColor: NSColor? = nil,
        mapRows: Int,
        mapCols: Int
    ) {
        let hasNorth = wallCells.contains(MapCoordinate(row: row - 1, col: col))
        let hasSouth = wallCells.contains(MapCoordinate(row: row + 1, col: col))
        guard hasNorth || hasSouth else { return }

        let sides: [(dc: Int, rotY: CGFloat, name: String)] = [
            (-1, .pi / 2, "wall_steps_side_w"),
            (1, -.pi / 2, "wall_steps_side_e"),
        ]

        for side in sides {
            let sideCell = MapCoordinate(row: row, col: col + side.dc)
            // Ako je bočna ćelija već zid, preskoči da nema vizualnog preklapanja.
            if wallCells.contains(sideCell) { continue }
            let pos = worldPositionAtCell(row: sideCell.row, col: sideCell.col, rows: mapRows, cols: mapCols)
            let instance = stepsTemplate.clone()
            duplicateMaterialsRecursive(instance)
            var (minB, _) = instance.boundingBox
            let y = max(groundLevelY, -CGFloat(minB.y))
            instance.position = SCNVector3(pos.x, y, pos.z)
            instance.eulerAngles.y = side.rotY
            instance.name = side.name
            instance.categoryBitMask = 0
            instance.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(alpha, to: instance)
            if let ghostColor {
                applyGhostColorRecursive(instance, color: ghostColor, transparency: alpha)
            }
            node.addChildNode(instance)
        }
    }

    private func addPlacementNode(for p: Placement, to node: SCNNode, templates: [String: SCNNode], fallback: SCNNode, wallCells: Set<MapCoordinate>, mapRows: Int, mapCols: Int) {
        guard let config = SceneKitPlacementRegistry.config(for: p.objectId) else {
            addFallbackBoxes(for: p, to: node, fallback: fallback, mapRows: mapRows, mapCols: mapCols)
            return
        }
        guard let template = templates[p.objectId]?.clone(), !template.childNodes.isEmpty else {
            addFallbackBoxes(for: p, to: node, fallback: fallback, mapRows: mapRows, mapCols: mapCols)
            return
        }
        template.isHidden = false
        template.categoryBitMask = 0
        template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
        if config.cellW == 1 && config.cellH == 1 {
            for r in p.row..<(p.row + p.height) {
                for c in p.col..<(p.col + p.width) {
                    let pos = worldPositionAtCell(row: r, col: c, rows: mapRows, cols: mapCols)
                    let instance = template.clone()
                    let isWall = WallParent.isWall(objectId: p.objectId)
                    let placeY: CGFloat
                    if isWall {
                        placeY = groundLevelY
                    } else {
                        let (minB, _) = instance.boundingBox
                        placeY = max(groundLevelY, -CGFloat(minB.y))
                    }
                    let wallShift: (offsetX: CGFloat, offsetZ: CGFloat) = isWall
                        ? applyAdaptiveWallShape(instance, row: r, col: c, wallCells: wallCells)
                        : (offsetX: 0, offsetZ: 0)
                    instance.position = SCNVector3(pos.x + wallShift.offsetX, placeY, pos.z + wallShift.offsetZ)
                    if !isWall {
                        _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: instance, bundle: .main)
                    }
                    let cellPlacement = Placement(id: p.id, objectId: p.objectId, row: r, col: c, width: 1, height: 1, currentHealth: p.currentHealth, ownerId: p.ownerId)
                    applyAdaptiveRoof(to: instance, placement: cellPlacement, wallCells: wallCells)
                    node.addChildNode(instance)
                }
            }
        } else {
            let centerRow = p.row + p.height / 2
            let centerCol = p.col + p.width / 2
            let pos = worldPositionAtCell(row: centerRow, col: centerCol, rows: mapRows, cols: mapCols)
            var (minB, _) = template.boundingBox
            let placeY = max(groundLevelY, -CGFloat(minB.y) + config.yOffset)
            template.position = SCNVector3(pos.x, placeY, pos.z)
            if p.objectId == Smocnica.objectId {
                template.name = "smocnica_place_\(p.id)"
            }
            if p.objectId == Lager.objectId {
                template.name = "lager_place_\(p.id)"
            }
            _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: template, bundle: .main)
            applyAdaptiveRoof(to: template, placement: p, wallCells: wallCells)
            node.addChildNode(template)
        }
    }

    private func applyAdaptiveRoof(to node: SCNNode, placement: Placement, wallCells: Set<MapCoordinate>) {
        guard node.childNode(withName: RoofLogic.nodeName, recursively: true) != nil else { return }
        RoofLogic.apply(to: node, kind: RoofLogic.kind(for: placement, wallCells: wallCells))
    }

    private func refreshPlacements(_ node: SCNNode?, placements: [Placement], templates: [String: SCNNode], mapRows: Int, mapCols: Int) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        node.isHidden = false
        let boxFallback = makePlacementBoxNode()
        boxFallback.categoryBitMask = 0
        let wallCells = wallCellsSet(from: placements)
        for p in placements {
            addPlacementNode(for: p, to: node, templates: templates, fallback: boxFallback, wallCells: wallCells, mapRows: mapRows, mapCols: mapCols)
        }
        if let wallTemplate = templates[HugeWall.objectId], hasAnyDiagonalAdjacency(wallCells) {
            let wallObjectIds = wallCellToObjectId(from: placements)
            let count = addWallDiagonalConnectors(
                to: node,
                wallCells: wallCells,
                focusCells: nil,
                color: NSColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1),
                alpha: 1.0,
                templateForHeight: wallTemplate,
                useWallTexture: true,
                stepsTemplate: templates[Steps.objectId],
                wallObjectIdPerCell: wallObjectIds,
                smallWallTemplate: templates[SmallWall.objectId],
                mapRows: mapRows,
                mapCols: mapCols
            )
            if count > 0 {
                placementDebug("wall diagonal connectors created: \(count)")
            }
        }
    }

    private func refreshWallLinePreview(_ node: SCNNode?, cells: [(Int, Int)], templates: [String: SCNNode], existingWallCells: Set<MapCoordinate>, wallObjectIdPerCell: [MapCoordinate: String] = [:], gameState: GameState? = nil, objectId: String = HugeWall.objectId, mapRows: Int, mapCols: Int) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        guard !cells.isEmpty,
              let template = templates[objectId],
              let config = SceneKitPlacementRegistry.config(for: objectId) else { return }
        let previewSet = Set(cells.map { MapCoordinate(row: $0.0, col: $0.1) })
        let allWallCells = existingWallCells.union(previewSet)
        placementDebug("wall preview update: dragCells=\(cells.count) uniquePreview=\(previewSet.count) existing=\(existingWallCells.count) total=\(allWallCells.count)")
        let canPlace = gameState.map { WallBuildConditions.wallBuildConditionsMet(gameState: $0, objectId: objectId, cells: cells) } ?? true
        let ghostColor = canPlace
            ? NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)
            : NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)
        let slopedLine = isWallLineSloped(cells)
        let slopedByExisting = hasDiagonalAdjacency(in: allWallCells, involving: previewSet)
        let sloped = slopedLine || slopedByExisting
        placementDebug("wall preview slope detection: line=\(slopedLine) existing=\(slopedByExisting) active=\(sloped)")
        let previewIsWall = WallParent.isWall(objectId: objectId)
        for (row, col) in cells {
            let instance = template.clone()
            duplicateMaterialsRecursive(instance)
            let pos = worldPositionAtCell(row: row, col: col, rows: mapRows, cols: mapCols)
            let y: CGFloat
            if previewIsWall {
                y = groundLevelY + config.yOffset
            } else {
                let (minB, _) = instance.boundingBox
                y = max(groundLevelY, -CGFloat(minB.y) + config.yOffset)
            }
            let wallShift = applyAdaptiveWallShape(instance, row: row, col: col, wallCells: allWallCells)
            applyGhostColorRecursive(instance, color: ghostColor, transparency: 0.55)
            instance.position = SCNVector3(pos.x + wallShift.offsetX, y, pos.z + wallShift.offsetZ)
            instance.categoryBitMask = 0
            instance.childNodes.forEach { $0.categoryBitMask = 0 }
            node.addChildNode(instance)
        }
        guard sloped else {
            placementDebug("wall preview render result: connectorNodes=0 (inactive: line is straight)")
            return
        }
        let created = addWallDiagonalConnectors(
            to: node,
            wallCells: allWallCells,
            focusCells: previewSet,
            color: ghostColor,
            alpha: 0.55,
            templateForHeight: template,
            useWallTexture: true,
            stepsTemplate: templates[Steps.objectId],
            wallObjectIdPerCell: wallObjectIdPerCell.isEmpty ? nil : wallObjectIdPerCell,
            smallWallTemplate: templates[SmallWall.objectId],
            mapRows: mapRows,
            mapCols: mapCols
        )
        placementDebug("wall preview render result: connectorNodes=\(created)")
    }

    private func addFallbackBoxes(for p: Placement, to node: SCNNode, fallback: SCNNode, mapRows: Int, mapCols: Int) {
        let fallbackHeight: CGFloat = 8
        for r in p.row..<(p.row + p.height) {
            for c in p.col..<(p.col + p.width) {
                let pos = worldPositionAtCell(row: r, col: c, rows: mapRows, cols: mapCols)
                let n = fallback.clone()
                let y = max(groundLevelY, groundLevelY + fallbackHeight / 2)
                n.position = SCNVector3(pos.x, y, pos.z)
                n.isHidden = false
                n.categoryBitMask = 0
                node.addChildNode(n)
            }
        }
    }

    private func makePlacementBoxNode() -> SCNNode {
        let wallColor = NSColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95)
        let box = SCNBox(width: worldUnitsPerCell, height: 8, length: worldUnitsPerCell, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = wallColor
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        return n
    }

    /// Za jedan objectId: učitaj model (ili koristi `cachedNode`), skaliaj na cellW×cellH, vrati (template, ghost). Ako model nije učitan, ghost = fallback box.
    private func makeTemplateAndGhost(config: SceneKitPlacementConfig, cachedNode: SCNNode? = nil) -> (template: SCNNode?, ghost: SCNNode) {
        let cw = CGFloat(config.cellW)
        let ch = CGFloat(config.cellH)
        let placementNode = cachedNode ?? SceneKitPlacementRegistry.loadSceneKitNode(objectId: config.objectId, bundle: .main)
        guard let placementNode = placementNode else {
            let fallbackGhost = makeGhostFarmObjNode(cellW: config.cellW, cellH: config.cellH)
            return (nil, fallbackGhost)
        }
        let templateContainer = SCNNode()
        placementNode.position = SCNVector3Zero
        templateContainer.addChildNode(placementNode)
        var (minB, maxB) = templateContainer.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.1)
        let dz = max(CGFloat(maxB.z - minB.z), 0.1)
        let dy = max(CGFloat(maxB.y - minB.y), 0.01)
        let scaleX = (cw * worldUnitsPerCell) / dx
        let scaleZ = (ch * worldUnitsPerCell) / dz
        let scaleY: CGFloat
        if WallParent.isWall(objectId: config.objectId) {
            // Zid (veliki/mali) je već u točnoj world skali, bez dodatnog scale-a.
            placementNode.scale = SCNVector3(1, 1, 1)
            if WallParent.isWall(objectId: config.objectId) {
                let finalHeight = dy
                placementDebug("template Wall source(dx=\(String(format: "%.3f", dx)),dy=\(String(format: "%.3f", dy)),dz=\(String(format: "%.3f", dz))) scale(x=1.000,y=1.000,z=1.000) finalHeight=\(String(format: "%.3f", finalHeight))")
            }
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghost_\(config.objectId)"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            return (templateContainer, ghostNode)
        } else if TowerKind.isTower(config.objectId) {
            // Jednoliki scale — okrugla ostaje krug, kvadratna kvadrat (ne elipsa/kocka).
            let target = CGFloat(max(config.cellW, config.cellH)) * worldUnitsPerCell
            let source = max(dx, dz)
            let sc = target / max(source, 0.1)
            placementNode.scale = SCNVector3(sc, sc, sc)
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghost_\(config.objectId)"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            return (templateContainer, ghostNode)
        } else {
            scaleY = min(scaleX, scaleZ)
        }
        placementNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
        let ghostNode = templateContainer.clone()
        duplicateMaterialsRecursive(ghostNode)
        ghostNode.name = "ghost_\(config.objectId)"
        ghostNode.isHidden = true
        ghostNode.categoryBitMask = 0
        ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
        applyTransparencyRecursive(0.6, to: ghostNode)
        return (templateContainer, ghostNode)
    }

    private func applyEditorCellOverlay(coord: Coordinator) {
        guard let node = coord.editorCellOverlayNode else { return }
        guard let mode = editorOverlayMode, gameState.isMapEditorMode, mode != .visina else {
            node.isHidden = true
            coord.editorOverlayKey = nil
            return
        }
        let selected = gameState.mapEditorState?.selectedCell
        let key = "\(mode.rawValue)_\(selected?.cellId ?? "-")_\(gameState.editorCellsVersion)_\(ObjectIdentifier(gameState.gameMap).hashValue)_\(terrainHeightsChecksum(gameMap: gameState.gameMap))"
        if coord.editorOverlayKey != key {
            coord.editorOverlayKey = key
            node.geometry = makeEditorCellOverlayGeometry(gameMap: gameState.gameMap, mode: mode, selected: selected)
        }
        node.isHidden = node.geometry == nil
    }

    private func applyBuildPadOverlay(coord: Coordinator) {
        guard let node = coord.buildPadOverlayNode else { return }
        guard !gameState.isUndergroundView else {
            node.isHidden = true
            return
        }
        let key = "\(gameState.editorCellsVersion)_\(gameState.placementsVersion)_\(ObjectIdentifier(gameState.gameMap).hashValue)_\(terrainHeightsChecksum(gameMap: gameState.gameMap))"
        if coord.buildPadOverlayKey != key {
            coord.buildPadOverlayKey = key
            node.geometry = makeBuildPadOverlayGeometry(gameMap: gameState.gameMap)
        }
        node.isHidden = node.geometry == nil
    }

    private func applyLordStartMarkers(coord: Coordinator) {
        guard let node = coord.lordStartsNode else { return }
        let gameMap = gameState.gameMap
        guard gameState.isMapEditorMode, !gameMap.lordStarts.isEmpty else {
            node.isHidden = true
            return
        }
        let starts = gameMap.lordStarts.sorted { $0.key < $1.key }
        let key = starts.map { "\($0.key):\($0.value.row),\($0.value.col)" }.joined(separator: "|")
            + "_\(selectedLordStartSlot ?? 0)_\(ObjectIdentifier(gameMap).hashValue)_\(terrainHeightsChecksum(gameMap: gameMap))"
        node.isHidden = false
        guard coord.lordStartsKey != key else { return }
        coord.lordStartsKey = key
        node.childNodes.forEach { $0.removeFromParentNode() }
        let halfW = effectiveMapWorldW(cols: gameMap.cols) / 2
        let halfH = effectiveMapWorldH(rows: gameMap.rows) / 2
        let step = worldUnitsPerCell
        for (slot, coordinate) in starts {
            let surface = gameMap.surface(row: coordinate.row, col: coordinate.col)
            let color = LordStartPalette.color(slot: slot)
            let selected = slot == selectedLordStartSlot
            let marker = SCNNode()
            marker.position = SCNVector3(
                (CGFloat(coordinate.col) + 0.5) * step - halfW,
                surface.center.height,
                (CGFloat(coordinate.row) + 0.5) * step - halfH
            )
            func flat(_ c: NSColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = c
                m.lightingModel = .constant
                return m
            }
            let pole = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 5))
            pole.geometry?.materials = [flat(NSColor(white: 0.25, alpha: 1))]
            pole.position = SCNVector3(0, 2.5, 0)
            marker.addChildNode(pole)
            let flag = SCNNode(geometry: SCNBox(width: 1.8, height: 1.1, length: 0.06, chamferRadius: 0))
            flag.geometry?.materials = [flat(color)]
            flag.position = SCNVector3(0.95, 4.4, 0)
            marker.addChildNode(flag)
            let ring = SCNNode(geometry: SCNTube(innerRadius: selected ? 1.6 : 1.3, outerRadius: selected ? 2.0 : 1.5, height: 0.05))
            ring.geometry?.materials = [flat(selected ? .systemYellow : color)]
            ring.position = SCNVector3(0, 0.08, 0)
            marker.addChildNode(ring)
            let text = SCNText(string: "\(slot)", extrusionDepth: 0.05)
            text.font = NSFont.systemFont(ofSize: 1, weight: .bold)
            text.flatness = 0.1
            text.materials = [flat(.white)]
            let label = SCNNode(geometry: text)
            let (minB, maxB) = label.boundingBox
            label.pivot = SCNMatrix4MakeTranslation((maxB.x + minB.x) / 2, (maxB.y + minB.y) / 2, 0)
            label.position = SCNVector3(0, 6, 0)
            label.constraints = [SCNBillboardConstraint()]
            marker.addChildNode(label)
            marker.renderingOrder = 380
            node.addChildNode(marker)
        }
    }

    private func applyGroundwaterOverlay(coord: Coordinator) {
        guard let node = coord.groundwaterOverlayNode else { return }
        let show = gameState.showsGroundwater && !gameState.isMapEditorMode
        if show {
            let mapId = ObjectIdentifier(gameState.gameMap)
            if coord.groundwaterGeometryMap != mapId || node.geometry == nil {
                node.geometry = makeGroundwaterGeometry(gameMap: gameState.gameMap, water: gameState.groundwater)
                coord.groundwaterGeometryMap = mapId
            }
        }
        guard show != coord.groundwaterShown else { return }
        coord.groundwaterShown = show
        if show { node.isHidden = false }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        SCNTransaction.completionBlock = { [weak node] in
            DispatchQueue.main.async {
                if !coord.groundwaterShown { node?.isHidden = true }
            }
        }
        node.opacity = show ? 1 : 0
        SCNTransaction.commit()
    }

    private func applyUndergroundMode(container: SceneKitMapNSView, coord: Coordinator) {
        container.hasPlacementAt = { [gameState] row, col in
            !gameState.isMapEditorMode && gameState.activeMap.placement(at: MapCoordinate(row: row, col: col)) != nil
        }
        container.undergroundEntranceAt = { [gameState] row, col in
            !gameState.isMapEditorMode && !gameState.isGamePaused
                && gameState.undergroundEntrance(row: row, col: col) != nil
        }
        container.onUndergroundEntrance = { [gameState] row, col in
            DispatchQueue.main.async {
                if let entrance = gameState.undergroundEntrance(row: row, col: col) {
                    gameState.enterUnderground(through: entrance)
                }
            }
        }
        let underground = gameState.isUndergroundView
        let levelY: CGFloat = underground ? -Underground.depthMeters : 0
        container.isUnderground = underground
        container.groundPlaneY = levelY
        coord.groundMarkNode?.position = SCNVector3(0, levelY, 0)
        guard coord.lastUnderground != underground, let scene = coord.scene, let layer = coord.undergroundNode else { return }
        let firstApply = coord.lastUnderground == nil
        coord.lastUnderground = underground
        if underground {
            Underground.refreshEntrances(in: layer, placements: gameState.gameMap.placements, rows: coord.mapRows, cols: coord.mapCols)
        }
        let levelNodes = [coord.placementsNode, coord.wallLinePreviewNode].compactMap { $0 }
        for node in levelNodes {
            node.position = SCNVector3(0, levelY, 0)
            node.opacity = firstApply ? 1 : 0
        }
        coord.wallLinePreviewNode?.childNodes.forEach { $0.removeFromParentNode() }
        coord.ghostNodes.values.forEach { $0.isHidden = true }
        if underground {
            refreshPlacements(coord.surfacePlacementsNode, placements: gameState.gameMap.placements, templates: coord.placementTemplates, mapRows: coord.mapRows, mapCols: coord.mapCols)
        }
        // Površina se nikad ne skriva: skrivanje vatri mijenja broj svjetala i ruši Metal validaciju.
        let surface = scene.rootNode.childNodes.filter { node in
            node !== layer && node.camera == nil && node.light == nil
                && node.name != "cameraTarget"
                && node.name != "groundwaterOverlay"
                && node.name != "groundMark"
                && node.name != "transport"
                && node.name != "warehouse"
                && !levelNodes.contains { $0 === node }
                && node.name?.hasPrefix("ghost_") != true
        }
        let duration: CGFloat = firstApply ? 0 : 0.9
        if underground { layer.isHidden = false }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.completionBlock = { [weak layer, weak coord] in
            DispatchQueue.main.async {
                guard let coord, coord.lastUnderground == underground else { return }
                if !underground {
                    layer?.isHidden = true
                    coord.surfacePlacementsNode?.childNodes.forEach { $0.removeFromParentNode() }
                }
            }
        }
        layer.opacity = underground ? 1 : 0
        surface.forEach { $0.opacity = underground ? Underground.surfaceOpacity : 1 }
        levelNodes.forEach { $0.opacity = 1 }
        SCNTransaction.commit()
    }

    private func bindGroundMark(container: SceneKitMapNSView, coord: Coordinator) {
        container.onGroundMarkPreview = { [gameState] pair in
            // Zelena ploha samo dok se vuče / crtа oznaka.
            refreshGroundMark(
                coord.groundMarkNode,
                origin: pair?.0,
                far: pair?.1,
                rows: coord.mapRows,
                cols: coord.mapCols,
                gameMap: gameState.gameMap
            )
            DispatchQueue.main.async {
                if let pair {
                    let mark = GroundMark(
                        originRow: pair.0.row,
                        originCol: pair.0.col,
                        farRow: pair.1.row,
                        farCol: pair.1.col
                    )
                    gameState.groundMark = mark
                    gameState.markedPeople = gameState.people(inside: mark)
                } else {
                    // Samo makni zeleni preview; označene osobe ostaju do cancel / novog nacrta.
                    gameState.groundMark = nil
                }
            }
        }
        container.onGroundMarkCommit = { [gameState] origin, far in
            // Gotovo: zelena nestaje, ostaju samo označene osobe.
            refreshGroundMark(
                coord.groundMarkNode,
                origin: nil,
                far: nil,
                rows: coord.mapRows,
                cols: coord.mapCols,
                gameMap: gameState.gameMap
            )
            DispatchQueue.main.async {
                let mark = GroundMark(
                    originRow: origin.row,
                    originCol: origin.col,
                    farRow: far.row,
                    farCol: far.col
                )
                gameState.groundMark = nil
                gameState.markedPeople = gameState.people(inside: mark)
            }
        }
        container.onGroundMarkDraftStarted = { [gameState] in
            DispatchQueue.main.async {
                gameState.groundMark = nil
                gameState.markedPeople = []
                gameState.moveOrderMarker = nil
            }
        }
        container.onGroundMarkCancelled = { [gameState] in
            DispatchQueue.main.async {
                gameState.groundMark = nil
                gameState.markedPeople = []
                gameState.moveOrderMarker = nil
            }
        }
        let enabled = !gameState.isMapEditorMode
            && gameState.selectedPlacementObjectId == nil
            && !isEraseMode
            && !isTerrainEditMode
            && !isCellSelectionMode
        container.setGroundMarkEnabled(enabled)
        container.hasMarkedSoldiers = { [gameState] in
            gameState.markedPeople.contains {
                $0.isKing || gameState.people.person(id: $0.id)?.canBeMarked == true
            }
        }
        container.onMoveOrder = { [gameState] row, col in
            DispatchQueue.main.async {
                gameState.sendMarkedSoldiers(row: row, col: col)
            }
        }
        container.editingTransportId = gameState.editingTransportId
        container.editingWarehouseRoute = gameState.editingWarehouseRoute != nil
        container.onTransportCornerDrag = { [gameState] index, row, col in
            DispatchQueue.main.async {
                if gameState.editingWarehouseRoute != nil {
                    gameState.moveWarehouseRouteCorner(index: index, row: Double(row), col: Double(col))
                } else if let id = gameState.editingTransportId {
                    gameState.moveTransportCorner(depotId: id, index: index, row: Double(row), col: Double(col))
                }
            }
        }
        container.onTransportMidPromote = { [gameState] index, row, col in
            DispatchQueue.main.async {
                if gameState.editingWarehouseRoute != nil {
                    gameState.promoteWarehouseRouteMid(after: index, row: Double(row), col: Double(col))
                } else if let id = gameState.editingTransportId {
                    gameState.promoteTransportMid(depotId: id, after: index, row: Double(row), col: Double(col))
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.retired = true
        (nsView as? SceneKitMapNSView)?.stopScene()
    }

    private static let zoomLerpFactor: CGFloat = 0.18
    /// Visina kamere u metrima pri zoomu 1. Zoom 8 gleda oko dvorca, ne cijelu mapu s visine.
    private static let cameraBaseHeight: CGFloat = 80

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var retired = false
        var scene: SCNScene?
        var placementsNode: SCNNode?
        var seatsNode: SCNNode?
        var peopleNode: SCNNode?
        var transportNode: SCNNode?
        var warehouseNode: SCNNode?
        var buildingAlertsNode: SCNNode?
        var cameraNode: SCNNode?
        var cameraTarget: SCNNode?
        var pivotIndicatorNode: SCNNode?
        var gridNode: SCNNode?
        var gridNode10: SCNNode?
        var gridNode40: SCNNode?
        var wallLinePreviewNode: SCNNode?
        var groundMarkNode: SCNNode?
        var moveOrderMarkerNode: SCNNode?
        var lastMoveOrderMarkerKey: String?
        var undergroundNode: SCNNode?
        var lastUnderground: Bool?
        var surfacePlacementsNode: SCNNode?
        /// Glatki spust kamere: 0 = tlo, -depth = podzemlje.
        var animatedDepth: CGFloat = 0
        fileprivate weak var mapViewContainer: SceneKitMapNSView?
        var mapRows: Int = 200
        var mapCols: Int = 200
        /// Template po objectId – za kloniranje pri refreshPlacements.
        var placementTemplates: [String: SCNNode] = [:]
        /// Ghost čvor po objectId – prikazuje se pri pomicanju miša kad je objekt odabran.
        var ghostNodes: [String: SCNNode] = [:]
        var lastGhostCellByObject: [String: (Int, Int)] = [:]
        var lastGridZoom: CGFloat = 1
        var lastTerrainHeightsChecksum: Double = 0
        var lastTerrainPadVersion: Int = -1
        var lastTerrainPlacementVersion: Int = -1
        var isTerrainEditMode: Bool = false
        var onTerrainEdit: ((Int, Int) -> Void)?
        var onTerrainAddBrushSelection: ((Int, Int) -> Void)?
        var onCellSelectionToggle: ((Int, Int) -> Void)?
        var terrainPaintSeaPreview: Bool = false
        /// Live click-drag preview (SceneKit-only, bez GameState publish).
        var terrainPaintPreviewCells: Set<MapCoordinate>?
        /// Live nacrt mora dok se vuče kontrolna točka.
        var seaDraftLive: SeaSurfaceDraft?
        /// Live nacrt rijeke dok se vuče / dijeli točka.
        var riverDraftLive: RiverPathDraft?
        var terrainBrushOption: TerrainBrushOption?
        /// Map Editor – zelena površina na terenu za područje pod mišem (bez letećeg elementa).
        var brushPreviewOverlayNode: SCNNode?
        var groundwaterOverlayNode: SCNNode?
        var editorCellOverlayNode: SCNNode?
        var editorOverlayKey: String?
        var buildPadOverlayNode: SCNNode?
        var buildPadOverlayKey: String?
        var lordStartsNode: SCNNode?
        var lordStartsKey: String?
        var groundwaterGeometryMap: ObjectIdentifier?
        var groundwaterShown = false
        /// Map Editor – čvor s oznakama odabranih ćelija (jedna kocka po ćeliji).
        var cellSelectionOverlayNode: SCNNode?
        weak var gameState: GameState?
        /// Glatka animacija: interpolira se prema target zoomu (iz gameState).
        var animatedZoom: CGFloat = 8
        /// 1 = kosi orbit, 0 = odozgo (nacrt). Lerp prema isTopDown.
        var animatedOrbitFactor: CGFloat = 1
        /// Broj placements pri zadnjem updateNSView – da se osvježi prikaz kad korisnik postavi objekt.
        var lastPlacementsCount: Int = -1
        var lastPlacementsVersion: Int = -1
        var pantryStockKey = ""
        var warehouseStockKey = ""
        var lastWarehouseEpoch = -1

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard !retired, gameState?.isShowingMainMenu != true else { return }
            PerformanceMonitor.shared.noteFrame(at: time)
            guard let cam = cameraNode, let target = cameraTarget else { return }
            let targetZoom: CGFloat
            let pan: CGPoint
            let rot: CGFloat
            let targetDepth: CGFloat
            let targetOrbit: CGFloat
            if let gs = gameState {
                targetZoom = gs.mapCameraSettings.currentZoom
                pan = gs.mapCameraSettings.panOffset
                rot = gs.mapCameraSettings.mapRotation
                targetDepth = 0
                targetOrbit = gs.mapCameraSettings.isTopDown ? 0 : 1
            } else {
                targetZoom = animatedZoom
                pan = .zero
                rot = .pi
                targetDepth = 0
                targetOrbit = 1
            }
            animatedZoom += (targetZoom - animatedZoom) * SceneKitMapView.zoomLerpFactor
            let depthStep = targetDepth - animatedDepth
            animatedDepth = abs(depthStep) < 0.01 ? targetDepth : animatedDepth + depthStep * 0.07
            animatedOrbitFactor += (targetOrbit - animatedOrbitFactor) * 0.14
            if abs(targetOrbit - animatedOrbitFactor) < 0.002 { animatedOrbitFactor = targetOrbit }
            let h = SceneKitMapView.cameraBaseHeight / animatedZoom
            // Maleni horizontalni ostatak (~2 %) sprječava gimbal lock lookAt kad je odozgo.
            let orbitRadius = h * (0.02 + 0.98 * animatedOrbitFactor)
            let r = CGFloat(-rot)
            target.position = SCNVector3(pan.x, animatedDepth, pan.y)
            cam.position = SCNVector3(
                pan.x + sin(r) * orbitRadius,
                h + animatedDepth,
                pan.y + cos(r) * orbitRadius
            )
            if let gs = gameState, let stores = placementsNode {
                let key = AppleBasketShapes.stockKey(gs)
                if key != pantryStockKey {
                    pantryStockKey = key
                    AppleBasketShapes.refreshPantries(in: stores, gameState: gs)
                }
            }
            if let gs = gameState, let warehouseNode {
                let key = WarehouseStacks.stockKey(gs)
                if key != warehouseStockKey {
                    warehouseStockKey = key
                    lastWarehouseEpoch = gs.warehouseGoodsEpoch
                    WarehouseStacks.syncWorld(on: warehouseNode, gameState: gs, rows: mapRows, cols: mapCols)
                }
            }
            if let gs = gameState, let seats = seatsNode {
                let markedKing = Set(gs.markedPeople.filter(\.isKing).compactMap { mark -> String? in
                    let id = mark.id
                    guard id.hasPrefix("king:") else { return nil }
                    return String(id.dropFirst(5))
                })
                syncRealmSeats(
                    on: seats,
                    snapshots: gs.realmSeats.copySnapshots(),
                    rings: gs.populationRing.copySnapshots(),
                    rows: mapRows,
                    cols: mapCols,
                    gameMap: gs.gameMap,
                    markedKingFactionIds: markedKing
                )
            }
            if let gs = gameState, let peopleNode {
                let markedIds = Set(gs.markedPeople.map(\.id))
                let snaps = gs.people.copySnapshots().map { snap -> PersonRenderSnapshot in
                    var copy = snap
                    copy.marked = markedIds.contains(snap.id)
                    return copy
                }
                syncPeople(on: peopleNode, snapshots: snaps, rows: mapRows, cols: mapCols, viewUnderground: gs.isUndergroundView, gameMap: gs.gameMap)
            }
            if let gs = gameState {
                refreshMoveOrderMarker(
                    moveOrderMarkerNode,
                    marker: gs.moveOrderMarker,
                    viewUnderground: gs.isUndergroundView,
                    rows: mapRows,
                    cols: mapCols,
                    gameMap: gs.gameMap,
                    lastKey: &lastMoveOrderMarkerKey
                )
            }
            if let gs = gameState, let transportNode {
                syncTransport(on: transportNode, lines: gs.transportLines, oxen: gs.oxen.copySnapshots(),
                              editingId: gs.editingTransportId, rows: mapRows, cols: mapCols)
            }
            if let gs = gameState, let warehouseNode {
                let stores = gs.mapLogic.allPlacements.map(\.placement).filter { StorageKind.of(buildingId: $0.objectId) != nil }
                syncWarehouse(on: warehouseNode, layouts: gs.warehouseLayouts, stores: stores,
                              editing: gs.editingWarehouseRoute, inspectedId: gs.inspectedPlacementId,
                              rows: mapRows, cols: mapCols)
            }
            if let gs = gameState, let buildingAlertsNode {
                let alerts = gs.isMapEditorMode ? [] : gs.buildingAlerts.copySnapshots()
                syncBuildingAlerts(on: buildingAlertsNode, snapshots: alerts, rows: mapRows, cols: mapCols)
            }
            // Ne pozivaj updateGhostFromCurrentMouseLocation ovdje – renderer radi na pozadinskoj niti (renderingQueue),
            // a convertPoint/bounds moraju na main thread. Ghost i brush ažuriraju se u onMouseMove (mouseMoved/mouseEntered).
        }
    }

    /// Ghost box za objekte kad 3D model nije učitan (fallback u makeTemplateAndGhost).
    private func makeGhostFarmObjNode(cellW: Int, cellH: Int) -> SCNNode {
        let w = CGFloat(cellW) * worldUnitsPerCell
        let h = CGFloat(cellH) * worldUnitsPerCell
        let box = SCNBox(width: w, height: 8, length: h, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = NSColor.white
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        applyTransparencyRecursive(0.6, to: n)
        return n
    }

    private func applyTransparencyRecursive(_ value: CGFloat, to node: SCNNode) {
        node.geometry?.materials.forEach { $0.transparency = value }
        node.childNodes.forEach { applyTransparencyRecursive(value, to: $0) }
    }

    /// Ghost je klon templatea – SceneKit clone() dijeli geometry i materijale. Da zelena ostane samo na ghostu,
    /// ghost mora imati vlastitu kopiju geometryja i materijala (inače mijenjamo i template i već postavljene zidove).
    private func duplicateMaterialsRecursive(_ node: SCNNode) {
        if let geo = node.geometry, !geo.materials.isEmpty, let newGeo = geo.copy() as? SCNGeometry {
            newGeo.materials = geo.materials.map { old in
                let m = SCNMaterial()
                m.diffuse.contents = old.diffuse.contents
                m.emission.contents = old.emission.contents
                m.ambient.contents = old.ambient.contents
                m.specular.contents = old.specular.contents
                m.transparency = old.transparency
                m.isDoubleSided = old.isDoubleSided
                m.lightingModel = old.lightingModel
                m.diffuse.wrapS = old.diffuse.wrapS
                m.diffuse.wrapT = old.diffuse.wrapT
                return m
            }
            node.geometry = newGeo
        }
        node.childNodes.forEach { duplicateMaterialsRecursive($0) }
    }

    /// Postavi boju ghost zida: zelena = dostupno (za sada uvijek zelena; kasnije + crvena kad ne može).
    private func applyGhostColorRecursive(_ node: SCNNode?, color: NSColor, transparency: CGFloat = 0.55) {
        guard let node = node else { return }
        node.geometry?.materials.forEach { mat in
            mat.diffuse.contents = color
            mat.emission.contents = NSColor(white: 0, alpha: 0)
            mat.transparency = transparency
            mat.lightingModel = .constant
        }
        node.childNodes.forEach { applyGhostColorRecursive($0, color: color, transparency: transparency) }
    }
}
