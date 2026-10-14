//
//  ObjectPreviewView.swift
//  Feudalism
//
//  Mali 3D pregled jednog objekta ili podloge (About izbornik).
//

import SwiftUI
import SceneKit
import AppKit

enum AboutPreviewTiming {
    static func after(slot: Int, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02 + Double(slot) * 0.04) {
            work()
        }
    }
}

struct ObjectPreviewView: NSViewRepresentable {
    var objectId: String
    var slot: Int = 0

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        view.backgroundColor = NSColor(white: 0.08, alpha: 0.95)
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if view.scene == nil {
            guard !context.coordinator.scheduled else { return }
            context.coordinator.scheduled = true
            let objectId = objectId
            let slot = slot
            AboutPreviewTiming.after(slot: slot) { [weak view] in
                guard let view, view.scene == nil else { return }
                apply(objectId: objectId, to: view)
                context.coordinator.shownId = objectId
            }
            return
        }
        guard context.coordinator.shownId != objectId else { return }
        apply(objectId: objectId, to: view)
        context.coordinator.shownId = objectId
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shownId: String?
        var scheduled = false
    }

    private func apply(objectId: String, to view: SCNView) {
        let scene = SCNScene()
        let node = previewNode(objectId: objectId)
        fit(node, in: scene)
        addSpin(node)
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "about_camera", recursively: false)
    }

    private func previewNode(objectId: String) -> SCNNode {
        if let cached = GameAssetLoader.shared.cachedPlacementNode(objectId: objectId)?.clone() {
            return cached
        }
        if let node = SceneKitPlacementRegistry.loadSceneKitNode(objectId: objectId, bundle: .main) {
            return node
        }
        if objectId == Food.objectId { return BuildingShapes.foodHall() }
        if objectId == Industry.objectId { return BuildingShapes.industryHall() }
        if let name = ObjectCatalog.shared.object(id: objectId)?.name,
           let node = BuildingShapes.catalogFallback(name: name) {
            return node
        }
        return placeholderNode()
    }

    private func placeholderNode() -> SCNNode {
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.02)
        box.firstMaterial?.diffuse.contents = NSColor(white: 0.45, alpha: 1)
        return SCNNode(geometry: box)
    }

    private func fit(_ node: SCNNode, in scene: SCNScene) {
        scene.rootNode.addChildNode(node)
        let (minB, maxB) = hierarchyBounds(node)
        let dx = max(CGFloat(maxB.x - minB.x), 0.2)
        let dy = max(CGFloat(maxB.y - minB.y), 0.2)
        let dz = max(CGFloat(maxB.z - minB.z), 0.2)
        node.position = SCNVector3(
            -CGFloat(minB.x + maxB.x) / 2,
            -CGFloat(minB.y),
            -CGFloat(minB.z + maxB.z) / 2
        )
        let radius = max(dx, dy, dz)
        let camera = SCNNode()
        camera.name = "about_camera"
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 40
        camera.position = SCNVector3(radius * 1.35, radius * 0.95, radius * 1.55)
        camera.look(at: SCNVector3(0, dy * 0.45, 0))
        scene.rootNode.addChildNode(camera)
    }

    private func addSpin(_ node: SCNNode) {
        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 10))
        node.runAction(spin)
    }

    private func hierarchyBounds(_ node: SCNNode) -> (SCNVector3, SCNVector3) {
        var minB = SCNVector3(10_000, 10_000, 10_000)
        var maxB = SCNVector3(-10_000, -10_000, -10_000)
        var found = false
        node.enumerateHierarchy { child, _ in
            guard child.geometry != nil else { return }
            let (cmin, cmax) = child.boundingBox
            let xs = [cmin.x, cmax.x]
            let ys = [cmin.y, cmax.y]
            let zs = [cmin.z, cmax.z]
            for x in xs {
                for y in ys {
                    for z in zs {
                        let world = child.convertPosition(SCNVector3(x, y, z), to: node)
                        minB.x = min(minB.x, world.x)
                        minB.y = min(minB.y, world.y)
                        minB.z = min(minB.z, world.z)
                        maxB.x = max(maxB.x, world.x)
                        maxB.y = max(maxB.y, world.y)
                        maxB.z = max(maxB.z, world.z)
                        found = true
                    }
                }
            }
        }
        return found ? (minB, maxB) : node.boundingBox
    }
}

