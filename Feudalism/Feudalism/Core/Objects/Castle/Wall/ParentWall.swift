//
//  ParentWall.swift
//  Feudalism
//
//  Zajednička logika za sve tipove zidova (npr. HugeWall, SmallWall).
//  Nije placeable sam po sebi – koriste ga HugeWall i SmallWall.
//

import Foundation
import AppKit
import SceneKit

/// Zajednička implementacija zida: geometrija, teksture, materijali.
/// Razlika između tipova (HugeWall / SmallWall) bit će visina, resursi i život.
/// Dimenzija baze zida (1 ćelija) = MapScale.objectCubeWorldUnits (40×40 world jedinica).
enum ParentWall {
    /// Jedan izvor istine: 1 ćelija mape = 40×40 world; usklađeno s MapScale i SceneKitMapView.
    static var cubeSize: CGFloat { MapScale.objectCubeWorldUnits }
    static var defaultWallHeight: CGFloat { MapScale.meters(ObjectDimensions.hugeWall.heightCells) }
    private static let wallColor = NSColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)

    /// Jedno ponavljanje teksture na 2 m. Kamera je na 40 m (daleko, zoom 2), 10 m (srednje, zoom 8) i oko 6 m (blizu, zoom 14). Gušće ponavljanje se na dalekoj kameri slije u sivu boju.
    private static let metersPerTextureRepeat: CGFloat = 2
    private static var tileU: CGFloat { max(0.25, cubeSize / metersPerTextureRepeat) }
    private static func tileV(for height: CGFloat) -> CGFloat { max(0.25, height / metersPerTextureRepeat) }
    private static var topTileU: CGFloat { tileU }
    private static var topTileV: CGFloat { tileU }

    private struct WallTextureSet {
        let baseColor: NSImage?
        let normalGL: NSImage?
        let roughness: NSImage?
        let ambientOcclusion: NSImage?
        let displacement: NSImage?
    }
    private struct TopTextureSet {
        let baseColor: NSImage?
        let normalGL: NSImage?
        let roughness: NSImage?
        let ambientOcclusion: NSImage?
        let displacement: NSImage?
    }

    private static func applyTiling(_ prop: SCNMaterialProperty, u: CGFloat, v: CGFloat) {
        prop.wrapS = .repeat
        prop.wrapT = .repeat
        prop.contentsTransform = SCNMatrix4MakeScale(u, v, 1)
        prop.mipFilter = .linear
        prop.maxAnisotropy = 16
    }

    private static func finishWallMaterial(_ mat: SCNMaterial) {
        mat.lightingModel = .blinn
        mat.locksAmbientWithDiffuse = true
        mat.ambient.contents = NSColor.white
        mat.specular.contents = NSColor(white: 0.15, alpha: 1)
        mat.shininess = 0.08
        mat.isDoubleSided = true
    }

    private static func textureURL(bundle: Bundle, name: String, subdirs: [String?]) -> URL? {
        for sub in subdirs {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "jpg", subdirectory: sub) {
                return url
            }
        }
        return nil
    }

    private static var cachedWallTextures: WallTextureSet?
    private static var cachedTopTextures: TopTextureSet?

    private static func loadWallTextureSet(bundle: Bundle = .main) -> WallTextureSet {
        if let cachedWallTextures { return cachedWallTextures }
        let subdirs: [String?] = [
            "Core/Objects/Textures/wall",
            "Objects/Textures/wall",
            "Textures/wall",
            "Core/Objects/Textures/Wall",
            "Objects/Textures/Wall",
            "Textures/Wall",
            nil,
        ]
        let baseCandidates = ["wall_base_color", "wall_texture", "wall", "Wall_texture"]
        let normalCandidates = ["wall_normal_gl", "wall_normal", "wall_normal_dx"]
        let roughCandidates = ["wall_roughness"]
        let aoCandidates = ["wall_ambient_occlusion", "wall_ao"]
        let dispCandidates = ["wall_displacement", "wall_height"]

        let load = { (candidates: [String]) -> NSImage? in
            for name in candidates {
                if let url = textureURL(bundle: bundle, name: name, subdirs: subdirs),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
            return nil
        }

        let set = WallTextureSet(
            baseColor: load(baseCandidates),
            normalGL: load(normalCandidates),
            roughness: load(roughCandidates),
            ambientOcclusion: load(aoCandidates),
            displacement: load(dispCandidates)
        )
        if set.baseColor == nil {
            placementDebugLog("Wall texture missing: expected base color in Core/Objects/Textures/wall (wall_base_color.png)")
        } else {
            placementDebugLog("Wall texture set loaded once for the GPU")
        }
        cachedWallTextures = set
        return set
    }

    private static func loadTopTextureSet(bundle: Bundle = .main) -> TopTextureSet {
        if let cachedTopTextures { return cachedTopTextures }
        let subdirs: [String?] = [
            "Core/Objects/Textures/top_wall",
            "Objects/Textures/top_wall",
            "Textures/top_wall",
            "Core/Objects/Textures/Top_Wall",
            "Objects/Textures/Top_Wall",
            "Textures/Top_Wall",
            nil,
        ]
        let baseCandidates = ["top_wall_base_color", "top_wall_texture", "top_wall", "Bricks100_1K-JPG_Color"]
        let normalCandidates = ["top_wall_normal_gl", "top_wall_normal", "top_wall_normal_dx", "Bricks100_1K-JPG_NormalGL"]
        let roughCandidates = ["top_wall_roughness", "Bricks100_1K-JPG_Roughness"]
        let aoCandidates = ["top_wall_ambient_occlusion", "top_wall_ao", "Bricks100_1K-JPG_AmbientOcclusion"]
        let dispCandidates = ["top_wall_displacement", "top_wall_height", "Bricks100_1K-JPG_Displacement"]

        let load = { (candidates: [String]) -> NSImage? in
            for name in candidates {
                if let url = textureURL(bundle: bundle, name: name, subdirs: subdirs),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
            return nil
        }

        let set = TopTextureSet(
            baseColor: load(baseCandidates),
            normalGL: load(normalCandidates),
            roughness: load(roughCandidates),
            ambientOcclusion: load(aoCandidates),
            displacement: load(dispCandidates)
        )
        if set.baseColor == nil {
            placementDebugLog("Top wall texture missing: expected base color in Core/Objects/Textures/top_wall (top_wall_base_color.png/jpg)")
        } else {
            placementDebugLog("Top wall texture set loaded once for the GPU")
        }
        cachedTopTextures = set
        return set
    }

    private static func makeWallMaterial(bundle: Bundle = .main, wallHeight: CGFloat) -> SCNMaterial {
        let textures = loadWallTextureSet(bundle: bundle)
        let mat = SCNMaterial()
        mat.diffuse.contents = textures.baseColor ?? wallColor
        applyTiling(mat.diffuse, u: tileU, v: tileV(for: wallHeight))
        finishWallMaterial(mat)
        if let n = textures.normalGL {
            mat.normal.contents = n
            mat.normal.intensity = 0.35
            applyTiling(mat.normal, u: tileU, v: tileV(for: wallHeight))
        }
        return mat
    }

    private static func makeTopWallMaterial(bundle: Bundle = .main) -> SCNMaterial {
        let textures = loadTopTextureSet(bundle: bundle)
        let mat = SCNMaterial()
        mat.diffuse.contents = textures.baseColor ?? wallColor
        applyTiling(mat.diffuse, u: topTileU, v: topTileV)
        finishWallMaterial(mat)
        if let n = textures.normalGL {
            mat.normal.contents = n
            mat.normal.intensity = 0.35
            applyTiling(mat.normal, u: topTileU, v: topTileV)
        }
        return mat
    }

    private static func applyWallMaterialRecursive(_ node: SCNNode, sideMaterial: SCNMaterial, topMaterial: SCNMaterial) {
        if let geo = node.geometry {
            if let box = geo as? SCNBox {
                let side = sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                let top = topMaterial.copy() as? SCNMaterial ?? topMaterial
                box.materials = [side, side, side, side, top, side]
            } else if node.name == "steps_prism", geo.elements.count >= 2 {
                let top = topMaterial.copy() as? SCNMaterial ?? topMaterial
                let side = sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                geo.materials = [top, side]
            } else if geo.materials.isEmpty {
                geo.materials = [sideMaterial.copy() as? SCNMaterial ?? sideMaterial]
            } else {
                geo.materials = geo.materials.map { _ in
                    sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                }
            }
        }
        node.childNodes.forEach { applyWallMaterialRecursive($0, sideMaterial: sideMaterial, topMaterial: topMaterial) }
    }

    /// Učitava 3D čvor zida s danom visinom. Koriste ga HugeWall i SmallWall.
    static func loadSceneKitNode(from bundle: Bundle = .main, wallHeight: CGFloat = defaultWallHeight) -> SCNNode? {
        let container = SCNNode()
        container.name = "wall"
        let box = SCNBox(width: cubeSize, height: wallHeight, length: cubeSize, chamferRadius: 0)
        let side = makeWallMaterial(bundle: bundle, wallHeight: wallHeight)
        let top = makeTopWallMaterial(bundle: bundle)
        box.materials = [side, side, side, side, top, side]
        let cubeNode = SCNNode(geometry: box)
        cubeNode.position = SCNVector3(0, wallHeight / 2, 0)
        container.addChildNode(cubeNode)

        let (mn, mx) = container.boundingBox
        let sourceHeight = CGFloat(mx.y - mn.y)
        placementDebugLog("ParentWall.loadSceneKitNode cubeSize=\(String(format: "%.3f", cubeSize)) wallHeight=\(String(format: "%.3f", wallHeight)) sourceHeight=\(String(format: "%.3f", sourceHeight))")
        return container
    }

    /// Ponovno primjenjuje teksture na čvor (glavni zid ili steps_prism). Koriste HugeWall i Steps.
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main, wallHeight: CGFloat = defaultWallHeight) -> Bool {
        let side = makeWallMaterial(bundle: bundle, wallHeight: wallHeight)
        let top = makeTopWallMaterial(bundle: bundle)
        applyWallMaterialRecursive(node, sideMaterial: side, topMaterial: top)
        return true
    }

    /// Visina zida za korištenje u mapi (npr. za scaling dijagonalnih elemenata). Čita iz child tipova (WallParent).
    static func wallHeight(for objectId: String) -> CGFloat {
        WallParent.wallHeightInUnits(for: objectId)
    }
}
