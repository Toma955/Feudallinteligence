//
//  EarthGroundMaterial.swift
//  Feudalism
//
//  Kontinuirana zemlja: splat težine po ćeliji, miješanje po pikselu u Metal shaderu.
//

import SceneKit
import simd

struct EarthUniforms {
    var origin: SIMD2<Float>
    var mapSize: SIMD2<Float>
    var preview: Float
    var previewSize: Float
    var pad: SIMD2<Float> = .zero
}

enum EarthGroundMaterial {
    static let program: SCNProgram = {
        let program = SCNProgram()
        program.vertexFunctionName = "feudalismEarthVertex"
        program.fragmentFunctionName = "feudalismEarthFragment"
        program.isOpaque = true
        program.handleBinding(ofBufferNamed: "earth", frequency: .perNode) { buffer, _, shadable, _ in
            let pack = (shadable as? SCNMaterial)?.value(forKey: "earthPack") as? EarthPack
            var uniforms = pack?.uniforms ?? EarthUniforms(origin: .zero, mapSize: SIMD2(200, 200), preview: 0, previewSize: 2.2)
            buffer.writeBytes(&uniforms, count: MemoryLayout<EarthUniforms>.stride)
        }
        program.delegate = EarthGroundLog.shared
        return program
    }()

    static func apply(to material: SCNMaterial, rows: Int, cols: Int, origin: SIMD2<Float>, mapSize: SIMD2<Float>, preview: Bool) {
        let pack = EarthPack()
        pack.uniforms = EarthUniforms(
            origin: origin,
            mapSize: mapSize,
            preview: preview ? 1 : 0,
            previewSize: 2.2
        )
        material.program = program
        material.setValue(pack, forKey: "earthPack")
        let atlas = EarthTiles.colorAtlas() ?? NSImage(size: NSSize(width: 4, height: 4))
        let splatImage = EarthTiles.splat(rows: max(2, rows), cols: max(2, cols), salt: preview ? 4 : 1)
            ?? NSImage(size: NSSize(width: 4, height: 4))
        let colors = SCNMaterialProperty(contents: atlas)
        colors.magnificationFilter = .linear
        colors.minificationFilter = .linear
        colors.mipFilter = .linear
        colors.wrapS = .repeat
        colors.wrapT = .repeat
        let splat = SCNMaterialProperty(contents: splatImage)
        splat.magnificationFilter = .linear
        splat.minificationFilter = .linear
        splat.mipFilter = .none
        splat.wrapS = .clamp
        splat.wrapT = .clamp
        material.setValue(colors, forKey: "colors")
        material.setValue(splat, forKey: "splat")
        material.diffuse.contents = atlas
        material.lightingModel = .constant
        material.isDoubleSided = true
    }

    static func applyTerrain(_ material: SCNMaterial, map: GameMap) {
        let width = Float(map.cols)
        let height = Float(map.rows)
        apply(
            to: material,
            rows: map.rows,
            cols: map.cols,
            origin: SIMD2(-width * 0.5, -height * 0.5),
            mapSize: SIMD2(width, height),
            preview: false
        )
    }

    static func applyPreview(_ material: SCNMaterial) {
        apply(to: material, rows: 16, cols: 16, origin: .zero, mapSize: SIMD2(2.2, 2.2), preview: true)
    }
}

final class EarthPack: NSObject {
    var uniforms = EarthUniforms(origin: .zero, mapSize: SIMD2(200, 200), preview: 0, previewSize: 2.2)
}

private final class EarthGroundLog: NSObject, SCNProgramDelegate {
    static let shared = EarthGroundLog()

    func program(_ program: SCNProgram, handleError error: Error) {
        print("Zemlja: \(error.localizedDescription)")
    }
}