struct SoldierPreviewView: NSViewRepresentable {
    var type: SoldierType
    var slot: Int = 0

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.backgroundColor = NSColor(white: 0.08, alpha: 0.95)
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if view.scene == nil {
            guard !context.coordinator.scheduled else { return }
            context.coordinator.scheduled = true
            let type = type
            AboutPreviewTiming.after(slot: slot) { [weak view] in
                guard let view, view.scene == nil else { return }
                apply(type: type, to: view)
                context.coordinator.shown = type
            }
            return
        }
        guard context.coordinator.shown != type else { return }
        apply(type: type, to: view)
        context.coordinator.shown = type
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shown: SoldierType?
        var scheduled = false
    }

    private func apply(type: SoldierType, to view: SCNView) {
        let scene = SCNScene()
        let node = GameAssetLoader.shared.cachedSoldierNode(type.rawValue)?.clone() ?? makeSoldierPreviewNode(type: type)
        scene.rootNode.addChildNode(node)
        let (minB, maxB) = node.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.3)
        let dy = max(CGFloat(maxB.y - minB.y), 0.3)
        let dz = max(CGFloat(maxB.z - minB.z), 0.3)
        node.position = SCNVector3(
            -CGFloat(minB.x + maxB.x) / 2,
            -CGFloat(minB.y),
            -CGFloat(minB.z + maxB.z) / 2
        )
        let radius = max(dx, dy, dz)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 38
        camera.position = SCNVector3(radius * 1.5, radius * 1.05, radius * 1.7)
        camera.look(at: SCNVector3(0, dy * 0.45, 0))
        scene.rootNode.addChildNode(camera)
        node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 11)))
        view.scene = scene
        view.pointOfView = camera
    }
}

enum AboutGoodKind: String, CaseIterable, Identifiable {
    case plank
    case iron
    case stone
    case appleBasket
    case cheese
    case meat
    case bread
    case eggBasket
    case chicken
    case corn
    case grapes
    case banana
    case vegetables
    case spices
    case wine
    case sausages
    case sword
    case shield
    case spear
    case bow
    case arrow
    case crossbow
    case mace
    case leather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plank: return "Daska"
        case .iron: return "Željezo"
        case .stone: return "Kamen"
        case .appleBasket: return "Jabuka"
        case .cheese: return "Sir"
        case .meat: return "Meso"
        case .bread: return "Kruh"
        case .eggBasket: return "Jaja"
        case .chicken: return "Pile"
        case .corn: return "Kukuruz"
        case .grapes: return "Grožđe"
        case .banana: return "Banana"
        case .vegetables: return "Povrće"
        case .spices: return "Začini"
        case .wine: return "Vino"
        case .sausages: return "Kobasice"
        case .sword: return "Mač"
        case .shield: return "Štit"
        case .spear: return "Koplje"
        case .bow: return "Luk"
        case .arrow: return "Strijela"
        case .crossbow: return "Samostrijel"
        case .mace: return "Buzdovan"
        case .leather: return "Kožna odjeća"
        }
    }
}

