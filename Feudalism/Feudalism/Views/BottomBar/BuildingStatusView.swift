//
//  BuildingStatusView.swift
//  Feudalism
//
//  Stanje kliknute građevine u donjem baru: zdravlje, vatra, radnik i ciklus proizvodnje.
//

import SwiftUI

struct BuildingStatusView: View {
    @EnvironmentObject private var gameState: GameState
    let placementId: String
    let title: String

    var body: some View {
        if let (layer, placement) = gameState.locatePlacement(id: placementId) {
            content(placement, layer: layer)
        } else {
            Text("\(title) – srušeno")
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func content(_ p: Placement, layer: MapLayer) -> some View {
        let state = gameState.buildingStates[p.id] ?? BuildingState()
        let health = gameState.healthPercent(p)
        let cycle = WorkCycleCatalog.cycle(for: p.objectId)
        let faction = gameState.owner(of: p) ?? ""
        let mine = gameState.isOwnedByPlayer(p)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(.white.opacity(0.95))
                if !mine, let seat = gameState.seat(of: faction) {
                    Text(seat.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: seat.colorHex) ?? .white)
                }
                healthBar(health)
                if state.isOnFire {
                    Label("Gori", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 8)
                if gameState.isFlammable(p) {
                    smallButton(state.isOnFire ? "Ugasi" : "Zapali", systemImage: state.isOnFire ? "drop.fill" : "flame") {
                        if state.isOnFire { gameState.extinguish(placementId: p.id) } else { gameState.ignite(placementId: p.id) }
                    }
                } else {
                    Text("Ne gori")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                if mine, gameState.hasSleepButton(for: p) {
                    smallButton(state.isClosed ? "Probudi" : "Spavaj", systemImage: state.isClosed ? "sun.max.fill" : "moon.zzz.fill") {
                        gameState.setWorkplaceClosed(placementId: p.id, closed: !state.isClosed)
                    }
                    .help("Spavanje šalje radnika vatri; novi ne dolazi dok se zgrada ne probudi.")
                }
                if mine, p.objectId != Castle.objectId {
                    smallButton("Sruši", systemImage: "hammer.fill") {
                        gameState.demolishPlacement(id: p.id)
                    }
                    .help("Srušeno se ne vraća; radnik ide natrag vatri.")
                }
            }
            if mine, p.objectId == Training.objectId {
                TrainingPanelView(faction: faction)
            }
            if let kind = StorageKind.of(buildingId: p.objectId) {
                storageInventory(kind, placement: p, faction: faction, mine: mine)
            }
            if mine, p.objectId == Smocnica.objectId {
                mealRow
            }
            if p.objectId == Carriage.objectId {
                transportPanel(p, faction: faction, mine: mine)
            }
            if let cycle {
                HStack(spacing: 12) {
                    Label(workerText(state, cycle: cycle, placement: p, layer: layer, faction: faction), systemImage: state.hasWorkerInside ? "person.fill.checkmark" : "person.fill.questionmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(state.hasWorkerInside ? .green : .white.opacity(0.75))
                    progressBar(state.progress / Double(cycle.durationTicks))
                    Text(cycleText(cycle, state: state))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func storageInventory(_ kind: StorageKind, placement p: Placement, faction: String, mine: Bool) -> some View {
        let keeper = gameState.warehouseHasKeeper(p.id)
        let layout = gameState.warehouseLayouts[p.id]
        let goods = kind.goods.sorted { $0.rawValue < $1.rawValue }
        let clients = gameState.warehouseClients(of: p, faction: faction)
        return VStack(alignment: .leading, spacing: 6) {
            storageRow(kind, faction: faction)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 4)], alignment: .leading, spacing: 3) {
                ForEach(goods, id: \.self) { good in
                    let amount = gameState.goodAmount(good, of: faction)
                    Text("\(good.displayName) \(amount)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(amount > 0 ? .white.opacity(0.9) : .white.opacity(0.4))
                }
            }
            if mine {
                HStack(spacing: 8) {
                    if gameState.buildingStates[p.id]?.isClosed == true {
                        Text("Spava – skladištar je otišao")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    } else {
                        smallButton(keeper ? "Otpusti skladištara" : "Zaposli skladištara", systemImage: keeper ? "person.fill.xmark" : "person.fill.badge.plus") {
                            if keeper { gameState.fireWarehouseKeeper(storeId: p.id) } else { gameState.hireWarehouseKeeper(storeId: p.id) }
                        }
                        Text(keeper ? "Skladištar određuje gdje stoji koja roba" : "Bez skladištara nema tlocrta ni ruta")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            if keeper {
                topologyGrid(p, kind: kind, layout: layout)
                if mine, !clients.isEmpty {
                    Text("Rute: tko uzima / tko ostavlja")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(clients) { client in
                                let editing = gameState.editingWarehouseRoute?.workplaceId == client.placement.id
                                    && gameState.editingWarehouseRoute?.good == client.good
                                Button {
                                    gameState.beginWarehouseRoute(storeId: p.id, workplaceId: client.placement.id, good: client.good)
                                } label: {
                                    Text("\(ObjectCatalog.shared.object(id: client.placement.objectId)?.name ?? "") · \(client.takes ? "uzima" : "stavlja") \(client.good.displayName)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(editing ? .black : .white.opacity(0.9))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(editing ? Color.yellow.opacity(0.85) : Color.white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func topologyGrid(_ p: Placement, kind: StorageKind, layout: WarehouseLayout?) -> some View {
        let goods = kind.goods.sorted { $0.rawValue < $1.rawValue }
        return VStack(alignment: .leading, spacing: 4) {
            Text(p.objectId == Lager.objectId ? "Križ je prolaz. Naslage stoje na poljima 2×2." : "Tlocrt – klikni ćeliju i odaberi robu")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
            VStack(spacing: 2) {
                ForEach(0..<max(1, p.height), id: \.self) { r in
                    HStack(spacing: 2) {
                        ForEach(0..<max(1, p.width), id: \.self) { c in
                            let passage = p.objectId == Lager.objectId && LagerPlan.isPassage(localRow: r, localCol: c)
                            let assigned = layout?.slots.first { $0.localRow == r && $0.localCol == c }?.good
                            if passage {
                                Text("prolaz")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 36, height: 22)
                                    .background(Color(red: 0.40, green: 0.30, blue: 0.18).opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                            } else {
                            Menu {
                                Button("Prazno") { gameState.setWarehouseSlot(storeId: p.id, localRow: r, localCol: c, good: nil) }
                                ForEach(goods, id: \.self) { good in
                                    Button(good.displayName) { gameState.setWarehouseSlot(storeId: p.id, localRow: r, localCol: c, good: good) }
                                }
                            } label: {
                                Text(assigned?.displayName ?? "·")
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .foregroundStyle(assigned == nil ? .white.opacity(0.35) : .black)
                                    .frame(width: 36, height: 22)
                                    .background(assigned == nil ? Color.white.opacity(0.08) : Color.yellow.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
                            }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Popunjenost svih skladišta te vrste (svaka građevina dodaje svoj kapacitet).
    private func storageRow(_ kind: StorageKind, faction: String) -> some View {
        let stored = gameState.storageStored(kind, of: faction)
        let capacity = gameState.storageCapacity(kind, of: faction)
        let detail = kind.goods.sorted { $0.rawValue < $1.rawValue }
            .map { "\($0.displayName) \(gameState.goodAmount($0, of: faction))" }.joined(separator: " · ")
        return HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.white.opacity(0.7))
            Text("\(stored) / \(capacity) \(kind.unit)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(stored >= capacity ? .orange : .white.opacity(0.9))
            progressBar(capacity > 0 ? Double(stored) / Double(capacity) : 1)
            Text(detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// Obrok: svaka osoba pojede porciju, pa potrošnja raste s brojem ljudi.
    private var mealRow: some View {
        let short = gameState.playerFoodShortfall
        return HStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .foregroundStyle(.white.opacity(0.7))
            Text("1 hrana svakih \(FoodRules.ticksPerMeal) s ako ima smočnicu · zaliha \(gameState.edibleFood)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            if short > 0 {
                Text("Falilo \(short) porcija")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func workerText(_ state: BuildingState, cycle: WorkCycle, placement: Placement, layer: MapLayer, faction: String) -> String {
        if state.isOnFire { return "Radnik je pobjegao" }
        if state.isClosed { return "Spava – radnik je otišao" }
        switch state.worker {
        case .none:
            if gameState.buildingAlert(for: placement, layer: layer) == .noPath { return "Nema puta do građevine" }
            let free = gameState.peopleOf(faction: faction).filter { $0.role == .peasant }.count
            return "Nema radnika (\(free) slobodnih)"
        case .walking(let left):
            if let person = gameState.worker(of: placement.id) {
                switch person.activity {
                case .delivering: return "Nosi daske u skladište (\(left))"
                case .fetching: return "Uzima sirovinu iz skladišta (\(left))"
                case .returningToWork: return "Vraća se na posao (\(left))"
                case .walkingToTree: return "Ide do stabla (\(left))"
                case .chopping: return "Siječe stablo (\(left))"
                case .haulingLog: return "Nosi deblo kući (\(left))"
                default: break
                }
            }
            return "Radnik dolazi (\(left))"
        case .inside:
            if state.waitingForStorage {
                if let missing = gameState.missingStorage(for: cycle.outputs, of: faction) { return missing.missingText }
                return gameState.fullStorage(for: cycle.outputs, of: faction)?.fullText ?? "Čeka mjesto u skladištu"
            }
            if state.waitingForCandle { return "Čeka svijeću (košnica → vosak → svijeća)" }
            if state.waitingForTree { return "Nema stabla za sječu" }
            if !state.pendingOutputs.isEmpty { return "Pili deblo u daske" }
            return state.waitingForInput ? "Radnik čeka sirovine iz skladišta" : "Radnik je unutra"
        }
    }

    private func cycleText(_ cycle: WorkCycle, state: BuildingState) -> String {
        let season = gameState.currentSeason
        let factor = cycle.kind.seasonFactor(season)
        let inputs = cycle.inputs.map { "\($0.value) \($0.key.displayName)" }.sorted().joined(separator: " + ")
        let outputs = cycle.outputs.map { "\($0.value) \($0.key.displayName)" }.sorted().joined(separator: " + ")
        let recipe = inputs.isEmpty ? "→ \(outputs)" : "\(inputs) → \(outputs)"
        return "\(recipe) · \(season.displayName) ×\(String(format: "%.1f", factor)) · ciklusa \(state.cyclesCompleted)"
    }

    private func healthBar(_ percent: Int) -> some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(percent > 60 ? Color.green : (percent > 30 ? Color.yellow : Color.red))
                    .frame(width: 80 * CGFloat(max(0, min(100, percent))) / 100)
            }
            .frame(width: 80, height: 6)
            Text("\(percent) %")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func progressBar(_ fraction: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.15))
            Capsule()
                .fill(Color.yellow.opacity(0.85))
                .frame(width: 70 * CGFloat(max(0, min(1, fraction))))
        }
        .frame(width: 70, height: 5)
    }

    private func transportPanel(_ p: Placement, faction: String, mine: Bool) -> some View {
        let line = gameState.transportLines[p.id]
        let stored = line?.stored ?? 0
        let cap = TransportRules.miniCapacity
        let detail = (line?.stock ?? [:]).sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.displayName) \($0.value)" }.joined(separator: " · ")
        let sources = gameState.workplacesForTransport(faction: faction)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "cart.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Text("Mini-skladište \(stored) / \(cap)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stored >= cap ? .orange : .white.opacity(0.9))
                progressBar(cap > 0 ? Double(stored) / Double(cap) : 1)
                Text(detail.isEmpty ? "prazno · volovi voze kad ima \(TransportRules.haulSize)" : detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if mine {
                Text("Tko smije ostavljati · klik na rutu: kutovi se miču, siva točka na pola pravi novi kut")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sources, id: \.id) { src in
                            let on = line?.allowedSourceIds.contains(src.id) == true
                            Button {
                                gameState.setTransportSource(depotId: p.id, sourceId: src.id, allowed: !on)
                            } label: {
                                Text(ObjectCatalog.shared.object(id: src.objectId)?.name ?? src.objectId)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(on ? .black : .white.opacity(0.85))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(on ? Color.yellow.opacity(0.85) : Color.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func smallButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
