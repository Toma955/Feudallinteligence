//
//  StoneGroundShader.swift
//  Feudalism
//
//  Kamenito tlo u Metalovom prolazu: grbavo, tamna i svijetla siva.
//

import SceneKit

enum StoneGroundShader {
    static let program: SCNProgram = make(fragment: "feudalismStoneFragment")
    static let ironProgram: SCNProgram = make(fragment: "feudalismIronFragment")

    private static func make(fragment: String) -> SCNProgram {
        let program = SCNProgram()
        program.vertexFunctionName = "feudalismStoneVertex"
        program.fragmentFunctionName = fragment
        program.isOpaque = true
        program.delegate = StoneGroundShaderLog.shared
        return program
    }
}

private final class StoneGroundShaderLog: NSObject, SCNProgramDelegate {
    static let shared = StoneGroundShaderLog()

    func program(_ program: SCNProgram, handleError error: Error) {
        print("Kamen: \(error.localizedDescription)")
    }
}