struct GoodPreviewView: NSViewRepresentable {
    var kind: AboutGoodKind
    var slot: Int = 0

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        view.backgroundColor = NSColor(white: 0.08, alpha: 0.95)
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if view.scene == nil {
            guard !context.coordinator.scheduled else { return }
            context.coordinator.scheduled = true
            let kind = kind
            AboutPreviewTiming.after(slot: slot) { [weak view] in
                guard let view, view.scene == nil else { return }
                view.scene = makeScene(kind)
                context.coordinator.shown = kind
            }
            return
        }
        guard context.coordinator.shown != kind else { return }
        view.scene = makeScene(kind)
        context.coordinator.shown = kind
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shown: AboutGoodKind?
        var scheduled = false
    }

    private func makeScene(_ kind: AboutGoodKind) -> SCNScene {
        let scene = SCNScene()
        let node = GameAssetLoader.shared.cachedGoodNode(kind.rawValue)?.clone() ?? Self.previewNode(kind)
        scene.rootNode.addChildNode(node)
        node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 10)))
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 32
        camera.position = SCNVector3(2.4, 1.5, 2.6)
        camera.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(camera)
        return scene
    }

    static func previewNode(_ kind: AboutGoodKind) -> SCNNode {
        switch kind {
        case .plank, .iron, .stone:
            return SCNNode(geometry: box(kind))
        case .appleBasket:
            return AppleBasketShapes.appleBasket()
        case .eggBasket:
            return AppleBasketShapes.eggBasket()
        case .sword, .shield, .spear, .bow, .arrow, .crossbow, .mace, .leather:
            return WeaponPreviewShapes.node(kind)
        default:
            return FoodPreviewShapes.node(kind)
        }
    }

    private static func box(_ kind: AboutGoodKind) -> SCNBox {
        let box: SCNBox
        let fallback: NSColor
        switch kind {
        case .plank:
            box = SCNBox(width: 2.6, height: 0.16, length: 0.55, chamferRadius: 0.02)
            fallback = NSColor(red: 0.72, green: 0.52, blue: 0.28, alpha: 1)
        case .iron:
            box = SCNBox(width: 1.15, height: 0.42, length: 0.55, chamferRadius: 0.03)
            fallback = NSColor(red: 0.45, green: 0.47, blue: 0.50, alpha: 1)
        case .stone:
            box = SCNBox(width: 1.7, height: 0.95, length: 1.25, chamferRadius: 0.04)
            fallback = NSColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
        default:
            box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
            fallback = .white
        }
        let mat = SCNMaterial()
        let maps = Self.maps(kind)
        mat.diffuse.contents = maps.color ?? fallback
        mat.lightingModel = .physicallyBased
        if let normal = maps.normal {
            mat.normal.contents = normal
            mat.normal.intensity = 0.8
        }
        if let roughness = maps.roughness {
            mat.roughness.contents = roughness
        }
        if let metalness = maps.metalness {
            mat.metalness.contents = metalness
        }
        if let occlusion = maps.occlusion {
            mat.ambientOcclusion.contents = occlusion
        }
        for prop in [mat.diffuse, mat.normal, mat.roughness, mat.metalness, mat.ambientOcclusion] {
            prop.wrapS = .repeat
            prop.wrapT = .repeat
        }
        box.materials = Array(repeating: mat, count: 6)
        return box
    }

    private struct GoodMaps {
        var color: NSImage?
        var normal: NSImage?
        var roughness: NSImage?
        var metalness: NSImage?
        var occlusion: NSImage?
    }

    /// Teksture dobara: Core/Objects/Textures/goods/plank, stone i metal.
    /// U bundleu su ravno u Resources, pa se traže po natpisu: Color, NormalGL, Roughness, Metalness.
    private static func maps(_ kind: AboutGoodKind) -> GoodMaps {
        let prefix: String
        let folder: String
        switch kind {
        case .plank:
            prefix = "Wood096_1K-JPG"
            folder = "plank"
        case .iron:
            prefix = "Metal053C_1K-JPG"
            folder = "metal"
        case .stone:
            prefix = "Rock030_1K-JPG"
            folder = "stone"
        default:
            prefix = ""
            folder = ""
        }
        func image(_ suffix: String) -> NSImage? {
            let name = "\(prefix)_\(suffix)"
            let folders: [String?] = [
                nil,
                "Core/Objects/Textures/goods/\(folder)",
                "Objects/Textures/goods/\(folder)",
                "Textures/goods/\(folder)"
            ]
            for folder in folders {
                for ext in ["jpg", "jpeg", "png"] {
                    if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: folder),
                       let image = NSImage(contentsOf: url) {
                        return image
                    }
                }
            }
            return nil
        }
        return GoodMaps(
            color: image("Color"),
            normal: image("NormalGL"),
            roughness: image("Roughness"),
            metalness: image("Metalness"),
            occlusion: image("AmbientOcclusion")
        )
    }
}

