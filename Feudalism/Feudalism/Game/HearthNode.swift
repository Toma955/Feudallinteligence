//
//  HearthNode.swift
//  Feudalism
//
//  Vatra ispred dvorca. Čvor "hearth" je mjesto okupljanja za buduće ljude.
//

import SceneKit
import AppKit

enum GatheringHearth {
    /// Metri od zida do središta vatre.
    static let standOff: CGFloat = 2.2

    static func frontOffset(footprintMeters: CGFloat) -> CGFloat {
        footprintMeters / 2 + standOff
    }

    static func makeNode() -> SCNNode {
        let root = SCNNode()
        root.name = "hearth"
        root.categoryBitMask = 1

        let ash = SCNCylinder(radius: 0.58, height: 0.05)
        ash.materials = [stoneMaterial(NSColor(white: 0.16, alpha: 1))]
        let ashNode = SCNNode(geometry: ash)
        ashNode.position = SCNVector3(0, 0.025, 0)
        ashNode.categoryBitMask = 1
        root.addChildNode(ashNode)

        for i in 0..<2 {
            let log = SCNCylinder(radius: 0.07, height: 0.85)
            log.materials = [stoneMaterial(NSColor(red: 0.28, green: 0.16, blue: 0.08, alpha: 1))]
            let logNode = SCNNode(geometry: log)
            logNode.eulerAngles = SCNVector3(0, CGFloat(i) * 0.7, .pi / 2)
            logNode.position = SCNVector3(0, 0.1, 0)
            logNode.categoryBitMask = 1
            root.addChildNode(logNode)
        }

        let stoneColors = [
            NSColor(red: 0.42, green: 0.4, blue: 0.36, alpha: 1),
            NSColor(red: 0.32, green: 0.3, blue: 0.27, alpha: 1),
            NSColor(red: 0.5, green: 0.46, blue: 0.4, alpha: 1)
        ]
        for i in 0..<12 {
            let angle = CGFloat(i) / 12 * .pi * 2
            let radius: CGFloat = 0.78 + (i % 2 == 0 ? 0.05 : 0)
            let stone = SCNSphere(radius: i % 3 == 0 ? 0.16 : 0.12)
            stone.materials = [stoneMaterial(stoneColors[i % stoneColors.count])]
            let stoneNode = SCNNode(geometry: stone)
            stoneNode.position = SCNVector3(cos(angle) * radius, 0.07, sin(angle) * radius)
            stoneNode.scale = SCNVector3(1.15, 0.62, 0.9)
            stoneNode.eulerAngles.y = angle
            stoneNode.categoryBitMask = 1
            root.addChildNode(stoneNode)
        }

        let glow = SCNCylinder(radius: 0.42, height: 0.02)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(red: 1, green: 0.45, blue: 0.08, alpha: 0.55)
        glowMat.emission.contents = NSColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
        glowMat.lightingModel = .constant
        glowMat.blendMode = .add
        glow.materials = [glowMat]
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(0, 0.06, 0)
        glowNode.categoryBitMask = 1
        root.addChildNode(glowNode)

        let flames = SCNNode()
        flames.position = SCNVector3(0, 0.18, 0)
        flames.categoryBitMask = 1
        flames.addParticleSystem(flameSystem(core: true))
        flames.addParticleSystem(flameSystem(core: false))
        flames.addParticleSystem(smokeSystem())
        root.addChildNode(flames)

        let lightNode = SCNNode()
        lightNode.position = SCNVector3(0, 0.45, 0)
        let light = SCNLight()
        light.type = .omni
        light.color = NSColor(red: 1, green: 0.55, blue: 0.18, alpha: 1)
        light.intensity = 640
        light.attenuationStartDistance = 0.3
        light.attenuationEndDistance = 7
        lightNode.light = light
        lightNode.categoryBitMask = 1
        lightNode.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.run { node in
                node.light?.intensity = CGFloat.random(in: 460...820)
            },
            SCNAction.wait(duration: 0.09)
        ])), forKey: "flicker")
        root.addChildNode(lightNode)
        return root
    }

    private static func stoneMaterial(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .blinn
        return mat
    }

    private static func flameSystem(core: Bool) -> SCNParticleSystem {
        let fire = SCNParticleSystem()
        fire.loops = true
        fire.birthRate = core ? 46 : 70
        fire.particleLifeSpan = core ? 0.38 : 0.7
        fire.particleLifeSpanVariation = 0.15
        fire.particleSize = core ? 0.22 : 0.42
        fire.particleSizeVariation = core ? 0.08 : 0.16
        fire.particleVelocity = core ? 0.55 : 0.9
        fire.particleVelocityVariation = 0.25
        fire.emittingDirection = SCNVector3(0, 1, 0)
        fire.spreadingAngle = core ? 12 : 22
        fire.acceleration = SCNVector3(0, core ? 1.1 : 0.7, 0)
        fire.particleColor = core
            ? NSColor(red: 1, green: 0.92, blue: 0.55, alpha: 1)
            : NSColor(red: 1, green: 0.42, blue: 0.08, alpha: 1)
        fire.particleColorVariation = SCNVector4(0.05, 0.15, 0.05, 0.15)
        fire.blendMode = .additive
        fire.particleImage = glowImage
        fire.warmupDuration = 0.6
        fire.isAffectedByGravity = false
        fire.emitterShape = SCNSphere(radius: core ? 0.08 : 0.16)
        fire.birthLocation = .surface
        return fire
    }

    private static func smokeSystem() -> SCNParticleSystem {
        let smoke = SCNParticleSystem()
        smoke.loops = true
        smoke.birthRate = 8
        smoke.particleLifeSpan = 1.6
        smoke.particleLifeSpanVariation = 0.4
        smoke.particleSize = 0.35
        smoke.particleSizeVariation = 0.2
        smoke.particleVelocity = 0.35
        smoke.particleVelocityVariation = 0.15
        smoke.emittingDirection = SCNVector3(0, 1, 0)
        smoke.spreadingAngle = 14
        smoke.acceleration = SCNVector3(0, 0.25, 0)
        smoke.particleColor = NSColor(white: 0.55, alpha: 0.28)
        smoke.blendMode = .alpha
        smoke.particleImage = glowImage
        smoke.warmupDuration = 1
        smoke.isAffectedByGravity = false
        smoke.emitterShape = SCNSphere(radius: 0.1)
        return smoke
    }

    private static let glowImage: NSImage = {
        let side: CGFloat = 64
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let colors = [
                NSColor(calibratedRed: 1, green: 0.96, blue: 0.75, alpha: 1),
                NSColor(calibratedRed: 1, green: 0.5, blue: 0.08, alpha: 0.55),
                NSColor(calibratedRed: 0.7, green: 0.08, blue: 0, alpha: 0)
            ]
            guard let gradient = NSGradient(colors: colors, atLocations: [0, 0.42, 1] as [CGFloat], colorSpace: .deviceRGB) else {
                return false
            }
            let center = NSPoint(x: rect.midX, y: rect.midY)
            gradient.draw(fromCenter: center, radius: 0, toCenter: center, radius: side / 2, options: [])
            return true
        }
    }()
}
