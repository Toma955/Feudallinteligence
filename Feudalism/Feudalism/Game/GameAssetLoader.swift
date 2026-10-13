//
//  GameAssetLoader.swift
//  Feudalism
//
//  Paralelno učitavanje asseta pri pokretanju igre: teren, level .scn, modeli objekata.
//  Teški posao (decode, čitanje) na background taskovima; korištenje cachea na MainActor.
//

import Foundation
import SceneKit
import SwiftUI

/// Cache učitane assete – teren, level, template čvorovi po objectId.
struct LoadedGameAssets {
    var terrainTexture: Any?
    var level: LoadedLevel?
    /// Učitani 3D čvorovi za svaki placeable objectId (za template/ghost).
    var placementNodes: [String: SCNNode] = [:]
    /// About: resursi i hrana, ključ je AboutGoodKind.rawValue.
    var goodNodes: [String: SCNNode] = [:]
    /// About: vojnici, ključ je SoldierType.rawValue.
    var soldierNodes: [String: SCNNode] = [:]
}

/// Paralelni loader s progressom. Pokreni pri startu igre (npr. IntroView).
final class GameAssetLoader: ObservableObject {
    static let shared = GameAssetLoader()

    @Published private(set) var loadProgress: Double = 0
    @Published private(set) var loadStatus: String = ""
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var assets: LoadedGameAssets = LoadedGameAssets()

    private let lock = NSLock()
    private var loadTask: Task<Void, Never>?

    private init() {}

    /// Maksimalan broj istovremenih taskova (ne preopterećuj disk).
    private static var maxConcurrency: Int {
        min(6, max(2, ProcessInfo.processInfo.activeProcessorCount - 1))
    }

    /// Pokreni učitavanje ako još nije pokrenuto; inače samo čekaj. Pozovi pri startu (IntroView).
    func loadAllIfNeeded() async {
        if isLoaded { return }
        lock.lock()
        if let existing = loadTask {
            lock.unlock()
            _ = await existing.value
            return
        }
        let task = Task { await loadAll() }
        loadTask = task
        lock.unlock()
        await task.value
    }

    /// Učitaj teren, level i sve 3D prikaze. Izbornik čeka ovaj kraj, ne samo animaciju naslova.
    func loadAll() async {
        await MainActor.run {
            loadStatus = "Priprema…"
            loadProgress = 0
        }

        let objectIds = SceneKitPlacementRegistry.placeableObjectIds
        let goods = AboutGoodKind.allCases
        let soldiers = SoldierType.allCases
        let pads = PadBrush.allCases.filter { $0 != .obrisi }
        let total = 2 + objectIds.count + goods.count + soldiers.count + pads.count
        var completed = 0

        func tick(_ status: String) async {
            completed += 1
            let progress = Double(completed) / Double(max(1, total))
            await MainActor.run {
                self.loadProgress = progress
                self.loadStatus = status
            }
            await Task.yield()
        }

        async let terrainTexture: Any? = Task.detached {
            EarthTiles.prepare()
            return SceneKitMapView.createTerrainTextureForPreload()
        }.value
        async let level: LoadedLevel? = Task.detached {
            if !UserDefaults.standard.bool(forKey: "Feudalism.didDeleteStaleSoloLevelForTextureFix") {
                SceneKitLevelLoader.deleteSoloLevelFiles()
                UserDefaults.standard.set(true, forKey: "Feudalism.didDeleteStaleSoloLevelForTextureFix")
            }
            return SceneKitLevelLoader.loadForSoloMode(bundleLevelName: "Level", bundle: .main)
        }.value

        let terrain = await terrainTexture
            await tick("Teren i zemlja")
        let loadedLevel = await level
        await tick("Mapa")

        var placementNodes: [String: SCNNode] = [:]
        var goodNodes: [String: SCNNode] = [:]
        var soldierNodes: [String: SCNNode] = [:]

        for objectId in objectIds {
            let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
            let node = await MainActor.run { () -> SCNNode? in
                guard let node = SceneKitPlacementRegistry.loadSceneKitNode(objectId: objectId, bundle: .main) else { return nil }
                warmScene(node)
                return node
            }
            if let node { placementNodes[objectId] = node }
            await tick("Građevina: \(name)")
        }

        for good in goods {
            let node = await MainActor.run { () -> SCNNode in
                let node = GoodPreviewView.previewNode(good)
                warmScene(node)
                return node
            }
            goodNodes[good.rawValue] = node
            await tick(good.title)
        }

        for type in soldiers {
            let node = await MainActor.run { () -> SCNNode in
                let node = makeSoldierPreviewNode(type: type)
                warmScene(node)
                return node
            }
            soldierNodes[type.rawValue] = node
            await tick("Vojnik: \(type.displayName)")
        }

        for pad in pads {
            await MainActor.run {
                let node = SCNNode(geometry: SCNBox(width: 1.2, height: 0.08, length: 1.2, chamferRadius: 0))
                node.geometry?.firstMaterial?.diffuse.contents = NSColor(white: 0.4, alpha: 1)
                warmScene(node)
            }
            await tick("Podloga: \(pad.rawValue)")
        }

        await MainActor.run {
            warmer?.scene = nil
            warmer = nil
            assets = LoadedGameAssets(
                terrainTexture: terrain,
                level: loadedLevel,
                placementNodes: placementNodes,
                goodNodes: goodNodes,
                soldierNodes: soldierNodes
            )
            isLoaded = true
            loadProgress = 1
            loadStatus = "Gotovo"
        }
    }

    private var warmer: SCNView?

    /// Jedan kadar kroz SceneKit da se model i materijali slože dok traje učitavanje.
    private func warmScene(_ node: SCNNode) {
        let view: SCNView
        if let warmer {
            view = warmer
        } else {
            let made = SCNView(frame: NSRect(x: 0, y: 0, width: 96, height: 96))
            made.antialiasingMode = .multisampling4X
            made.autoenablesDefaultLighting = true
            made.rendersContinuously = false
            warmer = made
            view = made
        }
        let scene = SCNScene()
        let clone = node.clone()
        scene.rootNode.addChildNode(clone)
        view.scene = scene
        _ = view.snapshot()
        clone.removeFromParentNode()
    }

    /// Dohvati učitani level (nil ako nije učitan ili nema mape).
    func cachedLevel() -> LoadedLevel? {
        assets.level
    }

    /// Dohvati učitani placement čvor za objectId (nil ako nije učitan).
    func cachedPlacementNode(objectId: String) -> SCNNode? {
        assets.placementNodes[objectId]
    }

    func cachedGoodNode(_ id: String) -> SCNNode? {
        assets.goodNodes[id]
    }

    func cachedSoldierNode(_ id: String) -> SCNNode? {
        assets.soldierNodes[id]
    }

    /// Dohvati učitanu teksturu terena (nil ako nije učitana).
    func cachedTerrainTexture() -> Any? {
        assets.terrainTexture
    }
}
