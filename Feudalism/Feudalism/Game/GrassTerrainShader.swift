//
//  GrassTerrainShader.swift
//  Feudalism
//
//  Trava se slaže u Metalovom prolazu, ne iz slike.
//

import SceneKit

enum GrassTerrainShader {
    static let program: SCNProgram = {
        let program = SCNProgram()
        program.vertexFunctionName = "feudalismGrassVertex"
        program.fragmentFunctionName = "feudalismGrassFragment"
        program.isOpaque = true
        program.delegate = GrassTerrainShaderLog.shared
        return program
    }()
}

private final class GrassTerrainShaderLog: NSObject, SCNProgramDelegate {
    static let shared = GrassTerrainShaderLog()

    func program(_ program: SCNProgram, handleError error: Error) {
        print("Trava: \(error.localizedDescription)")
    }
}
