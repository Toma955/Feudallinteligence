//
//  GrassPatch.swift
//  Feudalism
//
//  Guste uspravne vlati na kafenastoj podlozi.
//

import SceneKit

enum GrassPatch {
    static func make(side: CGFloat = 2.2) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(soil(side: side))
        root.addChildNode(blades(side: side))
        return root
    }

    private static func soil(side: CGFloat) -> SCNNode {
        let box = SCNBox(width: side, height: 0.14, length: side, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(calibratedRed: 0.40, green: 0.27, blue: 0.15, alpha: 1)
        mat.lightingModel = .blinn
        box.materials = [mat]
        let node = SCNNode(geometry: box)
        node.position.y = 0.07
        return node
    }

    private static func blades(side: CGFloat) -> SCNNode {
        let spacing: Float = 0.03
        let half = Float(side) * 0.5 - spacing
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [UInt32] = []

        var ix = 0
        var x = -half
        while x <= half {
            var iz = 0
            var z = -half
            while z <= half {
                addBlade(x: x, z: z, ix: ix, iz: iz, vertices: &vertices, normals: &normals, colors: &colors, indices: &indices)
                iz += 1
                z += spacing
            }
            ix += 1
            x += spacing
        }

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
        mat.lightingModel = .lambert
        mat.isDoubleSided = true
        mat.locksAmbientWithDiffuse = true
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.position.y = 0.14
        return node
    }

    private static func addBlade(
        x: Float, z: Float, ix: Int, iz: Int,
        vertices: inout [SCNVector3], normals: inout [SCNVector3], colors: inout [Float], indices: inout [UInt32]
    ) {
        let h1 = unit(ix, iz, 1)
        let h2 = unit(ix, iz, 2)
        let h3 = unit(ix, iz, 3)
        let height = 0.16 + h1 * 0.2
        let width = 0.007 + h2 * 0.008
        let yaw = h3 * Float.pi * 2
        let lean = 0.015 + unit(ix, iz, 4) * 0.05
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        let tipX = x + sinY * lean
        let tipZ = z + cosY * lean
        let left = SCNVector3(x - cosY * width, 0, z + sinY * width)
        let right = SCNVector3(x + cosY * width, 0, z - sinY * width)
        let tip = SCNVector3(tipX, height, tipZ)
        let normal = faceNormal(left, right, tip)
        let base = UInt32(vertices.count)
        vertices.append(contentsOf: [left, right, tip])
        normals.append(contentsOf: [normal, normal, normal])
        let deep = 0.1 + unit(ix, iz, 5) * 0.12
        let bright = 0.55 + unit(ix, iz, 6) * 0.3
        colors.append(contentsOf: [
            deep, 0.34 + h1 * 0.12, 0.06,
            deep, 0.38 + h2 * 0.1, 0.07,
            bright, 0.72 + h3 * 0.16, 0.16
        ])
        indices.append(contentsOf: [base, base + 1, base + 2])
    }

    private static func faceNormal(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> SCNVector3 {
        let e1 = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let e2 = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        var n = SCNVector3(
            e1.y * e2.z - e1.z * e2.y,
            e1.z * e2.x - e1.x * e2.z,
            e1.x * e2.y - e1.y * e2.x
        )
        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        guard len > 1e-5 else { return SCNVector3(0, 1, 0) }
        n.x /= len
        n.y /= len
        n.z /= len
        return n
    }

    private static func unit(_ x: Int, _ z: Int, _ salt: Int) -> Float {
        var n = UInt32(truncatingIfNeeded: x) &* 374761393
        n &+= UInt32(truncatingIfNeeded: z) &* 668265263
        n &+= UInt32(truncatingIfNeeded: salt) &* 1440671
        n = (n ^ (n >> 13)) &* 1274126177
        return Float(n & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
