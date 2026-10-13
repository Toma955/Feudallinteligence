//
//  RockPile.swift
//  Feudalism
//
//  Grbave gromade: tvrde plohe, tamna i svijetla siva, sitno i krupno.
//

import SceneKit
import simd

enum RockPile {
    static func make(side: CGFloat = 2.2) -> SCNNode {
        let root = SCNNode()
        let bed = SCNBox(width: side, height: 0.12, length: side, chamferRadius: 0)
        let bedMat = SCNMaterial()
        bedMat.diffuse.contents = NSColor(calibratedWhite: 0.22, alpha: 1)
        bedMat.lightingModel = .lambert
        bed.materials = [bedMat]
        let bedNode = SCNNode(geometry: bed)
        bedNode.position.y = 0.06
        root.addChildNode(bedNode)

        let surface: Float = 0.12
        let cols = 7
        let step = Float(side) / Float(cols)
        var index = 0
        for row in 0..<cols {
            for col in 0..<cols {
                let big = unit(index, 1) > 0.62
                let radius = step * (big ? 0.46 : 0.34)
                let (v, n, c, ix) = mesh(radius: radius, seed: index, tint: nil)
                let minY = v.map { Float($0.y) }.min() ?? 0
                let rock = geometryNode(vertices: v, normals: n, colors: c, indices: ix)
                let x = (Float(col) + 0.5) * step - Float(side) * 0.5
                let z = (Float(row) + 0.5) * step - Float(side) * 0.5
                rock.eulerAngles.y = CGFloat(unit(index, 7) * 6.2)
                rock.position = SCNVector3(CGFloat(x), CGFloat(surface - minY), CGFloat(z))
                root.addChildNode(rock)
                index += 1
            }
        }
        return root
    }

    /// Željezna ruda: gusto sitno kamenje, hrđa, smeđa i tamno siva.
    static func makeIron(side: CGFloat = 2.2) -> SCNNode {
        let root = SCNNode()
        let bed = SCNBox(width: side, height: 0.1, length: side, chamferRadius: 0)
        let bedMat = SCNMaterial()
        bedMat.diffuse.contents = NSColor(calibratedRed: 0.28, green: 0.16, blue: 0.12, alpha: 1)
        bedMat.lightingModel = .lambert
        bed.materials = [bedMat]
        let bedNode = SCNNode(geometry: bed)
        bedNode.position.y = 0.05
        root.addChildNode(bedNode)

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [UInt32] = []
        let surface: Float = 0.10
        let count = 16
        let step = Float(side) / Float(count)
        var index = 0
        for row in 0..<count {
            for col in 0..<count {
                let radius = step * (0.42 + unit(index, 2) * 0.12)
                let tint = ironTint(index)
                let (v, n, c, ix) = mesh(radius: radius, seed: index &+ 80, tint: tint)
                let yaw = unit(index, 7) * 6.2
                var minY = Float.greatestFiniteMagnitude
                let base = UInt32(vertices.count)
                let x = (Float(col) + 0.5) * step - Float(side) * 0.5
                let z = (Float(row) + 0.5) * step - Float(side) * 0.5
                var placed: [(SIMD3<Float>, SIMD3<Float>)] = []
                for i in v.indices {
                    let p = rotateY(SIMD3(Float(v[i].x), Float(v[i].y), Float(v[i].z)), yaw)
                    let nn = rotateY(SIMD3(Float(n[i].x), Float(n[i].y), Float(n[i].z)), yaw)
                    placed.append((p, nn))
                    minY = min(minY, p.y)
                }
                let lift = surface - minY
                for (p, nn) in placed {
                    vertices.append(SCNVector3(p.x + x, p.y + lift, p.z + z))
                    normals.append(SCNVector3(nn.x, nn.y, nn.z))
                }
                colors.append(contentsOf: c)
                indices.append(contentsOf: ix.map { $0 &+ base })
                index += 1
            }
        }
        root.addChildNode(geometryNode(vertices: vertices, normals: normals, colors: colors, indices: indices))
        return root
    }

    private static func geometryNode(vertices: [SCNVector3], normals: [SCNVector3], colors: [Float], indices: [UInt32]) -> SCNNode {
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
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
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vertexSource, normalSource, colorSource], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        mat.lightingModel = .blinn
        mat.specular.contents = NSColor(white: 0.25, alpha: 1)
        mat.shininess = 0.15
        mat.locksAmbientWithDiffuse = true
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private static func mesh(radius: Float, seed: Int, tint: (Float, Float, Float)?) -> ([SCNVector3], [SCNVector3], [Float], [UInt32]) {
        let t = Float((1 + sqrt(5)) / 2)
        let base: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1)
        ].map { normalize($0) }
        let faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]
        let stretch = SIMD3<Float>(
            0.75 + unit(seed, 11) * 0.6,
            0.65 + unit(seed, 12) * 0.55,
            0.75 + unit(seed, 13) * 0.6
        )
        let points = base.enumerated().map { index, point in
            let n = 0.82 + unit(seed &+ index, 20) * 0.36
            return point * stretch * radius * n
        }
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [UInt32] = []
        for (a, b, c) in faces {
            let pa = points[a], pb = points[b], pc = points[c]
            let n = normalize(cross(pb - pa, pc - pa))
            let up = max(0, n.y)
            let (r, g, b): (Float, Float, Float)
            if let tint {
                let shade = 0.55 + up * 0.6
                r = tint.0 * shade
                g = tint.1 * shade
                b = tint.2 * shade
            } else {
                let gray = 0.16 + up * 0.34 + unit(seed, a &+ 30) * 0.14
                r = gray
                g = gray + 0.01
                b = gray + 0.02
            }
            let start = UInt32(vertices.count)
            for p in [pa, pb, pc] {
                vertices.append(SCNVector3(p.x, p.y, p.z))
                normals.append(SCNVector3(n.x, n.y, n.z))
                colors.append(contentsOf: [r, g, b])
            }
            indices.append(contentsOf: [start, start + 1, start + 2])
        }
        return (vertices, normals, colors, indices)
    }

    private static func ironTint(_ seed: Int) -> (Float, Float, Float) {
        let pick = unit(seed, 40)
        if pick < 0.30 { return (0.32, 0.26, 0.24) }
        if pick < 0.58 { return (0.62, 0.28, 0.16) }
        if pick < 0.82 { return (0.42, 0.22, 0.16) }
        return (0.78, 0.50, 0.24)
    }

    private static func rotateY(_ v: SIMD3<Float>, _ yaw: Float) -> SIMD3<Float> {
        let c = cos(yaw)
        let s = sin(yaw)
        return SIMD3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }

    private static func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let len = simd_length(v)
        return len > 1e-5 ? v / len : SIMD3(0, 1, 0)
    }

    private static func unit(_ x: Int, _ salt: Int) -> Float {
        var n = UInt32(truncatingIfNeeded: x) &* 374761393
        n &+= UInt32(truncatingIfNeeded: salt) &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Float(n & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
