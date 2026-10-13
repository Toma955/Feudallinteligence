//
//  RiverWaterShader.swift
//  Feudalism
//
//  Rijeka u Metalovom prolazu: svijetlo plava, prozirna voda.
//

import SceneKit

enum RiverWaterShader {
    static let program: SCNProgram = make(fragment: "feudalismRiverFragment")
    static let seaProgram: SCNProgram = make(fragment: "feudalismSeaFragment")

    private static func make(fragment: String) -> SCNProgram {
        let program = SCNProgram()
        program.vertexFunctionName = "feudalismRiverVertex"
        program.fragmentFunctionName = fragment
        program.isOpaque = false
        program.delegate = RiverWaterShaderLog.shared
        return program
    }
}

private final class RiverWaterShaderLog: NSObject, SCNProgramDelegate {
    static let shared = RiverWaterShaderLog()

    func program(_ program: SCNProgram, handleError error: Error) {
        print("Rijeka: \(error.localizedDescription)")
    }
}
