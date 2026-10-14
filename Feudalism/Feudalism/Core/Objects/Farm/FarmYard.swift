//
//  FarmYard.swift
//  Feudalism
//
//  Polazni tlocrt svih farmi: 5×5.
//  Četiri polja 2×2 s mini L-ogradom na vanjskom kutu, između njih križ širine 1.
//  Na polju 4 (donje desno) stoji mala gospodarska zgrada.
//  Podloga je crna zemlja. Pšenica, kukuruz, povrće, vinograd i jabuke dodaju usjev na polja 1–3.
//
//    1 1 | 2 2
//    1 1 | 2 2
//    - - + - -
//    3 3 | 4 4
//    3 3 | 4 4
//

import Foundation
import SceneKit
import AppKit

enum FarmYard {
    static let side = 5
    static let plot = 2
    static let passageIndex = 2

    enum Crop {
        case soil
        case wheat
        case corn
        case vegetables
        case grapes
        case flowers
        case apple
    }

    static let earthColor = NSColor(red: 0.10, green: 0.07, blue: 0.05, alpha: 1)
    static let pathColor = NSColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1)
    static let yardColor = NSColor(red: 0.22, green: 0.16, blue: 0.10, alpha: 1)
    static let buildingWall = NSColor(red: 0.55, green: 0.38, blue: 0.24, alpha: 1)
    static let buildingRoof = NSColor(red: 0.42, green: 0.22, blue: 0.16, alpha: 1)
    static let fenceColor = NSColor(red: 0.38, green: 0.26, blue: 0.16, alpha: 1)
    static let wheatStem = NSColor(red: 0.42, green: 0.48, blue: 0.16, alpha: 1)
    static let wheatHead = NSColor(red: 0.86, green: 0.70, blue: 0.22, alpha: 1)
    static let wheatHeadRipe = NSColor(red: 0.78, green: 0.58, blue: 0.16, alpha: 1)
    static let cornStem = NSColor(red: 0.28, green: 0.52, blue: 0.14, alpha: 1)
    static let cornLeaf = NSColor(red: 0.34, green: 0.58, blue: 0.16, alpha: 1)
    static let cornEar = NSColor(red: 0.90, green: 0.72, blue: 0.18, alpha: 1)
    static let cornSilk = NSColor(red: 0.72, green: 0.62, blue: 0.28, alpha: 1)
    static let vegLeaf = NSColor(red: 0.22, green: 0.55, blue: 0.18, alpha: 1)
    static let vegLeafDark = NSColor(red: 0.14, green: 0.40, blue: 0.12, alpha: 1)
    static let vegCabbage = NSColor(red: 0.45, green: 0.62, blue: 0.28, alpha: 1)
    static let vegCarrot = NSColor(red: 0.88, green: 0.42, blue: 0.12, alpha: 1)
    static let vegTomato = NSColor(red: 0.78, green: 0.16, blue: 0.12, alpha: 1)
    static let vinePost = NSColor(red: 0.40, green: 0.26, blue: 0.14, alpha: 1)
    static let vineLeaf = NSColor(red: 0.24, green: 0.48, blue: 0.18, alpha: 1)
    static let vineLeafDark = NSColor(red: 0.16, green: 0.36, blue: 0.14, alpha: 1)
    static let grapePurple = NSColor(red: 0.42, green: 0.12, blue: 0.42, alpha: 1)
    static let grapeDeep = NSColor(red: 0.28, green: 0.06, blue: 0.30, alpha: 1)
    static let flowerPink = NSColor(red: 0.82, green: 0.28, blue: 0.48, alpha: 1)
    static let flowerYellow = NSColor(red: 0.92, green: 0.72, blue: 0.18, alpha: 1)
    static let flowerPurple = NSColor(red: 0.52, green: 0.28, blue: 0.72, alpha: 1)
    static let flowerWhite = NSColor(red: 0.92, green: 0.90, blue: 0.86, alpha: 1)
    static let hiveWood = NSColor(red: 0.72, green: 0.52, blue: 0.22, alpha: 1)
    static let hiveWoodDark = NSColor(red: 0.48, green: 0.32, blue: 0.14, alpha: 1)
    static let appleBark = NSColor(red: 0.32, green: 0.20, blue: 0.12, alpha: 1)
    static let appleLeaf = NSColor(red: 0.22, green: 0.46, blue: 0.16, alpha: 1)
    static let appleLeafDark = NSColor(red: 0.14, green: 0.34, blue: 0.12, alpha: 1)
    static let appleFruit = NSColor(red: 0.78, green: 0.14, blue: 0.12, alpha: 1)
    static let appleFruitDeep = NSColor(red: 0.62, green: 0.08, blue: 0.08, alpha: 1)

    /// Križ (srednji red i srednji stupac) ostaje prolaz.
    static func isPassage(localRow: Int, localCol: Int) -> Bool {
        guard localRow >= 0, localCol >= 0, localRow < side, localCol < side else { return false }
        return localRow == passageIndex || localCol == passageIndex
    }

    static func makeNode(name: String, field: NSColor = earthColor, crop: Crop = .soil) -> SCNNode {
        _ = field
        let container = SCNNode()
        container.name = name
        let step = PlaceholderBox.worldUnitsPerCell
        let earthH = step * 0.14
        let fieldH = step * 0.18
        let pathH = step * 0.12
        let plotW = CGFloat(plot) * step
        let plots: [(col: CGFloat, row: CGFloat)] = [(0.5, 0.5), (3.5, 0.5), (0.5, 3.5)]

        func plotCenter(localCol: CGFloat, localRow: CGFloat) -> SCNVector3 {
            SCNVector3((localCol - 2) * step, 0, (localRow - 2) * step)
        }

        func fieldPad(at localCol: CGFloat, localRow: CGFloat, color: NSColor) -> SCNNode {
            let box = SCNBox(width: plotW, height: fieldH, length: plotW, chamferRadius: 0)
            box.materials = [material(color)]
            let node = SCNNode(geometry: box)
            let p = plotCenter(localCol: localCol, localRow: localRow)
            node.position = SCNVector3(p.x, fieldH / 2, p.z)
            return node
        }

        let earth = SCNBox(width: CGFloat(side) * step, height: earthH, length: CGFloat(side) * step, chamferRadius: 0)
        earth.materials = [material(earthColor)]
        let earthNode = SCNNode(geometry: earth)
        earthNode.name = "farm_earth"
        earthNode.position.y = earthH / 2
        container.addChildNode(earthNode)

        for plot in plots {
            container.addChildNode(fieldPad(at: plot.col, localRow: plot.row, color: earthColor))
        }
        container.addChildNode(fieldPad(at: 3.5, localRow: 3.5, color: yardColor))

        // L-ograda na vanjskom kutu svakog polja; strane prema križu ostaju otvorene.
        container.addChildNode(makeLFence(center: plotCenter(localCol: 0.5, localRow: 0.5), outerX: -1, outerZ: -1, plotW: plotW, step: step))
        container.addChildNode(makeLFence(center: plotCenter(localCol: 3.5, localRow: 0.5), outerX: 1, outerZ: -1, plotW: plotW, step: step))
        container.addChildNode(makeLFence(center: plotCenter(localCol: 0.5, localRow: 3.5), outerX: -1, outerZ: 1, plotW: plotW, step: step))
        container.addChildNode(makeLFence(center: plotCenter(localCol: 3.5, localRow: 3.5), outerX: 1, outerZ: 1, plotW: plotW, step: step))

        let hPath = SCNBox(width: CGFloat(side) * step, height: pathH, length: step, chamferRadius: 0)
        hPath.materials = [material(pathColor)]
        let hNode = SCNNode(geometry: hPath)
        hNode.position.y = pathH / 2
        container.addChildNode(hNode)

        let vPath = SCNBox(width: step, height: pathH, length: CGFloat(side) * step, chamferRadius: 0)
        vPath.materials = [material(pathColor)]
        let vNode = SCNNode(geometry: vPath)
        vNode.position.y = pathH / 2
        container.addChildNode(vNode)

        let shed = makeShed(step: step)
        let yard = plotCenter(localCol: 3.5, localRow: 3.5)
        shed.position = SCNVector3(yard.x, 0, yard.z)
        container.addChildNode(shed)

        let cropRoot = SCNNode()
        cropRoot.name = "farm_crop"
        for (index, plot) in plots.enumerated() {
            let origin = plotCenter(localCol: plot.col, localRow: plot.row)
            switch crop {
            case .soil:
                break
            case .wheat:
                addWheat(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            case .corn:
                addCorn(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            case .vegetables:
                addVegetables(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            case .grapes:
                addVineyard(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            case .flowers:
                addFlowerBeds(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            case .apple:
                addAppleTrees(to: cropRoot, origin: origin, plotW: plotW, step: step, plotIndex: index)
            }
        }
        if crop == .flowers {
            addBeeHives(to: cropRoot, shedYard: plotCenter(localCol: 3.5, localRow: 3.5), step: step)
        }
        container.addChildNode(cropRoot)
        return container
    }

    private static func addWheat(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let stemMat = material(wheatStem)
        let headMat = material(wheatHead)
        let ripeMat = material(wheatHeadRipe)
        let cols = 13
        let rows = 13
        let inset = plotW * 0.10
        let span = plotW - inset * 2
        for r in 0..<rows {
            for c in 0..<cols {
                let u = CGFloat(c) / CGFloat(cols - 1)
                let v = CGFloat(r) / CGFloat(rows - 1)
                let jitterX = (unit(plotIndex, c, r) - 0.5) * step * 0.05
                let jitterZ = (unit(plotIndex, r, c + 3) - 0.5) * step * 0.05
                let x = origin.x - span / 2 + u * span + jitterX
                let z = origin.z - span / 2 + v * span + jitterZ
                let h = step * (0.20 + unit(plotIndex, c + 7, r + 2) * 0.16)
                let stem = SCNCylinder(radius: step * 0.012, height: h)
                stem.radialSegmentCount = 4
                stem.heightSegmentCount = 1
                stem.materials = [stemMat]
                let stemNode = SCNNode(geometry: stem)
                stemNode.position = SCNVector3(x, h / 2, z)
                stemNode.eulerAngles.x = (unit(plotIndex, c, r + 11) - 0.5) * 0.18
                stemNode.eulerAngles.z = (unit(plotIndex, c + 5, r) - 0.5) * 0.18
                root.addChildNode(stemNode)

                let head = SCNCone(topRadius: step * 0.008, bottomRadius: step * 0.028, height: step * 0.07)
                head.radialSegmentCount = 4
                head.materials = [unit(plotIndex, c + 1, r + 4) > 0.45 ? headMat : ripeMat]
                let headNode = SCNNode(geometry: head)
                headNode.position = SCNVector3(x, h + step * 0.03, z)
                headNode.eulerAngles = stemNode.eulerAngles
                root.addChildNode(headNode)
            }
        }
    }

    /// Visoki kukuruz: stabljike, listovi i klipovi.
    private static func addCorn(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let stemMat = material(cornStem)
        let leafMat = material(cornLeaf)
        let earMat = material(cornEar)
        let silkMat = material(cornSilk)
        let cols = 7
        let rows = 7
        let inset = plotW * 0.12
        let span = plotW - inset * 2
        for r in 0..<rows {
            for c in 0..<cols {
                let u = CGFloat(c) / CGFloat(max(1, cols - 1))
                let v = CGFloat(r) / CGFloat(max(1, rows - 1))
                let jitterX = (unit(plotIndex, c, r) - 0.5) * step * 0.06
                let jitterZ = (unit(plotIndex, r, c + 2) - 0.5) * step * 0.06
                let x = origin.x - span / 2 + u * span + jitterX
                let z = origin.z - span / 2 + v * span + jitterZ
                let h = step * (0.55 + unit(plotIndex, c + 3, r + 5) * 0.35)
                let stem = SCNCylinder(radius: step * 0.028, height: h)
                stem.radialSegmentCount = 5
                stem.materials = [stemMat]
                let stemNode = SCNNode(geometry: stem)
                stemNode.position = SCNVector3(x, h / 2, z)
                stemNode.eulerAngles.z = (unit(plotIndex, c, r + 8) - 0.5) * 0.12
                root.addChildNode(stemNode)

                for side in [-1.0, 1.0] as [CGFloat] {
                    let leaf = SCNBox(width: step * 0.22, height: step * 0.04, length: step * 0.08, chamferRadius: 0)
                    leaf.materials = [leafMat]
                    let leafNode = SCNNode(geometry: leaf)
                    leafNode.position = SCNVector3(x + side * step * 0.08, h * 0.55, z)
                    leafNode.eulerAngles.z = side * 0.55
                    leafNode.eulerAngles.y = (unit(plotIndex, c + 1, r) - 0.5) * 0.4
                    root.addChildNode(leafNode)
                }

                let ear = SCNCapsule(capRadius: step * 0.035, height: step * 0.16)
                ear.materials = [earMat]
                let earNode = SCNNode(geometry: ear)
                earNode.position = SCNVector3(x + step * 0.05, h * 0.72, z)
                earNode.eulerAngles.z = 0.35
                root.addChildNode(earNode)

                let silk = SCNCone(topRadius: 0, bottomRadius: step * 0.02, height: step * 0.08)
                silk.materials = [silkMat]
                let silkNode = SCNNode(geometry: silk)
                silkNode.position = SCNVector3(x + step * 0.05, h * 0.72 + step * 0.10, z)
                root.addChildNode(silkNode)
            }
        }
    }

    /// Gredice: kupus, mrkva, rajčica / lisnato povrće.
    private static func addVegetables(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let leafMat = material(vegLeaf)
        let leafDark = material(vegLeafDark)
        let cabbageMat = material(vegCabbage)
        let carrotMat = material(vegCarrot)
        let tomatoMat = material(vegTomato)
        let rows = 4
        let cols = 5
        let inset = plotW * 0.14
        let span = plotW - inset * 2
        for r in 0..<rows {
            for c in 0..<cols {
                let u = CGFloat(c) / CGFloat(max(1, cols - 1))
                let v = CGFloat(r) / CGFloat(max(1, rows - 1))
                let x = origin.x - span / 2 + u * span
                let z = origin.z - span / 2 + v * span
                let kind = Int(unit(plotIndex, c + r * 3, r + 2) * 3)
                switch kind {
                case 0:
                    let head = SCNSphere(radius: step * (0.10 + unit(plotIndex, c, r) * 0.04))
                    head.segmentCount = 8
                    head.materials = [cabbageMat]
                    let node = SCNNode(geometry: head)
                    node.position = SCNVector3(x, step * 0.12, z)
                    node.scale = SCNVector3(1.15, 0.85, 1.15)
                    root.addChildNode(node)
                    let fringe = SCNSphere(radius: step * 0.14)
                    fringe.segmentCount = 6
                    fringe.materials = [leafDark]
                    let fringeNode = SCNNode(geometry: fringe)
                    fringeNode.position = SCNVector3(x, step * 0.08, z)
                    fringeNode.scale = SCNVector3(1.3, 0.35, 1.3)
                    root.addChildNode(fringeNode)
                case 1:
                    let top = SCNCone(topRadius: 0, bottomRadius: step * 0.06, height: step * 0.10)
                    top.materials = [leafMat]
                    let topNode = SCNNode(geometry: top)
                    topNode.position = SCNVector3(x, step * 0.16, z)
                    root.addChildNode(topNode)
                    let rootVeg = SCNCone(topRadius: step * 0.012, bottomRadius: step * 0.04, height: step * 0.14)
                    rootVeg.materials = [carrotMat]
                    let rootNode = SCNNode(geometry: rootVeg)
                    rootNode.position = SCNVector3(x, step * 0.08, z)
                    rootNode.eulerAngles.x = .pi
                    root.addChildNode(rootNode)
                default:
                    let stake = SCNCylinder(radius: step * 0.012, height: step * 0.32)
                    stake.materials = [material(fenceColor)]
                    let stakeNode = SCNNode(geometry: stake)
                    stakeNode.position = SCNVector3(x, step * 0.18, z)
                    root.addChildNode(stakeNode)
                    for t in 0..<3 {
                        let tomato = SCNSphere(radius: step * 0.04)
                        tomato.segmentCount = 6
                        tomato.materials = [tomatoMat]
                        let tNode = SCNNode(geometry: tomato)
                        let ang = CGFloat(t) * 2.1
                        tNode.position = SCNVector3(
                            x + cos(ang) * step * 0.05,
                            step * (0.14 + CGFloat(t) * 0.07),
                            z + sin(ang) * step * 0.05
                        )
                        root.addChildNode(tNode)
                    }
                    let bush = SCNSphere(radius: step * 0.08)
                    bush.segmentCount = 6
                    bush.materials = [leafMat]
                    let bushNode = SCNNode(geometry: bush)
                    bushNode.position = SCNVector3(x, step * 0.20, z)
                    bushNode.scale = SCNVector3(1.2, 0.7, 1.2)
                    root.addChildNode(bushNode)
                }
            }
        }
    }

    /// Vinograd: redovi stupova s lozom i grozdovima.
    private static func addVineyard(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let postMat = material(vinePost)
        let leafMat = material(vineLeaf)
        let leafDark = material(vineLeafDark)
        let grapeMat = material(grapePurple)
        let grapeDeepMat = material(grapeDeep)
        let rowCount = 3
        let postsPerRow = 4
        let inset = plotW * 0.16
        let span = plotW - inset * 2
        for row in 0..<rowCount {
            let v = CGFloat(row) / CGFloat(max(1, rowCount - 1))
            let z = origin.z - span / 2 + v * span
            var postTops: [SCNVector3] = []
            for col in 0..<postsPerRow {
                let u = CGFloat(col) / CGFloat(max(1, postsPerRow - 1))
                let x = origin.x - span / 2 + u * span
                let postH = step * (0.55 + unit(plotIndex, row, col) * 0.08)
                let post = SCNCylinder(radius: step * 0.035, height: postH)
                post.radialSegmentCount = 5
                post.materials = [postMat]
                let postNode = SCNNode(geometry: post)
                postNode.position = SCNVector3(x, postH / 2, z)
                root.addChildNode(postNode)
                postTops.append(SCNVector3(x, postH * 0.85, z))

                // Loza oko stupa.
                for band in 0..<3 {
                    let vine = SCNTorus(ringRadius: step * 0.06, pipeRadius: step * 0.015)
                    vine.ringSegmentCount = 8
                    vine.pipeSegmentCount = 4
                    vine.materials = [band % 2 == 0 ? leafMat : leafDark]
                    let vineNode = SCNNode(geometry: vine)
                    vineNode.eulerAngles.x = .pi / 2
                    vineNode.position = SCNVector3(x, postH * (0.35 + CGFloat(band) * 0.18), z)
                    vineNode.scale = SCNVector3(1, 0.6, 1)
                    root.addChildNode(vineNode)
                }

                // Grozdovi.
                for g in 0..<2 {
                    let cluster = SCNNode()
                    let gx = x + (g == 0 ? -1 : 1) * step * 0.07
                    let gy = postH * (0.45 + unit(plotIndex, row + g, col) * 0.2)
                    for berry in 0..<6 {
                        let br = SCNSphere(radius: step * 0.028)
                        br.segmentCount = 5
                        br.materials = [berry % 2 == 0 ? grapeMat : grapeDeepMat]
                        let bNode = SCNNode(geometry: br)
                        let a = CGFloat(berry) * 0.9
                        bNode.position = SCNVector3(
                            cos(a) * step * 0.025,
                            -CGFloat(berry) * step * 0.018,
                            sin(a) * step * 0.025
                        )
                        cluster.addChildNode(bNode)
                    }
                    cluster.position = SCNVector3(gx, gy, z + step * 0.02)
                    root.addChildNode(cluster)
                }
            }
            // Žica / loza između stupova.
            if postTops.count >= 2 {
                for i in 0..<(postTops.count - 1) {
                    let a = postTops[i]
                    let b = postTops[i + 1]
                    let dx = b.x - a.x
                    let dz = b.z - a.z
                    let len = hypot(dx, dz)
                    let wire = SCNBox(width: len, height: step * 0.02, length: step * 0.02, chamferRadius: 0)
                    wire.materials = [leafDark]
                    let wireNode = SCNNode(geometry: wire)
                    wireNode.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
                    wireNode.eulerAngles.y = atan2(dx, dz) - .pi / 2
                    root.addChildNode(wireNode)

                    let foliage = SCNBox(width: len * 0.9, height: step * 0.10, length: step * 0.12, chamferRadius: 0)
                    foliage.materials = [leafMat]
                    let foliageNode = SCNNode(geometry: foliage)
                    foliageNode.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2 - step * 0.04, (a.z + b.z) / 2)
                    foliageNode.eulerAngles.y = wireNode.eulerAngles.y
                    root.addChildNode(foliageNode)
                }
            }
        }
    }

    /// Gredice cvijeća.
    private static func addFlowerBeds(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let colors = [flowerPink, flowerYellow, flowerPurple, flowerWhite].map(material)
        let stemMat = material(vegLeaf)
        let cols = 6
        let rows = 6
        let inset = plotW * 0.12
        let span = plotW - inset * 2
        for r in 0..<rows {
            for c in 0..<cols {
                let u = CGFloat(c) / CGFloat(max(1, cols - 1))
                let v = CGFloat(r) / CGFloat(max(1, rows - 1))
                let x = origin.x - span / 2 + u * span + (unit(plotIndex, c, r) - 0.5) * step * 0.04
                let z = origin.z - span / 2 + v * span + (unit(plotIndex, r, c) - 0.5) * step * 0.04
                let stemH = step * (0.10 + unit(plotIndex, c + 2, r) * 0.08)
                let stem = SCNCylinder(radius: step * 0.012, height: stemH)
                stem.materials = [stemMat]
                let stemNode = SCNNode(geometry: stem)
                stemNode.position = SCNVector3(x, stemH / 2, z)
                root.addChildNode(stemNode)

                let bloom = SCNSphere(radius: step * (0.04 + unit(plotIndex, c, r + 3) * 0.025))
                bloom.segmentCount = 6
                bloom.materials = [colors[(c + r + plotIndex) % colors.count]]
                let bloomNode = SCNNode(geometry: bloom)
                bloomNode.position = SCNVector3(x, stemH + step * 0.03, z)
                bloomNode.scale = SCNVector3(1.2, 0.7, 1.2)
                root.addChildNode(bloomNode)
            }
        }
    }

    /// Košnice uz gospodarsku zgradu (farma cvijeća).
    private static func addBeeHives(to root: SCNNode, shedYard: SCNVector3, step: CGFloat) {
        let wood = material(hiveWood)
        let woodDark = material(hiveWoodDark)
        let spots: [(CGFloat, CGFloat)] = [(-0.55, -0.35), (-0.15, -0.55), (0.35, -0.40)]
        for (i, spot) in spots.enumerated() {
            let hive = SCNNode()
            let w = step * 0.28
            let d = step * 0.22
            for level in 0..<3 {
                let box = SCNBox(width: w * (1 - CGFloat(level) * 0.08), height: step * 0.12, length: d * (1 - CGFloat(level) * 0.08), chamferRadius: 0)
                box.materials = [level % 2 == 0 ? wood : woodDark]
                let node = SCNNode(geometry: box)
                node.position.y = step * 0.08 + CGFloat(level) * step * 0.12
                hive.addChildNode(node)
            }
            let lid = SCNBox(width: w * 1.1, height: step * 0.04, length: d * 1.15, chamferRadius: 0)
            lid.materials = [woodDark]
            let lidNode = SCNNode(geometry: lid)
            lidNode.position.y = step * 0.42
            hive.addChildNode(lidNode)
            hive.position = SCNVector3(
                shedYard.x + spot.0 * step,
                0,
                shedYard.z + spot.1 * step
            )
            hive.eulerAngles.y = CGFloat(i) * 0.15
            root.addChildNode(hive)
        }
    }

    private static func addAppleTrees(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let bark = material(appleBark)
        let leaf = material(appleLeaf)
        let leafDark = material(appleLeafDark)
        let spots: [(dx: CGFloat, dz: CGFloat)] = [(-0.42, -0.40), (0.40, -0.38), (-0.38, 0.42), (0.38, 0.36)]
        for (treeIndex, spot) in spots.enumerated() {
            let scale = 0.88 + unit(plotIndex, treeIndex, 3) * 0.22
            let x = origin.x + spot.dx * plotW * 0.5
            let z = origin.z + spot.dz * plotW * 0.5
            let trunkH = step * 0.72 * scale
            let trunk = SCNCylinder(radius: step * 0.045 * scale, height: trunkH)
            trunk.radialSegmentCount = 6
            trunk.materials = [bark]
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(x, trunkH / 2, z)
            trunkNode.eulerAngles.z = (unit(plotIndex, treeIndex, 8) - 0.5) * 0.12
            root.addChildNode(trunkNode)

            let canopyY = trunkH + step * 0.28 * scale
            let clumps: [(dx: CGFloat, dy: CGFloat, dz: CGFloat, r: CGFloat, dark: Bool)] = [
                (0, 0, 0, 0.28, false),
                (0.16, -0.04, 0.08, 0.20, true),
                (-0.14, -0.02, -0.10, 0.19, true),
                (0.04, 0.12, -0.08, 0.16, false),
            ]
            for clump in clumps {
                let sphere = SCNSphere(radius: clump.r * step * scale * 1.7)
                sphere.segmentCount = 8
                sphere.materials = [clump.dark ? leafDark : leaf]
                let node = SCNNode(geometry: sphere)
                node.position = SCNVector3(
                    x + clump.dx * step * scale,
                    canopyY + clump.dy * step * scale,
                    z + clump.dz * step * scale
                )
                root.addChildNode(node)
            }

            for apple in 0..<5 {
                let a = unit(plotIndex, treeIndex, apple + 20)
                let b = unit(plotIndex, apple + 4, treeIndex + 6)
                let c = unit(plotIndex, treeIndex + 9, apple + 11)
                let fruitH = step * (0.16 + a * 0.06) * scale
                let fruitNode = AppleBasketShapes.apple(height: fruitH)
                fruitNode.eulerAngles.y = (b - 0.5) * 3
                fruitNode.position = SCNVector3(
                    x + (a - 0.5) * step * 0.42 * scale,
                    canopyY + (b - 0.45) * step * 0.22 * scale,
                    z + (c - 0.5) * step * 0.42 * scale
                )
                root.addChildNode(fruitNode)
            }

            if treeIndex == 0 {
                let fallen = AppleBasketShapes.apple(height: step * 0.14)
                fallen.eulerAngles.z = 0.4
                fallen.position = SCNVector3(x + step * 0.18, step * 0.1, z + step * 0.14)
                root.addChildNode(fallen)
            }
        }
        addBaskets(to: root, origin: origin, plotW: plotW, step: step, plotIndex: plotIndex)
    }

    /// Nekoliko košara jabuka na tlu. Jedna košara = jedna mjera hrane.
    private static func addBaskets(to root: SCNNode, origin: SCNVector3, plotW: CGFloat, step: CGFloat, plotIndex: Int) {
        let spots: [(CGFloat, CGFloat)] = [(-0.55, 0.15), (0.5, -0.35), (0.1, 0.55)]
        for (index, spot) in spots.enumerated() {
            let basket = AppleBasketShapes.appleBasket(height: step * 0.55)
            basket.eulerAngles.y = unit(plotIndex, index, 2) * .pi
            basket.position = SCNVector3(
                origin.x + spot.0 * plotW * 0.45,
                step * 0.16,
                origin.z + spot.1 * plotW * 0.45
            )
            root.addChildNode(basket)
        }
    }

    private static func unit(_ a: Int, _ b: Int, _ c: Int) -> CGFloat {
        var x = UInt32(bitPattern: Int32(truncatingIfNeeded: a &* 73856093 &+ b &* 19349663 &+ c &* 83492791))
        x &+= x << 10
        x ^= x >> 6
        x &+= x << 3
        return CGFloat(x % 10_000) / 10_000
    }

    private static func makeLFence(center: SCNVector3, outerX: CGFloat, outerZ: CGFloat, plotW: CGFloat, step: CGFloat) -> SCNNode {
        let fence = SCNNode()
        fence.name = "farm_l_fence"
        let wood = material(fenceColor)
        let thick = step * 0.07
        let postH = step * 0.48
        let railH = step * 0.05
        let half = plotW / 2
        let xEdge = center.x + outerX * half
        let zEdge = center.z + outerZ * half

        func post(x: CGFloat, z: CGFloat) {
            let box = SCNBox(width: thick * 1.2, height: postH, length: thick * 1.2, chamferRadius: 0)
            box.materials = [wood]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(x, postH / 2, z)
            fence.addChildNode(node)
        }

        func rail(x: CGFloat, z: CGFloat, alongX: Bool, y: CGFloat) {
            let box = SCNBox(
                width: alongX ? plotW : thick,
                height: railH,
                length: alongX ? thick : plotW,
                chamferRadius: 0
            )
            box.materials = [wood]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(x, y, z)
            fence.addChildNode(node)
        }

        post(x: xEdge, z: zEdge)
        post(x: center.x, z: zEdge)
        post(x: xEdge, z: center.z)
        rail(x: center.x, z: zEdge, alongX: true, y: postH * 0.38)
        rail(x: center.x, z: zEdge, alongX: true, y: postH * 0.72)
        rail(x: xEdge, z: center.z, alongX: false, y: postH * 0.38)
        rail(x: xEdge, z: center.z, alongX: false, y: postH * 0.72)
        return fence
    }

    private static func makeShed(step: CGFloat) -> SCNNode {
        let shed = SCNNode()
        shed.name = "farm_shed"
        let wallW = step * 1.15
        let wallH = step * 1.15
        let wallD = step * 1.05
        let walls = SCNBox(width: wallW, height: wallH, length: wallD, chamferRadius: 0)
        walls.materials = [material(buildingWall)]
        let wallNode = SCNNode(geometry: walls)
        wallNode.position.y = wallH / 2
        shed.addChildNode(wallNode)

        let roof = SCNBox(width: wallW * 1.18, height: step * 0.22, length: wallD * 1.18, chamferRadius: 0)
        roof.materials = [material(buildingRoof)]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position.y = wallH + step * 0.12
        shed.addChildNode(roofNode)

        let door = SCNBox(width: step * 0.32, height: step * 0.62, length: step * 0.04, chamferRadius: 0)
        door.materials = [material(NSColor(red: 0.28, green: 0.16, blue: 0.10, alpha: 1))]
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, step * 0.34, wallD / 2 + step * 0.01)
        shed.addChildNode(doorNode)
        return shed
    }

    private static func material(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.ambient.contents = color.blended(withFraction: 0.35, of: .black) ?? color
        mat.lightingModel = .blinn
        return mat
    }
}
