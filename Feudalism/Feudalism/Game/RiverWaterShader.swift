//
//  RiverWaterShader.swift
//  Feudalism
//
//  Metal shader za vodu (RiverWater.metal):
//  - feudalismSeaVertex / feudalismSeaFragment  → more (plavo, prozirno, valovi)
//  - feudalismRiverVertex / feudalismRiverFragment → rijeka
//

import SceneKit
import AppKit

enum RiverWaterShader {
    static let program: SCNProgram = make(vertex: "feudalismRiverVertex", fragment: "feudalismRiverFragment")
    static let seaProgram: SCNProgram = make(vertex: "feudalismSeaVertex", fragment: "feudalismSeaFragment")

    private static func make(vertex: String, fragment: String) -> SCNProgram {
        let program = SCNProgram()
        program.vertexFunctionName = vertex
        program.fragmentFunctionName = fragment
        program.isOpaque = false
        program.delegate = RiverWaterShaderLog.shared
        return program
    }

    /// Površina mora na mapi — Metal (valovi + fresnel + plava prozirnost).
    static func applySeaSurface(to mat: SCNMaterial) {
        mat.program = seaProgram
        mat.isDoubleSided = true
        mat.cullMode = .back
        mat.blendMode = .alpha
        mat.transparencyMode = .singleLayer
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        mat.lightingModel = .constant
        // Ako Metal padne, SceneKit može pokazati diffuse — plavo more.
        mat.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.42, blue: 0.88, alpha: 0.55)
        mat.transparency = 0.40
    }

    /// Rijeka (isti Metal prolaz, blaži valovi).
    static func applyRiverSurface(to mat: SCNMaterial) {
        mat.program = program
        mat.isDoubleSided = true
        mat.cullMode = .back
        mat.blendMode = .alpha
        mat.transparencyMode = .singleLayer
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        mat.lightingModel = .constant
        mat.diffuse.contents = NSColor(calibratedRed: 0.40, green: 0.72, blue: 0.92, alpha: 0.45)
        mat.transparency = 0.45
    }

    /// ObjectPreview / katalog.
    static func applySeaSurfaceWaves(to mat: SCNMaterial) {
        applySeaSurface(to: mat)
    }
}

private final class RiverWaterShaderLog: NSObject, SCNProgramDelegate {
    static let shared = RiverWaterShaderLog()

    func program(_ program: SCNProgram, handleError error: Error) {
        print("Voda (Metal): \(error.localizedDescription)")
    }
}
