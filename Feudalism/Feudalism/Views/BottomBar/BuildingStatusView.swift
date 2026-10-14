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
    @Binding var marketFocused: Bool

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
        let cycle = gameState.workCycle(for: p)
        let faction = gameState.owner(of: p) ?? ""
        let mine = gameState.isOwnedByPlayer(p)
        let name = ObjectCatalog.shared.object(id: p.objectId)?.name ?? ""
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
                if name == "Kula" {
                    healthBar(gameState.healthPercent(p))
                }
                Spacer(minLength: 8)
                if mine, gameState.hasSleepButton(for: p) {
                    smallButton(state.isClosed ? "Probudi" : "Spavaj", systemImage: state.isClosed ? "sun.max.fill" : "moon.zzz.fill") {
                        gameState.setWorkplaceClosed(placementId: p.id, closed: !state.isClosed)
                    }
                    .help("Spavanje šalje radnika vatri; novi ne dolazi dok se zgrada ne probudi.")
                }
            }
            if mine, p.objectId == Windmill.objectId {
                millGrainSwitch(placementId: p.id, selected: state.millGrain)
            }
            if mine, p.objectId == Training.objectId {
                TrainingPanelView(faction: faction)
            }
            if mine, p.objectId == Market.objectId, state.hasWorkerInside {
                MarketStockPanel(focused: $marketFocused, sells: false, adjusts: true)
            }
            if mine, p.objectId == Lager.objectId {
                let room = gameState.lagerRoom(of: faction)
                Text("Mjesta \(room.free) slobodna od \(room.total)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                MarketStockPanel(focused: $marketFocused, sells: gameState.marketIsWorking(), adjusts: false)
            }
            if let kind = StorageKind.of(buildingId: p.objectId), p.objectId != Lager.objectId {
                storageInventory(kind, placement: p, faction: faction, mine: mine)
            }
            if mine, p.objectId == Smocnica.objectId {
                mealRow
            }
            if p.objectId == Carriage.objectId {
                transportPanel(p, faction: faction, mine: mine)
            }
            let problems = gameState.workplaceProblems(for: p, layer: layer).filter(\.showsOnBuilding)
            if !problems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(problems, id: \.self) { problem in
                        Text(problem.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.42), in: Capsule())
                    }
                }
            }
            if let cycle, problems.isEmpty, (!cycle.inputs.isEmpty || !cycle.outputs.isEmpty), (state.hasWorkerInside || cycle.kind == .field), !state.isOnFire {
                HStack(spacing: 12) {
                    let denom: Double = {
                        guard cycle.kind == .field else { return Double(cycle.durationTicks) }
                        switch state.fieldPhase {
                        case .sowing: return GameState.FieldPhaseDuration.sow(cycle)
                        case .growing: return GameState.FieldPhaseDuration.grow(cycle)
                        case .harvesting: return GameState.FieldPhaseDuration.harvest(cycle)
                        case .fallow: return 1
                        }
                    }()
                    progressBar(state.progress / max(1, denom))
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
        let needed = gameState.workersRequired(for: placement.objectId)
        let crew = gameState.workers(of: placement.id)
        let have = crew.count
        let crewLabel = needed > 1 ? " \(have)/\(needed)" : ""
        if state.isOnFire { return "Radnik je pobjegao" }
        if state.isClosed { return "Spava – radnik je otišao" }
        if have < needed {
            if gameState.buildingAlert(for: placement, layer: layer) == .noPath { return "Nema puta do građevine" }
            let free = gameState.peopleOf(faction: faction).filter { $0.role == .peasant }.count
            return "Treba\(crewLabel) radnika (\(free) slobodnih)"
        }
        switch state.worker {
        case .none:
            return "Treba\(crewLabel) radnika"
        case .walking(let left):
            if let person = crew.first(where: {
                switch $0.activity {
                case .delivering, .fetching, .returningToWork, .walkingToTree, .chopping, .haulingLog,
                     .walkingToWork, .walkingToField, .workingField:
                    return true
                default: return false
                }
            }) {
                switch person.activity {
                case .delivering: return "Nosi u skladište (\(left))\(crewLabel)"
                case .fetching: return "Uzima sirovinu (\(left))\(crewLabel)"
                case .returningToWork: return "Vraća se na posao (\(left))\(crewLabel)"
                case .walkingToTree: return "Ide do stabla (\(left))"
                case .chopping: return "Siječe stablo (\(left))"
                case .haulingLog: return "Nosi deblo kući (\(left))"
                case .walkingToField(_, let task): return "Ide na polje (\(task.displayName), \(left))"
                case .workingField(_, let task): return "Na polju \(task.displayName) (\(left))"
                default: break
                }
            }
            return "Radnici dolaze (\(left))\(crewLabel)"
        case .inside:
            if state.waitingForStorage {
                if let missing = gameState.missingStorage(for: cycle.outputs, of: faction) { return missing.missingText }
                return gameState.fullStorage(for: cycle.outputs, of: faction)?.fullText ?? "Čeka mjesto u skladištu"
            }
            if state.waitingForCandle { return "Čeka svijeću (farma cvijeća → vosak / svijeća)" }
            if state.waitingForTree { return "Nema stabla za sječu" }
            if cycle.kind == .field {
                switch state.fieldPhase {
                case .fallow: return "Ugar — čeka proljeće\(crewLabel)"
                case .sowing: return "Sjetva\(crewLabel)"
                case .growing: return "Usjev raste\(crewLabel)"
                case .harvesting:
                    return state.pendingOutputs.isEmpty ? "Berba\(crewLabel)" : "Čeka odvoz u skladište\(crewLabel)"
                }
            }
            if !state.pendingOutputs.isEmpty {
                if state.pendingOutputs.keys.contains(.banana) { return "Sortira banane s palme" }
                return "Pili deblo u daske"
            }
            return state.waitingForInput ? "Čeka sirovine iz skladišta\(crewLabel)" : "Posada unutra\(crewLabel)"
        }
    }

    private func cycleText(_ cycle: WorkCycle, state: BuildingState) -> String {
        let season = gameState.currentSeason
        let factor = cycle.kind.seasonFactor(season)
        let inputs = cycle.inputs.map { "\($0.value) \($0.key.displayName)" }.sorted().joined(separator: " + ")
        let outputs = cycle.outputs.map { "\($0.value) \($0.key.displayName)" }.sorted().joined(separator: " + ")
        let recipe = inputs.isEmpty ? "→ \(outputs)" : "\(inputs) → \(outputs)"
        if cycle.kind == .field {
            return "\(recipe) · \(season.displayName) · \(state.fieldPhase.displayName) · žetvi \(state.cyclesCompleted)"
        }
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

    private func millGrainSwitch(placementId: String, selected: MillGrain) -> some View {
        HStack(spacing: 8) {
            Text("Melje")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(MillGrain.allCases, id: \.self) { grain in
                Button {
                    gameState.setMillGrain(placementId: placementId, grain: grain)
                } label: {
                    Text(grain.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected == grain ? .black : .white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selected == grain ? Color.yellow.opacity(0.85) : Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("→ brašno")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
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

private struct MarketStockPanel: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var focused: Bool
    /// Skladište, kad tržnica radi: klik na resurs otvara kupnju i prodaju.
    var sells: Bool = false
    /// Tržnica: plus i minus na zalihi.
    var adjusts: Bool = false
    @State private var selected: Good?

    private var goods: [Good] {
        [.gold] + Good.allCases.filter { $0 != .gold && $0 != .horse }
    }

    var body: some View {
        Group {
            if let selected {
                focusedResource(selected)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 8), spacing: 16) {
                    ForEach(goods, id: \.self) { good in
                        stockCell(good)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: selected?.rawValue) { value in
            focused = value != nil
        }
    }

    private func stockCell(_ good: Good) -> some View {
        let amount = gameState.goodAmount(good)
        return Button {
            selected = good
        } label: {
            VStack(spacing: 4) {
                resourceIcon(good)
                    .frame(width: 52, height: 52)
                Text("\(amount)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func focusedResource(_ good: Good) -> some View {
        let amount = gameState.goodAmount(good)
        return HStack(spacing: 16) {
            menuBackButton("chevron.left")
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                resourceIcon(good)
                    .frame(width: 92, height: 92)
                Text(good.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(amount)")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                if sells, good != .gold, let quote = gameState.tradeQuote(good) {
                    HStack(spacing: 10) {
                        tradeButton("Kupi \(quote.buy)") { gameState.marketBuy(good) }
                        tradeButton("Prodaj \(quote.sell)") { gameState.marketSell(good) }
                    }
                } else if adjusts, good != .gold {
                    HStack(spacing: 10) {
                        stepButton("-5") { gameState.adjustResource(id: good.rawValue, delta: -5) }
                        stepButton("-1") { gameState.adjustResource(id: good.rawValue, delta: -1) }
                        stepButton("+1") { gameState.adjustResource(id: good.rawValue, delta: 1) }
                        stepButton("+5") { gameState.adjustResource(id: good.rawValue, delta: 5) }
                    }
                }
            }
            Spacer(minLength: 0)
            menuBackButton("chevron.right")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func menuBackButton(_ systemName: String) -> some View {
        Button {
            selected = nil
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.16), in: Circle())
        }
        .buttonStyle(.plain)
        .help("Natrag na resurse")
    }

    private func resourceIcon(_ good: Good) -> some View {
        Group {
            if let img = loadBarIcon(named: marketIcon(good)) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private func tradeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 34, height: 28)
                .background(Color.white.opacity(0.16), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func marketIcon(_ good: Good) -> String {
        switch good {
        case .gold: return "gold"
        case .wood: return "wood_resource"
        case .stone: return "stone_resource"
        case .iron: return "iron_resource"
        case .hop: return "hop_resource"
        case .beer: return "beer_resource"
        case .food, .wheat, .flour: return "food"
        case .bread: return "bread_resource"
        case .hay: return "hay_resource"
        case .apple: return "apple_resource"
        case .banana: return "banana_resource"
        case .honey: return "honey_resource"
        case .cheese: return "cheese_resource"
        case .meat: return "meat_resouce"
        case .chicken: return "chicken_resource"
        case .sausages: return "sosages_resouce"
        case .vegetables: return "vegetables_resource"
        case .wine: return "vine_resources"
        case .candle: return "candle_resource"
        case .corn: return "corn_resource"
        case .eggs: return "eggs_resouce"
        case .grapes: return "grapes_resource"
        case .flowers: return "flowers_resoiurce"
        case .spices: return "spices_resources"
        case .leather: return "leather_resources"
        case .shield: return "shield_resource"
        case .spear: return "spear_resource"
        case .sword: return "sword_resource"
        case .bow: return "bow_and_sparrow_resouce"
        default: return good.rawValue
        }
    }
}

private struct MarketTradePanel: View {
    @EnvironmentObject private var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kupnja i prodaja za zlato")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MarketPrices.offers, id: \.good) { offer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(offer.good.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("ima \(gameState.goodAmount(offer.good))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                            HStack(spacing: 4) {
                                tradeButton("Kupi \(offer.buy)") { gameState.marketBuy(offer.good) }
                                tradeButton("Prodaj \(offer.sell)") { gameState.marketSell(offer.good) }
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func tradeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.yellow, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