struct PadPreviewView: NSViewRepresentable {
    var pad: PadBrush
    var slot: Int = 0

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.backgroundColor = NSColor(white: 0.08, alpha: 0.95)
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if view.scene == nil {
            guard !context.coordinator.scheduled else { return }
            context.coordinator.scheduled = true
            let pad = pad
            AboutPreviewTiming.after(slot: slot) { [weak view] in
                guard let view, view.scene == nil else { return }
                view.scene = makePadScene(pad)
                context.coordinator.shown = pad
            }
            return
        }
        guard context.coordinator.shown != pad else { return }
        view.scene = makePadScene(pad)
        context.coordinator.shown = pad
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shown: PadBrush?
        var scheduled = false
    }

    private func makePadScene(_ pad: PadBrush) -> SCNScene {
        let scene = SCNScene()
        let tile = SCNNode()
        switch pad {
        case .trava:
            tile.addChildNode(grassTile())
        case .plodna:
            tile.addChildNode(flat(NSColor(red: 0.16, green: 0.68, blue: 0.22, alpha: 1)))
        case .kamen:
            tile.addChildNode(stoneTile())
        case .zeljezo:
            tile.addChildNode(ironTile())
        case .rijeka, .jezero:
            tile.addChildNode(waterTile(sea: false))
        case .more:
            tile.addChildNode(waterTile(sea: true))
        case .pijesak:
            tile.addChildNode(flat(NSColor(red: 0.86, green: 0.74, blue: 0.46, alpha: 1)))
        case .obicno:
            tile.addChildNode(soilTile())
        case .mocvara:
            tile.addChildNode(flat(NSColor(red: 0.28, green: 0.38, blue: 0.22, alpha: 1)))
        case .obrisi:
            tile.addChildNode(flat(NSColor(white: 0.35, alpha: 1)))
        }
        scene.rootNode.addChildNode(tile)
        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12))
        tile.runAction(spin)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        if pad == .trava {
            camera.position = SCNVector3(0.85, 0.38, 1.05)
            camera.look(at: SCNVector3(0, 0.16, 0))
        } else if pad == .kamen {
            camera.position = SCNVector3(0.7, 0.48, 0.95)
            camera.look(at: SCNVector3(0, 0.12, 0))
        } else if pad == .zeljezo {
            camera.position = SCNVector3(0.2, 0.62, 0.55)
            camera.look(at: SCNVector3(0, 0.08, 0))
        } else if pad.isWater {
            camera.position = SCNVector3(1.15, 0.72, 1.4)
            camera.look(at: SCNVector3(0, 0.14, 0))
        } else if pad == .obicno {
            camera.position = SCNVector3(1.05, 0.85, 1.25)
            camera.look(at: SCNVector3(0, 0.1, 0))
        } else {
            camera.position = SCNVector3(2.2, 1.8, 2.4)
            camera.look(at: SCNVector3(0, 0.1, 0))
        }
        scene.rootNode.addChildNode(camera)
        return scene
    }

    private func grassTile() -> SCNNode {
        GrassPatch.make()
    }

    private func stoneTile() -> SCNNode {
        RockPile.make()
    }

    private func ironTile() -> SCNNode {
        RockPile.makeIron()
    }

    private func waterTile(sea: Bool) -> SCNNode {
        let root = SCNNode()
        let bed = SCNBox(width: 2.2, height: 0.14, length: 2.2, chamferRadius: 0)
        let bedMat = SCNMaterial()
        bedMat.diffuse.contents = sea
            ? NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.28, alpha: 1)
            : NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.40, alpha: 1)
        bedMat.lightingModel = .lambert
        bed.materials = [bedMat]
        let bedNode = SCNNode(geometry: bed)
        bedNode.position.y = 0.07
        root.addChildNode(bedNode)

        let plane = SCNPlane(width: 2.2, height: 2.2)
        plane.widthSegmentCount = 42
        plane.heightSegmentCount = 42
        let water = SCNMaterial()
        water.program = sea ? RiverWaterShader.seaProgram : RiverWaterShader.program
        water.blendMode = .alpha
        water.isDoubleSided = true
        water.writesToDepthBuffer = false
        water.lightingModel = .constant
        plane.materials = [water]
        let surface = SCNNode(geometry: plane)
        surface.eulerAngles.x = -.pi / 2
        surface.position.y = 0.2
        root.addChildNode(surface)
        return root
    }

    private func soilTile() -> SCNNode {
        let box = SCNBox(width: 2.2, height: 0.16, length: 2.2, chamferRadius: 0)
        let top = SCNMaterial()
        top.diffuse.contents = soilPreviewImage()
        top.diffuse.wrapS = .clamp
        top.diffuse.wrapT = .clamp
        top.diffuse.magnificationFilter = .linear
        top.diffuse.minificationFilter = .linear
        top.lightingModel = .blinn
        let side = SCNMaterial()
        side.diffuse.contents = NSColor(calibratedRed: 0.40, green: 0.27, blue: 0.15, alpha: 1)
        side.lightingModel = .blinn
        box.materials = [side, side, side, side, top, side]
        let node = SCNNode(geometry: box)
        node.position.y = 0.08
        return node
    }

    private func soilPreviewImage() -> NSImage {
        return EarthTiles.previewImage()
    }

    private func flat(_ color: NSColor) -> SCNNode {
        let box = SCNBox(width: 2.2, height: 0.16, length: 2.2, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .blinn
        box.materials = [mat]
        let node = SCNNode(geometry: box)
        node.position.y = 0.08
        return node
    }
}
